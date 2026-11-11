package funky.core;

#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#elseif neko
import neko.vm.Gc;
#end
import openfl.system.System;

final class MemoryUtil
{

	public static function clearMinor():Void
	{
		#if (cpp || neko)
		Gc.run(false);
		#end
	}

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

	public static function disable():Void
	{
		#if (cpp || hl)
		Gc.enable(false);
		#end
	}

	static var procReadable:Null<Bool> = null;

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

	public static function deviceMem():Null<{used:Float, total:Float}>
	{
		var text = readProc("/proc/meminfo");
		if (text == null) return null;
		var total = procKb(text, "MemTotal:");
		if (total <= 0) return null;
		var free = procKb(text, "MemAvailable:");
		if (free < 0)
		{
			var memFree = procKb(text, "MemFree:");
			var buffers = procKb(text, "Buffers:");
			var cached = procKb(text, "Cached:");
			if (memFree < 0) return null;
			free = memFree + Math.max(0, buffers) + Math.max(0, cached);
		}
		return {used: Math.max(0, total - free) * 1024, total: total * 1024};
	}

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
