package funky.scripting;

import flixel.FlxG;
import funky.core.Log;
import hscript.Expr;
import hscript.Expr.Error;
import hscript.Interp;
import hscript.Parser;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

class LevelScript
{
	static var EXTENSIONS:Array<String> = ["hx", "hscript", "hsc", "hxs"];

	public static var current(default, null):Null<LevelScript> = null;

	public final name:String;

	public var fileName(get, never):String;

	public final path:String;

	public var active:Bool = true;

	public var loaded(default, null):Bool = false;

	public var interp:Interp = new Interp();
	public var parser:Parser;

	var expr:Null<Expr>;
	var levelDir:String;
	var imported:Map<String, Bool> = new Map<String, Bool>();
	var reported:Map<String, Bool> = new Map<String, Bool>();

	inline function get_fileName():String
		return name;

	public function new(name:String, path:String, levelDir:String, globals:Map<String, Dynamic>, ?publicMap:Map<String, Dynamic>, ?parent:Dynamic)
	{
		this.name = name;
		this.path = path;
		this.levelDir = levelDir;

		interp.errorHandler = onError;
		interp.warnHandler = onWarn;
		interp.importFailedCallback = onImportFailed;
		interp.staticVariables = Scripts.statics;
		interp.publicVariables = publicMap != null ? publicMap : Scripts.shared;
		interp.allowStaticVariables = interp.allowPublicVariables = true;
		if (parent != null) interp.scriptObject = parent;

		for (key => value in globals)
			interp.variables.set(key, value);

		var print = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic
		{
			Log.info('[Script ' + name + '] ' + args.join(' '));
			return null;
		});
		interp.variables.set("debugPrint", print);
		interp.variables.set("trace", print);

		interp.variables.set("__script__", this);
		interp.variables.set("disableScript", function():Void active = false);
		interp.variables.set("state", FlxG.state);
		interp.variables.set("window", lime.app.Application.current.window);

		parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		parser.preprocessorValues = preprocessors();

		#if sys
		try
		{
			expr = parser.parseString(File.getContent(path), name);
		}
		catch (e:Dynamic)
		{
			report(Std.string(e));
		}
		#end
	}

	public function load():Void
	{
		if (loaded) return;
		loaded = true;
		if (expr == null) return;

		var previous = current;
		current = this;
		try
		{
			@:privateAccess interp.execute(parser.mk(EBlock([]), 0, 0));
			interp.execute(expr);
			call("new", []);
		}
		catch (e:Dynamic)
		{
			report(Std.string(e));
		}
		current = previous;
	}

	public function setParent(parent:Dynamic):Void
	{
		interp.scriptObject = parent;
		interp.invalidateCache();
	}

	public function setPublicMap(map:Map<String, Dynamic>):Void
		interp.publicVariables = map;

	public function get(key:String):Dynamic
	{
		var value = interp.variables.get(key);
		if (value == null && interp.publicVariables != null) value = interp.publicVariables.get(key);
		return value;
	}

	public function set(key:String, value:Dynamic):Void
	{
		interp.variables.set(key, value);
		interp.invalidateCache();
	}

	public function exists(func:String):Bool
		return Reflect.isFunction(interp.variables.get(func));

	public function call(func:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active) return null;

		var fn = interp.variables.get(func);
		if (!Reflect.isFunction(fn)) return null;

		var previous = current;
		current = this;
		var result:Dynamic = null;
		try
		{
			result = Reflect.callMethod(null, fn, args == null ? [] : args);
		}
		catch (e:Dynamic)
		{
			report(func + ': ' + Std.string(e));
		}
		current = previous;
		return result;
	}

	static function preprocessors():Map<String, Dynamic>
	{
		var values = new Map<String, Dynamic>();
		values.set("FMCE", true);
		#if sys values.set("sys", true); #end
		#if desktop values.set("desktop", true); #end
		#if mobile values.set("mobile", true); #end
		#if android values.set("android", true); #end
		#if web values.set("web", true); #end
		#if debug values.set("debug", true); #end
		return values;
	}

	function onImportFailed(cl:Array<String>, ?asName:String):Bool
	{
		#if sys
		var relative = cl.join("/");
		for (root in [Path.join([levelDir, "source"]), levelDir])
		{
			for (ext in EXTENSIONS)
			{
				var file = Path.join([root, relative + "." + ext]);
				if (imported.exists(file)) return true;
				if (!FileSystem.exists(file)) continue;

				try
				{
					parser.line = 1;
					var classExpr = parser.parseString(File.getContent(file), cl.join(".") + "." + ext);
					@:privateAccess interp.exprReturn(classExpr);
					imported.set(file, true);
				}
				catch (e:Dynamic)
				{
					report('import ' + cl.join(".") + ': ' + Std.string(e));
				}
				return true;
			}
		}
		#end
		return false;
	}

	function onError(error:Error):Void
		report(error.toString());

	function onWarn(error:Error):Void
		Log.warn('[Script ' + name + '] ' + error.toString());

	function report(message:String):Void
	{
		if (reported.exists(message)) return;
		reported.set(message, true);
		Log.error('[Script ' + name + '] ' + message);

		var game = funky.game.PlayState.instance;
		if (game != null) game.scriptFailed(name + ":\n" + message);
	}

	public function toString():String
		return 'LevelScript($name${active ? "" : ", disabled"})';
}
