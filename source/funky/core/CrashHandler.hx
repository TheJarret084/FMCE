package funky.core;

import flixel.FlxG;
import haxe.CallStack;
import haxe.CallStack.StackItem;
import openfl.Lib;
import openfl.errors.Error;
import openfl.events.ErrorEvent;
import openfl.events.UncaughtErrorEvent;
import funky.backend.utils.NativeAPI;
import funky.backend.utils.NativeAPI.MessageBoxIcon;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** CrashHandler */
final class CrashHandler
{
	public static var crashDir:String = "crashes/";
	private static var handlingCrash:Bool = false;
	private static var resolvedCrashDir:String;

	/** Resuelve `crashDir` de forma absoluta, junto al ejecutable — no al cwd
	 * (bajo Wine/Winlator el cwd casi nunca es la carpeta del .exe). */
	private static function getCrashDir():String
	{
		#if sys
		if (resolvedCrashDir != null)
			return resolvedCrashDir;

		var base = Storage.logDirectory();
		#if !android
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

		resolvedCrashDir = base + "/" + crashDir;
		return resolvedCrashDir;
		#else
		return crashDir;
		#end
	}

	public static function init():Void
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
			UncaughtErrorEvent.UNCAUGHT_ERROR,
			onUncaughtError
		);

		#if (cpp && !android)
		untyped __global__.__hxcpp_set_critical_error_handler(onNativeError);
		#elseif hl
		hl.Api.setErrorHandler(onNativeError);
		#end
	}

	private static function onUncaughtError(e:UncaughtErrorEvent):Void
	{
		if (handlingCrash)
			return;

		var message:String = Std.string(e.error);

		if (Std.isOfType(e.error, Error))
		{
			var err:Error = cast e.error;
			message = err.message;
		}
		else if (Std.isOfType(e.error, ErrorEvent))
		{
			var err:ErrorEvent = cast e.error;
			message = err.text;
		}

		e.preventDefault();
		e.stopPropagation();
		e.stopImmediatePropagation();

		handle(message, CallStack.exceptionStack(), false);
	}

	#if ((cpp && !android) || hl)
	private static function onNativeError(message:Dynamic):Void
	{
		// No volvemos a lanzar el mismo error: eso destruía el contexto útil
		// del handler nativo y dejaba solamente "Null Object Reference".
		var text = Std.string(message);
		try
		{
			Log.error('[NATIVE CRASH] ' + text);
		}
		catch (_:Dynamic) {}

		try
		{
			handle('Native error: ' + text, CallStack.callStack(), true);
		}
		catch (_:Dynamic)
		{
			#if sys
			try Sys.exit(1) catch (_:Dynamic) {}
			#end
		}
	}
	#end

	private static function handle(message:String, stack:Array<StackItem>, fatal:Bool):Void
	{
		if (handlingCrash)
			return;

		handlingCrash = true;

		try
		{
			handleInner(message, stack, fatal);
		}
		catch (e:Dynamic)
		{
			// Última red: si armar el reporte lindo revienta por lo que sea,
			// al menos mostramos el mensaje original crudo en vez de dejar
			// que se vaya a un crash nativo sin ningún contexto.
			try
			{
				NativeAPI.showMessageBox(
					"Funky Maker Crash Handler (fallback)",
					"Uncaught Error: " + message
						+ "\n\n(El CrashHandler falló al armar el reporte: " + Std.string(e) + ")",
					MSG_ERROR
				);
			}
			catch (_:Dynamic) {}
		}

		#if sys
		Sys.exit(1);
		#end
	}

	private static function handleInner(message:String, stack:Array<StackItem>, fatal:Bool):Void
	{
		var stackLabel:String = stackToString(stack);
		var stateName:String = getStateName();

		var report:String =
			"Funky Maker Crash Handler\n"
			+ "=========================\n\n"
			+ "Uncaught Error:\n"
			+ message
			+ "\n\n"
			+ "Current State:\n"
			+ stateName
			+ "\n\n"
			+ "Date:\n"
			+ DateTools.format(Date.now(), "%Y-%m-%d %H:%M:%S")
			+ "\n\n"
			+ "Stack Trace:\n"
			+ stackLabel;

		// Siempre intenta dejar el error en el log.
		try
		{
			Log.error(report);
		}
		catch (_:Dynamic) {}

		var savedPath:String = saveCrash(report);

		// La ventana sigue el formato del Crash Handler de Codename:
		// mensaje + stack trace, en una alerta nativa simple.
		var popupText:String =
			"Uncaught Error: " + message
			+ "\n\n"
			+ stackLabel;

		if (savedPath != "")
			popupText += "\n\nCrash report saved to:\n" + savedPath;

		// Escritorio: el popup nativo SIEMPRE sale primero (igual que Codename), tambien en errores recuperables.
		// Antes solo salia en errores fatales y, en los demas, el juego pasaba directo a CrashState sin popup.
		var popupShown:Bool = false;
		#if !android
		try
		{
			NativeAPI.showMessageBox("Funky Maker Crash Handler", popupText, MSG_ERROR);
			popupShown = true;
		}
		catch (_:Dynamic) {}
		#end

		// Error de Haxe recuperable: pantalla de error DENTRO del juego (el cuadro nativo no sale en Android y, si el
		// proceso se cierra enseguida, tampoco se alcanza a leer). Si ya van varios errores seguidos, o el estado no se
		// puede cambiar, cae al cuadro nativo y sale.
		if (!fatal && showCrashScreen(message, report, savedPath))
		{
			handlingCrash = false;
			return;
		}

		if (!popupShown)
		{
			try
			{
				// En Windows usa el MessageBox nativo (winapi); en Linux/Mac/HTML5
				// cae al alert de lime. Mismo comportamiento que Codename Engine.
				NativeAPI.showMessageBox(
					"Funky Maker Crash Handler",
					popupText,
					MSG_ERROR
				);
			}
			catch (_:Dynamic)
			{
				// El archivo ya fue guardado; si el popup no esta disponible,
				// no provocamos un segundo crash.
			}
		}

		#if sys
		Sys.exit(1);
		#end
	}

	/** Marcas de tiempo de los ultimos errores mostrados (para cortar un bucle de errores). */
	private static var recentCrashes:Array<Float> = [];

	/**
	 * Cambia a `CrashState`. Devuelve false si no se pudo (error nativo, bucle de errores o el cambio de estado fallo).
	 */
	private static function showCrashScreen(message:String, report:String, savedPath:String):Bool
	{
		try
		{
			var now = haxe.Timer.stamp();
			recentCrashes = recentCrashes.filter(function(t) return now - t < 10);
			recentCrashes.push(now);
			if (recentCrashes.length > 3) return false;

			FlxG.switchState(new funky.menus.CrashState(message, report, savedPath));
			return true;
		}
		catch (_:Dynamic) {}

		return false;
	}

	#if sys
	private static function saveCrash(report:String):String
	{
		try
		{
			var dir = getCrashDir();
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);

			var timestamp:String = DateTools.format(
				Date.now(),
				"%Y-%m-%d_%H-%M-%S"
			);

			var filePath:String =
				dir + "crash_" + timestamp + ".txt";

			File.saveContent(filePath, report);

			return filePath;
		}
		catch (e:Dynamic)
		{
			try
			{
				Log.error("Could not save crash report: " + Std.string(e));
			}
			catch (_:Dynamic) {}

			return "";
		}
	}
	#else
	private static function saveCrash(report:String):String
	{
		return "";
	}
	#end

	private static function getStateName():String
	{
		try
		{
			if (FlxG.state == null)
				return "null";

			var cls = Type.getClass(FlxG.state);

			if (cls == null)
				return Std.string(FlxG.state);

			return Type.getClassName(cls);
		}
		catch (_:Dynamic)
		{
			return "unknown";
		}
	}

	private static function stackToString(stack:Array<StackItem>):String
	{
		var out = new StringBuf();

		if (stack == null || stack.length == 0)
		{
			out.add("(No Haxe stack trace available)\n");
			return out.toString();
		}

		for (item in stack)
		{
			try
			{
				switch (item)
				{
					case CFunction:
						out.add("Non-Haxe (C) Function");

					case Module(c):
						out.add('Module ${c == null ? "?" : c}');

					case FilePos(parent, file, line, col):
						var fileStr = file == null ? "?" : file;
						switch (parent)
						{
							case Method(cla, func):
								var claStr = cla == null ? "?" : cla.split(".").pop();
								var funcStr = func == null ? "?" : func;
								out.add('($fileStr) $claStr.$funcStr() - line $line');

							case _:
								out.add('($fileStr) - line $line');
						}

					case LocalFunction(v):
						out.add('Local Function ${v == null ? "?" : Std.string(v)}');

					case Method(cl, m):
						out.add('${cl == null ? "?" : cl} - ${m == null ? "?" : m}');
				}
			}
			catch (_:Dynamic)
			{
				out.add("(stack item unreadable)");
			}

			out.add("\r\n");
		}

		return out.toString();
	}
}
