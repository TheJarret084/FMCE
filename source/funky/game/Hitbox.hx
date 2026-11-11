package funky.game;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;

class Hitbox extends FlxSpriteGroup
{
	static inline var DOWN_ALPHA:Float = 0.75;
	static inline var DOWN_TIME:Float = 0.075;
	static inline var UP_TIME:Float = 0.1;
	static inline var HINT_ALPHA:Float = 0.2;
	static inline var GRADIENT_ROWS:Int = 128;

	public static inline var HEIGHT_RATIO:Float = 0.9;

	public var laneCount(default, null):Int;
	public var columnWidth(default, null):Float;

	public var zoneTop(default, null):Float;
	public var zoneHeight(default, null):Float;

	var glows:Array<FlxSprite> = [];
	var tweens:Array<Null<FlxTween>> = [];
	var isDown:Array<Bool> = [];

	public function new(laneCount:Int)
	{
		super();
		this.laneCount = laneCount < 1 ? 1 : laneCount;
		columnWidth = FlxG.width / this.laneCount;
		zoneHeight = Math.round(FlxG.height * HEIGHT_RATIO);
		zoneTop = FlxG.height - zoneHeight;
		scrollFactor.set();

		for (lane in 1...this.laneCount)
		{
			var line = new FlxSprite(Std.int(lane * columnWidth) - 1, zoneTop).makeGraphic(2, Std.int(zoneHeight), FlxColor.WHITE);
			line.alpha = HINT_ALPHA;
			add(line);
		}
		var top = new FlxSprite(0, zoneTop).makeGraphic(FlxG.width, 2, FlxColor.WHITE);
		top.alpha = HINT_ALPHA;
		add(top);
		var floor = new FlxSprite(0, FlxG.height - 2).makeGraphic(FlxG.width, 2, FlxColor.WHITE);
		floor.alpha = HINT_ALPHA;
		add(floor);

		for (lane in 0...this.laneCount)
		{
			var glow = new FlxSprite(Std.int(lane * columnWidth), 0);
			glow.loadGraphic(gradient(laneColor(lane)), false, 0, 0, true);

			glow.antialiasing = true;
			glow.setGraphicSize(Math.ceil(columnWidth), Std.int(zoneHeight));
			glow.updateHitbox();
			glow.setPosition(Std.int(lane * columnWidth), zoneTop);
			glow.alpha = 0;
			glows.push(glow);
			tweens.push(null);
			isDown.push(false);
			add(glow);
		}
	}

	public inline function laneAt(screenX:Float):Int
		return Std.int(Math.max(0, Math.min(laneCount - 1, Math.floor(screenX / columnWidth))));

	public function setDown(lane:Int, down:Bool):Void
	{
		if (lane < 0 || lane >= laneCount || isDown[lane] == down) return;
		isDown[lane] = down;
		var glow = glows[lane];
		if (tweens[lane] != null) tweens[lane].cancel();
		tweens[lane] = FlxTween.num(glow.alpha, down ? DOWN_ALPHA : 0, down ? DOWN_TIME : UP_TIME, {ease: FlxEase.circInOut}, function(a:Float) glow.alpha = a);
	}

	static function gradient(color:FlxColor):BitmapData
	{
		var bitmap = new BitmapData(2, GRADIENT_ROWS, true, 0x00000000);
		var rgb = color & 0xFFFFFF;
		for (row in 0...GRADIENT_ROWS)
		{
			var t = row / (GRADIENT_ROWS - 1);
			var alpha = Std.int(255 * t * t);
			bitmap.fillRect(new Rectangle(0, row, 2, 1), (alpha << 24) | rgb);
		}
		return bitmap;
	}

	static function laneColor(lane:Int):FlxColor return switch (lane % 4)
	{
		case 0: 0xFF9C70FF;
		case 1: 0xFF54B8FF;
		case 2: 0xFF62DCA5;
		default: 0xFFFF6E79;
	}

	override public function destroy():Void
	{
		for (tween in tweens) if (tween != null) tween.cancel();
		tweens = [];
		glows = [];
		super.destroy();
	}
}
