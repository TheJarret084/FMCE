package funky.backend.converter;

import haxe.crypto.Crc32;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.zip.Compress;

/**
 * Codificador de PNG en Haxe puro, al estilo de UPNG.js: elige solo el mejor formato y comprime fuerte.
 *  - si la imagen usa 256 colores o menos, la guarda con paleta (PLTE + tRNS), sin perdida;
 *  - si usa mas y se pide `colors`, la cuantiza a esa cantidad de colores (median cut, como UPNG con `cnum`);
 *  - si no, RGBA de 8 bits;
 *  - elige el filtro de cada fila (el que deja menos diferencia), y comprime con zlib al maximo;
 *  - el color de los pixeles transparentes se pone en 0, asi comprimen mejor y se juntan colores.
 */
class PngHandler
{
	/**
	 * @param argb 4 bytes por pixel en orden A, R, G, B (como `BitmapData.getPixels`), alfa sin premultiplicar.
	 * @param colors 0 = sin perdida; de 2 a 256 = si la imagen tiene mas colores, se reduce a esa cantidad.
	 * @param level nivel de zlib (1 a 9).
	 */
	public static function encodeArgb(argb:Bytes, width:Int, height:Int, colors:Int = 0, level:Int = 9):Bytes
	{
		var count = width * height;
		if (argb.length < count * 4) throw "faltan pixeles: " + argb.length + " bytes para " + width + "x" + height;

		// 1) colores unicos (se corta al pasar de 256)
		var palette:Array<Int> = [];
		var lookup = new Map<Int, Int>();
		var tooMany = false;
		var transparent = false;
		for (i in 0...count)
		{
			var p = i * 4;
			var a = argb.get(p);
			var key = a == 0 ? 0 : (a << 24) | (argb.get(p + 1) << 16) | (argb.get(p + 2) << 8) | argb.get(p + 3);
			if (a < 255) transparent = true;
			if (!lookup.exists(key))
			{
				if (palette.length >= 256)
				{
					tooMany = true;
					break;
				}
				lookup.set(key, palette.length);
				palette.push(key);
			}
		}

		var indices:Null<Bytes> = null;
		if (!tooMany)
			indices = indexWith(argb, count, lookup);
		else if (colors >= 2 && colors <= 256)
		{
			var quantized = quantize(argb, count, colors);
			palette = quantized.palette;
			indices = quantized.indices;
		}

		var out = new BytesOutput();
		for (b in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) out.writeByte(b);

		if (indices != null)
		{
			chunk(out, "IHDR", header(width, height, 8, 3));
			var plte = Bytes.alloc(palette.length * 3);
			var alphas = Bytes.alloc(palette.length);
			var lastAlpha = -1;
			for (i in 0...palette.length)
			{
				var c = palette[i];
				plte.set(i * 3, (c >> 16) & 0xFF);
				plte.set(i * 3 + 1, (c >> 8) & 0xFF);
				plte.set(i * 3 + 2, c & 0xFF);
				var a = (c >>> 24) & 0xFF;
				alphas.set(i, a);
				if (a < 255) lastAlpha = i;
			}
			chunk(out, "PLTE", plte);
			if (transparent && lastAlpha >= 0) chunk(out, "tRNS", alphas.sub(0, lastAlpha + 1));
			chunk(out, "IDAT", Compress.run(filterRows(indices, width, height, 1), level));
		}
		else
		{
			chunk(out, "IHDR", header(width, height, 8, 6));
			var rgba = Bytes.alloc(count * 4);
			for (i in 0...count)
			{
				var p = i * 4;
				var a = argb.get(p);
				if (a == 0) continue; // transparente: RGBA = 0
				rgba.set(p, argb.get(p + 1));
				rgba.set(p + 1, argb.get(p + 2));
				rgba.set(p + 2, argb.get(p + 3));
				rgba.set(p + 3, a);
			}
			chunk(out, "IDAT", Compress.run(filterRows(rgba, width, height, 4), level));
		}
		chunk(out, "IEND", Bytes.alloc(0));
		return out.getBytes();
	}

	// ------------------------------------------------------------------ PNG

	static function header(w:Int, h:Int, depth:Int, colorType:Int):Bytes
	{
		var o = new BytesOutput();
		o.bigEndian = true;
		o.writeInt32(w);
		o.writeInt32(h);
		o.writeByte(depth);
		o.writeByte(colorType);
		o.writeByte(0);
		o.writeByte(0);
		o.writeByte(0);
		return o.getBytes();
	}

	static function chunk(out:BytesOutput, type:String, data:Bytes):Void
	{
		out.bigEndian = true;
		out.writeInt32(data.length);
		var body = Bytes.alloc(4 + data.length);
		body.blit(0, Bytes.ofString(type), 0, 4);
		body.blit(4, data, 0, data.length);
		out.writeBytes(body, 0, body.length);
		out.writeInt32(Crc32.make(body));
	}

	/** Filtros PNG por fila (none, sub, up, average, paeth): se queda con el de menor suma de valores absolutos. */
	static function filterRows(raw:Bytes, width:Int, height:Int, bpp:Int):Bytes
	{
		var stride = width * bpp;
		var out = Bytes.alloc(height * (stride + 1));
		var candidates = [for (_ in 0...5) Bytes.alloc(stride)];
		for (y in 0...height)
		{
			var row = y * stride;
			var prev = row - stride;
			var best = 0;
			var bestSum = 0x7FFFFFFF;
			for (f in 0...5)
			{
				var buf = candidates[f];
				var sum = 0;
				for (x in 0...stride)
				{
					var cur = raw.get(row + x);
					var a = x >= bpp ? raw.get(row + x - bpp) : 0;
					var b = y > 0 ? raw.get(prev + x) : 0;
					var c = (x >= bpp && y > 0) ? raw.get(prev + x - bpp) : 0;
					var v:Int;
					switch (f)
					{
						case 0: v = cur;
						case 1: v = cur - a;
						case 2: v = cur - b;
						case 3: v = cur - ((a + b) >> 1);
						default: v = cur - paeth(a, b, c);
					}
					v &= 0xFF;
					buf.set(x, v);
					sum += v < 128 ? v : 256 - v;
				}
				if (sum < bestSum)
				{
					bestSum = sum;
					best = f;
				}
			}
			var at = y * (stride + 1);
			out.set(at, best);
			out.blit(at + 1, candidates[best], 0, stride);
		}
		return out;
	}

	static inline function paeth(a:Int, b:Int, c:Int):Int
	{
		var p = a + b - c;
		var pa = p > a ? p - a : a - p;
		var pb = p > b ? p - b : b - p;
		var pc = p > c ? p - c : c - p;
		return (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
	}

	// ------------------------------------------------------------------ paleta

	static function indexWith(argb:Bytes, count:Int, lookup:Map<Int, Int>):Bytes
	{
		var out = Bytes.alloc(count);
		for (i in 0...count)
		{
			var p = i * 4;
			var a = argb.get(p);
			var key = a == 0 ? 0 : (a << 24) | (argb.get(p + 1) << 16) | (argb.get(p + 2) << 8) | argb.get(p + 3);
			out.set(i, lookup.get(key));
		}
		return out;
	}

	/**
	 * Reduce a `target` colores con median cut sobre un histograma de 5-5-5-4 bits (rojo, verde, azul, alfa). Cada casilla
	 * del histograma queda en una sola caja, asi cada pixel se asigna sin buscar el color mas cercano.
	 */
	static function quantize(argb:Bytes, count:Int, target:Int):{palette:Array<Int>, indices:Bytes}
	{
		var size = 1 << 19;
		var n = new Array<Int>();
		var sumA = new Array<Float>();
		var sumR = new Array<Float>();
		var sumG = new Array<Float>();
		var sumB = new Array<Float>();
		for (_ in 0...size)
		{
			n.push(0);
			sumA.push(0);
			sumR.push(0);
			sumG.push(0);
			sumB.push(0);
		}
		var keys = Bytes.alloc(count * 3);
		for (i in 0...count)
		{
			var p = i * 4;
			var a = argb.get(p);
			var k:Int;
			if (a == 0) k = 0;
			else
			{
				var r = argb.get(p + 1);
				var g = argb.get(p + 2);
				var b = argb.get(p + 3);
				k = ((a >> 4) << 15) | ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
				if (k == 0) k = 1; // el 0 es solo para "transparente"
				n[k]++;
				sumA[k] += a;
				sumR[k] += r;
				sumG[k] += g;
				sumB[k] += b;
			}
			keys.set(i * 3, k & 0xFF);
			keys.set(i * 3 + 1, (k >> 8) & 0xFF);
			keys.set(i * 3 + 2, (k >> 16) & 0xFF);
			if (a == 0) n[0]++;
		}

		var used:Array<Int> = [];
		for (k in 0...size)
			if (n[k] > 0) used.push(k);

		// cajas de median cut: se parte siempre la que tiene mas pixeles, por el canal de mayor rango
		var boxes:Array<Array<Int>> = [used];
		while (boxes.length < target)
		{
			var pick = -1;
			var pickCount = 1;
			for (i in 0...boxes.length)
			{
				if (boxes[i].length < 2) continue;
				var total = 0;
				for (k in boxes[i]) total += n[k];
				if (total > pickCount)
				{
					pickCount = total;
					pick = i;
				}
			}
			if (pick < 0) break;
			var box = boxes[pick];
			var minC = [255, 255, 255, 255];
			var maxC = [0, 0, 0, 0];
			for (k in box)
			{
				var comps = [(k >> 15) & 0xF, (k >> 10) & 0x1F, (k >> 5) & 0x1F, k & 0x1F];
				for (c in 0...4)
				{
					if (comps[c] < minC[c]) minC[c] = comps[c];
					if (comps[c] > maxC[c]) maxC[c] = comps[c];
				}
			}
			// el alfa pesa mas (4 bits) y se normaliza para compararlo con los canales de 5 bits
			var ranges = [(maxC[0] - minC[0]) * 2, maxC[1] - minC[1], maxC[2] - minC[2], maxC[3] - minC[3]];
			var axis = 0;
			for (c in 1...4)
				if (ranges[c] > ranges[axis]) axis = c;
			box.sort(function(x, y)
			{
				var cx = componentOf(x, axis);
				var cy = componentOf(y, axis);
				return cx != cy ? cx - cy : x - y;
			});
			var total = 0;
			for (k in box) total += n[k];
			var half = 0;
			var cut = 1;
			for (i in 0...box.length - 1)
			{
				half += n[box[i]];
				cut = i + 1;
				if (half * 2 >= total) break;
			}
			boxes[pick] = box.slice(0, cut);
			boxes.push(box.slice(cut));
		}

		// paleta (promedio de los colores reales de cada caja) y caja de cada casilla
		var palette:Array<Int> = [];
		var boxOf = Bytes.alloc(size);
		for (i in 0...boxes.length)
		{
			var total = 0;
			var a = 0.0;
			var r = 0.0;
			var g = 0.0;
			var b = 0.0;
			for (k in boxes[i])
			{
				boxOf.set(k, i);
				if (k == 0) continue;
				total += n[k];
				a += sumA[k];
				r += sumR[k];
				g += sumG[k];
				b += sumB[k];
			}
			if (total == 0) palette.push(0);
			else palette.push((Std.int(a / total + 0.5) << 24) | (Std.int(r / total + 0.5) << 16) | (Std.int(g / total + 0.5) << 8) | Std.int(b / total + 0.5));
		}

		var indices = Bytes.alloc(count);
		for (i in 0...count)
		{
			var k = keys.get(i * 3) | (keys.get(i * 3 + 1) << 8) | (keys.get(i * 3 + 2) << 16);
			indices.set(i, boxOf.get(k));
		}
		return {palette: palette, indices: indices};
	}

	static inline function componentOf(k:Int, axis:Int):Int
		return axis == 0 ? (k >> 15) & 0xF : (axis == 1 ? (k >> 10) & 0x1F : (axis == 2 ? (k >> 5) & 0x1F : k & 0x1F));
}
