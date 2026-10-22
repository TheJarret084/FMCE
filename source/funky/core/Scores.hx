package funky.core;

import haxe.Json;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Mejor puntaje de un nivel en una dificultad. */
typedef BestScore =
{
	var score:Int;
	var accuracy:Float;
	var misses:Int;
}

/**
 * Puntajes guardados por nivel y por dificultad (`scores.json` en la carpeta de datos del juego):
 * `{ "<nivel>": { "easy": {score, accuracy, misses}, "normal": {...}, ... } }`.
 * Solo se guarda el mejor de cada par nivel / dificultad.
 */
class Scores
{
	static var data:Dynamic = null;

	static function file():String
	{
		#if android
		return Storage.dataDirectory() + "/scores.json";
		#else
		return Path.join([Storage.dataDirectory(), Storage.path, "scores.json"]);
		#end
	}

	/** Id de un nivel a partir de su carpeta o archivo (`levels/N3RU/` -> `N3RU`). */
	public static function levelId(path:String):String
	{
		return Path.withoutExtension(Path.withoutDirectory(Path.removeTrailingSlashes(path)));
	}

	static function load():Void
	{
		if (data != null) return;
		data = {};

		#if sys
		try
		{
			var f = file();
			if (FileSystem.exists(f))
			{
				var parsed = Json.parse(File.getContent(f));
				if (parsed != null) data = parsed;
			}
		}
		catch (e:Dynamic)
		{
			Log.warn('[Scores] no se pudo leer scores.json: ' + Std.string(e));
		}
		#end
	}

	static function save():Void
	{
		#if sys
		try
		{
			var f = file();
			var dir = Path.directory(f);
			if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			File.saveContent(f, Json.stringify(data, null, "\t"));
		}
		catch (e:Dynamic)
		{
			Log.warn('[Scores] no se pudo guardar scores.json: ' + Std.string(e));
		}
		#end
	}

	/** Mejor puntaje del nivel en esa dificultad (indice de `Difficulty`), o null si nunca se jugo. */
	public static function get(level:String, difficulty:Int):Null<BestScore>
	{
		load();
		var entry:Dynamic = Reflect.field(data, level);
		if (entry == null) return null;
		var best:Dynamic = Reflect.field(entry, Difficulty.KEYS[difficulty]);
		if (best == null) return null;
		return {
			score: Std.int(best.score),
			accuracy: best.accuracy == null ? 0 : best.accuracy,
			misses: best.misses == null ? 0 : Std.int(best.misses)
		};
	}

	/** Guarda el resultado si supera al anterior. @return true si es un nuevo record. */
	public static function submit(level:String, difficulty:Int, score:Int, accuracy:Float, misses:Int):Bool
	{
		load();
		var previous = get(level, difficulty);
		if (previous != null && previous.score >= score) return false;

		var entry:Dynamic = Reflect.field(data, level);
		if (entry == null)
		{
			entry = {};
			Reflect.setField(data, level, entry);
		}
		Reflect.setField(entry, Difficulty.KEYS[difficulty], {
			score: score,
			accuracy: Math.round(accuracy * 100) / 100,
			misses: misses
		});
		save();
		Log.info('[Scores] nuevo record en $level (' + Difficulty.KEYS[difficulty] + '): $score');
		return true;
	}
}
