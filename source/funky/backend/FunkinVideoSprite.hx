package funky.backend;

import flixel.FlxSprite;
import funky.core.Log;
import funky.core.Paths;
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
			Log.warn('[FunkinVideoSprite] "$dir" no tiene meta.fmce.video en sprite.json');
			return false;
		}
		videoCount = info.count;
		if (index < 0 || index >= info.count)
		{
			Log.warn('[FunkinVideoSprite] "$dir": el video $index no existe (count = ${info.count})');
			return false;
		}

		var ok = loadVideo(haxe.io.Path.join([dir, "video" + index + EXTENSION]), info.loop);
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
				var json:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
				var video:Dynamic = json?.meta?.fmce?.video;
				if (video == null) return null;
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
		#end
		return null;
	}

	/** `intro` -> `assets/videos/intro.mp4`. Una ruta con extension se respeta. */
	static function resolve(name:String):String
	{
		var path = haxe.io.Path.extension(name) == "" ? Paths.video(name) : name;
		#if (hxvlc && !desktop)
		// En Android los assets viven dentro del APK: OpenFL sabe donde quedan en disco.
		var real = openfl.utils.Assets.getPath(path);
		if (real != null) return real;
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
