package funky.backend.converter;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
#if (lime_cffi && !macro)
import lime.media.AudioBuffer;
#end

typedef MixResult =
{
	/** OGG Vorbis con todas las pistas sumadas (null si no se pudo decodificar o codificar). */
	var ogg:Null<Bytes>;
	var used:Array<String>;
	var failed:Array<String>;
	var seconds:Float;
}

/**
 * Suma varias pistas de audio en una sola (para el .FNMM, que solo tiene un `music`).
 * Decodifica con lime (ogg/wav...), pasa todo a estereo a la frecuencia de la primera pista y lo codifica a OGG Vorbis
 * con `OggVorbisEncoder` (el FNMM de Funky Maker: Mobile solo lee OGG).
 */
class AudioMixer
{
	static inline var HEADER:Int = 44;

	var out:Bytes;
	var frames:Int = 0;
	var rate:Int = 0;

	public function new() {}

	/** Decodifica y mezcla `files` (en orden). `names` solo sirve para informar cual fallo. */
	public static function mix(names:Array<String>, files:Array<Bytes>, quality:Float = 0.45):MixResult
	{
		var result:MixResult = {ogg: null, used: [], failed: [], seconds: 0};
		#if (lime_cffi && !macro)
		var mixer = new AudioMixer();
		for (i in 0...files.length)
		{
			var buffer:Null<AudioBuffer> = null;
			try
				buffer = AudioBuffer.fromBytes(files[i])
			catch (e:Dynamic) {}
			if (buffer == null || buffer.data == null || buffer.bitsPerSample != 16 || buffer.channels < 1 || buffer.sampleRate < 8000)
			{
				result.failed.push(names[i]);
				continue;
			}
			var pcm:Bytes = buffer.data.buffer;
			mixer.add(pcm, buffer.data.byteOffset, buffer.channels, buffer.sampleRate, Std.int(buffer.data.byteLength / (2 * buffer.channels)));
			result.used.push(names[i]);
		}
		if (result.used.length > 0)
		{
			result.seconds = mixer.seconds();
			try
				result.ogg = mixer.finishOgg(quality)
			catch (e:Dynamic) {}
		}
		#else
		for (n in names) result.failed.push(n);
		#end
		return result;
	}

	public function seconds():Float
		return rate > 0 ? frames / rate : 0;

	/** Suma una pista de PCM de 16 bits entrelazado. La primera fija la frecuencia; las demas se re-muestrean si hace falta. */
	public function add(pcm:Bytes, offset:Int, channels:Int, srcRate:Int, srcFrames:Int):Void
	{
		if (rate == 0) rate = srcRate;
		var dstFrames = srcRate == rate ? srcFrames : Std.int(Math.ceil(srcFrames * (rate / srcRate)));
		if (out == null || dstFrames > frames)
		{
			var bigger = Bytes.alloc(HEADER + dstFrames * 4);
			if (out != null) bigger.blit(HEADER, out, HEADER, frames * 4);
			out = bigger;
			frames = dstFrames;
		}

		var right = channels > 1 ? 1 : 0;
		var step = srcRate / rate;
		for (f in 0...dstFrames)
		{
			var l:Int;
			var r:Int;
			if (srcRate == rate)
			{
				l = sample(pcm, offset, f, channels, 0);
				r = sample(pcm, offset, f, channels, right);
			}
			else
			{
				var pos = f * step;
				var i0 = Std.int(pos);
				if (i0 >= srcFrames) break;
				var i1 = i0 + 1 < srcFrames ? i0 + 1 : i0;
				var t = pos - i0;
				l = Std.int(sample(pcm, offset, i0, channels, 0) * (1 - t) + sample(pcm, offset, i1, channels, 0) * t);
				r = Std.int(sample(pcm, offset, i0, channels, right) * (1 - t) + sample(pcm, offset, i1, channels, right) * t);
			}
			var o = HEADER + f * 4;
			out.setUInt16(o, clamp(signed(out.getUInt16(o)) + l) & 0xFFFF);
			out.setUInt16(o + 2, clamp(signed(out.getUInt16(o + 2)) + r) & 0xFFFF);
		}
	}

	/** La mezcla ya codificada a OGG Vorbis (estereo, a la frecuencia de la primera pista). */
	public function finishOgg(quality:Float = 0.45):Bytes
		return OggVorbisEncoder.encode(out, HEADER, frames, 2, rate, quality);

	/** La mezcla como WAV de 16 bits (con cabecera). */
	public function finish():Bytes
	{
		var data = frames * 4;
		var head = new BytesOutput();
		head.writeString("RIFF");
		head.writeInt32(36 + data);
		head.writeString("WAVE");
		head.writeString("fmt ");
		head.writeInt32(16);
		head.writeUInt16(1);
		head.writeUInt16(2);
		head.writeInt32(rate);
		head.writeInt32(rate * 4);
		head.writeUInt16(4);
		head.writeUInt16(16);
		head.writeString("data");
		head.writeInt32(data);
		out.blit(0, head.getBytes(), 0, HEADER);
		return out;
	}

	static inline function sample(pcm:Bytes, offset:Int, frame:Int, channels:Int, channel:Int):Int
		return signed(pcm.getUInt16(offset + (frame * channels + channel) * 2));

	static inline function signed(v:Int):Int
		return v >= 32768 ? v - 65536 : v;

	static inline function clamp(v:Int):Int
		return v > 32767 ? 32767 : (v < -32768 ? -32768 : v);
}
