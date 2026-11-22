package funky.backend;

import haxe.io.Path;
import funky.core.Log;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Huevos de pascua de los niveles nuevos: de vez en cuando (CHANCE) se copia una imagen random de `assets/included/`
 * dentro de la carpeta del nivel, en `eastereggs/`. No cambia nada del chart ni del escenario; es solo un detalle.
 *
 * Las imagenes se buscan en la carpeta suelta y tambien en `assets.pack` (Assets.list), con una lista fija de respaldo
 * por si el listado no esta disponible en el target.
 */
class LevelEasterEggs
{
	/** Probabilidad por nivel nuevo (5%). */
	public static inline var CHANCE:Float = 0.05;

	/** Subcarpeta del nivel donde cae la imagen. */
	public static inline var FOLDER:String = "";

	/** Igual que LevelCreator.TEMPLATE_DIR. */
	public static inline var TEMPLATE_DIR:String = "assets/included/";

	static final KNOWN:Array<String> = [
		"IMG_20261027_204511.jpg",
		"eel_euq_le_otnot.png",
		"pendejo cree que le robe su mrd xdddddd Screenshot_20260811-195149.png"
	];

	static final EXTENSIONS:Array<String> = [".png", ".jpg", ".jpeg", ".gif", ".webp"];

	/** Copia una imagen al azar si toca. Devuelve la ruta copiada o null. */
	public static function maybeCopy(levelDir:String):Null<String>
	{
		if (Math.random() >= CHANCE) return null;
		return copyRandom(levelDir);
	}

	/** Copia una imagen al azar (sin mirar la probabilidad). Devuelve la ruta copiada o null. */
	public static function copyRandom(levelDir:String):Null<String>
	{
		#if sys
		var list = candidates();
		if (list.length == 0) return null;

		var pick = list[Std.int(Math.random() * list.length)];
		var bytes = assetBytes(TEMPLATE_DIR + pick);
		if (bytes == null)
		{
			Log.warn('[LevelEasterEggs] no se pudo leer ' + TEMPLATE_DIR + pick);
			return null;
		}

		var dir = Path.join([levelDir, FOLDER]);
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);

		var target = uniquePath(dir, pick);
		File.saveBytes(target, bytes);
		Log.info('[LevelEasterEggs] easter egg: ' + target);
		return target;
		#else
		return null;
		#end
	}

	#if sys
	static function assetBytes(path:String):Null<haxe.io.Bytes>
	{
		try
		{
			if (openfl.utils.Assets.exists(path)) return openfl.utils.Assets.getBytes(path);
			if (FileSystem.exists(path)) return File.getBytes(path);
		}
		catch (e:Dynamic) {}
		return null;
	}

	static function uniquePath(dir:String, fileName:String):String
	{
		var candidate = Path.join([dir, fileName]);
		if (!FileSystem.exists(candidate)) return candidate;

		var base = Path.withoutExtension(fileName);
		var ext = Path.extension(fileName);
		var i = 1;
		while (true)
		{
			candidate = Path.join([dir, base + "-" + i + (ext == null || ext == "" ? "" : "." + ext)]);
			if (!FileSystem.exists(candidate)) return candidate;
			i++;
		}
		return candidate;
	}

	/** Nombres de imagen que hay en assets/included (carpeta suelta, assets.pack y la lista fija). */
	static function candidates():Array<String>
	{
		var out:Array<String> = [];
		var seen = new Map<String, Bool>();

		function add(name:String):Void
		{
			if (name == null) return;
			name = Path.withoutDirectory(StringTools.replace(name, "\\", "/"));
			if (name == "") return;

			var lower = name.toLowerCase();
			var isImage = false;
			for (ext in EXTENSIONS)
				if (StringTools.endsWith(lower, ext))
				{
					isImage = true;
					break;
				}
			if (!isImage || seen.exists(name)) return;

			seen.set(name, true);
			out.push(name);
		}

		try
		{
			if (FileSystem.exists(TEMPLATE_DIR) && FileSystem.isDirectory(TEMPLATE_DIR))
				for (file in FileSystem.readDirectory(TEMPLATE_DIR)) add(file);
		}
		catch (e:Dynamic) {}

		try
		{
			for (path in openfl.utils.Assets.list())
			{
				var normalized = StringTools.replace(path, "\\", "/");
				if (!StringTools.startsWith(normalized, TEMPLATE_DIR)) continue;
				add(normalized.substr(TEMPLATE_DIR.length));
			}
		}
		catch (e:Dynamic) {}

		// El respaldo fijo solo agrega nombres que realmente existen. Asi el 5% no se pierde
		// al elegir por azar una referencia vieja que no este incluida en esta build.
		for (file in KNOWN)
		{
			var exists = false;
			try exists = openfl.utils.Assets.exists(TEMPLATE_DIR + file) catch (e:Dynamic) {}
			if (!exists && FileSystem.exists(TEMPLATE_DIR + file)) exists = true;
			if (exists) add(file);
		}

		out.sort(Reflect.compare);
		return out;
	}
	#end
}
