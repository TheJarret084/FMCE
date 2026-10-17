package funkin.backend.utils;

import haxe.xml.Access;
import openfl.utils.Assets;

class Translations
{
	/** Idioma del editor (carpeta de `assets/languages/<codigo>/`). Lo que falte en el se completa con `en`. */
	public static var language:String = "es";
	/** Idioma de respaldo cuando una clave no existe en `language`. */
	public static inline var FALLBACK:String = "en";

	static var loaded:Bool = false;

	/** Carga `en` y encima `language` (una sola vez). Lo llama `TranslationUtil` antes de leer la tabla. */
	public static function ensureLoaded():Void
	{
		if (loaded) return;
		loaded = true;
		var defaults = table; // los textos con formato de abajo se mantienen como base
		table = new Map();
		for (k => v in defaults) table.set(k, v);
		load(FALLBACK);
		if (language != FALLBACK) load(language);
	}

	/** Cambia el idioma y vuelve a leer los XML. */
	public static function setLanguage(code:String):Void
	{
		language = code;
		loaded = false;
		ensureLoaded();
	}

	static function load(code:String):Void
	{
		var path = 'assets/languages/$code/Editors.xml';
		try
		{
			if (!Assets.exists(path)) return;
			var root = Xml.parse(Assets.getText(path)).firstElement();
			if (root != null) walk(new Access(root), "");
		}
		catch (e:Dynamic) trace('[Translations] no se pudo leer $path: $e');
	}

	/** Los `<group prefix="x.">` se anidan: el id final es la suma de todos los prefijos + el `id` del `<str>`. */
	static function walk(node:Access, prefix:String):Void
	{
		for (el in node.elements)
		{
			if (el.name == "group")
				walk(el, prefix + (el.has.prefix ? el.att.prefix : ""));
			else if (el.name == "str" && el.has.id)
			{
				var text = new StringBuf();
				for (c in el.x.iterator())
					if (c.nodeType == Xml.PCData || c.nodeType == Xml.CData) text.add(c.nodeValue);
				table.set(prefix + el.att.id, StringTools.replace(text.toString(), "\\n", "\n"));
			}
		}
	}

	/** Textos con formato ({0}, {1}...) que el charter pide con `TU.getRaw`; sin esto devolvia null y crasheaba. */
	public static var table:Map<String, String> = [
		"songPosInfo.step" => "Step: {0}",
		"songPosInfo.beat" => "Beat: {0}",
		"songPosInfo.measure" => "Measure: {0}",
		"songPosInfo.bpm" => "BPM: {0}",
		"songPosInfo.timeSignature" => "Time Signature: {0}/{1}",
		"charter.bookmarks.goTo" => "Go to {0}",
		"charter.snap.snap" => "{0}x Grid Snap",
		"charterEventScreen.strumLine.format" => "Strumline #{0} ({1})",
		"uiImageExplorer.directory" => "Directory: {0}",
		"uiImageExplorer.found" => "found {0} {1}",
		"uiImageExplorer.foundplural" => "found {0} {1}s",
		"uiImageExplorer.notFound" => "no {0} found",
		"uiImageExplorer.foundAtlas" => "found {0} atlas",
		"uiImageExplorer.foundAtlasplural" => "found {0} atlases",
		"uiImageExplorer.fileAlreadyExists" => "These files already exist:\n{0}"
	];

	/** "charter.file.newChart" -> "New chart" (último segmento, camelCase a palabras). */
	public static function humanize(id:String):String
	{
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
}
