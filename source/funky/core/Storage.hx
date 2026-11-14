package funky.core;

#if (sys && android)
import lime.system.JNI;
import sys.FileSystem;
import sys.io.File;
#end

class Storage
{

	public static inline var path = ".JarretLabs-FMCE";

	public static inline var ANDROID_ROOT = "/storage/emulated/0/" + path;

	#if (sys && android)
	static var warnedNoAccess:Bool = false;
	static var askedAccess:Bool = false;
	#end

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
		return exeDirectory() + "/levels";
		#end
	}

	public static function cacheDirectory():String
	{
		#if android
		return androidGameDirectory() + "/fnmm-cache";
		#else
		return exeDirectory() + "/.fnmm-cache";
		#end
	}

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
		return exeDirectory();
		#end
	}

	public static function dataDirectory():String
	{
		#if android
		return androidGameDirectory();
		#else
		return exeDirectory();
		#end
	}

	#if !android
	static var exeDir:Null<String> = null;

	public static function exeDirectory():String
	{
		if (exeDir != null) return exeDir;
		var dir = ".";
		#if sys
		try
		{
			var prog = Sys.programPath();
			if (prog != null && prog != "")
			{
				var d = haxe.io.Path.directory(prog);
				if (d != null && d != "") dir = StringTools.replace(d, "\\", "/");
			}
		}
		catch (_:Dynamic) {}
		#end
		while (dir.length > 3 && StringTools.endsWith(dir, "/")) dir = dir.substr(0, dir.length - 1);
		return exeDir = dir;
	}
	#end

	#if android

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
	public static function hasAccess():Bool
	{
		try
		{
			var check = JNI.createStaticMethod("org/fmce/StorageAccess", "hasAccess", "()Z");
			return check();
		}
		catch (e:Dynamic)
		{

			return ensureWritable(ANDROID_ROOT);
		}
	}

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
