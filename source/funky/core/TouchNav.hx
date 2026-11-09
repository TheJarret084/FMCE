package funky.core;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;

/** Entrada de puntero para los menus: el DEDO (celular) y el MOUSE (PC) se tratan igual. */
class TouchNav
{
	/** True on platforms where there is normally no keyboard. */
	public static inline var MOBILE:Bool = #if (android || ios) true #else false #end;

	/** Extra pixels around an item that still count as a hit; fingers are fat. Con mouse el margen es la mitad. */
	static inline var PAD:Float = 14;

	static final point:FlxPoint = FlxPoint.get();

	/**
	 * Si un dedo o el mouse se apoyo en este frame, guarda su posicion de pantalla en `out` y devuelve true.
	 * (El primero que se encuentre; con dos dedos a la vez se atiende uno por frame.)
	 */
	public static function pressedAt(out:FlxPoint):Bool
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (!touch.justPressed) continue;
			out.set(touch.screenX, touch.screenY);
			return true;
		}
		#end
		#if FLX_MOUSE
		if (FlxG.mouse.enabled && FlxG.mouse.justPressed)
		{
			out.set(FlxG.mouse.screenX, FlxG.mouse.screenY);
			return true;
		}
		#end
		return false;
	}

	/** Igual que `pressedAt` pero con un punto nuevo (del pool): quien lo pide debe hacer `put()`. null si nadie toco. */
	public static function pressPoint():Null<FlxPoint>
	{
		var out = FlxPoint.get();
		if (pressedAt(out)) return out;
		out.put();
		return null;
	}

	/** True on the frame any finger touches the screen or the mouse is clicked. */
	public static function tapped():Bool
		return pressedAt(point);

	/** True si el punto de pantalla (px, py) cae sobre `item` (con `pad` px de margen por cada lado). */
	public static function contains(item:FlxObject, px:Float, py:Float, pad:Float = PAD):Bool
	{
		if (item == null || !item.exists || !item.visible) return false;

		var cam = item.camera != null ? item.camera : FlxG.camera;
		var left = item.x - cam.scroll.x * item.scrollFactor.x;
		var top = item.y - cam.scroll.y * item.scrollFactor.y;
		return px >= left - pad && px <= left + item.width + pad && py >= top - pad && py <= top + item.height + pad;
	}

	/** True on the frame a finger touches (or the mouse clicks) `item` (padded). */
	public static function hit(item:FlxObject):Bool
	{
		if (item == null || !pressedAt(point)) return false;
		return contains(item, point.x, point.y, MOBILE ? PAD : PAD * 0.5);
	}

	/** True mientras el mouse esta encima de `item` (solo PC: en el celular no hay mouse). Sirve para iluminar botones. */
	public static function over(item:FlxObject):Bool
	{
		#if (FLX_MOUSE && !(android || ios))
		if (item == null || !FlxG.mouse.visible) return false;
		return contains(item, FlxG.mouse.screenX, FlxG.mouse.screenY, 0);
		#else
		return false;
		#end
	}

	/** Index of the row a finger (or the mouse) just pressed, or -1. */
	public static function rowTapped(rows:Array<FlxText>):Int
	{
		if (!pressedAt(point)) return -1;
		for (index in 0...rows.length)
			if (contains(rows[index], point.x, point.y, MOBILE ? PAD : PAD * 0.5)) return index;
		return -1;
	}

	/** A tappable text button. The caller adds it to the state and tests it with `hit`. (Para botones nuevos usa `MenuButton`.) */
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
