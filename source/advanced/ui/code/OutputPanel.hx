package advanced.ui.code;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

private typedef LogLine =
{
	var text:String;
	var color:Int;
}

class OutputPanel extends FlxSpriteGroup
{
	static inline var LINE_H:Int = 18;
	static inline var MAX_LINES:Int = 400;

	public var onToggle:Void->Void;
	public var collapsed(default, null):Bool = false;
	public var fullHeight(default, null):Int;

	var px:Int;
	var py:Int;
	var pw:Int;
	var body:Array<FlxSprite> = [];
	var pool:Array<FlxText> = [];
	var lines:Array<LogLine> = [];
	var capacity:Int;
	var fromBottom:Int = 0;
	var toggleButton:CodeButton;
	var clearButton:CodeButton;

	public function new(x:Int, y:Int, w:Int, h:Int)
	{
		super();
		px = x;
		py = y;
		pw = w;
		fullHeight = h;
		capacity = Std.int((h - CodeTheme.PANEL_HEAD_H - 6) / LINE_H);

		var bodyBg = CodeDraw.rect(x, y + CodeTheme.PANEL_HEAD_H, w, h - CodeTheme.PANEL_HEAD_H, CodeTheme.PANEL);
		add(bodyBg);
		body.push(bodyBg);
		add(CodeDraw.rect(x, y, w, CodeTheme.PANEL_HEAD_H, CodeTheme.MENU));
		add(CodeDraw.rect(x, y, w, 1, CodeTheme.BORDER));
		add(CodeDraw.label(x + 14, y + 6, CodeLang.t("output.title", null, "SALIDA"), CodeTheme.FONT_SMALL, 0xFFFFFFFF));
		add(CodeDraw.rect(x + 12, y + CodeTheme.PANEL_HEAD_H - 2, 52, 2, CodeTheme.ACCENT));

		clearButton = new CodeButton(x + w - 120, y + 2, 76, 22, CodeLang.t("output.clear", null, "Limpiar"), clearLog, CodeTheme.MUTED, CodeTheme.FONT_SMALL);
		add(clearButton);
		toggleButton = new CodeButton(x + w - 38, y + 2, 28, 22, "▼", function() setCollapsed(!collapsed), CodeTheme.MUTED, CodeTheme.FONT_SMALL);
		add(toggleButton);

		for (i in 0...capacity)
		{
			var t = CodeDraw.label(x + 14, y + CodeTheme.PANEL_HEAD_H + 4 + i * LINE_H, "", CodeTheme.FONT_SMALL + 1, CodeTheme.TEXT, w - 36);
			t.wordWrap = false;
			add(t);
			pool.push(t);
		}
	}

	public function log(message:String, color:Int = CodeTheme.TEXT):Void
	{
		lines.push({text: message, color: color});
		while (lines.length > MAX_LINES) lines.shift();
		if (fromBottom > 0) fromBottom = Std.int(Math.min(fromBottom + 1, Math.max(0, lines.length - capacity)));
		redraw();
	}

	public function clearLog():Void
	{
		lines = [];
		fromBottom = 0;
		redraw();
	}

	public function setCollapsed(value:Bool):Int
	{
		if (collapsed == value) return currentHeight();
		collapsed = value;
		var dy = value ? fullHeight - CodeTheme.PANEL_HEAD_H : -(fullHeight - CodeTheme.PANEL_HEAD_H);
		y += dy;
		py += dy;
		for (t in pool) t.visible = !value;
		for (s in body) s.visible = !value;
		toggleButton.setLabel(value ? "▲" : "▼");
		clearButton.visible = !value;
		if (!value) redraw();
		if (onToggle != null) onToggle();
		return currentHeight();
	}

	public function currentHeight():Int
		return collapsed ? CodeTheme.PANEL_HEAD_H : fullHeight;

	function redraw():Void
	{
		if (collapsed) return;
		var start = Std.int(Math.max(0, lines.length - capacity - fromBottom));
		for (i in 0...capacity)
		{
			var t = pool[i];
			var idx = start + i;
			if (idx < lines.length)
			{
				t.text = lines[idx].text;
				t.color = lines[idx].color;
			}
			else
				t.text = "";
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (collapsed || CodeDraw.blocked) return;
		if (FlxG.mouse.wheel != 0 && CodeDraw.over(px, py + CodeTheme.PANEL_HEAD_H, pw, fullHeight - CodeTheme.PANEL_HEAD_H))
		{
			var maxFrom = Std.int(Math.max(0, lines.length - capacity));
			fromBottom = Std.int(Math.max(0, Math.min(maxFrom, fromBottom + FlxG.mouse.wheel * 2)));
			redraw();
		}
	}
}
