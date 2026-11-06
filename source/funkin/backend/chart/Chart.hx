package funkin.backend.chart;

import funkin.backend.chart.ChartData;
import funkin.backend.chart.EventsData;
import funky.backend.chart.LevelLoader;
import haxe.Json;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Puente entre el charter (ChartData) y los archivos de un nivel de FMCE. Un nivel tiene:
 *  - chart.json:  las notas. `strumLines` = una lista de {time, lane, length} por strumline, en segundos.
 *                 `fmceChart: true` marca que ya es de FMCE; si falta, `ChartNormalizer` detecta el tipo (FNMM, Codename,
 *                 Psych/Legacy, FNF) y lo convierte al cargar el nivel.
 *                 Es la unica dificultad base (la dificultad del juego es la velocidad de scroll).
 *  - events.json: los eventos GLOBALES (`events`, acciones agrupadas por tiempo) + `action_packs`.
 *                 No hay eventos locales ni charts/*.json.
 *  - meta.json:   bpm, stepsPerBeat, offset, displayName, color, stage, ...
 * Lo que el charter no conoce (campos extra, acciones de eventos desconocidas) se conserva tal cual al guardar.
 */
class Chart {
	public static inline var version:String = "fmce-1";

	public static var levelDir:String = null;
	/** Nombre de la carpeta del nivel (el que usa `AdvancedToolsState`). */
	public static var levelName(get, never):String;
	static function get_levelName():String return levelDir == null ? "" : Path.withoutDirectory(Path.removeTrailingSlashes(levelDir));
	public static var musicPath:String = null;
	/** `music/Voices.ogg` del nivel (opcional); null si no hay. */
	public static var voicesPath:String = null;
	/** `meta.offset` en ms (se suma a las notas al cargar y se resta al guardar). */
	public static var offsetMs:Float = 0;

	static var backedUp:Map<String, Bool> = new Map();

	// ───────────────────────── carga ─────────────────────────

	#if sys
	static function readJson(path:String):Dynamic {
		if (!FileSystem.exists(path)) return null;
		try return Json.parse(File.getContent(path)) catch (e:Dynamic) return null;
	}

	static function num(v:Dynamic, def:Float):Float {
		if (v == null) return def;
		var f = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? def : f;
	}

	public static function load(dir:String):ChartData {
		levelDir = dir;
		Paths.levelDir = dir;
		funky.core.Paths.currentLevel = dir;
		var lv = LevelLoader.loadFolder(dir);
		var meta:Dynamic = readJson(Path.join([dir, "meta.json"]));
		if (meta == null) meta = {};
		var rawChart:Dynamic = readJson(Path.join([dir, LevelLoader.CHART_FILE]));
		if (rawChart == null) rawChart = {};

		offsetMs = num(Reflect.field(meta, "offset"), 0);
		musicPath = lv.musicPath;
		voicesPath = lv.voicesPath;

		var lineCount = 2;
		for (n in lv.notes) {
			var line = n.line != null ? n.line : (n.mustPress ? 0 : 1);
			if (line + 1 > lineCount) lineCount = line + 1;
		}
		var keyCount = lv.laneCount > 0 ? lv.laneCount : 4;

		var icons:Dynamic = Reflect.field(meta, "icons");
		var strumLines:Array<ChartStrumLine> = [];
		for (i in 0...lineCount) {
			var type:ChartStrumLineType = i == 0 ? PLAYER : (i == 1 ? OPPONENT : ADDITIONAL);
			var icon:String = i == 0 ? lv.iconPlayer : (i == 1 ? lv.iconOpponent : null);
			strumLines.push({
				characters: [icon != null ? icon : (i == 0 ? "player" : "opponent")],
				type: type,
				notes: [],
				position: i == 0 ? "boyfriend" : (i == 1 ? "dad" : "girlfriend"),
				visible: true,
				strumScale: 1,
				strumSpacing: 1,
				vocalsSuffix: "",
				keyCount: keyCount
			});
		}
		for (n in lv.notes) {
			var line = n.line != null ? n.line : (n.mustPress ? 0 : 1);
			if (line < 0) continue;
			var cn:ChartNote = {time: n.time, id: n.lane, type: 0, sLen: n.length};
			if (n.onPress != null && n.onPress >= 0) cn.onPress = n.onPress;
			if (n.onMiss != null && n.onMiss >= 0) cn.onMiss = n.onMiss;
			strumLines[line].notes.push(cn);
		}

		var bpm:Float = lv.bpm > 0 ? lv.bpm : 120;
		var spb:Int = lv.stepsPerBeat != null && lv.stepsPerBeat > 0 ? Std.int(Math.round(lv.stepsPerBeat)) : 4;
		var chartMeta:ChartMetaData = {
			name: Path.withoutDirectory(Path.removeTrailingSlashes(dir)),
			displayName: lv.name,
			bpm: bpm,
			beatsPerMeasure: 4,
			stepsPerBeat: spb,
			needsVoices: voicesPath != null,
			instSuffix: "",
			vocalsSuffix: "",
			iconPlayer: lv.iconPlayer,
			iconOpponent: lv.iconOpponent
		};
		if (lv.color != null) {
			var c = flixel.util.FlxColor.fromString(lv.color);
			if (c != null) chartMeta.color = c;
		}

		var stage:String = Reflect.field(meta, "stage");
		var bookmarks:Array<ChartBookmark> = Reflect.field(rawChart, "bookmarks");

		return {
			strumLines: strumLines,
			events: loadEvents(dir),
			actionPacks: loadActionPacks(dir),
			meta: chartMeta,
			stage: stage != null ? stage : "scene",
			noteTypes: [],
			bookmarks: bookmarks != null ? bookmarks : [],
			chartVersion: version
		};
	}

	// ───────────────────────── eventos ─────────────────────────

	static function loadEvents(dir:String):Array<ChartEvent> {
		var out:Array<ChartEvent> = [];
		var raw:Dynamic = readJson(Path.join([dir, "events.json"]));
		if (raw == null) return out;
		var groups:Array<Dynamic> = Reflect.field(raw, "events");
		if (groups == null) return out;
		for (g in groups) {
			var t = num(Reflect.field(g, "time"), 0) * 1000;
			var actions:Array<Dynamic> = Reflect.field(g, "actions");
			if (actions == null) continue;
			for (a in actions) {
				var e = actionToEvent(a, t);
				if (e != null) out.push(e);
			}
		}
		out.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : 0));
		return out;
	}

	/** Una accion de events.json (`{type, props}`) -> evento del charter. Null si no tiene `type`. */
	static function actionToEvent(a:Dynamic, time:Float):Null<ChartEvent> {
		var type:String = Reflect.field(a, "type");
		if (type == null) return null;
		var props:Dynamic = Reflect.field(a, "props");
		var params:Array<Dynamic> = [];
		for (info in EventsData.getEventParams(type)) {
			var v:Dynamic = props != null ? Reflect.field(props, info.key) : null;
			// Niveles guardados con la clave vieja `chart` (antes el editor la usaba por error y perdia el valor real).
			if (v == null && props != null && type == "ObjectChartChange" && info.key == "strumLine") v = Reflect.field(props, "chart");
			params.push(v == null ? info.defValue : v);
		}
		var e:ChartEvent = {name: type, time: time, params: params};
		if (!EventsData.isKnown(type)) e.raw = a;
		return e;
	}

	/** Evento del charter -> accion de events.json (`{type, props}`). */
	static function eventToAction(e:ChartEvent):Dynamic {
		if (!EventsData.isKnown(e.name)) return e.raw;
		var props:Dynamic = {};
		for (i => info in EventsData.getEventParams(e.name)) {
			var v:Dynamic = i < e.params.length ? e.params[i] : info.defValue;
			if (v == null) v = info.defValue;
			Reflect.setField(props, info.key, switch (info.type) {
				case TInt(_, _, _) | TStrumLine | TActionPack | TObject | TObjectTransform | TObjectAnim | TCameraPoint: Std.int(v);
				default: v;
			});
		}
		return {type: e.name, props: props};
	}

	/** `action_packs` de events.json. */
	static function loadActionPacks(dir:String):Array<ChartActionPack> {
		var out:Array<ChartActionPack> = [];
		var raw:Dynamic = readJson(Path.join([dir, "events.json"]));
		if (raw == null || Std.isOfType(raw, Array)) return out;
		var packs:Array<Dynamic> = Reflect.field(raw, "action_packs");
		if (packs == null) return out;
		for (p in packs) {
			var actions:Array<Dynamic> = p == null ? null : Reflect.field(p, "actions");
			var pack:ChartActionPack = {actions: []};
			if (actions != null)
				for (a in actions) {
					var e = actionToEvent(a, 0);
					if (e != null) pack.actions.push(e);
				}
			var name:String = p == null ? null : Reflect.field(p, "name");
			if (name != null) pack.name = name;
			out.push(pack);
		}
		return out;
	}

	/** Packs del charter -> `action_packs` de events.json. */
	public static function actionPacksToJson(packs:Array<ChartActionPack>):Array<Dynamic> {
		if (packs == null) return [];
		return [for (p in packs) {
			var o:Dynamic = {actions: [for (e in p.actions) if (e != null) {var a = eventToAction(e); if (a != null) a;}]};
			if (p.name != null && p.name != "") Reflect.setField(o, "name", p.name);
			o;
		}];
	}

	/** Eventos del charter -> grupos por tiempo de events.json. Las acciones desconocidas vuelven tal cual por `raw`. */
	public static function eventsToJson(events:Array<ChartEvent>):Array<Dynamic> {
		var sorted = [for (e in events) if (e != null) e];
		sorted.sort((x, y) -> x.time < y.time ? -1 : (x.time > y.time ? 1 : 0));
		var groups:Array<Dynamic> = [];
		var last:Dynamic = null;
		var lastT = Math.NaN;
		for (e in sorted) {
			var action:Dynamic = eventToAction(e);
			if (action == null) continue;
			var t = round6(e.time / 1000);
			if (last != null && t == lastT) (last.actions : Array<Dynamic>).push(action);
			else {
				last = {actions: [action], time: t};
				lastT = t;
				groups.push(last);
			}
		}
		return groups;
	}

	// ───────────────────────── guardado ─────────────────────────

	static inline function round6(v:Float):Float
		return Math.round(v * 1000000) / 1000000;

	/** Copia `.bak` del archivo, una sola vez por sesion (antes de la primera escritura). */
	static function backup(path:String):Void {
		if (backedUp.exists(path) || !FileSystem.exists(path)) return;
		File.copy(path, path + ".bak");
		backedUp.set(path, true);
	}

	static function write(path:String, data:Dynamic, pretty:Bool):Void {
		backup(path);
		File.saveContent(path, Json.stringify(data, null, pretty ? "\t" : null));
	}

	/**
	 * `fresh` encima de lo que ya hay en el archivo. `owned` son los campos que el charter reescribe por completo
	 * (si `fresh` no los trae, se borran); el resto de campos del archivo se conservan tal cual.
	 */
	static function merge(path:String, fresh:Dynamic, owned:Array<String>):Dynamic {
		var out:Dynamic = {};
		var original:Dynamic = readJson(path);
		if (original != null && !Std.isOfType(original, Array))
			for (f in Reflect.fields(original))
				if (owned.indexOf(f) < 0) Reflect.setField(out, f, Reflect.field(original, f));
		for (f in Reflect.fields(fresh)) Reflect.setField(out, f, Reflect.field(fresh, f));
		return out;
	}

	static inline function levelFile(name:String):String
		return Path.join([levelDir, name]);

	/** chart.json: las notas en segundos (sin el `meta.offset`) y los bookmarks. La velocidad ya no vive en el chart (la fija la dificultad). */
	public static function saveChart(song:ChartData, pretty:Bool = true):Void {
		var lines:Array<Array<Dynamic>> = [];
		for (sl in song.strumLines) {
			var notes = sl.notes.copy();
			notes.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : (a.id - b.id)));
			lines.push([
				for (n in notes) {
					var o:Dynamic = {time: round6((n.time - offsetMs) / 1000), lane: n.id};
					if (n.sLen > 0) Reflect.setField(o, "length", round6(n.sLen / 1000));
					if (n.onPress != null && n.onPress >= 0) Reflect.setField(o, "onPress", n.onPress);
					if (n.onMiss != null && n.onMiss >= 0) Reflect.setField(o, "onMiss", n.onMiss);
					o;
				}
			]);
		}
		var fresh:Dynamic = {fmceChart: true, timeUnit: "seconds", strumLines: lines};
		if (song.bookmarks != null && song.bookmarks.length > 0) Reflect.setField(fresh, "bookmarks", song.bookmarks);
		var path = levelFile(LevelLoader.CHART_FILE);
		write(path, merge(path, fresh, ["notes", "strumLines", "timeUnit", "scrollSpeed", "bookmarks"]), pretty);
	}

	/** events.json: los eventos globales y los action_packs. */
	public static function saveEvents(song:ChartData, pretty:Bool = true):Void {
		var fresh:Dynamic = {events: eventsToJson(song.events), action_packs: actionPacksToJson(song.actionPacks)};
		var path = levelFile("events.json");
		write(path, merge(path, fresh, ["events", "action_packs"]), pretty);
	}

	/** meta.json: bpm, pasos por beat, nombre, color y escena. */
	public static function saveMeta(song:ChartData):Void {
		var fresh:Dynamic = {};
		var meta = song.meta;
		if (meta != null) {
			if (meta.bpm != null) Reflect.setField(fresh, "bpm", meta.bpm);
			if (meta.stepsPerBeat != null) Reflect.setField(fresh, "stepsPerBeat", meta.stepsPerBeat);
			if (meta.displayName != null) Reflect.setField(fresh, "displayName", meta.displayName);
			if (meta.color != null) Reflect.setField(fresh, "color", "#" + StringTools.hex(((meta.color : Int) & 0xFFFFFF), 6));
			saveIcons(fresh, meta);
		}
		if (song.stage != null) Reflect.setField(fresh, "stage", song.stage);
		var path = levelFile("meta.json");
		write(path, merge(path, fresh, []), true);
	}

	/** `icons.P1` / `icons.P2` de meta.json. Se parte del `icons` que ya hay para no perder otras llaves. */
	static function saveIcons(fresh:Dynamic, meta:ChartMetaData):Void {
		if (meta.iconPlayer == null && meta.iconOpponent == null) return;
		var old:Dynamic = Reflect.field(readJson(levelFile("meta.json")), "icons");
		var icons:Dynamic = {};
		if (old != null && !Std.isOfType(old, Array))
			for (f in Reflect.fields(old)) Reflect.setField(icons, f, Reflect.field(old, f));
		// null = no se toco; "" = el charter lo dejo en (none) y se quita del meta.json
		if (meta.iconPlayer == "") Reflect.deleteField(icons, "P1");
		else if (meta.iconPlayer != null) Reflect.setField(icons, "P1", meta.iconPlayer);
		if (meta.iconOpponent == "") Reflect.deleteField(icons, "P2");
		else if (meta.iconOpponent != null) Reflect.setField(icons, "P2", meta.iconOpponent);
		Reflect.setField(fresh, "icons", icons);
	}

	public static function saveAll(song:ChartData, pretty:Bool = true):Void {
		saveChart(song, pretty);
		saveEvents(song, pretty);
		saveMeta(song);
	}
	#end
}
