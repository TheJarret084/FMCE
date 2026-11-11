package funkin.backend.shaders;

import flixel.addons.display.FlxRuntimeShader;
import openfl.utils.Assets;

@:keep
class CustomShader extends FlxRuntimeShader {
	public var path:String;

	public function new(name:String, ?glslVersion:String) {
		var frag:String = null, vert:String = null;
		var fragPath = 'assets/shaders/$name.frag', vertPath = 'assets/shaders/$name.vert';
		if (Assets.exists(fragPath)) frag = Assets.getText(fragPath);
		if (Assets.exists(vertPath)) vert = Assets.getText(vertPath);
		path = name;
		super(frag, vert);
	}

	public function hset(name:String, value:Dynamic):Void {
		var param:Dynamic = Reflect.field(data, name);
		if (param == null) return;
		param.value = (value is Array) ? value : [value];
	}

	public function hget(name:String):Dynamic {
		var param:Dynamic = Reflect.field(data, name);
		return param == null ? null : param.value;
	}
}
