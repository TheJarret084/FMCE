package advanced.editors;

import funky.backend.converter.SparrowToAseprite;
import funky.backend.converter.SpriteFolderConverter;
import funky.core.Paths;
import funky.game.SpriteBuilder;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
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
 *  - sin nada: queda de un solo frame (animacion `anim0`, la idle).
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

				ensureConfig(dest);
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

	/**
	 * Crea `sprites/<name>/` desde bytes ya cargados (ventana de importar, estilo character editor de Codename):
	 * `sprite.png` + `sprite.xml`/`sprite.json` si trae atlas, o un solo frame `anim0`. Devuelve null si salio bien,
	 * o el motivo del fallo. Con `overwrite` reemplaza solo `sprite.png/xml/json` y deja el resto (config.json...).
	 */
	public static function importBytes(levelDir:String, name:String, image:Bytes, isJpg:Bool, dataKind:Null<String>, dataText:Null<String>, overwrite:Bool = false):Null<String>
	{
		#if sys
		var dest = SpriteBuilder.spriteDir(levelDir, name);
		var existed = FileSystem.exists(dest);
		if (existed && !overwrite) return "ya existe";

		try
		{
			var spritesRoot = Path.join([levelDir, "sprites"]);
			if (!FileSystem.exists(spritesRoot)) FileSystem.createDirectory(spritesRoot);
			if (!existed) FileSystem.createDirectory(dest);

			if (existed)
				for (f in ["sprite.png", "sprite.xml", "sprite.json"])
				{
					var old = Path.join([dest, f]);
					if (FileSystem.exists(old)) FileSystem.deleteFile(old);
				}

			var png:Bytes = image;
			if (isJpg)
			{
				var bmp = BitmapData.fromBytes(image);
				png = cast bmp.encode(bmp.rect, new PNGEncoderOptions());
				bmp.dispose();
			}
			File.saveBytes(Path.join([dest, "sprite.png"]), png);

			if (dataKind == "xml" && dataText != null)
			{
				var destXml = Path.join([dest, "sprite.xml"]);
				File.saveContent(destXml, dataText);

				// Sparrow -> JSON como siempre, pero con el config de nombres del juego: la idle es `anim0`, el resto `anim1..N`
				var configPath = Path.join([dest, "config.json"]);
				if (!FileSystem.exists(configPath))
					File.saveContent(configPath, Json.stringify(sparrowConfig(dataText), null, "\t"));

				var converted = SpriteFolderConverter.convertFile(destXml, true);
				if (!converted.ok) throw Std.string(converted.error);
			}
			else if (dataKind == "json" && dataText != null)
				File.saveContent(Path.join([dest, "sprite.json"]), dataText);
			else
				writeSingleFrame(dest);

			ensureConfig(dest);
			if (!SpriteBuilder.exists(levelDir, name)) throw "no quedo un sprite valido";
			return null;
		}
		catch (e:Dynamic)
		{
			if (!existed) removeDir(dest);
			return Std.string(e);
		}
		#else
		return "importar necesita un target sys";
		#end
	}

	/**
	 * `config.json` inicial de un atlas Sparrow: una entrada por animacion (`anim` = prefijo del atlas; el juego la llama anim<posicion en data>).
	 * La animacion que empieza por "idle" va primero, o sea es `anim0`; el resto sigue el orden del XML.
	 */
	static function sparrowConfig(xmlText:String):Dynamic
	{
		var list = SparrowToAseprite.prefixes(xmlText);
		for (i in 0...list.length)
			if (StringTools.startsWith(StringTools.trim(list[i]).toLowerCase(), "idle"))
			{
				if (i > 0) list.unshift(list.splice(i, 1)[0]);
				break;
			}
		return {
			type: "sprite",
			data: [for (i in 0...list.length) {anim: list[i], spd: 1, loop: true}]
		};
	}

	/**
	 * `config.json` minimo de un sprite recien importado (si ya hay uno, no se toca): `type` y una entrada por animacion con su `anim`
	 * (el tag del atlas), velocidad 1 y loop. La animacion que empieza por "idle" va primera (`anim0`); sin tags es una sola, `anim0`.
	 */
	static function ensureConfig(dest:String):Void
	{
		#if sys
		var configPath = Path.join([dest, "config.json"]);
		if (FileSystem.exists(configPath)) return;

		var tags:Array<String> = [];
		try
		{
			var data = Json.parse(File.getContent(Path.join([dest, "sprite.json"])));
			var meta:Dynamic = Reflect.field(data, "meta");
			var frameTags:Dynamic = meta == null ? null : Reflect.field(meta, "frameTags");
			if (Std.isOfType(frameTags, Array))
				for (tag in (frameTags : Array<Dynamic>))
				{
					var tagName = Reflect.field(tag, "name");
					if (tagName != null && tags.indexOf(Std.string(tagName)) < 0) tags.push(Std.string(tagName));
				}
		}
		catch (e:Dynamic) {}
		if (tags.length == 0) tags.push("anim0");

		for (i in 0...tags.length)
			if (StringTools.startsWith(StringTools.trim(tags[i]).toLowerCase(), "idle"))
			{
				if (i > 0) tags.unshift(tags.splice(i, 1)[0]);
				break;
			}

		var config = {type: "sprite", data: [for (tag in tags) {anim: tag, spd: 1, loop: true}]};
		File.saveContent(configPath, Json.stringify(config, null, "\t"));
		#end
	}

	/** Deja solo letras, numeros, `_` y `-` (los acentos y espacios pasan a `_`). */
	public static function cleanName(base:String):String
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

	/** `sprite.json` (estilo Aseprite) de un PNG suelto: un frame que ocupa toda la imagen y la animacion `anim0` (la idle). */
	static function writeSingleFrame(dest:String):Void
	{
		var size = SpriteFolderConverter.pngSize(Path.join([dest, "sprite.png"]));
		if (size == null) throw "no es un PNG valido";

		var out = {
			frames: [
				{
					filename: "anim0",
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
				frameTags: [{name: "anim0", from: 0, to: 0, direction: "forward"}],
				fmce: {source: "png", animations: {anim0: {fps: 24, loop: true}}}
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
