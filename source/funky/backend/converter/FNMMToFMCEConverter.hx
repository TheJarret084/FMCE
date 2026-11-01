package funky.backend.converter;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import funky.core.Log;

#if sys
import haxe.zip.Reader;
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef ConversionResult = {
	var id:String;
	var ok:Bool;
	var notes:Int;
	var sustains:Int;
	var laneCount:Int;
	/** Sprites que quedaron en cinta + JSON Hash (ver `StripConverter`). */
	var strips:Int;
	/** true si despues de convertir el nivel se pudo cargar completo (chart, audio, iconos y sprites de la escena). */
	var playable:Bool;
	/** true si se retomo una conversion que se habia quedado a medias (ver `ConversionProgress`). */
	var resumed:Bool;
	var target:String;
	var warnings:Array<String>;
	var error:Null<String>;
}

/** Nota cruda ya en milisegundos. `mustPress == null` = el formato no lo dice (se decide por mitades de lane). */
typedef RawNote = {
	var t:Float;
	var lane:Int;
	var len:Float;
	var mustPress:Null<Bool>;

	/** Indice de strumline cuando el formato la trae: 0 jugador, 1 oponente, 2+ extras. */
	@:optional var line:Null<Int>;

	/** Indice de `action_packs` que corre al acertar / fallar la nota (`onPressEvent` / `onMissEvent` del .fnmm). -1 o null = ninguno. */
	@:optional var onPress:Null<Int>;
	@:optional var onMiss:Null<Int>;
}

/**
 * Un archivo del zip. Se descomprime SOLO cuando se pide (`bytes()`), y `release()` suelta los bytes:
 * asi nunca estan todos los archivos del .fnmm descomprimidos a la vez en memoria (en el celular eso
 * era lo que tumbaba la conversion de niveles grandes).
 */
class ArchiveFile
{
	public var path:String;
	var entry:haxe.zip.Entry;

	public function new(path:String, entry:haxe.zip.Entry)
	{
		this.path = path;
		this.entry = entry;
	}

	/** Tamano descomprimido, sin descomprimir. */
	public var size(get, never):Int;

	inline function get_size():Int return entry.fileSize;

	public function bytes():Bytes
	{
		// Mensaje claro en vez de "Null Object Reference" dentro de haxe.zip.Reader.
		if (entry.data == null) throw "el archivo '" + path + "' ya se solto de memoria (release) y no se puede volver a leer";
		return haxe.zip.Reader.unzip(entry);
	}

	/** Suelta los bytes descomprimidos (el archivo ya no se puede volver a leer). */
	public function release():Void
	{
		entry.data = null;
	}
}

typedef FoundChart = {
	var path:String;
	var parsed:Dynamic;
}

/** Converts Funky Maker: Mobile (.fnmm) archives into FMCE levels. */
@:allow(funky.backend.converter.ConversionJob)
class FNMMToFMCEConverter
{
	public static final META_FILE = "meta.json";
	public static final CHART_FILE = "chart.json";
	public static final EVENTS_FILE = "events.json";
	public static final SCENE_FILE = "scene.json";
	public static final DATA_FILE = "data.json";
	public static final AUDIO_EXTENSIONS = ["ogg", "mp3", "wav", "m4a"];
	public static final VERSION = "4";
	/** Carpeta (dentro de levels/) donde queda una copia del .fnmm original, junto a su version descomprimida. */
	public static final TMP_DIR = ".tmp";
	/** Unidad de `start`/`duration` en el `data.json` de un .fnmm (comprobado contra el audio). */
	public static final DATA_TIME_UNIT = "seconds";

	/**
	 * JSON del archivo que nunca son el chart. `data.json` NO esta aqui: en los .fnmm reales
	 * (Funky Maker: Mobile) el chart se llama `data.json`. Si es otra cosa (como el
	 * `data.json` que escribe este conversor, `{offsets}`), `looksLikeChart` lo descarta.
	 */
	static final RESERVED_JSON = ["meta.json", "events.json", "scene.json", "config.json", "sprite.json"];

	public static function convertAll(inputDir:String, outputDir:String):Array<ConversionResult>
	{
		#if sys
		var results:Array<ConversionResult> = [];
		if (!FileSystem.exists(inputDir))
		{
			Log.warn('[converter] input dir missing: ' + inputDir);
			return results;
		}
		var archives = [for (file in FileSystem.readDirectory(inputDir)) if (StringTools.endsWith(file.toLowerCase(), ".fnmm")) Path.join([inputDir, file])];
		archives.sort(Reflect.compare);
		for (archive in archives) results.push(convert(archive, outputDir));
		return results;
		#else
		return [];
		#end
	}

	/**
	 * Convierte un .fnmm de principio a fin (bloquea hasta terminar). Si una conversion anterior de este
	 * mismo archivo se quedo a medias, la retoma (ver `ConversionProgress`). Para convertir sin congelar la
	 * pantalla, usa `ConversionJob` y llama `step()` cada frame.
	 */
	public static function convert(archivePath:String, outputDir:String):ConversionResult
	{
		#if sys
		var job = new ConversionJob(archivePath, outputDir);
		while (job.step()) {}
		return job.result;
		#else
		return {id: Path.withoutExtension(Path.withoutDirectory(archivePath)), ok: false, notes: 0, sustains: 0, laneCount: 4, strips: 0, playable: false, resumed: false, target: "", warnings: [], error: "necesita una build con sistema de archivos (sys)"};
		#end
	}

	/** true si hay una conversion a medias de `archivePath` (el menu muestra "continuar"). */
	public static function hasProgress(archivePath:String, outputDir:String):Bool
	{
		#if sys
		var id = Path.withoutExtension(Path.withoutDirectory(archivePath));
		return FileSystem.exists(Path.join([outputDir, id, ConversionProgress.FILE_NAME]));
		#else
		return false;
		#end
	}

	/**
	 * `chart.json` en formato FMCE (igual que `levels/ferti`): `strumLines[0]` = jugador,
	 * `strumLines[1]` = oponente, `strumLines[2..]` = extras (cada una separada), `time`/`length` en SEGUNDOS (ms / 1000) y `timeUnit: "seconds"`
	 * explicito, para que LevelLoader nunca tenga que adivinar la unidad.
	 */
	static function buildChart(notes:Array<Dynamic>, bpm:Float):Dynamic
	{
		var lines:Array<Array<Dynamic>> = [[], []];
		for (note in notes)
		{
			var entry:Dynamic = {time: round6(note.time / 1000), lane: note.lane};
			if (note.length > 0) Reflect.setField(entry, "length", round6(note.length / 1000));
			if (Reflect.hasField(note, "onPress")) Reflect.setField(entry, "onPress", Reflect.field(note, "onPress"));
			if (Reflect.hasField(note, "onMiss")) Reflect.setField(entry, "onMiss", Reflect.field(note, "onMiss"));

			// Las extras (2, 3, ...) conservan su indice y NO se mezclan con el oponente.
			var extra:Int = Reflect.hasField(note, "line") ? Std.int(Reflect.field(note, "line")) : -1;
			if (extra >= 2)
			{
				while (lines.length <= extra) lines.push([]);
				lines[extra].push(entry);
			}
			else if (note.mustPress == true) lines[0].push(entry);
			else lines[1].push(entry);
		}
		return {fmceChart: true, timeUnit: DATA_TIME_UNIT, strumLines: lines};
	}

	static inline function round6(value:Float):Float return Math.round(value * 1000000) / 1000000;

	/**
	 * Comprueba que el nivel recien convertido se puede jugar: carga el chart como lo hace el juego,
	 * hay audio y todos los sprites que nombran los iconos y `scene.json` existen. Devuelve los problemas.
	 */
	public static function validate(levelDir:String):Array<String>
	{
		var problems:Array<String> = [];
		#if sys
		try
		{
			var chart = funky.backend.chart.LevelLoader.loadFolder(levelDir);
			if (chart.notes.length == 0) problems.push("el chart no tiene notas");
			if (chart.musicPath == null) problems.push("no hay audio");
			for (icon in [chart.iconPlayer, chart.iconOpponent])
				if (icon != null && !funky.game.SpriteBuilder.exists(levelDir, icon)) problems.push("falta el icono " + icon);
		}
		catch (e:Dynamic)
		{
			problems.push("no carga: " + Std.string(e));
		}
		var scenePath = Path.join([levelDir, SCENE_FILE]);
		if (FileSystem.exists(scenePath))
		{
			try
			{
				var scene:Dynamic = Json.parse(File.getContent(scenePath));
				var missing:Array<String> = [];
				var objects = Reflect.field(scene, "objects");
				if (Std.isOfType(objects, Array))
					for (item in (cast objects:Array<Dynamic>))
					{
						var name = text(Reflect.field(item, "spr"), "");
						if (name != "" && !funky.game.SpriteBuilder.exists(levelDir, name) && missing.indexOf(name) < 0) missing.push(name);
					}
				if (missing.length > 0) problems.push("faltan sprites de la escena: " + missing.join(", "));
			}
			catch (e:Dynamic)
			{
				problems.push("scene.json ilegible");
			}
		}
		#end
		return problems;
	}

	/** Las tiras `sprites/<n>/<i>.png` de un sprite nativo (no son imagenes sueltas). */
	static function isNativeStrip(path:String):Bool
		return ~/(^|\/)sprites\/[^\/]+\/[0-9]+\.png$/i.match(StringTools.replace(path, "\\", "/"));

	/** Color de la tarjeta del nivel, fijo para un mismo nombre. */
	static function colorFor(name:String):String
	{
		var palette = ["#31A2F2", "#E5547A", "#6BD968", "#F2B531", "#9C70FF", "#2FC9B8", "#F27A31", "#C24B99"];
		var sum = 0;
		for (i in 0...name.length) sum += name.charCodeAt(i);
		return palette[sum % palette.length];
	}

	/**
	 * Rol de cada sprite segun `scene.json`: los de `icons` son iconos, los objetos ligados a una
	 * strumLine (>= 0) son personajes y el resto, items (fondos, textos, cortinas).
	 */
	static function readSceneRoles(files:Array<ArchiveFile>):Map<String, String>
	{
		var roles = new Map<String, String>();
		var sceneFile = findByName(files, SCENE_FILE);
		if (sceneFile == null) return roles;
		var scene = parseJson(sceneFile);
		if (!isRecord(scene)) return roles;
		var objects = Reflect.field(scene, "objects");
		if (Std.isOfType(objects, Array))
			for (item in (cast objects:Array<Dynamic>))
			{
				var name = text(Reflect.field(item, "spr"), "");
				if (name != "" && number(Reflect.field(item, "strumLine"), -1) >= 0) roles.set(name, FNMMSpriteImporter.ROLE_CHARACTER);
			}
		var icons = Reflect.field(scene, "icons");
		if (Std.isOfType(icons, Array))
			for (item in (cast icons:Array<Dynamic>)) roles.set(text(item, ""), FNMMSpriteImporter.ROLE_ICON);
		return roles;
	}

	/** `scene.json > icons` es `[oponente, jugador]`; meta.json los quiere como `{P1: jugador, P2: oponente}`. */
	static function readSceneIcons(files:Array<ArchiveFile>):Dynamic
	{
		var sceneFile = findByName(files, SCENE_FILE);
		if (sceneFile == null) return null;
		var scene = parseJson(sceneFile);
		if (!isRecord(scene)) return null;
		var list = Reflect.field(scene, "icons");
		if (!Std.isOfType(list, Array)) return null;
		var icons:Array<Dynamic> = cast list;
		if (icons.length < 2) return null;
		return {P1: text(icons[1], ""), P2: text(icons[0], "")};
	}

	#if sys
	/**
	 * Guarda el .fnmm original en `<levels>/.tmp/` (junto a la carpeta descomprimida) y lo quita de
	 * `levels/`, que solo tiene carpetas de niveles. Si el archivo venia de otro sitio, se copia.
	 */
	static function stashOriginal(archivePath:String, outputDir:String, warnings:Array<String>):Void
	{
		try
		{
			var tmp = Path.join([outputDir, TMP_DIR]);
			ensureDirectory(tmp);
			var dest = Path.join([tmp, Path.withoutDirectory(archivePath)]);
			var sameDir = Path.removeTrailingSlashes(Path.directory(archivePath)) == Path.removeTrailingSlashes(outputDir);
			if (Path.normalize(archivePath) == Path.normalize(dest)) return;
			if (FileSystem.exists(dest)) FileSystem.deleteFile(dest);
			File.copy(archivePath, dest);
			if (sameDir) FileSystem.deleteFile(archivePath);
		}
		catch (e:Dynamic)
		{
			warnings.push('no se pudo guardar el original en ' + TMP_DIR + '/: ' + Std.string(e));
		}
	}
	#end

	#if sys
	static function readArchive(archivePath:String, warnings:Array<String>):Array<ArchiveFile>
	{
		var entries:List<haxe.zip.Entry> = null;
		var input = File.read(archivePath, true);
		try
		{
			entries = Reader.readZip(input);
		}
		catch (e:Dynamic)
		{
			input.close();
			throw 'not a readable zip: ' + Std.string(e);
		}
		input.close();

		var files:Array<ArchiveFile> = [];
		for (entry in entries)
		{
			var name = StringTools.replace(entry.fileName, "\\", "/");
			if (StringTools.endsWith(name, "/")) continue;
			var base = Path.withoutDirectory(name);
			if (StringTools.startsWith(name, "__MACOSX/") || StringTools.startsWith(base, "._") || base == ".DS_Store" || base == "Thumbs.db") continue;
			var relative = sanitize(name);
			if (relative == null)
			{
				warnings.push('skipped unsafe path: ' + entry.fileName);
				continue;
			}
			files.push(new ArchiveFile(relative, entry));
		}

		// Si todo el zip cuelga de una sola carpeta ("Fertility/chart.json"), se le quita.
		var root = commonRoot(files);
		if (root != "") for (file in files) file.path = file.path.substr(root.length);
		return files;
	}

	static function commonRoot(files:Array<ArchiveFile>):String
	{
		if (files.length == 0) return "";
		var first = files[0].path.split("/");
		if (first.length < 2) return "";
		var root = first[0];
		for (file in files)
		{
			var parts = file.path.split("/");
			if (parts.length < 2 || parts[0] != root) return "";
		}
		return root + "/";
	}
	#end

	static function describe(files:Array<ArchiveFile>):String
	{
		var names = [for (file in files) file.path];
		names.sort(Reflect.compare);
		var shown = names.slice(0, 10);
		return shown.join(", ") + (names.length > shown.length ? ' (+' + (names.length - shown.length) + ' mas)' : "");
	}

	static function findByName(files:Array<ArchiveFile>, name:String):Null<ArchiveFile>
	{
		var best:Null<ArchiveFile> = null;
		var bestDepth = 1000;
		for (file in files)
		{
			var lower = file.path.toLowerCase();
			if (StringTools.startsWith(lower, "sprites/") || basename(lower) != name) continue;
			var depth = file.path.split("/").length;
			if (depth < bestDepth)
			{
				best = file;
				bestDepth = depth;
			}
		}
		return best;
	}

	/** `chart.json` si existe; si no, cualquier JSON (fuera de sprites/) que tenga pinta de chart. */
	static function findChart(files:Array<ArchiveFile>):Null<FoundChart>
	{
		var candidates:Array<ArchiveFile> = [];
		for (file in files)
		{
			var lower = file.path.toLowerCase();
			if (Path.extension(lower) == "json" && !StringTools.startsWith(lower, "sprites/") && RESERVED_JSON.indexOf(basename(lower)) < 0)
				candidates.push(file);
		}
		candidates.sort(function(a, b)
		{
			var ca = chartRank(basename(a.path.toLowerCase()));
			var cb = chartRank(basename(b.path.toLowerCase()));
			if (ca != cb) return ca - cb;
			return a.path.split("/").length - b.path.split("/").length;
		});
		for (candidate in candidates)
		{
			var parsed = parseJson(candidate);
			if (parsed != null && looksLikeChart(parsed)) return {path: candidate.path, parsed: parsed};
		}
		return null;
	}

	/** 0 = chart.json, 1 = data.json (formato FNMM), 2 = cualquier otro. */
	static function chartRank(name:String):Int
		return name == CHART_FILE ? 0 : (name == DATA_FILE ? 1 : 2);

	static function looksLikeChart(value:Dynamic):Bool
	{
		if (Std.isOfType(value, Array)) return true;
		if (!isRecord(value)) return false;
		if (Std.isOfType(Reflect.field(value, "strumLines"), Array)) return true;
		if (Std.isOfType(Reflect.field(value, "notes"), Array)) return true;
		return isRecord(Reflect.field(value, "song"));
	}

	static function parseJson(file:ArchiveFile):Dynamic
	{
		var raw = file.bytes().toString();
		if (raw.length > 0 && raw.charCodeAt(0) == 0xFEFF) raw = raw.substr(1);
		try
		{
			return Json.parse(raw);
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}

	static function parseChart(root:Dynamic, meta:Dynamic, bpm:Float, warnings:Array<String>):Array<RawNote>
	{
		var out:Array<RawNote> = [];
		var stepMs = 60000 / bpm / 4;

		if (Std.isOfType(root, Array))
		{
			for (item in (cast root:Array<Dynamic>)) pushAny(out, item, 1, stepMs, null);
			return out;
		}
		if (!isRecord(root))
		{
			warnings.push("chart root is neither an array nor an object");
			return out;
		}

		var unit = unitOf(root, meta);

		var strumLines = Reflect.field(root, "strumLines");
		if (Std.isOfType(strumLines, Array))
		{
			var lines:Array<Dynamic> = cast strumLines;
			var nextExtra = 2;
			for (index in 0...lines.length)
			{
				var line = lines[index];
				if (isLaneList(line))
				{
					// Formato FNMM (data.json): strumLines[strumLine][lane] = [{start, duration, props}].
					// `start`/`duration` van en SEGUNDOS (comprobado contra el audio; el `bpm` del archivo
					// es solo para el pulso visual). 0 = jugador, 1 = oponente.
					var lanes:Array<Dynamic> = cast line;
					var factor = msPerUnit(unit == null ? DATA_TIME_UNIT : unit, bpm);
					for (laneIndex in 0...lanes.length)
					{
						for (note in (cast lanes[laneIndex]:Array<Dynamic>))
						{
							if (!isRecord(note) || !Reflect.hasField(note, "start")) continue;
							var length = fieldNumber(note, "duration", 0) * factor;
							out.push({t: fieldNumber(note, "start", 0) * factor, lane: laneIndex, len: length > 0 ? length : 0, mustPress: index == 0, line: index,
								onPress: packIndex(note, ["onPressEvent", "onPress"]), onMiss: packIndex(note, ["onMissEvent", "onMiss"])});
						}
					}
				}
				else if (Std.isOfType(line, Array))
				{
					// Formato del editor FMCE: 0 = jugador, 1 = oponente, 2+ = extras, en beats salvo que diga otra cosa.
					var factor = msPerUnit(unit == null ? DATA_TIME_UNIT : unit, bpm);
					var first = out.length;
					for (item in (cast line:Array<Dynamic>)) pushAny(out, item, factor, stepMs, index == 0);
					for (i in first...out.length) out[i].line = index;
				}
				else if (isRecord(line) && Std.isOfType(Reflect.field(line, "notes"), Array))
				{
					// Formato Codename: `type` 0 oponente, 1 jugador, 2 extra.
					var type = Reflect.hasField(line, "type") ? Std.int(number(Reflect.field(line, "type"), 0)) : (index == 1 ? 1 : 0);
					var factor = msPerUnit(unit == null ? "ms" : unit, bpm);
					var first = out.length;
					for (item in (cast Reflect.field(line, "notes"):Array<Dynamic>)) pushAny(out, item, factor, stepMs, type == 1);

					// type 2 = extra: va a su propia strumline (2, 3, ...) sin mezclarse con jugador/oponente
					if (type == 2)
					{
						var assigned = nextExtra++;
						for (i in first...out.length) out[i].line = assigned;
					}
				}
			}
			return out;
		}

		var notes = Reflect.field(root, "notes");
		if (Std.isOfType(notes, Array))
		{
			var factor = msPerUnit(unit == null ? "ms" : unit, bpm);
			for (item in (cast notes:Array<Dynamic>)) pushAny(out, item, factor, stepMs, null);
			// Sin unidad declarada, 40+ notas que acaban antes de 1 s solo pueden estar en beats.
			if (unit == null && looksLikeBeats(out))
			{
				var rescale = 60000 / bpm;
				for (note in out)
				{
					note.t *= rescale;
					note.len *= rescale;
				}
				warnings.push("los tiempos parecian beats (sin timeUnit); convertidos a ms con " + bpm + " bpm");
			}
			return out;
		}

		var song = Reflect.field(root, "song");
		if (isRecord(song)) return parseChart(song, meta, bpm, warnings);

		warnings.push('chart has no "strumLines", "notes" or "song" field');
		return out;
	}

	/**
	 * `true` si la strumline es una lista de lanes (`[[nota, ...], [nota, ...], ...]`, notas como
	 * objetos o lanes vacios), y no una lista plana de notas (`[t, lane, len]` o `{time, lane}`).
	 */
	static function isLaneList(line:Dynamic):Bool
	{
		if (!Std.isOfType(line, Array)) return false;
		var items:Array<Dynamic> = cast line;
		if (items.length == 0) return false;
		for (item in items)
		{
			if (!Std.isOfType(item, Array)) return false;
			var inner:Array<Dynamic> = cast item;
			if (inner.length > 0 && !isRecord(inner[0])) return false;
		}
		return true;
	}

	static function pushAny(out:Array<RawNote>, value:Dynamic, factor:Float, stepMs:Float, mustPress:Null<Bool>):Void
	{
		if (Std.isOfType(value, Array))
		{
			var values:Array<Dynamic> = cast value;
			if (values.length < 2) return;
			var lane = Std.int(number(values[1], 0));
			if (lane < 0) return;
			var length = values.length > 2 ? number(values[2], 0) * factor : 0;
			out.push({t: number(values[0], 0) * factor, lane: lane, len: length > 0 ? length : 0, mustPress: mustPress});
			return;
		}
		if (!isRecord(value)) return;

		if (Reflect.hasField(value, "sectionNotes"))
		{
			var sections = Reflect.field(value, "sectionNotes");
			if (Std.isOfType(sections, Array)) for (note in (cast sections:Array<Dynamic>)) pushAny(out, note, factor, stepMs, mustPress);
			return;
		}
		if (!Reflect.hasField(value, "strumTime") && !Reflect.hasField(value, "time")) return;

		var lane = Std.int(fieldNumber(value, "lane", fieldNumber(value, "data", fieldNumber(value, "id", 0))));
		if (lane < 0) return;
		var length = fieldNumber(value, "length", fieldNumber(value, "sustainLength", 0)) * factor;
		if (!Reflect.hasField(value, "length") && !Reflect.hasField(value, "sustainLength") && Reflect.hasField(value, "sLen"))
			length = fieldNumber(value, "sLen", 0) * stepMs;
		var press = mustPress;
		if (press == null && Reflect.hasField(value, "mustPress")) press = Reflect.field(value, "mustPress") == true;
		out.push({
			t: fieldNumber(value, "strumTime", fieldNumber(value, "time", 0)) * factor,
			lane: lane,
			len: length > 0 ? length : 0,
			mustPress: press,
			onPress: packIndex(value, ["onPressEvent", "onPress"]),
			onMiss: packIndex(value, ["onMissEvent", "onMiss"])
		});
	}

	static function looksLikeBeats(notes:Array<RawNote>):Bool
	{
		if (notes.length < 40) return false;
		var end = 0.0;
		for (note in notes) end = Math.max(end, note.t + note.len);
		return end < 1000;
	}

	/** Milisegundos que dura una unidad de tiempo del chart. */
	static function msPerUnit(unit:String, bpm:Float):Float
	{
		return switch (unit.toLowerCase())
		{
			case "beats" | "beat": 60000 / bpm;
			case "steps" | "step": 60000 / bpm / 4;
			case "seconds" | "second" | "s": 1000;
			default: 1;
		};
	}

	static function unitOf(chart:Dynamic, meta:Dynamic):Null<String>
	{
		var unit = text(Reflect.field(chart, "timeUnit"), "");
		if (unit == "") unit = text(Reflect.field(meta, "timeUnit"), "");
		return unit == "" ? null : unit;
	}

	/**
	 * Lanes por strumline. Las notas sin `mustPress` vienen en el estilo Psych (jugador en la
	 * mitad baja), asi que el lane mas alto define cuanto mide cada mitad: 4 teclas llega a 7,
	 * 6 a 11 y 9 a 17. Las que ya traen `mustPress` usan el lane tal cual.
	 */
	static function detectLaneCount(raw:Array<RawNote>, metaLanes:Int):Int
	{
		var legacyMax = -1;
		var directMax = -1;
		for (note in raw)
		{
			if (note.mustPress == null) legacyMax = Std.int(Math.max(legacyMax, note.lane));
			else directMax = Std.int(Math.max(directMax, note.lane));
		}
		var count = Math.max(1, metaLanes);
		if (legacyMax >= 0) count = Math.max(count, Math.floor((legacyMax + 1) / 2));
		if (directMax >= 0) count = Math.max(count, Math.max(4, directMax + 1));
		return Std.int(Math.min(count, 9));
	}

	/**
	 * Indice de action pack de una nota. En el .fnmm viven en `note.props` (`{props: {onPressEvent: 0.0, onMissEvent: -1.0}, start, duration}`)
	 * como float, -1.0 = ninguno; tambien se acepta en la raiz de la nota. -1 si falta o no es valido.
	 */
	static function packIndex(note:Dynamic, names:Array<String>):Int
	{
		var props = Reflect.field(note, "props");
		for (name in names)
		{
			var value = isRecord(props) ? fieldNumber(props, name, -1) : -1;
			if (value < 0) value = fieldNumber(note, name, -1);
			if (value >= 0) return Std.int(value);
		}
		return -1;
	}

	static function mapNotes(raw:Array<RawNote>, laneCount:Int, result:ConversionResult):Array<Dynamic>
	{
		var legacyMax = -1;
		for (note in raw) if (note.mustPress == null) legacyMax = Std.int(Math.max(legacyMax, note.lane));
		var half = legacyMax >= 0 ? Std.int(Math.max(1, Math.floor((legacyMax + 1) / 2))) : laneCount;

		var out:Array<Dynamic> = [];
		for (note in raw)
		{
			var mustPress:Bool;
			var lane:Int;
			if (note.mustPress == null)
			{
				mustPress = note.lane < half;
				lane = note.lane % half;
			}
			else
			{
				mustPress = note.mustPress;
				lane = note.lane;
			}
			if (lane >= laneCount) lane = lane % laneCount;
			if (note.len > 0) result.sustains++;
			var entry:Dynamic = {time: note.t, lane: lane, length: note.len, mustPress: mustPress};
			if (note.line != null && note.line >= 2) Reflect.setField(entry, "line", note.line);
			if (note.onPress != null && note.onPress >= 0) Reflect.setField(entry, "onPress", note.onPress);
			if (note.onMiss != null && note.onMiss >= 0) Reflect.setField(entry, "onMiss", note.onMiss);
			out.push(entry);
		}
		out.sort(function(a, b) return a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		return out;
	}

	static function readName(chart:Dynamic, meta:Dynamic, fallback:String):String
	{
		var name = clean(text(Reflect.field(meta, "displayName"), ""), "");
		if (name == "" && isRecord(chart))
		{
			name = clean(text(Reflect.field(chart, "name"), ""), "");
			var song = Reflect.field(chart, "song");
			if (name == "") name = isRecord(song) ? clean(text(Reflect.field(song, "song"), ""), "") : clean(text(song, ""), "");
		}
		return name == "" ? fallback : name;
	}

	static function readBpm(chart:Dynamic, meta:Dynamic):Float
	{
		var candidates:Array<Dynamic> = [Reflect.field(meta, "bpm")];
		if (isRecord(chart))
		{
			candidates.push(Reflect.field(chart, "bpm"));
			var song = Reflect.field(chart, "song");
			if (isRecord(song)) candidates.push(Reflect.field(song, "bpm"));
			var chartMeta = Reflect.field(chart, "meta");
			if (isRecord(chartMeta)) candidates.push(Reflect.field(chartMeta, "bpm"));
		}
		for (candidate in candidates)
		{
			var value = number(candidate, 0);
			if (value > 0) return value;
		}
		return 120;
	}

	/** `Reflect.isObject` da true para Strings y Arrays; esto solo acepta objetos reales. */
	static function isRecord(value:Dynamic):Bool
		return value != null && Reflect.isObject(value) && !Std.isOfType(value, String) && !Std.isOfType(value, Array);

	static function text(value:Dynamic, fallback:String = ""):String
	{
		if (value == null) return fallback;
		var parsed = Std.string(value);
		return parsed == "null" ? fallback : parsed;
	}

	static function clean(value:String, fallback:String):String
	{
		var trimmed = StringTools.trim(value);
		return trimmed == "" ? fallback : trimmed;
	}

	static function isMusic(lower:String):Bool
	{
		return StringTools.startsWith(basename(lower), "music") || StringTools.startsWith(basename(lower), "inst");
	}

	static function basename(lower:String):String return Path.withoutDirectory(lower);

	static function sanitize(path:String):Null<String>
	{
		var clean = StringTools.replace(path, "\\", "/");
		while (StringTools.startsWith(clean, "./")) clean = clean.substr(2);
		if (clean.length == 0 || StringTools.startsWith(clean, "/")) return null;
		for (part in clean.split("/")) if (part == "..") return null;
		return clean;
	}

	static function fieldNumber(value:Dynamic, field:String, fallback:Float):Float
	{
		if (!Reflect.hasField(value, field)) return fallback;
		return number(Reflect.field(value, field), fallback);
	}

	static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	#if sys
	static function ensureDirectory(path:String):Void
	{
		if (path == "" || path == "." || FileSystem.exists(path)) return;
		ensureDirectory(Path.directory(path));
		FileSystem.createDirectory(path);
	}

	static function saveAsset(target:String, relative:String, bytes:Bytes):Void
	{
		var path = Path.join([target, relative]);
		ensureDirectory(Path.directory(path));
		File.saveBytes(path, bytes);
	}

	/** Json de un solo frame para un PNG suelto. El tamano se lee de la cabecera del PNG ya escrito en disco. */
	static function writeAsepriteStub(target:String, imagePath:String):Void
	{
		var pngPath = Path.join([target, imagePath]);
		var jsonPath = Path.withExtension(pngPath, "json");
		if (FileSystem.exists(jsonPath) || !FileSystem.exists(pngPath)) return;
		var header:Bytes = Bytes.alloc(24);
		var input = File.read(pngPath, true);
		try
		{
			input.readBytes(header, 0, 24);
		}
		catch (_:Dynamic) {}
		input.close();
		var width = readUInt32(header, 16);
		var height = readUInt32(header, 20);
		var frame = {
			frame: {x: 0, y: 0, w: width, h: height},
			rotated: false,
			trimmed: false,
			spriteSourceSize: {x: 0, y: 0, w: width, h: height},
			sourceSize: {w: width, h: height}
		};
		File.saveContent(jsonPath, Json.stringify({
			frames: {"frame_0": frame},
			meta: {app: "FMCE", image: Path.withoutDirectory(imagePath), size: {w: width, h: height}, scale: "1"}
		}, null, "\t"));
	}

	static function readUInt32(bytes:Bytes, offset:Int):Int
		return (bytes.get(offset) << 24) | (bytes.get(offset + 1) << 16) | (bytes.get(offset + 2) << 8) | bytes.get(offset + 3);
	#end
}
