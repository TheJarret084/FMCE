package funky.core;

import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;

class NoteRGBShader extends FlxShader
{

	static var cache:Map<String, NoteRGBShader> = new Map();

	public var red(default, null):FlxColor;
	public var green(default, null):FlxColor;
	public var blue(default, null):FlxColor;

	public static function forColors(colors:Array<Int>):NoteRGBShader
	{
		var key = '${colors[0]}/${colors[1]}/${colors[2]}';
		var shader = cache.get(key);
		if (shader == null)
		{
			shader = new NoteRGBShader(colors);
			cache.set(key, shader);
		}
		return shader;
	}

	@:glFragmentSource('
		#pragma header

		uniform vec3 channelR;
		uniform vec3 channelG;
		uniform vec3 channelB;

		void main()
		{
			vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

			if (color.a == 0.0)
			{
				gl_FragColor = color;
			}
			else
			{
				color.rgb = min(color.r * channelR + color.g * channelG + color.b * channelB, vec3(1.0));
				gl_FragColor = color;
			}
		}
	')
	public function new(colors:Array<Int>)
	{
		super();
		setColors(colors);
	}

	public function setColors(colors:Array<Int>):Void
	{
		red = FlxColor.fromInt(colors.length > 0 ? colors[0] : 0xFF0000);
		green = FlxColor.fromInt(colors.length > 1 ? colors[1] : 0x00FF00);
		blue = FlxColor.fromInt(colors.length > 2 ? colors[2] : 0x0000FF);
		data.channelR.value = [red.redFloat, red.greenFloat, red.blueFloat];
		data.channelG.value = [green.redFloat, green.greenFloat, green.blueFloat];
		data.channelB.value = [blue.redFloat, blue.greenFloat, blue.blueFloat];
	}

	public static function clearCache():Void
	{
		cache.clear();
	}
}
