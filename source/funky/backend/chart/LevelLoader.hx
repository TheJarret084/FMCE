package funky.backend.chart;

import haxe.Json;
import haxe.io.Path;
import funky.core.Log;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Carga un chart para jugarlo desde cualquiera de las fuentes que entiende el motor. */
class LevelLoader
{
	public static function isArchive(path:String):Bool
		return StringTools.endsWith(path.toLowerCase(), ".fnmm");

	public static function loadAny(path:String):FNMMChart
	{
		#if sys
		return isArchive(path) ? FNMMLoader.load(path) : loadFolder(path);
		#else
		throw "Level loading requires a sys target";
		#end
	}

	/** Notas del nivel. Es la unica dificultad base: la dificultad del juego es la velocidad (`Difficulty`). */
	public static inline var CHART_FILE:String = "chart.json";

	#if sys
	public static function loadFolder(dir:String):FNMMChart
	{
		if (!FileSystem.exists(dir)) throw 'level folder not found: $dir';

		var chartPath = Path.join([dir, CHART_FILE]);
		if (!FileSystem.exists(chartPath)) throw 'level folder has no chart.json: $dir';

		var chart:Dynamic = parseObject(File.getContent(chartPath), chartPath);
		var meta:Dynamic = readMeta(dir);

		var name = text(Reflect.field(chart, "name"), "");
		if (name == "") name = text(Reflect.field(meta, "displayName"), "");
		if (name == "") name = text(Reflect.field(meta, "levelName"), "");
		if (name == "") name = text(Reflect.field(meta, "songName"), "");
		if (name == "") name = Path.withoutDirectory(Path.removeTrailingSlashes(dir));

		var bpm:Float = number(Reflect.field(chart, "bpm"), number(Reflect.field(meta, "bpm"), 120));
		if (bpm <= 0) bpm = 120;

		// chart.json: `strumLines` = una lista de notas `{time, lane, length}` por strumline.
		// 0 = jugador, 1 = oponente, 2+ = extras (CPU, cada una con sus notas, sin mezclar).
		var strumLines = Reflect.field(chart, "strumLines");
		if (!Std.isOfType(strumLines, Array)) throw 'chart.json de $dir no tiene "strumLines"';

		var notes:Array<FNMMNote> = [];
		var unit = text(Reflect.field(chart, "timeUnit"), text(Reflect.field(meta, "timeUnit"), "seconds"));
		var factor = unitToMs(unit, bpm);
		var lines:Array<Dynamic> = cast strumLines;
		for (index in 0...lines.length)
		{
			if (!Std.isOfType(lines[index], Array)) continue;
			for (item in (cast lines[index]:Array<Dynamic>)) appendNote(notes, item, factor, index);
		}

		var offset = number(Reflect.field(meta, "offset"), 0);
		var highest = 0;
		for (note in notes)
		{
			note.time += offset;
			if (note.lane > highest) highest = note.lane;
		}
		notes.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));

		var declaredLanes = Std.int(number(Reflect.field(meta, "lanes"), 0));
		var laneCount = declaredLanes > 0 ? declaredLanes : Std.int(Math.max(4, highest + 1));
		if (laneCount > 9) laneCount = 9;

		var icons = Reflect.field(meta, "icons");
		var iconPlayer:Null<String> = icons != null ? nullableText(Reflect.field(icons, "P1")) : null;
		var iconOpponent:Null<String> = icons != null ? nullableText(Reflect.field(icons, "P2")) : null;
		if (iconPlayer == null && iconOpponent == null)
		{
			// Sin `icons` en meta.json: scene.json lista [oponente, jugador] (asi sale en levels/ferti).
			var sceneIcons = readSceneIcons(dir);
			if (sceneIcons.length > 0) iconOpponent = sceneIcons[0];
			if (sceneIcons.length > 1) iconPlayer = sceneIcons[1];
		}

		var events = readEvents(dir);
		var actionPacks = readActionPacks(dir);
		var music = findMusic(dir, Reflect.field(meta, "song"));
		var voices = findVoices(dir, "", Reflect.field(meta, "voices"));
		// Pasos por beat: meta.json manda; si no, el `npb` del chart (asi sale en el data.json de un .fnmm).
		var stepsPerBeat = number(Reflect.field(meta, "stepsPerBeat"), number(Reflect.field(chart, "npb"), 4));
		if (stepsPerBeat <= 0) stepsPerBeat = 4;

		// Sparrow -> Aseprite: cubre niveles hechos a mano o viejos. Solo escribe los .json que faltan.
		for (converted in funky.backend.converter.SpriteFolderConverter.convertTree(Path.join([dir, "sprites"]), false))
			if (!converted.ok) Log.warn('[LevelLoader] sprite ' + converted.xml + ': ' + converted.error);

		Log.info('[LevelLoader] ' + name + ' ' + notes.length + ' notes, ' + laneCount + ' lanes, ' + bpm + ' bpm' + (music == null ? ' (silent)' : ''));
		return {
			name: name,
			bpm: bpm,
			notes: notes,
			events: events,
			musicPath: music,
			voicesPath: voices,
			levelDir: dir,
			laneCount: laneCount,
			iconPlayer: iconPlayer,
			iconOpponent: iconOpponent,
			stepsPerBeat: stepsPerBeat,
			actionPacks: actionPacks,
			stage: nullableText(Reflect.field(meta, "stage")),
			color: nullableText(Reflect.field(meta, "color"))
		};
	}

	/** Milisegundos que dura una unidad de tiempo del chart. */
	static function unitToMs(unit:String, bpm:Float):Float
	{
		return switch (unit.toLowerCase())
		{
			case "beats" | "beat": 60000 / bpm;
			case "seconds" | "second" | "s": 1000;
			case "steps" | "step": 60000 / bpm / 4;
			default: 1;
		};
	}

	static function parseObject(raw:String, path:String):Dynamic
	{
		var parsed:Dynamic = null;
		try parsed = funky.core.JsonLoose.parse(raw) catch (e:Dynamic) throw 'JSON invalido en $path: ' + Std.string(e);
		if (parsed == null || !Reflect.isObject(parsed)) throw '$path no contiene un objeto JSON';
		return parsed;
	}

	static function readMeta(dir:String):Dynamic
	{
		var path = Path.join([dir, "meta.json"]);
		if (!FileSystem.exists(path)) return {};
		try
		{
			var parsed:Dynamic = funky.core.JsonLoose.parse(File.getContent(path));
			return Reflect.isObject(parsed) ? parsed : {};
		}
		catch (e:Dynamic)
		{
			Log.warn('[LevelLoader] unreadable meta.json in ' + dir);
			return {};
		}
	}

	/**
	 * Nombre del icono del oponente de un nivel sin cargar el chart (para Freeplay): `meta.json` > icons.P2,
	 * o el primero de `scene.json` > icons. null si el nivel no trae.
	 */
	public static function opponentIcon(dir:String):Null<String>
	{
		var icons = Reflect.field(readMeta(dir), "icons");
		var name:Null<String> = icons != null ? nullableText(Reflect.field(icons, "P2")) : null;
		if (name == null)
		{
			var fromScene = readSceneIcons(dir);
			if (fromScene.length > 0) name = nullableText(fromScene[0]);
		}
		return name;
	}

	static function readSceneIcons(dir:String):Array<String>
	{
		var path = Path.join([dir, "scene.json"]);
		if (!FileSystem.exists(path)) return [];
		try
		{
			var parsed:Dynamic = funky.core.JsonLoose.parse(File.getContent(path));
			var list = parsed == null ? null : Reflect.field(parsed, "icons");
			if (!Std.isOfType(list, Array)) return [];
			return [for (item in (cast list:Array<Dynamic>)) text(item, "")];
		}
		catch (e:Dynamic)
		{
			return [];
		}
	}

	/** Eventos globales: `events.json` = `{events: [{time, actions}], action_packs: [{actions}]}`. */
	static function readEvents(dir:String):Array<Dynamic>
	{
		var parsed = readEventsFile(dir);
		var list = parsed == null ? null : Reflect.field(parsed, "events");
		return Std.isOfType(list, Array) ? cast list : [];
	}

	/** `action_packs` de events.json: cada pack es la lista de `actions` que corre un `RunActionPack`. */
	static function readActionPacks(dir:String):Array<Array<Dynamic>>
	{
		var out:Array<Array<Dynamic>> = [];
		var parsed = readEventsFile(dir);
		var packs = parsed == null ? null : Reflect.field(parsed, "action_packs");
		if (!Std.isOfType(packs, Array)) return out;
		for (pack in (cast packs:Array<Dynamic>))
		{
			var actions = pack == null ? null : Reflect.field(pack, "actions");
			out.push(Std.isOfType(actions, Array) ? cast actions : []);
		}
		return out;
	}

	static function readEventsFile(dir:String):Dynamic
	{
		var path = Path.join([dir, "events.json"]);
		if (!FileSystem.exists(path)) return null;
		try
		{
			var parsed:Dynamic = funky.core.JsonLoose.parse(File.getContent(path));
			return Reflect.isObject(parsed) && !Std.isOfType(parsed, Array) ? parsed : null;
		}
		catch (e:Dynamic)
		{
			Log.warn('[LevelLoader] events.json ilegible en ' + dir + ': ' + Std.string(e));
			return null;
		}
	}

	static function findMusic(dir:String, declared:Dynamic):Null<String>
	{
		var relative = declared == null ? "" : Std.string(declared);
		if (relative == "null") relative = "";
		var folders = [Path.join([dir, "music"]), dir];

		// 1) lo que declara meta.song, buscado primero dentro de music/ y luego en la raiz
		if (relative != "")
			for (folder in folders)
			{
				var path = Path.join([folder, relative]);
				if (FileSystem.exists(path)) return path;
			}

		// Preferido: <nivel>/music/music.ogg. Respaldo: los mismos nombres en la raiz del nivel (niveles viejos).
		var names = ["music.ogg", "inst.ogg", "song.ogg", "music.mp3", "music.wav", "music.m4a"];
		for (folder in folders)
			for (name in names)
				if (FileSystem.exists(Path.join([folder, name]))) return Path.join([folder, name]);
		return null;
	}

	/**
	 * Voces separadas (opcional): <nivel>/music/Voices.ogg, o Voices<suffix>.ogg para strumlines con voces propias.
	 * Respaldo: la raiz del nivel. `declared` (meta.voices) manda si existe y no hay suffix. null = sin voces.
	 */
	public static function findVoices(dir:String, ?suffix:String, ?declared:Dynamic):Null<String>
	{
		if (suffix == null) suffix = "";
		if (suffix == "" && declared != null)
		{
			var relative = Std.string(declared);
			if (relative != "" && relative != "null" && FileSystem.exists(Path.join([dir, relative])))
				return Path.join([dir, relative]);
		}
		for (folder in [Path.join([dir, "music"]), dir])
			for (base in ["Voices", "voices"])
				for (ext in ["ogg", "mp3", "wav", "m4a"])
				{
					var path = Path.join([folder, base + suffix + "." + ext]);
					if (FileSystem.exists(path)) return path;
				}
		return null;
	}

	/**
	 * Carga un audio desde disco. `FlxG.sound.playMusic("ruta")` solo entiende assets
	 * empaquetados en OpenFL, no archivos sueltos, asi que hay que armar el Sound a mano.
	 */
	public static function loadSound(path:String):Null<openfl.media.Sound>
	{
		try
		{
			return openfl.media.Sound.fromFile(path);
		}
		catch (e:Dynamic)
		{
			Log.error('[LevelLoader] no se pudo cargar el audio ' + path + ': ' + Std.string(e));
			return null;
		}
	}
	#end

	/**
	 * @param factor ms por unidad de tiempo del chart.
	 * @param line   strumline a la que pertenece (el indice dentro de `strumLines`).
	 */
	static function appendNote(out:Array<FNMMNote>, value:Dynamic, factor:Float, line:Int):Void
	{
		if (!Reflect.isObject(value) || Std.isOfType(value, Array)) return;
		var lane = Std.int(number(Reflect.field(value, "lane"), 0));
		if (lane < 0) return;
		var length = number(Reflect.field(value, "length"), 0);
		out.push({
			time: number(Reflect.field(value, "time"), 0) * factor,
			lane: lane,
			length: length > 0 ? length * factor : 0,
			mustPress: line == 0,
			line: line
		});
	}

	static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	/** Std.string(null) is "null", so a missing field has to be caught before the cast. */
	static function text(value:Dynamic, fallback:String):String
	{
		if (value == null) return fallback;
		var parsed = Std.string(value);
		return parsed == "null" ? fallback : parsed;
	}

	static function nullableText(value:Dynamic):Null<String>
	{
		var parsed = text(value, "");
		return parsed == "" ? null : parsed;
	}
}
