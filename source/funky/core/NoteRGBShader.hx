package funky.core;

import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;

/** Tinte RGB por canales para notas y receptores. */
class NoteRGBShader extends FlxShader
{
	/**
	 * Una instancia por color. El numero de combinaciones esta acotado por las lanes
	 * (9 como maximo, x2 estados presionado/reposo), asi que la cache no crece sin control.
	 */
	static var cache:Map<String, NoteRGBShader> = new Map();

	/** Que se le suma al canal rojo, al verde y al azul respectivamente. */
	public var red(default, null):FlxColor;
	public var green(default, null):FlxColor;
	public var blue(default, null):FlxColor;

	/**
	 * Devuelve el shader de `colors` = `[r, g, b]`, creandolo la primera vez.
	 * Todas las notas de una lane comparten la misma instancia.
	 */
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

	/** Libera la cache. El juego no lo necesita, pero el editor si al cambiar de nivel. */
	public static function clearCache():Void
	{
		cache.clear();
	}
}
