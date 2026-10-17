package funky.backend.converter;

import haxe.Json;
import haxe.crypto.Md5;
import haxe.io.Bytes;
import haxe.io.Path;
import funky.core.Log;

#if sys
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;
#end

typedef StripResult = {
	/** Carpeta del sprite (`levels/<nivel>/sprites/<n>`). */
	var dir:String;
	var ok:Bool;
	/** true si no hacia falta convertirlo (ya es cinta + JSON Hash, o es de otro tipo). */
	var skipped:Bool;
	var frames:Int;
	/** Frames distintos que quedaron en la cinta. */
	var unique:Int;
	var width:Int;
	var height:Int;
	var warnings:Array<String>;
	var error:Null<String>;
}

private typedef Piece = {
	var bitmap:Dynamic;
	var w:Int;
	var h:Int;
	var offX:Int;
	var offY:Int;
	var srcW:Int;
	var srcH:Int;
}

/** Sprite de nivel -> CINTA + JSON HASH. */
class StripConverter
{
	/** Tipos de sprite que se convierten por defecto. Los iconos tambien: idle/singLEFT/singRIGHT -> anim0/anim1/anim2. */
	public static final DEFAULT_TYPES:Array<String> = ["character", "icon"];

	static inline var GAP:Int = 2;
	/** Mas ancho que esto y algunos celulares no cargan la textura. */
	static inline var MAX_SAFE_WIDTH:Int = 4096;

	/** Carpetas de sprites de un nivel (`sprites/<n>`) con `sprite.png` + `sprite.json`. */
	public static function spriteDirs(levelDir:String):Array<String>
	{
		var out:Array<String> = [];
		#if sys
		var root = Path.join([levelDir, "sprites"]);
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return out;
		for (entry in FileSystem.readDirectory(root))
		{
			var dir = Path.join([root, entry]);
			if (FileSystem.isDirectory(dir) && FileSystem.exists(Path.join([dir, "sprite.png"])) && FileSystem.exists(Path.join([dir, "sprite.json"])))
				out.push(dir);
		}
		out.sort(Reflect.compare);
		#end
		return out;
	}

	/** true si el sprite es de un tipo a convertir y todavia no es cinta + JSON Hash `animN`. */
	public static function needsConversion(dir:String, ?types:Array<String>):Bool
	{
		#if sys
		try
		{
			if (types == null) types = DEFAULT_TYPES;
			var type = spriteType(dir);
			if (types.indexOf(type) < 0) return false;
			var data:Dynamic = Json.parse(File.getContent(Path.join([dir, "sprite.json"])));
			if (Std.isOfType(data.frames, Array)) return true;
			var tags:Array<Dynamic> = data.meta != null && Std.isOfType(data.meta.frameTags, Array) ? data.meta.frameTags : [];
			for (tag in tags) if (newAnimName(Std.string(tag.name), type) != Std.string(tag.name)) return true;
		}
		catch (e:Dynamic) {}
		#end
		return false;
	}

	/** Cuantos sprites de `levelDir` falta convertir. */
	public static function pending(levelDir:String, ?types:Array<String>):Int
	{
		var count = 0;
		for (dir in spriteDirs(levelDir)) if (needsConversion(dir, types)) count++;
		return count;
	}

	/** Convierte todo lo pendiente de un nivel. */
	public static function convertLevel(levelDir:String, ?types:Array<String>):Array<StripResult>
	{
		var results:Array<StripResult> = [];
		for (dir in spriteDirs(levelDir)) if (needsConversion(dir, types)) results.push(convertSprite(dir));
		return results;
	}

	public static function convertSprite(dir:String):StripResult
	{
		var result:StripResult = {dir: dir, ok: false, skipped: false, frames: 0, unique: 0, width: 0, height: 0, warnings: [], error: null};
		#if sys
		var pieces:Array<BitmapData> = [];
		var source:Null<BitmapData> = null;
		try
		{
			var jsonPath = Path.join([dir, "sprite.json"]);
			var pngPath = Path.join([dir, "sprite.png"]);
			var configPath = Path.join([dir, "config.json"]);

			var data:Dynamic = Json.parse(File.getContent(jsonPath));
			source = BitmapData.fromFile(pngPath);
			if (source == null) throw "no se pudo leer " + pngPath;

			var type = spriteType(dir);
			var old = readFrames(data);
			var tags:Array<Dynamic> = data.meta != null && Std.isOfType(data.meta.frameTags, Array) ? data.meta.frameTags : [];
			if (tags.length == 0) throw "sprite.json no tiene frameTags";

			// 1) nombre nuevo de cada frame: <anim><indice dentro del tag, 4 digitos>
			var names:Array<String> = [];
			var picked = new Map<String, Dynamic>();
			for (tag in tags)
			{
				var animName = newAnimName(Std.string(tag.name), type);
				var from:Int = Std.int(tag.from);
				var to:Int = Std.int(tag.to);
				for (index in from...to + 1)
				{
					if (index < 0 || index >= old.length) throw 'el tag ${tag.name} apunta al frame $index, que no existe';
					var name = animName + StringTools.lpad(Std.string(index - from), "0", 4);
					if (picked.exists(name)) throw "nombre repetido: " + name;
					picked.set(name, old[index]);
					names.push(name);
				}
			}
			names.sort(Reflect.compare);
			result.frames = names.length;

			// 2) cada frame completo -> recorte a lo visible -> dedupe por contenido
			var uniqueIndex = new Map<String, Int>();
			var unique:Array<Piece> = [];
			var plan = new Map<String, Int>();
			for (name in names)
			{
				var f:Dynamic = picked.get(name);
				if (f.rotated == true) throw name + ": frame rotado; exporta el atlas sin rotacion";
				var ss = f.sourceSize;
				var sp = f.spriteSourceSize;
				var fr = f.frame;
				var canvas = new BitmapData(Std.int(ss.w), Std.int(ss.h), true, 0x00000000);
				canvas.copyPixels(source, new Rectangle(fr.x, fr.y, fr.w, fr.h), new Point(sp.x, sp.y));

				var box = canvas.getColorBoundsRect(0xFF000000, 0x00000000, false);
				if (box.width < 1 || box.height < 1) box = new Rectangle(0, 0, 1, 1);
				var crop = new BitmapData(Std.int(box.width), Std.int(box.height), true, 0x00000000);
				crop.copyPixels(canvas, box, new Point(0, 0));
				canvas.dispose();

				var raw:Bytes = crop.getPixels(crop.rect);
				var key = Md5.make(raw).toHex() + ":" + crop.width + "x" + crop.height + "@" + Std.int(box.x) + "," + Std.int(box.y) + "/" + Std.int(ss.w) + "x" + Std.int(ss.h);
				if (!uniqueIndex.exists(key))
				{
					uniqueIndex.set(key, unique.length);
					unique.push({bitmap: crop, w: crop.width, h: crop.height, offX: Std.int(box.x), offY: Std.int(box.y), srcW: Std.int(ss.w), srcH: Std.int(ss.h)});
					pieces.push(crop);
				}
				else
					crop.dispose();
				plan.set(name, uniqueIndex.get(key));
			}
			result.unique = unique.length;

			// 3) la cinta: una sola fila
			var width = GAP;
			var height = 1;
			for (piece in unique)
			{
				width += piece.w + GAP;
				if (piece.h > height) height = piece.h;
			}
			height += GAP * 2;
			var strip = new BitmapData(width, height, true, 0x00000000);
			var rects:Array<{x:Int, y:Int}> = [];
			var x = GAP;
			for (piece in unique)
			{
				strip.copyPixels(piece.bitmap, new Rectangle(0, 0, piece.w, piece.h), new Point(x, GAP));
				rects.push({x: x, y: GAP});
				x += piece.w + GAP;
			}
			result.width = width;
			result.height = height;
			if (width > MAX_SAFE_WIDTH)
				result.warnings.push('cinta de ${width}px de ancho: algunos celulares no cargan texturas de mas de $MAX_SAFE_WIDTH');

			// 4) JSON Hash (frames ordenados por nombre)
			var indexOf = new Map<String, Int>();
			for (i in 0...names.length) indexOf.set(names[i], i);

			var frames:Dynamic = {};
			for (name in names)
			{
				var u = plan.get(name);
				var piece = unique[u];
				var original:Dynamic = picked.get(name);
				Reflect.setField(frames, name, {
					frame: {x: rects[u].x, y: rects[u].y, w: piece.w, h: piece.h},
					rotated: false,
					trimmed: piece.offX != 0 || piece.offY != 0 || piece.w != piece.srcW || piece.h != piece.srcH,
					spriteSourceSize: {x: piece.offX, y: piece.offY, w: piece.w, h: piece.h},
					sourceSize: {w: piece.srcW, h: piece.srcH},
					duration: original.duration != null ? original.duration : 42
				});
			}

			// frameTags: mismo orden que el original (el primero es la animacion inicial),
			// con el nombre nuevo y los indices del orden por nombre.
			var rename = new Map<String, String>();
			var newTags:Array<Dynamic> = [];
			for (tag in tags)
			{
				var animName = newAnimName(Std.string(tag.name), type);
				rename.set(Std.string(tag.name), animName);
				var count = Std.int(tag.to) - Std.int(tag.from) + 1;
				var first = indexOf.get(animName + "0000");
				var newTag:Dynamic = Reflect.copy(tag);
				newTag.name = animName;
				Reflect.setField(newTag, "from", first);
				Reflect.setField(newTag, "to", first + count - 1);
				newTags.push(newTag);
			}

			var meta:Dynamic = data.meta != null ? Reflect.copy(data.meta) : {};
			meta.app = "FMCE StripConverter";
			meta.version = "1.0";
			meta.image = "sprite.png";
			meta.format = "RGBA8888";
			meta.size = {w: width, h: height};
			meta.scale = "1";
			meta.frameTags = newTags;
			if (meta.fmce != null && meta.fmce.animations != null)
			{
				var fmce:Dynamic = Reflect.copy(meta.fmce);
				var anims:Dynamic = {};
				for (key in Reflect.fields(meta.fmce.animations))
					Reflect.setField(anims, rename.exists(key) ? rename.get(key) : key, Reflect.field(meta.fmce.animations, key));
				fmce.animations = anims;
				meta.fmce = fmce;
			}

			// 5) config.json: mismos nombres
			var config:Null<Dynamic> = null;
			if (FileSystem.exists(configPath))
			{
				config = Json.parse(File.getContent(configPath));
				if (Std.isOfType(config.data, Array))
					for (entry in (config.data : Array<Dynamic>))
					{
						// `anim` = nombre en el atlas (el tag), `name` = el que aplica el juego. Sin `anim` (FNMM viejo) `name` hace de ambos.
						var key = entry.anim != null ? entry.anim : entry.name;
						if (key != null && rename.exists(Std.string(key)))
						{
							if (entry.anim != null) entry.anim = rename.get(Std.string(key));
							else entry.name = rename.get(Std.string(key));
						}
					}
			}

			// 6) escribir (con copia .orig de lo que habia)
			for (path in [jsonPath, pngPath, configPath])
				if (FileSystem.exists(path) && !FileSystem.exists(path + ".orig")) File.copy(path, path + ".orig");

			File.saveBytes(pngPath, strip.encode(strip.rect, new PNGEncoderOptions()));
			File.saveContent(jsonPath, Json.stringify({frames: frames, meta: meta}, null, "\t"));
			if (config != null) File.saveContent(configPath, Json.stringify(config, null, "  "));
			strip.dispose();
			result.ok = true;
		}
		catch (e:Dynamic)
		{
			result.error = Std.string(e);
			Log.error('[StripConverter] ' + dir + ': ' + result.error);
		}
		for (piece in pieces) piece.dispose();
		if (source != null) source.dispose();
		#else
		result.error = "necesita una build con sistema de archivos (sys)";
		#end
		return result;
	}

	/**
	 * singLEFT/DOWN/UP/RIGHT (o sing0, sing1...) -> anim0..N. Cualquier otro nombre queda igual.
	 * En un icono (`type == "icon"`): idle -> anim0, singLEFT -> anim1, singRIGHT -> anim2.
	 */
	public static function newAnimName(name:String, ?type:String):String
	{
		var lower = name.toLowerCase();
		if (type == "icon")
		{
			switch (lower)
			{
				case "idle": return "anim0";
				case "singleft": return "anim1";
				case "singright": return "anim2";
				default: return name;
			}
		}
		if (!StringTools.startsWith(lower, "sing")) return name;
		return switch (lower.substr(4))
		{
			case "left": "anim0";
			case "down": "anim1";
			case "up": "anim2";
			case "right": "anim3";
			default:
				var n = Std.parseInt(lower.substr(4));
				n != null && Std.string(n) == lower.substr(4) ? "anim" + n : name;
		}
	}

	#if sys
	/** Frames del sprite.json como lista, en el orden del indice (lista) o del objeto (Hash). */
	static function readFrames(data:Dynamic):Array<Dynamic>
	{
		if (Std.isOfType(data.frames, Array)) return data.frames;
		// Hash: mismo orden que usa el motor al leerlo (por nombre).
		var keys = Reflect.fields(data.frames);
		keys.sort(Reflect.compare);
		return [for (key in keys) Reflect.field(data.frames, key)];
	}

	static function spriteType(dir:String):String
	{
		var configPath = Path.join([dir, "config.json"]);
		if (FileSystem.exists(configPath))
		{
			var config:Dynamic = Json.parse(File.getContent(configPath));
			if (config.type != null) return Std.string(config.type);
		}
		var data:Dynamic = Json.parse(File.getContent(Path.join([dir, "sprite.json"])));
		if (data.meta != null && data.meta.fmce != null && data.meta.fmce.type != null) return Std.string(data.meta.fmce.type);
		return "sprite";
	}
	#end
}
