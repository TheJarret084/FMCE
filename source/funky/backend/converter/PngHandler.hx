package funky.backend.converter;

import haxe.crypto.Crc32;
import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.zip.Compress;

class PngHandler
{

	public static function encodeArgb(argb:Bytes, width:Int, height:Int, colors:Int = 0, level:Int = 9):Bytes
	{
		var count = width * height;
		if (argb.length < count * 4) throw "faltan pixeles: " + argb.length + " bytes para " + width + "x" + height;

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
				if (a == 0) continue;
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

	static function filterRows(raw:Bytes, width:Int, height:Int, bpp:Int):Bytes
	{
		var stride = width * bpp;
		var out = Bytes.alloc(height * (stride + 1));
		if (bpp == 1)
		{
			for (y in 0...height) out.blit(y * (stride + 1) + 1, raw, y * stride, stride);
			return out;
		}
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

	static inline function dist(r1:Float, g1:Float, b1:Float, a1:Float, r2:Float, g2:Float, b2:Float, a2:Float):Float
	{
		var dr = r1 - r2;
		var dg = g1 - g2;
		var db = b1 - b2;
		var da = a1 - a2;
		return 2 * dr * dr + 4 * dg * dg + 3 * db * db + 6 * da * da;
	}

	static function quantize(argb:Bytes, count:Int, target:Int):{palette:Array<Int>, indices:Bytes}
	{
		var size = 1 << 19;
		var n = new Vector<Int>(size);
		var sumA = new Vector<Float>(size);
		var sumR = new Vector<Float>(size);
		var sumG = new Vector<Float>(size);
		var sumB = new Vector<Float>(size);
		for (i in 0...size)
		{
			n[i] = 0;
			sumA[i] = 0;
			sumR[i] = 0;
			sumG[i] = 0;
			sumB[i] = 0;
		}
		var keys = Bytes.alloc(count * 3);
		var transparentPixels = 0;
		for (i in 0...count)
		{
			var p = i * 4;
			var a = argb.get(p);
			var k:Int;
			if (a == 0)
			{
				k = 0;
				transparentPixels++;
			}
			else
			{
				var r = argb.get(p + 1);
				var g = argb.get(p + 2);
				var b = argb.get(p + 3);
				k = ((a >> 4) << 15) | ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
				if (k == 0) k = 1;
				n[k]++;
				sumA[k] += a;
				sumR[k] += r;
				sumG[k] += g;
				sumB[k] += b;
			}
			keys.set(i * 3, k & 0xFF);
			keys.set(i * 3 + 1, (k >> 8) & 0xFF);
			keys.set(i * 3 + 2, (k >> 16) & 0xFF);
		}

		var used:Array<Int> = [];
		for (k in 1...size)
			if (n[k] > 0) used.push(k);

		var reserved = transparentPixels > 0 ? 1 : 0;
		var want = target - reserved;
		if (want < 1) want = 1;

		var boxes:Array<Array<Int>> = [used];
		while (boxes.length < want)
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

		var m = boxes.length;
		var pr = new Vector<Float>(m);
		var pg = new Vector<Float>(m);
		var pb = new Vector<Float>(m);
		var pa = new Vector<Float>(m);
		for (i in 0...m)
		{
			var total = 0;
			var a = 0.0;
			var r = 0.0;
			var g = 0.0;
			var b = 0.0;
			for (k in boxes[i])
			{
				total += n[k];
				a += sumA[k];
				r += sumR[k];
				g += sumG[k];
				b += sumB[k];
			}
			if (total == 0) total = 1;
			pa[i] = a / total;
			pr[i] = r / total;
			pg[i] = g / total;
			pb[i] = b / total;
		}

		var cells = used.length;
		var cr = new Vector<Float>(cells);
		var cg = new Vector<Float>(cells);
		var cb = new Vector<Float>(cells);
		var ca = new Vector<Float>(cells);
		var cw = new Vector<Float>(cells);
		for (i in 0...cells)
		{
			var k = used[i];
			var c:Float = n[k];
			cw[i] = c;
			ca[i] = sumA[k] / c;
			cr[i] = sumR[k] / c;
			cg[i] = sumG[k] / c;
			cb[i] = sumB[k] / c;
		}
		var near = new Vector<Int>(cells);
		var passes = cells > m ? 4 : 0;
		for (pass in 0...passes + 1)
		{
			for (i in 0...cells) near[i] = nearest(cr[i], cg[i], cb[i], ca[i], pr, pg, pb, pa, m);
			if (pass == passes) break;
			var ar = new Vector<Float>(m);
			var ag = new Vector<Float>(m);
			var ab = new Vector<Float>(m);
			var aa = new Vector<Float>(m);
			var aw = new Vector<Float>(m);
			for (i in 0...m)
			{
				ar[i] = 0;
				ag[i] = 0;
				ab[i] = 0;
				aa[i] = 0;
				aw[i] = 0;
			}
			for (i in 0...cells)
			{
				var j = near[i];
				var w = cw[i];
				ar[j] += cr[i] * w;
				ag[j] += cg[i] * w;
				ab[j] += cb[i] * w;
				aa[j] += ca[i] * w;
				aw[j] += w;
			}
			for (j in 0...m)
				if (aw[j] > 0)
				{
					pr[j] = ar[j] / aw[j];
					pg[j] = ag[j] / aw[j];
					pb[j] = ab[j] / aw[j];
					pa[j] = aa[j] / aw[j];
				}
		}

		var palette:Array<Int> = [];
		if (reserved == 1) palette.push(0);
		for (j in 0...m) palette.push((clamp(pa[j]) << 24) | (clamp(pr[j]) << 16) | (clamp(pg[j]) << 8) | clamp(pb[j]));
		var indexOf = Bytes.alloc(size);
		for (i in 0...cells) indexOf.set(used[i], near[i] + reserved);

		var indices = Bytes.alloc(count);
		for (i in 0...count)
		{
			var k = keys.get(i * 3) | (keys.get(i * 3 + 1) << 8) | (keys.get(i * 3 + 2) << 16);
			indices.set(i, k == 0 ? 0 : indexOf.get(k));
		}
		return {palette: palette, indices: indices};
	}

	static function nearest(r:Float, g:Float, b:Float, a:Float, pr:Vector<Float>, pg:Vector<Float>, pb:Vector<Float>, pa:Vector<Float>, m:Int):Int
	{
		var best = 0;
		var bestDistance = 1.0e30;
		for (i in 0...m)
		{
			var d = dist(r, g, b, a, pr[i], pg[i], pb[i], pa[i]);
			if (d < bestDistance)
			{
				bestDistance = d;
				best = i;
			}
		}
		return best;
	}

	static inline function clamp(v:Float):Int
		return v <= 0 ? 0 : (v >= 255 ? 255 : Std.int(v + 0.5));

	static inline function componentOf(k:Int, axis:Int):Int
		return axis == 0 ? (k >> 15) & 0xF : (axis == 1 ? (k >> 10) & 0x1F : (axis == 2 ? (k >> 5) & 0x1F : k & 0x1F));
}
