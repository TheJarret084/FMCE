package funky.core;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;

class NavPad extends FlxGroup
{

	public static inline var SIZE:Float = 92;

	static inline var MARGIN:Float = 14;

	static inline var GAP:Float = 44;

	static inline var BASE_ALPHA:Float = 0.8;

	public static inline var WIDTH:Float = MARGIN + SIZE + 12;

	var up:FlxSprite;
	var down:FlxSprite;
	var onUp:Void->Void;
	var onDown:Void->Void;

	public static function make(onUp:Void->Void, onDown:Void->Void):Null<NavPad>
		return TouchNav.MOBILE ? new NavPad(onUp, onDown) : null;

	function new(onUp:Void->Void, onDown:Void->Void)
	{
		super();
		this.onUp = onUp;
		this.onDown = onDown;

		var top = topY();
		up = makeButton(true, MARGIN, top);
		down = makeButton(false, MARGIN, top + SIZE + GAP);
		add(up);
		add(down);
	}

	static inline function topY():Float
		return (FlxG.height - (SIZE * 2 + GAP)) / 2;

	static function makeButton(pointsUp:Bool, x:Float, y:Float):FlxSprite
	{
		var side = Std.int(SIZE);
		var button = new FlxSprite(x, y);
		button.makeGraphic(side, side, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(button, 2, 2, side - 4, side - 4, 28, 28, 0xE6101828, {thickness: 4, color: FlxColor.WHITE});

		var cx = side / 2;
		var cy = side / 2;
		var halfW = side * 0.26;
		var halfH = side * 0.17;
		var sign = pointsUp ? 1 : -1;
		var points = [
			FlxPoint.get(cx, cy - sign * halfH),
			FlxPoint.get(cx + halfW, cy + sign * halfH),
			FlxPoint.get(cx - halfW, cy + sign * halfH)
		];
		FlxSpriteUtil.drawPolygon(button, points, FlxColor.WHITE);
		for (point in points) point.put();

		button.scrollFactor.set(0, 0);
		button.alpha = BASE_ALPHA;
		return button;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var k = Math.min(1, elapsed * 14);
		for (button in [up, down])
		{
			button.alpha = FlxMath.lerp(button.alpha, BASE_ALPHA, k);
			button.scale.x = button.scale.y = FlxMath.lerp(button.scale.x, 1, k);
		}

		if (!visible || !exists) return;

		if (TouchNav.hit(up)) press(up, onUp);
		else if (TouchNav.hit(down)) press(down, onDown);
	}

	function press(button:FlxSprite, callback:Void->Void):Void
	{
		button.alpha = 1;
		button.scale.set(0.9, 0.9);
		callback();
	}

	public function tapped():Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
			if (touch.justPressed && covers(touch.screenX, touch.screenY)) return true;
		#end
		return false;
	}

	public function covers(screenX:Float, screenY:Float):Bool
	{
		var top = topY();
		return screenX <= MARGIN + SIZE + 14 && screenY >= top - 14 && screenY <= top + SIZE * 2 + GAP + 14;
	}
}
