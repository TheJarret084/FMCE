package funky.backend.chart;

import funky.game.SpriteBuilder;
import haxe.Json;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Lo que el charter necesita saber de `scene.json` y de `sprites/` para ofrecer listas en vez de numeros:
 * objetos, sus posiciones (`transform`), las camaras, los sprites y las animaciones de un sprite.
 * Las listas salen siempre del disco, asi que reflejan lo ultimo que se guardo en el editor de escena.
 */
class SceneInfo
{
	static function readJson(path:String):Dynamic
	{
		#if sys
		try
		{
			if (!FileSystem.exists(path)) return null;
			var text = File.getContent(path);
			if (text.length > 0 && text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
			return Json.parse(text);
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	static function num(v:Dynamic, fallback:Float = 0):Float
	{
		if (v == null) return fallback;
		var f = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? fallback : f;
	}

	static function fmt(v:Float):String
		return Std.string(Math.round(v * 100) / 100);

	static function objectList(levelDir:String):Array<Dynamic>
	{
		var scene = readJson(Path.join([levelDir, "scene.json"]));
		var list:Dynamic = scene == null ? null : Reflect.field(scene, "objects");
		return Std.isOfType(list, Array) ? list : [];
	}

	/** "#0  bg", "#1  player (strumline 0)"... un texto por objeto de `scene.json > objects`. */
	public static function objectLabels(levelDir:String):Array<String>
	{
		var out:Array<String> = [];
		for (i => o in objectList(levelDir))
		{
			var spr = Std.string(Reflect.field(o, "spr"));
			var strum = Std.int(num(Reflect.field(o, "strumLine"), -1));
			out.push("#" + i + "  " + spr + (strum >= 0 ? " (strumline " + strum + ")" : ""));
		}
		return out;
	}

	/** Posiciones (`transform`) del objeto: "#0 (x: 1080, y: 960)". */
	public static function positionLabels(levelDir:String, object:Int):Array<String>
	{
		var list = objectList(levelDir);
		if (object < 0 || object >= list.length) return [];
		var transform:Dynamic = Reflect.field(list[object], "transform");
		var out:Array<String> = [];
		if (Std.isOfType(transform, Array))
			for (i => t in (transform : Array<Dynamic>))
			{
				var p = Reflect.field(t, "position");
				out.push("#" + i + "  (x: " + fmt(num(Reflect.field(p, "x"))) + ", y: " + fmt(num(Reflect.field(p, "y"))) + ")");
			}
		return out;
	}

	/** Puntos de camara de `scene.json > cameras`. */
	public static function cameraLabels(levelDir:String):Array<String>
	{
		var scene = readJson(Path.join([levelDir, "scene.json"]));
		var list:Dynamic = scene == null ? null : Reflect.field(scene, "cameras");
		var out:Array<String> = [];
		if (Std.isOfType(list, Array))
			for (i => c in (list : Array<Dynamic>))
			{
				var p = Reflect.field(c, "position");
				out.push("#" + i + "  (x: " + fmt(num(Reflect.field(p, "x"))) + ", y: " + fmt(num(Reflect.field(p, "y"))) + ", zoom " + fmt(num(Reflect.field(c, "scale"), 1)) + ")");
			}
		return out;
	}

	/** Carpetas de `sprites/` del nivel (los iconos primero, como en el resto de los editores). */
	public static function spriteNames(levelDir:String):Array<String>
		return SpriteBuilder.listSprites(levelDir);

	/** Sprite que tiene ahora el objeto en `scene.json` ("" si no existe). */
	public static function spriteOf(levelDir:String, object:Int):String
	{
		var list = objectList(levelDir);
		return object >= 0 && object < list.length ? Std.string(Reflect.field(list[object], "spr")) : "";
	}

	/**
	 * Animaciones de un sprite, en el orden que usa `ObjectAnimationSet` (0 = idle): las entradas de su `config.json`,
	 * o los tags de `sprite.json`. En un video, un numero por video.
	 */
	public static function animationLabels(levelDir:String, sprite:String):Array<String>
	{
		var out:Array<String> = [];
		if (sprite == "") return out;
		try
		{
			var videos = SpriteBuilder.videoCount(levelDir, sprite);
			if (videos > 0)
			{
				for (i in 0...videos) out.push("#" + i + "  video " + i);
				return out;
			}
		}
		catch (e:Dynamic) {}

		var dir = SpriteBuilder.spriteDir(levelDir, sprite);
		var names:Array<String> = [];
		var config = readJson(Path.join([dir, "config.json"]));
		var data:Dynamic = config == null ? null : Reflect.field(config, "data");
		if (Std.isOfType(data, Array) && (data : Array<Dynamic>).length > 0)
		{
			for (i => entry in (data : Array<Dynamic>))
			{
				var n = Reflect.field(entry, "anim") != null ? Reflect.field(entry, "anim") : Reflect.field(entry, "name");
				names.push(n == null ? "anim" + i : Std.string(n));
			}
		}
		else
		{
			var sheet = readJson(Path.join([dir, "sprite.json"]));
			var tags:Dynamic = sheet == null ? null : Reflect.field(Reflect.field(sheet, "meta"), "frameTags");
			if (Std.isOfType(tags, Array))
				for (t in (tags : Array<Dynamic>))
				{
					var n = Std.string(Reflect.field(t, "name"));
					if (names.indexOf(n) < 0) names.push(n);
				}
		}
		for (i => n in names) out.push("#" + i + "  " + n);
		return out;
	}
}
