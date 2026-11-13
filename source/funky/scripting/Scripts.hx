package funky.scripting;

import animate.FlxAnimateFrames;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import funky.backend.FunkinSprite;
import funky.backend.system.framerate.Framerate;
import funky.core.Conductor;
import funky.core.Log;
import funky.core.Storage;
import funky.game.LevelSprite;
import funky.game.SpriteBuilder;
import funky.game.Stage;
import haxe.io.Path;

#if sys
import sys.FileSystem;
#end

class Scripts
{

	public static inline var DIR:String = "data/scripts";

	public static inline var LEGACY_DIR:String = "scripts";

	public static inline var CONTINUE:Int = Script.CONTINUE;
	public static inline var STOP:Int = Script.STOP;

	static var EXTENSIONS:Array<String> = ["hx", "hscript", "hsc", "hxs"];

	public static var has(default, null):Bool = false;

	public static var shared(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	public static var statics(default, null):Map<String, Dynamic> = new Map<String, Dynamic>();

	public static var scripts(default, null):Array<LevelScript> = [];

	public static var parent(default, null):Dynamic = null;

	static var globals:Map<String, Dynamic> = new Map<String, Dynamic>();

	static var levelDir:String = "";

	public static function load(levelDir:String, extra:Map<String, Dynamic>):Void
	{
		clear();
		Scripts.levelDir = levelDir;

		globals = baseGlobals();
		for (key => value in extra) globals.set(key, value);
		if (extra.exists("game")) parent = extra.get("game");

		#if sys

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

	public static function getByPath(path:String):Null<LevelScript>
	{
		var wanted = Path.normalize(path);
		for (script in scripts)
			if (Path.normalize(script.path) == wanted) return script;
		return null;
	}

	public static function getByName(name:String):Null<LevelScript>
	{
		for (script in scripts)
			if (script.name == name || Path.withoutExtension(script.name) == name) return script;
		return null;
	}

	public static function setParent(object:Dynamic):Void
	{
		parent = object;
		for (script in scripts) script.setParent(object);
	}

	public static function get(key:String):Dynamic
	{
		for (script in scripts)
		{
			var value = script.get(key);
			if (value != null) return value;
		}
		return shared.get(key);
	}

	public static function set(key:String, value:Dynamic):Void
	{
		globals.set(key, value);
		for (script in scripts) script.set(key, value);
	}

	/**
	 * Nombres alternativos (estilo Codename / Psych) que se llaman ademas del nombre real. Si el alias no define `args`
	 * recibe los mismos argumentos que el original. Ojo: a diferencia de Codename no llegan eventos (`event.note`),
	 * llegan los valores sueltos (`note`, `lane`...). Para saber el lado de una nota: `note.strumLine == playerLine`.
	 */
	static function alias(name:String, ?args:Void->Null<Array<Dynamic>>):{name:String, args:Void->Null<Array<Dynamic>>}
		return {name: name, args: args};

	static final ALIASES:Map<String, Array<{name:String, args:Void->Null<Array<Dynamic>>}>> = [
		// ciclo de vida
		"onLoad" => [alias("onCreate"), alias("create")],
		"onCreatePost" => [alias("postCreate")],
		"onUpdate" => [alias("update")],
		"onUpdatePost" => [alias("postUpdate")],
		"onStepHit" => [alias("stepHit", () -> [Conductor.currentStep])],
		"onBeatHit" => [alias("beatHit", () -> [Conductor.currentBeat])],
		"onSectionHit" => [alias("measureHit", () -> [Std.int(Conductor.currentBeat / 4)])],
		"onDestroy" => [alias("destroy")],

		// notas: Pre = antes de animar/puntuar (como onNoteHit de Codename), sin Pre = ya procesada (onPostNoteHit)
		"goodNoteHitPre" => [alias("onNoteHit"), alias("onPlayerHit")],
		"opponentNoteHitPre" => [alias("onNoteHit"), alias("onDadHit"), alias("onOpponentHit")],
		"goodNoteHit" => [alias("onPostNoteHit"), alias("onPostPlayerHit")],
		"opponentNoteHit" => [alias("onPostNoteHit"), alias("onPostDadHit"), alias("onPostOpponentHit")],
		"noteMiss" => [alias("onNoteMiss"), alias("onPlayerMiss")],
		"noteMissPress" => [alias("onGhostMiss")],
		"onSpawnNote" => [alias("onNoteCreation")],
		"onSpawnNotePost" => [alias("onPostNoteCreation")],
		"preReceptorGeneration" => [alias("onStrumCreation")],
		"postReceptorGeneration" => [alias("onPostStrumCreation")],

		// partida
		"onSongStart" => [alias("onStartSong")],
		"onEndSong" => [alias("onSongEnd")],
		"onCountdownStarted" => [alias("onPostStartCountdown")],
		"onCountdownTick" => [alias("onCountdown")],
		"onPause" => [alias("onGamePause")],
		"onMoveCamera" => [alias("onCameraMove")]
	];

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

				var aliasArgs = alias.args != null ? alias.args() : args;
				if (callOne(alias.name, aliasArgs)) stopped = true;
			}
		}
		return stopped;
	}

	static function callOne(func:String, args:Array<Dynamic>):Bool
	{
		var stopped = false;

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
		var globals = Script.commonGlobals();

		#if sys globals.set("Sys", Sys); #end

		globals.set("FlxBasic", flixel.FlxBasic);
		globals.set("FlxText", FlxText);
		globals.set("FlxBar", flixel.ui.FlxBar);
		globals.set("FlxGroup", FlxGroup);
		globals.set("FlxTypedGroup", flixel.group.FlxGroup.FlxTypedGroup);
		globals.set("FlxSpriteGroup", FlxSpriteGroup);
		globals.set("FlxCamera", FlxCamera);
		globals.set("FlxSound", flixel.sound.FlxSound);
		globals.set("FlxMath", flixel.math.FlxMath);
		globals.set("FlxAnimateFrames", FlxAnimateFrames);
		globals.set("FlxPoint", Script.abstractClass("flixel.math.FlxPoint", null));
		globals.set("FlxAxes", Script.abstractClass("flixel.util.FlxAxes", null));

		globals.set("PlayHUD", funky.game.PlayHUD);
		globals.set("HealthBar", funky.game.HealthBar);
		globals.set("HealthIcon", funky.game.HealthIcon);
		globals.set("FunkinSprite", FunkinSprite);
		globals.set("LevelSprite", LevelSprite);
		globals.set("SpriteBuilder", SpriteBuilder);
		globals.set("Stage", Stage);
		globals.set("Storage", Storage);
		globals.set("NoteSkin", funky.core.NoteSkin);
		globals.set("Difficulty", funky.core.Difficulty);
		globals.set("KeyBinds", funky.core.KeyBinds);
		globals.set("CoolUtil", funky.core.CoolUtil);

		globals.set("Framerate", Framerate);

		globals.set("Scripts", Scripts);
		globals.set("scripts", Scripts);
		globals.set("importScript", importScript);

		globals.set("setVar", function(name:String, value:Dynamic):Void shared.set(name, value));
		globals.set("getVar", function(name:String):Dynamic return shared.get(name));

		return globals;
	}
}
