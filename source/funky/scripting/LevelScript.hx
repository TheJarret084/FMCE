package funky.scripting;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

/** Script de un nivel (data/scripts/*.hx). Todo lo generico esta en `Script`. */
class LevelScript extends Script
{
	public static var current(default, null):Null<LevelScript> = null;

	public final path:String;

	public var fileName(get, never):String;

	var levelDir:String;

	inline function get_fileName():String
		return name;

	public function new(name:String, path:String, levelDir:String, globals:Map<String, Dynamic>, ?publicMap:Map<String, Dynamic>, ?parent:Dynamic)
	{
		super(name, "Script " + name, globals, Scripts.statics, publicMap != null ? publicMap : Scripts.shared, parent);
		this.path = path;
		this.levelDir = levelDir;

		interp.variables.set("state", flixel.FlxG.state);
		interp.variables.set("window", lime.app.Application.current.window);

		#if sys
		try
		{
			parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			report(Std.string(e));
		}
		#end
	}

	override public function load():Void
	{
		var previous = current;
		current = this;
		super.load();
		current = previous;
	}

	override public function call(func:String, ?args:Array<Dynamic>):Dynamic
	{
		var previous = current;
		current = this;
		var result = super.call(func, args);
		current = previous;
		return result;
	}

	override function importRoots():Array<String>
		#if sys return [Path.join([levelDir, "source"]), levelDir]; #else return []; #end

	override function readSource(file:String):Null<String>
	{
		#if sys
		return FileSystem.exists(file) ? File.getContent(file) : null;
		#else
		return null;
		#end
	}

	override function report(message:String):Void
	{
		if (reported.exists(message)) return;
		super.report(message);

		var game = funky.game.PlayState.instance;
		if (game != null) game.scriptFailed(name + ":\n" + message);
	}
}
