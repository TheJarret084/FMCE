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
