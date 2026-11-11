package funky.backend.converter;

import haxe.Json;
import funky.core.Log;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ConversionProgress
{
	public static inline var VERSION:Int = 1;

	public static inline var MAX_ATTEMPTS:Int = 2;
	public static inline var FILE_NAME:String = ".convert.json";

	public var path(default, null):String;
	public var archive(default, null):String;

	public var resumed(default, null):Bool = false;

	public var stage:String = "open";

	public var current(default, null):Null<String> = null;

	public var assetsDone:Int = 0;

	var archiveSize:Float = 0;
	var archiveTime:Float = 0;
	var attempts:Map<String, Int> = new Map<String, Int>();
	var sprites:Map<String, String> = new Map<String, String>();

	function new(path:String, archive:String)
	{
		this.path = path;
		this.archive = archive;
		#if sys
		try
		{
			var stat = FileSystem.stat(archive);
			archiveSize = stat.size;
			archiveTime = stat.mtime.getTime();
		}
		catch (_:Dynamic) {}
		#end
	}

	public static function open(path:String, archive:String):ConversionProgress
	{
		var progress = new ConversionProgress(path, archive);
		#if sys
		progress.read();
		#end
		return progress;
	}

	#if sys
	function read():Void
	{
		var source = FileSystem.exists(path) ? path : (FileSystem.exists(path + ".tmp") ? path + ".tmp" : null);
		if (source == null) return;
		try
		{
			var data:Dynamic = Json.parse(File.getContent(source));
			if (data == null || number(Reflect.field(data, "version")) != VERSION) return;
			if (number(Reflect.field(data, "archiveSize")) != archiveSize || number(Reflect.field(data, "archiveTime")) != archiveTime)
			{
				Log.info('[ConversionProgress] ' + archive + ' cambio desde la ultima vez: empiezo de cero');
				return;
			}
			stage = text(Reflect.field(data, "stage"), "open");
			var running = text(Reflect.field(data, "current"), "");
			current = running == "" ? null : running;
			assetsDone = Std.int(number(Reflect.field(data, "assetsDone")));
			fill(attempts, Reflect.field(data, "attempts"), true);
			fill(sprites, Reflect.field(data, "sprites"), false);
			resumed = true;
			Log.info('[ConversionProgress] retomando ' + archive + ' en "' + stage + '"' + (current != null ? ' (se cayo en ' + current + ')' : ''));
		}
		catch (e:Dynamic)
		{
			Log.warn('[ConversionProgress] ' + source + ' ilegible, empiezo de cero: ' + Std.string(e));
		}
	}

	static function fill(into:Map<String, Dynamic>, object:Dynamic, numeric:Bool):Void
	{
		if (object == null) return;
		for (key in Reflect.fields(object))
		{
			var value = Reflect.field(object, key);
			if (numeric) into.set(key, Std.int(number(value)));
			else into.set(key, text(value, ""));
		}
	}
	#end

	public function attemptsOf(unit:String):Int
		return attempts.exists(unit) ? attempts.get(unit) : 0;

	public function crashedTooMuch(unit:String):Bool
		return attemptsOf(unit) >= MAX_ATTEMPTS;

	public function begin(unit:String):Void
	{
		attempts.set(unit, attemptsOf(unit) + 1);
		current = unit;
		save();
	}

	public function finish(unit:String):Void
	{
		attempts.remove(unit);
		if (current == unit) current = null;
	}

	public function spriteStatus(name:String):String
		return sprites.exists(name) ? sprites.get(name) : "";

	public function setSprite(name:String, status:String):Void
		sprites.set(name, status);

	public function spritesWith(status:String):Int
	{
		var count = 0;
		for (value in sprites) if (value == status) count++;
		return count;
	}

	public function save():Void
	{
		#if sys
		try
		{
			var data = {
				version: VERSION,
				archive: archive,
				archiveSize: archiveSize,
				archiveTime: archiveTime,
				stage: stage,
				current: current,
				assetsDone: assetsDone,
				attempts: toObject(attempts),
				sprites: toObject(sprites),
				updated: Date.now().toString()
			};
			var tmp = path + ".tmp";
			File.saveContent(tmp, Json.stringify(data, null, "  "));
			if (FileSystem.exists(path)) FileSystem.deleteFile(path);
			FileSystem.rename(tmp, path);
		}
		catch (e:Dynamic)
		{
			Log.warn('[ConversionProgress] no se pudo guardar ' + path + ': ' + Std.string(e));
		}
		#end
	}

	public function discard():Void
	{
		#if sys
		for (file in [path, path + ".tmp"])
			try
			{
				if (FileSystem.exists(file)) FileSystem.deleteFile(file);
			}
			catch (_:Dynamic) {}
		#end
	}

	static function toObject(map:Map<String, Dynamic>):Dynamic
	{
		var object:Dynamic = {};
		for (key in map.keys()) Reflect.setField(object, key, map.get(key));
		return object;
	}

	static function number(value:Dynamic):Float
	{
		if (value == null) return 0;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? 0 : parsed;
	}

	static function text(value:Dynamic, fallback:String):String
	{
		if (value == null) return fallback;
		var parsed = Std.string(value);
		return parsed == "null" ? fallback : parsed;
	}
}
