package funky.backend;

import haxe.Json;
import haxe.io.Path;
import haxe.io.Bytes;
import funky.backend.system.Log;
import funky.backend.assets.Paths;
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

/** Opciones de la ventana NUEVO NIVEL (todas menos el nombre tienen valor por defecto). */
typedef CreateOptions =
{
	/** Nombre interno de la cancion (se usa para el chart y la carpeta). */
	var ?songName:String;
	/** Nombre visible en el menu. Se mantiene obligatorio para compatibilidad con el creador anterior. */
	var displayName:String;
	var ?bpm:Float;
	var ?beatsPerMeasure:Int;
	var ?stepsPerBeat:Int;
	var ?lanes:Int;
	var ?stage:String;
	var ?withSprites:Bool;
	var ?icon:String;
	var ?color:String;
	var ?difficulties:Array<String>;
	var ?opponentModeAllowed:Bool;
	var ?coopAllowed:Bool;
	var ?instrumentalBytes:Bytes;
	var ?instrumentalPath:String;
	var ?voicesBytes:Bytes;
	var ?voicesPath:String;
}

/**
 * Crea un nivel nuevo: carpeta `<nombre>_<id base64 del timestamp>`, meta.json con el nombre que se ve y la plantilla de
 * assets/included (chart.json, events.json, scene.json y los sprites de default.zip).
 *
 * Ademas, de vez en cuando copia una imagen de `assets/included/` a `<nivel>/eastereggs/` (LevelEasterEggs).
 */
class LevelCreator
{
	public static inline var TEMPLATE_DIR:String = "assets/included/";

	public static inline var DEFAULT_BPM:Float = 120;
	public static inline var DEFAULT_LANES:Int = 4;
	public static inline var DEFAULT_STAGE:String = "scene";

	/** Version corta que siguen usando los llamados viejos. */
	public static function create(displayName:String, withSprites:Bool = true):CreateResult
	{
		return createWithOptions({displayName: displayName, withSprites: withSprites});
	}

	public static function createWithOptions(options:CreateOptions):CreateResult
	{
		var displayName = options == null || options.displayName == null ? "" : StringTools.trim(options.displayName);
		var songName = options != null && options.songName != null ? StringTools.trim(options.songName) : displayName;
		if (songName == "") songName = displayName;
		if (displayName == "") displayName = songName;
		if (songName == "") return fail("Escribe un nombre para la cancion");
		if (songName.length > 60) songName = songName.substr(0, 60);
		if (displayName.length > 60) displayName = displayName.substr(0, 60);

		var bpm = options != null && options.bpm != null && !Math.isNaN(options.bpm) && options.bpm > 0 ? options.bpm : DEFAULT_BPM;
		if (bpm > 1000) bpm = 1000;

		var beatsPerMeasure = options != null && options.beatsPerMeasure != null ? Std.int(options.beatsPerMeasure) : 4;
		beatsPerMeasure = Std.int(Math.max(1, Math.min(32, beatsPerMeasure)));

		var stepsPerBeat = options != null && options.stepsPerBeat != null ? Std.int(options.stepsPerBeat) : 4;
		stepsPerBeat = Std.int(Math.max(1, Math.min(16, stepsPerBeat)));

		var lanes = options != null && options.lanes != null ? Std.int(options.lanes) : DEFAULT_LANES;
		lanes = Std.int(Math.max(1, Math.min(9, lanes)));

		var stage = options != null && options.stage != null ? StringTools.trim(options.stage) : DEFAULT_STAGE;
		if (stage == "") stage = DEFAULT_STAGE;

		var withSprites = options == null || options.withSprites == null ? true : options.withSprites;
		var icon = options != null && options.icon != null ? StringTools.trim(options.icon) : "";
		var color = options != null && options.color != null && StringTools.trim(options.color) != "" ? StringTools.trim(options.color) : "#9271FD";
		var difficulties = cleanDifficulties(options == null ? null : options.difficulties);
		var opponentModeAllowed = options != null && options.opponentModeAllowed == true;
		var coopAllowed = options != null && options.coopAllowed == true;
		var instrumentalBytes = options == null ? null : options.instrumentalBytes;
		var instrumentalPath = options == null ? null : options.instrumentalPath;
		var voicesBytes = options == null ? null : options.voicesBytes;
		var voicesPath = options == null ? null : options.voicesPath;
		if (instrumentalBytes != null && instrumentalBytes.length == 0) return fail("El archivo instrumental está vacío");
		if (voicesBytes != null && voicesBytes.length == 0) return fail("El archivo de voces está vacío");

		#if sys
		var root = Paths.levelsRoot();
		var folder = LevelId.freshFolder(root, songName);
		var target = Path.join([root, folder]);
		var stamp = LevelId.stampOf(folder);

		try
		{
			ensureDir(target);

			// Plantilla base: cualquier chart que traiga default.zip se conserva, pero se actualizan sus datos principales.
			writeTemplate(target, "chart.json", "{\n  \"strumLines\": [\n    [],\n    []\n  ]\n}");
			writeTemplate(target, "events.json", "{\n  \"events\": [],\n  \"action_packs\": []\n}");
			writeTemplate(target, "scene.json", null);
			if (withSprites) extractTemplateZip(target, TEMPLATE_DIR + "default.zip");

			// El formato de FMCE usa meta.json + chart.json, sin la estructura de carpetas de Codename.
			var instFile:String = null;
			var voicesFile:String = null;
			if (instrumentalBytes != null)
			{
				instFile = "music/Inst." + audioExtension(instrumentalPath);
				var musicDir = Path.join([target, "music"]);
				ensureDir(musicDir);
				File.saveBytes(Path.join([target, instFile]), instrumentalBytes);
			}
			if (voicesBytes != null)
			{
				voicesFile = "music/Voices." + audioExtension(voicesPath);
				var musicDir = Path.join([target, "music"]);
				ensureDir(musicDir);
				File.saveBytes(Path.join([target, voicesFile]), voicesBytes);
			}

			writeNewChart(target, songName);

			var meta:Dynamic = {
				displayName: displayName,
				songName: songName,
				bpm: bpm,
				beatsPerMeasure: beatsPerMeasure,
				stepsPerBeat: stepsPerBeat,
				stage: stage,
				lanes: lanes,
				validScore: true,
				difficulties: difficulties,
				opponentModeAllowed: opponentModeAllowed,
				coopAllowed: coopAllowed,
				needsVoices: voicesBytes != null,
				icon: icon,
				color: color
			};
			if (instFile != null) Reflect.setField(meta, "song", instFile);
			if (voicesFile != null) Reflect.setField(meta, "voices", voicesFile);
			if (icon != "") Reflect.setField(meta, "icons", {P2: icon});
			Reflect.setField(meta, "id", LevelId.encode(stamp));
			Reflect.setField(meta, "created", LevelId.stampText(stamp));
			File.saveContent(Path.join([target, "meta.json"]), Json.stringify(meta, null, "  "));

			// Migracion inmediata para videos que vengan en default.zip; el Checker vuelve a revisar todos los niveles al arrancar.
			try
			{
				var videoReport = LevelVideoMigrator.scanLevel(target);
				for (line in videoReport.fixed) Log.info('[LevelCreator] video migrado: ' + line);
				for (line in videoReport.problems) Log.warn('[LevelCreator] video: ' + line);
			}
			catch (e:Dynamic)
			{
				Log.warn('[LevelCreator] no se pudo revisar los videos de la plantilla: ' + e);
			}

			// Detalle aleatorio: 5% de probabilidad de copiar una imagen de assets/included dentro del nivel.
			try
			{
				LevelEasterEggs.maybeCopy(target);
			}
			catch (e:Dynamic)
			{
				Log.warn('[LevelCreator] no se pudo copiar el easter egg: ' + e);
			}
		}
		catch (e:Dynamic)
		{
			removeDir(target);
			Log.warn('[LevelCreator] no se pudo crear ' + folder + ': ' + e);
			return fail("No se pudo crear el nivel: " + Std.string(e));
		}

		Log.info('[LevelCreator] nivel creado: "' + displayName + '" (' + songName + ') -> ' + folder);
		return {ok: true, folder: folder, name: displayName, error: ""};
		#else
		return fail("Crear niveles necesita un target con archivos (sys)");
		#end
	}

	static function cleanDifficulties(values:Null<Array<String>>):Array<String>
	{
		var out:Array<String> = [];
		if (values != null)
			for (value in values)
			{
				if (value == null) continue;
				var clean = StringTools.trim(value);
				if (clean != "" && out.indexOf(clean) < 0) out.push(clean);
			}
		if (out.length == 0) out.push("normal");
		return out;
	}

	static function audioExtension(path:Null<String>):String
	{
		if (path == null) return "ogg";
		var ext = Path.extension(path).toLowerCase();
		return switch (ext)
		{
			case "ogg" | "mp3" | "wav" | "m4a": ext;
			default: "ogg";
		};
	}

	static function fail(error:String):CreateResult
		return {ok: false, folder: "", name: "", error: error};

	#if sys


	static function writeNewChart(target:String, songName:String):Void
	{
		var path = Path.join([target, "chart.json"]);
		var chart:Dynamic = {};
		if (FileSystem.exists(path))
			try chart = funky.backend.utils.JsonLoose.parse(File.getContent(path)) catch (e:Dynamic) chart = {};
		if (chart == null || !Reflect.isObject(chart) || Std.isOfType(chart, Array)) chart = {};

		if (!Std.isOfType(Reflect.field(chart, "strumLines"), Array))
			Reflect.setField(chart, "strumLines", [[], []]);
		Reflect.setField(chart, "name", songName);
		// El BPM y el compas viven en meta.json en el formato nativo de FMCE.
		// Quitamos copias de la plantilla para que no oculten cambios posteriores del metadata editor.
		for (field in ["bpm", "npb", "beatsPerMeasure"]) Reflect.deleteField(chart, field);
		Reflect.setField(chart, "timeUnit", "seconds");
		Reflect.setField(chart, "fmceChart", true);
		File.saveContent(path, Json.stringify(chart, null, "  "));
	}

	static function writeTemplate(target:String, file:String, fallback:Null<String>):Void
	{
		var text = CoolUtil.assetText(TEMPLATE_DIR + file);
		if (text == null) text = fallback;
		if (text != null) File.saveContent(Path.join([target, file]), text);
	}

	static function extractTemplateZip(target:String, assetPath:String):Void
	{
		var bytes = CoolUtil.assetBytes(assetPath);
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
