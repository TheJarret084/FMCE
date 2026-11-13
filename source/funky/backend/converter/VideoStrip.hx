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

typedef VideoClip =
{

	var path:Null<String>;

	var cfg:Dynamic;
}

typedef VideoInfo =
{

	var w:Int;
	var h:Int;
	var fps:Float;
	var seconds:Float;
}

class VideoStrip
{

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

	public static function tapeOptions():TapeOptions
	{
		var o = new TapeOptions();
		o.scaleDivisor = 0;
		o.maxWidth = FMCEToFNMMExporter.VIDEO_MAX_WIDTH;
		o.maxHeight = FMCEToFNMMExporter.VIDEO_MAX_HEIGHT;
		#if android

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

	public static function parseProbe(text:String, path:String):Null<VideoInfo>
	{
		var w = 0;
		var h = 0;
		var fps = 0.0;
		for (line in text.split("\n"))
		{
			if (line.indexOf("Video:") < 0) continue;

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

class VideoStripTask
{
	public var done(default, null):Bool = false;
	public var ok(default, null):Bool = false;
	public var error(default, null):Null<String> = null;
	public var label(default, null):String = "";
	public var fraction(get, never):Float;
	public var warnings(default, null):Array<String> = [];

	public var bytes(default, null):Null<Bytes> = null;

	public var sourceWidth(default, null):Int = 0;
	public var sourceHeight(default, null):Int = 0;
	public var frameWidth(default, null):Int = 0;
	public var frameHeight(default, null):Int = 0;
	public var frames(default, null):Int = 0;

	public var fps(default, null):Float = 24;

	public var resampled(default, null):Bool = false;
	public var paletteSize(default, null):Int = 0;

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

	public function dispose():Void
	{
		cancelled = true;
		#if android
		if (stage == 1) AndroidFrames.cancel();
		if (stage == 2 && !done) return;
		#else
		if (started && !done) return;
		#end
		try VideoStrip.wipe(work) catch (_:Dynamic) {}
	}

	#if android
	var stage:Int = 0;
	var total:Int = 0;
	var target:Array<Int> = [0, 0];

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
					if (info == null) throw "no se pudo leer el video (MediaMetadataRetriever): " + (AndroidFrames.lastError == "" ? "sin detalle" : AndroidFrames.lastError);
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

	#if !android
	function run():Void
	{
		var info = VideoStrip.probe(ffmpeg, path);
		if (info == null) info = probeByFrame();
		if (info == null) throw "no se pudo leer el video (ni con ffmpeg, ni su cabecera, ni decodificando un frame)";
		sourceWidth = info.w;
		sourceHeight = info.h;
		fps = Math.min(FMCEToFNMMExporter.VIDEO_MAX_FPS, Math.max(FMCEToFNMMExporter.VIDEO_MIN_FPS, info.fps));
		resampled = Math.abs(fps - info.fps) > 0.01;
		percent = 2;

		var count = 600;
		if (info.seconds > 0) count = Std.int(Math.ceil(info.seconds * fps)) + 1;
		else warnings.push("no se pudo leer la duracion de " + Path.withoutDirectory(path) + ": el tamano de los frames puede salir mas chico de lo posible");

		var target = FrameScale.fit(info.w, info.h, count, options);
		label = "sacando frames " + target[0] + "x" + target[1];
		extract(info, target);
		if (cancelled) throw "cancelado";
		percent = 35;
		buildTape();
	}
	#end

	#if !android
	function probeByFrame():Null<VideoInfo>
	{
		try
		{
			VideoStrip.wipe(work);
			FileSystem.createDirectory(work);
			var shot = Path.join([work, "probe.png"]);
			var p = new Process(ffmpeg, ["-y", "-hide_banner", "-v", "error", "-nostdin", "-i", path, "-map", "0:v:0", "-frames:v", "1", "-an", "-sn", "-dn", shot]);
			p.stderr.readAll();
			var code = p.exitCode();
			p.close();
			if (code != 0 || !FileSystem.exists(shot)) return null;
			var head = File.getBytes(shot);
			if (head.length < 24) return null;
			var w = head.get(16) << 24 | head.get(17) << 16 | head.get(18) << 8 | head.get(19);
			var h = head.get(20) << 24 | head.get(21) << 16 | head.get(22) << 8 | head.get(23);
			VideoStrip.wipe(work);
			if (w <= 0 || h <= 0) return null;
			warnings.push("el video " + Path.withoutDirectory(path) + " no tenia cabecera legible: se exporto a " + FMCEToFNMMExporter.VIDEO_MAX_FPS + " fps con el tamano del primer frame");
			return {w: w, h: h, fps: FMCEToFNMMExporter.VIDEO_MAX_FPS, seconds: 0};
		}
		catch (e:Dynamic)
		{
			Log.warn('[VideoStrip] no se pudo sacar un frame de $path: $e');
		}
		return null;
	}
	#end

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

	function extract(info:VideoInfo, target:Array<Int>):Void
	{
		VideoStrip.wipe(work);
		FileSystem.createDirectory(work);
		var filters:Array<String> = [];
		if (resampled) filters.push("fps=" + fps);
		if (target[0] != info.w || target[1] != info.h) filters.push("scale=" + target[0] + ":" + target[1] + ":flags=area");

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
