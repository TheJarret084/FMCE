package funky.core;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;

/** Touch input for the menus. */
class TouchNav
{
	/** True on platforms where there is normally no keyboard. */
	public static inline var MOBILE:Bool = #if (android || ios) true #else false #end;

	/** Extra pixels around an item that still count as a hit; fingers are fat. */
	static inline var PAD:Float = 14;

	/** True on the frame any finger touches the screen. */
	public static function tapped():Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
			if (touch.justPressed) return true;
		#end
		return false;
	}

	/** True on the frame a finger touches `item` (padded). */
	public static function hit(item:FlxObject):Bool
	{
		#if FLX_TOUCH
		if (item == null || !item.exists || !item.visible) return false;
		for (touch in FlxG.touches.list)
		{
			if (!touch.justPressed) continue;
			var point = touch.getWorldPosition(FlxG.camera);
			var inside = point.x >= item.x - PAD && point.x <= item.x + item.width + PAD
				&& point.y >= item.y - PAD && point.y <= item.y + item.height + PAD;
			point.put();
			if (inside) return true;
		}
		#end
		return false;
	}

	/** Index of the row a finger just touched, or -1. */
	public static function rowTapped(rows:Array<FlxText>):Int
	{
		for (index in 0...rows.length)
			if (hit(rows[index])) return index;
		return -1;
	}

	/** A tappable text button. The caller adds it to the state and tests it with `hit`. */
	public static function button(label:String, x:Float, y:Float, width:Float = 220):FlxText
	{
		var item = new FlxText(x, y, width, label, 22);
		item.size = 22;
		item.color = 0xFFFFFFFF;
		item.alignment = FlxTextAlign.CENTER;
		item.alpha = 0.85;
		return item;
	}
}
