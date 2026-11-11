package funky.core;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
#if (!nme && !flash)
import funky.backend.shaders.CustomShader;
#end
import hscript.Expr;
import hscript.Expr.Error;
import hscript.Interp;
import hscript.Parser;

class NoteSkinScript
{
	public static var CONTINUE:Int = 0;
	public static var STOP:Int = 1;

	static var EXTENSIONS:Array<String> = ["hx", "hscript", "hsc"];

	public final name:String;
	public var active:Bool = true;
	public var loaded(default, null):Bool = false;

	public var interp:Interp = new Interp();
	public var parser:Parser;

	var expr:Null<Expr>;
	var skin:NoteSkin;
	var imported:Map<String, Bool> = new Map<String, Bool>();
	var reported:Map<String, Bool> = new Map<String, Bool>();

	public function new(name:String, source:String, skin:NoteSkin)
	{
		this.name = name;
		this.skin = skin;

		interp.errorHandler = onError;
		interp.warnHandler = onWarn;
		interp.importFailedCallback = onImportFailed;
		interp.staticVariables = new Map<String, Dynamic>();
		interp.publicVariables = new Map<String, Dynamic>();
		interp.allowStaticVariables = interp.allowPublicVariables = true;
		interp.scriptObject = skin;

		for (key => value in makeGlobals())
			interp.variables.set(key, value);

		var print = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic
		{
			Log.info('[NoteSkin ' + skin.id + '] ' + args.join(' '));
			return null;
		});
		interp.variables.set("debugPrint", print);
		interp.variables.set("trace", print);

		// Como en los scripts de nivel.
		interp.variables.set("__script__", this);
		interp.variables.set("disableScript", function():Void active = false);

		parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		parser.preprocessorValues = preprocessors();

		try
		{
			expr = parser.parseString(source, name);
		}
		catch (e:Dynamic)
		{
			report(Std.string(e));
		}
	}

	/** Ejecuta el script (una sola vez) y llama a `onLoad` / `create` / `new`. */
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

		if (exists("onLoad")) call("onLoad");
		else if (exists("create")) call("create");
		else call("new");
	}

	/** true si el script define una funcion `func`. */
	public function exists(func:String):Bool
		return Reflect.isFunction(interp.variables.get(func));

	/** Llama a `func` si existe; devuelve lo que retorne (null si no existe, esta desactivado o falla). */
	public function call(func:String, ?args:Array<Dynamic>):Dynamic
	{
		if (!active) return null;

		var fn = interp.variables.get(func);
		if (!Reflect.isFunction(fn)) return null;

		var result:Dynamic = null;
		try
		{
			result = Reflect.callMethod(null, fn, args == null ? [] : args);
		}
		catch (e:Dynamic)
		{
			report(func + ': ' + Std.string(e));
		}
		return result;
	}

	// ───────────────────────────── ayudas para el script ─────────────────────────────

	/** `shader("sombra")`: primero `noteskins/<id>/shaders/sombra.frag`, despues `assets/shaders/sombra.frag`. */
	public function makeShader(name:String):Dynamic
	{
		#if (!nme && !flash)
		var local = skin.shaderSource(name);
		if (local != null) return new NoteSkinShader(local, null, name);
		return new CustomShader(name);
		#else
		Log.warn('[NoteSkin ' + skin.id + '] los shaders no estan disponibles en este target: ' + name);
		return null;
		#end
	}

	function makeGlobals():Map<String, Dynamic>
	{
		var globals = new Map<String, Dynamic>();

		globals.set("skin", skin);
		globals.set("NoteSkin", NoteSkin);
		globals.set("NoteSkinScript", NoteSkinScript);
		#if (!nme && !flash)
		globals.set("NoteSkinShader", NoteSkinShader);
		globals.set("CustomShader", CustomShader);
		globals.set("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
		#end
		globals.set("NoteRGBShader", NoteRGBShader);

		globals.set("Function_Continue", CONTINUE);
		globals.set("Function_Stop", STOP);

		// Haxe
		globals.set("Std", Std);
		globals.set("Math", Math);
		globals.set("Reflect", Reflect);
		globals.set("StringTools", StringTools);
		globals.set("Json", haxe.Json);
		globals.set("Xml", Xml);
		globals.set("Type", Type);
		globals.set("Date", Date);
		globals.set("Lambda", Lambda);

		// OpenFL / Lime
		globals.set("Assets", openfl.utils.Assets);
		globals.set("Application", lime.app.Application);

		// Flixel
		globals.set("FlxG", FlxG);
		globals.set("FlxSprite", FlxSprite);
		globals.set("FlxTween", FlxTween);
		globals.set("FlxEase", FlxEase);
		globals.set("FlxTimer", FlxTimer);
		globals.set("FlxColor", colors());

		// Motor
		globals.set("PlayState", funky.game.PlayState);
		globals.set("Note", funky.game.Note);
		globals.set("Strum", funky.game.Strum);
		globals.set("StrumLine", funky.game.StrumLine);
		globals.set("Paths", Paths);
		globals.set("ClientPrefs", ClientPrefs);
		globals.set("Conductor", Conductor);
		globals.set("Log", Log);

		// Ayudas propias
		globals.set("shader", function(name:String):Dynamic
		{
			return makeShader(name);
		});
		globals.set("createShader", function(name:String):Dynamic
		{
			return makeShader(name);
		});
		globals.set("setShader", function(sprite:Dynamic, name:String):Dynamic
		{
			var s = makeShader(name);
			if (sprite != null) sprite.shader = s;
			return s;
		});
		globals.set("clearShader", function(sprite:Dynamic):Void
		{
			if (sprite != null) sprite.shader = null;
		});

		return globals;
	}

	/** `FlxColor` es un abstract: en runtime no existe, asi que se expone lo basico como objeto. */
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

	/** `#if android ... #end` dentro de los scripts del skin. */
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

	/** `import a.b.C;` busca `addons/noteskins/<id>/source/a/b/C.hx` (y sin `source/`). */
	function onImportFailed(cl:Array<String>, ?asName:String):Bool
	{
		var relative = cl.join("/");
		for (root in ["noteskins/" + skin.id + "/source/", "noteskins/" + skin.id + "/"])
		{
			for (ext in EXTENSIONS)
			{
				var rel = root + relative + "." + ext;
				if (imported.exists(rel)) return true;

				var source = Addons.getText(rel);
				if (source == null) continue;

				try
				{
					parser.line = 1;
					var classExpr = parser.parseString(source, cl.join(".") + "." + ext);
					@:privateAccess interp.exprReturn(classExpr);
					imported.set(rel, true);
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
	{
		report(error.toString());
	}

	function onWarn(error:Error):Void
		Log.warn('[NoteSkin ' + skin.id + '] ' + error.toString());

	/** Un mismo error sale una sola vez en el log. */
	function report(message:String):Void
	{
		if (reported.exists(message)) return;
		reported.set(message, true);
		Log.error('[NoteSkin ' + skin.id + '] ' + name + ': ' + message);
	}

	public function toString():String
		return 'NoteSkinScript($name' + (active ? "" : ", disabled") + ')';
}
