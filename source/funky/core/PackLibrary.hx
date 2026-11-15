package funky.core;

#if sys
import haxe.io.Bytes;
import haxe.io.Path;
import lime.app.Future;
import lime.graphics.Image;
import lime.media.AudioBuffer;
import lime.text.Font;
import lime.utils.AssetLibrary;
import lime.utils.AssetType;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileInput;
import sys.io.FileSeek;

class PackLibrary extends AssetLibrary
{
	static inline var MAGIC:String = "FMPK";
	static inline var VERSION:Int = 1;

	public var packPath(default, null):String;

	public var count(default, null):Int = 0;

	/** Tamano real del .pack en disco (para saber si quedo cortado). */
	public var packSize(default, null):Float = 0;

	/** Donde empiezan los datos (justo despues de la cabecera y el indice): ninguna entrada puede caer antes. */
	public var dataStart(default, null):Int = 0;

	var file:Null<FileInput>;
	var offsets:Map<String, Int> = new Map();
	var lengths:Map<String, Int> = new Map();
	var fallback:Null<AssetLibrary>;

	#if target.threaded
	var mutex:sys.thread.Mutex = new sys.thread.Mutex();
	#end

	public function new(path:String, ?fallback:AssetLibrary)
	{
		super();
		this.packPath = path;
		this.fallback = fallback;
		readIndex();
	}

	function open():FileInput
	{
		if (file == null) file = File.read(packPath, true);
		return file;
	}

	function readIndex():Void
	{
		var input = open();
		var magic = input.readString(4);
		if (magic != MAGIC) throw 'no es un .pack de FMCE: $packPath';

		var version = input.readInt32();
		if (version != VERSION) throw 'version de .pack no soportada ($version, se esperaba $VERSION): $packPath';

		count = input.readInt32();
		var indexSize = input.readInt32();
		dataStart = 16 + indexSize;
		packSize = FileSystem.stat(packPath).size;
		var index = Bytes.alloc(indexSize);
		input.readFullBytes(index, 0, indexSize);

		var pos = 0;
		for (_ in 0...count)
		{
			var length = index.getUInt16(pos);
			pos += 2;
			var id = index.getString(pos, length);
			pos += length;
			offsets.set(id, index.getInt32(pos));
			lengths.set(id, index.getInt32(pos + 4));
			pos += 8;
			types.set(id, typeOf(id));
		}

		if (pos != indexSize) throw 'indice del .pack corrupto: $packPath';
	}

	static function typeOf(id:String):AssetType
	{
		return switch (Path.extension(id).toLowerCase())
		{
			case "png" | "jpg" | "jpeg" | "gif" | "bmp" | "webp": IMAGE;
			case "ogg" | "wav" | "mp3" | "flac": SOUND;
			case "ttf" | "otf": FONT;
			case "xml" | "json" | "txt" | "frag" | "vert" | "glsl" | "hx" | "hxc" | "ini" | "csv" | "md": TEXT;
			default: BINARY;
		}
	}

	function readEntry(id:String):Null<Bytes>
	{
		var offset = offsets.get(id);
		var length = lengths.get(id);
		if (offset == null || length == null) return null;

		var bytes:Null<Bytes> = null;

		#if target.threaded
		mutex.acquire();
		#end
		try
		{
			var input = open();
			input.seek(offset, SeekBegin);
			bytes = Bytes.alloc(length);
			input.readFullBytes(bytes, 0, length);
		}
		catch (e:Dynamic)
		{
			bytes = null;
			Log.error('[PackLibrary] no se pudo leer $id: ' + Std.string(e));
		}
		#if target.threaded
		mutex.release();
		#end

		return bytes;
	}

	inline function inPack(id:String):Bool
		return offsets.exists(id);

	/** Todos los ids que trae el .pack. */
	public function ids():Array<String>
		return [for (id in offsets.keys()) id];

	/**
	 * Revision rapida de una entrada, sin descomprimir nada: que su rango caiga dentro del archivo y, en imagenes y audio,
	 * que los primeros bytes sean la firma del formato. Devuelve null si esta bien, o el motivo si no.
	 */
	public function entryProblem(id:String):Null<String>
	{
		var offset = offsets.get(id);
		var length = lengths.get(id);
		if (offset == null || length == null) return "no esta en el indice";
		if (length < 0 || offset < dataStart) return 'rango invalido (offset $offset, $length bytes)';
		if (((offset : Float) + (length : Float)) > packSize) return "se sale del archivo (el .pack esta cortado)";

		var sig = signatureOf(id);
		if (sig == null) return null;
		if (length < sig.length) return 'vacio o truncado ($length bytes)';

		var head = readHead(offset, sig.length);
		if (head == null) return "no se pudo leer";
		for (i in 0...sig.length)
			if (head.get(i) != sig[i]) return "la firma del archivo no coincide con su extension";
		return null;
	}

	static function signatureOf(id:String):Null<Array<Int>>
	{
		return switch (Path.extension(id).toLowerCase())
		{
			case "png": [0x89, 0x50, 0x4E, 0x47];
			case "ogg": [0x4F, 0x67, 0x67, 0x53];
			case "jpg" | "jpeg": [0xFF, 0xD8];
			default: null;
		}
	}

	function readHead(offset:Int, size:Int):Null<Bytes>
	{
		var bytes:Null<Bytes> = null;

		#if target.threaded
		mutex.acquire();
		#end
		try
		{
			var input = open();
			input.seek(offset, SeekBegin);
			bytes = Bytes.alloc(size);
			input.readFullBytes(bytes, 0, size);
		}
		catch (e:Dynamic)
		{
			bytes = null;
		}
		#if target.threaded
		mutex.release();
		#end

		return bytes;
	}

	override public function exists(id:String, type:String):Bool
	{
		if (inPack(id)) return super.exists(id, type);
		return fallback != null && fallback.exists(id, type);
	}

	override public function isLocal(id:String, type:String):Bool
	{
		if (inPack(id)) return true;
		return fallback != null && fallback.isLocal(id, type);
	}

	override public function list(type:String):Array<String>
	{
		var items = super.list(type);
		if (fallback != null)
			for (id in fallback.list(type))
				if (!inPack(id)) items.push(id);
		return items;
	}

	override public function getPath(id:String):String
	{

		if (inPack(id)) return null;
		return fallback != null ? fallback.getPath(id) : null;
	}

	override public function getBytes(id:String):lime.utils.Bytes
	{
		if (inPack(id)) return readEntry(id);
		return fallback != null ? fallback.getBytes(id) : null;
	}

	override public function getText(id:String):String
	{
		if (inPack(id))
		{
			var bytes = readEntry(id);
			return bytes == null ? null : bytes.getString(0, bytes.length);
		}
		return fallback != null ? fallback.getText(id) : null;
	}

	override public function getImage(id:String):Image
	{
		if (inPack(id))
		{
			var bytes = readEntry(id);
			return bytes == null ? null : Image.fromBytes(bytes);
		}
		return fallback != null ? fallback.getImage(id) : null;
	}

	override public function getAudioBuffer(id:String):AudioBuffer
	{
		if (inPack(id))
		{
			var bytes = readEntry(id);
			return bytes == null ? null : AudioBuffer.fromBytes(bytes);
		}
		return fallback != null ? fallback.getAudioBuffer(id) : null;
	}

	override public function getFont(id:String):Font
	{
		if (inPack(id))
		{
			var bytes = readEntry(id);
			return bytes == null ? null : Font.fromBytes(bytes);
		}
		return fallback != null ? fallback.getFont(id) : null;
	}

	override public function loadBytes(id:String):Future<lime.utils.Bytes>
		return inPack(id) ? ready(function() return getBytes(id)) : (fallback != null ? fallback.loadBytes(id) : super.loadBytes(id));

	override public function loadText(id:String):Future<String>
		return inPack(id) ? ready(function() return getText(id)) : (fallback != null ? fallback.loadText(id) : super.loadText(id));

	override public function loadImage(id:String):Future<Image>
		return inPack(id) ? ready(function() return getImage(id)) : (fallback != null ? fallback.loadImage(id) : super.loadImage(id));

	override public function loadAudioBuffer(id:String):Future<AudioBuffer>
		return inPack(id) ? ready(function() return getAudioBuffer(id)) : (fallback != null ? fallback.loadAudioBuffer(id) : super.loadAudioBuffer(id));

	override public function loadFont(id:String):Future<Font>
		return inPack(id) ? ready(function() return getFont(id)) : (fallback != null ? fallback.loadFont(id) : super.loadFont(id));

	static function ready<T>(make:Void->T):Future<T>
	{
		try
		{
			return Future.withValue(make());
		}
		catch (e:Dynamic)
		{
			return cast Future.withError(e);
		}
	}

	override public function unload():Void
	{
		super.unload();

		if (file != null)
		{
			try file.close() catch (_:Dynamic) {}
			file = null;
		}
	}
}
#end
