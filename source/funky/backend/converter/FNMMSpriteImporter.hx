package funky.backend.converter;

import haxe.Json;
import haxe.Int32;
import haxe.io.Bytes;
import haxe.io.Path;
import funky.backend.AtlasPager;
import funky.core.Log;

#if sys
import flixel.FlxG;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;
#end

typedef ImportResult = {
	/** Carpeta del sprite (`<nivel>/sprites/<n>`). */
	var dir:String;
	var ok:Bool;
	var type:String;
	/** Frames del original y cuantos distintos quedaron en el atlas. */
	var frames:Int;
	var unique:Int;
	/** Tamano de la primera pagina. */
	var width:Int;
	var height:Int;
	/** Paginas del atlas (1 si cabe en una). */
	@:optional var pages:Int;
	var warnings:Array<String>;
	var error:Null<String>;
}

/** Sprites NATIVOS de un .fnmm -> atlas FMCE (`sprite.png` + `sprite.json` + `config.json`). */
class FNMMSpriteImporter
{
	public static inline var GAP:Int = 2;
	public static inline var MAX_WIDTH:Int = 4096;
	public static inline var FRAME_DURATION:Int = 42;
	/** Alto maximo de una pagina (el ancho maximo es MAX_WIDTH). */
	public static inline var MAX_PAGE_HEIGHT:Int = 4096;
	/** PNG con compresion rapida: pesa un poco mas pero se escribe mucho mas rapido (en un celular se nota). */
	public static inline var FAST_PNG:Bool = true;

	/** Archivo de la pagina `index`: `sprite.png`, `sprite_p1.png`, ... */
	public static inline function pageFile(index:Int):String
		return index == 0 ? "sprite.png" : "sprite_p" + index + ".png";

	public static final ROLE_CHARACTER = "character";
	public static final ROLE_ICON = "icon";
	public static final ROLE_ITEM = "item";

	/** Nombre de la animacion `index` de un sprite de rol `role`. */
	public static function animName(role:String, index:Int):String
	{
		// Todos los sprites van con anim#: anim0 = idle (en un icono, normal), anim1.. = el resto (icono: perdiendo, ganando).
		return "anim" + index;
	}

	/** Respaldo del sprite.json nativo mientras se cambia por el atlas; si existe, el cambio quedo a medias. */
	public static inline var NATIVE_BACKUP:String = "sprite.native.json";

	/**
	 * Deshace un cambio que se quedo a medias (el juego se cayo): devuelve el sprite.json nativo y borra lo
	 * que ya se habia escrito del atlas. Las tiras `0.png...` solo se borran al final, asi que se puede reconvertir.
	 */
	public static function recover(dir:String):Bool
	{
		#if sys
		var native = Path.join([dir, NATIVE_BACKUP]);
		var restored = false;
		if (FileSystem.exists(native))
		{
			var jsonPath = Path.join([dir, "sprite.json"]);
			if (FileSystem.exists(jsonPath)) FileSystem.deleteFile(jsonPath);
			FileSystem.rename(native, jsonPath);
			if (FileSystem.exists(Path.join([dir, "config.json"]))) FileSystem.deleteFile(Path.join([dir, "config.json"]));
			for (entry in FileSystem.readDirectory(dir))
				if (entry == "sprite.png" || isExtraPage(entry))
					FileSystem.deleteFile(Path.join([dir, entry]));
			restored = true;
			Log.warn('[FNMMSpriteImporter] ' + dir + ': cambio a medias, restaurado el sprite nativo');
		}
		for (entry in FileSystem.readDirectory(dir))
			if (StringTools.endsWith(entry, ".tmp") && (StringTools.startsWith(entry, "sprite") || StringTools.startsWith(entry, "config")))
				FileSystem.deleteFile(Path.join([dir, entry]));
		return restored;
		#else
		return false;
		#end
	}

	/** `sprite_p1.png`, `sprite_p2.png`... (las paginas despues de la primera). */
	public static function isExtraPage(entry:String):Bool
		return StringTools.startsWith(entry, "sprite_p") && StringTools.endsWith(entry, ".png");

	/** `recover` en todos los sprites del nivel. Hay que llamarlo ANTES de `nativeDirs`/`convertLevel`. */
	public static function recoverLevel(levelDir:String):Void
	{
		#if sys
		var root = Path.join([levelDir, "sprites"]);
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return;
		for (entry in FileSystem.readDirectory(root))
		{
			var dir = Path.join([root, entry]);
			if (FileSystem.isDirectory(dir)) recover(dir);
		}
		#end
	}

	#if sys
	/** Renombra pisando el destino (en Windows `rename` falla si ya existe). */
	public static function replaceFile(from:String, to:String):Void
	{
		if (FileSystem.exists(to)) FileSystem.deleteFile(to);
		FileSystem.rename(from, to);
	}
	#end

	/** Carpetas de sprites de `levelDir` que todavia estan en formato nativo (tiras sin `sprite.png`). */
	public static function nativeDirs(levelDir:String):Array<String>
	{
		var out:Array<String> = [];
		#if sys
		var root = Path.join([levelDir, "sprites"]);
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return out;
		for (entry in FileSystem.readDirectory(root))
		{
			var dir = Path.join([root, entry]);
			if (FileSystem.isDirectory(dir) && isNative(dir)) out.push(dir);
		}
		out.sort(Reflect.compare);
		#end
		return out;
	}

	public static function isNative(dir:String):Bool
	{
		#if sys
		var json = Path.join([dir, "sprite.json"]);
		if (!FileSystem.exists(json) || FileSystem.exists(Path.join([dir, "sprite.png"]))) return false;
		if (!FileSystem.exists(Path.join([dir, "0.png"]))) return false;
		try
		{
			var parsed:Dynamic = Json.parse(File.getContent(json));
			return parsed != null && Std.isOfType(Reflect.field(parsed, "data"), Array);
		}
		catch (e:Dynamic)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	/**
	 * Convierte todos los sprites nativos de un nivel.
	 * @param roles nombre de sprite -> "character" | "icon" | "item" (los que no aparezcan son "item").
	 */
	public static function convertLevel(levelDir:String, roles:Map<String, String>):Array<ImportResult>
	{
		var results:Array<ImportResult> = [];
		for (dir in nativeDirs(levelDir))
		{
			var name = Path.withoutDirectory(dir);
			results.push(convertSprite(dir, roles.exists(name) ? roles.get(name) : ROLE_ITEM));
		}
		return results;
	}

	/** Empieza a convertir un sprite sin hacer nada todavia: llama a `step()` hasta que devuelva false. */
	public static function begin(dir:String, role:String):SpriteImportTask
		return new SpriteImportTask(dir, role);

	/** Convierte un sprite de una vez (bloquea hasta terminar). Para no congelar la pantalla usa `begin` + `step`. */
	public static function convertSprite(dir:String, role:String):ImportResult
	{
		var task = begin(dir, role);
		while (task.step()) {}
		return task.result;
	}

	public static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}

/** Conversion de un sprite paso a paso, reanudable. */
class SpriteImportTask
{
	public var result(default, null):ImportResult;
	/** Que esta haciendo ahora ("tira 3/9"). */
	public var label(default, null):String = "";
	public var done(default, null):Bool = false;

	#if sys
	var dir:String = "";
	var role:String = "";
	var phase:Int = 0;
	var data:Array<Dynamic> = [];
	var index:Int = 0;
	var frames:Array<Dynamic> = [];
	var tags:Array<Dynamic> = [];
	var configData:Array<Dynamic> = [];
	var pager:Null<AtlasPager> = null;
	var queue:Array<{index:Int, bitmap:BitmapData}> = [];
	var pageSizes:Array<{w:Int, h:Int}> = [];
	#end

	public function new(dir:String, role:String)
	{
		result = {dir: dir, ok: false, type: role, frames: 0, unique: 0, width: 0, height: 0, warnings: [], error: null};
		#if sys
		this.dir = dir;
		this.role = role;
		#else
		result.error = "necesita una build con sistema de archivos (sys)";
		done = true;
		#end
	}

	/** Un pedazo de trabajo. true = quedan mas pasos. */
	public function step():Bool
	{
		#if sys
		if (done) return false;
		try
		{
			if (queue.length > 0)
			{
				writePage(queue.shift());
			}
			else
			{
				switch (phase)
				{
					case 0: open();
					case 1: readStrip();
					case 2: closePages();
					default: commit();
				}
			}
		}
		catch (e:Dynamic)
		{
			fail(Std.string(e));
		}
		#end
		return !done;
	}

	#if sys
	function open():Void
	{
		FNMMSpriteImporter.recover(dir);

		var native:Dynamic = Json.parse(File.getContent(Path.join([dir, "sprite.json"])));
		var list:Array<Dynamic> = Reflect.field(native, "data");
		if (list == null || list.length == 0) throw "sprite.json no tiene animaciones";
		data = list;

		pager = new AtlasPager(FNMMSpriteImporter.MAX_WIDTH, FNMMSpriteImporter.MAX_PAGE_HEIGHT, FNMMSpriteImporter.GAP, function(page:Int, bitmap:BitmapData):Void
		{
			queue.push({index: page, bitmap: bitmap});
		});

		phase = 1;
		label = "abriendo";
	}

	/** Una tira: se recorta cada frame, se quitan los repetidos y se acomoda directo en la pagina actual. */
	function readStrip():Void
	{
		if (index >= data.length)
		{
			phase = 2;
			return;
		}

		var i = index;
		index++;
		label = "tira " + index + "/" + data.length;

		var entry:Dynamic = data[i];
		var count = Std.int(Math.max(1, FNMMSpriteImporter.number(Reflect.field(entry, "num"), 1)));
		var path = Path.join([dir, i + ".png"]);
		if (!FileSystem.exists(path)) throw "falta la tira " + i + ".png";
		var strip = BitmapData.fromFile(path);
		if (strip == null) throw "no se pudo leer " + i + ".png";

		var frameW = Std.int(strip.width / count);
		var frameH = strip.height;
		if (frameW < 1)
		{
			strip.dispose();
			throw i + ".png es demasiado angosta para " + count + " frames";
		}
		if (frameW * count != strip.width)
			result.warnings.push(i + ".png: " + strip.width + "px no se divide justo en " + count + " frames");

		var atlasName = "anim" + i;
		var from = frames.length;

		// Un solo lienzo por tira: cada copyPixels lo pisa entero, no hace falta limpiarlo ni crear otro por frame.
		var canvas = new BitmapData(frameW, frameH, true, 0x00000000);
		for (k in 0...count)
		{
			canvas.copyPixels(strip, new Rectangle(k * frameW, 0, frameW, frameH), new Point(0, 0));
			var box = canvas.getColorBoundsRect(0xFF000000, 0x00000000, false);
			if (box.width < 1 || box.height < 1) box = new Rectangle(0, 0, 1, 1);

			var bx = Std.int(box.x);
			var by = Std.int(box.y);
			var bw = Std.int(box.width);
			var bh = Std.int(box.height);

			// Dos frames con los mismos pixeles visibles comparten lugar en la pagina (el desplazamiento va en el json de cada frame).
			var raw:Bytes = canvas.getPixels(box);
			var slot = pager.place(hash(raw) + ":" + bw + "x" + bh, bw, bh, canvas, box);

			frames.push({
				filename: atlasName + StringTools.lpad(Std.string(k), "0", 4),
				frame: {x: slot.x, y: slot.y, w: bw, h: bh},
				rotated: false,
				trimmed: bx != 0 || by != 0 || bw != frameW || bh != frameH,
				spriteSourceSize: {x: bx, y: by, w: bw, h: bh},
				sourceSize: {w: frameW, h: frameH},
				duration: FNMMSpriteImporter.FRAME_DURATION,
				page: slot.page
			});
		}
		canvas.dispose();
		strip.dispose();

		tags.push({name: atlasName, from: from, to: frames.length - 1, direction: "forward"});

		// `anim` = tag dentro del atlas. El nombre en el juego (anim0 = idle, anim<N>...) es la posicion en `data`:
		// las tiras se agregan en orden, asi que ya coincide.
		var offset:Dynamic = Reflect.field(entry, "offset");
		configData.push({
			anim: atlasName,
			num: count,
			// FNMM guarda un multiplicador de 24 fps; aca queda como FPS crudos (`spd_fps: true`).
			spd: Math.round(24 * FNMMSpriteImporter.number(Reflect.field(entry, "spd"), 1) * 100) / 100,
			spd_fps: true,
			indices: ([] : Array<Int>),
			loop: Reflect.field(entry, "loop") != false,
			bilinear: Reflect.field(entry, "bilinear") == true,
			scale: FNMMSpriteImporter.number(Reflect.field(entry, "scale"), 1),
			offset: {
				x: FNMMSpriteImporter.number(offset == null ? null : Reflect.field(offset, "x"), 0),
				y: FNMMSpriteImporter.number(offset == null ? null : Reflect.field(offset, "y"), 0)
			}
		});
		result.frames += count;
	}

	function closePages():Void
	{
		pager.finish();
		result.unique = pager.placedCount;
		phase = 3;
		label = "guardando";
	}

	/** Escribe una pagina ya cerrada a `<pagina>.tmp` y libera su bitmap. */
	function writePage(item:{index:Int, bitmap:BitmapData}):Void
	{
		label = "pagina " + (item.index + 1);
		var path = Path.join([dir, FNMMSpriteImporter.pageFile(item.index) + ".tmp"]);
		File.saveBytes(path, item.bitmap.encode(item.bitmap.rect, new PNGEncoderOptions(FNMMSpriteImporter.FAST_PNG)));
		pageSizes[item.index] = {w: item.bitmap.width, h: item.bitmap.height};
		item.bitmap.dispose();
	}

	/** sprite.json (lista de frames + frameTags) y config.json, y el cambio de archivos. */
	function commit():Void
	{
		var pageCount = pageSizes.length;
		if (pageCount == 0) throw "no quedo ninguna pagina";
		result.width = pageSizes[0].w;
		result.height = pageSizes[0].h;
		result.pages = pageCount;

		var data0:Dynamic = data[0];
		var config = {
			type: role,
			bilinear: Reflect.field(data0, "bilinear") == true,
			data: configData
		};

		var meta:Dynamic = {
			app: "FMCE",
			version: "2.0",
			image: "sprite.png",
			format: "RGBA8888",
			size: {w: pageSizes[0].w, h: pageSizes[0].h},
			scale: "1",
			frameTags: tags
		};
		// Un solo `sprite.png` se queda como siempre; con varias, `meta.pages` las lista (ver SpritePages).
		if (pageCount > 1)
		{
			var info:Array<Dynamic> = [];
			for (k in 0...pageCount) info.push({image: FNMMSpriteImporter.pageFile(k), w: pageSizes[k].w, h: pageSizes[k].h});
			Reflect.setField(meta, "pages", info);
		}
		var atlasJson = {frames: frames, meta: meta};

		// Todo se escribe primero a `.tmp` y luego se cambia en un orden fijo, guardando el sprite.json nativo
		// como `sprite.native.json`: si el juego se cae a mitad, `recover` deshace el cambio y las tiras siguen ahi.
		var jsonPath = Path.join([dir, "sprite.json"]);
		var configPath = Path.join([dir, "config.json"]);
		var nativePath = Path.join([dir, FNMMSpriteImporter.NATIVE_BACKUP]);
		File.saveContent(jsonPath + ".tmp", Json.stringify(atlasJson, null, "\t"));
		File.saveContent(configPath + ".tmp", Json.stringify(config, null, "  "));

		if (FileSystem.exists(nativePath)) FileSystem.deleteFile(nativePath);
		FileSystem.rename(jsonPath, nativePath);
		FNMMSpriteImporter.replaceFile(configPath + ".tmp", configPath);
		FNMMSpriteImporter.replaceFile(jsonPath + ".tmp", jsonPath);
		for (k in 0...pageCount)
		{
			var page = Path.join([dir, FNMMSpriteImporter.pageFile(k)]);
			FNMMSpriteImporter.replaceFile(page + ".tmp", page);
			// Si este nivel ya se habia cargado en la sesion, que no quede el atlas viejo en cache.
			FlxG.bitmap.removeByKey("level:" + page);
		}
		// Primero el respaldo (ya esta todo en su sitio) y despues las tiras.
		FileSystem.deleteFile(nativePath);

		// Paginas de una conversion anterior que ahora sobran.
		for (entry in FileSystem.readDirectory(dir))
			if (FNMMSpriteImporter.isExtraPage(entry) && entry != "sprite.png")
			{
				var found = false;
				for (k in 1...pageCount) if (entry == FNMMSpriteImporter.pageFile(k)) found = true;
				if (!found) FileSystem.deleteFile(Path.join([dir, entry]));
			}

		// Las tiras y los stubs de un solo frame que dejaba el conversor viejo ya no sirven.
		for (i in 0...data.length)
			for (leftover in [Path.join([dir, i + ".png"]), Path.join([dir, i + ".json"])])
				if (FileSystem.exists(leftover)) FileSystem.deleteFile(leftover);

		result.ok = true;
		label = "listo";
		done = true;
	}

	function fail(message:String):Void
	{
		result.error = message;
		Log.error('[FNMMSpriteImporter] ' + dir + ': ' + message);
		if (pager != null) pager.dispose();
		for (item in queue) item.bitmap.dispose();
		queue = [];
		// Si se cayo a medias del cambio de archivos, esto devuelve el sprite nativo; si no, solo borra los .tmp.
		try
		{
			FNMMSpriteImporter.recover(dir);
		}
		catch (e:Dynamic) {}
		done = true;
	}

	/** Huella rapida de los pixeles (dos hashes de 32 bits sobre palabras de 4 bytes): mucho mas barata que un MD5 por frame. */
	static function hash(bytes:Bytes):String
	{
		var a:Int32 = 0x811C9DC5;
		var b:Int32 = 0x12345678;
		for (w in 0...(bytes.length >> 2))
		{
			var v:Int32 = bytes.getInt32(w << 2);
			a = (a ^ v) * 16777619;
			b = (b + v) * 0x2C1B3C6D;
			b = b ^ (b >>> 15);
		}
		return StringTools.hex(a, 8) + StringTools.hex(b, 8) + "." + bytes.length;
	}
	#end
}
