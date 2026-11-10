package funky.backend.converter;

#if android
import lime.system.JNI;

/**
 * Frames de un video en Android (en escritorio los saca ffmpeg). Es solo el puente JNI a `org.fmce.VideoFrames`
 * (source/java/org/fmce/VideoFrames.java): la extraccion corre en un hilo de Java y aqui solo se consulta.
 * Llamar siempre desde el hilo principal.
 */
class AndroidFrames
{
	public static inline var IDLE:Int = 0;
	public static inline var RUNNING:Int = 1;
	public static inline var DONE:Int = 2;
	public static inline var FAILED:Int = 3;
	public static inline var CANCELLED:Int = 4;

	static inline var CLASS:String = "org/fmce/VideoFrames";

	static var probeMethod:Dynamic;
	static var startMethod:Dynamic;
	static var progressMethod:Dynamic;
	static var stateMethod:Dynamic;
	static var errorMethod:Dynamic;
	static var cancelMethod:Dynamic;

	/** Tamano (con la rotacion aplicada), fps y duracion; null si el telefono no pudo leer el video. */
	public static function probe(path:String):Null<VideoStrip.VideoInfo>
	{
		try
		{
			if (probeMethod == null) probeMethod = JNI.createStaticMethod(CLASS, "probe", "(Ljava/lang/String;)Ljava/lang/String;");
			var text:String = probeMethod(path);
			if (text == null || StringTools.startsWith(text, "error:"))
			{
				funky.core.Log.warn('[AndroidFrames] $path: ' + text);
				return null;
			}
			var parts = text.split(",");
			if (parts.length < 4) return null;
			var w = Std.parseInt(parts[0]);
			var h = Std.parseInt(parts[1]);
			if (w == null || h == null || w <= 0 || h <= 0) return null;
			var fps = Std.parseFloat(parts[2]);
			var seconds = Std.parseFloat(parts[3]);
			return {w: w, h: h, fps: Math.isNaN(fps) || fps <= 0 ? 30 : fps, seconds: Math.isNaN(seconds) ? 0 : seconds};
		}
		catch (e:Dynamic)
		{
			funky.core.Log.warn('[AndroidFrames] probe fallo: $e');
		}
		return null;
	}

	/** Empieza a sacar `count` frames a `f000001.png`... en `outDir`, ya de `width` x `height`. */
	public static function start(path:String, outDir:String, fps:Float, width:Int, height:Int, count:Int):Bool
	{
		try
		{
			if (startMethod == null) startMethod = JNI.createStaticMethod(CLASS, "start", "(Ljava/lang/String;Ljava/lang/String;IIII)Z");
			return startMethod(path, outDir, Math.round(fps * 1000), width, height, count) == true;
		}
		catch (e:Dynamic)
		{
			funky.core.Log.warn('[AndroidFrames] start fallo: $e');
		}
		return false;
	}

	public static function state():Int
	{
		try
		{
			if (stateMethod == null) stateMethod = JNI.createStaticMethod(CLASS, "state", "()I");
			return stateMethod();
		}
		catch (_:Dynamic) {}
		return FAILED;
	}

	/** Frames ya escritos. */
	public static function progress():Int
	{
		try
		{
			if (progressMethod == null) progressMethod = JNI.createStaticMethod(CLASS, "progress", "()I");
			return progressMethod();
		}
		catch (_:Dynamic) {}
		return 0;
	}

	public static function error():String
	{
		try
		{
			if (errorMethod == null) errorMethod = JNI.createStaticMethod(CLASS, "error", "()Ljava/lang/String;");
			var text:String = errorMethod();
			return text == null || text == "" ? "error desconocido al sacar los frames" : text;
		}
		catch (e:Dynamic) {}
		return "no se pudo hablar con VideoFrames.java";
	}

	public static function cancel():Void
	{
		try
		{
			if (cancelMethod == null) cancelMethod = JNI.createStaticMethod(CLASS, "cancel", "()V");
			cancelMethod();
		}
		catch (_:Dynamic) {}
	}
}
#end
