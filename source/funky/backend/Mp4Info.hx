package funky.backend;

import haxe.io.Bytes;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Lee ancho y alto de un .mp4 sin reproducirlo. */
class Mp4Info
{
	/** Una caja `moov` mas grande que esto se considera corrupta (los .mp4 normales miden unos KB). */
	static inline var MAX_MOOV:Int = 64 * 1024 * 1024;

	static var cache:Map<String, Null<{w:Int, h:Int}>> = new Map();

	public static function size(path:String):Null<{w:Int, h:Int}>
	{
		#if sys
		if (cache.exists(path)) return cache.get(path);

		var result:Null<{w:Int, h:Int}> = null;
		try
		{
			result = read(path);
		}
		catch (e:Dynamic) {}

		cache.set(path, result);
		return result;
		#else
		return null;
		#end
	}

	#if sys
	static function read(path:String):Null<{w:Int, h:Int}>
	{
		if (!FileSystem.exists(path)) return null;

		var length = FileSystem.stat(path).size;
		var input = File.read(path, true);
		try
		{
			var pos = 0.0;
			while (pos + 8 <= length)
			{
				input.seek(Std.int(pos), SeekBegin);
				var head = input.read(8);
				var boxSize:Float = u32(head, 0);
				var type = head.getString(4, 4);
				var header = 8;

				if (boxSize == 1)
				{
					var large = input.read(8);
					boxSize = u32(large, 0) * 4294967296.0 + u32(large, 4);
					header = 16;
				}
				else if (boxSize == 0)
					boxSize = length - pos;

				if (boxSize < header) break;

				if (type == "moov")
				{
					var inner = Std.int(boxSize - header);
					if (inner <= 0 || inner > MAX_MOOV) break;
					var content = input.read(inner);
					input.close();
					return find(content, 0, content.length, 0);
				}
				pos += boxSize;
			}
		}
		catch (e:Dynamic) {}

		try
			input.close()
		catch (e:Dynamic) {}
		return null;
	}

	/** Recorre las cajas de `bytes[start...end]`: entra a `trak` / `mdia`-less hijos y lee el primer `tkhd` con tamano. */
	static function find(bytes:Bytes, start:Int, end:Int, depth:Int):Null<{w:Int, h:Int}>
	{
		if (depth > 6) return null;

		var p = start;
		while (p + 8 <= end)
		{
			var boxSize = Std.int(u32(bytes, p));
			var type = bytes.getString(p + 4, 4);
			if (boxSize < 8 || p + boxSize > end) break;

			if (type == "trak")
			{
				var found = find(bytes, p + 8, p + boxSize, depth + 1);
				if (found != null) return found;
			}
			else if (type == "tkhd")
			{
				var content = p + 8;
				var version = bytes.get(content);
				var offset = version == 1 ? 88 : 76; // despues de la matriz de transformacion
				if (content + offset + 8 <= p + boxSize)
				{
					var w = Std.int(u32(bytes, content + offset) / 65536);
					var h = Std.int(u32(bytes, content + offset + 4) / 65536);
					if (w > 0 && h > 0) return {w: w, h: h};
				}
			}
			p += boxSize;
		}
		return null;
	}

	/** Entero de 32 bits sin signo, big endian (el orden de las cajas mp4). */
	static function u32(bytes:Bytes, pos:Int):Float
		return bytes.get(pos) * 16777216.0 + (bytes.get(pos + 1) << 16 | bytes.get(pos + 2) << 8 | bytes.get(pos + 3));
	#end
}
