package funky.backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import haxe.Timer;
import haxe.io.Path;
import funky.backend.system.Log;
import funky.backend.core.Paths;
import funky.backend.AtlasPager;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Rectangle;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

class SpritePages
{

	public static inline var CACHE_VERSION:Int = 1;
	public static inline var GAP:Int = 2;

	public static var maxPage:Int = 4096;

	public static var keepCacheInTmp:Bool = true;

	public static function cacheDir(levelDir:String, name:String):String
		return Path.join([Paths.levelsRoot(), ".tmp", "cache", levelKey(levelDir), name]);

	public static function load(levelDir:String, name:String):Null<FlxAtlasFrames>
	{
		#if sys
		var dir = Path.join([levelDir, "sprites", name]);
		var png = Path.join([dir, "sprite.png"]);
		var jsonPath = Path.join([dir, "sprite.json"]);
		try
		{
			var data:Dynamic = SpriteSheet.parse(File.getContent(jsonPath));
			if (!Std.isOfType(field(data, "frames"), Array)) return null;

			var pages = pagesOf(data);
			if (pages.length > 0) return fromPages(dir, data, pages, null);

			var size = pngSize(png);
			if (size == null || (size.w <= maxPage && size.h <= maxPage)) return null;
			return repack(levelDir, name, png, data, size.w, size.h);
		}
		catch (e:Dynamic)
		{
			Log.error('[SpritePages] ' + name + ': ' + Std.string(e));
			return null;
		}
		#else
		return null;
		#end
	}

	#if sys

	static function repack(levelDir:String, name:String, png:String, data:Dynamic, srcW:Int, srcH:Int):Null<FlxAtlasFrames>
	{
		var cache = cacheDir(levelDir, name);
		var stat = FileSystem.stat(png);
		var stamp = 'v' + CACHE_VERSION + '|' + stat.size + '|' + Std.string(stat.mtime.getTime()) + '|' + maxPage;
		var cachedJson = Path.join([cache, "sprite.json"]);

		if (keepCacheInTmp && FileSystem.exists(cachedJson))
		{
			try
			{
				var cached:Dynamic = SpriteSheet.parse(File.getContent(cachedJson));
				if (field(field(cached, "meta"), "stamp") == stamp)
				{
					var fromCache = fromPages(cache, cached, pagesOf(cached), null);
					if (fromCache != null)
					{
						Log.info('[SpritePages] ' + name + ': ' + srcW + 'x' + srcH + ' ya reempacado, paginas de la cache ' + cache);
						return fromCache;
					}
				}
			}
			catch (e:Dynamic)
			{
				Log.warn('[SpritePages] ' + name + ': cache ilegible, se rehace (' + Std.string(e) + ')');
			}
		}

		var t0 = Timer.stamp();
		Log.info('[SpritePages] ' + name + ': ' + srcW + 'x' + srcH + ' pasa de ' + maxPage + ', reempacando en paginas');

		var source = BitmapData.fromFile(png);
		if (source == null)
		{
			Log.error('[SpritePages] ' + name + ': no se pudo leer ' + png);
			return null;
		}

		var frames:Array<Dynamic> = field(data, "frames");
		var bitmaps:Array<BitmapData> = [];
		var pager = new AtlasPager(maxPage, maxPage, GAP, function(index:Int, bitmap:BitmapData):Void
		{
			bitmaps.push(bitmap);
		});
		var out:Array<Dynamic> = [];

		for (frame in frames)
		{
			if (field(frame, "rotated") == true)
			{
				Log.warn('[SpritePages] ' + name + ': tiene frames rotados, no se puede reempacar');
				pager.dispose();
				source.dispose();
				for (bitmap in bitmaps) bitmap.dispose();
				return null;
			}

			var rect = field(frame, "frame");
			var fx = int(rect, "x");
			var fy = int(rect, "y");
			var fw = int(rect, "w");
			var fh = int(rect, "h");

			var slot = pager.place(fx + ',' + fy + ',' + fw + ',' + fh, fw, fh, source, new Rectangle(fx, fy, fw, fh));
			var copy:Dynamic = Reflect.copy(frame);
			Reflect.setField(copy, "frame", {x: slot.x, y: slot.y, w: fw, h: fh});
			Reflect.setField(copy, "page", slot.page);
			out.push(copy);
		}
		pager.finish();
		source.dispose();

		if (bitmaps.length == 0)
		{
			Log.warn('[SpritePages] ' + name + ': el atlas no tiene frames');
			return null;
		}

		var info:Array<Dynamic> = [];
		for (k in 0...bitmaps.length) info.push({image: pageFile(k), w: bitmaps[k].width, h: bitmaps[k].height});

		var oldMeta = field(data, "meta");
		var master:Dynamic = {
			frames: out,
			meta: {
				app: "FMCE",
				version: "2.0",
				image: pageFile(0),
				format: "RGBA8888",
				size: {w: bitmaps[0].width, h: bitmaps[0].height},
				scale: "1",
				frameTags: field(oldMeta, "frameTags"),
				pages: info,
				stamp: stamp,
				source: png
			}
		};

		var where = 'solo en memoria';
		if (keepCacheInTmp)
		{
			try
			{
				ensureDir(cache);
				clearCache(cache);
				for (k in 0...bitmaps.length)
					File.saveBytes(Path.join([cache, pageFile(k)]), bitmaps[k].encode(bitmaps[k].rect, new PNGEncoderOptions(true)));

				File.saveContent(cachedJson, SpriteSheet.stringify(master));
				where = 'cache en ' + cache;
			}
			catch (e:Dynamic)
			{
				Log.warn('[SpritePages] ' + name + ': no se pudo escribir la cache en ' + cache + ': ' + Std.string(e));
			}
		}

		var atlas = fromPages(cache, master, info, bitmaps);
		var sizes = [for (k in 0...bitmaps.length) bitmaps[k].width + 'x' + bitmaps[k].height];
		Log.info('[SpritePages] ' + name + ': ' + frames.length + ' frames -> ' + bitmaps.length + ' paginas (' + sizes.join(', ') + ') en '
			+ Std.int((Timer.stamp() - t0) * 1000) + ' ms, ' + where);
		return atlas;
	}

	static function fromPages(baseDir:String, data:Dynamic, pages:Array<Dynamic>, bitmaps:Null<Array<BitmapData>>):Null<FlxAtlasFrames>
	{
		var frames:Array<Dynamic> = field(data, "frames");

		// Los frames pueden venir en cualquier orden de pagina (un video con frames repetidos reusa la celda de una pagina anterior).
		// Se arma cada pagina por separado y al final se acomodan en el orden ORIGINAL de frames, que es el que usan los indices.
		for (frame in frames)
		{
			var page = pageOf(frame);
			if (page < 0 || page >= pages.length)
			{
				Log.warn('[SpritePages] ' + baseDir + ': un frame apunta a la pagina ' + page + ' y solo hay ' + pages.length + ', se carga sin paginas');
				return null;
			}
		}

		var parts:Array<FlxAtlasFrames> = [];
		var counts:Array<Int> = [];
		for (k in 0...pages.length)
		{
			var image = Std.string(field(pages[k], "image"));
			var graphic = graphicOf(Path.join([baseDir, image]), bitmaps == null ? null : bitmaps[k]);
			if (graphic == null) return null;

			var own = [for (frame in frames) if (pageOf(frame) == k) frame];
			var part = own.length == 0 ? null : FlxAtlasFrames.fromAseprite(graphic, Json.stringify({frames: own, meta: {image: image}}));
			if (own.length > 0 && part == null) return null;
			parts.push(part);
			counts.push(0);
		}

		var atlas:Null<FlxAtlasFrames> = null;
		for (frame in frames)
		{
			var k = pageOf(frame);
			var piece = parts[k].frames[counts[k]++];
			if (atlas == null) atlas = new FlxAtlasFrames(parts[k].parent);
			atlas.pushFrame(piece);
		}
		return atlas;
	}

	static function graphicOf(path:String, bitmap:Null<BitmapData>):Null<FlxGraphic>
	{
		var key = "level:" + path;
		var graphic = FlxG.bitmap.get(key);
		if (graphic == null || graphic.bitmap == null)
		{
			if (bitmap == null)
			{
				if (!FileSystem.exists(path))
				{
					Log.warn('[SpritePages] falta ' + path);
					return null;
				}
				bitmap = BitmapData.fromFile(path);
			}
			if (bitmap == null)
			{
				Log.warn('[SpritePages] no se pudo leer ' + path);
				return null;
			}
			graphic = FlxG.bitmap.add(bitmap, false, key);
		}
		if (graphic != null) graphic.persist = true;
		return graphic;
	}

	static inline function pageFile(index:Int):String
		return index == 0 ? "sprite.png" : "sprite_p" + index + ".png";

	static function pagesOf(data:Dynamic):Array<Dynamic>
	{
		var pages = field(field(data, "meta"), "pages");
		return Std.isOfType(pages, Array) ? cast pages : [];
	}

	static function pageOf(frame:Dynamic):Int
	{
		var page = field(frame, "page");
		return page == null ? 0 : Std.int(page);
	}

	static function levelKey(levelDir:String):String
		return Path.withoutDirectory(Path.removeTrailingSlashes(levelDir));

	static function pngSize(path:String):Null<{w:Int, h:Int}>
	{
		var input = File.read(path, true);
		var head = input.read(24);
		input.close();
		if (head.length < 24 || head.get(1) != 0x50) return null;
		return {
			w: (head.get(16) << 24) | (head.get(17) << 16) | (head.get(18) << 8) | head.get(19),
			h: (head.get(20) << 24) | (head.get(21) << 16) | (head.get(22) << 8) | head.get(23)
		};
	}

	static function ensureDir(path:String):Void
	{
		if (path == "" || FileSystem.exists(path)) return;
		var parent = Path.directory(path);
		if (parent != path) ensureDir(parent);
		FileSystem.createDirectory(path);
	}

	static function clearCache(dir:String):Void
	{
		if (!FileSystem.exists(dir)) return;
		for (entry in FileSystem.readDirectory(dir))
			if (entry == "sprite.json" || (StringTools.startsWith(entry, "sprite") && StringTools.endsWith(entry, ".png")))
				FileSystem.deleteFile(Path.join([dir, entry]));
	}

	static inline function field(object:Dynamic, name:String):Dynamic
		return object == null ? null : Reflect.field(object, name);

	static function int(object:Dynamic, name:String):Int
	{
		var value = field(object, name);
		return value == null ? 0 : Std.int(value);
	}
	#end
}
