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

/**
 * Recorre carpetas buscando atlas Sparrow (`*.xml` con raiz `TextureAtlas`) y escribe al lado un
 * `.json` estilo Aseprite con el mismo nombre base (`sprite.xml` -> `sprite.json`).
 */
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
	static function walk(dir:String, overwrite:Bool, out:Array<SpriteConvertResult>, depth:Int):Void
	{
		if (depth > 12) return;
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
