package funky.game;

import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funky.core.NoteSkin;

/** Splash al acertar una nota (SICK). */
class NoteSplash extends FlxSprite
{
	/** Cuanto crece (x) la flecha cuando se usa de splash. */
	static inline var POP_SCALE:Float = 1.6;
	static inline var POP_TIME:Float = 0.3;

	public function new()
	{
		super();
		kill();
	}

	/** @param strum receptor sobre el que sale: da el centro y la escala (la misma que su confirm). */
	public function burst(skin:NoteSkin, lane:Int, laneCount:Int, strum:Strum):Void
	{
		FlxTween.cancelTweensOf(this);
		FlxTween.cancelTweensOf(scale);
		revive();

		// Atlas de splash aparte si el skin lo trae; si no, el principal.
		var splashAtlas = skin.splashFrames();
		var atlas = splashAtlas != null ? splashAtlas : skin.frames();
		if (atlas == null)
		{
			kill();
			return;
		}

		frames = atlas;
		animation.destroyAnimations();
		animation.finishCallback = null;

		var base = strum.scale.x * skin.splashScale;
		scale.set(base, base);
		alpha = skin.splashAlpha;

		animation.addByPrefix("splash", skin.animFor("splash", lane), skin.splashFps, false);
		if (!animation.exists("splash") && splashAtlas != null && skin.frames() != null)
		{
			// el atlas aparte no trae esa animacion: se intenta con el principal
			frames = skin.frames();
			animation.destroyAnimations();
			animation.addByPrefix("splash", skin.animFor("splash", lane), skin.splashFps, false);
		}

		if (animation.exists("splash"))
		{
			animation.finishCallback = function(_) kill();
			animation.play("splash", true);
		}
		else
		{
			// sin animacion de splash: la flecha de la nota (atlas principal), que crece y se desvanece
			if (skin.frames() != null) frames = skin.frames();
			animation.destroyAnimations();
			animation.addByPrefix("pop", skin.animFor("note", lane), 24, false);
			if (!animation.exists("pop"))
			{
				kill();
				return;
			}

			animation.play("pop", true);
			FlxTween.tween(scale, {x: base * POP_SCALE, y: base * POP_SCALE}, POP_TIME, {ease: FlxEase.quadOut});
			FlxTween.tween(this, {alpha: 0}, POP_TIME, {ease: FlxEase.quadIn, onComplete: function(_) kill()});
		}

		// igual que las notas: shader RGB / tinte / nada segun el type del skin
		skin.applyTo(this, lane, false, laneCount);

		// Script del skin (si trae).
		skin.notify("onSplashCreate", "onSplash", [this, lane]);

		// sin updateHitbox: el origen es el centro del frame, asi que se coloca por el centro y crece desde ahi
		setPosition(strum.x + strum.width * 0.5 - frameWidth * 0.5, strum.y + strum.height * 0.5 - frameHeight * 0.5);
	}
}
