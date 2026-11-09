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

/**
 * Un `.hx` de un nivel, con su propio interprete (hscript-improved: clases, `import`, `using`).
 * Hace el papel de `HScript` en Codename:
 *
 *  - Su "padre" es el PlayState (`setParent`): lo que el script no define lo busca ahi, asi que `healthBar.visible = false;`,
 *    `hud`, `score`, `stage`... funcionan sin prefijo, y `score = 10;` asigna al PlayState.
 *  - Comparte el mapa de variables publicas con todos los demas scripts (`setPublicMap`): `public var x`, `public function f()`
 *    y `static var` se ven desde cualquier script.
 *  - Se crea primero (se parsea) y se ejecuta despues con `load()`, cuando ya tiene padre y mapa publico.
 *
 * Las clases propias van en `<nivel>/source/` (NO en `data/scripts/`, porque todo lo de `data/scripts/` se ejecuta
 * solo): `import MiClase;` carga `<nivel>/source/MiClase.hx`, `import jefe.Boss;` carga `<nivel>/source/jefe/Boss.hx`.
 */
class LevelScript
{
	static var EXTENSIONS:Array<String> = ["hx", "hscript", "hsc", "hxs"];

	/** El script que se esta ejecutando ahora mismo (null fuera de un script). Util para trazas y errores. */
	public static var current(default, null):Null<LevelScript> = null;

	public final name:String;
	/** Igual que `name`: como lo llama Codename. */
	public var fileName(get, never):String;
	/** Ruta del archivo en disco. */
	public final path:String;
	/** false = `Scripts.call` lo salta (`disableScript()` desde el propio script). */
	public var active:Bool = true;
	/** true si ya se ejecuto (`load`). */
	public var loaded(default, null):Bool = false;

	public var interp:Interp = new Interp();
	public var parser:Parser;

	var expr:Null<Expr>;
	var levelDir:String;
	var imported:Map<String, Bool> = new Map<String, Bool>();
	var reported:Map<String, Bool> = new Map<String, Bool>();

	inline function get_fileName():String
		return name;

	/** Lee y parsea `path`, pero NO lo ejecuta: llama a `load()` cuando ya tenga padre y mapa publico. */
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

		// Como en Codename.
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

	/** Ejecuta el script (una sola vez) y llama a su `new()` si lo define. */
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

	/**
	 * Objeto "padre" del script (el PlayState): `healthBar` se escribe `healthBar`, no `game.healthBar`.
	 * Lo que el script define el mismo (variables, funciones) tiene prioridad sobre lo del padre.
	 */
	public function setParent(parent:Dynamic):Void
	{
		interp.scriptObject = parent;
		interp.invalidateCache();
	}

	/** Mapa de variables publicas (`public var`) compartido por todos los scripts. */
	public function setPublicMap(map:Map<String, Dynamic>):Void
		interp.publicVariables = map;

	/** Variable del script: las suyas primero y despues las publicas. */
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

	/** true si el script define una funcion `func`. */
	public function exists(func:String):Bool
		return Reflect.isFunction(interp.variables.get(func));

	/** Llama a `func` si el script la define; devuelve lo que retorna (null si no existe, esta desactivado o falla). */
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

	/** Un mismo error sale una sola vez en el log (onUpdate lo repetiria cada frame). */
	function report(message:String):Void
	{
		if (reported.exists(message)) return;
		reported.set(message, true);
		Log.error('[Script ' + name + '] ' + message);

		// Modo test: el juego para y sale la ventana de error. Jugando normal solo queda en el log.
		var game = funky.game.PlayState.instance;
		if (game != null) game.scriptFailed(name + ":\n" + message);
	}

	public function toString():String
		return 'LevelScript($name${active ? "" : ", disabled"})';
}
