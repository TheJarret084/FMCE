package advanced.ui.code;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;

/** Helpers para dibujar y para saber donde esta el mouse. */
class CodeDraw
{
	/** true mientras hay un menu abierto: el resto de la UI ignora el mouse. */
	public static var blocked:Bool = false;

	public static function rect(x:Float, y:Float, w:Float, h:Float, color:Int):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(Std.int(Math.max(1, w)), Std.int(Math.max(1, h)), color);
		s.scrollFactor.set(0, 0);
		return s;
	}

	public static function remake(s:FlxSprite, w:Float, h:Float, color:Int):Void
		s.makeGraphic(Std.int(Math.max(1, w)), Std.int(Math.max(1, h)), color);

	public static function label(x:Float, y:Float, value:String, size:Int = CodeTheme.FONT, color:Int = CodeTheme.TEXT, width:Float = 0):FlxText
	{
		var t = new FlxText(Std.int(x), Std.int(y), width, value, size);
		var f = CodeTheme.fontPath();
		if (f != null) t.font = f;
		t.color = color;
		t.scrollFactor.set(0, 0);
		return t;
	}

	public static inline function over(x:Float, y:Float, w:Float, h:Float):Bool
		return FlxG.mouse.x >= x && FlxG.mouse.x < x + w && FlxG.mouse.y >= y && FlxG.mouse.y < y + h;

	/** Recorta con "…" si no entra en `maxChars` caracteres. */
	public static function fit(value:String, maxChars:Int):String
	{
		if (value.length <= maxChars) return value;
		return value.substr(0, Std.int(Math.max(1, maxChars - 1))) + "…";
	}
}
