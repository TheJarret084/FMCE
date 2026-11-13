package funky.scripting;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funky.core.ClientPrefs;
import funky.core.Conductor;
import funky.core.Log;
import funky.core.Paths;
import haxe.io.Path;
import hscript.Expr;
import hscript.Expr.Error;
import hscript.Interp;
import hscript.Parser;

/**
 * Base de todos los scripts hscript del motor (nivel, noteskin, ...). Hace lo que antes se copiaba en cada clase:
 * Interp + Parser, print/trace, imports de clases .hx, preprocesadores, reporte de errores, load/call/get/set y los
 * globals comunes. Cada hijo solo pone lo suyo (de donde sale el codigo, que globals extra, que pasa al cargar).
 */
class Script
{
	public static inline var CONTINUE:Int = 0;
	public static inline var STOP:Int = 1;

	static var EXTENSIONS:Array<String> = ["hx", "hscript", "hsc", "hxs"];

	public final name:String;

	public var active:Bool = true;
	public var loaded(default, null):Bool = false;

	public var interp:Interp = new Interp();
	public var parser:Parser;

	var tag:String;
	var expr:Null<Expr>;
	var imported:Map<String, Bool> = new Map<String, Bool>();
	var reported:Map<String, Bool> = new Map<String, Bool>();

	public function new(name:String, tag:String, globals:Map<String, Dynamic>, statics:Map<String, Dynamic>, publics:Map<String, Dynamic>, ?scriptObject:Dynamic)
	{
		this.name = name;
		this.tag = tag;

		interp.errorHandler = onError;
		interp.warnHandler = onWarn;
		interp.importFailedCallback = onImportFailed;
		interp.staticVariables = statics;
		interp.publicVariables = publics;
		interp.allowStaticVariables = interp.allowPublicVariables = true;
		if (scriptObject != null) interp.scriptObject = scriptObject;

		for (key => value in globals)
			interp.variables.set(key, value);

		var print = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic
		{
			Log.info('[' + this.tag + '] ' + args.join(' '));
			return null;
		});
		interp.variables.set("debugPrint", print);
		interp.variables.set("trace", print);

		interp.variables.set("__script__", this);
		interp.variables.set("disableScript", function():Void active = false);

		parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		parser.preprocessorValues = preprocessors();
	}

	/** Parsea el codigo. Los hijos lo llaman desde su constructor con el texto que lean de donde sea. */
	function parse(source:String):Void
	{
		try
		{
			expr = parser.parseString(source, name);
		}
		catch (e:Dynamic)
		{
			report(Std.string(e));
		}
	}

	public function load():Void
	{
		if (loaded) return;
		loaded = true;
		if (expr == null) return;

		try
		{
			@:privateAccess interp.execute(parser.mk(EBlock([]), 0, 0));
			interp.execute(expr);
		}
		catch (e:Dynamic)
		{
			report(Std.string(e));
			return;
		}

		onLoaded();
	}

	/** Se llama despues de ejecutar el script sin error. Por defecto, `new()`. */
	function onLoaded():Void
		call("new");

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

		try
		{
			return Reflect.callMethod(null, fn, args == null ? [] : args);
		}
		catch (e:Dynamic)
		{
			report(func + ': ' + Std.string(e));
		}
		return null;
	}

	/** Carpetas donde buscar `import a.b.C;` (sin barra final). */
	function importRoots():Array<String>
		return [];

	/** Codigo de un archivo importable o null si no existe. */
	function readSource(file:String):Null<String>
		return null;

	function onImportFailed(cl:Array<String>, ?asName:String):Bool
	{
		var relative = cl.join("/");
		for (root in importRoots())
		{
			for (ext in EXTENSIONS)
			{
				var file = Path.join([root, relative + "." + ext]);
				if (imported.exists(file)) return true;

				var source = readSource(file);
				if (source == null) continue;

				try
				{
					parser.line = 1;
					var classExpr = parser.parseString(source, cl.join(".") + "." + ext);
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
		return false;
	}

	function onError(error:Error):Void
		report(error.toString());

	function onWarn(error:Error):Void
		Log.warn('[' + tag + '] ' + error.toString());

	function report(message:String):Void
	{
		if (reported.exists(message)) return;
		reported.set(message, true);
		Log.error('[' + tag + '] ' + message);
	}

	public function toString():String
		return Type.getClassName(Type.getClass(this)).split(".").pop() + '($name' + (active ? "" : ", disabled") + ')';

	/** Globals que ven todos los scripts. Cada hijo agrega los suyos encima. */
	public static function commonGlobals():Map<String, Dynamic>
	{
		var globals = new Map<String, Dynamic>();

		globals.set("Function_Continue", CONTINUE);
		globals.set("Function_Stop", STOP);

		globals.set("Std", Std);
		globals.set("Math", Math);
		globals.set("Reflect", Reflect);
		globals.set("StringTools", StringTools);
		globals.set("Json", haxe.Json);
		globals.set("Xml", Xml);
		globals.set("Type", Type);
		globals.set("Date", Date);
		globals.set("Lambda", Lambda);

		globals.set("Assets", openfl.utils.Assets);
		globals.set("Application", lime.app.Application);

		globals.set("FlxG", FlxG);
		globals.set("FlxSprite", FlxSprite);
		globals.set("FlxTween", FlxTween);
		globals.set("FlxEase", FlxEase);
		globals.set("FlxTimer", FlxTimer);
		globals.set("FlxColor", abstractClass("flixel.util.FlxColor", colors()));

		globals.set("PlayState", funky.game.PlayState);
		globals.set("Note", funky.game.Note);
		globals.set("Strum", funky.game.Strum);
		globals.set("StrumLine", funky.game.StrumLine);
		globals.set("Paths", Paths);
		globals.set("ClientPrefs", ClientPrefs);
		globals.set("Conductor", Conductor);
		globals.set("Log", Log);

		return globals;
	}

	public static function abstractClass(name:String, fallback:Dynamic):Dynamic
	{
		var cls = Type.resolveClass(name + "_HSC");
		return cls != null ? cls : fallback;
	}

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
			fromInt: function(value:Int):Int return value,
			interpolate: function(a:Int, b:Int, factor:Float = 0.5):Int return FlxColor.interpolate(a, b, factor)
		};
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
}
