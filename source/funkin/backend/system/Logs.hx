package funkin.backend.system;

import funky.core.Log;

enum abstract LogLevel(Int) { var INFO; var WARNING; var ERROR; var TRACE; var VERBOSE; }

class Logs
{
	public static function warn(text:String):Void Log.warn(text);
	public static function error(text:String):Void Log.error(text);
	public static function trace(text:String, ?level:Dynamic, ?color:Dynamic):Void Log.info(text);
	public static function traceColored(text:Array<Dynamic>, ?level:Dynamic):Void Log.info([for (t in text) Std.string(t)].join(""));
	public static function logText(text:String, ?color:Dynamic):Void Log.info(text);
}
