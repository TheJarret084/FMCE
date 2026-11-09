package funky.core;

import haxe.PosInfos;

#if sys
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
#end

/** Severidad de un log, la misma del legacy (`funkin.backend.Logger`): decide la etiqueta y el color ANSI. */
enum abstract Severity(Int) to Int
{
	var PRINT;
	var WARN;
	var ERROR;
	var NOTICE;

	public function toString():String
	{
		return switch (this)
		{
			case WARN: '[WARN] ';
			case ERROR: '[ERROR] ';
			case NOTICE: '[NOTICE] ';
			default: '[LOG] ';
		}
	}
}

class Log
{
	static var initialized:Bool = false;
	#if sys
	static var logFile:Null<FileOutput>;
	#end

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;
		haxe.Log.trace = function(v:Dynamic, ?infos:PosInfos) log(v, PRINT, infos);

		#if sys
		try
		{
			var base = logBase();
			var latest = base + "/latest.log";
			if (FileSystem.exists(latest))
			{
				var previous = base + "/previous.log";
				if (FileSystem.exists(previous)) FileSystem.deleteFile(previous);
				FileSystem.rename(latest, previous);
			}
			logFile = File.write(latest, false);
		}
		catch (_:Dynamic) {}
		#end

		info("Logger listo");
	}

	/** Carpeta del log: junto al ejecutable (no al cwd, que bajo Wine/Winlator casi nunca es esa) o, en Android, la carpeta del juego. */
	#if sys
	static function logBase():String
	{
		var base = Storage.logDirectory();
		#if android
		// Los logs van en `<carpeta del juego>/logs`; los crashes en `<carpeta del juego>/crashes` (CrashHandler).
		base += "/logs";
		try
		{
			if (!FileSystem.exists(base)) FileSystem.createDirectory(base);
		}
		catch (_:Dynamic) {}
		#else
		try
		{
			var prog = Sys.programPath();
			if (prog != null && prog != "")
			{
				var dir = haxe.io.Path.directory(prog);
				if (dir != null && dir != "") base = dir;
			}
		}
		catch (_:Dynamic) {}
		#end
		return base;
	}
	#end

	/** Funcion principal, como `Logger.log` del legacy. */
	public static function log(data:Dynamic, severity:Severity = PRINT, ?pos:PosInfos):Void
	{
		var message:String = haxe.Log.formatOutput(data, pos);
		var text:String = severity.toString() + message;

		// Tarjeta en pantalla (F2 la apaga). LogOverlay no llama a Log, asi que no se cicla.
		funky.backend.system.LogOverlay.push(severity, message);

		#if sys
		if (logFile != null)
		{
			try
			{
				logFile.writeString('[${Date.now()}]' + text + "\n");
				logFile.flush();
			}
			catch (_:Dynamic) {}
		}
		#end

		var output = Ansi.reset(Ansi.fg(text, ansiColor(severity)));
		// Algunos depuradores (el de VSCode) anulan el color de la terminal: ahi se define FORCED_ANSI.
		#if !FORCED_ANSI
		output = Ansi.stripColor(output);
		#end

		#if sys
		Sys.println(output);
		#elseif js
		js.Browser.console.log(output);
		#end
	}

	public static function info(message:String, ?infos:PosInfos):Void
		log(message, PRINT, infos);

	public static function warn(message:String, ?infos:PosInfos):Void
		log(message, WARN, infos);

	public static function error(message:String, ?infos:PosInfos):Void
		log(message, ERROR, infos);

	public static function trace(message:String, ?infos:PosInfos):Void
		log(message, PRINT, infos);

	/** Un aviso destacado para depurar a mano (antes `alert`). */
	public static function notice(message:String, ?infos:PosInfos):Void
		log(message, NOTICE, infos);

	public static inline function alert(message:String, ?infos:PosInfos):Void
		notice(message, infos);

	static function ansiColor(severity:Severity):AnsiColor
	{
		return switch (severity)
		{
			case ERROR: AnsiColor.RED;
			case WARN: AnsiColor.YELLOW;
			case NOTICE: AnsiColor.GREEN;
			default: AnsiColor.WHITE;
		}
	}

	/** Un volcado de texto (no es un log): `<folder>/<fileName>_<fecha>.txt`. */
	public static function writeDump(content:String, folder:String, fileName:String):Void
	{
		#if sys
		try
		{
			if (!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
			var stamp = StringTools.replace(StringTools.replace(StringTools.replace(Date.now().toString(), ":", "_"), " ", "_"), "/", "-");
			File.saveContent('$folder/${fileName}_$stamp.txt', content);
		}
		catch (_:Dynamic) {}
		#end
	}
}

// Copiado del legacy (a su vez de hscript-iris: crowplexus/iris/utils/Ansi.hx), solo lo que usa Log.

enum abstract AnsiColor(Int) to Int
{
	final BLACK = 0;
	final RED = 1;
	final GREEN = 2;
	final YELLOW = 3;
	final BLUE = 4;
	final MAGENTA = 5;
	final CYAN = 6;
	final WHITE = 7;
	final DEFAULT = 9;
}

class Ansi
{
	/** Cabecera de las secuencias de escape ANSI. */
	public static inline final ESC = "\x1B[";

	/** Quita todos los atributos y colores. */
	public static inline function reset(str:String):String
		return str + ESC + "0m";

	/** Color de primer plano (paleta de 256). */
	public static inline function fg(str:String, color:AnsiColor):String
		return ESC + "38;5;" + (color : Int) + "m" + str;

	static var colorSupported:Null<Bool> = null;

	/** Deja el texto tal cual si la terminal soporta color; si no, le quita las secuencias de escape. */
	public static function stripColor(output:String):String
	{
		#if sys
		if (colorSupported == null)
		{
			var term = Sys.getEnv("TERM");

			if (term == "dumb")
			{
				colorSupported = false;
			}
			else
			{
				if (colorSupported != true && term != null)
				{
					colorSupported = ~/(?i)-256(color)?$/.match(term)
						|| ~/(?i)^screen|^xterm|^vt100|^vt220|^rxvt|color|ansi|cygwin|linux/.match(term);
				}

				if (colorSupported != true)
				{
					colorSupported = Sys.getEnv("TERM_PROGRAM") == "iTerm.app"
						|| Sys.getEnv("TERM_PROGRAM") == "Apple_Terminal"
						|| Sys.getEnv("COLORTERM") != null
						|| Sys.getEnv("ANSICON") != null
						|| Sys.getEnv("ConEmuANSI") != null
						|| Sys.getEnv("WT_SESSION") != null;
				}
			}
		}

		if (colorSupported == true)
		{
			return output;
		}
		#end
		return ~/\x1b\[[^m]*m/g.replace(output, "");
	}
}
