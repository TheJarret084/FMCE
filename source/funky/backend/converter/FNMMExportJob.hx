package funky.backend.converter;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import funky.backend.converter.FMCEToFNMMExporter.FNMMExportPlan;
import funky.backend.converter.FMCEToFNMMExporter.FNMMExportResult;
import funky.core.JsonLoose;
import funky.core.Log;

#if sys
import haxe.crypto.Crc32;
import haxe.zip.Tools;
import haxe.zip.Writer;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
#end

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
	/** Archivos del sprite en curso: solo pasan al zip si el sprite se exporto completo (nada de tiras sueltas sin sprite.json). */
	var taskFiles:Array<{path:String, bytes:Bytes}> = [];
	var exported:Array<String> = [];
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
		// si el chart.json no trae `fmceChart: true` se detecta el tipo y se pasa a FMCE antes de exportarlo
		chart = funky.backend.chart.ChartNormalizer.ensure(dir, chartPath, chart, meta);

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
		add("events.json", Bytes.ofString(Json.stringify(parsed)));
		stage = "scene";
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
		var tracks = plan.tracks;
		if (tracks.length == 0) result.warnings.push("el nivel no tiene audio: el .FNMM sale sin musica");
		else if (tracks.length == 1 && Path.extension(tracks[0]).toLowerCase() == "ogg")
			add("music.ogg", File.getBytes(tracks[0]));
		else
		{
			// Funky Maker: Mobile lee un solo `music.ogg`: varias pistas se mezclan, y un audio que no es OGG se convierte.
			label = tracks.length > 1 ? "mezclando " + tracks.length + " pistas" : "convirtiendo a ogg";
			var names = [for (t in tracks) Path.withoutDirectory(t)];
			var mixed = AudioMixer.mix(names, [for (t in tracks) File.getBytes(t)], FMCEToFNMMExporter.OGG_QUALITY);
			if (mixed.ogg != null)
			{
				add("music.ogg", mixed.ogg);
				if (tracks.length > 1) result.warnings.push(mixed.used.length + " pistas mezcladas en music.ogg (" + mixed.used.join(", ") + ")");
				for (name in mixed.failed) result.warnings.push("no se pudo leer " + name + ": se deja fuera de la mezcla");
			}
			else
			{
				// no hubo forma de decodificar/codificar: se manda el audio principal tal cual (si no es OGG, el FNMM no lo va a leer)
				var main = plan.music != null ? plan.music : tracks[0];
				var ext = Path.extension(main).toLowerCase();
				if (FMCEToFNMMExporter.AUDIO.indexOf(ext) < 0) ext = "ogg";
				add("music." + ext, File.getBytes(main));
				result.warnings.push("no se pudo mezclar/convertir el audio: se exporta " + Path.withoutDirectory(main) + " tal cual"
					+ (ext == "ogg" ? "" : " (Funky Maker: Mobile solo lee OGG)"));
			}
		}
		stage = "sprites";
	}

	function stepSprites():Void
	{
		if (task != null)
		{
			var more = task.step();
			label = "sprite " + task.name + " " + task.label;
			for (item in task.pending) taskFiles.push(item);
			task.pending = [];
			if (more) return;

			for (warning in task.warnings) result.warnings.push("sprite " + task.name + ": " + warning);
			if (task.ok)
			{
				for (item in taskFiles) add(item.path, item.bytes);
				exported.push(task.name);
				result.sprites++;
			}
			else
				result.warnings.push("sprite " + task.name + " saltado: " + task.error + " (el .FNMM no lo lleva; la escena lo sigue usando)");
			taskFiles = [];
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
			if (exported.indexOf(name) < 0)
				result.warnings.push("scene.json usa el sprite " + name + " y " + (spriteNames.indexOf(name) < 0 ? "no esta en sprites/" : "no se pudo exportar"));

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
