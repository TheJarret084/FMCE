import funkfmpeg.PngImage;
import funkfmpeg.Tape;
import funkfmpeg.TapeOptions;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * Reescribe los PNG del repo como PNG indexado con FunkFMPEG.
 * Mantiene dimensions y alpha. Si el resultado no es mas pequeno (o falla),
 * deja el original intacto. Solo se ejecuta desde GitHub Actions.
 */
class OptimizeSprites {
	static var total = 0;
	static var changed = 0;
	static var skipped = 0;
	static var beforeBytes = 0;
	static var afterBytes = 0;

	static function main() {
		for (root in ["assets", "addons/hudskins", "levels"])
			if (FileSystem.exists(root)) collect(root, root == "levels");
		Sys.println('OptimizeSprites: $changed/$total PNG reescritos, '
			+ '${beforeBytes - afterBytes} bytes ahorrados, $skipped sin cambios');
	}

	static function collect(path:String, levelSpritesOnly:Bool) {
		if (!FileSystem.isDirectory(path)) return;
		for (name in FileSystem.readDirectory(path)) {
			var full = Path.join([path, name]);
			if (FileSystem.isDirectory(full)) {
				collect(full, levelSpritesOnly);
			} else if (~/\.png$/i.match(name)) {
				var norm = StringTools.replace(full, "\\", "/");
				// levels/ solo sprites de nivel; el ruido de shader no es un sprite.
				if (levelSpritesOnly && norm.indexOf("/sprites/") < 0) continue;
				if (norm.indexOf("/shaders/") >= 0) continue;
				optimize(full);
			}
		}
	}

	static function optimize(path:String) {
		total++;
		var tmp = path + ".funkfmpeg.tmp";
		try {
			var original = PngImage.read(path);
			var options = new TapeOptions();
			options.maxWidth = 0;
			options.maxHeight = 0;
			options.maxPixels = 0;   // AUTO sin tope: nunca reduce el atlas
			options.maxBytes = 0;
			options.colors = 256;    // cuantizacion permitida
			options.keepAlpha = true;
			options.compression = 9;
			options.refine = 0;   // median-cut solo; las pasadas k-means son lentas en atlas gigantes

			var result = Tape.create([path], tmp, options);
			if (result.width != original.width || result.height != original.height) {
				Sys.println("  skip (dimensiones): " + path + " -> " + result.width + "x" + result.height);
				skipped++;
				FileSystem.deleteFile(tmp);
				return;
			}

			var input = File.getBytes(path);
			var output = File.getBytes(tmp);
			if (output.length < input.length) {
				File.saveBytes(path, output);
				changed++;
				beforeBytes += input.length;
				afterBytes += output.length;
				Sys.println("  ok " + path + ": " + input.length + " -> " + output.length);
			} else {
				skipped++;
			}
			FileSystem.deleteFile(tmp);
		} catch (e:Dynamic) {
			skipped++;
			if (FileSystem.exists(tmp)) FileSystem.deleteFile(tmp);
			Sys.println("  skip (error): " + path + " -> " + Std.string(e));
		}
	}
}
