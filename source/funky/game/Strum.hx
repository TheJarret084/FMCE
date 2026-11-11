package funky.game;

import flixel.FlxG;
import flixel.FlxSprite;
import funky.core.ClientPrefs;
import funky.core.NoteRGBShader;
import funky.core.NoteSkin;

class Strum extends FlxSprite
{
	public var lane(default, null):Int;
	public var laneCount(default, null):Int;
	public var lastHit:Float = -5000;

	var skin:NoteSkin;

	var rgbPressed:Null<Bool> = null;

	var holding:Bool = false;

	var pressFactor:Float = 1;

	static inline var PRESS_SCALE_SPEED:Float = 30;

	public var confirmSprite(default, null):Null<FlxSprite>;

	public function new(lane:Int, x:Float, y:Float, slotWidth:Float = 110, laneCount:Int = 4)
	{
		super(x, y);
		this.lane = lane;
		this.laneCount = laneCount;
		skin = NoteSkin.current();

		var atlas = skin.frames();
		if (atlas != null)
		{
			frames = atlas;
			animation.addByPrefix("static", skin.animFor("receptor", lane), 24, false);
			animation.addByPrefix("pressed", skin.animFor("press", lane), 24, false);
			animation.play("static");
		}
		else makeGraphic(100, 100, 0xFF888888);

		setGraphicSize(Std.int(slotWidth), 0);
		updateHitbox();
		alpha = ClientPrefs.getStrumAlpha();
		applyColor(false);

		if (atlas != null)
		{
			confirmSprite = new FlxSprite(x, y);
			confirmSprite.frames = atlas;
			confirmSprite.animation.addByPrefix("confirm", skin.animFor("confirm", lane), 24, false);

			confirmSprite.scale.set(scale.x, scale.y);
			confirmSprite.updateHitbox();
			confirmSprite.alpha = ClientPrefs.getStrumAlpha();

			skin.applyTo(confirmSprite, lane, true, laneCount);
			confirmSprite.visible = false;
		}

		skin.notify("onReceptorCreate", "onReceptor", [this, lane]);
		if (confirmSprite != null) skin.notify("onConfirmCreate", "onConfirm", [confirmSprite, lane]);
	}

	function applyColor(pressed:Bool):Void
	{
		if (pressed == rgbPressed) return;
		rgbPressed = pressed;

		switch (skin.type)
		{
			case SPARROW:
				shader = null;
			case TINT:

				shader = null;
				color = pressed ? skin.tintFor(lane, true, laneCount) : skin.restTintFor(lane, laneCount);
			case RGB:
				var colors = pressed ? skin.rgbFor(lane, true, laneCount) : ClientPrefs.idleRgb();
				shader = colors == null ? null : NoteRGBShader.forColors(colors);
		}

		skin.notify("onReceptorColor", null, [this, lane, pressed]);
	}

	function updatePressScale(active:Bool):Void
	{
		var target = active ? skin.pressedScale : 1;
		if (pressFactor == target) return;

		var next = pressFactor + (target - pressFactor) * Math.min(1, FlxG.elapsed * PRESS_SCALE_SPEED);
		if (Math.abs(target - next) < 0.002) next = target;

		var ratio = next / pressFactor;
		scale.x *= ratio;
		scale.y *= ratio;
		if (confirmSprite != null)
		{
			confirmSprite.scale.x *= ratio;
			confirmSprite.scale.y *= ratio;
		}
		pressFactor = next;
	}

	public function updateInput(pressed:Bool, justPressed:Bool):Void
	{
		applyColor(pressed);
		if (skin.pressedScale != 1 || pressFactor != 1)
			updatePressScale(pressed || (confirmSprite != null && confirmSprite.visible));
		if (animation.numFrames > 0 || animation.getNameList().length > 0) animation.play(pressed ? "pressed" : "static");
		if (confirmSprite != null)
		{

			if (confirmSprite.animation.finished && !holding) confirmSprite.visible = false;
			holding = false;
			syncConfirm();

			visible = !confirmSprite.visible;
		}
	}

	function syncConfirm():Void
	{
		confirmSprite.updateHitbox();
		confirmSprite.setPosition(x + (width - confirmSprite.width) * 0.5, y + (height - confirmSprite.height) * 0.5);
	}

	public function confirm(songTime:Float, restart:Bool = true):Void
	{
		lastHit = songTime;
		if (confirmSprite == null) return;
		confirmSprite.alpha = ClientPrefs.getStrumAlpha();
		if (restart || !confirmSprite.visible)
			confirmSprite.animation.play("confirm", true);
		else
			holding = true;
		confirmSprite.visible = true;
		visible = false;
		syncConfirm();
	}
}
