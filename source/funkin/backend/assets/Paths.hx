package funkin.backend.assets;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;

/** Subconjunto de la API de Paths de Codename sobre la carpeta `assets/` de FMCE. */
class Paths
{
	public static inline function getPath(file:String, ?library:String):String return 'assets/$file';
	public static inline function file(file:String, ?library:String):String return getPath(file);
	public static inline function image(key:String, ?library:String, ?ext:String):String return getPath('images/$key.' + (ext == null ? 'png' : ext));
	public static inline function xml(key:String, ?library:String):String return getPath('data/$key.xml');
	public static inline function json(key:String, ?library:String):String return getPath('data/$key.json');
	public static inline function txt(key:String, ?library:String):String return getPath('data/$key.txt');
	public static inline function ini(key:String, ?library:String):String return getPath('data/$key.ini');
	public static inline function sound(key:String, ?library:String):String return getPath('sounds/$key.ogg');
	public static inline function music(key:String, ?library:String):String return getPath('music/$key.ogg');
	public static inline function font(key:String, ?library:String):String return getPath('fonts/$key');
	public static inline function getAssetsRoot():String return 'assets';
	public static inline function pack(key:String, ?library:String):String return getPath('data/$key.pack');
	public static inline function script(key:String, ?library:String):String return getPath('$key.hx');
	public static inline function getFontName(path:String):String return path;

	/** Carpeta del nivel abierto en el charter (la fija Chart.load). */
	public static var levelDir:String = null;

	/** La musica del nivel (`music.ogg` o la que diga `meta.song`). */
	public static function inst(song:String, ?diff:String, ?suffix:String):String return funkin.backend.chart.Chart.musicPath;
	/** Voces del nivel: `music/Voices<suffix>.ogg`. Si no existen devuelve una ruta inexistente (nunca null). */
	public static function voices(song:String, ?diff:String, ?suffix:String):String {
		var found = suffix == null || suffix == "" ? funkin.backend.chart.Chart.voicesPath : funky.backend.chart.LevelLoader.findVoices(levelDir, suffix);
		return found != null ? found : levelDir + '/__sin_voces__.ogg';
	}

	public static function getFrames(key:String, assetsPath:Bool = false, ?library:String, ?ext:String):FlxFramesCollection
	{
		var png = assetsPath ? key : image(key, library, ext);
		var base = png.substr(0, png.length - 4);
		var graphic = flixel.FlxG.bitmap.add(png);
		if (graphic == null) return null;
		if (openfl.utils.Assets.exists(base + '.xml')) return FlxAtlasFrames.fromSparrow(graphic, openfl.utils.Assets.getText(base + '.xml'));
		if (openfl.utils.Assets.exists(base + '.txt')) return FlxAtlasFrames.fromSpriteSheetPacker(graphic, openfl.utils.Assets.getText(base + '.txt'));
		return graphic.imageFrame;
	}

	public static inline function getSparrowAtlas(key:String, ?library:String, ?ext:String):FlxFramesCollection return getFrames(key, false, library, ext);

	public static function getFolderContent(folder:String, addPath:Bool = false, ?source:Dynamic, ?scanSource:Bool, ?library:String):Array<String>
	{
		var out:Array<String> = [];
		var prefix = getPath(folder);
		if (!StringTools.endsWith(prefix, '/')) prefix += '/';
		for (id in openfl.utils.Assets.list())
			if (StringTools.startsWith(id, prefix) && id.indexOf('/', prefix.length) < 0)
				out.push(addPath ? id : id.substr(prefix.length));
		return out;
	}
}
