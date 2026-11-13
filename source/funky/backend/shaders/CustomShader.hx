package funky.backend.shaders;

import flixel.addons.display.FlxRuntimeShader;
import funky.core.Addons;
import funky.core.Log;
import openfl.display.BitmapData;
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

		if (Std.isOfType(value, BitmapData))
		{
			if (Reflect.hasField(param, "input"))
			{
				param.input = cast(value, BitmapData);
				return true;
			}
			Log.warn('[CustomShader:$path] "$name" no es un sampler2D');
			return false;
		}

		if (!Reflect.hasField(param, "value"))
		{
			Log.warn('[CustomShader:$path] "$name" es un sampler2D: pasa un BitmapData');
			return false;
		}

		var list:Array<Dynamic> = Std.isOfType(value, Array) ? cast value : [value];
		var type:Null<ShaderParameterType> = Reflect.field(param, "type");
		var out:Array<Dynamic> = [];
		for (item in list)
		{
			if (type == null) out.push(item);
			else switch (type)
			{
				case BOOL, BOOL2, BOOL3, BOOL4:
					out.push(item == true || (Std.isOfType(item, Float) && item != 0));
				case INT, INT2, INT3, INT4:
					out.push(Std.isOfType(item, Bool) ? (item ? 1 : 0) : Std.int(item));
				default:
					out.push(Std.isOfType(item, Bool) ? (item ? 1.0 : 0.0) : item);
			}
		}
		param.value = out;
		return true;
	}

	public function get(name:String):Dynamic
	{
		var param:Dynamic = Reflect.field(data, name);
		if (param == null) return null;
		if (Reflect.hasField(param, "input")) return param.input;
		var value:Null<Array<Dynamic>> = param.value;
		if (value == null) return null;
		return value.length == 1 ? value[0] : value;
	}

	public function hset(name:String, value:Dynamic):Void
		set(name, value);

	public function hget(name:String):Dynamic
		return get(name);
}
