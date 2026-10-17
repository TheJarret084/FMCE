package funky.scripting;

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

/**
 * Un `.hx` de `<nivel>/scripts/`, con su propio interprete (hscript-improved: clases, `import`, `using`).
 *
 * Las clases propias van en `<nivel>/source/` (NO en `scripts/`, porque todo lo de `scripts/` se ejecuta
 * solo): `import MiClase;` carga `<nivel>/source/MiClase.hx`, `import jefe.Boss;` carga `<nivel>/source/jefe/Boss.hx`.
 */
class LevelScript
{
	static var EXTENSIONS:Array<String> = ["hx", "hscript", "hsc", "hxs"];

	public final name:String;

	var interp:Interp = new Interp();
	var parser:Parser;
	var levelDir:String;
	var imported:Map<String, Bool> = new Map<String, Bool>();
	var reported:Map<String, Bool> = new Map<String, Bool>();

	public function new(name:String, path:String, levelDir:String, globals:Map<String, Dynamic>)
	{
		this.name = name;
		this.levelDir = levelDir;

		interp.errorHandler = onError;
		interp.warnHandler = onWarn;
		interp.importFailedCallback = onImportFailed;
		interp.staticVariables = Scripts.statics;
		interp.publicVariables = Scripts.shared;
		interp.allowStaticVariables = interp.allowPublicVariables = true;

		for (key => value in globals)
			interp.variables.set(key, value);

		var print = Reflect.makeVarArgs(function(args:Array<Dynamic>):Dynamic
		{
			Log.info('[Script ' + name + '] ' + args.join(' '));
			return null;
		});
		interp.variables.set("debugPrint", print);
		interp.variables.set("trace", print);

		parser = new Parser();
		parser.allowJSON = parser.allowMetadata = parser.allowTypes = true;
		parser.preprocessorValues = preprocessors();

		#if sys
		var expr = parser.parseString(File.getContent(path), name);
		@:privateAccess interp.execute(parser.mk(EBlock([]), 0, 0));
		interp.execute(expr);
		call("new", []);
		#end
	}

	public function set(key:String, value:Dynamic):Void
	{
		interp.variables.set(key, value);
		interp.invalidateCache();
	}

	public function exists(func:String):Bool
		return Reflect.isFunction(interp.variables.get(func));

	/** Llama a `func` si el script la define; devuelve lo que retorna (null si no existe o falla). */
	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		var fn = interp.variables.get(func);
		if (!Reflect.isFunction(fn)) return null;

		try
		{
			return Reflect.callMethod(null, fn, args);
		}
		catch (e:Dynamic)
		{
			report(func + ': ' + Std.string(e));
			return null;
		}
	}

	/** `#if android ... #end` dentro de los scripts. */
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

	/** Resuelve `import a.b.C;` buscando `<nivel>/source/a/b/C.hx` (y `<nivel>/a/b/C.hx`). */
	function onImportFailed(cl:Array<String>, ?asName:String):Bool
	{
		#if sys
		var relative = cl.join("/");
		for (root in [Path.join([levelDir, "source"]), levelDir])
		{
			for (ext in EXTENSIONS)
			{
				var file = Path.join([root, relative + "." + ext]);
				if (imported.exists(file)) return true; // ya cargado en este script
				if (!FileSystem.exists(file)) continue;

				try
				{
					parser.line = 1;
					var expr = parser.parseString(File.getContent(file), cl.join(".") + "." + ext);
					@:privateAccess interp.exprReturn(expr);
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

	/** Un mismo error sale una sola vez en el log (onUpdate lo repetiria cada frame). */
	function report(message:String):Void
	{
		if (reported.exists(message)) return;
		reported.set(message, true);
		Log.error('[Script ' + name + '] ' + message);
	}
}
