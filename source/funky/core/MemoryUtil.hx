package funky.core;

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif neko
import neko.vm.Gc;
#end
import openfl.system.System;
/**
 * FunkyMaker2 - MemoryUtil Adaptado de `MemoryUtil` (CodenameEngine), recortado a garbage
 * collection.
 */
final class MemoryUtil
{
	/** Corre una recolección de basura menor (rápida). */
	public static function clearMinor():Void
	{
		#if (cpp || neko)
		Gc.run(false);
		#end
	}

	/** Corre una recolección de basura completa (más pesada, útil entre states). */
	public static function clearMajor():Void
	{
		#if cpp
		Gc.run(true);
		Gc.compact();
		#elseif hl
		Gc.major();
		#elseif neko
		Gc.run(true);
		#end
	}

	public static function enable():Void
	{
		#if (cpp || hl)
		Gc.enable(true);
		#end
	}

	/** Desactiva el GC automático (no lo desactiva del todo, solo evita que corra tan seguido). */
	public static function disable():Void
	{
		#if (cpp || hl)
		Gc.enable(false);
		#end
	}

	/** null = aun no se sabe si /proc se puede leer; false = no se puede (Windows, etc.), no se vuelve a intentar. */
	static var procReadable:Null<Bool> = null;

	/**
	 * RAM real que usa el proceso del juego (RSS de /proc/self/status), en bytes. Es lo que ve el sistema,
	 * no solo lo que tiene el GC de Haxe. Si /proc no existe cae a `currentMemUsage()`.
	 */
	public static function processMemUsage():Float
	{
		var text = readProc("/proc/self/status");
		if (text != null)
		{
			var kb = procKb(text, "VmRSS:");
			if (kb >= 0) return kb * 1024;
		}
		return currentMemUsage();
	}

	/**
	 * RAM de todo el dispositivo en bytes (`used` = total - disponible), de /proc/meminfo.
	 * null si no se puede leer (por ejemplo en Windows).
	 */
	public static function deviceMem():Null<{used:Float, total:Float}>
	{
		var text = readProc("/proc/meminfo");
		if (text == null) return null;
		var total = procKb(text, "MemTotal:");
		if (total <= 0) return null;
		var free = procKb(text, "MemAvailable:");
		if (free < 0) // kernels viejos sin MemAvailable
		{
			var memFree = procKb(text, "MemFree:");
			var buffers = procKb(text, "Buffers:");
			var cached = procKb(text, "Cached:");
			if (memFree < 0) return null;
			free = memFree + Math.max(0, buffers) + Math.max(0, cached);
		}
		return {used: Math.max(0, total - free) * 1024, total: total * 1024};
	}

	/** Lee un archivo de /proc (tamano 0 segun stat, por eso readAll y no getContent). null si no se puede. */
	static function readProc(path:String):Null<String>
	{
		#if sys
		if (procReadable == false) return null;
		try
		{
			var input = sys.io.File.read(path, false);
			var text = input.readAll().toString();
			input.close();
			procReadable = true;
			return text;
		}
		catch (e:Dynamic)
		{
			if (procReadable == null) procReadable = false;
		}
		#end
		return null;
	}

	/** Valor en kB de una linea `Clave:   1234 kB`; -1 si no esta. */
	static function procKb(text:String, key:String):Float
	{
		for (line in text.split("\n"))
		{
			if (!StringTools.startsWith(line, key)) continue;
			var value = Std.parseFloat(StringTools.trim(line.substr(key.length)));
			return Math.isNaN(value) ? -1 : value;
		}
		return -1;
	}

	/** Memoria actualmente usada por Haxe (no la memoria total del proceso). */
	public static inline function currentMemUsage():Float
	{
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_USAGE);
		#elseif hl
		return Gc.stats().currentMemory;
		#elseif sys
		return cast(cast(System.totalMemory, UInt), Float);
		#else
		return 0;
		#end
	}
}
