package funky.core;

import haxe.Json;
import haxe.crypto.Hmac;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Mejor puntaje de un nivel en una dificultad. */
typedef BestScore =
{
	var score:Int;
	var accuracy:Float;
	var misses:Int;
}

/** Puntajes guardados por nivel y por dificultad. */
class Scores
{
	static inline var MAGIC:String = "FMSC";
	static inline var VERSION:Int = 1;
	static inline var FILE_NAME:String = "scores.fmsc";
	static inline var MAC_SIZE:Int = 32;
	/** version (1) + largo (4). */
	static inline var HEAD_TAIL:Int = 5;

	/** "<nivel>|<indice de dificultad>" -> mejor puntaje. */
	static var entries:Null<Map<String, BestScore>> = null;

	static function file():String
	{
		#if android
		return Path.join([lime.system.System.applicationStorageDirectory, FILE_NAME]);
		#else
		return Path.join([Storage.dataDirectory(), Storage.path, FILE_NAME]);
		#end
	}

	/** Id de un nivel a partir de su carpeta o archivo (`levels/N3RU/` -> `N3RU`). */
	public static function levelId(path:String):String
	{
		return Path.withoutExtension(Path.withoutDirectory(Path.removeTrailingSlashes(path)));
	}

	static inline function keyOf(level:String, difficulty:Int):String
		return level + "|" + difficulty;

	// ───────────────────────────── clave y firma ─────────────────────────────

	/** La clave no esta escrita como un string: se arma al vuelo con dos mitades. */
	static function secret():Bytes
	{
		var a = [0x4A, 0x61, 0x72, 0x72, 0x65, 0x74, 0x4C, 0x61, 0x62, 0x73, 0x2D, 0x46, 0x4D, 0x43, 0x45, 0x21];
		var b = [0x9D, 0x17, 0xE4, 0x52, 0xB1, 0x08, 0xC6, 0x3F, 0x7A, 0xD3, 0x25, 0x8E, 0x61, 0xF0, 0x4B, 0xA9];
		var out = Bytes.alloc(a.length + b.length);
		for (i in 0...a.length)
		{
			out.set(i, a[i] ^ 0x5C);
			out.set(a.length + i, b[i] ^ ((i * 31 + 7) & 0xFF));
		}
		return out;
	}

	static function mac(message:Bytes):Bytes
		return new Hmac(SHA256).make(secret(), message);

	/** Ofusca con un flujo de bytes: HMAC(clave, contador) encadenado. XOR es su propio inverso. */
	static function xorStream(data:Bytes):Bytes
	{
		var out = Bytes.alloc(data.length);
		var key = secret();
		var pos = 0;
		var counter = 0;
		while (pos < data.length)
		{
			var block = new BytesOutput();
			block.writeInt32(counter++);
			block.writeString("fmsc-stream");
			var pad = new Hmac(SHA256).make(key, block.getBytes());
			var n = Std.int(Math.min(pad.length, data.length - pos));
			for (i in 0...n) out.set(pos + i, data.get(pos + i) ^ pad.get(i));
			pos += n;
		}
		return out;
	}

	static function sameBytes(a:Bytes, b:Bytes):Bool
	{
		if (a.length != b.length) return false;
		var diff = 0;
		for (i in 0...a.length) diff |= a.get(i) ^ b.get(i);
		return diff == 0;
	}

	// ───────────────────────────── (de)serializar ─────────────────────────────

	static function encode(map:Map<String, BestScore>):Bytes
	{
		var plain = new BytesOutput();
		var keys = [for (k in map.keys()) k];
		keys.sort(Reflect.compare);
		plain.writeInt32(keys.length);
		for (key in keys)
		{
			var cut = key.lastIndexOf("|");
			var id = Bytes.ofString(key.substr(0, cut));
			var best = map.get(key);
			var difficulty:Int = cast Std.parseInt(key.substr(cut + 1));
			plain.writeUInt16(id.length);
			plain.write(id);
			plain.writeByte(difficulty);
			plain.writeInt32(best.score);
			plain.writeUInt16(Std.int(Math.max(0, Math.min(10000, Math.round(best.accuracy * 100)))));
			plain.writeInt32(best.misses);
		}
		var body = plain.getBytes();

		var tail = new BytesOutput();
		tail.writeByte(VERSION);
		tail.writeInt32(body.length);
		var versionAndLength = tail.getBytes();

		var signed = Bytes.alloc(HEAD_TAIL + body.length);
		signed.blit(0, versionAndLength, 0, HEAD_TAIL);
		signed.blit(HEAD_TAIL, body, 0, body.length);

		var out = new BytesOutput();
		out.writeString(MAGIC);
		out.write(versionAndLength);
		out.write(xorStream(body));
		out.write(mac(signed));
		return out.getBytes();
	}

	/** null si el archivo esta alterado, truncado o no es un scores.fmsc. */
	static function decode(raw:Bytes):Null<Map<String, BestScore>>
	{
		try
		{
			var headerSize = MAGIC.length + HEAD_TAIL;
			if (raw.length < headerSize + MAC_SIZE) return null;

			var input = new BytesInput(raw);
			if (input.readString(MAGIC.length) != MAGIC) return null;
			if (input.readByte() != VERSION) return null;
			var length = input.readInt32();
			if (length < 4 || length != raw.length - headerSize - MAC_SIZE) return null;

			var body = xorStream(raw.sub(headerSize, length));

			var signed = Bytes.alloc(HEAD_TAIL + length);
			signed.blit(0, raw, MAGIC.length, HEAD_TAIL);
			signed.blit(HEAD_TAIL, body, 0, length);
			if (!sameBytes(mac(signed), raw.sub(headerSize + length, MAC_SIZE))) return null;

			var plain = new BytesInput(body);
			var count = plain.readInt32();
			if (count < 0 || count > 1000000) return null;

			var map = new Map<String, BestScore>();
			for (_ in 0...count)
			{
				var id = plain.readString(plain.readUInt16());
				var difficulty = plain.readByte();
				var score = plain.readInt32();
				var accuracy = plain.readUInt16() / 100;
				var misses = plain.readInt32();
				map.set(keyOf(id, difficulty), {score: score, accuracy: accuracy, misses: misses});
			}
			return map;
		}
		catch (_:Dynamic)
		{
			return null;
		}
	}

	// ───────────────────────────── disco ─────────────────────────────

	static function load():Void
	{
		if (entries != null) return;
		entries = new Map();

		#if sys
		try
		{
			var f = file();
			if (FileSystem.exists(f))
			{
				var decoded = decode(File.getBytes(f));
				if (decoded != null) entries = decoded;
				else
				{
					// Alterado o corrupto: se aparta (por si fue un error) y se empieza de cero.
					Log.warn('[Scores] $FILE_NAME no paso la verificacion: se descarta');
					var bad = f + ".invalid";
					if (FileSystem.exists(bad)) FileSystem.deleteFile(bad);
					FileSystem.rename(f, bad);
				}
			}
			else
				importLegacyJson();
		}
		catch (e:Dynamic)
		{
			Log.warn('[Scores] no se pudo leer $FILE_NAME: ' + Std.string(e));
		}
		#end
	}

	#if sys
	/**
	 * Migracion de una sola vez desde el viejo `scores.json`: solo si NO existe ya un scores.fmsc (si no, bastaria
	 * recrear el JSON para meter puntajes falsos). Despues el JSON se borra.
	 */
	static function importLegacyJson():Void
	{
		var candidates = [Path.join([Storage.dataDirectory(), "scores.json"]), Path.join([Storage.dataDirectory(), Storage.path, "scores.json"])];
		var imported = 0;
		for (json in candidates)
		{
			if (!FileSystem.exists(json)) continue;
			try
			{
				var parsed:Dynamic = Json.parse(File.getContent(json));
				for (level in Reflect.fields(parsed))
				{
					var perDifficulty:Dynamic = Reflect.field(parsed, level);
					for (d in 0...Difficulty.KEYS.length)
					{
						var best:Dynamic = Reflect.field(perDifficulty, Difficulty.KEYS[d]);
						if (best == null) continue;
						entries.set(keyOf(level, d), {
							score: Std.int(best.score),
							accuracy: best.accuracy == null ? 0 : best.accuracy,
							misses: best.misses == null ? 0 : Std.int(best.misses)
						});
						imported++;
					}
				}
				FileSystem.deleteFile(json);
			}
			catch (e:Dynamic)
			{
				Log.warn('[Scores] no se pudo migrar $json: ' + Std.string(e));
			}
		}
		if (imported > 0)
		{
			Log.info('[Scores] migrados $imported puntajes de scores.json a $FILE_NAME');
			save();
		}
	}
	#end

	static function save():Void
	{
		#if sys
		try
		{
			var f = file();
			var dir = Path.directory(f);
			if (dir != "" && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);

			var tmp = f + ".tmp";
			File.saveBytes(tmp, encode(entries));
			if (FileSystem.exists(f)) FileSystem.deleteFile(f);
			FileSystem.rename(tmp, f);
		}
		catch (e:Dynamic)
		{
			Log.warn('[Scores] no se pudo guardar $FILE_NAME: ' + Std.string(e));
		}
		#end
	}

	// ───────────────────────────── API ─────────────────────────────

	/** Mejor puntaje del nivel en esa dificultad (indice de `Difficulty`), o null si nunca se jugo. */
	public static function get(level:String, difficulty:Int):Null<BestScore>
	{
		load();
		var best = entries.get(keyOf(level, difficulty));
		return best == null ? null : {score: best.score, accuracy: best.accuracy, misses: best.misses};
	}

	/** Guarda el resultado si supera al anterior. @return true si es un nuevo record. */
	public static function submit(level:String, difficulty:Int, score:Int, accuracy:Float, misses:Int):Bool
	{
		load();
		var previous = entries.get(keyOf(level, difficulty));
		if (previous != null && previous.score >= score) return false;

		entries.set(keyOf(level, difficulty), {
			score: score,
			accuracy: Math.round(accuracy * 100) / 100,
			misses: misses
		});
		save();
		Log.info('[Scores] nuevo record en $level (' + Difficulty.KEYS[difficulty] + '): $score');
		return true;
	}
}
