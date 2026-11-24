package funky.backend;

import haxe.Json;
import haxe.io.Path;
import funky.backend.utils.JsonLoose;
import funky.backend.system.Log;
import funky.backend.converter.VideoSheet;
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
 * Convierte videos de niveles al formato de spritesheet (`sprite.json` + paginas + `config.json` `type: "item"`),
 * usando VideoSheet/FunkFMPEG. Los .mp4 originales se mueven a `source/` dentro del sprite.
 *
 * Si la conversion no es posible (ej. sin ffmpeg/extractor de frames), se normaliza el config como
 * `type: "video"` para que el nivel siga funcionando.
 *
 * Es idempotente: si el sprite ya esta convertido no toca nada. No borra videos originales.
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
		report.videos += files.length;

		// Nuevo formato: video -> spritesheet (sprite.json + paginas). Los .mp4 originales se mueven a source/.
		// Esto elimina la dependencia de hxvlc en el juego y sincroniza el video con el BPM.
		if (VideoSheet.canConvert(dir))
		{
			var job = VideoSheet.start(dir);
			try
			{
				while (job.step()) {}
			}
			catch (e:Dynamic)
			{
				try job.dispose() catch (_:Dynamic) {}
				report.problems.push(label + ": no se pudo convertir a spritesheet (" + Std.string(e) + ")");
				return normalizeVideoConfig(dir, files, label, report);
			}

			if (job.ok)
			{
				for (w in job.warnings) report.problems.push(label + ": " + w);
				report.fixed.push(label + " (video -> spritesheet: " + job.summary + ")");
				return countDataEntries(dir);
			}

			var err = job.error == null ? "sin detalle" : job.error;
			report.problems.push(label + ": no se pudo convertir a spritesheet (" + err + ")");
			// Si no se pudo convertir (ej. sin ffmpeg/frame extractor), se deja como video normalizado para que siga funcionando.
			return normalizeVideoConfig(dir, files, label, report);
		}

		// Ya es spritesheet o no se puede convertir: normalizar config de video por compatibilidad.
		return normalizeVideoConfig(dir, files, label, report);
	}

	static function countDataEntries(dir:String):Int
	{
		var configPath = Path.join([dir, "config.json"]);
		if (!FileSystem.exists(configPath)) return 0;
		try
		{
			var config:Dynamic = JsonLoose.parse(File.getContent(configPath));
			var data:Dynamic = config == null ? null : Reflect.field(config, "data");
			if (Std.isOfType(data, Array)) return (cast data:Array<Dynamic>).length;
		}
		catch (_:Dynamic) {}
		return 0;
	}

	/** Fallback: mantiene el sprite como `type: "video"` (formato viejo) para que el nivel siga funcionando. */
	public static function normalizeVideoConfig(dir:String, files:Array<String>, label:String, report:LevelVideoReport):Int
	{
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

		for (file in files)
		{
			var path = Path.join([dir, file]);
			Mp4Info.forget(path);
			var size = Mp4Info.size(path);
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
