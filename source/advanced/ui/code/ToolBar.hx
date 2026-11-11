package advanced.ui.code;

import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

class ToolBar extends FlxSpriteGroup
{
	var buttons:Array<CodeButton> = [];
	var cursorX:Float = 10;
	var titleText:FlxText;
	var barW:Int;
	var barY:Int;

	public function new(y:Int, w:Int)
	{
		super();
		barW = w;
		barY = y;
		add(CodeDraw.rect(0, y, w, CodeTheme.TOOL_H, CodeTheme.TOOLBAR));
		add(CodeDraw.rect(0, y + CodeTheme.TOOL_H - 1, w, 1, CodeTheme.BORDER));
		titleText = CodeDraw.label(0, y + 9, "", CodeTheme.FONT_SMALL, CodeTheme.MUTED);
		add(titleText);
	}

	public function addButton(label:String, color:Int, onClick:Void->Void):CodeButton
	{
		var probe = CodeDraw.label(0, 0, label, CodeTheme.FONT_SMALL + 1);
		var w = Std.int(probe.width) + 22;
		probe.destroy();
		var b = new CodeButton(cursorX, barY + 4, w, CodeTheme.TOOL_H - 9, label, onClick, color);
		add(b);
		buttons.push(b);
		cursorX += w + 4;
		return b;
	}

	public function addSeparator():Void
	{
		cursorX += 6;
		add(CodeDraw.rect(cursorX, barY + 8, 1, CodeTheme.TOOL_H - 17, CodeTheme.BORDER));
		cursorX += 8;
	}

	public function setTitle(value:String):Void
	{
		titleText.text = value;
		titleText.x = barW - titleText.width - 14;
	}
}
