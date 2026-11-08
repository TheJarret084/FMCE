package funky.core;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

/**
 * Addons: extensiones que el juego carga siempre (noteskins, videos...), separadas de `assets/` (que va en el `assets.pack`).
 *
 *     addons/
 *       noteskins/<id>/data/noteSkin.xml      <- la configuracion
 *       noteskins/<id>/images/NOTE_assets.*   <- el atlas
 *       videos/<nombre>.mp4                   <- hxvlc necesita un archivo real, por eso no entran en el .pack
 *
 * Dos origenes para la misma ruta relativa (`noteskins/default/data/noteSkin.xml`); el externo gana, asi un addon
 * puesto a mano reemplaza al que trae el juego:
 *
 * 1. Carpeta externa en disco: `addons/` junto al ejecutable (escritorio) o `.JarretLabs-FMCE/addons/` (Android).
 * 2. Lo que trae el build: Project.xml mete `addons/` como assets de OpenFL (ids `addons/...`).
 *    En escritorio Lime los copia junto al ejecutable (== el origen 1); en Android quedan dentro del APK.
 */
class Addons
{
	/** Prefijo de los ids de OpenFL de lo que trae el build. */
	public static inline var ID_ROOT:String = "addons/";

	/** Carpeta externa de addons (sin `/` al final). */
	public static function externalRoot():String
	{
		#if sys
		return Path.join([Storage.dataDirectory(), "addons"]);
		#else
		return "addons";
		#end
	}

	/** Ruta en disco de un archivo de addon externo (exista o no). */
	public static inline function externalPath(rel:String):String
		return externalRoot() + "/" + clean(rel);

	/** true si el archivo existe afuera (disco) o en lo que trae el build. */
	public static function exists(rel:String):Bool
	{
		rel = clean(rel);
		#if sys
		if (sys.FileSystem.exists(externalRoot() + "/" + rel)) return true;
		#end
		return OpenFlAssets.exists(ID_ROOT + rel);
	}

	/** Ruta REAL en disco del archivo (para hxvlc y similares), o null si no existe. */
	public static function file(rel:String):Null<String>
	{
		rel = clean(rel);
		#if sys
		var external = externalRoot() + "/" + rel;
		if (sys.FileSystem.exists(external) && !sys.FileSystem.isDirectory(external)) return external;
		#end

		// Android: lo que trae el build vive en el APK; Lime sabe donde queda en disco.
		// OpenFlAssets.getPath lanza una excepcion si el id no existe, por eso se comprueba antes.
		try
		{
			if (OpenFlAssets.exists(ID_ROOT + rel)) return OpenFlAssets.getPath(ID_ROOT + rel);
		}
		catch (_:Dynamic) {}
		return null;
	}

	public static function getText(rel:String):Null<String>
	{
		rel = clean(rel);
		try
		{
			#if sys
			var external = externalRoot() + "/" + rel;
			if (sys.FileSystem.exists(external) && !sys.FileSystem.isDirectory(external)) return sys.io.File.getContent(external);
			#end
			if (OpenFlAssets.exists(ID_ROOT + rel)) return OpenFlAssets.getText(ID_ROOT + rel);
		}
		catch (e:Dynamic)
		{
			Log.warn('[Addons] no se pudo leer $rel: ' + Std.string(e));
		}
		return null;
	}

	public static function getBitmap(rel:String):Null<BitmapData>
	{
		rel = clean(rel);
		try
		{
			#if sys
			var external = externalRoot() + "/" + rel;
			if (sys.FileSystem.exists(external) && !sys.FileSystem.isDirectory(external)) return BitmapData.fromFile(external);
			#end
			if (OpenFlAssets.exists(ID_ROOT + rel)) return OpenFlAssets.getBitmapData(ID_ROOT + rel);
		}
		catch (e:Dynamic)
		{
			Log.warn('[Addons] no se pudo leer la imagen $rel: ' + Std.string(e));
		}
		return null;
	}

	/**
	 * Nombres de las subcarpetas directas de `addons/<sub>/` (externas + las que trae el build), sin repetidos y ordenados.
	 * `list("noteskins")` -> [codename, default, fmm, ...].
	 */
	public static function folders(sub:String):Array<String>
	{
		sub = clean(sub);
		var seen = new Map<String, Bool>();

		#if sys
		try
		{
			var dir = externalRoot() + "/" + sub;
			if (sys.FileSystem.exists(dir) && sys.FileSystem.isDirectory(dir))
				for (entry in sys.FileSystem.readDirectory(dir))
					if (sys.FileSystem.isDirectory(dir + "/" + entry)) seen.set(entry, true);
		}
		catch (_:Dynamic) {}
		#end

		try
		{
			var prefix = ID_ROOT + sub + "/";
			var ids = OpenFlAssets.list(null);
			if (ids != null)
				for (id in ids)
				{
					if (id == null || !id.startsWith(prefix)) continue;
					var rest = id.substr(prefix.length);
					var slash = rest.indexOf("/");
					if (slash > 0) seen.set(rest.substr(0, slash), true);
				}
		}
		catch (_:Dynamic) {}

		var out = [for (name in seen.keys()) name];
		out.sort(Reflect.compare);
		return out;
	}

	/**
	 * Atlas Sparrow de un addon: `<rel>.png` + `<rel>.xml` (rel sin extension, ej. `noteskins/default/images/NOTE_assets`).
	 * null si falta alguno de los dos.
	 */
	public static function getSparrowAtlas(rel:String):Null<FlxAtlasFrames>
	{
		rel = clean(rel);
		var xml = getText(rel + ".xml");
		if (xml == null) return null;

		// Mismo grafico para todos los que piden este atlas, y persistente: si ningun sprite lo usa en el state actual,
		// el cache de Flixel no lo tira ni deja el BitmapData invalido (igual que Paths.getSparrowAtlas).
		var key = "addon:" + rel;
		var graphic = FlxG.bitmap.get(key);
		if (graphic == null || graphic.bitmap == null || !graphic.bitmap.readable)
		{
			var bitmap = getBitmap(rel + ".png");
			if (bitmap == null) return null;
			graphic = FlxG.bitmap.add(bitmap, false, key);
		}
		if (graphic == null) return null;
		graphic.persist = true;

		return FlxAtlasFrames.fromSparrow(graphic, xml);
	}

	/** Sin `/` al inicio, barras normales, y sin `..` (no se sale de addons/). */
	static function clean(rel:String):String
	{
		var p = (rel == null ? "" : rel).replace("\\", "/");
		while (p.startsWith("/")) p = p.substr(1);
		return [for (part in p.split("/")) if (part != ".." && part != ".") part].join("/");
	}
}
