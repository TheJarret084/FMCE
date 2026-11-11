package funkin.backend.chart;

import funkin.backend.chart.ChartData;
import haxe.Json;

typedef ImportResult = {

	var format:String;

	var lines:Array<Array<ChartNote>>;

	var bpm:Null<Float>;
	var notes:Int;
	var sustains:Int;

	var droppedLanes:Int;

	var droppedEvents:Int;

	var duplicates:Int;

	var lanes:Int;

	var ?difficulties:Array<String>;
	var ?difficulty:String;

	var ?droppedKinds:Int;
}

class ChartImporter {
	public static function detect(raw:Dynamic):Null<String> {
		if (raw == null || Std.isOfType(raw, Array)) return null;
		var sl:Dynamic = Reflect.field(raw, "strumLines");
		if (Std.isOfType(sl, Array)) {
			var arr:Array<Dynamic> = sl;

			for (l in arr) {
				if (!Std.isOfType(l, Array)) continue;
				var items:Array<Dynamic> = l;
				if (items.length > 0) return Std.isOfType(items[0], Array) ? "fnmm" : "fmce";
			}
			if (arr.length > 0 && Std.isOfType(arr[0], Array)) return "fmce";
			if (arr.length > 0 && Reflect.hasField(arr[0], "notes")) return "codename";
		}

		var fnfNotes:Dynamic = Reflect.field(raw, "notes");
		if (fnfNotes != null && !Std.isOfType(fnfNotes, Array) && Reflect.isObject(fnfNotes) && Reflect.fields(fnfNotes).length > 0) return "fnf";
		var song:Dynamic = Reflect.hasField(raw, "song") && !Std.isOfType(Reflect.field(raw, "song"), String) ? Reflect.field(raw, "song") : raw;
		if (Std.isOfType(Reflect.field(song, "notes"), Array)) return "legacy";
		return null;
	}

	public static function parse(text:String, lanes:Int = 4, ?difficulty:String):ImportResult {
		var raw:Dynamic = try Json.parse(text) catch (e:Dynamic) throw "No es un JSON valido.";
		var format = detect(raw);
		if (format == null) throw "Formato no reconocido (no es un chart de FNMM, Codename, Legacy/Psych, FNF (.fnfc) ni FMCE).";
		var res:ImportResult = {format: format, lines: [], bpm: null, notes: 0, sustains: 0, droppedLanes: 0, droppedEvents: 0, duplicates: 0, lanes: lanes};
		switch (format) {
			case "fnmm": fromFNMM(raw, res);
			case "codename": fromCodename(raw, res);
			case "legacy": fromLegacy(raw, res);
			case "fnf": fromFNF(raw, res, difficulty);
			default: fromFMCE(raw, res);
		}
		for (l in res.lines) {

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

	static function fromCodename(raw:Dynamic, res:ImportResult):Void {
		var strums:Array<Dynamic> = Reflect.field(raw, "strumLines");

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
		var ev:Array<Dynamic> = Reflect.field(raw, "events");
		res.droppedEvents = ev == null ? 0 : ev.length;
	}

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
		res.bpm = Reflect.hasField(song, "bpm") ? f(Reflect.field(song, "bpm")) : null;
		var ev:Array<Dynamic> = Reflect.field(song, "events");
		if (ev != null) for (e in ev) {
			var inner:Array<Dynamic> = Std.isOfType(e, Array) && (e:Array<Dynamic>).length > 1 && Std.isOfType((e:Array<Dynamic>)[1], Array) ? (e:Array<Dynamic>)[1] : null;
			res.droppedEvents += inner != null ? inner.length : 1;
		}
	}

	static function fromFNF(raw:Dynamic, res:ImportResult, difficulty:Null<String>):Void {
		var all:Dynamic = Reflect.field(raw, "notes");
		var names:Array<String> = Reflect.fields(all);
		res.difficulties = names;
		var pick = difficulty != null && names.indexOf(difficulty) >= 0 ? difficulty : (names.indexOf("hard") >= 0 ? "hard" : names[names.length - 1]);
		res.difficulty = pick;
		res.droppedKinds = 0;

		line(res, 0); line(res, 1);
		var list:Array<Dynamic> = Reflect.field(all, pick);
		if (list != null) for (n in list) {
			var d = Std.int(f(Reflect.field(n, "d"), -1));
			if (d < 0) continue;
			if (Reflect.field(n, "k") != null && Std.string(Reflect.field(n, "k")) != "") res.droppedKinds++;
			add(res, Std.int(d / 4), f(Reflect.field(n, "t"), -1), d % 4, f(Reflect.field(n, "l")));
		}
		var ev:Array<Dynamic> = Reflect.field(raw, "events");
		res.droppedEvents = ev == null ? 0 : ev.length;
	}

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

	static function fromFMCE(raw:Dynamic, res:ImportResult):Void {
		var unit:String = Reflect.field(raw, "timeUnit");
		var mul = unit == "milliseconds" || unit == "ms" ? 1.0 : 1000.0;
		var lines:Array<Array<Dynamic>> = Reflect.field(raw, "strumLines");
		for (i => l in lines) {
			line(res, i);
			for (n in l) add(res, i, f(Reflect.field(n, "time")) * mul, Std.int(f(Reflect.field(n, "lane"), -1)), f(Reflect.field(n, "length")) * mul);
		}
	}
}
