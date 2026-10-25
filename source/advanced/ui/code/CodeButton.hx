package advanced.ui.code;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

/** Boton plano con hover. El grupo esta en (x, y) y mide (bw, bh). */
class CodeButton extends FlxSpriteGroup
{
	public var onClick:Void->Void;
	public var enabled:Bool = true;
	public var toggled(default, set):Bool = false;
	public var bw(default, null):Int;
	public var bh(default, null):Int;

	var bg:FlxSprite;
	var text:FlxText;
	var textColor:Int;
	var hovered:Bool = false;

	public function new(x:Float, y:Float, w:Int, h:Int, label:String, ?onClick:Void->Void, color:Int = CodeTheme.TEXT, size:Int = CodeTheme.FONT_SMALL + 1)
	{
		super(x, y);
		bw = w;
		bh = h;
		this.onClick = onClick;
		this.textColor = color;
		bg = CodeDraw.rect(0, 0, w, h, 0xFFFFFFFF);
		bg.alpha = 0;
		add(bg);
		text = CodeDraw.label(0, 0, label, size, color);
		add(text);
		center();
	}

	public function setLabel(label:String, ?color:Int):Void
	{
		text.text = label;
		if (color != null)
		{
			textColor = color;
			text.color = color;
		}
		center();
	}

	function center():Void
	{
		text.x = x + Std.int((bw - text.width) / 2);
		text.y = y + Std.int((bh - text.height) / 2);
	}

	function set_toggled(v:Bool):Bool
	{
		toggled = v;
		refresh();
		return v;
	}

	function refresh():Void
	{
		bg.color = toggled ? CodeTheme.ACCENT : 0xFFFFFFFF;
		bg.alpha = toggled ? 0.35 : (hovered && enabled ? 0.12 : 0);
		text.color = enabled ? textColor : CodeTheme.DIM;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (!visible || !exists) return;
		var h = !CodeDraw.blocked && CodeDraw.over(x, y, bw, bh);
		if (h != hovered || text.color != (enabled ? textColor : CodeTheme.DIM))
		{
			hovered = h;
			refresh();
		}
		if (h && enabled && FlxG.mouse.justPressed && onClick != null) onClick();
	}
}
