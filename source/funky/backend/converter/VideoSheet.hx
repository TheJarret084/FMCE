package funky.backend.converter;

import haxe.Json;
import haxe.io.Path;
import funky.backend.FunkinVideoSprite;
import funky.backend.SpriteSheet;
import funky.backend.converter.VideoStrip.VideoClip;
import funky.backend.utils.JsonLoose;
import funky.backend.system.Log;
#if sys
import funky.backend.converter.VideoStrip.VideoStripTask;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Video -> SPRITESHEET del mismo sistema de sprites (sprite.json compacto + paginas + config.json por `anim`).
 *
 * Una carpeta de sprite con videos (.mp4) se convierte en un sprite normal: cada video queda como una animacion
 * (tag = su `anim`), los frames repetidos se guardan una sola vez y las paginas son de maximo SpritePages.maxPage.
 * Se juega con LevelSprite como cualquier otro sprite: sin hxvlc, sin retrasos de arranque y sincronizado con el BPM.
 *
 * Los .mp4 originales se mueven a `source/` dentro de la carpeta del sprite (no se borra nada).
 * Para videos LARGOS (fondos de varios segundos) conviene dejar el .mp4: un spritesheet guarda cada frame.
 */
class VideoSheet
{
	/** Sin tope artificial de paginas: usa las que necesite. El límite real lo pone la GPU/memoria al cargar. */
	public static inline var MAX_PAGES:Int = 0x7FFFFFFF;

	public static inline var SOURCE_DIR:String = "source";

	public static inline function maxPages():Int
	{
		return MAX_PAGES;
	}

	/** ¿La carpeta tiene videos .mp4 sueltos y todavia no es un spritesheet? */
	public static function canConvert(dir:String):Bool
	{
		#if sys
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return false;
		if (FileSystem.exists(Path.join([dir, "sprite.png"]))) return false;
		return FunkinVideoSprite.videoFiles(dir).length > 0;
		#else
		return false;
		#end
	}

	public static function start(dir:String):VideoSheetJob
		return new VideoSheetJob(dir);
}

#if sys

private typedef Converted =
{
	var clip:VideoClip;
	var task:VideoStripTask;
}

class VideoSheetJob
{
	public var done(default, null):Bool = false;
	public var ok(default, null):Bool = false;
	public var error(default, null):Null<String> = null;
	public var label(default, null):String = "";
	public var fraction(get, never):Float;
	public var warnings(default, null):Array<String> = [];
	public var summary(default, null):String = "";

	var dir:String;
	var ffmpeg:Null<String> = null;
	var clips:Array<VideoClip> = [];
	var results:Array<Converted> = [];
	var task:Null<VideoStripTask> = null;
	var index:Int = 0;
	var stage:Int = 0;
	var pagesPerVideo:Int = 1;
	var tempDirs:Array<String> = [];

	public function new(dir:String)
	{
		this.dir = Path.removeTrailingSlashes(dir);
	}

	function get_fraction():Float
	{
		if (done) return 1.0;
		if (clips.length == 0) return 0;
		var current = task != null ? task.fraction : 0;
		return Math.min(0.97, (index + current) / clips.length);
	}

	/** Un paso (se llama una vez por frame desde el editor). Devuelve true mientras siga trabajando. */
	public function step():Bool
	{
		if (done) return false;
		try
		{
			switch (stage)
			{
				case 0:
					open();
				case 1:
					convertNext();
				default:
					assemble();
			}
		}
		catch (e:Dynamic)
		{
			fail(Std.string(e));
		}
		return !done;
	}

	public function dispose():Void
	{
		if (task != null) task.dispose();
		wipeTemp();
	}

	function open():Void
	{
		label = "preparando";
		if (FileSystem.exists(Path.join([dir, "sprite.png"])) || FileSystem.exists(Path.join([dir, "sprite.json"])))
			throw "la carpeta ya tiene sprite.png/sprite.json: un spritesheet no se mezcla con videos";

		#if !android
		ffmpeg = VideoStrip.findFfmpeg();
		if (ffmpeg == null) throw "los videos necesitan ffmpeg: ponlo junto al .exe o en el PATH";
		#end

		for (clip in VideoStrip.clips(dir, warnings))
		{
			if (clip.path == null)
			{
				warnings.push("un video de config.json no existe como .mp4 y se salta");
				continue;
			}
			clips.push(clip);
		}
		if (clips.length == 0) throw "la carpeta no tiene videos (.mp4)";

		pagesPerVideo = Std.int(Math.max(1, Math.floor(VideoSheet.maxPages() / clips.length)));
		stage = 1;
	}

	function sheetDirOf(i:Int):String
	{
		var work = VideoStrip.workDir(dir, i);
		return Path.join([Path.directory(work), "sheet__" + Path.withoutDirectory(work)]);
	}

	function convertNext():Void
	{
		if (task == null)
		{
			var clip = clips[index];
			var work = VideoStrip.workDir(dir, index);
			FMCEToFNMMExporter.ensureDir(Path.directory(work));
			var out = sheetDirOf(index);
			VideoStrip.wipe(out);
			tempDirs.push(out);
			task = new VideoStripTask(ffmpeg, clip.path, work);
			task.useSheet(out, "p", pagesPerVideo);
			label = Path.withoutDirectory(clip.path);
			return;
		}

		var file = Path.withoutDirectory(clips[index].path);
		if (task.step())
		{
			label = file + ": " + task.label;
			return;
		}

		var finished = task;
		task = null;
		for (w in finished.warnings) warnings.push(w);
		if (!finished.ok || finished.sheetResult == null)
			throw "el video " + file + " no se pudo convertir: " + (finished.error == null ? "sin detalle" : finished.error);

		results.push({clip: clips[index], task: finished});
		index++;
		if (index >= clips.length) stage = 2;
	}

	function animNameOf(clip:VideoClip, position:Int, taken:Map<String, Bool>):String
	{
		var name = "";
		var cfgAnim:Dynamic = clip.cfg == null ? null : Reflect.field(clip.cfg, "anim");
		if (cfgAnim != null) name = StringTools.trim(Std.string(cfgAnim));
		if (name == "") name = Path.withoutExtension(Path.withoutDirectory(clip.path));
		if (name == "") name = "anim" + position;
		if (taken.exists(name)) name += "_" + position;
		taken.set(name, true);
		return name;
	}

	static function num(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	function assemble():Void
	{
		label = "sprite.json";

		var pages:Array<Dynamic> = [];
		var frames:Array<Dynamic> = [];
		var tags:Array<Dynamic> = [];
		var entries:Array<Dynamic> = [];
		var taken = new Map<String, Bool>();
		var totalFrames = 0;
		var totalUnique = 0;

		for (i in 0...results.length)
		{
			var r = results[i];
			var sheet = r.task.sheetResult;
			var pageBase = pages.length;

			for (k in 0...sheet.pages.length)
			{
				var finalName = pages.length == 0 ? "sprite.png" : "sprite_p" + pages.length + ".png";
				var from = Path.join([sheetDirOf(i), sheet.pages[k].file]);
				var to = Path.join([dir, finalName]);
				if (FileSystem.exists(to)) FileSystem.deleteFile(to);
				FileSystem.rename(from, to);
				pages.push({image: finalName, w: sheet.pages[k].width, h: sheet.pages[k].height});
			}

			var animName = animNameOf(r.clip, i, taken);
			var start = frames.length;
			var duration = Std.int(Math.max(1, Math.round(1000 / r.task.fps)));
			var fw = sheet.frameWidth;
			var fh = sheet.frameHeight;
			for (n in 0...sheet.slots.length)
			{
				var slot = sheet.slots[n];
				frames.push({
					filename: animName + StringTools.lpad(Std.string(n), "0", 4),
					frame: {x: slot.x, y: slot.y, w: fw, h: fh},
					rotated: false,
					trimmed: false,
					spriteSourceSize: {x: 0, y: 0, w: fw, h: fh},
					sourceSize: {w: fw, h: fh},
					duration: duration,
					page: pageBase + slot.page
				});
			}
			tags.push({name: animName, from: start, to: frames.length - 1, direction: "forward"});

			// El frame puede ser mas chico que el video: la escala y el pivote compensan para que se vea del mismo tamano.
			var shrink = Math.min(1, fw / Math.max(1, r.task.sourceWidth));
			var entry:Dynamic = {};
			var original = r.clip.cfg;
			if (original != null)
				for (key in Reflect.fields(original))
					if (key != "name" && key != "index" && key != "indices") Reflect.setField(entry, key, Reflect.field(original, key));
			var offset:Dynamic = original == null ? null : Reflect.field(original, "offset");
			Reflect.setField(entry, "anim", animName);
			Reflect.setField(entry, "spd", Math.round(r.task.fps * 100) / 100);
			Reflect.setField(entry, "spd_fps", true);
			if (Reflect.field(entry, "loop") == null) Reflect.setField(entry, "loop", true);
			Reflect.setField(entry, "scale", Math.round(num(Reflect.field(entry, "scale"), 1) / shrink * 10000) / 10000);
			Reflect.setField(entry, "offset", {
				x: Math.round(num(offset == null ? null : Reflect.field(offset, "x"), 0) * shrink * 100) / 100,
				y: Math.round(num(offset == null ? null : Reflect.field(offset, "y"), 0) * shrink * 100) / 100
			});
			entries.push(entry);

			totalFrames += sheet.frameCount;
			totalUnique += sheet.uniqueCount;
			if (shrink < 1) warnings.push(animName + ": frames al " + Math.round(shrink * 100) + "% del video (" + fw + "x" + fh + "), la escala lo compensa");
		}

		var master:Dynamic = {
			frames: frames,
			meta: {
				app: "FMCE",
				version: "2.0",
				image: "sprite.png",
				format: "RGBA8888",
				size: {w: pages[0].w, h: pages[0].h},
				scale: "1",
				frameTags: tags,
				pages: pages,
				fmce: {type: "item", bilinear: true, source: "video"}
			}
		};
		var jsonText = SpriteSheet.stringify(master);

		// Se comprueba lo que se acaba de armar ANTES de tocar nada del sprite original.
		var check:Dynamic = SpriteSheet.parse(jsonText);
		var checkFrames:Array<Dynamic> = Reflect.field(check, "frames");
		if (checkFrames == null || checkFrames.length != frames.length)
			throw "el sprite.json armado no coincide con los frames (" + (checkFrames == null ? 0 : checkFrames.length) + " de " + frames.length + ")";

		File.saveContent(Path.join([dir, "sprite.json"]), jsonText);
		writeConfig(entries);
		moveSources();

		wipeTemp();
		summary = results.length + (results.length == 1 ? " video" : " videos") + ": " + totalFrames + " frames (" + totalUnique + " unicos), " + pages.length
			+ (pages.length == 1 ? " pagina" : " paginas") + ", " + results[0].task.frameWidth + "x" + results[0].task.frameHeight;
		ok = true;
		done = true;
	}

	function writeConfig(entries:Array<Dynamic>):Void
	{
		var path = Path.join([dir, "config.json"]);
		var config:Dynamic = {};
		if (FileSystem.exists(path))
		{
			try
			{
				var parsed:Dynamic = JsonLoose.parse(File.getContent(path));
				if (parsed != null) config = parsed;
			}
			catch (e:Dynamic)
			{
				warnings.push("config.json ilegible, se reescribe desde cero: " + e);
			}
		}
		Reflect.setField(config, "type", "item");
		if (Reflect.field(config, "bilinear") == null) Reflect.setField(config, "bilinear", true);
		Reflect.setField(config, "data", entries);
		File.saveContent(path, Json.stringify(config, null, "\t"));
	}

	function moveSources():Void
	{
		var target = Path.join([dir, VideoSheet.SOURCE_DIR]);
		FMCEToFNMMExporter.ensureDir(target);
		for (r in results)
		{
			var name = Path.withoutDirectory(r.clip.path);
			var to = Path.join([target, name]);
			try
			{
				if (FileSystem.exists(to)) FileSystem.deleteFile(to);
				FileSystem.rename(r.clip.path, to);
			}
			catch (e:Dynamic)
			{
				warnings.push("no se pudo mover " + name + " a " + VideoSheet.SOURCE_DIR + "/: " + e);
			}
		}
	}

	function wipeTemp():Void
	{
		for (path in tempDirs) try VideoStrip.wipe(path) catch (_:Dynamic) {}
		tempDirs = [];
	}

	function fail(message:String):Void
	{
		error = message;
		Log.warn('[VideoSheet] ' + dir + ': ' + message);
		wipeTemp();
		done = true;
	}
}

#else

class VideoSheetJob
{
	public var done(default, null):Bool = true;
	public var ok(default, null):Bool = false;
	public var error(default, null):Null<String> = "convertir videos necesita un target sys";
	public var label(default, null):String = "";
	public var fraction(get, never):Float;
	public var warnings(default, null):Array<String> = [];
	public var summary(default, null):String = "";

	public function new(dir:String) {}

	function get_fraction():Float return 1;

	public function step():Bool return false;

	public function dispose():Void {}
}

#end
