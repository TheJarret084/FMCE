package advanced.ui.code;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;

private typedef TabSlot =
{
	var file:CodeStudioFile;
	var x:Float;
	var w:Float;
}

class TabBar extends FlxSpriteGroup
{
	static inline var MAX_W:Int = 230;
	static inline var MIN_W:Int = 110;

	public var onSelect:CodeStudioFile->Void;
	public var onClose:CodeStudioFile->Void;

	var barY:Int;
	var barW:Int;
	var content:FlxSpriteGroup;
	var hoverBg:FlxSprite;
	var slots:Array<TabSlot> = [];
	var tabs:Array<CodeStudioFile> = [];
	var activeFile:Null<CodeStudioFile>;
	var first:Int = 0;
	var needActiveVisible:Bool = true;

	public function new(y:Int, w:Int)
	{
		super();
		barY = y;
		barW = w;
		add(CodeDraw.rect(0, y, w, CodeTheme.TAB_H, CodeTheme.TAB_BAR));
		add(CodeDraw.rect(0, y + CodeTheme.TAB_H - 1, w, 1, CodeTheme.BORDER));
		hoverBg = CodeDraw.rect(0, y, MAX_W, CodeTheme.TAB_H - 1, 0xFFFFFFFF);
		hoverBg.alpha = 0.07;
		hoverBg.origin.set(0, 0);
		hoverBg.visible = false;
		add(hoverBg);
		content = new FlxSpriteGroup();
		add(content);
	}

	public function refresh(tabs:Array<CodeStudioFile>, current:Null<CodeStudioFile>):Void
	{
		this.tabs = tabs;
		this.activeFile = current;
		needActiveVisible = true;
		rebuild();
	}

	function tabWidth(file:CodeStudioFile):Float
	{
		var chars = Std.int(Math.min(26, file.baseName.length + (file.editable ? 0 : 5)));
		return Math.max(MIN_W, Math.min(MAX_W, chars * 8 + 56));
	}

	function rebuild():Void
	{
		for (m in content.members)
			if (m != null) m.destroy();
		content.clear();
		slots = [];
		if (tabs.length == 0) return;

		if (first >= tabs.length) first = tabs.length - 1;
		if (first < 0) first = 0;

		if (needActiveVisible && activeFile != null)
		{
			var ai = tabs.indexOf(activeFile);
			if (ai >= 0)
			{
				if (ai < first) first = ai;

				while (first < ai)
				{
					var used:Float = 0;
					for (i in first...ai + 1) used += tabWidth(tabs[i]) + 1;
					if (used <= barW - 8) break;
					first++;
				}
			}
		}
		needActiveVisible = false;

		var x:Float = 0;
		for (i in first...tabs.length)
		{
			var f = tabs[i];
			var w = tabWidth(f);
			if (x + w > barW - 4 && slots.length > 0) break;
			slots.push({file: f, x: x, w: w});
			drawTab(f, x, w);
			x += w + 1;
		}

		if (first > 0) content.add(CodeDraw.label(2, barY + 7, "‹", 16, CodeTheme.ACCENT));
		if (first + slots.length < tabs.length) content.add(CodeDraw.label(barW - 14, barY + 7, "›", 16, CodeTheme.ACCENT));
	}

	function drawTab(f:CodeStudioFile, x:Float, w:Float):Void
	{
		var isActive = f == activeFile;
		content.add(CodeDraw.rect(x, barY, w, CodeTheme.TAB_H - 1, isActive ? CodeTheme.EDITOR : CodeTheme.TAB_IDLE));
		if (isActive) content.add(CodeDraw.rect(x, barY, w, 2, CodeTheme.ACCENT));
		var name = CodeDraw.fit(f.baseName, Std.int((w - 44) / 8)) + (f.editable ? "" : " [RO]");
		content.add(CodeDraw.label(x + 12, barY + 8, name, CodeTheme.FONT_SMALL + 1, isActive ? 0xFFFFFFFF : CodeTheme.MUTED));
		if (f.dirty) content.add(CodeDraw.label(x + w - 24, barY + 6, "●", CodeTheme.FONT_SMALL + 2, CodeTheme.WARN));
		else content.add(CodeDraw.label(x + w - 22, barY + 5, "×", 18, isActive ? CodeTheme.TEXT : CodeTheme.DIM));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		hoverBg.visible = false;
		if (CodeDraw.blocked || !CodeDraw.over(0, barY, barW, CodeTheme.TAB_H)) return;

		if (FlxG.mouse.wheel != 0 && tabs.length > 0)
		{
			first = Std.int(Math.max(0, Math.min(tabs.length - 1, first - FlxG.mouse.wheel)));
			rebuild();
			return;
		}

		for (s in slots)
		{
			if (!CodeDraw.over(s.x, barY, s.w, CodeTheme.TAB_H)) continue;
			hoverBg.visible = true;
			hoverBg.x = s.x;
			hoverBg.scale.set(s.w / MAX_W, 1);
			if (FlxG.mouse.justPressedMiddle)
			{
				if (onClose != null) onClose(s.file);
			}
			else if (FlxG.mouse.justPressed)
			{
				var onX = FlxG.mouse.x >= s.x + s.w - 28;
				if (onX && onClose != null) onClose(s.file);
				else if (onSelect != null) onSelect(s.file);
			}
			break;
		}
	}
}
