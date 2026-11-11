package funky.core;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

class Addons
{

	public static inline var ID_ROOT:String = "addons/";

	public static function externalRoot():String
	{
		#if sys
		return Path.join([Storage.dataDirectory(), "addons"]);
		#else
		return "addons";
		#end
	}

	public static inline function externalPath(rel:String):String
		return externalRoot() + "/" + clean(rel);

	public static function exists(rel:String):Bool
	{
		rel = clean(rel);
		#if sys
		if (sys.FileSystem.exists(externalRoot() + "/" + rel)) return true;
		#end
		return OpenFlAssets.exists(ID_ROOT + rel);
	}

	public static function file(rel:String):Null<String>
	{
		rel = clean(rel);
		#if sys
		var external = externalRoot() + "/" + rel;
		if (sys.FileSystem.exists(external) && !sys.FileSystem.isDirectory(external)) return external;
		#end

		try
		{
			if (OpenFlAssets.exists(ID_ROOT + rel)) return OpenFlAssets.getPath(ID_ROOT + rel);
		}
		catch (_:Dynamic) {}
		return null;
	}

	public static function getText(rel:String):Null<String>
	{
		rel = clean(rel);
		try
		{
			#if sys
			var external = externalRoot() + "/" + rel;
			if (sys.FileSystem.exists(external) && !sys.FileSystem.isDirectory(external)) return sys.io.File.getContent(external);
			#end
			if (OpenFlAssets.exists(ID_ROOT + rel)) return OpenFlAssets.getText(ID_ROOT + rel);
		}
		catch (e:Dynamic)
		{
			Log.warn('[Addons] no se pudo leer $rel: ' + Std.string(e));
		}
		return null;
	}

	public static function getBitmap(rel:String):Null<BitmapData>
	{
		rel = clean(rel);
		try
		{
			#if sys
			var external = externalRoot() + "/" + rel;
			if (sys.FileSystem.exists(external) && !sys.FileSystem.isDirectory(external)) return BitmapData.fromFile(external);
			#end

			if (OpenFlAssets.exists(ID_ROOT + rel)) return OpenFlAssets.getBitmapData(ID_ROOT + rel, false);
		}
		catch (e:Dynamic)
		{
			Log.warn('[Addons] no se pudo leer la imagen $rel: ' + Std.string(e));
		}
		return null;
	}

	public static function folders(sub:String):Array<String>
	{
		sub = clean(sub);
		var seen = new Map<String, Bool>();

		#if sys
		try
		{
			var dir = externalRoot() + "/" + sub;
			if (sys.FileSystem.exists(dir) && sys.FileSystem.isDirectory(dir))
				for (entry in sys.FileSystem.readDirectory(dir))
					if (sys.FileSystem.isDirectory(dir + "/" + entry)) seen.set(entry, true);
		}
		catch (_:Dynamic) {}
		#end

		try
		{
			var prefix = ID_ROOT + sub + "/";
			var ids = OpenFlAssets.list(null);
			if (ids != null)
				for (id in ids)
				{
					if (id == null || !id.startsWith(prefix)) continue;
					var rest = id.substr(prefix.length);
					var slash = rest.indexOf("/");
					if (slash > 0) seen.set(rest.substr(0, slash), true);
				}
		}
		catch (_:Dynamic) {}

		var out = [for (name in seen.keys()) name];
		out.sort(Reflect.compare);
		return out;
	}

	public static function getSparrowAtlas(rel:String):Null<FlxAtlasFrames>
	{
		rel = clean(rel);
		var xml = getText(rel + ".xml");
		if (xml == null) return null;

		var key = "addon:" + rel;
		var graphic = FlxG.bitmap.get(key);
		if (graphic != null && (graphic.isDestroyed || graphic.bitmap == null))
		{
			try FlxG.bitmap.removeByKey(key) catch (_:Dynamic) {}
			graphic = null;
		}
		if (graphic == null)
		{
			var bitmap = getBitmap(rel + ".png");
			if (bitmap == null) return null;
			graphic = FlxG.bitmap.add(bitmap, false, key);
		}
		if (graphic == null) return null;
		graphic.persist = true;

		return FlxAtlasFrames.fromSparrow(graphic, xml);
	}

	static function clean(rel:String):String
	{
		var p = (rel == null ? "" : rel).replace("\\", "/");
		while (p.startsWith("/")) p = p.substr(1);
		return [for (part in p.split("/")) if (part != ".." && part != ".") part].join("/");
	}
}
