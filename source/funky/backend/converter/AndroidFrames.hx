package funky.backend.converter;

#if android
/**
 * Backend Android para extraer frames de video. Delega en FunkFMPEG (Java: funkfmpeg.VideoFrames),
 * que usa MediaMetadataRetriever y se incluye via include.xml de la libreria.
 */
class AndroidFrames
{
	public static inline var IDLE:Int = funkfmpeg.VideoFrames.IDLE;
	public static inline var RUNNING:Int = funkfmpeg.VideoFrames.RUNNING;
	public static inline var DONE:Int = funkfmpeg.VideoFrames.DONE;
	public static inline var FAILED:Int = funkfmpeg.VideoFrames.FAILED;
	public static inline var CANCELLED:Int = funkfmpeg.VideoFrames.CANCELLED;

	public static var lastError:String = "";

	public static function probe(path:String):Null<VideoStrip.VideoInfo>
	{
		lastError = "";
		var info = funkfmpeg.VideoFrames.probe(path);
		if (info == null)
		{
			lastError = funkfmpeg.VideoFrames.error();
			if (lastError == null || lastError == "") lastError = "no se pudo leer el video";
			return null;
		}
		return {w: info.w, h: info.h, fps: info.fps, seconds: info.seconds};
	}

	public static function start(path:String, outDir:String, fps:Float, width:Int, height:Int, count:Int):Bool
	{
		lastError = "";
		var ok = funkfmpeg.VideoFrames.start(path, outDir, Math.round(fps * 1000), width, height, count);
		if (!ok) lastError = funkfmpeg.VideoFrames.error();
		return ok;
	}

	public static function state():Int
		return funkfmpeg.VideoFrames.state();

	public static function progress():Int
		return funkfmpeg.VideoFrames.progress();

	public static function error():String
	{
		var e = funkfmpeg.VideoFrames.error();
		return (e == null || e == "") ? lastError : e;
	}

	public static function cancel():Void
		funkfmpeg.VideoFrames.cancel();
}
#end
