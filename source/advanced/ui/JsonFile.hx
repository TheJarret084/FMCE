package advanced.ui;

import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Lee y escribe los JSON que tocan los editores. Antes de la primera escritura de la sesion deja una copia `.bak`. */
class JsonFile
{
	static var backedUp:Map<String, Bool> = new Map();

	public static function read(path:String):Dynamic
	{
		#if sys
		if (!FileSystem.exists(path)) return null;
		try
			return Json.parse(File.getContent(path))
		catch (e:Dynamic)
			return null;
		#else
		return null;
		#end
	}

	/** false si no se pudo escribir. */
	public static function write(path:String, data:Dynamic):Bool
	{
		#if sys
		try
		{
			if (!backedUp.exists(path) && FileSystem.exists(path))
			{
				File.copy(path, path + ".bak");
				backedUp.set(path, true);
			}
			File.saveContent(path, Json.stringify(data, null, "  "));
			return true;
		}
		catch (e:Dynamic)
			return false;
		#else
		return false;
		#end
	}

	public static inline function field(object:Dynamic, name:String):Dynamic
		return object == null ? null : Reflect.field(object, name);

	public static function num(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	/** Redondea a 4 decimales (evita 1.9900000000000027 en el archivo). */
	public static inline function round(value:Float):Float
		return Math.round(value * 10000) / 10000;

	/** `object[name]` como objeto; lo crea si no existe. */
	public static function obj(object:Dynamic, name:String):Dynamic
	{
		var value:Dynamic = Reflect.field(object, name);
		if (value == null || Std.isOfType(value, Array) || !Reflect.isObject(value))
		{
			value = {};
			Reflect.setField(object, name, value);
		}
		return value;
	}
}
