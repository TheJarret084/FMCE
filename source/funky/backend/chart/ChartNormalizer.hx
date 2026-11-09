package funky.backend.chart;

import funkin.backend.chart.ChartImporter;
import funky.core.Log;
import haxe.Json;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Deja `chart.json` en el formato del engine antes de que lo lea el juego o el charter. */
class ChartNormalizer
{
	public static inline var FLAG:String = "fmceChart";
	public static inline var BACKUP_FILE:String = "chart.orig.json";

	/** Carriles maximos de un nivel (los mismos que acepta `LevelLoader`). */
	static inline var MAX_LANES:Int = 9;

	public static function isFmce(chart:Dynamic):Bool
		return chart != null && !Std.isOfType(chart, Array) && Reflect.field(chart, FLAG) == true;

	#if sys
	/** Devuelve el chart en formato FMCE (el mismo objeto si ya lo era). `chartPath` es el `chart.json` de `dir`. */
	public static function ensure(dir:String, chartPath:String, chart:Dynamic, meta:Dynamic):Dynamic
	{
		if (isFmce(chart)) return chart;

		var format = ChartImporter.detect(chart);
		if (format == null)
		{
			Log.warn('[ChartNormalizer] $chartPath: formato no reconocido (ni FMCE, ni FNMM, Codename, Psych/Legacy o FNF); se deja como esta');
			return chart;
		}

		// FMCE sin la marca (niveles viejos): la estructura ya es la buena, solo se marca.
		if (format == "fmce")
		{
			Reflect.setField(chart, FLAG, true);
			save(chartPath, chart);
			Log.info('[ChartNormalizer] $chartPath: chart FMCE sin marca, se agrego "$FLAG": true');
			return chart;
		}

		var offset = number(Reflect.field(meta, "offset"), 0);
		var declared = Std.int(number(Reflect.field(meta, "lanes"), 0));
		var lanes = declared > 0 ? Std.int(Math.min(declared, MAX_LANES)) : MAX_LANES;

		var result = ChartImporter.parse(Json.stringify(chart), lanes);

		// Los campos que el loader sigue leyendo del chart (nombre, bpm, pasos por beat) se conservan.
		var out:Dynamic = {};
		Reflect.setField(out, FLAG, true);
		Reflect.setField(out, "timeUnit", "seconds");
		for (field in ["name", "bpm", "npb", "bookmarks"])
			if (Reflect.field(chart, field) != null) Reflect.setField(out, field, Reflect.field(chart, field));
		if (Reflect.field(out, "bpm") == null && result.bpm != null && result.bpm > 0) Reflect.setField(out, "bpm", result.bpm);

		// ChartImporter da ms absolutos; el archivo guarda segundos SIN el `meta.offset` (LevelLoader lo vuelve a sumar).
		var lines:Array<Array<Dynamic>> = [];
		for (line in result.lines)
		{
			var notes = line.copy();
			notes.sort((a, b) -> a.time < b.time ? -1 : (a.time > b.time ? 1 : (a.id - b.id)));
			lines.push([
				for (n in notes)
				{
					var entry:Dynamic = {time: round6((n.time - offset) / 1000), lane: n.id};
					if (n.sLen > 0) Reflect.setField(entry, "length", round6(n.sLen / 1000));
					entry;
				}
			]);
		}
		while (lines.length < 2) lines.push([]);
		Reflect.setField(out, "strumLines", lines);

		var original = Path.join([dir, BACKUP_FILE]);
		try
		{
			if (!FileSystem.exists(original)) File.copy(chartPath, original);
		}
		catch (e:Dynamic)
		{
			Log.warn('[ChartNormalizer] no se pudo guardar $BACKUP_FILE: ' + Std.string(e));
		}
		save(chartPath, out);

		var extra = [];
		if (result.difficulty != null) extra.push('dificultad "' + result.difficulty + '"' + (result.difficulties != null && result.difficulties.length > 1 ? ' de ' + result.difficulties.join("/") : ""));
		if (result.droppedLanes > 0) extra.push(result.droppedLanes + " notas fuera de los carriles");
		if (result.droppedEvents > 0) extra.push(result.droppedEvents + " eventos sin importar (viven en events.json)");
		if (result.duplicates > 0) extra.push(result.duplicates + " notas repetidas");
		Log.info('[ChartNormalizer] $chartPath: $format -> FMCE, ' + result.notes + ' notas' + (extra.length > 0 ? " (" + extra.join(", ") + ")" : ""));
		return out;
	}

	static function save(chartPath:String, chart:Dynamic):Void
	{
		try File.saveContent(chartPath, Json.stringify(chart, null, "\t"))
		catch (e:Dynamic) Log.warn('[ChartNormalizer] no se pudo escribir $chartPath (se usa en memoria): ' + Std.string(e));
	}
	#end

	static inline function round6(value:Float):Float
		return Math.round(value * 1000000) / 1000000;

	static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}
