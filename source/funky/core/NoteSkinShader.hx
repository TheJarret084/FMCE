package funky.core;

#if !nme && !flash
import flixel.addons.display.FlxRuntimeShader;

/**
 * Shader de un noteskin. Se crea desde un `.frag` propio del skin
 * (`addons/noteskins/<id>/shaders/<nombre>.frag`) o, si no existe, desde `assets/shaders/<nombre>.frag`.
 *
 * Los scripts de noteskin lo usan con `shader("nombre")`, o directamente con `new CustomShader("...")`.
 */
@:keep
class NoteSkinShader extends FlxRuntimeShader
{
	/** Nombre con el que se creo (`game/dropShadow`, `sombra`...). */
	public var path:String;
	/** Codigo del fragment shader ya cargado. */
	public var source:String;

	public function new(fragment:String, ?vertex:String, ?path:String)
	{
		super(fragment, vertex);
		this.source = fragment;
		this.path = path == null ? "" : path;
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
#end
