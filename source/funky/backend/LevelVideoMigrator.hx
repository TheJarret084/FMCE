package funky.backend;

import haxe.Json;
import haxe.io.Path;
import funky.core.JsonLoose;
import funky.core.Log;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Resultado de revisar/migrar los videos de un nivel. */
typedef LevelVideoReport =
{
	var dir:String;
	/** .mp4 encontrados en las carpetas de sprites. */
	var videos:Int;
	/** Cosas que se normalizaron (para el checker). */
	var fixed:Array<String>;
	/** Videos rotos o configs que no se pudieron arreglar. */
	var problems:Array<String>;
}

/**
 * Migra los niveles viejos al sistema de video actual (`sprites/<nombre>/` con `config.json` `type: "video"` y una
 * entrada `data[]` por video, `anim` = nombre del .mp4 sin extension).
 *
 * - Empareja cada entrada de `config.json` con un .mp4 real (arregla nombres cambiados, por ejemplo `tungazo` -> `tungaso`).
 * - Agrega las entradas que falten para los .mp4 que no esten en `data`.
 * - Deja explicito el indice `video` de los objetos de `scene.json` que usan un sprite de video.
 * - Revisa cada .mp4 con `Mp4Info` (igual que el checker de addons): si no tiene header valido, lo reporta como problema.
 *
 * Es idempotente: si el nivel ya esta bien no escribe nada. No borra videos ni cambia offsets/escalas/loops existentes.
 */
class LevelVideoMigrator
{
	public static function scanAll(levelsRoot:String):Array<LevelVideoReport>
	{
		var out:Array<LevelVideoReport> = [];
		#if sys
		levelsRoot = Path.removeTrailingSlashes(levelsRoot);
		if (!FileSystem.exists(levelsRoot) || !FileSystem.isDirectory(levelsRoot)) return out;

		for (entry in FileSystem.readDirectory(levelsRoot))
		{
			if (entry == null || entry == "" || entry.charAt(0) == ".") continue;
			var dir = Path.join([levelsRoot, entry]);
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;

			var report = scanLevel(dir);
			if (report.videos > 0 || report.fixed.length > 0 || report.problems.length > 0) out.push(report);
		}
		#end
		return out;
	}

	public static function scanLevel(levelDir:String):LevelVideoReport
	{
		var report:LevelVideoReport = {dir: levelDir, videos: 0, fixed: [], problems: []};
		#if sys
		levelDir = Path.removeTrailingSlashes(levelDir);
		var spritesRoot = Path.join([levelDir, "sprites"]);
		if (!FileSystem.exists(spritesRoot) || !FileSystem.isDirectory(spritesRoot)) return report;

		var label = Path.withoutDirectory(levelDir);
		var videoDirs = new Map<String, Int>();

		for (entry in FileSystem.readDirectory(spritesRoot))
		{
			var dir = Path.join([spritesRoot, entry]);
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;

			var count = migrateSprite(dir, label, report);
			if (count > 0) videoDirs.set(entry, count);
		}

		if (videoDirs.keys().hasNext()) migrateScene(levelDir, label, videoDirs, report);
		#end
		return report;
	}

	#if sys
	static function migrateSprite(dir:String, levelLabel:String, report:LevelVideoReport):Int
	{
		var files = FunkinVideoSprite.videoFiles(dir);
		if (files.length == 0) return 0;

		var name = Path.withoutDirectory(dir);
		var label = levelLabel + "/sprites/" + name;
		var configPath = Path.join([dir, "config.json"]);
		var config:Dynamic = null;

		if (FileSystem.exists(configPath))
		{
			try
			{
				config = JsonLoose.parse(File.getContent(configPath));
			}
			catch (e:Dynamic)
			{
				report.problems.push(label + ": config.json ilegible (" + Std.string(e) + ")");
			}
		}

		var changed = false;
		if (config == null || !Reflect.isObject(config))
		{
			config = {};
			changed = true;
		}

		if (text(Reflect.field(config, "type")) != "video")
		{
			Reflect.setField(config, "type", "video");
			changed = true;
		}

		var data:Array<Dynamic> = null;
		var rawData = Reflect.field(config, "data");
		if (Std.isOfType(rawData, Array)) data = cast rawData;
		else
		{
			data = [];
			Reflect.setField(config, "data", data);
			changed = true;
		}

		var used = new Map<Int, Bool>();
		var assigned:Array<Int> = [for (_ in data) -1];

		// 1) Lo que ya apunta a un .mp4 existente se respeta (aunque el nombre tenga distinta capitalizacion o .mp4).
		for (i in 0...data.length)
		{
			var entry = data[i];
			if (!Reflect.isObject(entry))
			{
				entry = {};
				data[i] = entry;
				changed = true;
			}

			var fileIndex = findVideo(files, text(Reflect.field(entry, "anim")));
			if (fileIndex >= 0 && !used.exists(fileIndex))
			{
				assigned[i] = fileIndex;
				used.set(fileIndex, true);
			}
		}

		// 2) Entradas sin video: se les asigna el primer .mp4 libre. Si el archivo se llamaba distinto se corrige `anim`.
		for (i in 0...data.length)
		{
			if (assigned[i] < 0)
				for (f in 0...files.length)
					if (!used.exists(f))
					{
						assigned[i] = f;
						used.set(f, true);
						break;
					}

			if (assigned[i] < 0)
			{
				var anim = text(Reflect.field(data[i], "anim"));
				report.problems.push(label + ": la animacion \"" + (anim == "" ? "?" : anim) + "\" no tiene un .mp4");
				continue;
			}

			var wanted = baseName(files[assigned[i]]);
			if (text(Reflect.field(data[i], "anim")) != wanted)
			{
				Reflect.setField(data[i], "anim", wanted);
				changed = true;
			}
		}

		// 3) .mp4 que no estaban en data: se agregan al final, copiando loop/escala/offset de la primera animacion.
		var template:Dynamic = data.length > 0 ? data[0] : null;
		for (f in 0...files.length)
		{
			if (used.exists(f)) continue;

			var entry:Dynamic = {anim: baseName(files[f])};
			copyField(entry, template, "loop");
			copyField(entry, template, "scale");
			copyField(entry, template, "offset");
			copyField(entry, template, "spd");
			copyField(entry, template, "spd_fps");
			if (Reflect.field(entry, "loop") == null) Reflect.setField(entry, "loop", true);

			data.push(entry);
			used.set(f, true);
			changed = true;
		}

		if (changed)
		{
			try
			{
				File.saveContent(configPath, Json.stringify(config, null, "  "));
				report.fixed.push(label + " (config de video normalizado)");
			}
			catch (e:Dynamic)
			{
				report.problems.push(label + ": no se pudo guardar config.json (" + Std.string(e) + ")");
			}
		}

		// 4) Validacion de los .mp4 (header/moov) con el mismo lector que usa el checker de addons.
		for (file in files)
		{
			var path = Path.join([dir, file]);
			Mp4Info.forget(path);
			var size = Mp4Info.size(path);
			report.videos++;
			if (size == null) report.problems.push(label + "/" + file + ": el video esta corrupto o incompleto");
		}

		return data.length;
	}

	static function migrateScene(levelDir:String, levelLabel:String, videoDirs:Map<String, Int>, report:LevelVideoReport):Void
	{
		var scenePath = Path.join([levelDir, "scene.json"]);
		if (!FileSystem.exists(scenePath))
		{
			report.problems.push(levelLabel + ": hay videos en sprites/ pero no hay scene.json");
			return;
		}

		var scene:Dynamic = null;
		try
		{
			scene = JsonLoose.parse(File.getContent(scenePath));
		}
		catch (e:Dynamic)
		{
			report.problems.push(levelLabel + ": scene.json ilegible (" + Std.string(e) + ")");
			return;
		}

		if (scene == null || !Reflect.isObject(scene)) return;
		var objects = Reflect.field(scene, "objects");
		if (!Std.isOfType(objects, Array)) return;

		var changed = false;
		for (item in (cast objects:Array<Dynamic>))
		{
			if (item == null || !Reflect.isObject(item)) continue;

			var sprite = text(Reflect.field(item, "spr"));
			if (sprite == "" || !videoDirs.exists(sprite)) continue;

			var count = videoDirs.get(sprite);
			var index = Std.int(Math.max(0, Math.min(count - 1, number(Reflect.field(item, "video"), 0))));

			if (Std.int(number(Reflect.field(item, "video"), -1)) != index)
			{
				Reflect.setField(item, "video", index);
				changed = true;
			}
		}

		if (!changed) return;

		try
		{
			File.saveContent(scenePath, Json.stringify(scene, null, "  "));
			report.fixed.push(levelLabel + " (scene.json: indice de video)");
		}
		catch (e:Dynamic)
		{
			report.problems.push(levelLabel + ": no se pudo guardar scene.json (" + Std.string(e) + ")");
		}
	}

	static function findVideo(files:Array<String>, anim:String):Int
	{
		var wanted = baseName(Path.withoutDirectory(anim == null ? "" : anim)).toLowerCase();
		if (wanted == "") return -1;

		for (i in 0...files.length)
			if (baseName(files[i]).toLowerCase() == wanted) return i;
		return -1;
	}

	static function baseName(file:String):String
	{
		if (file == null) return "";
		var name = Path.withoutExtension(Path.withoutDirectory(file));
		return StringTools.replace(name, "\\", "/");
	}

	static function copyField(to:Dynamic, from:Dynamic, field:String):Void
	{
		if (to == null || from == null || Reflect.field(to, field) != null) return;
		var value = Reflect.field(from, field);
		if (value == null) return;

		if (Std.isOfType(value, Array))
			Reflect.setField(to, field, (cast value:Array<Dynamic>).copy());
		else if (Reflect.isObject(value))
			Reflect.setField(to, field, Reflect.copy(value));
		else
			Reflect.setField(to, field, value);
	}

	static function text(value:Dynamic):String
		return value == null ? "" : StringTools.trim(Std.string(value));

	static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
	#end
}
