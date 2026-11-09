package funkin.backend.utils;

import funky.core.ClientPrefs;
import funkin.backend.system.Flags;
import haxe.xml.Access;
import openfl.utils.Assets as OpenFlAssets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Motor de traducciones estilo Codename Engine. */
class Translations
{
	/** Idioma por defecto (respaldo). Se puede cambiar desde Flags. */
	public static var DEFAULT_LANGUAGE(get, never):String;
	public static var DEFAULT_LANGUAGE_NAME(get, never):String;

	/** Idioma actual. Al asignarlo se recargan los XML. */
	public static var language(get, set):String;

	/** Mapa del idioma actual (`id` -> texto). */
	public static var table:Map<String, String> = new Map();

	/** Mapa del idioma por defecto, usado cuando falta una clave en el actual. */
	public static var fallbackTable:Map<String, String> = new Map();

	/** Lista `codigo/Nombre` de todos los idiomas encontrados (el defecto primero). */
	public static var foundLanguages:Array<String> = [];

	/** Nombre visible de cada idioma. */
	public static var nameMap:Map<String, String> = new Map();

	/** Config (`config.ini`) de cada idioma. */
	public static var configs:Map<String, Map<String, String>> = new Map();

	/** Si el idioma actual muestra las claves que faltan en vez de usar el respaldo. */
	public static var showMissingIds:Bool = false;

	static var scanned:Bool = false;
	static var loaded:Bool = false;
	static var currentLanguage:Null<String> = null;
	static var assetList:Array<String> = [];
	static var assetListReady:Bool = false;

	public static function ensureLoaded():Void
	{
		ensureScanned();
		if (loaded) return;
		loaded = true;
		reloadTables();
	}

	/** Vuelve a explorar `assets/languages` (util si se agregan idiomas en caliente). */
	public static function rescan():Void
	{
		scanned = false;
		assetListReady = false;
		assetList = [];
		ensureScanned();
		loaded = true;
		reloadTables();
	}

	/** Cambia el idioma y recarga las tablas. Si `code` no existe usa el de por defecto. */
	public static function setLanguage(code:String):Void
	{
		ensureScanned();
		if (code == null || !nameMap.exists(code)) code = DEFAULT_LANGUAGE;
		if (!nameMap.exists(code) && foundLanguages.length > 0) code = firstLanguageCode();

		currentLanguage = code;
		ClientPrefs.setLanguage(code);
		loaded = true;
		reloadTables();
	}

	public static function getLanguage():String
	{
		if (currentLanguage == null)
		{
			var saved = ClientPrefs.getLanguage();
			currentLanguage = (saved != null && saved.length > 0) ? saved : DEFAULT_LANGUAGE;
		}
		return currentLanguage;
	}

	public static function getLanguageName(code:String):String
		return nameMap.exists(code) ? nameMap.get(code) : code;

	public static function getLanguageFromName(name:String):String
	{
		for (code => visible in nameMap)
			if (visible == name) return code;
		return name;
	}

	public static function getConfig(code:String):Map<String, String>
	{
		if (configs.exists(code)) return configs.get(code);
		var config = new Map<String, String>();
		config.set("name", getLanguageName(code));
		config.set("credits", "");
		config.set("version", "1.0.0");
		return config;
	}

	public static function exists(id:String):Bool
	{
		ensureLoaded();
		return table.exists(id) || fallbackTable.exists(id);
	}

	/** Devuelve el texto sin formatear (para usar `.format([...])` encima). */
	public static function raw(id:String, ?def:String):String
	{
		ensureLoaded();
		if (id == null) return def != null ? def : "";

		var text = table.get(id);
		if (text == null) text = fallbackTable.get(id);
		if (text == null)
			text = def != null ? def : (showMissingIds ? "{" + id + "}" : humanize(id));
		return text;
	}

	/** Traduce un id y reemplaza `{0}`, `{1}`... con `params`. */
	public static function translate(?id:String, ?params:Array<Dynamic>, ?def:String):String
		return format(raw(id, def), params);

	/** Traduce una dificultad (`normal` -> `diff.normal`), con `id` como respaldo. */
	public static function translateDiff(?id:String, ?params:Array<Dynamic>):String
		return translate(id != null ? "diff." + id.toLowerCase() : null, params, id);

	public static function format(text:String, ?params:Array<Dynamic>):String
	{
		if (text == null) return "";
		if (params != null)
			for (i in 0...params.length)
				text = StringTools.replace(text, "{" + i + "}", Std.string(params[i]));
		return text;
	}

	/** `Resume Song` -> `resumeSong` (mismo criterio que Codename). */
	public static function raw2Id(raw:String):String
	{
		if (raw == null) return "";
		raw = raw.trim().toLowerCase();
		var parts = raw.split(" ");
		return [for (i => part in parts) i != 0 ? part.charAt(0).toUpperCase() + part.substr(1) : part].join("");
	}

	/** `charter.file.newChart` -> `New chart` (ultimo segmento, camelCase a palabras). */
	public static function humanize(id:String):String
	{
		if (id == null || id.length == 0) return "";
		var last = id.substr(id.lastIndexOf('.') + 1);
		var out = new StringBuf();
		for (i in 0...last.length)
		{
			var c = last.charAt(i);
			if (i > 0 && c != c.toLowerCase() && last.charAt(i - 1) == last.charAt(i - 1).toLowerCase()) out.add(' ' + c.toLowerCase());
			else out.add(i == 0 ? c.toUpperCase() : c);
		}
		return out.toString();
	}

	public static inline function isDefaultLanguage():Bool
		return getLanguage() == DEFAULT_LANGUAGE;

	public static inline function isLanguageLoaded():Bool
		return table != null && table.keys().hasNext();

	// ---------------------------------------------------------------- carga

	static function reloadTables():Void
	{
		var code = getLanguage();
		var config = getConfig(code);
		showMissingIds = config.get("showMissingIds") == "true";

		table = loadLanguage(code);
		fallbackTable = (code == DEFAULT_LANGUAGE || showMissingIds) ? new Map() : loadLanguage(DEFAULT_LANGUAGE);
	}

	static function loadLanguage(code:String):Map<String, String>
	{
		var result:Map<String, String> = new Map();
		for (path in collectLanguageFiles(code))
		{
			var text = readText(path);
			if (text == null) continue;
			parseXml(text, result, path);
		}
		return result;
	}

	static function parseXml(text:String, result:Map<String, String>, source:String):Void
	{
		var root:Xml = null;
		try
		{
			root = Xml.parse(text).firstElement();
		}
		catch (e:Dynamic)
		{
			trace('[Translations] $source: XML invalido: $e');
			return;
		}
		if (root == null) return;

		var languageNode:Xml = root.nodeName == "language" ? root : null;
		if (languageNode == null)
		{
			for (node in root.elements()) if (node.nodeName == "language")
			{
				languageNode = node;
				break;
			}
		}
		if (languageNode == null) return;

		var access = new Access(languageNode);
		var rootPrefix = access.has.prefix ? access.att.prefix : "";
		parseNode(access, rootPrefix, result);
	}

	static function parseNode(node:Access, prefix:String, result:Map<String, String>):Void
	{
		for (child in node.elements)
		{
			if (child.name == "group")
			{
				parseNode(child, prefix + (child.has.prefix ? child.att.prefix : ""), result);
				continue;
			}

			if (!isTranslationNode(child.name)) continue;
			if (!child.has.id)
			{
				trace('[Translations] <${child.name}> sin atributo id');
				continue;
			}

			var id = prefix + child.att.id;
			if (result.exists(id)) continue;

			var value = child.has.string ? child.att.string : child.innerData;
			if (child.has.notrim && child.att.notrim != "true") value = value.trim();
			value = StringTools.replace(value, "\\n", "\n");
			value = StringTools.replace(value, "\r", "");
			result.set(id, value);
		}
	}

	static inline function isTranslationNode(name:String):Bool
		return name == "str" || name == "text" || name == "trans" || name == "lang" || name == "string";

	// -------------------------------------------------------------- idiomas

	static function ensureScanned():Void
	{
		if (scanned) return;
		scanned = true;

		nameMap = new Map();
		configs = new Map();
		foundLanguages = [];

		var codes = collectLanguageCodes();
		if (!codes.contains(DEFAULT_LANGUAGE)) codes.push(DEFAULT_LANGUAGE);
		codes.sort(Reflect.compare);

		for (code in codes)
		{
			var config = readConfig(code);
			var name = config.get("name");
			if (name == null || name.length == 0) name = code;
			nameMap.set(code, name);
			configs.set(code, config);
		}

		// El idioma por defecto siempre primero.
		foundLanguages.push(DEFAULT_LANGUAGE + "/" + getLanguageName(DEFAULT_LANGUAGE));
		var others = [for (code in codes) if (code != DEFAULT_LANGUAGE) code];
		others.sort(function(a, b) return Reflect.compare(getLanguageName(a).toLowerCase(), getLanguageName(b).toLowerCase()));
		for (code in others) foundLanguages.push(code + "/" + getLanguageName(code));

		var saved = getLanguage();
		if (!nameMap.exists(saved))
		{
			currentLanguage = DEFAULT_LANGUAGE;
			ClientPrefs.setLanguage(DEFAULT_LANGUAGE);
		}
		else currentLanguage = saved;
	}

	static function collectLanguageCodes():Array<String>
	{
		var codes = new Map<String, Bool>();

		for (id in assetIds())
		{
			var normalized = normalizeId(id);
			var parts = normalized.split("/");
			if (parts.length >= 3 && parts[0] == "languages") codes.set(parts[1], true);
		}

		#if sys
		for (base in ["assets/languages", "languages"]) scanDiskCodes(base, codes);
		#end

		return [for (code in codes.keys()) code];
	}

	#if sys
	static function scanDiskCodes(base:String, codes:Map<String, Bool>):Void
	{
		try
		{
			if (!FileSystem.exists(base) || !FileSystem.isDirectory(base)) return;
			for (entry in FileSystem.readDirectory(base))
				if (FileSystem.isDirectory(base + "/" + entry)) codes.set(entry, true);
		}
		catch (e:Dynamic) {}
	}
	#end

	static function collectLanguageFiles(code:String):Array<String>
	{
		var files:Map<String, String> = new Map();
		var prefix = "languages/" + code + "/";

		for (id in assetIds())
		{
			var normalized = normalizeId(id);
			if (normalized.startsWith(prefix) && normalized.endsWith(".xml")) files.set(normalized, id);
		}

		#if sys
		for (base in ["assets/languages/" + code, "languages/" + code])
			collectDiskFiles(base, code, files);
		#end

		var keys = [for (key in files.keys()) key];
		keys.sort(Reflect.compare);
		return [for (key in keys) files.get(key)];
	}

	#if sys
	static function collectDiskFiles(base:String, code:String, files:Map<String, String>):Void
	{
		try
		{
			if (!FileSystem.exists(base) || !FileSystem.isDirectory(base)) return;
			for (entry in FileSystem.readDirectory(base))
			{
				if (!entry.toLowerCase().endsWith(".xml")) continue;
				files.set("languages/" + code + "/" + entry, base + "/" + entry);
			}
		}
		catch (e:Dynamic) {}
	}
	#end

	static function readConfig(code:String):Map<String, String>
	{
		var config:Map<String, String> = new Map();
		config.set("name", code);
		config.set("credits", "");
		config.set("version", "1.0.0");

		var text = readText("assets/languages/" + code + "/config.ini");
		if (text == null) text = readText("languages/" + code + "/config.ini");
		if (text == null) return config;

		for (line in text.split("\n"))
		{
			line = StringTools.trim(line);
			if (line.length == 0 || line.startsWith(";") || line.startsWith("#")) continue;
			var split = line.indexOf("=");
			if (split < 0) continue;

			var key = StringTools.trim(line.substr(0, split));
			var value = StringTools.trim(line.substr(split + 1));
			if (value.length >= 2 && ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))))
				value = value.substring(1, value.length - 1);
			config.set(key, value);
		}
		return config;
	}

	static function assetIds():Array<String>
	{
		if (assetListReady) return assetList;
		assetListReady = true;
		try
		{
			var list = OpenFlAssets.list(null);
			if (list != null) assetList = list;
		}
		catch (e:Dynamic) {}
		return assetList;
	}

	static inline function normalizeId(id:String):String
		return id.startsWith("assets/") ? id.substr("assets/".length) : id;

	static function readText(path:String):Null<String>
	{
		#if sys
		try
		{
			if (FileSystem.exists(path)) return File.getContent(path);
		}
		catch (e:Dynamic) {}
		#end

		try
		{
			var text = OpenFlAssets.getText(path);
			if (text != null) return text;
		}
		catch (e:Dynamic) {}

		try
		{
			var text = OpenFlAssets.getText("assets/" + normalizeId(path));
			if (text != null) return text;
		}
		catch (e:Dynamic) {}

		return null;
	}

	// ------------------------------------------------------- getters/setters

	static function firstLanguageCode():String
	{
		var value = foundLanguages[0];
		return value != null ? value.split("/")[0] : DEFAULT_LANGUAGE;
	}

	static inline function get_DEFAULT_LANGUAGE():String
		return Flags.DEFAULT_LANGUAGE;

	static inline function get_DEFAULT_LANGUAGE_NAME():String
		return Flags.DEFAULT_LANGUAGE_NAME;

	static function get_language():String
		return getLanguage();

	static function set_language(value:String):String
	{
		setLanguage(value);
		return getLanguage();
	}
}
