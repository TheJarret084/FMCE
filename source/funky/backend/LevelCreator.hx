package funky.backend;

import haxe.Json;
import haxe.io.Path;
import funky.core.Log;
import funky.core.Paths;
#if sys
import haxe.zip.Reader;
import sys.FileSystem;
import sys.io.File;
#end

typedef CreateResult =
{
	var ok:Bool;
	var folder:String;
	var name:String;
	var error:String;
}

/**
 * Crea un nivel nuevo: carpeta `<nombre>_<id base64 del timestamp>`, meta.json con el nombre que se ve y la plantilla de
 * assets/included (chart.json, events.json, scene.json y los sprites de default.zip).
 */
class LevelCreator
{
	public static inline var TEMPLATE_DIR:String = "assets/included/";

	public static function create(displayName:String, withSprites:Bool = true):CreateResult
	{
		var name = displayName == null ? "" : StringTools.trim(displayName);
		if (name == "") return fail("Escribe un nombre para el nivel");
		if (name.length > 60) name = name.substr(0, 60);

		#if sys
		var root = Paths.levelsRoot();
		var folder = LevelId.freshFolder(root, name);
		var target = Path.join([root, folder]);
		var stamp = LevelId.stampOf(folder);

		try
		{
			ensureDir(target);

			// 1) Plantilla suelta (vacio si no esta en assets).
			writeTemplate(target, "chart.json", "{\n  \"strumLines\": [\n    [],\n    []\n  ]\n}");
			writeTemplate(target, "events.json", "{\n  \"events\": [],\n  \"action_packs\": []\n}");
			writeTemplate(target, "scene.json", null);

			// 2) Nivel de ejemplo: escenario, eventos y sprites (los de arriba se pisan si el zip los trae).
			if (withSprites) extractTemplateZip(target, TEMPLATE_DIR + "default.zip");

			// 3) meta.json: el nombre que se ve es el que escribio la persona.
			var meta:Dynamic = {
				displayName: name,
				bpm: 120,
				stage: "scene",
				lanes: 4,
				validScore: true
			};
			Reflect.setField(meta, "id", LevelId.encode(stamp));
			Reflect.setField(meta, "created", LevelId.stampText(stamp));
			File.saveContent(Path.join([target, "meta.json"]), Json.stringify(meta, null, "  "));
		}
		catch (e:Dynamic)
		{
			removeDir(target);
			Log.warn('[LevelCreator] no se pudo crear ' + folder + ': ' + e);
			return fail("No se pudo crear el nivel: " + Std.string(e));
		}

		Log.info('[LevelCreator] nivel creado: "' + name + '" -> ' + folder);
		return {ok: true, folder: folder, name: name, error: ""};
		#else
		return fail("Crear niveles necesita un target con archivos (sys)");
		#end
	}

	static function fail(error:String):CreateResult
		return {ok: false, folder: "", name: "", error: error};

	#if sys
	static function assetText(path:String):Null<String>
	{
		try
		{
			if (openfl.utils.Assets.exists(path)) return openfl.utils.Assets.getText(path);
			if (FileSystem.exists(path)) return File.getContent(path);
		}
		catch (e:Dynamic) {}
		return null;
	}

	static function assetBytes(path:String):Null<haxe.io.Bytes>
	{
		try
		{
			if (openfl.utils.Assets.exists(path)) return openfl.utils.Assets.getBytes(path);
			if (FileSystem.exists(path)) return File.getBytes(path);
		}
		catch (e:Dynamic) {}
		return null;
	}

	static function writeTemplate(target:String, file:String, fallback:Null<String>):Void
	{
		var text = assetText(TEMPLATE_DIR + file);
		if (text == null) text = fallback;
		if (text != null) File.saveContent(Path.join([target, file]), text);
	}

	static function extractTemplateZip(target:String, assetPath:String):Void
	{
		var bytes = assetBytes(assetPath);
		if (bytes == null)
		{
			Log.info('[LevelCreator] sin ' + assetPath + ': el nivel queda vacio');
			return;
		}
		var entries = Reader.readZip(new haxe.io.BytesInput(bytes));
		for (entry in entries)
		{
			var name = StringTools.replace(entry.fileName, "\\", "/");
			if (StringTools.endsWith(name, "/") || name.indexOf("..") >= 0 || StringTools.startsWith(name, "/")) continue;
			var dest = Path.join([target, name]);
			ensureDir(Path.directory(dest));
			File.saveBytes(dest, Reader.unzip(entry));
		}
	}

	static function ensureDir(dir:String):Void
	{
		if (dir == null || dir == "" || dir == "." || FileSystem.exists(dir)) return;
		ensureDir(Path.directory(dir));
		FileSystem.createDirectory(dir);
	}

	static function removeDir(dir:String):Void
	{
		try
		{
			if (!FileSystem.exists(dir)) return;
			for (entry in FileSystem.readDirectory(dir))
			{
				var path = dir + "/" + entry;
				if (FileSystem.isDirectory(path)) removeDir(path);
				else FileSystem.deleteFile(path);
			}
			FileSystem.deleteDirectory(dir);
		}
		catch (e:Dynamic) {}
	}
	#end
}
