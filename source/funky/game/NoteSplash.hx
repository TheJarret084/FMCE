package funky.game;

import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funky.core.NoteSkin;

class NoteSplash extends FlxSprite
{

	static inline var POP_SCALE:Float = 1.6;
	static inline var POP_TIME:Float = 0.3;

	public function new()
	{
		super();
		kill();
	}

	public function burst(skin:NoteSkin, lane:Int, laneCount:Int, strum:Strum):Void
	{
		FlxTween.cancelTweensOf(this);
		FlxTween.cancelTweensOf(scale);
		revive();

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

		skin.applyTo(this, lane, false, laneCount);

		skin.notify("onSplashCreate", "onSplash", [this, lane]);

		setPosition(strum.x + strum.width * 0.5 - frameWidth * 0.5, strum.y + strum.height * 0.5 - frameHeight * 0.5);
	}
}
