package funky.backend.converter;

import haxe.io.Bytes;
import haxe.io.Path;
import funky.backend.FunkinVideoSprite;
import funky.core.JsonLoose;
import funky.core.Log;
#if sys
import sys.FileSystem;
import sys.io.File;
#end
#if sys
import funkfmpeg.FrameScale;
import funkfmpeg.FunkFMPEG;
import funkfmpeg.TapeOptions;
import funky.core.Storage;
#if !android
import sys.io.Process;
#end
#if target.threaded
import sys.thread.Deque;
import sys.thread.Thread;
#end
#end

/** Un video de `sprites/<nombre>/` en el orden en que el motor lo reproduce (`FunkinVideoSprite.videoFile`). */
typedef VideoClip =
{
	/** Ruta del .mp4, o null si el config.json lo menciona pero el archivo no existe. */
	var path:Null<String>;
	/** Entrada de `config.json` (`data[i]`); `{}` si no tiene. */
	var cfg:Dynamic;
}

typedef VideoInfo =
{
	/** Tamano con el que ffmpeg entrega los frames (ya con la rotacion aplicada). */
	var w:Int;
	var h:Int;
	var fps:Float;
	var seconds:Float;
}

/**
 * Video (.mp4) -> UNA tira horizontal de PNG indexado (frames pegados, sin huecos ni recortes) con FunkFMPEG.
 * El fps queda dentro de VIDEO_MIN_FPS..VIDEO_MAX_FPS (12..24).
 * Es lo que el .FNMM entiende: el FNMM no tiene video, pero una tira con `num` frames y `spd` = fps / 24 se ve igual.
 *
 * Los frames los saca ffmpeg en escritorio y `MediaMetadataRetriever` (source/java/org/fmce/VideoFrames.java, via `AndroidFrames`) en Android;
 * FunkFMPEG (Haxe puro) arma la tira igual en los dos.
 *
 * Cada frame se saca a su fps real si esta en el rango (nada de saltar frames) y al mayor tamano que entre en los limites de la tira
 * (`FMCEToFNMMExporter.VIDEO_MAX_*`), sin agrandar jamas el video.
 */
class VideoStrip
{
	/** ffmpeg usable: junto al .exe, o el que haya en el PATH. null si no hay (o en Android, donde no existe). */
	public static function findFfmpeg():Null<String>
	{
		#if (sys && !android)
		var exe = Sys.systemName() == "Windows" ? "ffmpeg.exe" : "ffmpeg";
		for (candidate in [Path.join([Storage.exeDirectory(), exe]), "ffmpeg"])
		{
			try
			{
				var p = new Process(candidate, ["-version"]);
				p.stderr.readAll();
				var code = p.exitCode();
				p.close();
				if (code == 0) return candidate;
			}
			catch (_:Dynamic) {}
		}
		#end
		return null;
	}

	/**
	 * Los videos de una carpeta de sprite, en el orden del motor: la entrada `i` de `config.json` es el video `i`
	 * (`anim` -> `<anim>.mp4`, o `video<i>.mp4`, o el `i`-esimo .mp4). Un .mp4 que el config no menciona NO se deja: va al final
	 * como una animacion mas.
	 */
	public static function clips(dir:String, warnings:Array<String>):Array<VideoClip>
	{
		var out:Array<VideoClip> = [];
		#if sys
		var files = FunkinVideoSprite.videoFiles(dir);
		var used = new Map<String, Bool>();
		var data = configData(dir);
		for (i in 0...data.length)
		{
			var file = FunkinVideoSprite.videoFile(dir, i);
			if (file != null) used.set(Path.normalize(file), true);
			out.push({path: file, cfg: data[i] == null ? {} : data[i]});
		}
		for (name in files)
		{
			var file = Path.join([dir, name]);
			if (used.exists(Path.normalize(file))) continue;
			if (data.length > 0) warnings.push("el video " + name + " no estaba en config.json: se exporta como la animacion " + out.length);
			out.push({path: file, cfg: {}});
		}
		#end
		return out;
	}

	#if sys
	static function configData(dir:String):Array<Dynamic>
	{
		var path = Path.join([dir, "config.json"]);
		if (!FileSystem.exists(path)) return [];
		try
		{
			var config:Dynamic = JsonLoose.parse(File.getContent(path));
			var data:Dynamic = config == null ? null : Reflect.field(config, "data");
			if (Std.isOfType(data, Array)) return cast data;
		}
		catch (e:Dynamic)
		{
			Log.warn('[VideoStrip] json invalido ($path): $e');
		}
		return [];
	}
	#end

	#if sys
	/** Opciones de FunkFMPEG para un video: el frame mas grande que quepa en los limites, paleta global de 256 colores. */
	public static function tapeOptions():TapeOptions
	{
		var o = new TapeOptions();
		o.scaleDivisor = 0;
		o.maxWidth = FMCEToFNMMExporter.VIDEO_MAX_WIDTH;
		o.maxHeight = FMCEToFNMMExporter.VIDEO_MAX_HEIGHT;
		#if android
		// la tira se arma en memoria (un buffer del tamano de la tira): en el telefono no pasa del tope de las tiras de atlas
		o.maxPixels = Math.min(FMCEToFNMMExporter.VIDEO_MAX_PIXELS, FMCEToFNMMExporter.MAX_PIXELS);
		#else
		o.maxPixels = FMCEToFNMMExporter.VIDEO_MAX_PIXELS;
		#end
		o.colors = 256;
		o.compression = 9;
		o.refine = 4;
		o.keepAlpha = false;
		o.background = 0x000000;
		return o;
	}

	#if !android
	/** Tamano, fps y duracion del video, leidos con ffmpeg (copia de flujo: no decodifica nada, es instantaneo). */
	public static function probe(ffmpeg:String, path:String):Null<VideoInfo>
	{
		var text = "";
		try
		{
			var p = new Process(ffmpeg, ["-hide_banner", "-nostdin", "-i", path, "-map", "0:v:0", "-c", "copy", "-f", "null", "-"]);
			p.stdout.readAll();
			text = p.stderr.readAll().toString();
			p.exitCode();
			p.close();
		}
		catch (e:Dynamic)
		{
			Log.warn('[VideoStrip] ffmpeg no pudo leer $path: $e');
		}
		return parseProbe(text, path);
	}

	/** Separado de `probe` para poder probarlo con texto de ffmpeg ya capturado. */
	public static function parseProbe(text:String, path:String):Null<VideoInfo>
	{
		var w = 0;
		var h = 0;
		var fps = 0.0;
		for (line in text.split("\n"))
		{
			if (line.indexOf("Video:") < 0) continue;
			// ", 1920x1080 [SAR 1:1 DAR 16:9], 30 fps": el tamano va despues de una coma y antes de un espacio, coma o corchete
			var size = ~/, (\d{2,5})x(\d{2,5})[ ,\[]/;
			if (size.match(line + " "))
			{
				w = Std.parseInt(size.matched(1));
				h = Std.parseInt(size.matched(2));
			}
			var rate = ~/([\d.]+) fps/;
			if (rate.match(line)) fps = Std.parseFloat(rate.matched(1));
			break;
		}
		if (w <= 0 || h <= 0)
		{
			var size = Mp4Info.size(path);
			if (size == null) return null;
			w = size.w;
			h = size.h;
		}

		// un video grabado de lado trae una rotacion: ffmpeg la aplica al decodificar y los frames salen girados
		var turn = ~/(?:rotation of|rotate\s*:)\s*(-?[\d.]+)/;
		if (turn.match(text))
		{
			var deg = Math.abs(Std.parseFloat(turn.matched(1)));
			if (Math.round(deg / 90) % 2 == 1)
			{
				var swap = w;
				w = h;
				h = swap;
			}
		}

		var seconds = 0.0;
		var dur = ~/Duration: (\d+):(\d+):([\d.]+)/;
		if (dur.match(text)) seconds = Std.parseFloat(dur.matched(1)) * 3600 + Std.parseFloat(dur.matched(2)) * 60 + Std.parseFloat(dur.matched(3));

		if (fps <= 0) fps = 30;
		return {w: w, h: h, fps: fps, seconds: seconds};
	}

	#end

	/** Carpeta de trabajo (frames temporales) de un video. */
	public static function workDir(spriteDir:String, index:Int):String
		return Path.join([Storage.cacheDirectory(), "video-export", Path.withoutDirectory(Path.removeTrailingSlashes(Path.directory(Path.removeTrailingSlashes(spriteDir)))) + "__" + Path.withoutDirectory(Path.removeTrailingSlashes(spriteDir)) + "__" + index]);

	public static function wipe(path:String):Void
	{
		if (!FileSystem.exists(path)) return;
		if (!FileSystem.isDirectory(path))
		{
			FileSystem.deleteFile(path);
			return;
		}
		for (entry in FileSystem.readDirectory(path)) wipe(Path.join([path, entry]));
		FileSystem.deleteDirectory(path);
	}
	#end
}

#if sys
/**
 * Un video -> una tira. Todo el trabajo pesado (ffmpeg y FunkFMPEG) corre en OTRO hilo; `step()` solo mira si ya termino, asi
 * la pantalla sigue viva (y se puede cancelar) mientras se procesa un video de cientos de frames.
 */
class VideoStripTask
{
	public var done(default, null):Bool = false;
	public var ok(default, null):Bool = false;
	public var error(default, null):Null<String> = null;
	public var label(default, null):String = "";
	public var fraction(get, never):Float;
	public var warnings(default, null):Array<String> = [];

	/** PNG indexado de la tira. */
	public var bytes(default, null):Null<Bytes> = null;
	/** Tamano del video original y de un frame de la tira. */
	public var sourceWidth(default, null):Int = 0;
	public var sourceHeight(default, null):Int = 0;
	public var frameWidth(default, null):Int = 0;
	public var frameHeight(default, null):Int = 0;
	public var frames(default, null):Int = 0;
	/** fps con los que se exporta (el del video, dentro de VIDEO_MIN_FPS..VIDEO_MAX_FPS). */
	public var fps(default, null):Float = 24;
	/** true si hubo que cambiar el fps del video para entrar en el rango. */
	public var resampled(default, null):Bool = false;
	public var paletteSize(default, null):Int = 0;

	/** null en Android (ahi los frames salen de `AndroidFrames`). */
	var ffmpeg:Null<String>;
	var path:String;
	var work:String;
	var started:Bool = false;
	var cancelled:Bool = false;
	var percent:Int = 0;
	var options:TapeOptions;
	var tapePath:String;
	#if target.threaded
	var inbox:Deque<Dynamic> = new Deque<Dynamic>();
	#end

	public function new(ffmpeg:Null<String>, path:String, work:String)
	{
		this.ffmpeg = ffmpeg;
		this.path = path;
		this.work = work;
		this.tapePath = Path.join([work, "strip.png"]);
		this.options = VideoStrip.tapeOptions();
		this.options.onProgress = function(value:Int) percent = 35 + Std.int(value * 0.65);
	}

	function get_fraction():Float
		return done ? 1.0 : percent / 100;

	/** true mientras siga trabajando. */
	public function step():Bool
	{
		if (done) return false;
		#if android
		return stepAndroid();
		#elseif target.threaded
		if (!started)
		{
			started = true;
			label = "leyendo " + Path.withoutDirectory(path);
			var box = inbox;
			Thread.create(function()
			{
				try
				{
					run();
					box.add("ok");
				}
				catch (e:Dynamic)
				{
					box.add("error: " + Std.string(e));
				}
				if (cancelled) try VideoStrip.wipe(work) catch (_:Dynamic) {}
			});
			return true;
		}
		var message:Null<Dynamic> = inbox.pop(false);
		if (message == null) return true;
		if (message == "ok") finish();
		else fail(StringTools.replace(Std.string(message), "error: ", ""));
		#else
		try
		{
			run();
			finish();
		}
		catch (e:Dynamic)
		{
			fail(Std.string(e));
		}
		#end
		return !done;
	}

	/** Cancela: el hilo termina el paso en curso y se borran los temporales. */
	public function dispose():Void
	{
		cancelled = true;
		#if android
		if (stage == 1) AndroidFrames.cancel();
		if (stage == 2 && !done) return; // el hilo de FunkFMPEG borra al terminar
		#else
		if (started && !done) return; // el hilo borra al terminar
		#end
		try VideoStrip.wipe(work) catch (_:Dynamic) {}
	}

	#if android
	var stage:Int = 0;
	var total:Int = 0;
	var target:Array<Int> = [0, 0];

	/** Android: Java saca los frames (se consulta desde aqui) y despues FunkFMPEG arma la tira en un hilo de Haxe. */
	function stepAndroid():Bool
	{
		try
		{
			switch (stage)
			{
				case 0:
					started = true;
					label = "leyendo " + Path.withoutDirectory(path);
					var info = AndroidFrames.probe(path);
					if (info == null) throw "no se pudo leer el video (MediaMetadataRetriever)";
					if (info.seconds <= 0) throw "no se pudo leer la duracion del video";
					sourceWidth = info.w;
					sourceHeight = info.h;
					fps = Math.min(FMCEToFNMMExporter.VIDEO_MAX_FPS, Math.max(FMCEToFNMMExporter.VIDEO_MIN_FPS, info.fps));
					resampled = Math.abs(fps - info.fps) > 0.01;
					total = Std.int(Math.max(1, Math.round(info.seconds * fps)));
					target = FrameScale.fit(info.w, info.h, total, options);
					label = "sacando frames " + target[0] + "x" + target[1];
					FMCEToFNMMExporter.ensureDir(Path.directory(work));
					VideoStrip.wipe(work);
					FileSystem.createDirectory(work);
					if (!AndroidFrames.start(path, work, fps, target[0], target[1], total)) throw AndroidFrames.error();
					percent = 2;
					stage = 1;
				case 1:
					var state = AndroidFrames.state();
					var count = AndroidFrames.progress();
					percent = 2 + Std.int(33 * Math.min(1, count / total));
					label = "sacando frames " + target[0] + "x" + target[1] + " (" + count + "/" + total + ")";
					if (state == AndroidFrames.RUNNING) return true;
					if (state != AndroidFrames.DONE) throw state == AndroidFrames.CANCELLED ? "cancelado" : AndroidFrames.error();
					percent = 35;
					label = "armando la tira (" + count + " frames)";
					var box = inbox;
					Thread.create(function()
					{
						try
						{
							buildTape();
							box.add("ok");
						}
						catch (e:Dynamic)
						{
							box.add("error: " + Std.string(e));
						}
						if (cancelled) try VideoStrip.wipe(work) catch (_:Dynamic) {}
					});
					stage = 2;
				default:
					var message:Null<Dynamic> = inbox.pop(false);
					if (message == null) return true;
					if (message == "ok") finish();
					else fail(StringTools.replace(Std.string(message), "error: ", ""));
			}
		}
		catch (e:Dynamic)
		{
			fail(Std.string(e));
		}
		return !done;
	}
	#end

	function finish():Void
	{
		try VideoStrip.wipe(work) catch (_:Dynamic) {}
		ok = !cancelled;
		done = true;
	}

	function fail(message:String):Void
	{
		error = message;
		try VideoStrip.wipe(work) catch (_:Dynamic) {}
		done = true;
	}

	// ------------------------------------------------------------------ trabajo (en el hilo)

	#if !android
	function run():Void
	{
		var info = VideoStrip.probe(ffmpeg, path);
		if (info == null) throw "no se pudo leer el video (ni con ffmpeg ni su cabecera)";
		sourceWidth = info.w;
		sourceHeight = info.h;
		fps = Math.min(FMCEToFNMMExporter.VIDEO_MAX_FPS, Math.max(FMCEToFNMMExporter.VIDEO_MIN_FPS, info.fps));
		resampled = Math.abs(fps - info.fps) > 0.01;
		percent = 2;

		// frames que van a salir: duracion x fps (+1 de margen: si sobra, FunkFMPEG ajusta con el numero real)
		var count = 600;
		if (info.seconds > 0) count = Std.int(Math.ceil(info.seconds * fps)) + 1;
		else warnings.push("no se pudo leer la duracion de " + Path.withoutDirectory(path) + ": el tamano de los frames puede salir mas chico de lo posible");

		// el frame mas grande que deje la tira dentro de los limites
		var target = FrameScale.fit(info.w, info.h, count, options);
		label = "sacando frames " + target[0] + "x" + target[1];
		extract(info, target);
		if (cancelled) throw "cancelado";
		percent = 35;
		buildTape();
	}
	#end

	/** FunkFMPEG: los f000001.png de `work` -> una tira. Igual en escritorio y Android. */
	function buildTape():Void
	{
		var names = [for (f in FileSystem.readDirectory(work)) if (~/^f\d+\.png$/i.match(f)) f];
		names.sort(Reflect.compare);
		if (names.length == 0) throw "el video no dio ningun frame";
		var files = [for (n in names) Path.join([work, n])];

		label = "armando la tira (" + files.length + " frames)";
		var result = FunkFMPEG.create(files, tapePath, options);
		frameWidth = result.frameWidth;
		frameHeight = result.frameHeight;
		frames = result.frameCount;
		paletteSize = result.paletteSize;
		bytes = File.getBytes(tapePath);
		percent = 100;
	}

	#if !android
	/** ffmpeg: todos los frames del video (a `fps` si hay que ajustarlo) ya al tamano final, PNG RGB sin perdida. */
	function extract(info:VideoInfo, target:Array<Int>):Void
	{
		VideoStrip.wipe(work);
		FileSystem.createDirectory(work);
		var filters:Array<String> = [];
		if (resampled) filters.push("fps=" + fps); // antes de escalar: se escalan menos frames
		if (target[0] != info.w || target[1] != info.h) filters.push("scale=" + target[0] + ":" + target[1] + ":flags=area");

		// -fps_mode es de ffmpeg 5.1+; uno mas viejo usa -vsync 0 (ambos: "no toques los tiempos")
		for (variant in 0...2)
		{
			var args = ["-y", "-hide_banner", "-v", "error", "-nostdin", "-i", path, "-map", "0:v:0", "-an", "-sn", "-dn"];
			if (filters.length > 0) args = args.concat(["-vf", filters.join(",")]);
			args = args.concat(["-pix_fmt", "rgb24", variant == 0 ? "-fps_mode" : "-vsync", variant == 0 ? "passthrough" : "0", "-compression_level", "1", Path.join([work, "f%06d.png"])]);
			var p = new Process(ffmpeg, args);
			var message = p.stderr.readAll().toString();
			var code = p.exitCode();
			p.close();
			if (code == 0) return;
			if (variant == 0 && message.indexOf("fps_mode") >= 0)
			{
				VideoStrip.wipe(work);
				FileSystem.createDirectory(work);
				continue;
			}
			throw "ffmpeg fallo (codigo " + code + "): " + StringTools.trim(message);
		}
	}
	#end
}
#end
