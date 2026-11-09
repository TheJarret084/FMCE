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
import funky.backend.system.framerate.Framerate;
import funky.core.ClientPrefs;
import funky.core.Conductor;
import funky.core.Log;
import funky.core.Paths;
import funky.core.Storage;
import funky.game.LevelSprite;
import funky.game.SpriteBuilder;
import funky.game.Stage;
import haxe.Json;
import haxe.io.Path;

#if sys
import sys.FileSystem;
#end

/** Scripts de un nivel: todo `.hx` de `<nivel>/data/scripts/` (en orden alfabetico). */
class Scripts
{
	/** Carpeta de los scripts dentro del nivel. */
	public static inline var DIR:String = "data/scripts";

	/** Carpeta de antes (`<nivel>/scripts/`): se sigue leyendo para no romper niveles viejos, pero lo nuevo va en `DIR`. */
	public static inline var LEGACY_DIR:String = "scripts";

	public static inline var CONTINUE:Int = 0;
	public static inline var STOP:Int = 1;

	static var EXTENSIONS:Array<String> = ["hx", "hscript", "hsc", "hxs"];

	/** true si hay al menos un script cargado (para no armar argumentos en vano). */
	public static var has(default, null):Bool = false;

	/** Variables publicas compartidas entre scripts (`public var`, `public function`, `setVar` / `getVar`). */
	public static var shared(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	/** Variables `static` de las clases de los scripts (compartidas entre todos). */
	public static var statics(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	/** Todos los scripts cargados, en orden de carga. */
	public static var scripts(default, null):Array<LevelScript> = [];

	/** Objeto padre de los scripts (el PlayState). */
	public static var parent(default, null):Dynamic = null;

	/** Variables globales de todos los scripts: las base + las de `load` + las que se agregan con `set`. */
	static var globals:Map<String, Dynamic> = new Map<String, Dynamic>();

	static var levelDir:String = "";

	/**
	 * Carga los scripts de `levelDir`. `extra` son variables globales para ellos (`game`, `song`...).
	 * Si `extra` trae `game`, ese objeto es el padre de los scripts.
	 */
	public static function load(levelDir:String, extra:Map<String, Dynamic>):Void
	{
		clear();
		Scripts.levelDir = levelDir;

		globals = baseGlobals();
		for (key => value in extra) globals.set(key, value);
		if (extra.exists("game")) parent = extra.get("game");

		#if sys
		// (carpeta, archivo): primero data/scripts y despues la carpeta vieja, cada una en orden alfabetico
		var found:Array<{dir:String, file:String}> = [];
		for (sub in [DIR, LEGACY_DIR])
		{
			var dir = Path.join([levelDir, sub]);
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;

			var files = [for (entry in FileSystem.readDirectory(dir)) if (StringTools.endsWith(entry.toLowerCase(), ".hx")) entry];
			files.sort(Reflect.compare);
			for (file in files) found.push({dir: dir, file: file});
		}
		if (found.length == 0) return;

		// Primero se crean todos (asi un script puede usar `scripts.getByName("otro.hx")` desde su codigo de arriba)...
		for (item in found)
		{
			try
			{
				add(create(item.file, Path.join([item.dir, item.file])));
			}
			catch (e:Dynamic)
			{
				Log.error('[Scripts] ' + item.file + ': ' + Std.string(e));
			}
		}

		// ...y luego se ejecutan en orden.
		var i = 0;
		while (i < scripts.length) scripts[i++].load();

		Log.info('[Scripts] ' + scripts.length + ' scripts de ' + levelDir + ' (' + DIR + ')');
		#end
	}

	static function create(name:String, path:String):LevelScript
		return new LevelScript(name, path, levelDir, globals, shared, parent);

	static function add(script:LevelScript):Void
	{
		scripts.push(script);
		has = true;
	}

	/**
	 * Carga y ejecuta otro `.hx` del nivel (`importScript("data/utils")`) y lo devuelve; si ya estaba cargado devuelve el mismo.
	 * Busca la ruta tal cual, y despues dentro de `data/scripts/`, `source/` y `data/` del nivel; la extension es opcional.
	 */
	public static function importScript(path:String):LevelScript
	{
		var file = resolve(path);
		if (file == null) throw 'Script at $path does not exist.';

		var existing = getByPath(file);
		if (existing == null)
		{
			existing = create(haxe.io.Path.withoutDirectory(file), file);
			add(existing);
		}
		existing.load();
		return existing;
	}

	static function resolve(path:String):Null<String>
	{
		#if sys
		for (root in [levelDir, Path.join([levelDir, DIR]), Path.join([levelDir, "source"]), Path.join([levelDir, "data"])])
		{
			var base = Path.join([root, path]);
			if (FileSystem.exists(base) && !FileSystem.isDirectory(base)) return Path.normalize(base);
			for (ext in EXTENSIONS)
			{
				var file = base + "." + ext;
				if (FileSystem.exists(file)) return Path.normalize(file);
			}
		}
		#end
		return null;
	}

	/** El script cargado desde `path` (la ruta con que se creo), o null. */
	public static function getByPath(path:String):Null<LevelScript>
	{
		var wanted = Path.normalize(path);
		for (script in scripts)
			if (Path.normalize(script.path) == wanted) return script;
		return null;
	}

	/** El script por nombre de archivo (`"vida.hx"`; sin extension tambien vale), o null. */
	public static function getByName(name:String):Null<LevelScript>
	{
		for (script in scripts)
			if (script.name == name || Path.withoutExtension(script.name) == name) return script;
		return null;
	}

	/** Pone el objeto padre de todos los scripts (los ya cargados y los que lleguen despues). */
	public static function setParent(object:Dynamic):Void
	{
		parent = object;
		for (script in scripts) script.setParent(object);
	}

	/**
	 * Valor de una variable: la del primer script que la tenga y, si ninguno, la publica.
	 * (Con `getVar` pasa lo mismo: son lo mismo.)
	 */
	public static function get(key:String):Dynamic
	{
		for (script in scripts)
		{
			var value = script.get(key);
			if (value != null) return value;
		}
		return shared.get(key);
	}

	/** Define una variable global en todos los scripts (por ejemplo `hud` cuando ya existe), tambien en los que se importen despues. */
	public static function set(key:String, value:Dynamic):Void
	{
		globals.set(key, value);
		for (script in scripts) script.set(key, value);
	}

	/**
	 * Nombres de Codename para los eventos que el motor lanza con nombre Psych: cada uno con los argumentos que
	 * recibe en Codename. Un script puede definir el nombre Psych, el de Codename o los dos: se llama a los que existan.
	 * (Los eventos de Codename con objeto `event` -- onPlayerHit, onNoteCreation... -- no tienen equivalente aqui.)
	 */
	static final ALIASES:Map<String, Array<{name:String, args:Void->Null<Array<Dynamic>>}>> = [
		"onLoad" => [{name: "onCreate", args: null}, {name: "create", args: null}],
		"onCreatePost" => [{name: "postCreate", args: null}],
		"onUpdate" => [{name: "update", args: null}],
		"onUpdatePost" => [{name: "postUpdate", args: null}],
		"onStepHit" => [{name: "stepHit", args: () -> [Conductor.currentStep]}],
		"onBeatHit" => [{name: "beatHit", args: () -> [Conductor.currentBeat]}],
		"onSectionHit" => [{name: "measureHit", args: () -> [Std.int(Conductor.currentBeat / 4)]}],
		"onDestroy" => [{name: "destroy", args: null}]
	];

	/** Llama `func` en todos los scripts activos. true = alguno devolvio `Function_Stop`. */
	public static function call(func:String, ?args:Array<Dynamic>):Bool
	{
		if (!has) return false;
		if (args == null) args = [];

		var stopped = callOne(func, args);

		var aliases = ALIASES.get(func);
		if (aliases != null)
		{
			for (alias in aliases)
			{
				// `update` / `postUpdate` reciben `elapsed` igual que el original; beat/step/measure llevan su numero.
				var aliasArgs = alias.args != null ? alias.args() : (func == "onUpdate" || func == "onUpdatePost" ? args : []);
				if (callOne(alias.name, aliasArgs)) stopped = true;
			}
		}
		return stopped;
	}

	static function callOne(func:String, args:Array<Dynamic>):Bool
	{
		var stopped = false;
		// por indice: un script puede hacer `importScript` durante la llamada y agrandar la lista
		var i = 0;
		while (i < scripts.length)
		{
			var script = scripts[i++];
			if (script.active && script.call(func, args) == STOP)
				stopped = true;
		}
		return stopped;
	}

	public static function clear():Void
	{
		scripts = [];
		has = false;
		parent = null;
		globals = new Map<String, Dynamic>();
		shared = new Map<String, Dynamic>();
		statics = new Map<String, Dynamic>();
	}

	static function baseGlobals():Map<String, Dynamic>
	{
		var globals = new Map<String, Dynamic>();

		globals.set("Function_Continue", CONTINUE);
		globals.set("Function_Stop", STOP);

		// Haxe
		globals.set("Std", Std);
		globals.set("Math", Math);
		globals.set("Reflect", Reflect);
		globals.set("StringTools", StringTools);
		globals.set("Json", Json);
		globals.set("Xml", Xml);
		globals.set("Type", Type);
		globals.set("Date", Date);
		globals.set("Lambda", Lambda);
		#if sys globals.set("Sys", Sys); #end

		// OpenFL / Lime
		globals.set("Assets", openfl.utils.Assets);
		globals.set("Application", lime.app.Application);

		// Flixel
		globals.set("FlxG", FlxG);
		globals.set("FlxBasic", flixel.FlxBasic);
		globals.set("FlxSprite", FlxSprite);
		globals.set("FlxText", FlxText);
		globals.set("FlxBar", flixel.ui.FlxBar);
		globals.set("FlxGroup", FlxGroup);
		globals.set("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
		globals.set("FlxSpriteGroup", FlxSpriteGroup);
		globals.set("FlxCamera", FlxCamera);
		globals.set("FlxSound", flixel.sound.FlxSound);
		globals.set("FlxMath", flixel.math.FlxMath);
		globals.set("FlxAnimateFrames", FlxAnimateFrames);
		globals.set("FlxTween", FlxTween);
		globals.set("FlxEase", FlxEase);
		globals.set("FlxTimer", FlxTimer);
		globals.set("FlxColor", abstractClass("flixel.util.FlxColor", colors()));
		globals.set("FlxPoint", abstractClass("flixel.math.FlxPoint", null));
		globals.set("FlxAxes", abstractClass("flixel.util.FlxAxes", null));

		// Motor
		globals.set("PlayState", funky.game.PlayState);
		globals.set("PlayHUD", funky.game.PlayHUD);
		globals.set("HealthBar", funky.game.HealthBar);
		globals.set("HealthIcon", funky.game.HealthIcon);
		globals.set("Note", funky.game.Note);
		globals.set("Strum", funky.game.Strum);
		globals.set("StrumLine", funky.game.StrumLine);
		globals.set("FunkinSprite", FunkinSprite);
		globals.set("LevelSprite", LevelSprite);
		globals.set("SpriteBuilder", SpriteBuilder);
		globals.set("Stage", Stage);
		globals.set("Storage", Storage);
		globals.set("Paths", Paths);
		globals.set("Conductor", Conductor);
		globals.set("ClientPrefs", ClientPrefs);
		globals.set("NoteSkin", funky.core.NoteSkin);
		globals.set("Difficulty", funky.core.Difficulty);
		globals.set("KeyBinds", funky.core.KeyBinds);
		globals.set("CoolUtil", funky.core.CoolUtil);
		globals.set("Log", Log);
		// Framerate.setPosition(x, y) / .move(dx, dy) / .resetPosition() / .setAlpha(a): mueve el contador de FPS.
		globals.set("Framerate", Framerate);

		// Scripts: `scripts.getByName("a.hx").call("f", [x])`, `importScript("data/utils")`, `Scripts.shared`...
		globals.set("Scripts", Scripts);
		globals.set("scripts", Scripts);
		globals.set("importScript", importScript);

		// Siguen funcionando, pero `public var x` / `x` hacen lo mismo y se ven directo en todos los scripts.
		globals.set("setVar", function(name:String, value:Dynamic):Void shared.set(name, value));
		globals.set("getVar", function(name:String):Dynamic return shared.get(name));

		return globals;
	}

	/**
	 * `FlxColor`, `FlxPoint`... son abstracts: no existen como valor en tiempo de ejecucion. hscript-improved genera una clase
	 * `<nombre>_HSC` (ver `hscript.Config.ALLOWED_ABSTRACT_AND_ENUM`) que los scripts si pueden usar; si no esta, `fallback`.
	 */
	static function abstractClass(name:String, fallback:Dynamic):Dynamic
	{
		var cls = Type.resolveClass(name + "_HSC");
		return cls != null ? cls : fallback;
	}

	/** Respaldo de `FlxColor` si no existe `FlxColor_HSC`: lo basico. */
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
			LIME: FlxColor.LIME,
			MAGENTA: FlxColor.MAGENTA,
			PINK: FlxColor.PINK,
			PURPLE: FlxColor.PURPLE,
			fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255):Int return FlxColor.fromRGB(r, g, b, a),
			fromString: function(value:String):Int return FlxColor.fromString(value),
			interpolate: function(a:Int, b:Int, factor:Float = 0.5):Int return FlxColor.interpolate(a, b, factor)
		};
	}
}
