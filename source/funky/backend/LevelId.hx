package funky.backend;

import haxe.Json;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import haxe.io.Path;
import funky.backend.utils.JsonLoose;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Identificador de carpeta de un nivel: `<nombre>_<base64 del timestamp de creacion>`.
 *
 * El nombre que se ve (displayName) vive en meta.json, no en la carpeta: se puede renombrar el nivel sin tocar la carpeta
 * y dos niveles con el mismo nombre no se pisan. El id es el timestamp en milisegundos en base64 "url-safe" (sin = ni / ni +),
 * asi que tambien sirve para ordenar por fecha de creacion.
 */
class LevelId
{
	static inline var MAX_SLUG:Int = 24;

	/** Timestamp actual en milisegundos. */
	public static function now():Float
		return Date.now().getTime();

	/** El timestamp como texto entero (sin notacion cientifica ni limite de 32 bits). */
	public static function stampText(stamp:Float):String
	{
		// Math.floor devuelve Int (32 bits) y desbordaria con un timestamp en ms: se trabaja siempre en Float.
		var n:Float = stamp - (stamp % 1);
		if (n <= 0) return "0";
		var out = "";
		while (n >= 1)
		{
			var digit:Float = n % 10;
			out = Std.string(Std.int(digit)) + out;
			n = (n - digit) / 10;
		}
		return out;
	}

	/** Timestamp -> id (base64 url-safe del numero en texto, sin relleno). */
	public static function encode(stamp:Float):String
	{
		var text = stampText(stamp);
		var b64 = Base64.encode(Bytes.ofString(text), false);
		return StringTools.replace(StringTools.replace(b64, "+", "-"), "/", "_");
	}

	/** id -> timestamp (null si no es un id valido). */
	public static function decode(id:String):Null<Float>
	{
		if (id == null || id.length < 8) return null;
		try
		{
			var b64 = StringTools.replace(StringTools.replace(id, "-", "+"), "_", "/");
			var text = Base64.decode(b64, false).toString();
			if (!~/^[0-9]{10,16}$/.match(text)) return null;
			return Std.parseFloat(text);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	/** Parte legible de un nombre para la carpeta: minusculas, a-z 0-9 y guiones. */
	public static function slug(name:String):String
	{
		var out = new StringBuf();
		var lastDash = true;
		for (i in 0...(name == null ? 0 : name.length))
		{
			var c = name.charCodeAt(i);
			var ch = fold(String.fromCharCode(c).toLowerCase());
			var code = ch.charCodeAt(0);
			var ok = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
			if (ok)
			{
				out.add(ch);
				lastDash = false;
			}
			else if (!lastDash)
			{
				out.add("-");
				lastDash = true;
			}
		}
		var s = out.toString();
		while (StringTools.endsWith(s, "-")) s = s.substr(0, s.length - 1);
		if (s.length > MAX_SLUG) s = s.substr(0, MAX_SLUG);
		while (StringTools.endsWith(s, "-")) s = s.substr(0, s.length - 1);
		return s == "" ? "level" : s;
	}

	static function fold(ch:String):String
	{
		var idx = "áàäâãéèëêíìïîóòöôõúùüûñç".indexOf(ch);
		return idx < 0 ? ch : "aaaaaeeeeiiiiooooouuuunc".charAt(idx);
	}

	public static function folderName(name:String, stamp:Float):String
		return slug(name) + "_" + encode(stamp);

	/** Si la carpeta ya trae un id valido al final (`algo_<id>`), devuelve su timestamp. */
	public static function stampOf(folder:String):Null<Float>
	{
		var base = Path.withoutDirectory(Path.removeTrailingSlashes(folder));
		var cut = base.lastIndexOf("_");
		if (cut < 0) return null;
		return decode(base.substr(cut + 1));
	}

	/** Nombre sin el id (para carpetas viejas o importadas que no tienen meta). */
	public static function stripId(folder:String):String
	{
		var base = Path.withoutDirectory(Path.removeTrailingSlashes(folder));
		return stampOf(base) == null ? base : base.substr(0, base.lastIndexOf("_"));
	}

	/**
	 * Carpeta libre para un nivel nuevo con ese nombre dentro de `root`. Si el timestamp ya esta usado (dos niveles en el mismo
	 * milisegundo) se avanza 1 ms.
	 */
	public static function freshFolder(root:String, name:String):String
	{
		var stamp = now();
		#if sys
		while (FileSystem.exists(Path.join([root, folderName(name, stamp)]))) stamp++;
		#end
		return folderName(name, stamp);
	}

	/** Nombre que se muestra en los menus: displayName de meta.json (o name / levelName), si no el nombre de la carpeta sin id. */
	public static function displayName(levelsRoot:String, folder:String):String
	{
		#if sys
		var meta = readMeta(Path.join([levelsRoot, folder]));
		if (meta != null)
			for (key in ["displayName", "name", "levelName", "songName"])
			{
				var v:Dynamic = Reflect.field(meta, key);
				if (v != null && StringTools.trim(Std.string(v)) != "") return StringTools.trim(Std.string(v));
			}
		#end
		return stripId(folder);
	}

	#if sys
	public static function readMeta(dir:String):Null<Dynamic>
	{
		var path = Path.join([dir, "meta.json"]);
		if (!FileSystem.exists(path)) return null;
		try
		{
			var parsed:Dynamic = JsonLoose.parse(File.getContent(path));
			return Reflect.isObject(parsed) ? parsed : null;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	/**
	 * Deja en meta.json el displayName (si faltaba), el id y la fecha de creacion. Se usa al crear y al importar:
	 * lo que ya trae el meta se respeta.
	 */
	public static function stampMeta(dir:String, fallbackName:String, stamp:Float):Void
	{
		var meta:Dynamic = readMeta(dir);
		if (meta == null) meta = {};
		var current:Dynamic = Reflect.field(meta, "displayName");
		if (current == null || StringTools.trim(Std.string(current)) == "") Reflect.setField(meta, "displayName", fallbackName);
		if (Reflect.field(meta, "id") == null) Reflect.setField(meta, "id", encode(stamp));
		if (Reflect.field(meta, "created") == null) Reflect.setField(meta, "created", stampText(stamp));
		File.saveContent(Path.join([dir, "meta.json"]), Json.stringify(meta, null, "  "));
	}

	/** Carpeta de una conversion a medias de `name` (para retomarla con el mismo id), o null. */
	public static function findInProgress(root:String, name:String, progressFile:String):Null<String>
	{
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return null;
		var prefix = slug(name) + "_";
		for (entry in FileSystem.readDirectory(root))
			if (StringTools.startsWith(entry, prefix) && stampOf(entry) != null && FileSystem.exists(Path.join([root, entry, progressFile])))
				return entry;
		return null;
	}
	#end
}
