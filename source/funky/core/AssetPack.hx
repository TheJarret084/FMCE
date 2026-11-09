package funky.core;

#if sys
import haxe.io.Path;
import lime.utils.Assets as LimeAssets;
import sys.FileSystem;
import sys.io.File;
#end

/** Monta `assets.pack` (todo `assets/`, compilado por `building/pack-assets.py`) como la libreria "default" de OpenFL. */
class AssetPack
{
	public static inline var FILE:String = "assets.pack";
	public static inline var ID_FILE:String = "assets.id";

	/** true si el .pack quedo montado. */
	public static var mounted(default, null):Bool = false;

	/** Ruta del .pack en uso (null si no hay). */
	public static var path(default, null):Null<String> = null;

	public static function mount():Bool
	{
		#if (sys && !FMCE_LOOSE_ASSETS)
		try
		{
			var file = locate();
			if (file == null)
			{
				Log.error('[AssetPack] no se encontro $FILE: el juego se queda sin assets. Corre `python3 building/pack-assets.py` y recompila (o usa -DFMCE_LOOSE_ASSETS).');
				return false;
			}

			var library = new PackLibrary(file, LimeAssets.getLibrary("default"));
			LimeAssets.registerLibrary("default", library);

			path = file;
			mounted = true;
			Log.info('[AssetPack] ' + library.count + ' archivos desde $file');
			return true;
		}
		catch (e:Dynamic)
		{
			Log.error('[AssetPack] no se pudo montar el .pack: ' + Std.string(e));
			return false;
		}
		#else
		return false;
		#end
	}

	#if (sys && !FMCE_LOOSE_ASSETS)
	/** Donde esta el .pack legible con seek, o null. */
	static function locate():Null<String>
	{
		#if android
		return extractFromApk();
		#else
		var file = Path.join([Storage.exeDirectory(), FILE]);
		return FileSystem.exists(file) ? file : null;
		#end
	}
	#end

	#if (sys && android && !FMCE_LOOSE_ASSETS)
	/**
	 * Copia el .pack del APK a la carpeta privada de la app, solo si falta o si `assets.id` (un texto chiquito que
	 * tambien viaja en el APK) no coincide con el de la copia ya extraida. Cuesta leer el .pack entero una vez; despues no.
	 */
	static function extractFromApk():Null<String>
	{
		var dir = lime.system.System.applicationStorageDirectory;
		var packFile = Path.join([dir, FILE]);
		var idFile = Path.join([dir, ID_FILE]);

		var bundledId = LimeAssets.exists(ID_FILE) ? StringTools.trim(LimeAssets.getText(ID_FILE)) : null;
		var currentId = FileSystem.exists(idFile) ? StringTools.trim(File.getContent(idFile)) : null;

		if (FileSystem.exists(packFile) && bundledId != null && bundledId == currentId) return packFile;

		if (!LimeAssets.exists(FILE))
		{
			// Sin .pack en el APK: si ya hay una copia vieja se usa antes que nada.
			return FileSystem.exists(packFile) ? packFile : null;
		}

		Log.info('[AssetPack] extrayendo $FILE del APK (id ' + (bundledId == null ? "?" : bundledId.substr(0, 12)) + ')');
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);

		// Primero se borra el id: si algo corta a mitad, la proxima vez se extrae de nuevo.
		if (FileSystem.exists(idFile)) FileSystem.deleteFile(idFile);

		var bytes = LimeAssets.getBytes(FILE);
		if (bytes == null) return null;

		var tmp = packFile + ".tmp";
		File.saveBytes(tmp, bytes);
		if (FileSystem.exists(packFile)) FileSystem.deleteFile(packFile);
		FileSystem.rename(tmp, packFile);

		if (bundledId != null) File.saveContent(idFile, bundledId);
		return packFile;
	}
	#end
}
