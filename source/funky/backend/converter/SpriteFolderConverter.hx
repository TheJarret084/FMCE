package funky.backend.converter;

import haxe.Json;
import haxe.io.Path;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef SpriteConvertResult = {
	var xml:String;
	var json:String;
	var ok:Bool;
	var skipped:Bool;
	var frames:Int;
	var tags:Int;
	var warnings:Array<String>;
	var error:Null<String>;
}

/** Convierte atlas Sparrow (*.xml) a JSON estilo Aseprite. */
class SpriteFolderConverter
{
	/** Convierte todo lo que cuelgue de `root`. Devuelve un resultado por atlas encontrado. */
	public static function convertTree(root:String, overwrite:Bool = false):Array<SpriteConvertResult>
	{
		var results:Array<SpriteConvertResult> = [];
		#if sys
		if (FileSystem.exists(root) && FileSystem.isDirectory(root)) walk(root, overwrite, results, 0);
		#end
		return results;
	}

	/** Convierte un unico `.xml`. */
	public static function convertFile(xmlPath:String, overwrite:Bool = false):SpriteConvertResult
	{
		var jsonPath = Path.withExtension(xmlPath, "json");
		var result:SpriteConvertResult = {xml: xmlPath, json: jsonPath, ok: false, skipped: false, frames: 0, tags: 0, warnings: [], error: null};

		#if sys
		try
		{
			if (!overwrite && FileSystem.exists(jsonPath))
			{
				result.ok = true;
				result.skipped = true;
				return result;
			}

			var xmlText = File.getContent(xmlPath);

			var imageName = SparrowToAseprite.declaredImage(xmlText);
			if (imageName == null || imageName == "") imageName = Path.withoutExtension(Path.withoutDirectory(xmlPath)) + ".png";

			var dir = Path.directory(xmlPath);
			var pngPath = Path.join([dir, imageName]);
			if (!FileSystem.exists(pngPath)) pngPath = Path.withExtension(xmlPath, "png");
			var size = FileSystem.exists(pngPath) ? pngSize(pngPath) : null;
			if (size == null) result.warnings.push("no se pudo leer el tamano del PNG, se deduce del XML");

			var config:Dynamic = null;
			var configPath = Path.join([dir, "config.json"]);
			if (FileSystem.exists(configPath))
			{
				try config = funky.core.JsonLoose.parse(File.getContent(configPath))
				catch (e:Dynamic) result.warnings.push("config.json ilegible: " + Std.string(e));
			}

			var converted = SparrowToAseprite.convert(xmlText, Path.withoutDirectory(pngPath), config, size == null ? 0 : size.w, size == null ? 0 : size.h);
			for (warning in converted.warnings) result.warnings.push(warning);

			File.saveContent(jsonPath, converted.json);
			result.frames = converted.frames;
			result.tags = converted.tags;
			result.ok = true;
		}
		catch (e:Dynamic)
		{
			result.error = Std.string(e);
		}
		#else
		result.error = "necesita un target sys";
		#end

		return result;
	}

	#if sys
	/** Lado de cada frame de un icono estilo FNF (la imagen mide 150 de alto y 150 o 300 de ancho). */
	public static inline var FNF_ICON_SIZE:Int = 150;

	/** Frames de un icono FNF segun el tamano del PNG: 300x150 = 2 (normal, perdiendo), 150x150 = 1. 0 si no es de ese tamano. */
	public static function fnfIconFrames(size:Null<{w:Int, h:Int}>):Int
	{
		if (size == null || size.h != FNF_ICON_SIZE) return 0;
		return size.w == FNF_ICON_SIZE * 2 ? 2 : (size.w == FNF_ICON_SIZE ? 1 : 0);
	}

	/**
	 * Icono base de FNF: `sprite.png` suelto de 300x150 (2 frames de 150x150: anim0 normal y anim1 perdiendo) o de 150x150 (1 frame).
	 * La imagen no se toca: solo se escribe el `sprite.json` (Aseprite) que la mapea y, si falta, un `config.json` con `type: icon`.
	 * No hace nada si la carpeta ya trae `sprite.json` / `sprite.xml` o si el PNG no mide eso. true = lo mapeo.
	 */
	public static function mapFnfIcon(dir:String):Bool
	{
		try
		{
			var png = Path.join([dir, "sprite.png"]);
			if (!FileSystem.exists(png)) return false;
			if (FileSystem.exists(Path.join([dir, "sprite.json"])) || FileSystem.exists(Path.join([dir, "sprite.xml"]))) return false;

			var size = pngSize(png);
			var count = fnfIconFrames(size);
			if (count == 0) return false;

			var frames:Array<Dynamic> = [];
			var tags:Array<Dynamic> = [];
			var anims:Dynamic = {};
			for (i in 0...count)
			{
				var name = "anim" + i;
				var side = FNF_ICON_SIZE;
				frames.push({
					filename: name,
					frame: {x: i * side, y: 0, w: side, h: side},
					rotated: false,
					trimmed: false,
					spriteSourceSize: {x: 0, y: 0, w: side, h: side},
					sourceSize: {w: side, h: side},
					duration: 42
				});
				tags.push({name: name, from: i, to: i, direction: "forward"});
				Reflect.setField(anims, name, {fps: 24, loop: true});
			}

			var out = {
				frames: frames,
				meta: {
					app: "FMCE SpriteImporter",
					version: "1.0",
					image: "sprite.png",
					format: "RGBA8888",
					size: {w: size.w, h: size.h},
					scale: "1",
					frameTags: tags,
					fmce: {source: "fnf-icon", type: "icon", animations: anims}
				}
			};
			File.saveContent(Path.join([dir, "sprite.json"]), Json.stringify(out, null, "\t"));

			var configPath = Path.join([dir, "config.json"]);
			if (!FileSystem.exists(configPath))
			{
				var config = {type: "icon", data: [for (i in 0...count) {anim: "anim" + i, spd: 1, loop: true}]};
				File.saveContent(configPath, Json.stringify(config, null, "\t"));
			}
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	static function walk(dir:String, overwrite:Bool, out:Array<SpriteConvertResult>, depth:Int):Void
	{
		if (depth > 12) return;
		// Iconos FNF sueltos (sprite.png de 300x150 / 150x150 sin json): se mapean al cargar el nivel.
		mapFnfIcon(dir);
		var entries = FileSystem.readDirectory(dir);
		entries.sort(Reflect.compare);
		for (entry in entries)
		{
			var path = Path.join([dir, entry]);
			if (FileSystem.isDirectory(path))
			{
				walk(path, overwrite, out, depth + 1);
				continue;
			}
			if (Path.extension(entry).toLowerCase() != "xml") continue;

			// Solo atlas Sparrow: cualquier otro .xml (settings.xml, stage.xml...) se deja en paz.
			var text:String = null;
			try text = File.getContent(path) catch (_:Dynamic) continue;
			if (!SparrowToAseprite.isSparrow(text)) continue;

			out.push(convertFile(path, overwrite));
		}
	}

	/** Ancho/alto de un PNG leyendo solo la cabecera IHDR. */
	public static function pngSize(path:String):Null<{w:Int, h:Int}>
	{
		try
		{
			var input = File.read(path, true);
			var header = input.read(24);
			input.close();
			// firma PNG + longitud + "IHDR"
			if (header.length < 24 || header.get(1) != 0x50 || header.get(2) != 0x4E || header.get(3) != 0x47) return null;
			var w = (header.get(16) << 24) | (header.get(17) << 16) | (header.get(18) << 8) | header.get(19);
			var h = (header.get(20) << 24) | (header.get(21) << 16) | (header.get(22) << 8) | header.get(23);
			return {w: w, h: h};
		}
		catch (_:Dynamic)
		{
			return null;
		}
	}
	#end
}
