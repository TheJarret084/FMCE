package funky.backend.shaders;

import flixel.addons.display.FlxRuntimeShader;
import funky.backend.addons.Addons;
import funky.backend.system.Log;
import openfl.display.BitmapData;
import openfl.display.ShaderInput;
import openfl.display.ShaderParameterType;
import openfl.utils.Assets;

@:keep
class CustomShader extends FlxRuntimeShader
{
	public var path:String;

	public var failed:Bool = false;

	public static function readSource(name:String, ?folder:String):{frag:Null<String>, vert:Null<String>}
	{
		if (folder == null || folder.length == 0) folder = "assets/shaders";
		if (folder.charAt(folder.length - 1) == "/") folder = folder.substr(0, folder.length - 1);

		var frag:Null<String> = null;
		var vert:Null<String> = null;
		var fragPath = folder + '/' + name + '.frag';
		var vertPath = folder + '/' + name + '.vert';

		if (folder.indexOf("assets/") == 0)
		{
			if (Assets.exists(fragPath)) frag = Assets.getText(fragPath);
			if (Assets.exists(vertPath)) vert = Assets.getText(vertPath);
		}
		else
		{
			var rel = folder.indexOf("addons/") == 0 ? folder.substr("addons/".length) : folder;
			frag = Addons.getText(rel + '/' + name + '.frag');
			vert = Addons.getText(rel + '/' + name + '.vert');
		}
		return {frag: frag, vert: vert};
	}

	static function withVersion(source:Null<String>, version:Null<String>):Null<String>
	{
		if (source == null || version == null || version.length == 0) return source;
		if (source.indexOf("#version") >= 0) return source;
		return "#version " + version + "\n" + source;
	}

	public function new(?name:String, ?folder:String, ?glslVersion:String)
	{
		var src = name == null ? {frag: null, vert: null} : readSource(name, folder);
		var missing = name != null && src.frag == null;
		super(withVersion(src.frag, glslVersion), withVersion(src.vert, glslVersion));
		path = name == null ? "" : name;
		failed = missing;
		if (missing) Log.warn('[CustomShader] no se encontro ${folder == null || folder.length == 0 ? "assets/shaders" : folder}/$name.frag');
	}

	public function has(name:String):Bool
		return Reflect.field(data, name) != null;

	public function set(name:String, value:Dynamic):Bool
	{
		var param:Dynamic = Reflect.field(data, name);
		if (param == null)
		{
			Log.warn('[CustomShader:$path] el uniform "$name" no existe');
			return false;
		}

		// Un sampler2D es un ShaderInput; todo lo demas, un ShaderParameter. (No sirve mirar hasField("value"/"input"):
		// ambos arrancan en null y hasField da false hasta que se setean.)
		if (Std.isOfType(param, ShaderInput))
		{
			if (!Std.isOfType(value, BitmapData))
			{
				Log.warn('[CustomShader:$path] "$name" es un sampler2D: pasa un BitmapData');
				return false;
			}
			setSampler2D(name, cast value);
			return true;
		}

		if (Std.isOfType(value, BitmapData))
		{
			Log.warn('[CustomShader:$path] "$name" no es un sampler2D');
			return false;
		}

		var list:Array<Dynamic> = Std.isOfType(value, Array) ? cast value : [value];
		var type:Null<ShaderParameterType> = Reflect.field(param, "type");

		// API de FlxRuntimeShader segun el tipo del uniform.
		switch (type)
		{
			case BOOL, BOOL2, BOOL3, BOOL4:
				setBoolArray(name, [for (item in list) asBool(item)]);
			case INT, INT2, INT3, INT4:
				setIntArray(name, [for (item in list) asInt(item)]);
			default:
				setFloatArray(name, [for (item in list) asFloat(item)]);
		}
		return true;
	}

	static inline function asBool(v:Dynamic):Bool
		return v == true || (Std.isOfType(v, Float) && v != 0);

	static inline function asInt(v:Dynamic):Int
		return Std.isOfType(v, Bool) ? (v ? 1 : 0) : Std.int(v);

	static inline function asFloat(v:Dynamic):Float
	{
		if (Std.isOfType(v, Bool)) return v ? 1.0 : 0.0;
		if (Std.isOfType(v, Int) || Std.isOfType(v, Float)) return cast v;
		// FlxColor/objetos con .red/.green/.blue/.alpha o valor numérico
		if (v != null && Reflect.hasField(v, "red") && Reflect.hasField(v, "green") && Reflect.hasField(v, "blue"))
			return 0; // usar setColor para colores; aqui evitamos crash
		return Std.parseFloat(Std.string(v));
	}

	/** Setea un color (vec3/vec4) como floats 0..1. */
	public function setColor(name:String, color:flixel.util.FlxColor, alpha:Bool = true):Bool
	{
		var vals = alpha ? [color.redFloat, color.greenFloat, color.blueFloat, color.alphaFloat] : [color.redFloat, color.greenFloat, color.blueFloat];
		return set(name, vals);
	}

	public function get(name:String):Dynamic
	{
		var param:Dynamic = Reflect.field(data, name);
		if (param == null) return null;
		if (Std.isOfType(param, ShaderInput)) return getSampler2D(name);
		var value:Null<Array<Dynamic>> = param.value;
		if (value == null) return null;
		return value.length == 1 ? value[0] : value;
	}

	public function hset(name:String, value:Dynamic):Void
		set(name, value);

	public function hget(name:String):Dynamic
		return get(name);
}
