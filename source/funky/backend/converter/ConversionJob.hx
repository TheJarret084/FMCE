package funky.backend.converter;

import haxe.Json;
import haxe.Timer;
import haxe.io.Path;
import funky.backend.converter.FNMMToFMCEConverter.ArchiveFile;
import funky.backend.converter.FNMMToFMCEConverter.ConversionResult;
import funky.backend.converter.FNMMSpriteImporter.SpriteImportTask;
import funky.backend.converter.FNMMToFMCEConverter.FoundChart;
import funky.core.Log;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Una conversion .fnmm -> nivel FMCE hecha por ETAPAS, que se puede retomar si el juego se cae. */
@:allow(funky.backend.converter.FNMMToFMCEConverter)
class ConversionJob
{
	public static final STAGES:Array<String> = ["open", "assets", "sprites", "sparrow", "stubs", "chart", "finish"];
	/** Tiempo (s) que una llamada a `step()` puede gastar escribiendo archivos pequenos antes de devolver el control. */
	static inline var STEP_BUDGET:Float = 0.008;

	public var result(default, null):ConversionResult;
	/** Que esta haciendo ahora, para mostrarlo ("sprite me (2/9)"). */
	public var label(default, null):String = "";
	public var done(default, null):Bool = false;
	/** 0..1. */
	public var progress(get, never):Float;

	#if sys
	var archivePath:String;
	var outputDir:String;
	var id:String;
	var target:String;
	var state:ConversionProgress;
	var stage:String = "open";
	var started:Bool = false;
	var unit:Null<String> = null;
	/** Sprite que se esta convirtiendo ahora (se avanza un pedazo por `step()`), su nombre y su clave de progreso. */
	var task:Null<SpriteImportTask> = null;
	var taskName:String = "";
	var taskKey:String = "";

	// Lo que arma `open` y usan las etapas siguientes.
	var files:Array<ArchiveFile> = [];
	var found:Null<FoundChart>;
	var chartFile:Null<String>;
	var metaFile:Null<String>;
	var meta:Dynamic = {};
	var bpm:Float = 120;
	var laneCount:Int = 4;
	var notes:Array<Dynamic> = [];
	var songName:String = "";
	var musicFile:Null<String> = null;
	var roles:Map<String, String> = new Map<String, String>();
	/** `scene.json > icons`, leido en `open`: mas adelante el scene.json ya se solto de memoria (ver `ArchiveFile.release`). */
	var sceneIcons:Dynamic = null;

	var queue:Array<ArchiveFile> = [];
	var index:Int = 0;
	var spriteDirs:Array<String> = [];
	#end

	public function new(archivePath:String, outputDir:String)
	{
		var name = Path.withoutExtension(Path.withoutDirectory(archivePath));
		result = {id: name, ok: false, notes: 0, sustains: 0, laneCount: 4, strips: 0, playable: false, resumed: false, target: "", warnings: [], error: null};
		#if sys
		this.archivePath = archivePath;
		this.outputDir = outputDir;
		this.id = name;
		this.target = Path.join([outputDir, name]);
		#else
		result.error = "necesita una build con sistema de archivos (sys)";
		done = true;
		#end
	}

	/** Un pedazo de trabajo. true = quedan mas pasos. */
	public function step():Bool
	{
		#if sys
		if (done) return false;
		try
		{
			switch (stage)
			{
				case "open": stepOpen();
				case "assets": stepAssets();
				case "sprites": stepSprites();
				case "sparrow": stepSparrow();
				case "stubs": stepStubs();
				case "chart": stepChart();
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
			case "assets": 0.05 + 0.5 * fraction();
			case "sprites": 0.55 + 0.35 * fraction();
			case "sparrow": 0.91;
			case "stubs": 0.93;
			case "chart": 0.96;
			default: 0.99;
		};
		#else
		return 1;
		#end
	}

	#if sys
	inline function fraction():Float return queueLength() == 0 ? 1 : Math.min(1, index / queueLength());

	inline function queueLength():Int return stage == "sprites" ? spriteDirs.length : queue.length;

	function stepOpen():Void
	{
		label = "leyendo " + id + ".fnmm";
		if (!FileSystem.exists(archivePath)) throw "no existe " + archivePath;
		ensureDirectory(target);
		state = ConversionProgress.open(Path.join([target, ConversionProgress.FILE_NAME]), archivePath);
		result.resumed = state.resumed;

		// Un `open` que ya tumbo el juego dos veces no se vuelve a intentar: el .fnmm es demasiado para este dispositivo.
		beginStage("open");
		files = FNMMToFMCEConverter.readArchive(archivePath, result.warnings);
		if (files.length == 0) throw "archive is empty";

		found = FNMMToFMCEConverter.findChart(files);
		if (found == null) throw "archive has no chart (contents: " + FNMMToFMCEConverter.describe(files) + ")";
		chartFile = found.path;
		if (FNMMToFMCEConverter.basename(found.path.toLowerCase()) != FNMMToFMCEConverter.CHART_FILE) result.warnings.push('chart read from ' + found.path);

		var metaEntry = FNMMToFMCEConverter.findByName(files, FNMMToFMCEConverter.META_FILE);
		if (metaEntry != null)
		{
			metaFile = metaEntry.path;
			var parsedMeta = FNMMToFMCEConverter.parseJson(metaEntry);
			if (FNMMToFMCEConverter.isRecord(parsedMeta)) meta = parsedMeta;
		}

		bpm = FNMMToFMCEConverter.readBpm(found.parsed, meta);
		var raw = FNMMToFMCEConverter.parseChart(found.parsed, meta, bpm, result.warnings);
		if (raw.length == 0) throw "chart parsed (" + found.path + ") but contained no readable notes";
		var metaLanes = Std.int(FNMMToFMCEConverter.number(Reflect.field(meta, "lanes"), 0));
		laneCount = FNMMToFMCEConverter.detectLaneCount(raw, metaLanes);
		notes = FNMMToFMCEConverter.mapNotes(raw, laneCount, result);
		songName = FNMMToFMCEConverter.readName(found.parsed, meta, id);
		roles = FNMMToFMCEConverter.readSceneRoles(files);
		sceneIcons = FNMMToFMCEConverter.readSceneIcons(files);

		// El audio: el que se llame music*/inst*, y si no, el primero.
		var audio:Null<ArchiveFile> = null;
		for (file in files)
		{
			var lower = file.path.toLowerCase();
			if (FNMMToFMCEConverter.AUDIO_EXTENSIONS.indexOf(Path.extension(lower)) < 0) continue;
			if (audio == null || (FNMMToFMCEConverter.isMusic(lower) && !FNMMToFMCEConverter.isMusic(audio.path.toLowerCase()))) audio = file;
		}
		if (audio != null) musicFile = audio.path;
		else result.warnings.push("no audio track found; level will run silent");

		finishStage("open");
		// Si se retoma, `state.stage` ya dice donde quedo; si no, empieza en assets.
		enter(state.resumed && state.stage != "open" ? state.stage : "assets");
	}

	/** Archivos que `assets` escribe tal cual: todo menos chart/meta (se reescriben normalizados) y lo de sprites ya convertidos. */
	function extractable(file:ArchiveFile):Bool
	{
		if (file.path == chartFile || file.path == metaFile) return false;
		var normalized = StringTools.replace(file.path, "\\", "/");
		if (StringTools.startsWith(normalized.toLowerCase(), "sprites/"))
		{
			var parts = normalized.split("/");
			if (parts.length > 2 && state.spriteStatus(parts[1]) == "done") return false;
		}
		return true;
	}

	function stepAssets():Void
	{
		if (!started)
		{
			beginStage("assets");
			queue = [for (file in files) if (extractable(file)) file];
			index = 0;
			started = true;
		}
		var t0 = Timer.stamp();
		while (index < queue.length)
		{
			var file = queue[index];
			index++;
			label = "archivo " + index + "/" + queue.length + ": " + Path.withoutDirectory(file.path);
			var dest = Path.join([target, file.path]);
			// Retomando: lo que ya esta escrito completo no se vuelve a descomprimir.
			var complete = FileSystem.exists(dest) && !FileSystem.isDirectory(dest) && FileSystem.stat(dest).size == file.size;
			if (!complete)
			{
				FNMMToFMCEConverter.saveAsset(target, file.path, file.bytes());
				file.release();
			}
			state.assetsDone = index;
			if (Timer.stamp() - t0 > STEP_BUDGET) return;
		}

		// events.json y scene.json siempre en la raiz del nivel, que es donde los busca LevelLoader.
		for (name in [FNMMToFMCEConverter.EVENTS_FILE, FNMMToFMCEConverter.SCENE_FILE])
		{
			var special = FNMMToFMCEConverter.findByName(files, name);
			if (special == null || special.path == name) continue;
			// OJO: si `special` iba en la cola de arriba, sus bytes ya se soltaron (`release()`): releerlos daba
			// "Null Object Reference" en la 1a pasada, y en la 2a (reanudando) pasaba porque ya estaba escrito y no se soltaba.
			// Por eso se copia del archivo ya escrito y solo se descomprime si no esta.
			var written = Path.join([target, special.path]);
			if (FileSystem.exists(written) && !FileSystem.isDirectory(written)) File.copy(written, Path.join([target, name]));
			else FNMMToFMCEConverter.saveAsset(target, name, special.bytes());
		}
		finishStage("assets");
		enter("sprites");
	}

	function stepSprites():Void
	{
		if (!started)
		{
			beginStage("sprites");
			// Un cambio que se quedo a medias (el juego se cayo escribiendo un atlas) se deshace antes de buscar tiras.
			FNMMSpriteImporter.recoverLevel(target);
			spriteDirs = FNMMSpriteImporter.nativeDirs(target);
			index = 0;
			started = true;
			return;
		}

		// Un sprite en curso: una tira o una pagina por llamada, asi la pantalla sigue viva aunque el atlas sea enorme.
		if (task != null)
		{
			if (task.step())
			{
				label = "sprite " + taskName + " (" + index + "/" + spriteDirs.length + ") " + task.label;
				return;
			}
			var imported = task.result;
			task = null;
			state.finish(taskKey);
			if (imported.ok)
			{
				state.setSprite(taskName, "done");
				for (warning in imported.warnings) result.warnings.push(taskName + ': ' + warning);
			}
			else
			{
				state.setSprite(taskName, "failed: " + imported.error);
				result.warnings.push('sprite ' + taskName + ': ' + imported.error);
			}
			state.save();
			return;
		}

		if (index >= spriteDirs.length)
		{
			finishStage("sprites");
			enter("sparrow");
			return;
		}

		var dir = spriteDirs[index];
		var name = Path.withoutDirectory(dir);
		index++;
		label = "sprite " + name + " (" + index + "/" + spriteDirs.length + ")";
		var key = "sprite:" + name;

		if (state.crashedTooMuch(key))
		{
			// Este sprite ya tumbo el juego las veces permitidas: se deja y se sigue con los demas.
			state.finish(key);
			state.setSprite(name, "skipped: tumbo la conversion " + ConversionProgress.MAX_ATTEMPTS + " veces");
			result.warnings.push('sprite ' + name + ': saltado, ya habia tumbado la conversion ' + ConversionProgress.MAX_ATTEMPTS + ' veces');
			state.save();
			return;
		}

		state.begin(key);
		taskName = name;
		taskKey = key;
		task = FNMMSpriteImporter.begin(dir, roles.exists(name) ? roles.get(name) : FNMMSpriteImporter.ROLE_ITEM);
	}

	function stepSparrow():Void
	{
		label = "sprites sparrow";
		beginStage("sparrow");
		// Sprites Sparrow (sprite.xml) -> Aseprite (sprite.json), para archivos que no vienen en formato nativo.
		for (converted in SpriteFolderConverter.convertTree(target, true))
		{
			if (!converted.ok) result.warnings.push('sprite ' + converted.xml + ': ' + converted.error);
			else for (warning in converted.warnings) result.warnings.push(Path.withoutDirectory(Path.directory(converted.xml)) + ': ' + warning);
		}
		// Configs viejos (solo `name`) o con tags renombrados: se dejan en formato `anim` / `name`.
		var repaired = ConfigRepair.repairLevel(target);
		for (orphan in repaired.orphans) result.warnings.push('config.json: ' + orphan);
		finishStage("sparrow");
		enter("stubs");
	}

	function stepStubs():Void
	{
		label = "imagenes sueltas";
		beginStage("stubs");
		// PNG sueltos sin XML (fondos, etc.): un JSON de un solo frame. Las tiras de `sprites/<n>/<i>.png` ya se atendieron.
		for (file in files)
			if (Path.extension(file.path.toLowerCase()) == "png" && !FNMMToFMCEConverter.isNativeStrip(file.path))
				FNMMToFMCEConverter.writeAsepriteStub(target, file.path);
		finishStage("stubs");
		enter("chart");
	}

	function stepChart():Void
	{
		label = "chart y meta";
		beginStage("chart");
		File.saveContent(Path.join([target, FNMMToFMCEConverter.CHART_FILE]), Json.stringify(FNMMToFMCEConverter.buildChart(notes, bpm), null, "  "));

		// meta.json, el mismo formato corto que levels/ferti: nombre, bpm, pasos por beat, stage, color,
		// audio, lanes e iconos. Del meta del archivo solo se respeta lo que es dato del nivel.
		var out:Dynamic = {};
		Reflect.setField(out, "displayName", FNMMToFMCEConverter.text(Reflect.field(meta, "displayName"), songName));
		Reflect.setField(out, "bpm", bpm);
		var npb = FNMMToFMCEConverter.isRecord(found.parsed) ? Std.int(FNMMToFMCEConverter.number(Reflect.field(found.parsed, "npb"), 0)) : 0;
		var stepsPerBeat = Std.int(FNMMToFMCEConverter.number(Reflect.field(meta, "stepsPerBeat"), npb));
		if (stepsPerBeat > 0) Reflect.setField(out, "stepsPerBeat", stepsPerBeat);
		var hasScene = FNMMToFMCEConverter.findByName(files, FNMMToFMCEConverter.SCENE_FILE) != null;
		var stageName = FNMMToFMCEConverter.text(Reflect.field(meta, "stage"), hasScene ? "scene" : "");
		if (stageName != "") Reflect.setField(out, "stage", stageName);
		Reflect.setField(out, "validScore", Reflect.hasField(meta, "validScore") ? Reflect.field(meta, "validScore") == true : true);
		Reflect.setField(out, "color", FNMMToFMCEConverter.text(Reflect.field(meta, "color"), FNMMToFMCEConverter.colorFor(songName)));
		if (musicFile != null) Reflect.setField(out, "song", musicFile);
		Reflect.setField(out, "lanes", laneCount);
		if (Reflect.hasField(meta, "offset")) Reflect.setField(out, "offset", Reflect.field(meta, "offset"));
		var icons:Dynamic = Reflect.field(meta, "icons");
		if (icons == null) icons = sceneIcons;
		if (icons != null) Reflect.setField(out, "icons", icons);
		File.saveContent(Path.join([target, FNMMToFMCEConverter.META_FILE]), Json.stringify(out, null, "  "));

		finishStage("chart");
		enter("finish");
	}

	function stepFinish():Void
	{
		label = "comprobando el nivel";
		beginStage("finish");
		result.ok = true;
		result.notes = notes.length;
		result.laneCount = laneCount;
		result.target = target;
		result.strips = state.spritesWith("done");
		for (name in sprites()) if (state.spriteStatus(name).indexOf("skipped") == 0) result.warnings.push("sprite " + name + " saltado: " + state.spriteStatus(name));
		FNMMToFMCEConverter.stashOriginal(archivePath, outputDir, result.warnings);
		var problems = FNMMToFMCEConverter.validate(target);
		result.playable = problems.length == 0;
		for (problem in problems) result.warnings.push("NO JUGABLE: " + problem);
		Log.info('[converter] ' + id + ' -> ' + notes.length + ' notes, ' + laneCount + ' lanes, ' + bpm + ' bpm' + (result.resumed ? ' (retomada)' : ''));
		finishStage("finish");
		state.discard();
		finishUp();
	}

	function sprites():Array<String>
		return [for (dir in spriteDirs) Path.withoutDirectory(dir)];

	function enter(next:String):Void
	{
		stage = next;
		started = false;
		index = 0;
		queue = [];
		if (state != null)
		{
			state.stage = next;
			state.save();
		}
	}

	function beginStage(name:String):Void
	{
		unit = "stage:" + name;
		if (state.crashedTooMuch(unit))
			throw 'la conversion se cayo ' + ConversionProgress.MAX_ATTEMPTS + ' veces en "' + name + '"; borra ' + state.path + ' para empezar de cero';
		state.begin(unit);
	}

	function finishStage(name:String):Void
	{
		state.finish("stage:" + name);
		unit = null;
	}

	function finishUp():Void
	{
		files = [];
		queue = [];
		done = true;
	}

	function fail(message:String):Void
	{
		result.error = message;
		Log.error('[converter] ' + id + ' failed: ' + message);
		if (stage == "open")
		{
			// Ni se pudo abrir: no hay nada que retomar, no se deja carpeta ni JSON.
			if (state != null) state.discard();
			removeEmptyTarget();
		}
		else if (state != null)
		{
			// Un error controlado no es un crash: no cuenta como intento. El avance queda guardado para reintentar.
			if (unit != null) state.finish(unit);
			state.save();
		}
		finishUp();
	}

	/** Si el .fnmm ni se pudo abrir, no se deja una carpeta vacia en levels/. */
	function removeEmptyTarget():Void
	{
		try
		{
			if (FileSystem.exists(target) && FileSystem.readDirectory(target).length == 0) FileSystem.deleteDirectory(target);
		}
		catch (_:Dynamic) {}
	}

	static function ensureDirectory(path:String):Void
	{
		if (path == "" || path == "." || FileSystem.exists(path)) return;
		ensureDirectory(Path.directory(path));
		FileSystem.createDirectory(path);
	}
	#end
}
