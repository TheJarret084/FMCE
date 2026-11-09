package funkin.backend.chart;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Path;
import haxe.zip.Reader;

typedef FnfcAudio =
{
	/** Nombre del archivo dentro del .fnfc (Inst.ogg, Voices-darnell.ogg...). */
	var name:String;
	var bytes:Bytes;
	/** Como se llama en `music/` del nivel de FMCE. */
	var target:String;
}

/** Un `.fnfc` de Friday Night Funkin' (un zip): `<cancion>-chart.json`, `<cancion>-metadata.json`, `Inst.ogg` y las `Voices*.ogg`. */
class FnfcPackage
{
	public var chart(default, null):String = null;
	public var songId(default, null):String = "";
	public var songName(default, null):Null<String> = null;
	public var bpm(default, null):Null<Float> = null;
	public var audio(default, null):Array<FnfcAudio> = [];
	/** Audios del paquete que no se copian (alternativos, etc.). */
	public var skipped(default, null):Array<String> = [];

	public function new() {}

	public static function isFnfc(path:Null<String>):Bool
		return path != null && Path.extension(path).toLowerCase() == "fnfc";

	/** Lanza un String con el motivo si no es un .fnfc valido. */
	public static function read(bytes:Bytes):FnfcPackage
	{
		var entries = try Reader.readZip(new BytesInput(bytes)) catch (e:Dynamic) throw "No es un .fnfc valido (no se pudo abrir el zip).";
		var pack = new FnfcPackage();
		var metadata:Null<String> = null;

		for (entry in entries)
		{
			var name = Path.withoutDirectory(entry.fileName);
			if (name == "" || entry.fileName.charAt(entry.fileName.length - 1) == "/") continue;
			var lower = name.toLowerCase();
			var ext = Path.extension(lower);

			if (StringTools.endsWith(lower, "-chart.json") || lower == "chart.json")
			{
				pack.chart = Reader.unzip(entry).toString();
			}
			else if (StringTools.endsWith(lower, "-metadata.json") || lower == "metadata.json")
			{
				metadata = Reader.unzip(entry).toString();
			}
			else if (lower == "manifest.json")
			{
				try
					pack.songId = Std.string(Reflect.field(Json.parse(Reader.unzip(entry).toString()), "songId"))
				catch (e:Dynamic) {}
			}
			else if (ext == "ogg" || ext == "mp3" || ext == "wav" || ext == "m4a")
			{
				var base = Path.withoutExtension(lower);
				// Inst.ogg es la musica del nivel (music.ogg); las Voices* conservan su nombre (el sufijo lo usa cada strumline).
				if (base == "inst") pack.audio.push({name: name, bytes: Reader.unzip(entry), target: "music." + ext});
				else if (StringTools.startsWith(base, "voices")) pack.audio.push({name: name, bytes: Reader.unzip(entry), target: name});
				else pack.skipped.push(name);
			}
		}

		if (pack.chart == null) throw "El .fnfc no trae un archivo -chart.json.";
		if (metadata != null) pack.readMetadata(metadata);
		pack.audio.sort(function(a, b) return a.target < b.target ? -1 : (a.target > b.target ? 1 : 0));
		return pack;
	}

	function readMetadata(text:String):Void
	{
		try
		{
			var meta:Dynamic = Json.parse(text);
			var name:Dynamic = Reflect.field(meta, "songName");
			if (name != null) songName = Std.string(name);
			var changes:Dynamic = Reflect.field(meta, "timeChanges");
			if (Std.isOfType(changes, Array) && (changes : Array<Dynamic>).length > 0)
			{
				var bpmValue = Std.parseFloat(Std.string(Reflect.field((changes : Array<Dynamic>)[0], "bpm")));
				if (!Math.isNaN(bpmValue) && bpmValue > 0) bpm = bpmValue;
			}
		}
		catch (e:Dynamic) {}
	}
}
