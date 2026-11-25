package funky.game;

import flixel.FlxSprite;
import funky.backend.skins.HudSkin;
#if (!nme && !flash)
import flixel.system.FlxAssets.FlxShader;
#end

/**
 * Sombra simple: se dibuja el mismo sprite una vez mas, un poco mas abajo, teñido y con menos alpha.
 * Se configura en hudSkin.xml con <shadow x="" y="" alpha="" color=""/> (x e y son fracciones del ancho del sprite).
 * Sin shaders: no rompe el batching y no cuesta casi nada en celular.
 *
 * Uso (dentro de draw): if (SpriteShadow.active(skin, this)) { SpriteShadow.enter(this, skin); super.draw(); SpriteShadow.leave(this); }
 * El estado se guarda en estaticos porque draw() nunca se anida.
 */
class SpriteShadow
{
	static var savedX:Float = 0;
	static var savedY:Float = 0;
	static var savedAlpha:Float = 1;
	static var savedColor:Int = 0xFFFFFFFF;
	#if (!nme && !flash)
	static var savedShader:Null<FlxShader> = null;
	#end

	public static inline function active(skin:Null<HudSkin>, sprite:FlxSprite):Bool
		return skin != null && skin.shadowEnabled && sprite.visible && sprite.alpha > 0;

	public static function enter(sprite:FlxSprite, skin:HudSkin):Void
	{
		savedX = sprite.x;
		savedY = sprite.y;
		savedAlpha = sprite.alpha;
		savedColor = sprite.color;
		#if (!nme && !flash)
		savedShader = sprite.shader;
		sprite.shader = null;
		#end

		var w = sprite.width;
		sprite.x = savedX + w * skin.shadowX;
		sprite.y = savedY + w * skin.shadowY;
		sprite.color = skin.shadowColor;
		sprite.alpha = savedAlpha * skin.shadowAlpha;
	}

	public static function leave(sprite:FlxSprite):Void
	{
		sprite.x = savedX;
		sprite.y = savedY;
		sprite.color = savedColor;
		sprite.alpha = savedAlpha;
		#if (!nme && !flash)
		sprite.shader = savedShader;
		savedShader = null;
		#end
	}
}
