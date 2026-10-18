package funky.backend;

import flixel.FlxSprite;
import funky.core.Log;
import funky.core.Paths;

using StringTools;
#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#end

#if hxvlc
private typedef VideoBase = FlxVideoSprite;
#else
private typedef VideoBase = FlxSprite;
#end

/**
 * Video dentro de un sprite (`FlxVideoSprite` de hxvlc), SIEMPRE SIN AUDIO: el video es decoracion
 * (fondos, cutscenes mudas); la musica la lleva el juego.
 */
class FunkinVideoSprite extends VideoBase
{
	/** true si este build trae hxvlc. */
	public static inline final SUPPORTED:Bool = #if hxvlc true #else false #end;

	public static inline final EXTENSION:String = ".mp4";

	/** Ruta del video cargado, o null. */
	public var videoPath(default, null):Null<String>;

	/** Si el video cargado se repite (lo decide `loadVideo` / el `sprite.json`). */
	public var looping(default, null):Bool = true;

	/**
	 * Carga `assets/videos/<name>.mp4` (o una ruta tal cual si ya trae extension) sin audio.
	 * @param loop repetir al terminar.
	 * @return true si el video quedo listo para `play()`.
	 */
	public function loadVideo(name:String, loop:Bool = true):Bool
	{
		var path = resolve(name);
		looping = loop;

		#if hxvlc
		var options = [":no-audio"];
		if (loop) options.push(":input-repeat=65535");

		var ok = false;
		try
		{
			ok = load(path, options);
		}
		catch (e:Dynamic)
		{
			Log.error('[FunkinVideoSprite] error cargando "$path": $e');
		}

		if (!ok) Log.warn('[FunkinVideoSprite] no se pudo cargar "$path"');
		else videoPath = path;
		return ok;
		#else
		Log.warn('[FunkinVideoSprite] este build no incluye hxvlc, se omite el video "$path"');
		return false;
		#end
	}

	/** Cuantos videos tiene la carpeta cargada con `loadSpriteVideo` (0 si no es de video). */
	public var videoCount(default, null):Int = 0;

	/**
	 * Video de una carpeta de sprite de nivel (`levels/<n>/sprites/<nombre>/`).
	 * @param index cual de los `count` videos cargar.
	 */
	public function loadSpriteVideo(dir:String, index:Int = 0):Bool
	{
		var info = readInfo(dir);
		if (info == null)
		{
			Log.warn('[FunkinVideoSprite] "$dir" no es una carpeta de video (ni meta.fmce.video en sprite.json, ni config.json "type": "video" con un .mp4)');
			return false;
		}
		videoCount = info.count;
		if (index < 0 || index >= info.count)
		{
			Log.warn('[FunkinVideoSprite] "$dir": el video $index no existe (count = ${info.count})');
			return false;
		}

		var file = videoFile(dir, index);
		if (file == null)
		{
			Log.warn('[FunkinVideoSprite] "$dir": no hay un .mp4 para el video $index');
			return false;
		}
		var ok = loadVideo(file, info.loop);
		if (ok && info.scale != 1) scale.set(info.scale, info.scale);
		return ok;
	}

	/** Lee `meta.fmce.video` de `<dir>/sprite.json` (o `Sprite.json`). null si no es una carpeta de video. */
	public static function readInfo(dir:String):Null<{count:Int, loop:Bool, scale:Float}>
	{
		#if sys
		for (file in ["sprite.json", "Sprite.json"])
		{
			var path = haxe.io.Path.join([dir, file]);
			if (!sys.FileSystem.exists(path)) continue;
			try
			{
				var json:Dynamic = funky.core.JsonLoose.parse(sys.io.File.getContent(path));
				var video:Dynamic = json?.meta?.fmce?.video;
				if (video == null) break;
				var count = Std.parseInt(Std.string(video.count));
				return {
					count: count != null && count > 0 ? count : 1,
					loop: video.loop == null ? true : video.loop == true,
					scale: video.scale != null && video.scale > 0 ? video.scale : 1
				};
			}
			catch (e:Dynamic)
			{
				Log.warn('[FunkinVideoSprite] json invalido ($path): $e');
			}
		}
		// Sprite de tipo video sin sprite.json: `config.json` con "type": "video" y un .mp4 en la carpeta
		// (sprite.mp4, o video0.mp4, video1.mp4... si son varios). loop / escala salen de la primera animacion de `data`.
		var files = videoFiles(dir);
		if (files.length == 0) return null;
		var config:Dynamic = null;
		var configPath = haxe.io.Path.join([dir, "config.json"]);
		if (sys.FileSystem.exists(configPath))
		{
			try
			{
				config = funky.core.JsonLoose.parse(sys.io.File.getContent(configPath));
			}
			catch (e:Dynamic)
			{
				Log.warn('[FunkinVideoSprite] json invalido ($configPath): $e');
			}
		}
		var isVideoType = config != null && Std.string(config.type) == "video";
		// una carpeta con atlas (sprite.png) y un .mp4 suelto sigue siendo un sprite normal
		if (!isVideoType && sys.FileSystem.exists(haxe.io.Path.join([dir, "sprite.png"]))) return null;
		if (!isVideoType && config != null) return null;
		var data:Array<Dynamic> = config != null && Std.isOfType(config.data, Array) ? config.data : [];
		var first:Dynamic = data.length > 0 ? data[0] : null;
		var scale:Float = first != null && first.scale != null ? Std.parseFloat(Std.string(first.scale)) : 1;
		var withVideo = 0;
		for (i in 0...data.length) if (animFile(dir, animOf(dir, i)) != null) withVideo++;
		return {
			count: withVideo > 0 ? data.length : files.length,
			loop: first == null || first.loop == null ? true : first.loop == true,
			scale: Math.isNaN(scale) || scale <= 0 ? 1 : scale
		};
		#end
		return null;
	}

	/** Los .mp4 de una carpeta de sprite, ordenados por nombre (`sprite.mp4`, o `video0.mp4`, `video1.mp4`...). */
	public static function videoFiles(dir:String):Array<String>
	{
		var out:Array<String> = [];
		#if sys
		try
		{
			if (sys.FileSystem.exists(dir) && sys.FileSystem.isDirectory(dir))
				for (file in sys.FileSystem.readDirectory(dir))
					if (file.toLowerCase().endsWith(EXTENSION)) out.push(file);
		}
		catch (e:Dynamic) {}
		out.sort(Reflect.compare);
		#end
		return out;
	}

	/** Ruta del video `index`: `video<index>.mp4` si existe (formato viejo), si no el `index`-esimo .mp4 de la carpeta. */
	public static function videoFile(dir:String, index:Int):Null<String>
	{
		#if sys
		// Lo primero: el video que dice `anim` de la entrada `index` del config.json (anim: "videotal" -> videotal.mp4).
		var byAnim = animFile(dir, animOf(dir, index));
		if (byAnim != null) return byAnim;
		var legacy = haxe.io.Path.join([dir, "video" + index + EXTENSION]);
		if (sys.FileSystem.exists(legacy)) return legacy;
		var files = videoFiles(dir);
		if (index >= 0 && index < files.length) return haxe.io.Path.join([dir, files[index]]);
		#end
		return null;
	}

	/** `anim` de la entrada `index` de `<dir>/config.json` (null si no hay). */
	public static function animOf(dir:String, index:Int):Null<String>
	{
		#if sys
		var configPath = haxe.io.Path.join([dir, "config.json"]);
		if (!sys.FileSystem.exists(configPath)) return null;
		try
		{
			var config:Dynamic = funky.core.JsonLoose.parse(sys.io.File.getContent(configPath));
			var data:Array<Dynamic> = config != null && Std.isOfType(config.data, Array) ? config.data : [];
			if (index < 0 || index >= data.length || data[index] == null || data[index].anim == null) return null;
			var anim = Std.string(data[index].anim);
			return anim == "" ? null : anim;
		}
		catch (e:Dynamic)
		{
			Log.warn('[FunkinVideoSprite] json invalido ($configPath): $e');
		}
		#end
		return null;
	}

	/** `<dir>/<anim>.mp4` si existe, si no null. Los sprites de video NO usan sprite.png: el video es el `anim`. */
	public static function animFile(dir:String, anim:Null<String>):Null<String>
	{
		#if sys
		if (anim == null || anim == "") return null;
		var file = anim.toLowerCase().endsWith(EXTENSION) ? anim : anim + EXTENSION;
		var path = haxe.io.Path.join([dir, file]);
		if (sys.FileSystem.exists(path)) return path;
		#end
		return null;
	}

	/** `intro` -> `assets/videos/intro.mp4`. Una ruta con extension se respeta. */
	static function resolve(name:String):String
	{
		var path = haxe.io.Path.extension(name) == "" ? Paths.video(name) : name;
		#if (hxvlc && !desktop)
		// En Android los assets viven dentro del APK: OpenFL sabe donde quedan en disco.
		// Assets.getPath lanza una excepcion ("no asset with an ID") si el archivo no es un asset empaquetado: los videos
		// de un nivel (/storage/.../levels/<nivel>/sprites/...) son archivos sueltos y se abren por su ruta.
		if (openfl.utils.Assets.exists(path))
		{
			var real = openfl.utils.Assets.getPath(path);
			if (real != null) return real;
		}
		#end
		return path;
	}

	#if !hxvlc
	public function play():Bool
		return false;

	public function stop():Void {}

	public function pause():Void {}

	public function resume():Void {}
	#end
}
