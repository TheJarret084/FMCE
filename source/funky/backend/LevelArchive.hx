package funky.backend;

import funky.core.Log;
import funky.core.Paths;
import haxe.io.Path;

#if sys
import haxe.crypto.Crc32;
import haxe.zip.Reader;
import haxe.zip.Tools;
import haxe.zip.Writer;
import sys.FileSystem;
import sys.io.File;
#end

/** Resultado de exportar / importar. `path` = el .FMCE creado (exportar) o la carpeta del nivel creada (importar). */
typedef ArchiveResult =
{
	var ok:Bool;
	var path:String;
	var level:String;
	var files:Int;
	var error:String;
}

/**
 * Niveles `.FMCE`: un zip normal con lo que hay DENTRO de la carpeta del nivel (`meta.json`, `chart.json`,
 * `scene.json`, `data/`, `sprites/`...), sin copias de seguridad (`.bak` / `.bck`).
 *
 * - Exportar = comprimir la carpeta del nivel en `exports/<Nivel>.FMCE`.
 * - Importar = descomprimir un `.FMCE` en `levels/<Nivel>/` (si el zip trae todo dentro de una carpeta, se le quita).
 *
 * Como es un zip, tambien se puede abrir con cualquier compresor (renombrandolo a .zip).
 */
class LevelArchive
{
	public static inline var EXT:String = ".FMCE";

	/** Extensiones que nunca entran al .FMCE (ni se sacan al importar): las copias de seguridad de los editores. */
	static final SKIP:Array<String> = [".bak", ".bck"];

	/** Ya vienen comprimidos: se guardan tal cual (mas rapido, mismo tamano). */
	static final STORED:Array<String> = [".ogg", ".mp3", ".wav", ".png", ".jpg", ".jpeg", ".mp4", ".webm", ".zip", ".fnmm", ".fmce"];

	public static function isArchive(path:String):Bool
		return path != null && StringTools.endsWith(path.toLowerCase(), ".fmce");

	/** true si el archivo es una copia de seguridad que no se exporta. */
	public static function isBackup(name:String):Bool
	{
		var lower = name.toLowerCase();
		for (ext in SKIP)
			if (StringTools.endsWith(lower, ext)) return true;
		return false;
	}

	/** `.FMCE` sueltos en `levels/` (asi se pasan niveles a un celular: se copian ahi). */
	public static function listArchives():Array<String>
	{
		var out:Array<String> = [];
		#if sys
		var root = Paths.levelsRoot();
		if (FileSystem.exists(root) && FileSystem.isDirectory(root))
		{
			for (entry in FileSystem.readDirectory(root))
				if (isArchive(entry) && !FileSystem.isDirectory(root + entry)) out.push(root + entry);
		}
		out.sort(Reflect.compare);
		#end
		return out;
	}

	// ───────────────────────── exportar ─────────────────────────

	/** Comprime `levels/<levelName>/` en `<destDir>/<Nivel>.FMCE` (por defecto `exports/`). */
	public static function exportLevel(levelName:String, ?destDir:String):ArchiveResult
	{
		#if sys
		var src = Path.removeTrailingSlashes(Paths.levelsRoot() + levelName);
		if (!FileSystem.exists(src) || !FileSystem.isDirectory(src))
			return fail('No existe el nivel ' + levelName);

		var dir = destDir != null ? destDir : Paths.exportsRoot();
		var dest = Path.join([dir, Path.withoutDirectory(levelName) + EXT]);

		var files:Array<String> = [];
		collect(src, "", files);
		if (files.length == 0) return fail('El nivel ' + levelName + ' esta vacio');

		try
		{
			ensureDir(dir);
			var out = File.write(dest, true);
			var writer = new Writer(out);

			// una entrada a la vez: no se junta todo el nivel en memoria
			for (rel in files)
			{
				var bytes = File.getBytes(src + "/" + rel);
				var entry:haxe.zip.Entry = {
					fileName: rel,
					fileSize: bytes.length,
					fileTime: FileSystem.stat(src + "/" + rel).mtime,
					compressed: false,
					dataSize: bytes.length,
					data: bytes,
					crc32: Crc32.make(bytes),
					extraFields: new List()
				};
				if (!isStored(rel)) Tools.compress(entry, 6);

				writer.writeEntryHeader(entry);
				out.writeFullBytes(entry.data, 0, entry.data.length);
			}

			writer.writeCDR();
			out.close();
		}
		catch (e:Dynamic)
		{
			return fail('No se pudo exportar: ' + Std.string(e));
		}

		Log.info('[LevelArchive] exportado ' + levelName + ' -> ' + dest + ' (' + files.length + ' archivos)');
		return {ok: true, path: dest, level: levelName, files: files.length, error: ""};
		#else
		return fail("Exportar necesita un target con archivos (sys)");
		#end
	}

	#if sys
	static function collect(abs:String, rel:String, out:Array<String>):Void
	{
		var entries = FileSystem.readDirectory(abs);
		entries.sort(Reflect.compare);
		for (entry in entries)
		{
			if (entry == "." || entry == "..") continue;
			var path = abs + "/" + entry;
			var name = rel == "" ? entry : rel + "/" + entry;
			if (FileSystem.isDirectory(path)) collect(path, name, out);
			else if (!isBackup(entry)) out.push(name);
		}
	}

	static function isStored(name:String):Bool
	{
		var lower = name.toLowerCase();
		for (ext in STORED)
			if (StringTools.endsWith(lower, ext)) return true;
		return false;
	}
	#end

	// ───────────────────────── importar ─────────────────────────

	/**
	 * Descomprime un `.FMCE` en `levels/<nombre del archivo>/`. Si ese nivel ya existe NO lo pisa (devuelve error):
	 * borra o renombra el de la carpeta y vuelve a importar.
	 */
	public static function importArchive(archivePath:String):ArchiveResult
	{
		#if sys
		if (archivePath == null || !FileSystem.exists(archivePath)) return fail('No existe ' + archivePath);

		var level = Path.withoutExtension(Path.withoutDirectory(archivePath));
		var target = Paths.levelsRoot() + level;
		if (FileSystem.exists(target)) return fail('Ya existe el nivel ' + level + ' (borralo o renombralo para importar otra vez)');

		var entries:List<haxe.zip.Entry>;
		try
		{
			var input = File.read(archivePath, true);
			entries = Reader.readZip(input);
			input.close();
		}
		catch (e:Dynamic)
		{
			return fail('No es un zip legible: ' + Std.string(e));
		}

		// nombres seguros; si todo cuelga de UNA carpeta (Nivel/chart.json) se le quita
		var items:Array<{name:String, entry:haxe.zip.Entry}> = [];
		for (entry in entries)
		{
			var name = StringTools.replace(entry.fileName, "\\", "/");
			if (StringTools.endsWith(name, "/")) continue;
			if (isUnsafe(name)) return fail('El archivo trae una ruta insegura: ' + name);
			items.push({name: name, entry: entry});
		}

		var prefix = commonFolder(items.map(i -> i.name));
		var written = 0;
		var hasLevel = false;

		try
		{
			for (item in items)
			{
				var rel = prefix == "" ? item.name : item.name.substr(prefix.length);
				if (isBackup(rel)) continue;

				var lower = rel.toLowerCase();
				if (lower == "meta.json" || lower == "chart.json") hasLevel = true;

				var dest = target + "/" + rel;
				ensureDir(Path.directory(dest));
				File.saveBytes(dest, Reader.unzip(item.entry));
				written++;
			}
		}
		catch (e:Dynamic)
		{
			removeDir(target);
			return fail('No se pudo importar: ' + Std.string(e));
		}

		if (!hasLevel)
		{
			removeDir(target);
			return fail('Ese .FMCE no parece un nivel (no trae meta.json ni chart.json)');
		}

		Log.info('[LevelArchive] importado ' + archivePath + ' -> ' + target + ' (' + written + ' archivos)');
		return {ok: true, path: target, level: level, files: written, error: ""};
		#else
		return fail("Importar necesita un target con archivos (sys)");
		#end
	}

	/** Despues de importar un .FMCE de `levels/`, se mueve a `exports/` para que no estorbe ni se vuelva a importar. */
	public static function archiveDone(archivePath:String):Void
	{
		#if sys
		try
		{
			ensureDir(Paths.exportsRoot());
			var dest = Path.join([Paths.exportsRoot(), Path.withoutDirectory(archivePath)]);
			if (FileSystem.exists(dest)) FileSystem.deleteFile(dest);
			FileSystem.rename(archivePath, dest);
		}
		catch (_:Dynamic) {}
		#end
	}

	#if sys
	/** Sin `..`, sin ruta absoluta ni unidad (`C:`). */
	static function isUnsafe(name:String):Bool
	{
		if (StringTools.startsWith(name, "/") || name.indexOf(":") >= 0) return true;
		for (part in name.split("/"))
			if (part == "..") return true;
		return false;
	}

	/** "Nivel/" si TODOS los archivos cuelgan de esa unica carpeta y no hay meta/chart en la raiz; si no, "". */
	static function commonFolder(names:Array<String>):String
	{
		if (names.length == 0) return "";

		var first = names[0].indexOf("/");
		if (first < 0) return "";

		var folder = names[0].substr(0, first + 1);
		for (name in names)
			if (!StringTools.startsWith(name, folder)) return "";

		return folder;
	}

	static function ensureDir(dir:String):Void
	{
		if (dir == null || dir == "" || FileSystem.exists(dir)) return;
		ensureDir(Path.directory(dir));
		FileSystem.createDirectory(dir);
	}

	static function removeDir(dir:String):Void
	{
		try
		{
			if (!FileSystem.exists(dir)) return;
			for (entry in FileSystem.readDirectory(dir))
			{
				var path = dir + "/" + entry;
				if (FileSystem.isDirectory(path)) removeDir(path);
				else FileSystem.deleteFile(path);
			}
			FileSystem.deleteDirectory(dir);
		}
		catch (_:Dynamic) {}
	}
	#end

	static function fail(error:String):ArchiveResult
		return {ok: false, path: "", level: "", files: 0, error: error};
}
