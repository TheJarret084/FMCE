package funky.backend.core;

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

final class CrashHandler
{
	public static var crashDir:String = "crashes/";
	private static var handlingCrash:Bool = false;
	private static var resolvedCrashDir:String;

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

		var waitingForUser = false;
		try
		{
			waitingForUser = handleInner(message, stack, fatal);
		}
		catch (e:Dynamic)
		{
			var fallbackText = "Uncaught Error: " + message
				+ "\n\n(El CrashHandler falló al armar el reporte: " + Std.string(e) + ")";

			#if android
			// El fallback tambien debe ser nativo en Android: NativeAPI.showMessageBox solo loguea.
			try
			{
				if (showAndroidDialog(message, "(no se pudo armar el reporte: " + Std.string(e) + ")", fallbackText, "", false))
					return;
			}
			catch (_:Dynamic) {}
			#end

			try
			{
				NativeAPI.showMessageBox(
					"Funky Maker Crash Handler (fallback)",
					fallbackText,
					MSG_ERROR
				);
			}
			catch (_:Dynamic) {}
		}

		// La ventana nativa de Android espera al usuario: se cierra desde su boton.
		if (waitingForUser)
			return;

		#if sys
		Sys.exit(1);
		#end
	}

	private static function handleInner(message:String, stack:Array<StackItem>, fatal:Bool):Bool
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

		try
		{
			Log.error(report);
		}
		catch (_:Dynamic) {}

		var savedPath:String = saveCrash(report);

		#if android
		if (showAndroidDialog(message, stackLabel, report, savedPath, !fatal))
			return true;
		#end

		var popupText:String =
			"Uncaught Error: " + message
			+ "\n\n"
			+ stackLabel;

		if (savedPath != "")
			popupText += "\n\nCrash report saved to:\n" + savedPath;

		var popupShown:Bool = false;
		#if !android
		try
		{
			NativeAPI.showMessageBox("Funky Maker Crash Handler", popupText, MSG_ERROR);
			popupShown = true;
		}
		catch (_:Dynamic) {}
		#end

		if (!fatal && showCrashScreen(message, report, savedPath))
		{
			handlingCrash = false;
			return false;
		}

		if (!popupShown)
		{
			try
			{

				NativeAPI.showMessageBox(
					"Funky Maker Crash Handler",
					popupText,
					MSG_ERROR
				);
			}
			catch (_:Dynamic)
			{

			}
		}

		#if sys
		Sys.exit(1);
		#end

		return false;
	}

	private static var recentCrashes:Array<Float> = [];

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
		var path = writeReport(getCrashDir(), report);

		#if android
		// sin permiso de almacenamiento la carpeta publica falla: se guarda en la privada de la app
		if (path == "")
			path = writeReport(lime.system.System.applicationStorageDirectory + "/" + crashDir, report);
		#end

		return path;
	}

	private static function writeReport(dir:String, report:String):String
	{
		try
		{
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);

			var timestamp:String = DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S");
			var filePath:String = dir + "crash_" + timestamp + ".txt";

			File.saveContent(filePath, report);

			return filePath;
		}
		catch (e:Dynamic)
		{
			try
			{
				Log.error("Could not save crash report in " + dir + ": " + Std.string(e));
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

	#if android
	static var pendingContinue:Bool = false;
	static var pendingClose:Bool = false;
	static var pendingMessage:String = "";
	static var pendingReport:String = "";
	static var pendingPath:String = "";
	static var androidTickListening:Bool = false;

	/**
	 * Ventana nativa de Android (AlertDialog de extension-androidtools). No bloquea: por eso el juego NO se cierra aqui,
	 * se cierra al tocar "Cerrar" (en el hilo principal, nunca desde el hilo de la interfaz de Android).
	 * En fallos no fatales hay tambien "Continuar" (abre la pantalla de crash del juego).
	 * Devuelve false si no se pudo mostrar (entonces el flujo normal cierra el juego).
	 */
	private static function showAndroidDialog(message:String, stackLabel:String, report:String, savedPath:String, canContinue:Bool):Bool
	{
		try
		{
			var app = lime.app.Application.current;
			if (app == null)
				return false;

			var text = message;
			if (stackLabel != null && stackLabel != "")
				text += "\n\n" + (stackLabel.length > 900 ? stackLabel.substr(0, 900) + "..." : stackLabel);
			text += savedPath != "" ? "\n\nLog: " + savedPath : "\n\n(no se pudo guardar el log)";

			pendingMessage = message;
			pendingReport = report;
			pendingPath = savedPath;
			pendingContinue = false;
			pendingClose = false;

			// Los callbacks del AlertDialog llegan desde el hilo de la interfaz: solo marcan banderas.
			var close = function():Void pendingClose = true;
			var keepGoing = function():Void pendingContinue = true;

			// Registrar primero: asi "Cerrar" siempre tiene quien lo atienda.
			if (!androidTickListening)
			{
				app.onUpdate.add(onAndroidContinueTick);
				androidTickListening = true;
			}

			extension.androidtools.Tools.showAlertDialog("Funky Maker se cerro por un error", text,
				{name: "Cerrar", func: close}, canContinue ? {name: "Continuar", func: keepGoing} : null);
			return true;
		}
		catch (_:Dynamic) {}

		return false;
	}

	private static function stopAndroidTick():Void
	{
		try
		{
			if (androidTickListening && lime.app.Application.current != null)
				lime.app.Application.current.onUpdate.remove(onAndroidContinueTick);
		}
		catch (_:Dynamic) {}
		androidTickListening = false;
	}

	private static function onAndroidContinueTick(_:Int):Void
	{
		if (pendingClose)
		{
			pendingClose = false;
			pendingContinue = false;
			stopAndroidTick();
			try Sys.exit(1) catch (_:Dynamic) {}
			return;
		}

		if (!pendingContinue)
			return;

		pendingContinue = false;
		stopAndroidTick();

		handlingCrash = false;
		if (!showCrashScreen(pendingMessage, pendingReport, pendingPath))
		{
			try Sys.exit(1) catch (_:Dynamic) {}
		}
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
