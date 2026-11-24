package funky.backend.skins;

#if (!nme && !flash)
import flixel.FlxSprite;
import flixel.addons.display.FlxRuntimeShader;
import funky.backend.shaders.CustomShader;
import funky.backend.system.Log;

/**
 * Utilidades de shader para HUD skins.
 *
 * Los scripts de skin pueden llamar:
 *   HudShaderUtil.set(sprite, shader)  -> aplica y recuerda el shader
 *   HudShaderUtil.clear(sprite)        -> limpia el shader recordado
 *
 * `HudSkin.applyTo` llama a `restore` despues de aplicar el color de la skin,
 * asi un shader de script no se pierde cada vez que cambia el color/tint/RGB.
 */
class HudShaderUtil
{
	static var saved:Map<FlxSprite, FlxRuntimeShader> = new Map();

	public static function set(sprite:FlxSprite, shader:Dynamic):Void
	{
		if (sprite == null) return;
		if (shader == null)
		{
			clear(sprite);
			return;
		}
		if (!(Std.isOfType(shader, FlxRuntimeShader)))
		{
			Log.warn('[HudShaderUtil] shader no es FlxRuntimeShader: ' + Type.getClassName(Type.getClass(shader)));
			return;
		}
		var s:FlxRuntimeShader = cast shader;
		saved.set(sprite, s);
		sprite.shader = s;
	}

	public static function restore(sprite:FlxSprite):Void
	{
		if (sprite == null) return;
		var s = saved.get(sprite);
		if (s != null) sprite.shader = s;
	}

	public static function clear(sprite:FlxSprite):Void
	{
		if (sprite == null) return;
		saved.remove(sprite);
		sprite.shader = null;
	}

	public static function clearAll():Void
	{
		saved.clear();
	}

	public static function make(name:String, ?customFolder:String):Dynamic
	{
		if (name == null || name.length == 0) return null;
		if (customFolder != null && customFolder.length > 0)
			return new CustomShader(name, customFolder);

		var builtin = "noteskin";
		var frag = openfl.utils.Assets.exists('assets/shaders/$builtin.frag') ? openfl.utils.Assets.getText('assets/shaders/$builtin.frag') : null;
		if (frag == null) return new CustomShader(name);
		return new HudSkinShader(frag, null, name);
	}
}
#end
