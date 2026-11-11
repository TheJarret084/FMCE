package advanced.ui.code;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

typedef MenuItem =
{
	var label:String;
	@:optional var shortcut:String;
	@:optional var action:Void->Void;
	@:optional var separator:Bool;
	@:optional var disabled:Bool;
}

typedef MenuDef =
{
	var title:String;

	var items:Void->Array<MenuItem>;
}

private typedef DropRow =
{
	var y:Float;
	var h:Float;
	var item:MenuItem;
}

class MenuBar extends FlxSpriteGroup
{
	static inline var ITEM_H:Int = 24;
	static inline var SEP_H:Int = 9;

	public var onOpen:Void->Void;
	public var onClose:Void->Void;
	public var isOpen(get, never):Bool;

	var defs:Array<MenuDef>;
	var titleX:Array<Float> = [];
	var titleW:Array<Float> = [];
	var titleBar:FlxSpriteGroup;
	var hoverBg:FlxSprite;
	var drop:FlxSpriteGroup;
	var dropHover:FlxSprite;
	var rows:Array<DropRow> = [];
	var openIndex:Int = -1;
	var dropX:Float = 0;
	var dropY:Float = CodeTheme.MENU_H;
	var dropW:Float = 0;
	var dropH:Float = 0;

	public function new(defs:Array<MenuDef>, w:Int)
	{
		super();
		this.defs = defs;

		titleBar = new FlxSpriteGroup();
		add(titleBar);
		titleBar.add(CodeDraw.rect(0, 0, w, CodeTheme.MENU_H, CodeTheme.MENU));
		titleBar.add(CodeDraw.rect(0, CodeTheme.MENU_H - 1, w, 1, CodeTheme.BORDER));
		hoverBg = CodeDraw.rect(0, 0, 10, CodeTheme.MENU_H - 1, CodeTheme.HOVER);
		hoverBg.visible = false;
		titleBar.add(hoverBg);

		var brand = CodeDraw.label(12, 6, "FMCE", CodeTheme.FONT, CodeTheme.ACCENT);
		titleBar.add(brand);
		var cx:Float = 12 + brand.width + 18;
		for (def in defs)
		{
			var t = CodeDraw.label(0, 6, def.title, CodeTheme.FONT_SMALL + 1, CodeTheme.TEXT);
			titleX.push(cx);
			titleW.push(t.width + 20);
			t.x = cx + 10;
			titleBar.add(t);
			cx += t.width + 20;
		}

		drop = new FlxSpriteGroup();
		drop.visible = false;
		add(drop);
		dropHover = CodeDraw.rect(0, 0, 10, ITEM_H, CodeTheme.SELECT);
	}

	function get_isOpen():Bool
		return openIndex >= 0;

	public function open(index:Int):Void
	{
		if (index < 0 || index >= defs.length) return;
		var wasOpen = isOpen;
		openIndex = index;
		build();
		hoverBg.visible = true;
		hoverBg.x = titleX[index];
		hoverBg.scale.set(titleW[index] / 10, 1);
		hoverBg.updateHitbox();
		hoverBg.x = titleX[index];
		if (!wasOpen)
		{
			CodeDraw.blocked = true;
			if (onOpen != null) onOpen();
		}
	}

	public function close():Void
	{
		if (!isOpen) return;
		openIndex = -1;
		drop.visible = false;
		hoverBg.visible = false;
		CodeDraw.blocked = false;
		if (onClose != null) onClose();
	}

	function build():Void
	{
		for (m in drop.members)
			if (m != null) m.destroy();
		drop.clear();
		rows = [];

		var items = defs[openIndex].items();
		var labels:Array<FlxText> = [];
		var shorts:Array<Null<FlxText>> = [];
		var width:Float = 220;
		for (item in items)
		{
			if (item.separator == true)
			{
				labels.push(null);
				shorts.push(null);
				continue;
			}
			var l = CodeDraw.label(0, 0, item.label, CodeTheme.FONT_SMALL + 1, item.disabled == true ? CodeTheme.DIM : CodeTheme.TEXT);
			var s:Null<FlxText> = item.shortcut != null ? CodeDraw.label(0, 0, item.shortcut, CodeTheme.FONT_SMALL, CodeTheme.MUTED) : null;
			width = Math.max(width, l.width + (s != null ? s.width : 0) + 64);
			labels.push(l);
			shorts.push(s);
		}

		dropX = titleX[openIndex];
		dropY = CodeTheme.MENU_H;
		dropW = Math.min(width, FlxG.width - dropX - 4);
		var y:Float = dropY + 4;
		for (i in 0...items.length)
		{
			var h = items[i].separator == true ? SEP_H : ITEM_H;
			rows.push({y: y, h: h, item: items[i]});
			y += h;
		}
		dropH = y - dropY + 4;

		drop.add(CodeDraw.rect(dropX + 4, dropY + 4, dropW, dropH, 0xFF000000)).alpha = 0.35;
		drop.add(CodeDraw.rect(dropX - 1, dropY, dropW + 2, dropH + 1, CodeTheme.BORDER));
		drop.add(CodeDraw.rect(dropX, dropY, dropW, dropH, CodeTheme.MENU));
		dropHover.visible = false;
		drop.add(dropHover);

		for (i in 0...items.length)
		{
			var r = rows[i];
			if (items[i].separator == true)
			{
				drop.add(CodeDraw.rect(dropX + 8, r.y + 4, dropW - 16, 1, CodeTheme.BORDER));
				continue;
			}
			var l = labels[i];
			l.x = dropX + 16;
			l.y = r.y + 4;
			drop.add(l);
			var s = shorts[i];
			if (s != null)
			{
				s.x = dropX + dropW - 16 - s.width;
				s.y = r.y + 5;
				drop.add(s);
			}
		}
		drop.visible = true;
	}

	function rowAt(mx:Float, my:Float):Null<DropRow>
	{
		if (mx < dropX || mx >= dropX + dropW) return null;
		for (r in rows)
			if (my >= r.y && my < r.y + r.h) return r;
		return null;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;

		var hover = -1;
		if (my >= 0 && my < CodeTheme.MENU_H)
			for (i in 0...defs.length)
				if (mx >= titleX[i] && mx < titleX[i] + titleW[i]) hover = i;

		if (!isOpen)
		{
			hoverBg.visible = hover >= 0;
			if (hover >= 0)
			{
				hoverBg.scale.set(titleW[hover] / 10, 1);
				hoverBg.updateHitbox();
				hoverBg.x = titleX[hover];
				hoverBg.y = 0;
			}
			if (hover >= 0 && FlxG.mouse.justPressed) open(hover);
			return;
		}

		if (hover >= 0 && hover != openIndex) open(hover);

		var row = rowAt(mx, my);
		if (row != null && row.item.separator != true && row.item.disabled != true)
		{
			dropHover.visible = true;
			dropHover.x = dropX + 2;
			dropHover.y = row.y;
			dropHover.scale.set((dropW - 4) / 10, row.h / ITEM_H);
			dropHover.updateHitbox();
			dropHover.x = dropX + 2;
			dropHover.y = row.y;
		}
		else
			dropHover.visible = false;

		if (FlxG.mouse.justPressed)
		{
			if (hover == openIndex) close();
			else if (row != null)
			{
				if (row.item.separator != true && row.item.disabled != true)
				{
					var action = row.item.action;
					close();
					if (action != null) action();
				}
			}
			else if (hover < 0)
				close();
		}
	}
}
