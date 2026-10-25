package advanced.ui.code;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/** Barra azul de abajo: estado a la izquierda; linea, columna y tipo de archivo a la derecha. */
class StatusBar extends FlxSpriteGroup
{
	var bg:FlxSprite;
	var left:FlxText;
	var segments:Array<FlxText> = [];
	var barY:Int;
	var barW:Int;
	var caretText:String = "";
	var kindText:String = "";
	var extraText:String = "";
	var hasError:Bool = false;

	public function new(y:Int, w:Int)
	{
		super();
		barY = y;
		barW = w;
		bg = CodeDraw.rect(0, y, w, CodeTheme.STATUS_H, CodeTheme.STATUS);
		add(bg);
		left = CodeDraw.label(12, y + 5, "Listo", CodeTheme.FONT_SMALL, 0xFFFFFFFF);
		add(left);
		for (i in 0...3)
		{
			var t = CodeDraw.label(0, y + 5, "", CodeTheme.FONT_SMALL, 0xFFFFFFFF);
			segments.push(t);
			add(t);
		}
	}

	/** Mensaje de la izquierda. `error` pone la barra naranja como VS cuando hay problemas. */
	public function setMessage(value:String, error:Bool = false):Void
	{
		left.text = CodeDraw.fit(value, Std.int((barW - 420) / 7.5));
		hasError = error;
		bg.color = error ? CodeTheme.STATUS_ERROR : CodeTheme.STATUS;
	}

	public function setCaret(line:Int, col:Int, selected:Int):Void
	{
		caretText = "Ln " + line + ", Col " + col + (selected > 0 ? " (" + selected + " sel)" : "");
		layoutRight();
	}

	public function setFileInfo(kind:String, extra:String):Void
	{
		kindText = kind;
		extraText = extra;
		layoutRight();
	}

	function layoutRight():Void
	{
		var texts = [caretText, "Espacios: 4", kindText + (extraText != "" ? "  " + extraText : "")];
		var x:Float = barW - 12;
		var i = texts.length - 1;
		while (i >= 0)
		{
			var t = segments[i];
			t.text = texts[i];
			x -= t.width;
			t.x = x;
			t.y = barY + 5;
			x -= 22;
			i--;
		}
	}
}
