package funkin.backend.utils;

import flixel.sound.FlxSound;

/** Amplitud de un FlxSound por rango de tiempo (para la waveform del charter). Lee el buffer de 16 bits ya decodificado. */
class AudioAnalyzer {
	static inline var BIN_MS:Float = 5;

	var peaks:Array<Float> = [];

	@:access(flixel.sound.FlxSound)
	@:access(openfl.media.Sound)
	public function new(sound:FlxSound) {
		try {
			var buffer = sound._sound == null ? null : sound._sound.__buffer;
			if (buffer == null || buffer.data == null || buffer.bitsPerSample != 16 || buffer.channels < 1) return;

			var bytes = buffer.data.buffer;
			var frameSize = buffer.channels * 2;
			var frames = Std.int(buffer.data.length / frameSize);
			var perBin = Std.int(buffer.sampleRate * BIN_MS / 1000);
			if (perBin < 1) return;

			var bins = Std.int(frames / perBin);
			var stride = Std.int(Math.max(1, perBin / 12));
			var maxPeak = 0.0;
			for (bin in 0...bins) {
				var peak = 0;
				var frame = bin * perBin;
				var end = frame + perBin;
				while (frame < end) {
					var v = lime.utils.ArrayBufferView.ArrayBufferIO.getInt16(bytes, frame * frameSize);
					if (v < 0) v = -v;
					if (v > peak) peak = v;
					frame += stride;
				}
				var amp = peak / 32768;
				peaks.push(amp);
				if (amp > maxPeak) maxPeak = amp;
			}
			if (maxPeak > 0)
				for (i in 0...peaks.length) peaks[i] = Math.sqrt(peaks[i] / maxPeak);
		} catch (e:Dynamic) {
			peaks = [];
			funky.core.Log.warn('[AudioAnalyzer] waveform no disponible: ' + Std.string(e));
		}
	}

	/** Amplitud maxima (0 a 1) entre `startMs` y `endMs`. */
	public function analyze(startMs:Float, endMs:Float):Float {
		if (peaks.length == 0) return 0;
		var a = Std.int(Math.max(0, startMs / BIN_MS));
		var b = Std.int(Math.max(a, endMs / BIN_MS));
		var m = 0.0;
		for (i in a...b + 1) {
			if (i >= peaks.length) break;
			if (peaks[i] > m) m = peaks[i];
		}
		return m;
	}
}
