package funky.scripting;

import animate.FlxAnimateFrames;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funky.backend.FunkinSprite;
import funky.core.ClientPrefs;
import funky.core.Conductor;
import funky.core.Log;
import funky.core.Paths;
import funky.core.Storage;
import funky.game.LevelSprite;
import funky.game.SpriteBuilder;
import haxe.Json;
import haxe.io.Path;

#if sys
import sys.FileSystem;
#end

/** Scripts de un nivel: todo `.hx` de `<nivel>/scripts/` (en orden alfabetico). hscript-improved: clases, import, using. */
class Scripts
{
	public static inline var CONTINUE:Int = 0;
	public static inline var STOP:Int = 1;

	/** true si hay al menos un script cargado (para no armar argumentos en vano). */
	public static var has(default, null):Bool = false;

	/** Variables compartidas entre scripts: `setVar` / `getVar`. */
	public static var shared(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	/** Variables `static` de las clases de los scripts (compartidas entre todos). */
	public static var statics(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	static var list:Array<LevelScript> = [];

	/** Carga los scripts de `levelDir`. `extra` son variables globales para ellos (`game`, `song`...). */
	public static function load(levelDir:String, extra:Map<String, Dynamic>):Void
	{
		clear();

		#if sys
		var dir = Path.join([levelDir, "scripts"]);
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) return;

		var files = [for (entry in FileSystem.readDirectory(dir)) if (StringTools.endsWith(entry.toLowerCase(), ".hx")) entry];
		files.sort(Reflect.compare);
		if (files.length == 0) return;

		var globals = baseGlobals();
		for (key => value in extra) globals.set(key, value);

		for (file in files)
		{
			try
			{
				list.push(new LevelScript(file, Path.join([dir, file]), levelDir, globals));
			}
			catch (e:Dynamic)
			{
				Log.error('[Scripts] ' + file + ': ' + Std.string(e));
			}
		}

		has = list.length > 0;
		Log.info('[Scripts] ' + list.length + ' scripts de ' + dir);
		#end
	}

	/** Define una variable global en todos los scripts (por ejemplo `hud` cuando ya existe). */
	public static function set(key:String, value:Dynamic):Void
		for (script in list) script.set(key, value);

	/** Llama `func` en todos los scripts. true = alguno devolvio `Function_Stop`. */
	public static function call(func:String, ?args:Array<Dynamic>):Bool
	{
		if (!has) return false;
		if (args == null) args = [];

		var stopped = false;
		for (script in list)
			if (script.call(func, args) == STOP)
				stopped = true;
		return stopped;
	}

	public static function clear():Void
	{
		list = [];
		has = false;
		shared = new Map<String, Dynamic>();
		statics = new Map<String, Dynamic>();
	}

	static function baseGlobals():Map<String, Dynamic>
	{
		var globals = new Map<String, Dynamic>();

		globals.set("Function_Continue", CONTINUE);
		globals.set("Function_Stop", STOP);

		globals.set("FlxG", FlxG);
		globals.set("FlxSprite", FlxSprite);
		globals.set("FlxText", FlxText);
		globals.set("FlxGroup", FlxGroup);
		globals.set("FlxSpriteGroup", FlxSpriteGroup);
		globals.set("FlxCamera", FlxCamera);
		globals.set("FlxAnimateFrames", FlxAnimateFrames);
		globals.set("FunkinSprite", FunkinSprite);
		globals.set("LevelSprite", LevelSprite);
		globals.set("SpriteBuilder", SpriteBuilder);
		globals.set("Storage", Storage);
		globals.set("FlxTween", FlxTween);
		globals.set("FlxEase", FlxEase);
		globals.set("FlxTimer", FlxTimer);
		globals.set("FlxColor", colors());
		globals.set("Math", Math);
		globals.set("Std", Std);
		globals.set("StringTools", StringTools);
		globals.set("Reflect", Reflect);
		globals.set("Json", Json);
		globals.set("Paths", Paths);
		globals.set("Conductor", Conductor);
		globals.set("ClientPrefs", ClientPrefs);
		globals.set("Log", Log);

		globals.set("setVar", function(name:String, value:Dynamic):Void shared.set(name, value));
		globals.set("getVar", function(name:String):Dynamic return shared.get(name));

		return globals;
	}

	/** `FlxColor` es un abstract y no se puede pasar como valor: se ofrece lo basico. */
	static function colors():Dynamic
	{
		return {
			TRANSPARENT: FlxColor.TRANSPARENT,
			WHITE: FlxColor.WHITE,
			BLACK: FlxColor.BLACK,
			GRAY: FlxColor.GRAY,
			RED: FlxColor.RED,
			GREEN: FlxColor.GREEN,
			BLUE: FlxColor.BLUE,
			YELLOW: FlxColor.YELLOW,
			ORANGE: FlxColor.ORANGE,
			CYAN: FlxColor.CYAN,
			MAGENTA: FlxColor.MAGENTA,
			PINK: FlxColor.PINK,
			PURPLE: FlxColor.PURPLE,
			fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255):Int return FlxColor.fromRGB(r, g, b, a),
			fromString: function(value:String):Int return FlxColor.fromString(value)
		};
	}
}
