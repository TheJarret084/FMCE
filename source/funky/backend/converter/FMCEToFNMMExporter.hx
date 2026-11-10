package funky.backend.converter;

import haxe.io.Bytes;
import haxe.io.Path;
import funky.backend.LevelArchive;
import funky.backend.chart.LevelLoader;
import funky.core.JsonLoose;
import funky.core.Paths;

#if sys
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import sys.FileSystem;
import sys.io.File;
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
	/** Todos los audios que se juntan en un solo `music` (`music/*` del nivel). Con mas de uno se mezclan. */
	var tracks:Array<String>;
	var ignored:Array<String>;
}

/** Nivel FMCE -> `.FNMM` (el inverso de `FNMMToFMCEConverter`). `data/` no se exporta. */
class FMCEToFNMMExporter
{
	public static inline var EXT:String = ".FNMM";
	public static inline var MAX_BITMAP:Int = 16384;
	/**
	 * Lado maximo de una tira. Una tira se queda a su resolucion completa mientras quepa en este limite; si no cabe (antes
	 * abortaba y dejaba el sprite sin `sprite.json`) se dibuja lo justo mas chica y el `scale` y el pivote del config se corrigen.
	 * Para celulares con texturas de 8192 px o menos, baja este numero.
	 */
	public static inline var FNMM_MAX_SIDE:Int = 16000;

	/**
	 * Colores de los PNG. 0 = sin perdida (paleta exacta si hay 256 o menos, RGBA si hay mas). 2..256 = si la imagen trae mas colores
	 * se cuantiza a una sola paleta global (mediana + k-means), como UPNG: el PNG pesa una fraccion y el 0 queda reservado para el
	 * transparente. Una imagen con 256 colores o menos sale igual en los dos modos.
	 */
	public static inline var PNG_COLORS:Int = 256;

	/**
	 * Limites de una tira de VIDEO (las de atlas usan FNMM_MAX_SIDE / MAX_PIXELS). El video se exporta a su fps real y al mayor tamano
	 * que entre en estos limites, sin pasar nunca del tamano original. 0 = sin limite propio (queda solo el de memoria de Haxe).
	 * 84800000 px = el area de una tira de 264920x320, que ya se sabe que funciona.
	 */
	public static inline var VIDEO_MAX_WIDTH:Int = 0;
	public static inline var VIDEO_MAX_HEIGHT:Int = 0;
	public static inline var VIDEO_MAX_PIXELS:Float = 84800000;
	/**
	 * Rango de fps de un video exportado. Dentro del rango se conservan todos los frames; uno de mas de 24 fps baja a 24 y uno de
	 * menos de 12 sube a 12 (frames repetidos). Menos frames = cada frame de la tira sale mas grande.
	 */
	public static inline var VIDEO_MIN_FPS:Float = 12;
	public static inline var VIDEO_MAX_FPS:Float = 24;

	/** PNG de un BitmapData con `PngHandler` (indexado, lo mas chico posible); si algo falla, con el codificador de OpenFL. */
	public static function encodePng(bitmap:BitmapData):Bytes
	{
		try
		{
			var raw:Bytes = bitmap.getPixels(bitmap.rect);
			return PngHandler.encodeArgb(raw, bitmap.width, bitmap.height, PNG_COLORS);
		}
		catch (e:Dynamic) {}
		return bitmap.encode(bitmap.rect, new PNGEncoderOptions(true));
	}

	/** Pixeles maximos de una tira de un atlas de Animate (memoria): si pasa, se dibuja mas chica. */
	public static inline var MAX_PIXELS:Float = 48000000;

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

	/** Calidad del OGG cuando hay que mezclar o convertir el audio (0 = chico, 1 = mejor). */
	public static inline var OGG_QUALITY:Float = 0.45;

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
		var out:FNMMExportPlan = {music: null, voices: null, tracks: [], ignored: []};
		#if sys
		var dir = levelPath(levelName);
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return out;

		var meta = readJson(Path.join([dir, "meta.json"]));
		out.music = findMusic(dir, meta == null ? null : Reflect.field(meta, "song"));
		out.voices = LevelLoader.findVoices(dir);
		out.tracks = findTracks(dir, out.music, out.voices);

		var entries = FileSystem.readDirectory(dir);
		entries.sort(Reflect.compare);
		for (entry in entries)
		{
			if (entry == "." || entry == ".." || LevelArchive.isBackup(entry)) continue;
			if (KEEP.indexOf(entry.toLowerCase()) >= 0) continue;
			var path = Path.join([dir, entry]);
			if (FileSystem.isDirectory(path)) collect(path, entry, out.ignored, out.tracks);
			else if (!isTrack(path, out.tracks)) out.ignored.push(entry);
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
	static function collect(abs:String, rel:String, out:Array<String>, skip:Array<String>):Void
	{
		var entries = FileSystem.readDirectory(abs);
		entries.sort(Reflect.compare);
		for (entry in entries)
		{
			if (entry == "." || entry == ".." || LevelArchive.isBackup(entry)) continue;
			var path = abs + "/" + entry;
			var name = rel + "/" + entry;
			if (FileSystem.isDirectory(path)) collect(path, name, out, skip);
			else if (!isTrack(path, skip)) out.push(name);
		}
	}

	static function isTrack(path:String, tracks:Array<String>):Bool
	{
		for (t in tracks)
			if (sameFile(path, t)) return true;
		return false;
	}

	/** El audio principal, las voces y todo lo que haya en `music/`: el FNMM tiene un solo `music`, asi que se juntan. */
	static function findTracks(dir:String, music:Null<String>, voices:Null<String>):Array<String>
	{
		var tracks:Array<String> = [];
		function push(path:Null<String>)
		{
			if (path != null && !isTrack(path, tracks)) tracks.push(path);
		}
		push(music);
		var folder = Path.join([dir, "music"]);
		if (FileSystem.exists(folder) && FileSystem.isDirectory(folder))
		{
			var files = FileSystem.readDirectory(folder);
			files.sort(Reflect.compare);
			for (file in files)
			{
				var path = Path.join([folder, file]);
				if (!FileSystem.isDirectory(path) && AUDIO.indexOf(Path.extension(file).toLowerCase()) >= 0) push(path);
			}
		}
		push(voices);
		return tracks;
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
