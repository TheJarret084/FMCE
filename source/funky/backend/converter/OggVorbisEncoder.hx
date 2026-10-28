package funky.backend.converter;

import haxe.ds.Vector;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

/** Escritor de bits como Vorbis: el primer bit va en el bit menos significativo del byte. */
private class BitWriter
{
	var out:BytesOutput = new BytesOutput();
	var cur:Int = 0;
	var count:Int = 0;

	public function new() {}

	/** Escribe los `bits` bajos de `value` (hasta 16 por llamada). */
	public function write(value:Int, bits:Int):Void
	{
		if (bits <= 0) return;
		cur |= (value & ((1 << bits) - 1)) << count;
		count += bits;
		while (count >= 8)
		{
			out.writeByte(cur & 0xFF);
			cur >>>= 8;
			count -= 8;
		}
	}

	public function write24(value:Int):Void
	{
		write(value & 0xFFFF, 16);
		write((value >> 16) & 0xFF, 8);
	}

	public function write32(value:Int):Void
	{
		write(value & 0xFFFF, 16);
		write((value >>> 16) & 0xFFFF, 16);
	}

	/** Bits de un codigo de Huffman: el primero que se lee es el del extremo alto. */
	public function writeCode(code:Int, length:Int):Void
	{
		var i = length - 1;
		while (i >= 0)
		{
			write((code >> i) & 1, 1);
			i--;
		}
	}

	public function finish():Bytes
	{
		if (count > 0)
		{
			out.writeByte(cur & 0xFF);
			cur = 0;
			count = 0;
		}
		return out.getBytes();
	}
}

/** Un codebook escalar (dimension 1) con codigos de Huffman canonicos; la entrada 0 es la mas corta. */
private class Book
{
	public var entries:Int;
	public var lengths:Array<Int> = [];
	public var codes:Array<Int> = [];
	/** Valor que representa cada entrada (-K..K). Vacio en el classbook. */
	public var values:Array<Int> = [];
	public var maxValue:Int = 0;
	var entryOfValue:Array<Int> = [];

	public function new() {}

	/** Libro de enteros -K..K con probabilidad ~ ratio^|v|. */
	public static function ofValues(k:Int, ratio:Float):Book
	{
		var b = new Book();
		b.maxValue = k;
		b.entries = 2 * k + 1;
		var vals = [for (v in -k...k + 1) v];
		var weights = [for (v in vals) Math.pow(ratio, Math.abs(v))];
		var lens = huffman(weights);
		var order = [for (i in 0...vals.length) i];
		order.sort(function(a, c)
		{
			if (lens[a] != lens[c]) return lens[a] - lens[c];
			var aa = Std.int(Math.abs(vals[a]));
			var cc = Std.int(Math.abs(vals[c]));
			if (aa != cc) return aa - cc;
			return vals[a] - vals[c];
		});
		b.entryOfValue = [for (_ in 0...vals.length) 0];
		for (entry in 0...order.length)
		{
			b.lengths.push(lens[order[entry]]);
			b.values.push(vals[order[entry]]);
			b.entryOfValue[vals[order[entry]] + k] = entry;
		}
		b.assignCodes();
		return b;
	}

	/** Classbook con largos fijos (ya en orden no decreciente). */
	public static function ofLengths(lengths:Array<Int>):Book
	{
		var b = new Book();
		b.entries = lengths.length;
		b.lengths = lengths.copy();
		b.assignCodes();
		return b;
	}

	function assignCodes():Void
	{
		var code = 0;
		for (i in 0...entries)
		{
			if (i > 0) code = (code + 1) << (lengths[i] - lengths[i - 1]);
			codes.push(code);
		}
	}

	public inline function entryFor(value:Int):Int
		return entryOfValue[value + maxValue];

	/** Largos de un arbol de Huffman para los pesos dados. */
	static function huffman(weights:Array<Float>):Array<Int>
	{
		var n = weights.length;
		var w = weights.copy();
		var parent = [for (_ in 0...n * 2) -1];
		var alive = [for (i in 0...n) i];
		var next = n;
		while (alive.length > 1)
		{
			alive.sort(function(a, c) return w[a] < w[c] ? -1 : (w[a] > w[c] ? 1 : a - c));
			var a = alive.shift();
			var c = alive.shift();
			w[next] = w[a] + w[c];
			parent[a] = next;
			parent[c] = next;
			alive.push(next);
			next++;
		}
		var lens = [];
		for (i in 0...n)
		{
			var d = 0;
			var p = i;
			while (parent[p] >= 0)
			{
				p = parent[p];
				d++;
			}
			lens.push(Std.int(Math.max(1, d)));
		}
		return lens;
	}
}

/**
 * Codificador de OGG Vorbis en Haxe puro, hecho para que el .FNMM (Funky Maker: Mobile, que pide OGG) pueda llevar una mezcla.
 *
 * Es un codificador sencillo, no un libvorbis: un solo tamano de bloque (2048), un floor tipo 1 de dos puntos (el mismo paso de
 * cuantizacion para todo el frame, con una pendiente hacia los agudos), cuantizacion escalar con cinco clases de residuo,
 * acoplamiento magnitud/angulo en estereo y corte de agudos. Pesa mas que un OGG de libvorbis al mismo nivel de calidad,
 * pero cualquier decodificador de Vorbis lo lee.
 */
class OggVorbisEncoder
{
	static inline var BLOCK:Int = 2048;
	static inline var HALF:Int = 1024;
	static inline var PART:Int = 16;
	/** Valor maximo de un coeficiente cuantizado (antes del acoplamiento): el angulo puede llegar al doble. */
	static inline var QMAX:Int = 511;
	static inline var CLASSES:Int = 6;
	static inline var FLOOR_FIRST:Float = 1.0649863e-07;
	static var CLASS_LIMIT:Array<Int> = [0, 1, 3, 15, 127, 1023];

	var channels:Int;
	var rate:Int;
	var books:Array<Book>;
	var endBin:Int;
	var floorY0:Int = 0;
	var floorY1:Int = 0;
	/** Cuanto mas chico, mas fiel: relacion senal/ruido que se busca en cada frame, en dB. */
	var snrDb:Float;
	var tiltSteps:Int;
	var dbPerStep:Float;
	var amp:Vector<Float>;
	var specs:Array<Vector<Float>>;
	var window:Vector<Float>;

	// FFT de HALF/2 puntos y twiddles de la DCT-IV
	var fftRe:Vector<Float>;
	var fftIm:Vector<Float>;
	var fftCos:Vector<Float>;
	var fftSin:Vector<Float>;
	var bitrev:Vector<Int>;
	var twCos:Vector<Float>;
	var twSin:Vector<Float>;
	var postCos:Vector<Float>;
	var postSin:Vector<Float>;
	var fold:Vector<Float>;
	var spec:Vector<Float>;
	var scale:Float;

	function new(channels:Int, rate:Int, quality:Float, cutoffHz:Float, tiltDb:Float)
	{
		this.channels = channels;
		this.rate = rate;

		// libros: 0 = classbook (clase de cada particion); 1..4 = valores para cada clase
		books = [
			Book.ofLengths([1, 2, 3, 4, 5, 5]),
			Book.ofValues(1, 0.30),
			Book.ofValues(3, 0.45),
			Book.ofValues(15, 0.65),
			Book.ofValues(127, 0.93),
			Book.ofValues(1023, 0.985)
		];

		// el paso de cuantizacion se calcula en cada frame a partir de su volumen; la tabla del floor va de -141 dB a 0 dB en 255 pasos
		snrDb = 12 + 38 * quality;
		dbPerStep = 20 * Math.log(1.0 / FLOOR_FIRST) / Math.log(10) / 255;
		tiltSteps = Math.round(tiltDb / dbPerStep);
		amp = new Vector<Float>(HALF);
		specs = [for (_ in 0...channels) new Vector<Float>(HALF)];

		var maxBin = Std.int(Math.min(HALF, Math.floor(cutoffHz / (rate / 2) * HALF)));
		endBin = Std.int(maxBin / PART) * PART;
		if (endBin < PART) endBin = PART;

		window = new Vector<Float>(BLOCK);
		for (i in 0...BLOCK)
		{
			var s = Math.sin(Math.PI * (i + 0.5) / BLOCK);
			window[i] = Math.sin(Math.PI / 2 * s * s);
		}
		initFft();
		fold = new Vector<Float>(HALF);
		spec = new Vector<Float>(HALF);
		scale = 2.0 / HALF;
	}

	static inline function clampInt(v:Int, lo:Int, hi:Int):Int
		return v < lo ? lo : (v > hi ? hi : v);

	/** Amplitud de la floor para cada bin: lo mismo que calcula el decodificador (linea entera + tabla en dB). */
	function renderFloor():Void
	{
		floorY1 = clampInt(floorY0 + tiltSteps, 0, 255);
		var y0 = floorY0;
		var y1 = floorY1;
		var x1 = HALF;
		var dy = y1 - y0;
		var adx = x1;
		var ady = Std.int(Math.abs(dy));
		var base = Std.int(dy / adx);
		var sy = dy < 0 ? base - 1 : base + 1;
		ady = ady - Std.int(Math.abs(base)) * adx;
		var y = y0;
		var err = 0;
		amp[0] = dbTable(y);
		for (x in 1...HALF)
		{
			err += ady;
			if (err >= adx)
			{
				err -= adx;
				y += sy;
			}
			else
				y += base;
			amp[x] = dbTable(y);
		}
	}

	static inline function dbTable(i:Int):Float
		return Math.pow(FLOOR_FIRST, (255 - clampInt(i, 0, 255)) / 255.0);

	// ------------------------------------------------------------------ transformada

	function initFft():Void
	{
		var h = HALF >> 1;
		fftRe = new Vector<Float>(h);
		fftIm = new Vector<Float>(h);
		fftCos = new Vector<Float>(h >> 1);
		fftSin = new Vector<Float>(h >> 1);
		for (i in 0...(h >> 1))
		{
			fftCos[i] = Math.cos(2 * Math.PI * i / h);
			fftSin[i] = -Math.sin(2 * Math.PI * i / h);
		}
		bitrev = new Vector<Int>(h);
		var bits = 0;
		while ((1 << bits) < h) bits++;
		for (i in 0...h)
		{
			var r = 0;
			for (b in 0...bits)
				if ((i & (1 << b)) != 0) r |= 1 << (bits - 1 - b);
			bitrev[i] = r;
		}
		twCos = new Vector<Float>(h);
		twSin = new Vector<Float>(h);
		postCos = new Vector<Float>(h);
		postSin = new Vector<Float>(h);
		for (n in 0...h)
		{
			var theta = Math.PI * (4 * n + 1) / (4 * HALF);
			twCos[n] = Math.cos(theta);
			twSin[n] = Math.sin(theta);
			postCos[n] = Math.cos(Math.PI * n / HALF);
			postSin[n] = Math.sin(Math.PI * n / HALF);
		}
	}

	function fft():Void
	{
		var n = HALF >> 1;
		for (i in 0...n)
		{
			var j = bitrev[i];
			if (j > i)
			{
				var tr = fftRe[i];
				fftRe[i] = fftRe[j];
				fftRe[j] = tr;
				var ti = fftIm[i];
				fftIm[i] = fftIm[j];
				fftIm[j] = ti;
			}
		}
		var size = 2;
		while (size <= n)
		{
			var half = size >> 1;
			var step = Std.int(n / size);
			var start = 0;
			while (start < n)
			{
				for (k in 0...half)
				{
					var wr = fftCos[k * step];
					var wi = fftSin[k * step];
					var a = start + k;
					var b = a + half;
					var xr = fftRe[b] * wr - fftIm[b] * wi;
					var xi = fftRe[b] * wi + fftIm[b] * wr;
					fftRe[b] = fftRe[a] - xr;
					fftIm[b] = fftIm[a] - xi;
					fftRe[a] += xr;
					fftIm[a] += xi;
				}
				start += size;
			}
			size <<= 1;
		}
	}

	/** DCT-IV de HALF puntos: `fold` -> `spec`. */
	function dct4():Void
	{
		var h = HALF >> 1;
		for (n in 0...h)
		{
			var a = fold[2 * n];
			var b = fold[HALF - 1 - 2 * n];
			var c = twCos[n];
			var s = twSin[n];
			fftRe[n] = a * c + b * s;
			fftIm[n] = b * c - a * s;
		}
		fft();
		for (k in 0...h)
		{
			var c = postCos[k];
			var s = postSin[k];
			var yr = fftRe[k] * c + fftIm[k] * s;
			var yi = fftIm[k] * c - fftRe[k] * s;
			spec[2 * k] = yr;
			spec[HALF - 1 - 2 * k] = -yi;
		}
	}

	/** MDCT de un bloque ya enventanado `x` (BLOCK muestras) -> `spec` (HALF coeficientes), con la escala del decodificador. */
	function mdct(x:Vector<Float>):Void
	{
		var h = HALF >> 1;
		for (n in 0...h)
		{
			fold[n] = -x[3 * h - 1 - n] - x[3 * h + n];
			fold[h + n] = x[n] - x[HALF - 1 - n];
		}
		dct4();
	}

	// ------------------------------------------------------------------ cabeceras

	static function packFloat(w:BitWriter, x:Float):Void
	{
		if (x == 0)
		{
			w.write32(0);
			return;
		}
		var sign = x < 0 ? 1 : 0;
		var ax = Math.abs(x);
		var ex = Math.floor(Math.log(ax) / Math.log(2));
		var mant = Math.round(ax / Math.pow(2, ex - 20));
		if (mant >= 2097152)
		{
			mant = Math.round(mant / 2);
			ex++;
		}
		var biased = Std.int(ex - 20 + 788);
		var m = Std.int(mant);
		w.write(m & 0xFFFF, 16);
		w.write(((m >> 16) & 0x1F) | ((biased & 0x3FF) << 5) | (sign << 15), 16);
	}

	function writeBook(w:BitWriter, b:Book):Void
	{
		w.write24(0x564342);
		w.write(1, 16);
		w.write24(b.entries);
		w.write(0, 1); // no ordenado
		w.write(0, 1); // no disperso
		for (len in b.lengths) w.write(len - 1, 5);
		if (b.values.length == 0)
		{
			w.write(0, 4);
			return;
		}
		w.write(1, 4); // lookup tipo 1 (lattice): con dimension 1 cada entrada tiene su propio valor
		packFloat(w, -b.maxValue);
		packFloat(w, 1.0);
		var valueBits = 1;
		while ((1 << valueBits) <= 2 * b.maxValue) valueBits++;
		w.write(valueBits - 1, 4);
		w.write(0, 1);
		for (v in b.values) w.write(v + b.maxValue, valueBits);
	}

	function identificationHeader(nominalBitrate:Int):Bytes
	{
		var o = new BytesOutput();
		o.writeByte(1);
		o.writeString("vorbis");
		o.writeInt32(0);
		o.writeByte(channels);
		o.writeInt32(rate);
		o.writeInt32(0);
		o.writeInt32(nominalBitrate);
		o.writeInt32(0);
		o.writeByte(11 | (11 << 4)); // blocksize_0 = blocksize_1 = 2^11
		o.writeByte(1);
		return o.getBytes();
	}

	static function commentHeader():Bytes
	{
		var o = new BytesOutput();
		o.writeByte(3);
		o.writeString("vorbis");
		var vendor = "FMCE OggVorbisEncoder";
		o.writeInt32(vendor.length);
		o.writeString(vendor);
		o.writeInt32(0);
		o.writeByte(1);
		return o.getBytes();
	}

	function setupHeader():Bytes
	{
		var w = new BitWriter();
		w.write(5, 8);
		for (c in "vorbis".split("")) w.write(c.charCodeAt(0), 8);

		w.write(books.length - 1, 8);
		for (b in books) writeBook(w, b);

		// transformaciones de tiempo: una, sin uso
		w.write(0, 6);
		w.write(0, 16);

		// floor: tipo 1, sin particiones (solo los puntos 0 y 2^rangebits), multiplicador 1 (rango 256)
		w.write(0, 6);
		w.write(1, 16);
		w.write(0, 5);
		w.write(0, 2);
		w.write(10, 4);

		// residuo: tipo 1, cinco clases (0 = silencio)
		w.write(0, 6);
		w.write(1, 16);
		w.write24(0);
		w.write24(endBin);
		w.write24(PART - 1);
		w.write(CLASSES - 1, 6);
		w.write(0, 8);
		for (c in 0...CLASSES)
		{
			w.write(c == 0 ? 0 : 1, 3);
			w.write(0, 1);
		}
		for (c in 1...CLASSES) w.write(c, 8);

		// mapping: un submapa; en estereo, acoplamiento canal 0 (magnitud) / canal 1 (angulo)
		w.write(0, 6);
		w.write(0, 16);
		w.write(0, 1);
		if (channels == 2)
		{
			w.write(1, 1);
			w.write(0, 8);
			w.write(0, 1);
			w.write(1, 1);
		}
		else
			w.write(0, 1);
		w.write(0, 2);
		w.write(0, 8);
		w.write(0, 8);
		w.write(0, 8);

		// un modo: bloque corto (= BLOCK, los dos tamanos son iguales)
		w.write(0, 6);
		w.write(0, 1);
		w.write(0, 16);
		w.write(0, 16);
		w.write(0, 8);

		w.write(1, 1);
		return w.finish();
	}

	// ------------------------------------------------------------------ paquetes de audio

	function sampleAt(pcm:Bytes, offset:Int, frames:Int, pos:Int, ch:Int):Float
	{
		if (pos < 0 || pos >= frames) return 0;
		var v = pcm.getUInt16(offset + (pos * channels + ch) * 2);
		return (v >= 32768 ? v - 65536 : v) / 32768.0;
	}

	function encodeFrame(pcm:Bytes, offset:Int, frames:Int, t:Int, q:Array<Vector<Int>>, cls:Array<Vector<Int>>):Bytes
	{
		var start = (t - 1) * HALF;
		var block = new Vector<Float>(BLOCK);
		var energy = 0.0;
		var peak = 0.0;
		for (ch in 0...channels)
		{
			for (i in 0...BLOCK) block[i] = sampleAt(pcm, offset, frames, start + i, ch) * window[i];
			mdct(block);
			var sp = specs[ch];
			for (k in 0...HALF)
			{
				sp[k] = spec[k] * scale;
				if (k < endBin)
				{
					energy += sp[k] * sp[k];
					if (Math.abs(sp[k]) > peak) peak = Math.abs(sp[k]);
				}
			}
		}

		// paso de este frame: ruido de cuantizacion (paso / raiz de 12) a `snrDb` por debajo del volumen del frame
		var rms = Math.sqrt(energy / (endBin * channels));
		// ... pero nunca tan fino que el coeficiente mas grande no entre en el libro mas ancho
		var step = Math.max(Math.max(rms * 3.46 / Math.pow(10, snrDb / 20), peak / (QMAX * 0.98)), 1.0e-5);
		floorY0 = clampInt(255 + Math.round(20 * Math.log(step) / Math.log(10) / dbPerStep), 0, 255);
		renderFloor();

		for (ch in 0...channels)
		{
			var qc = q[ch];
			var sp = specs[ch];
			for (k in 0...endBin)
			{
				var v = Math.round(sp[k] / amp[k]);
				qc[k] = v > QMAX ? QMAX : (v < -QMAX ? -QMAX : Std.int(v));
			}
		}

		if (channels == 2)
		{
			var a = q[0];
			var b = q[1];
			for (k in 0...endBin)
			{
				var l = a[k];
				var r = b[k];
				var mag:Int;
				var ang:Int;
				if (Std.int(Math.abs(l)) > Std.int(Math.abs(r)))
				{
					mag = l;
					ang = l > 0 ? l - r : r - l;
				}
				else
				{
					mag = r;
					ang = r > 0 ? l - r : r - l;
				}
				a[k] = mag;
				b[k] = ang;
			}
		}

		var parts = Std.int(endBin / PART);
		for (ch in 0...channels)
			for (p in 0...parts)
			{
				var peak = 0;
				for (k in p * PART...(p + 1) * PART)
				{
					var m = Std.int(Math.abs(q[ch][k]));
					if (m > peak) peak = m;
				}
				var c = 0;
				while (c < CLASSES - 1 && peak > CLASS_LIMIT[c]) c++;
				cls[ch][p] = c;
			}

		var w = new BitWriter();
		w.write(0, 1); // paquete de audio
		for (ch in 0...channels)
		{
			w.write(1, 1);
			w.write(floorY0, 8);
			w.write(floorY1, 8);
		}
		var classBook = books[0];
		for (p in 0...parts)
		{
			for (ch in 0...channels) w.writeCode(classBook.codes[cls[ch][p]], classBook.lengths[cls[ch][p]]);
			for (ch in 0...channels)
			{
				var c = cls[ch][p];
				if (c == 0) continue;
				var book = books[c];
				for (k in p * PART...(p + 1) * PART)
				{
					var entry = book.entryFor(q[ch][k]);
					w.writeCode(book.codes[entry], book.lengths[entry]);
				}
			}
		}
		return w.finish();
	}

	// ------------------------------------------------------------------ Ogg

	static var crcTable:Null<Array<Int>> = null;

	static function crc(data:Bytes):Int
	{
		if (crcTable == null)
		{
			crcTable = [];
			for (i in 0...256)
			{
				var r = i << 24;
				for (_ in 0...8) r = (r & 0x80000000) != 0 ? (r << 1) ^ 0x04C11DB7 : r << 1;
				crcTable.push(r);
			}
		}
		var c = 0;
		for (i in 0...data.length) c = (c << 8) ^ crcTable[((c >>> 24) & 0xFF) ^ data.get(i)];
		return c;
	}

	static function page(serial:Int, seq:Int, flags:Int, granule:Float, packets:Array<Bytes>):Bytes
	{
		var segments:Array<Int> = [];
		for (p in packets)
		{
			var n = p.length;
			while (n >= 255)
			{
				segments.push(255);
				n -= 255;
			}
			segments.push(n);
		}
		var body = 0;
		for (p in packets) body += p.length;
		var o = new BytesOutput();
		o.writeString("OggS");
		o.writeByte(0);
		o.writeByte(flags);
		// granule como int64 little endian (las posiciones caben en 52 bits)
		var low = Std.int(granule % 4294967296.0);
		var high = Std.int(Math.floor(granule / 4294967296.0));
		o.writeInt32(low);
		o.writeInt32(high);
		o.writeInt32(serial);
		o.writeInt32(seq);
		o.writeInt32(0);
		o.writeByte(segments.length);
		for (s in segments) o.writeByte(s);
		for (p in packets) o.write(p);
		var bytes = o.getBytes();
		var sum = crc(bytes);
		bytes.setInt32(22, sum);
		return bytes;
	}

	// ------------------------------------------------------------------ API

	/**
	 * Codifica PCM de 16 bits entrelazado (`frames` cuadros, 1 o 2 canales) a OGG Vorbis.
	 * @param quality 0 = chico, 1 = mejor (el paso de cuantizacion baja de -30 dB a -80 dB).
	 * @param cutoffHz los agudos por encima de esto se descartan.
	 * @param tiltDb cuanto mas grueso es el paso en los agudos que en los graves.
	 */
	public static function encode(pcm:Bytes, offset:Int, frames:Int, channels:Int, rate:Int, quality:Float = 0.55, cutoffHz:Float = 16500, tiltDb:Float = 14):Bytes
	{
		if (channels < 1 || channels > 2) throw "solo se codifica mono o estereo";
		var enc = new OggVorbisEncoder(channels, rate, quality, cutoffHz, tiltDb);
		return enc.run(pcm, offset, frames);
	}

	function run(pcm:Bytes, offset:Int, frames:Int):Bytes
	{
		var serial = 0x464D4345;
		var seq = 0;
		var out = new BytesOutput();

		var ident = identificationHeader(0);
		var setup = setupHeader();
		out.write(page(serial, seq++, 0x02, 0, [ident]));
		out.write(page(serial, seq++, 0x00, 0, [commentHeader(), setup]));

		var q:Array<Vector<Int>> = [for (_ in 0...channels) new Vector<Int>(HALF)];
		var cls:Array<Vector<Int>> = [for (_ in 0...channels) new Vector<Int>(HALF)];
		var count = Std.int(Math.ceil(frames / HALF)) + 1;
		var pending:Array<Bytes> = [];
		var segs = 0;
		var granule:Float = 0;
		for (t in 0...count)
		{
			var packet = encodeFrame(pcm, offset, frames, t, q, cls);
			var need = Std.int(packet.length / 255) + 1;
			granule = t == 0 ? 0 : Math.min(frames, t * HALF);
			if (pending.length > 0 && (segs + need > 250))
			{
				out.write(page(serial, seq++, 0x00, lastGranule, pending));
				pending = [];
				segs = 0;
			}
			pending.push(packet);
			segs += need;
			lastGranule = granule;
			if (t == 0)
			{
				// el primer paquete no produce muestras: va solo en su pagina (granule 0), asi los lectores saben donde empieza el audio
				out.write(page(serial, seq++, 0x00, 0, pending));
				pending = [];
				segs = 0;
			}
		}
		out.write(page(serial, seq++, 0x04, frames, pending));
		return out.getBytes();
	}

	var lastGranule:Float = 0;
}
