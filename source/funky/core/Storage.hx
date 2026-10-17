package funky.core;

#if (sys && android)
import lime.system.JNI;
import sys.FileSystem;
import sys.io.File;
#end

/** Carpetas de datos que se pueden escribir en runtime. */
class Storage
{
	/** Nombre de la carpeta publica (sin ruta). */
	public static inline var path = ".JarretLabs-FMCE";

	/** `/storage/emulated/0/.JarretLabs-FMCE` */
	public static inline var ANDROID_ROOT = "/storage/emulated/0/" + path;

	#if (sys && android)
	static var warnedNoAccess:Bool = false;
	static var askedAccess:Bool = false;
	#end

	/** Llamar una vez al arrancar (SplashState): pide el permiso si falta y crea la carpeta. En escritorio no hace nada. */
	public static function init():Void
	{
		#if (sys && android)
		if (!hasAccess() && !askedAccess)
		{
			askedAccess = true;
			Log.warn('[Storage] sin permiso para $ANDROID_ROOT: se pide "Acceso a todos los archivos"');
			try
			{
				var request = JNI.createStaticMethod("org/fmce/StorageAccess", "requestAccess", "()V");
				request();
			}
			catch (e:Dynamic)
			{
				Log.error('[Storage] no se pudo abrir la pantalla de permisos: $e');
			}
		}
		Log.info('[Storage] datos en ' + dataDirectory());
		#end
	}

	public static function levelsDirectory():String
	{
		#if android
		return androidGameDirectory() + "/levels";
		#else
		return "levels";
		#end
	}

	public static function cacheDirectory():String
	{
		#if android
		return androidGameDirectory() + "/fnmm-cache";
		#else
		return ".fnmm-cache";
		#end
	}

	/**
	 * Base de logs y crashes. En Android es la carpeta del juego (`.JarretLabs-FMCE`, o `Android/media/<package>`
	 * si aun no hay permiso), no la carpeta privada de la app: asi se pueden leer sin root. En escritorio, junto al ejecutable.
	 */
	public static function logDirectory():String
	{
		#if android
		#if sys
		try
		{
			return androidGameDirectory();
		}
		catch (_:Dynamic) {}
		#end
		return lime.system.System.applicationStorageDirectory;
		#else
		return ".";
		#end
	}

	/** Root for user data (levels/backups/exports). Android never writes beside its APK. */
	public static function dataDirectory():String
	{
		#if android
		return androidGameDirectory();
		#else
		return ".";
		#end
	}

	#if android
	/** Carpeta publica si se puede escribir ahi; si no, la de `Android/media/<package>`. Sin `/` al final. */
	static function androidGameDirectory():String
	{
		#if sys
		if (hasAccess() && ensureWritable(ANDROID_ROOT)) return ANDROID_ROOT;

		if (!warnedNoAccess)
		{
			warnedNoAccess = true;
			Log.warn('[Storage] $ANDROID_ROOT no es escribible todavia; se usa ' + mediaDirectory());
		}
		var fallback = mediaDirectory();
		ensureWritable(fallback);
		return fallback;
		#else
		return ANDROID_ROOT;
		#end
	}

	static function mediaDirectory():String
	{
		var pkg = lime.app.Application.current != null ? lime.app.Application.current.meta.get("packageName") : null;
		return "/storage/emulated/0/Android/media/" + (pkg != null ? pkg : "com.jarretlabs.fmce");
	}

	#if sys
	static function hasAccess():Bool
	{
		try
		{
			var check = JNI.createStaticMethod("org/fmce/StorageAccess", "hasAccess", "()Z");
			return check();
		}
		catch (e:Dynamic)
		{
			// Sin el helper Java (build viejo): se prueba escribiendo de verdad.
			return ensureWritable(ANDROID_ROOT);
		}
	}

	/** Crea la carpeta (con padres) y prueba a escribir un archivo. */
	static function ensureWritable(dir:String):Bool
	{
		try
		{
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			var probe = dir + "/.write-test";
			File.saveContent(probe, "ok");
			FileSystem.deleteFile(probe);
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}
	#end
	#end
}
