package funky.backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.Json;
import haxe.Timer;
import haxe.io.Path;
import funky.core.Log;
import funky.core.Paths;
import funky.backend.AtlasPager;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Rectangle;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Atlas de un sprite repartidos en PAGINAS. */
class SpritePages
{
	/** Sube este numero si cambia el formato de la cache, para que se rehaga sola. */
	public static inline var CACHE_VERSION:Int = 1;
	public static inline var GAP:Int = 2;

	/** Lado maximo (px) de una pagina. 4096 es lo que cargan todos los celulares. */
	public static var maxPage:Int = 4096;

	/**
	 * DEBUG. true = las paginas que se generan al reempacar un atlas gigante se escriben en
	 * `<levels>/.tmp/cache/<nivel>/<sprite>/` y SE QUEDAN ahi para que las revises (y se reusan al volver
	 * a cargar). false = se hacen en memoria cada vez y no se escribe nada.
	 */
	public static var keepCacheInTmp:Bool = true;

	/** Carpeta de la cache de un sprite (la haya o no). */
	public static function cacheDir(levelDir:String, name:String):String
		return Path.join([Paths.levelsRoot(), ".tmp", "cache", levelKey(levelDir), name]);

	/**
	 * Frames del sprite si necesita paginas (ya las trae o es demasiado grande); null si el sprite es
	 * normal y lo carga `Paths.getLevelSprite` como siempre.
	 */
	public static function load(levelDir:String, name:String):Null<FlxAtlasFrames>
	{
		#if sys
		var dir = Path.join([levelDir, "sprites", name]);
		var png = Path.join([dir, "sprite.png"]);
		var jsonPath = Path.join([dir, "sprite.json"]);
		try
		{
			var data:Dynamic = Json.parse(File.getContent(jsonPath));
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

		// Cache de una corrida anterior.
		if (keepCacheInTmp && FileSystem.exists(cachedJson))
		{
			try
			{
				var cached:Dynamic = Json.parse(File.getContent(cachedJson));
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
				// El json va al final: sin el, la cache no cuenta (un corte a medias no deja nada valido).
				File.saveContent(cachedJson, Json.stringify(master, null, "\t"));
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

	/**
	 * Junta las paginas en un solo atlas. `bitmaps` (opcional) son las paginas ya en memoria; si no, se leen
	 * de `baseDir/<image>`.
	 */
	static function fromPages(baseDir:String, data:Dynamic, pages:Array<Dynamic>, bitmaps:Null<Array<BitmapData>>):Null<FlxAtlasFrames>
	{
		var frames:Array<Dynamic> = field(data, "frames");

		// Las paginas se juntan en orden: los frames tienen que venir agrupados por pagina, o los indices se desordenan.
		var last = 0;
		for (frame in frames)
		{
			var page = pageOf(frame);
			if (page < last || page >= pages.length)
			{
				Log.warn('[SpritePages] ' + baseDir + ': los frames no vienen ordenados por pagina, se carga sin paginas');
				return null;
			}
			last = page;
		}

		var atlas:Null<FlxAtlasFrames> = null;
		for (k in 0...pages.length)
		{
			var image = Std.string(field(pages[k], "image"));
			var graphic = graphicOf(Path.join([baseDir, image]), bitmaps == null ? null : bitmaps[k]);
			if (graphic == null) return null;

			var own = [for (frame in frames) if (pageOf(frame) == k) frame];
			var part = FlxAtlasFrames.fromAseprite(graphic, Json.stringify({frames: own, meta: {image: image}}));
			if (part == null) return null;

			if (atlas == null) atlas = part;
			else
				for (frame in part.frames) atlas.pushFrame(frame); // (flixel 5.3 del fork de Codename no trae addAtlas)
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

	/** Ancho y alto de un PNG leyendo solo su cabecera (sin decodificarlo). */
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

	/** Borra el `sprite.json` y las paginas viejas de una cache. */
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
