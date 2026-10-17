package funkin.backend.chart;

import funkin.backend.chart.ChartData;
import haxe.Json;

typedef ImportResult = {
	/** "fnmm" (data.json de un .fnmm), "codename", "legacy" (Psych/Legacy `song.notes[]`) o "fmce". */
	var format:String;
	/** Indice 0 = jugador, 1 = oponente, 2+ = extras (el orden de FMCE). */
	var lines:Array<Array<ChartNote>>;
	var scrollSpeed:Null<Float>;
	/** BPM que declara el archivo (solo Legacy). Las notas ya estan en ms, asi que solo sirve para avisar. */
	var bpm:Null<Float>;
	var notes:Int;
	var sustains:Int;
	/** Notas que caen en carriles >= `lanes` (los carriles del nivel abierto). */
	var droppedLanes:Int;
	/** Eventos del archivo: viven en events.json y usan otros nombres, no se importan. */
	var droppedEvents:Int;
	/** Notas repetidas (mismo tiempo y carril en la misma strumline) que se descartaron. */
	var duplicates:Int;
	/** Carriles del nivel abierto. */
	var lanes:Int;
}

/**
 * Lee charts de otros motores y los deja como notas de FMCE (strumlines con `ChartNote`).
 * Los tiempos de los tres formatos ya vienen en ms, asi que no hace falta BPM para convertirlos.
 */
class ChartImporter {
	public static function detect(raw:Dynamic):Null<String> {
		if (raw == null || Std.isOfType(raw, Array)) return null;
		var sl:Dynamic = Reflect.field(raw, "strumLines");
		if (Std.isOfType(sl, Array)) {
			var arr:Array<Dynamic> = sl;
			// FNMM: strumLines[strumline][lane] = [{start, duration}]. FMCE: strumLines[strumline] = [{time, lane, length}].
			for (l in arr) {
				if (!Std.isOfType(l, Array)) continue;
				var items:Array<Dynamic> = l;
				if (items.length > 0) return Std.isOfType(items[0], Array) ? "fnmm" : "fmce";
			}
			if (arr.length > 0 && Std.isOfType(arr[0], Array)) return "fmce";
			if (arr.length > 0 && Reflect.hasField(arr[0], "notes")) return "codename";
		}
		var song:Dynamic = Reflect.hasField(raw, "song") && !Std.isOfType(Reflect.field(raw, "song"), String) ? Reflect.field(raw, "song") : raw;
		if (Std.isOfType(Reflect.field(song, "notes"), Array)) return "legacy";
		return null;
	}

	/** Lanza un String con el motivo si el archivo no es un chart reconocible. */
	public static function parse(text:String, lanes:Int = 4):ImportResult {
		var raw:Dynamic = try Json.parse(text) catch (e:Dynamic) throw "No es un JSON valido.";
		var format = detect(raw);
		if (format == null) throw "Formato no reconocido (no es un chart de FNMM, Codename, Legacy/Psych ni FMCE).";
		var res:ImportResult = {format: format, lines: [], scrollSpeed: null, bpm: null, notes: 0, sustains: 0, droppedLanes: 0, droppedEvents: 0, duplicates: 0, lanes: lanes};
		switch (format) {
			case "fnmm": fromFNMM(raw, res);
			case "codename": fromCodename(raw, res);
			case "legacy": fromLegacy(raw, res);
			default: fromFMCE(raw, res);
		}
		for (l in res.lines) {
			// sin repetidas: mismo tiempo (al ms) y carril
			var seen:Map<String, Bool> = new Map();
			var kept:Array<ChartNote> = [];
			for (n in l) {
				var key = Math.round(n.time) + ":" + n.id;
				if (seen.exists(key)) {res.duplicates++; continue;}
				seen.set(key, true);
				kept.push(n);
			}
			l.resize(0);
			for (n in kept) {
				l.push(n);
				res.notes++;
				if (n.sLen > 0) res.sustains++;
			}
		}
		return res;
	}

	static function line(res:ImportResult, i:Int):Array<ChartNote> {
		while (res.lines.length <= i) res.lines.push([]);
		return res.lines[i];
	}

	static function add(res:ImportResult, lineIdx:Int, time:Float, lane:Int, sLen:Float):Void {
		if (lane < 0 || time < 0 || Math.isNaN(time)) return;
		if (lane >= res.lanes) {res.droppedLanes++; return;}
		line(res, lineIdx).push({time: time, id: lane, type: 0, sLen: sLen > 0 ? sLen : 0});
	}

	static function f(v:Dynamic, def:Float = 0):Float {
		var n = Std.parseFloat(Std.string(v));
		return Math.isNaN(n) ? def : n;
	}

	// ───────────── Codename: strumLines[{type, position, keyCount, notes[{id,time,sLen,type}]}] ─────────────
	static function fromCodename(raw:Dynamic, res:ImportResult):Void {
		var strums:Array<Dynamic> = Reflect.field(raw, "strumLines");
		// 0 = oponente, 1 = jugador, 2 = adicional en Codename. FMCE: 0 jugador, 1 oponente, 2+ extras.
		function isPlayer(s:Dynamic) return Reflect.field(s, "type") == 1;
		function isOpponent(s:Dynamic) return Reflect.field(s, "type") == 0;
		var player = Lambda.find(strums, isPlayer);
		if (player == null) player = Lambda.find(strums, s -> Reflect.field(s, "position") == "boyfriend");
		var opponent = Lambda.find(strums, s -> s != player && isOpponent(s) && Reflect.field(s, "position") != "girlfriend");
		if (opponent == null) opponent = Lambda.find(strums, s -> s != player && isOpponent(s));
		var order:Array<Dynamic> = [player, opponent];
		for (s in strums) if (s != player && s != opponent) order.push(s);

		for (i => s in order) {
			line(res, i);
			if (s == null) continue;
			var notes:Array<Dynamic> = Reflect.field(s, "notes");
			if (notes != null) for (n in notes) add(res, i, f(Reflect.field(n, "time")), Std.int(f(Reflect.field(n, "id"), -1)), f(Reflect.field(n, "sLen")));
		}
		res.scrollSpeed = Reflect.hasField(raw, "scrollSpeed") ? f(Reflect.field(raw, "scrollSpeed")) : null;
		var ev:Array<Dynamic> = Reflect.field(raw, "events");
		res.droppedEvents = ev == null ? 0 : ev.length;
	}

	// ───────────── Legacy / Psych: song.notes[{sectionNotes:[[t,lane,sus,...]], mustHitSection}] ─────────────
	static function fromLegacy(raw:Dynamic, res:ImportResult):Void {
		var song:Dynamic = Reflect.hasField(raw, "song") && !Std.isOfType(Reflect.field(raw, "song"), String) ? Reflect.field(raw, "song") : raw;
		var keys = Std.int(f(Reflect.field(song, "keys"), 4));
		if (keys < 1) keys = 4;
		var sections:Array<Dynamic> = Reflect.field(song, "notes");
		line(res, 0); line(res, 1);
		for (sec in sections) {
			var notes:Array<Dynamic> = Reflect.field(sec, "sectionNotes");
			if (notes == null) continue;
			var mustHit = Reflect.field(sec, "mustHitSection") == true;
			for (n in notes) {
				var arr:Array<Dynamic> = n;
				if (arr.length < 2) continue;
				var raw_lane = Std.int(f(arr[1], -1));
				if (raw_lane < 0) continue;
				var group = Std.int(raw_lane / keys);
				var lineIdx = group < 2 ? ((group == 0) == mustHit ? 0 : 1) : group;
				add(res, lineIdx, f(arr[0]), raw_lane % keys, arr.length > 2 ? f(arr[2]) : 0);
			}
		}
		res.scrollSpeed = Reflect.hasField(song, "speed") ? f(Reflect.field(song, "speed")) : null;
		res.bpm = Reflect.hasField(song, "bpm") ? f(Reflect.field(song, "bpm")) : null;
		var ev:Array<Dynamic> = Reflect.field(song, "events");
		if (ev != null) for (e in ev) {
			var inner:Array<Dynamic> = Std.isOfType(e, Array) && (e:Array<Dynamic>).length > 1 && Std.isOfType((e:Array<Dynamic>)[1], Array) ? (e:Array<Dynamic>)[1] : null;
			res.droppedEvents += inner != null ? inner.length : 1;
		}
	}

	// ───────────── FNMM: data.json de un .fnmm, tiempos en segundos ─────────────
	static function fromFNMM(raw:Dynamic, res:ImportResult):Void {
		var unit:String = Reflect.field(raw, "timeUnit");
		var mul = unit == "milliseconds" || unit == "ms" ? 1.0 : 1000.0;
		var lines:Array<Array<Dynamic>> = Reflect.field(raw, "strumLines");
		for (i => l in lines) {
			line(res, i);
			if (!Std.isOfType(l, Array)) continue;
			for (lane => notes in l) {
				if (!Std.isOfType(notes, Array)) continue;
				for (n in (cast notes:Array<Dynamic>))
					if (Reflect.hasField(n, "start")) add(res, i, f(Reflect.field(n, "start")) * mul, lane, f(Reflect.field(n, "duration")) * mul);
			}
		}
	}

	// ───────────── FMCE (por si se vuelve a importar un chart propio) ─────────────
	static function fromFMCE(raw:Dynamic, res:ImportResult):Void {
		var unit:String = Reflect.field(raw, "timeUnit");
		var mul = unit == "milliseconds" || unit == "ms" ? 1.0 : 1000.0;
		var lines:Array<Array<Dynamic>> = Reflect.field(raw, "strumLines");
		for (i => l in lines) {
			line(res, i);
			for (n in l) add(res, i, f(Reflect.field(n, "time")) * mul, Std.int(f(Reflect.field(n, "lane"), -1)), f(Reflect.field(n, "length")) * mul);
		}
		res.scrollSpeed = Reflect.hasField(raw, "scrollSpeed") ? f(Reflect.field(raw, "scrollSpeed")) : null;
	}
}
