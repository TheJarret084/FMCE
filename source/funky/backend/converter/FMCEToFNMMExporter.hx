package funky.backend.converter;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import funky.backend.LevelArchive;
import funky.backend.chart.LevelLoader;
import funky.core.JsonLoose;
import funky.core.Log;
import funky.core.Paths;

#if sys
import haxe.crypto.Crc32;
import haxe.zip.Tools;
import haxe.zip.Writer;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
#end

typedef FNMMExportResult =
{
	var ok:Bool;
	var level:String;
	var path:String;
	var notes:Int;
	var sprites:Int;
	var files:Int;
	/** Archivos del nivel que no entran al .FNMM (data/, voces...). */
	var ignored:Array<String>;
	var warnings:Array<String>;
	var error:Null<String>;
}

/** Que audio se usa y que se queda fuera, sin escribir nada. */
typedef FNMMExportPlan =
{
	var music:Null<String>;
	var voices:Null<String>;
	var ignored:Array<String>;
}

/** Nivel FMCE -> `.FNMM` (el inverso de `FNMMToFMCEConverter`). `data/` no se exporta. */
class FMCEToFNMMExporter
{
	public static inline var EXT:String = ".FNMM";
	public static inline var MAX_BITMAP:Int = 16384;

	/**
	 * true = la celda de cada tira se recorta a la union de lo visible de sus frames (en vez de usar el `sourceSize` completo)
	 * y el pivote (`offset`) se corre lo mismo, asi el sprite se ve igual. Las tiras salen mucho mas chicas y se codifican mas rapido.
	 * false = celdas del tamano original del frame, como antes.
	 */
	public static inline var CROP_CELLS:Bool = true;

	/** Eventos que solo existen en FMCE. */
	public static final FMCE_EVENTS:Array<String> = ["ObjectSpriteSet", "ObjectChartChange"];
	static final KEEP:Array<String> = ["chart.json", "meta.json", "events.json", "scene.json", "sprites"];
	public static final AUDIO:Array<String> = ["ogg", "mp3", "wav", "m4a"];

	public static function outputPath(levelName:String, ?destDir:String):String
		return Path.join([destDir != null ? destDir : Paths.exportsRoot(), Path.withoutDirectory(levelName) + EXT]);

	public static function levelPath(levelName:String):String
		return Path.normalize(Path.removeTrailingSlashes(Paths.levelsRoot() + levelName));

	/** Niveles de `levels/` que se pueden exportar (los que traen chart.json). */
	public static function listLevels():Array<String>
	{
		var out:Array<String> = [];
		#if sys
		var root = Paths.levelsRoot();
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return out;
		for (entry in FileSystem.readDirectory(root))
		{
			if (StringTools.startsWith(entry, ".")) continue;
			if (FileSystem.exists(Path.join([root, entry, "chart.json"]))) out.push(entry);
		}
		out.sort(Reflect.compare);
		#end
		return out;
	}

	/** Lo que el .FNMM se deja fuera. Sirve para avisar antes de exportar. */
	public static function plan(levelName:String):FNMMExportPlan
	{
		var out:FNMMExportPlan = {music: null, voices: null, ignored: []};
		#if sys
		var dir = levelPath(levelName);
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return out;

		var meta = readJson(Path.join([dir, "meta.json"]));
		out.music = findMusic(dir, meta == null ? null : Reflect.field(meta, "song"));
		out.voices = LevelLoader.findVoices(dir);

		var entries = FileSystem.readDirectory(dir);
		entries.sort(Reflect.compare);
		for (entry in entries)
		{
			if (entry == "." || entry == ".." || LevelArchive.isBackup(entry)) continue;
			if (KEEP.indexOf(entry.toLowerCase()) >= 0) continue;
			var path = Path.join([dir, entry]);
			if (FileSystem.isDirectory(path)) collect(path, entry, out.ignored, out.music);
			else if (!sameFile(path, out.music)) out.ignored.push(entry);
		}
		#end
		return out;
	}

	public static function begin(levelName:String, ?destDir:String):FNMMExportJob
		return new FNMMExportJob(levelName, destDir);

	/** Exporta de corrido (bloquea). Para no congelar la pantalla usa `begin` + `step()`. */
	public static function exportLevel(levelName:String, ?destDir:String):FNMMExportResult
	{
		var job = begin(levelName, destDir);
		while (job.step()) {}
		return job.result;
	}

	#if sys
	static function collect(abs:String, rel:String, out:Array<String>, skip:Null<String>):Void
	{
		var entries = FileSystem.readDirectory(abs);
		entries.sort(Reflect.compare);
		for (entry in entries)
		{
			if (entry == "." || entry == ".." || LevelArchive.isBackup(entry)) continue;
			var path = abs + "/" + entry;
			var name = rel + "/" + entry;
			if (FileSystem.isDirectory(path)) collect(path, name, out, skip);
			else if (!sameFile(path, skip)) out.push(name);
		}
	}

	static function sameFile(a:String, b:Null<String>):Bool
		return b != null && Path.normalize(a) == Path.normalize(b);

	public static function readJson(path:String):Dynamic
	{
		if (!FileSystem.exists(path)) return null;
		try
		{
			var parsed:Dynamic = JsonLoose.parse(File.getContent(path));
			return Reflect.isObject(parsed) ? parsed : null;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	/** Mismo orden de busqueda que `LevelLoader`: meta.song, y si no music.ogg / inst.ogg... */
	static function findMusic(dir:String, declared:Dynamic):Null<String>
	{
		var relative = declared == null ? "" : Std.string(declared);
		if (relative == "null") relative = "";
		var folders = [Path.join([dir, "music"]), dir];
		if (relative != "")
			for (folder in folders)
				if (FileSystem.exists(Path.join([folder, relative]))) return Path.join([folder, relative]);
		for (folder in folders)
			for (name in ["music.ogg", "inst.ogg", "song.ogg", "music.mp3", "music.wav", "music.m4a"])
				if (FileSystem.exists(Path.join([folder, name]))) return Path.join([folder, name]);
		return null;
	}

	public static function ensureDir(dir:String):Void
	{
		if (dir == null || dir == "" || dir == "." || FileSystem.exists(dir)) return;
		ensureDir(Path.directory(dir));
		FileSystem.createDirectory(dir);
	}
	#end

	public static inline function num(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	public static inline function text(value:Dynamic, fallback:String):String
	{
		if (value == null) return fallback;
		var parsed = Std.string(value);
		return parsed == "null" ? fallback : parsed;
	}

	public static inline function field(value:Dynamic, name:String):Dynamic
		return value == null ? null : Reflect.field(value, name);

	public static inline function round6(value:Float):Float
		return Math.round(value * 1000000) / 1000000;

	/** Segundos que dura una unidad de tiempo del chart (mismo criterio que `LevelLoader`). */
	public static function unitToSeconds(unit:String, bpm:Float):Float
	{
		return switch (unit.toLowerCase())
		{
			case "beats" | "beat": 60 / bpm;
			case "seconds" | "second" | "s": 1;
			case "steps" | "step": 60 / bpm / 4;
			default: 0.001;
		};
	}
}

/** Una exportacion hecha por etapas (cada `step()` hace un pedazo y devuelve el control). */
class FNMMExportJob
{
	public var result(default, null):FNMMExportResult;
	public var label(default, null):String = "";
	public var done(default, null):Bool = false;
	public var progress(get, never):Float;

	#if sys
	var levelName:String;
	var dir:String;
	var dest:String;
	var tmp:String;
	var stage:String = "open";
	var out:Null<FileOutput> = null;
	var writer:Null<Writer> = null;
	var meta:Dynamic = {};
	var chart:Dynamic = null;
	var plan:FNMMExportPlan;
	var sceneSprites:Array<String> = [];
	var spriteNames:Array<String> = [];
	var spriteIndex:Int = 0;
	var task:Null<FNMMSpriteExport> = null;
	#end

	public function new(levelName:String, ?destDir:String)
	{
		var name = Path.withoutDirectory(levelName);
		result = {ok: false, level: name, path: "", notes: 0, sprites: 0, files: 0, ignored: [], warnings: [], error: null};
		#if sys
		this.levelName = levelName;
		this.dir = FMCEToFNMMExporter.levelPath(levelName);
		this.dest = FMCEToFNMMExporter.outputPath(levelName, destDir);
		this.tmp = dest + ".part";
		#else
		result.error = "Exportar necesita un target con archivos (sys)";
		done = true;
		#end
	}

	public function step():Bool
	{
		#if sys
		if (done) return false;
		try
		{
			switch (stage)
			{
				case "open": stepOpen();
				case "chart": stepChart();
				case "events": stepEvents();
				case "scene": stepScene();
				case "music": stepMusic();
				case "sprites": stepSprites();
				default: stepFinish();
			}
		}
		catch (e:Dynamic)
		{
			fail(Std.string(e));
		}
		#end
		return !done;
	}

	function get_progress():Float
	{
		#if sys
		if (done) return 1;
		return switch (stage)
		{
			case "open": 0.02;
			case "chart": 0.05;
			case "events": 0.08;
			case "scene": 0.1;
			case "music": 0.12;
			case "sprites":
				var total = Math.max(1, spriteNames.length);
				0.15 + 0.8 * ((spriteIndex + (task != null ? task.fraction : 0)) / total);
			default: 0.98;
		};
		#else
		return 1;
		#end
	}

	#if sys
	function stepOpen():Void
	{
		label = "abriendo " + result.level;
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) throw "No existe el nivel " + levelName;
		var chartPath = Path.join([dir, "chart.json"]);
		if (!FileSystem.exists(chartPath)) throw "El nivel no tiene chart.json";

		chart = JsonLoose.parse(File.getContent(chartPath));
		if (chart == null || !Reflect.isObject(chart)) throw "chart.json no es un objeto JSON";
		var parsedMeta = FMCEToFNMMExporter.readJson(Path.join([dir, "meta.json"]));
		if (parsedMeta != null) meta = parsedMeta;

		plan = FMCEToFNMMExporter.plan(levelName);
		result.ignored = plan.ignored;

		FMCEToFNMMExporter.ensureDir(Path.directory(dest));
		out = File.write(tmp, true);
		writer = new Writer(out);

		var spritesDir = Path.join([dir, "sprites"]);
		if (FileSystem.exists(spritesDir) && FileSystem.isDirectory(spritesDir))
			for (entry in FileSystem.readDirectory(spritesDir))
				if (FileSystem.isDirectory(Path.join([spritesDir, entry]))) spriteNames.push(entry);
		spriteNames.sort(Reflect.compare);
		stage = "chart";
	}

	/** `data.json` del .FNMM: `strumLines[strumline][lane] = [{start, duration, props}]`, tiempos en segundos. */
	function stepChart():Void
	{
		label = "chart";
		var num = FMCEToFNMMExporter.num;
		var bpm = num(Reflect.field(chart, "bpm"), num(Reflect.field(meta, "bpm"), 120));
		if (bpm <= 0) bpm = 120;
		var unit = FMCEToFNMMExporter.text(Reflect.field(chart, "timeUnit"), FMCEToFNMMExporter.text(Reflect.field(meta, "timeUnit"), "seconds"));
		var factor = FMCEToFNMMExporter.unitToSeconds(unit, bpm);
		var offset = num(Reflect.field(meta, "offset"), 0) / 1000;
		if (offset != 0) result.warnings.push("meta.offset no existe en FNMM: se sumo a las notas (" + Math.round(offset * 1000) + " ms), no a los eventos");

		var rawLines = Reflect.field(chart, "strumLines");
		if (!Std.isOfType(rawLines, Array)) throw "chart.json no tiene strumLines";
		var lines:Array<Dynamic> = cast rawLines;

		var highest = 0;
		for (line in lines)
		{
			if (!Std.isOfType(line, Array)) continue;
			for (item in (cast line:Array<Dynamic>))
				if (isNote(item)) highest = Std.int(Math.max(highest, num(Reflect.field(item, "lane"), 0)));
		}
		var declared = Std.int(num(Reflect.field(meta, "lanes"), 0));
		var laneCount = Std.int(Math.max(declared > 0 ? declared : 4, highest + 1));

		// scene.json puede apuntar a strumlines que el chart no tiene
		var strumCount = Std.int(Math.max(2, lines.length));
		var scene = FMCEToFNMMExporter.readJson(Path.join([dir, "scene.json"]));
		var objects = FMCEToFNMMExporter.field(scene, "objects");
		if (Std.isOfType(objects, Array))
			for (item in (cast objects:Array<Dynamic>))
				strumCount = Std.int(Math.max(strumCount, num(Reflect.field(item, "strumLine"), -1) + 1));

		var strums:Array<Array<Array<Dynamic>>> = [];
		for (s in 0...strumCount)
		{
			var lanes:Array<Array<Dynamic>> = [];
			for (l in 0...laneCount) lanes.push([]);
			strums.push(lanes);
		}

		var count = 0;
		var sustains = 0;
		for (index in 0...lines.length)
		{
			if (!Std.isOfType(lines[index], Array)) continue;
			for (item in (cast lines[index]:Array<Dynamic>))
			{
				if (!isNote(item)) continue;
				var lane = Std.int(num(Reflect.field(item, "lane"), 0));
				if (lane < 0) continue;
				var length = num(Reflect.field(item, "length"), 0);
				strums[index][lane].push({
					props: {skin: 0, onMissEvent: pack(item, "onMiss"), onPressEvent: pack(item, "onPress")},
					duration: length > 0 ? FMCEToFNMMExporter.round6(length * factor) : 0,
					start: FMCEToFNMMExporter.round6(num(Reflect.field(item, "time"), 0) * factor + offset)
				});
				count++;
				if (length > 0) sustains++;
			}
		}
		for (lanes in strums)
			for (notes in lanes) notes.sort(function(a, b) return a.start < b.start ? -1 : (a.start > b.start ? 1 : 0));

		var npb = num(Reflect.field(meta, "stepsPerBeat"), num(Reflect.field(chart, "npb"), 4));
		if (npb <= 0) npb = 4;
		add("data.json", Bytes.ofString(Json.stringify({strumLines: strums, version: 4, bpm: bpm, npb: npb})));
		result.notes = count;
		if (count == 0) result.warnings.push("el chart no tiene notas");
		stage = "events";
	}

	static function isNote(item:Dynamic):Bool
		return item != null && Reflect.isObject(item) && !Std.isOfType(item, Array);

	static function pack(item:Dynamic, name:String):Int
	{
		var n = FMCEToFNMMExporter.num(Reflect.field(item, name), -1);
		return n >= 0 ? Std.int(n) : -1;
	}

	function stepEvents():Void
	{
		label = "events.json";
		var path = Path.join([dir, "events.json"]);
		var parsed = FMCEToFNMMExporter.readJson(path);
		if (parsed == null)
		{
			if (FileSystem.exists(path)) result.warnings.push("events.json ilegible: se exporto vacio");
			parsed = {events: [], action_packs: []};
		}
		else warnFmceEvents(parsed);
		add("events.json", Bytes.ofString(Json.stringify(parsed)));
		stage = "scene";
	}

	function warnFmceEvents(events:Dynamic):Void
	{
		var found:Array<String> = [];
		var lists:Array<Dynamic> = [];
		var top = Reflect.field(events, "events");
		if (Std.isOfType(top, Array)) for (item in (cast top:Array<Dynamic>)) lists.push(Reflect.field(item, "actions"));
		var packs = Reflect.field(events, "action_packs");
		if (Std.isOfType(packs, Array)) for (item in (cast packs:Array<Dynamic>)) lists.push(Reflect.field(item, "actions"));
		for (actions in lists)
		{
			if (!Std.isOfType(actions, Array)) continue;
			for (action in (cast actions:Array<Dynamic>))
			{
				var type = FMCEToFNMMExporter.text(Reflect.field(action, "type"), "");
				if (FMCEToFNMMExporter.FMCE_EVENTS.indexOf(type) >= 0 && found.indexOf(type) < 0) found.push(type);
			}
		}
		if (found.length > 0)
			result.warnings.push("eventos solo de FMCE (" + found.join(", ") + "): se dejan en events.json, el FNMM original puede no reconocerlos");
	}

	function stepScene():Void
	{
		label = "scene.json";
		var path = Path.join([dir, "scene.json"]);
		var scene = FMCEToFNMMExporter.readJson(path);
		if (scene == null)
		{
			result.warnings.push(FileSystem.exists(path) ? "scene.json ilegible: el .FNMM sale sin escena" : "el nivel no tiene scene.json: el .FNMM sale sin escena");
			stage = "music";
			return;
		}

		// scene.json lleva [oponente, jugador]; si solo estan en meta.icons {P1, P2}, se pasan
		var icons = Reflect.field(scene, "icons");
		var metaIcons = Reflect.field(meta, "icons");
		if (!Std.isOfType(icons, Array) && metaIcons != null)
		{
			var p1 = FMCEToFNMMExporter.text(Reflect.field(metaIcons, "P1"), "");
			var p2 = FMCEToFNMMExporter.text(Reflect.field(metaIcons, "P2"), "");
			if (p1 != "" || p2 != "") Reflect.setField(scene, "icons", [p2, p1]);
		}

		var used = Reflect.field(scene, "icons");
		if (Std.isOfType(used, Array)) for (item in (cast used:Array<Dynamic>)) addSceneSprite(FMCEToFNMMExporter.text(item, ""));
		var objects = Reflect.field(scene, "objects");
		if (Std.isOfType(objects, Array))
			for (item in (cast objects:Array<Dynamic>)) addSceneSprite(FMCEToFNMMExporter.text(Reflect.field(item, "spr"), ""));

		add("scene.json", Bytes.ofString(Json.stringify(scene)));
		stage = "music";
	}

	function addSceneSprite(name:String):Void
	{
		if (name != "" && sceneSprites.indexOf(name) < 0) sceneSprites.push(name);
	}

	function stepMusic():Void
	{
		label = "audio";
		if (plan.music == null) result.warnings.push("el nivel no tiene audio: el .FNMM sale sin musica");
		else
		{
			var ext = Path.extension(plan.music).toLowerCase();
			if (FMCEToFNMMExporter.AUDIO.indexOf(ext) < 0) ext = "ogg";
			add("music." + ext, File.getBytes(plan.music));
		}
		if (plan.voices != null) result.warnings.push("el FNMM no tiene pista de voces: " + Path.withoutDirectory(plan.voices) + " se ignora");
		stage = "sprites";
	}

	function stepSprites():Void
	{
		if (task != null)
		{
			var more = task.step();
			label = "sprite " + task.name + " " + task.label;
			for (item in task.pending) add(item.path, item.bytes);
			task.pending = [];
			if (more) return;

			for (warning in task.warnings) result.warnings.push("sprite " + task.name + ": " + warning);
			if (task.ok) result.sprites++;
			else result.warnings.push("sprite " + task.name + " saltado: " + task.error);
			task = null;
			spriteIndex++;
			return;
		}
		if (spriteIndex >= spriteNames.length)
		{
			stage = "finish";
			return;
		}
		var name = spriteNames[spriteIndex];
		label = "sprite " + name;
		task = new FNMMSpriteExport(dir, name);
	}

	function stepFinish():Void
	{
		label = "guardando";
		for (name in sceneSprites)
			if (spriteNames.indexOf(name) < 0) result.warnings.push("scene.json usa el sprite " + name + " y no esta en sprites/");

		writer.writeCDR();
		closeOutput();
		FNMMSpriteImporter.replaceFile(tmp, dest);

		if (result.ignored.length > 0) result.warnings.push(result.ignored.length + " archivo(s) del nivel no entran al .FNMM (data/ y otros)");
		result.ok = true;
		result.path = dest;
		Log.info('[FNMMExport] ' + result.level + ' -> ' + dest + ' (' + result.files + ' archivos, ' + result.notes + ' notas, ' + result.sprites + ' sprites)');
		done = true;
	}

	function add(name:String, bytes:Bytes):Void
	{
		var entry:haxe.zip.Entry = {
			fileName: name,
			fileSize: bytes.length,
			fileTime: Date.now(),
			compressed: false,
			dataSize: bytes.length,
			data: bytes,
			crc32: Crc32.make(bytes),
			extraFields: new List()
		};
		if (!isStored(name)) Tools.compress(entry, 6);
		writer.writeEntryHeader(entry);
		out.writeFullBytes(entry.data, 0, entry.data.length);
		result.files++;
	}

	static function isStored(name:String):Bool
	{
		var lower = name.toLowerCase();
		for (ext in [".png", ".ogg", ".mp3", ".wav", ".m4a"])
			if (StringTools.endsWith(lower, ext)) return true;
		return false;
	}

	function closeOutput():Void
	{
		if (out == null) return;
		try out.close() catch (_:Dynamic) {}
		out = null;
	}

	function fail(message:String):Void
	{
		result.error = message;
		Log.error('[FNMMExport] ' + result.level + ': ' + message);
		if (task != null) task.dispose();
		closeOutput();
		try
		{
			if (FileSystem.exists(tmp)) FileSystem.deleteFile(tmp);
		}
		catch (_:Dynamic) {}
		done = true;
	}
	#end
}

/** Un sprite de `sprites/<nombre>/` -> tiras `<i>.png` + `sprite.json` nativo de FNMM. */
class FNMMSpriteExport
{
	public var name(default, null):String;
	public var label(default, null):String = "";
	public var done(default, null):Bool = false;
	public var ok(default, null):Bool = false;
	public var error(default, null):Null<String> = null;
	public var warnings(default, null):Array<String> = [];
	public var fraction(get, never):Float;
	/** Archivos listos para el zip; el job los escribe y vacia la lista. */
	public var pending:Array<{path:String, bytes:Bytes}> = [];

	#if sys
	var dir:String;
	var base:String;
	var phase:Int = 0;
	var index:Int = 0;
	var nativeFiles:Array<String> = [];
	var frames:Array<Dynamic> = [];
	var pageFiles:Array<String> = [];
	var pages:Map<Int, BitmapData> = new Map<Int, BitmapData>();
	var anims:Array<{frames:Array<Dynamic>, cfg:Dynamic}> = [];
	var outData:Array<Dynamic> = [];
	/** Pagina del atlas -> ultima tira que la usa (despues de esa se libera su bitmap). */
	var lastUse:Map<Int, Int> = new Map<Int, Int>();
	#end

	public function new(levelDir:String, name:String)
	{
		this.name = name;
		#if sys
		this.dir = Path.join([levelDir, "sprites", name]);
		this.base = "sprites/" + name + "/";
		#else
		error = "necesita sys";
		done = true;
		#end
	}

	function get_fraction():Float
	{
		#if sys
		return phase == 1 && anims.length > 0 ? index / anims.length : 0;
		#else
		return 0;
		#end
	}

	public function step():Bool
	{
		#if sys
		if (done) return false;
		try
		{
			switch (phase)
			{
				case 0: open();
				case 1: stepAnim();
				case 2: finishAtlas();
				default: stepNative();
			}
		}
		catch (e:Dynamic)
		{
			error = Std.string(e);
			dispose();
			done = true;
		}
		#end
		return !done;
	}

	public function dispose():Void
	{
		#if sys
		for (bitmap in pages) bitmap.dispose();
		pages = new Map<Int, BitmapData>();
		#end
	}

	#if sys
	function open():Void
	{
		label = "abriendo";
		for (entry in FileSystem.readDirectory(dir))
		{
			var lower = entry.toLowerCase();
			if (StringTools.endsWith(lower, ".mp4") || StringTools.endsWith(lower, ".webm")) throw "es un video y el .FNMM no los soporta";
		}

		// ya viene en formato FNMM (tiras + sprite.json con `data`): se copia tal cual
		if (FNMMSpriteImporter.isNative(dir))
		{
			var native:Dynamic = JsonLoose.parse(File.getContent(Path.join([dir, "sprite.json"])));
			nativeFiles = ["sprite.json"];
			for (i in 0...(cast Reflect.field(native, "data"):Array<Dynamic>).length) nativeFiles.push(i + ".png");
			phase = 3;
			return;
		}

		var jsonPath = Path.join([dir, "sprite.json"]);
		if (!FileSystem.exists(jsonPath)) throw "no tiene sprite.json";
		var atlas:Dynamic = JsonLoose.parse(File.getContent(jsonPath));
		frames = framesOf(atlas);
		if (frames.length == 0) throw "el atlas no tiene frames";

		var meta = Reflect.field(atlas, "meta");
		var pageInfo = FMCEToFNMMExporter.field(meta, "pages");
		if (Std.isOfType(pageInfo, Array) && (cast pageInfo:Array<Dynamic>).length > 0)
			for (page in (cast pageInfo:Array<Dynamic>)) pageFiles.push(FMCEToFNMMExporter.text(Reflect.field(page, "image"), "sprite.png"));
		else
			pageFiles.push("sprite.png");

		var tags:Array<Dynamic> = [];
		var rawTags = FMCEToFNMMExporter.field(meta, "frameTags");
		if (Std.isOfType(rawTags, Array)) tags = cast rawTags;

		var config:Dynamic = null;
		var configPath = Path.join([dir, "config.json"]);
		if (FileSystem.exists(configPath))
		{
			try config = JsonLoose.parse(File.getContent(configPath)) catch (_:Dynamic) warnings.push("config.json ilegible: se usan los tags del atlas");
		}
		var list = FMCEToFNMMExporter.field(config, "data");
		if (Std.isOfType(list, Array) && (cast list:Array<Dynamic>).length > 0) fromConfig(cast list, tags);
		else fromTags(tags);

		if (anims.length == 0) throw "no quedo ninguna animacion";
		for (i in 0...anims.length)
			for (frame in anims[i].frames) lastUse.set(pageKey(frame), i);
		phase = 1;
	}

	/** Cada entrada del config.json es una tira; van en el orden de `index`, que es la posicion que usan los eventos. */
	function fromConfig(list:Array<Dynamic>, tags:Array<Dynamic>):Void
	{
		var order = [for (i in 0...list.length) i];
		order.sort(function(a:Int, b:Int):Int
		{
			var ia = FMCEToFNMMExporter.num(Reflect.field(list[a], "index"), a);
			var ib = FMCEToFNMMExporter.num(Reflect.field(list[b], "index"), b);
			return ia < ib ? -1 : (ia > ib ? 1 : a - b);
		});

		for (i in order)
		{
			var cfg = list[i];
			var tagName = FMCEToFNMMExporter.text(Reflect.field(cfg, "anim"), FMCEToFNMMExporter.text(Reflect.field(cfg, "name"), ""));
			var slice:Array<Dynamic> = [];
			var indices = Reflect.field(cfg, "indices");
			if (Std.isOfType(indices, Array) && (cast indices:Array<Dynamic>).length > 0)
			{
				// `indices` = frames del atlas tal cual (igual que en el juego): no necesita tag y pueden repetirse.
				for (value in (cast indices:Array<Dynamic>))
				{
					var at = Std.int(FMCEToFNMMExporter.num(value, -1));
					if (at >= 0 && at < frames.length) slice.push(frames[at]);
				}
				if (slice.length == 0)
				{
					warnings.push("la animacion '" + tagName + "' tiene indices que no existen en el atlas y se salta");
					continue;
				}
			}
			else
			{
				var range = rangeOf(tags, tagName);
				if (range == null && tags.length == 0 && list.length == 1) range = {from: 0, to: frames.length - 1};
				if (range == null)
				{
					warnings.push("la animacion '" + tagName + "' no tiene tag en el atlas y se salta");
					continue;
				}
				slice = frames.slice(range.from, range.to + 1);
			}
			if (slice.length > 0) anims.push({frames: slice, cfg: cfg});
		}
	}

	function fromTags(tags:Array<Dynamic>):Void
	{
		for (tag in tags)
		{
			var range = rangeOf([tag], FMCEToFNMMExporter.text(Reflect.field(tag, "name"), ""));
			if (range != null) anims.push({frames: frames.slice(range.from, range.to + 1), cfg: null});
		}
		if (anims.length == 0) anims.push({frames: frames, cfg: null});
		warnings.push("no tiene config.json: se exporta con offset 0 y velocidad 1");
	}

	function rangeOf(tags:Array<Dynamic>, tagName:String):Null<{from:Int, to:Int}>
	{
		for (tag in tags)
		{
			if (FMCEToFNMMExporter.text(Reflect.field(tag, "name"), "") != tagName) continue;
			var from = Std.int(FMCEToFNMMExporter.num(Reflect.field(tag, "from"), 0));
			var to = Std.int(FMCEToFNMMExporter.num(Reflect.field(tag, "to"), from));
			from = Std.int(Math.max(0, from));
			to = Std.int(Math.min(frames.length - 1, to));
			if (to >= from) return {from: from, to: to};
		}
		return null;
	}

	/** Aseprite puede traer `frames` como lista o como objeto {nombre: frame}. */
	static function framesOf(atlas:Dynamic):Array<Dynamic>
	{
		var raw:Dynamic = Reflect.field(atlas, "frames");
		if (Std.isOfType(raw, Array)) return cast raw;
		var out:Array<Dynamic> = [];
		if (raw != null && Reflect.isObject(raw))
			for (key in Reflect.fields(raw)) out.push(Reflect.field(raw, key));
		return out;
	}

	/** Una tira por llamada: los frames recortados del atlas vuelven a su lugar dentro de su celda original. */
	function stepAnim():Void
	{
		if (index >= anims.length)
		{
			phase = 2;
			return;
		}
		var i = index;
		index++;
		label = "tira " + index + "/" + anims.length;

		var list = anims[i].frames;

		// Zona visible de cada frame dentro de su celda original (`spriteSourceSize`). La celda de la tira es la union de todas.
		var minX = 1 << 30;
		var minY = 1 << 30;
		var maxX = 0;
		var maxY = 0;
		var fullW = 1;
		var fullH = 1;
		for (frame in list)
		{
			var size = Reflect.field(frame, "sourceSize");
			var box = Reflect.field(frame, "frame");
			var inner = Reflect.field(frame, "spriteSourceSize");
			var w = Std.int(FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(box, "w"), 0));
			var h = Std.int(FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(box, "h"), 0));
			fullW = Std.int(Math.max(fullW, FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(size, "w"), w)));
			fullH = Std.int(Math.max(fullH, FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(size, "h"), h)));
			if (w < 1 || h < 1) continue;
			var ix = Std.int(FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(inner, "x"), 0));
			var iy = Std.int(FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(inner, "y"), 0));
			minX = Std.int(Math.min(minX, ix));
			minY = Std.int(Math.min(minY, iy));
			maxX = Std.int(Math.max(maxX, ix + w));
			maxY = Std.int(Math.max(maxY, iy + h));
		}
		if (maxX <= minX || maxY <= minY)
		{
			// todos los frames vacios: una celda de 1x1
			minX = 0;
			minY = 0;
			maxX = 1;
			maxY = 1;
		}

		var cropX = 0;
		var cropY = 0;
		var cellW = Std.int(Math.max(fullW, maxX));
		var cellH = Std.int(Math.max(fullH, maxY));
		if (FMCEToFNMMExporter.CROP_CELLS)
		{
			cropX = minX;
			cropY = minY;
			cellW = maxX - minX;
			cellH = maxY - minY;
		}
		if (cellW * list.length > FMCEToFNMMExporter.MAX_BITMAP || cellH > FMCEToFNMMExporter.MAX_BITMAP)
			throw "la tira " + i + " mide " + (cellW * list.length) + "x" + cellH + " (maximo " + FMCEToFNMMExporter.MAX_BITMAP + ")";

		var strip = new BitmapData(cellW * list.length, cellH, true, 0x00000000);
		for (k in 0...list.length)
		{
			var frame = list[k];
			if (Reflect.field(frame, "rotated") == true) warnings.push("tira " + i + ": hay frames rotados, no se soportan");
			var box = Reflect.field(frame, "frame");
			var inner = Reflect.field(frame, "spriteSourceSize");
			var w = Std.int(FMCEToFNMMExporter.num(Reflect.field(box, "w"), 0));
			var h = Std.int(FMCEToFNMMExporter.num(Reflect.field(box, "h"), 0));
			if (w < 1 || h < 1) continue;
			var page = pageBitmap(pageKey(frame));
			var source = new Rectangle(FMCEToFNMMExporter.num(Reflect.field(box, "x"), 0), FMCEToFNMMExporter.num(Reflect.field(box, "y"), 0), w, h);
			var at = new Point(k * cellW + FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(inner, "x"), 0) - cropX,
				FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(inner, "y"), 0) - cropY);
			strip.copyPixels(page, source, at);
		}
		var bytes:Bytes = strip.encode(strip.rect, new PNGEncoderOptions(true));
		strip.dispose();
		pending.push({path: base + i + ".png", bytes: bytes});
		outData.push(animEntry(anims[i].cfg, list.length, cropX, cropY));

		// una pagina del atlas que ya no usa ninguna tira de las que faltan se libera (ahorra memoria en celulares)
		for (page in lastUse.keys())
			if (lastUse.get(page) == i && pages.exists(page))
			{
				pages.get(page).dispose();
				pages.remove(page);
			}
	}

	/** Pagina del atlas de un frame (si apunta a una que no existe, la 0, igual que `pageBitmap`). */
	function pageKey(frame:Dynamic):Int
	{
		var page = Std.int(FMCEToFNMMExporter.num(Reflect.field(frame, "page"), 0));
		return page >= 0 && page < pageFiles.length ? page : 0;
	}

	function pageBitmap(page:Int):BitmapData
	{
		if (pages.exists(page)) return pages.get(page);
		var file = page >= 0 && page < pageFiles.length ? pageFiles[page] : pageFiles[0];
		var path = Path.join([dir, file]);
		if (!FileSystem.exists(path)) throw "falta la imagen " + file;
		var bitmap = BitmapData.fromFile(path);
		if (bitmap == null) throw "no se pudo leer " + file;
		pages.set(page, bitmap);
		return bitmap;
	}

	/** `spd` en FNMM es un multiplicador de 24 fps; en FMCE puede venir en fps crudos (`spd_fps`). */
	function animEntry(cfg:Dynamic, count:Int, cropX:Int, cropY:Int):Dynamic
	{
		var offset = FMCEToFNMMExporter.field(cfg, "offset");
		var spd = FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(cfg, "spd"), 1);
		if (FMCEToFNMMExporter.field(cfg, "spd_fps") == true) spd = spd / 24;
		return {
			// el pivote se mide desde la esquina de la celda: si la celda se recorto, se corre lo mismo
			offset: {x: FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(offset, "x"), 0) - cropX, y: FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(offset, "y"), 0) - cropY},
			num: count,
			spd: spd,
			spd_fps: false,
			scale: FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(cfg, "scale"), 1),
			bilinear: FMCEToFNMMExporter.field(cfg, "bilinear") == true,
			loop: FMCEToFNMMExporter.field(cfg, "loop") != false
		};
	}

	function finishAtlas():Void
	{
		label = "sprite.json";
		dispose();
		pending.push({path: base + "sprite.json", bytes: Bytes.ofString(Json.stringify({type: 0, data: outData}))});
		ok = true;
		done = true;
	}

	function stepNative():Void
	{
		if (index >= nativeFiles.length)
		{
			ok = true;
			done = true;
			return;
		}
		var file = nativeFiles[index];
		index++;
		label = file;
		var path = Path.join([dir, file]);
		if (FileSystem.exists(path)) pending.push({path: base + file, bytes: File.getBytes(path)});
		else warnings.push("falta " + file);
	}
	#end
}
