package funky.backend.converter;

#if android
/**
 * Antes sacaba los frames del video con una clase Java propia (MediaMetadataRetriever). Se quito todo el codigo Java,
 * asi que en Android esta exportacion no esta disponible: se avisa con un error claro y el resto del exportador sigue igual.
 */
class AndroidFrames
{
	public static inline var IDLE:Int = 0;
	public static inline var RUNNING:Int = 1;
	public static inline var DONE:Int = 2;
	public static inline var FAILED:Int = 3;
	public static inline var CANCELLED:Int = 4;

	static inline var UNAVAILABLE:String = "extraer frames de video no esta disponible en Android";

	public static var lastError:String = UNAVAILABLE;

	public static function probe(path:String):Null<VideoStrip.VideoInfo>
	{
		lastError = UNAVAILABLE;
		return null;
	}

	public static function start(path:String, outDir:String, fps:Float, width:Int, height:Int, count:Int):Bool
		return false;

	public static function state():Int
		return FAILED;

	public static function progress():Int
		return 0;

	public static function error():String
		return UNAVAILABLE;

	public static function cancel():Void {}
}
#end
