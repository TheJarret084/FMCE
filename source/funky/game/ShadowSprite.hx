package funky.game;

import flixel.FlxSprite;
import funky.backend.skins.HudSkin;

/** FlxSprite que dibuja la sombra de la skin (se usa para el sprite de confirm de los receptores). */
class ShadowSprite extends FlxSprite
{
	var shadowSkin:Null<HudSkin>;

	public function new(x:Float, y:Float, skin:Null<HudSkin>)
	{
		super(x, y);
		shadowSkin = skin;
	}

	override public function draw():Void
	{
		if (SpriteShadow.active(shadowSkin, this))
		{
			SpriteShadow.enter(this, shadowSkin);
			super.draw();
			SpriteShadow.leave(this);
		}
		super.draw();
	}
}
