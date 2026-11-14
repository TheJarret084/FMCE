package funky.core.other;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Path;
import haxe.zip.Reader;
import lime.net.HTTPRequest;
import sys.FileSystem;
import sys.io.File;
import funky.core.Addons;

using StringTools;

/**
 * Un addon descargable.
 * - `dest` vacio  -> la URL es un .zip y se extrae dentro de addons/ (el zip trae sus propias carpetas, ej. noteskins/...)
 * - `dest` puesto -> la URL es un archivo suelto y se guarda en addons/<dest> (ej. videos/splash.mp4)
 * - `check`       -> rutas relativas a addons/ que deben existir para dar el addon por instalado
 * - `priority`    -> se descarga antes que los demas
 */
typedef AddonFile =
{
	var name:String;
	var url:String;
	var check:Array<String>;
	var priority:Bool;
	@:optional var dest:String;
}

class AddonsDownloader
{
	public static function present(item:AddonFile):Bool
	{
		for (rel in item.check)
			if (!Addons.exists(rel)) return false;
		return true;
	}

	public static function missing(list:Array<AddonFile>):Array<AddonFile>
	{
		var out = [for (item in list) if (!present(item)) item];
		out.sort(function(a, b) return a.priority == b.priority ? 0 : (a.priority ? -1 : 1));
		return out;
	}

	public var file(default, null):AddonFile;

	public var onProgress:Null<Float->Void>;
	public var onComplete:Null<Void->Void>;
	public var onError:Null<String->Void>;

	public function new(file:AddonFile)
	{
		this.file = file;
	}

	public function download():Void
	{
		try
		{
			var request = new HTTPRequest<Bytes>(file.url);
			request.load()
				.onProgress(function(loaded:Int, total:Int)
				{
					if (onProgress != null && total > 0) onProgress(loaded / total);
				})
				.onComplete(function(bytes:Bytes)
				{
					try
					{
						install(bytes);
						verify();
					}
					catch (e:Dynamic)
					{
						fail(Std.string(e));
						return;
					}
					if (onComplete != null) onComplete();
				})
				.onError(function(e:Dynamic) fail(Std.string(e)));
		}
		catch (e:Dynamic)
		{
			fail(Std.string(e));
		}
	}

	function fail(message:String):Void
	{
		if (onError != null) onError(message);
	}

	function install(bytes:Bytes):Void
	{
		var root = Addons.externalRoot();
		mkdirs(root);

		if (file.dest != null && file.dest != "")
		{
			var rel = safe(file.dest);
			if (rel == null) throw 'ruta invalida: ${file.dest}';

			var target = Path.join([root, rel]);
			mkdirs(Path.directory(target));

			// Se escribe en .part y se renombra: si se corta a la mitad no queda un archivo roto en su lugar.
			var part = target + ".part";
			File.saveBytes(part, bytes);
			if (FileSystem.exists(target)) FileSystem.deleteFile(target);
			FileSystem.rename(part, target);
			return;
		}

		// El zip se extrae primero a una carpeta temporal y recien al terminar se copia a addons/ (sin borrar nada
		// de lo que ya hay: skins propias del usuario se quedan). Si algo falla, addons/ no queda a medias.
		var tmp = Path.join([root, ".tmp-" + file.name]);
		wipe(tmp);
		mkdirs(tmp);
		try
		{
			unzip(bytes, tmp);
			copyTree(tmp, root);
		}
		catch (e:Dynamic)
		{
			wipe(tmp);
			throw e;
		}
		wipe(tmp);
	}

	function verify():Void
	{
		for (rel in file.check)
			if (!FileSystem.exists(Addons.externalPath(rel)))
				throw 'el addon ${file.name} quedo incompleto (falta $rel)';
	}

	static function unzip(bytes:Bytes, into:String):Void
	{
		for (entry in Reader.readZip(new BytesInput(bytes)))
		{
			var rel = safe(entry.fileName);
			if (rel == null || rel == "") continue;

			var out = Path.join([into, rel]);
			if (rel.endsWith("/"))
			{
				mkdirs(out);
				continue;
			}

			mkdirs(Path.directory(out));
			File.saveBytes(out, Reader.unzip(entry));
		}
	}

	static function copyTree(from:String, to:String):Void
	{
		mkdirs(to);
		for (name in FileSystem.readDirectory(from))
		{
			var src = from + "/" + name;
			var dst = to + "/" + name;
			if (FileSystem.isDirectory(src)) copyTree(src, dst);
			else File.copy(src, dst);
		}
	}

	static function wipe(path:String):Void
	{
		if (!FileSystem.exists(path)) return;
		if (FileSystem.isDirectory(path))
		{
			for (name in FileSystem.readDirectory(path)) wipe(path + "/" + name);
			FileSystem.deleteDirectory(path);
		}
		else
			FileSystem.deleteFile(path);
	}

	static function mkdirs(path:String):Void
	{
		path = Path.removeTrailingSlashes(path);
		if (path == "" || path == "." || FileSystem.exists(path)) return;

		var parent = Path.directory(path);
		if (parent != "" && parent != path) mkdirs(parent);
		if (!FileSystem.exists(path)) FileSystem.createDirectory(path);
	}

	static function safe(rel:String):Null<String>
	{
		var p = rel.replace("\\", "/");
		while (p.startsWith("/")) p = p.substr(1);
		for (part in p.split("/"))
			if (part == "..") return null;
		return p;
	}
}
