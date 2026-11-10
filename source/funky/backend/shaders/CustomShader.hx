package funky.backend.shaders;

import flixel.addons.display.FlxRuntimeShader;
import funky.core.Addons;
import funky.core.Log;
import openfl.utils.Assets;

/**
 * Shader `.frag` con carpeta opcional.
 *
 * - Sin carpeta usa `assets/shaders/`.
 * - Con carpeta usa esa carpeta: si empieza con `assets/` lee del pack; si no, la trata como ruta
 *   relativa a `addons/` (ej. `noteskins/fmm/shaders`), asi funciona tanto con addons externos como
 *   con los que vienen dentro del build.
 */
@:keep // los scripts lo crean por reflection: que DCE no lo borre
class CustomShader extends FlxRuntimeShader
{
	public var path:String;

	public function new(name:String, ?folder:String, ?glslVersion:String)
	{
		var frag:String = null, vert:String = null;
		if (folder == null || folder.length == 0) folder = "assets/shaders";

		var fragPath = folder + '/' + name + '.frag';
		var vertPath = folder + '/' + name + '.vert';

		if (folder.indexOf("assets/") == 0)
		{
			if (Assets.exists(fragPath)) frag = Assets.getText(fragPath);
			if (Assets.exists(vertPath)) vert = Assets.getText(vertPath);
		}
		else
		{
			// `Addons` ya antepone "addons/" y prefiere la carpeta externa.
			var rel = folder.indexOf("addons/") == 0 ? folder.substr("addons/".length) : folder;
			frag = Addons.getText(rel + '/' + name + '.frag');
			vert = Addons.getText(rel + '/' + name + '.vert');
		}

		if (frag == null) Log.warn('[CustomShader] no se encontro $fragPath');
		path = name;
		super(frag, vert);
	}

	/** Asigna un uniform por nombre (acepta un valor o un array). */
	public function hset(name:String, value:Dynamic):Void
	{
		var param:Dynamic = Reflect.field(data, name);
		if (param == null) return;
		param.value = (value is Array) ? value : [value];
	}

	public function hget(name:String):Dynamic
	{
		var param:Dynamic = Reflect.field(data, name);
		return param == null ? null : param.value;
	}
}
