package funky.backend.converter;

#if sys
import haxe.Json;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.geom.Point;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import funky.backend.FunkinVideoSprite;
import funky.core.Log;
import funky.core.Storage;
#end

/**
 * Video (.mp4) -> frames -> spritesheet. El .FNMM no soporta video, asi que al exportar la carpeta de un sprite de video
 * se sacan los frames con ffmpeg, se arma un atlas `sprite.png` + `sprite.json` (Aseprite Hash, un tag por video) en una carpeta
 * temporal y el exportador sigue su flujo normal como si fuera un sprite cualquiera. El nivel original no se toca.
 *
 * Necesita `ffmpeg` (junto al .exe o en el PATH). Solo escritorio.
 */
class VideoSheet
{
	/** Frames por segundo a los que se muestrea el video. */
	public static inline var FPS:Int = 12;

	/** Ancho al que se reduce cada frame (el alto sale proporcional). */
	public static inline var MAX_W:Int = 320;

	/** Lado maximo del spritesheet en pixeles. Si no cabe, se saltan frames (se avisa). */
	public static inline var MAX_SIDE:Int = 4096;

	/** ffmpeg usable: junto al .exe, o el que haya en el PATH. null si no hay. */
	public static function findFfmpeg():Null<String>
	{
		#if (sys && !android)
		var exe = Sys.systemName() == "Windows" ? "ffmpeg.exe" : "ffmpeg";
		for (candidate in [Path.join([Storage.exeDirectory(), exe]), "ffmpeg"])
		{
			try
			{
				var p = new Process(candidate, ["-version"]);
				var code = p.exitCode();
				p.close();
				if (code == 0) return candidate;
			}
			catch (_:Dynamic) {}
		}
		#end
		return null;
	}

	#if (sys && !android)
	/**
	 * Arma el atlas de los videos de `srcDir` y devuelve la carpeta temporal donde quedo (`sprite.png`, `sprite.json`, `config.json`).
	 * Lanza un String con el motivo si no se puede.
	 */
	public static function build(srcDir:String, warnings:Array<String>):String
	{
		var videos = FunkinVideoSprite.videoFiles(srcDir);
		if (videos.length == 0) throw "no hay videos en la carpeta";
		var ffmpeg = findFfmpeg();
		if (ffmpeg == null) throw "para exportar videos hace falta ffmpeg (ponlo junto al .exe o instalalo en el PATH)";

		var out = Path.join([Storage.cacheDirectory(), "video-export", Path.withoutDirectory(Path.removeTrailingSlashes(srcDir))]);
		wipe(out);
		FileSystem.createDirectory(out);

		// 1) frames de cada video
		var clips:Array<{tag:String, files:Array<String>}> = [];
		for (i in 0...videos.length)
		{
			var framesDir = Path.join([out, "_f" + i]);
			FileSystem.createDirectory(framesDir);
			var code = Sys.command(ffmpeg, [
				"-y", "-v", "error",
				"-i", Path.join([srcDir, videos[i]]),
				"-an",
				"-vf", "fps=" + FPS + ",scale=" + MAX_W + ":-2",
				Path.join([framesDir, "f%05d.png"])
			]);
			if (code != 0) throw "ffmpeg fallo (codigo " + code + ") con " + videos[i];
			var files = [for (f in FileSystem.readDirectory(framesDir)) if (StringTools.endsWith(f.toLowerCase(), ".png")) Path.join([framesDir, f])];
			files.sort(Reflect.compare);
			if (files.length == 0) throw videos[i] + " no dio ningun frame";
			clips.push({tag: Path.withoutExtension(videos[i]), files: files});
		}

		// 2) tamano de celda y salto de frames si no cabe en MAX_SIDE
		var first = BitmapData.fromFile(clips[0].files[0]);
		if (first == null) throw "no se pudo leer el primer frame";
		var cellW = first.width;
		var cellH = first.height;
		first.dispose();
		var total = 0;
		for (c in clips) total += c.files.length;

		var cols = Std.int(Math.max(1, Math.floor(MAX_SIDE / cellW)));
		var maxRows = Std.int(Math.max(1, Math.floor(MAX_SIDE / cellH)));
		var skip = 1;
		while (Math.ceil(totalWith(clips, skip) / cols) > maxRows) skip++;
		if (skip > 1) warnings.push("el video es largo para un solo spritesheet: se usa 1 de cada " + skip + " frames (" + Std.int(FPS / skip) + " fps)");
		var animFps = FPS / skip;

		// 3) spritesheet + json
		var n = totalWith(clips, skip);
		var rows = Std.int(Math.ceil(n / cols));
		var sheet = new BitmapData(cols * cellW, rows * cellH, true, 0);
		var frames:Array<Dynamic> = [];
		var tags:Array<Dynamic> = [];
		var at = 0;
		for (c in clips)
		{
			var from = at;
			var j = 0;
			while (j < c.files.length)
			{
				var bmp = BitmapData.fromFile(c.files[j]);
				if (bmp != null)
				{
					var x = (at % cols) * cellW;
					var y = Std.int(at / cols) * cellH;
					sheet.copyPixels(bmp, bmp.rect, new Point(x, y));
					frames.push({
						filename: c.tag + "_" + (at - from),
						frame: {x: x, y: y, w: bmp.width, h: bmp.height},
						rotated: false,
						trimmed: false,
						spriteSourceSize: {x: 0, y: 0, w: bmp.width, h: bmp.height},
						sourceSize: {w: bmp.width, h: bmp.height},
						duration: Std.int(1000 / animFps)
					});
					bmp.dispose();
					at++;
				}
				j += skip;
			}
			tags.push({name: c.tag, from: from, to: at - 1, direction: "forward"});
		}

		File.saveBytes(Path.join([out, "sprite.png"]), FMCEToFNMMExporter.encodePng(sheet));
		sheet.dispose();
		File.saveContent(Path.join([out, "sprite.json"]), Json.stringify({
			frames: frames,
			meta: {
				app: "FMCE VideoSheet",
				version: "1.0",
				image: "sprite.png",
				format: "RGBA8888",
				size: {w: cols * cellW, h: rows * cellH},
				scale: "1",
				frameTags: tags,
				fmce: {source: "video"}
			}
		}, null, "\t"));

		// la config del sprite (anim = nombre del video, offsets, velocidad...) se usa tal cual
		var cfg = Path.join([srcDir, "config.json"]);
		if (FileSystem.exists(cfg)) File.copy(cfg, Path.join([out, "config.json"]));

		for (i in 0...videos.length) wipe(Path.join([out, "_f" + i]));
		Log.info("[VideoSheet] " + srcDir + ": " + n + " frames de " + cellW + "x" + cellH + " en " + cols + "x" + rows);
		return out;
	}

	static function totalWith(clips:Array<{tag:String, files:Array<String>}>, skip:Int):Int
	{
		var n = 0;
		for (c in clips) n += Std.int(Math.ceil(c.files.length / skip));
		return n;
	}

	static function wipe(path:String):Void
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
