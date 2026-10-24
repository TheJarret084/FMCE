package advanced.editors;

import funky.backend.converter.SparrowToAseprite;
import funky.backend.converter.SpriteFolderConverter;
import funky.core.Paths;
import funky.game.SpriteBuilder;
import haxe.Json;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef SpriteImportResult =
{
	var inbox:String;
	var imported:Array<String>;
	var skipped:Array<String>;
	var failed:Array<String>;
}

/**
 * Importa sprites a un nivel desde la carpeta `import-sprites` (junto a `levels/`; en Android
 * `.JarretLabs-FMCE/import-sprites`). Cada `nombre.png` se vuelve `levels/<nivel>/sprites/<nombre>/sprite.png`:
 *  - con `nombre.xml` (atlas Sparrow) al lado: se copia como `sprite.xml` y se genera su `sprite.json`;
 *  - con `nombre.json` (Aseprite): se copia como `sprite.json`;
 *  - sin nada: queda de un solo frame (animacion `idle`).
 * Es un "mover": lo importado se borra de la carpeta (despues de copiarlo y comprobar que quedo bien).
 * Un sprite que ya existe en el nivel no se pisa.
 */
class SpriteImporter
{
	public static inline var INBOX:String = "import-sprites";

	public static function inboxDir():String
		return Path.join([Path.directory(Path.removeTrailingSlashes(Paths.levelsRoot())), INBOX]);

	public static function run(levelDir:String):SpriteImportResult
	{
		var result:SpriteImportResult = {inbox: inboxDir(), imported: [], skipped: [], failed: []};

		#if sys
		var inbox = result.inbox;

		try
		{
			if (!FileSystem.exists(inbox)) FileSystem.createDirectory(inbox);
		}
		catch (e:Dynamic)
		{
			result.failed.push("no pude crear " + inbox);
			return result;
		}

		var files:Array<String> = [];
		try
		{
			files = FileSystem.readDirectory(inbox);
		}
		catch (e:Dynamic) {}
		files.sort(Reflect.compare);

		for (file in files)
		{
			var png = Path.join([inbox, file]);
			if (Path.extension(file).toLowerCase() != "png" || FileSystem.isDirectory(png)) continue;

			var base = Path.withoutExtension(file);
			var name = cleanName(base);
			if (name == "")
			{
				result.failed.push(file + " (nombre invalido)");
				continue;
			}

			var dest = SpriteBuilder.spriteDir(levelDir, name);
			if (FileSystem.exists(dest))
			{
				result.skipped.push(name);
				continue;
			}

			var used:Array<String> = [png];

			try
			{
				var spritesRoot = Path.join([levelDir, "sprites"]);
				if (!FileSystem.exists(spritesRoot)) FileSystem.createDirectory(spritesRoot);
				FileSystem.createDirectory(dest);
				File.copy(png, Path.join([dest, "sprite.png"]));

				var xml = Path.join([inbox, base + ".xml"]);
				var json = Path.join([inbox, base + ".json"]);

				if (FileSystem.exists(xml) && isSparrowFile(xml))
				{
					var destXml = Path.join([dest, "sprite.xml"]);
					File.copy(xml, destXml);

					var converted = SpriteFolderConverter.convertFile(destXml, true);
					if (!converted.ok) throw Std.string(converted.error);
					used.push(xml);
				}
				else if (FileSystem.exists(json))
				{
					File.copy(json, Path.join([dest, "sprite.json"]));
					used.push(json);
				}
				else
					writeSingleFrame(dest);

				if (!SpriteBuilder.exists(levelDir, name)) throw "no quedo un sprite valido";

				result.imported.push(name);

				// ya esta copiado y comprobado: se saca de la carpeta de entrada
				for (path in used)
				{
					try
					{
						FileSystem.deleteFile(path);
					}
					catch (e:Dynamic) {}
				}
			}
			catch (e:Dynamic)
			{
				result.failed.push(name + " (" + Std.string(e) + ")");
				removeDir(dest);
			}
		}
		#end

		return result;
	}

	/** Deja solo letras, numeros, `_` y `-` (los acentos y espacios pasan a `_`). */
	static function cleanName(base:String):String
	{
		var name = ~/[^A-Za-z0-9_\-]+/g.replace(base, "_");
		return ~/^_+|_+$/g.replace(name, "");
	}

	#if sys
	static function isSparrowFile(path:String):Bool
	{
		try
		{
			return SparrowToAseprite.isSparrow(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}

	/** `sprite.json` (estilo Aseprite) de un PNG suelto: un frame que ocupa toda la imagen y la animacion `idle`. */
	static function writeSingleFrame(dest:String):Void
	{
		var size = SpriteFolderConverter.pngSize(Path.join([dest, "sprite.png"]));
		if (size == null) throw "no es un PNG valido";

		var out = {
			frames: [
				{
					filename: "idle",
					frame: {x: 0, y: 0, w: size.w, h: size.h},
					rotated: false,
					trimmed: false,
					spriteSourceSize: {x: 0, y: 0, w: size.w, h: size.h},
					sourceSize: {w: size.w, h: size.h},
					duration: 42
				}
			],
			meta: {
				app: "FMCE SpriteImporter",
				version: "1.0",
				image: "sprite.png",
				format: "RGBA8888",
				size: {w: size.w, h: size.h},
				scale: "1",
				frameTags: [{name: "idle", from: 0, to: 0, direction: "forward"}],
				fmce: {source: "png", animations: {idle: {fps: 24, loop: true}}}
			}
		};

		File.saveContent(Path.join([dest, "sprite.json"]), Json.stringify(out, null, "\t"));
	}

	/** Borra una carpeta recien creada por el importador (solo archivos sueltos, sin subcarpetas). */
	static function removeDir(dir:String):Void
	{
		try
		{
			if (!FileSystem.exists(dir)) return;
			for (f in FileSystem.readDirectory(dir)) FileSystem.deleteFile(Path.join([dir, f]));
			FileSystem.deleteDirectory(dir);
		}
		catch (e:Dynamic) {}
	}
	#end
}
