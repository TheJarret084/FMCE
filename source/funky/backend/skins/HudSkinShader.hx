package funky.backend.skins;

#if (!nme && !flash)
import flixel.addons.display.FlxRuntimeShader;
import funky.backend.system.Log;
import openfl.display.BitmapData;
import openfl.display.ShaderInput;
import openfl.display.ShaderParameterType;

@:keep
class HudSkinShader extends FlxRuntimeShader
{
	public var path:String;
	public var failed:Bool = false;

	public function new(fragSource:String, ?vertSource:String, ?name:String)
	{
		super(fragSource, vertSource);
		path = name == null ? "noteskin" : name;
		failed = fragSource == null || fragSource.length == 0;
	}

	public function has(name:String):Bool
		return Reflect.field(data, name) != null;

	public function set(name:String, value:Dynamic):Bool
	{
		var param:Dynamic = Reflect.field(data, name);
		if (param == null)
		{
			Log.warn('[HudSkinShader:$path] el uniform "$name" no existe');
			return false;
		}
		if (Std.isOfType(param, ShaderInput))
		{
			if (!Std.isOfType(value, BitmapData))
			{
				Log.warn('[HudSkinShader:$path] "$name" es un sampler2D: pasa un BitmapData');
				return false;
			}
			setSampler2D(name, cast value);
			return true;
		}
		if (Std.isOfType(value, BitmapData))
		{
			Log.warn('[HudSkinShader:$path] "$name" no es un sampler2D');
			return false;
		}
		var list:Array<Dynamic> = Std.isOfType(value, Array) ? cast value : [value];
		var type:Null<ShaderParameterType> = Reflect.field(param, "type");
		switch (type)
		{
			case BOOL, BOOL2, BOOL3, BOOL4:
				setBoolArray(name, [for (item in list) item == true || (Std.isOfType(item, Float) && item != 0)]);
			case INT, INT2, INT3, INT4:
				setIntArray(name, [for (item in list) Std.isOfType(item, Bool) ? (item ? 1 : 0) : Std.int(item)]);
			default:
				setFloatArray(name, [for (item in list) {
					var value:Float = 0;
					if (Std.isOfType(item, Bool)) value = item == true ? 1.0 : 0.0;
					else if (Std.isOfType(item, Int) || Std.isOfType(item, Float)) value = Std.parseFloat(Std.string(item));
					else value = Std.parseFloat(Std.string(item));
					value;
				}]);
		}
		return true;
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
#end
