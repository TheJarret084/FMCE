package advanced.ui.code;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

private typedef TreeNode =
{
	var name:String;
	var path:String;
	var depth:Int;
	var folder:Bool;
	var file:Null<CodeStudioFile>;
	var children:Array<TreeNode>;
}

private typedef RowSlot =
{
	var arrow:FlxText;
	var badge:FlxText;
	var name:FlxText;
	var tail:FlxText;
}

class FileTree extends FlxSpriteGroup
{
	public var onOpen:CodeStudioFile->Void;
	public var onNewScript:Void->Void;

	var tx:Int;
	var ty:Int;
	var tw:Int;
	var th:Int;
	var headerY:Int;
	var rowsY:Int;
	var capacity:Int;
	var slots:Array<RowSlot> = [];
	var flat:Array<TreeNode> = [];
	var root:Null<TreeNode>;
	var collapsed:Map<String, Bool> = new Map();
	var files:Array<CodeStudioFile> = [];
	var activeFile:Null<CodeStudioFile>;
	var scroll:Int = 0;
	var selBar:FlxSprite;
	var hoverBar:FlxSprite;
	var thumb:FlxSprite;
	var titleText:FlxText;
	var emptyText:FlxText;

	public function new(x:Int, y:Int, w:Int, h:Int)
	{
		super();
		tx = x;
		ty = y;
		tw = w;
		th = h;
		headerY = y;
		rowsY = y + CodeTheme.PANEL_HEAD_H + 2;
		capacity = Std.int((h - CodeTheme.PANEL_HEAD_H - 4) / CodeTheme.ROW_H);

		add(CodeDraw.rect(x, y, w, h, CodeTheme.PANEL));
		add(CodeDraw.rect(x, y, 1, h, CodeTheme.BORDER));
		add(CodeDraw.rect(x, y, w, CodeTheme.PANEL_HEAD_H, CodeTheme.MENU));
		add(CodeDraw.rect(x, y + CodeTheme.PANEL_HEAD_H - 1, w, 1, CodeTheme.BORDER));
		titleText = CodeDraw.label(x + 12, y + 6, "EXPLORADOR", CodeTheme.FONT_SMALL, CodeTheme.MUTED);
		add(titleText);
		add(new CodeButton(x + w - 30, y + 2, 24, 22, "+", function()
		{
			if (onNewScript != null) onNewScript();
		}, CodeTheme.ACCENT, 18));

		selBar = CodeDraw.rect(x + 1, rowsY, w - 1, CodeTheme.ROW_H, CodeTheme.SELECT);
		selBar.visible = false;
		add(selBar);
		hoverBar = CodeDraw.rect(x + 1, rowsY, w - 1, CodeTheme.ROW_H, 0xFFFFFFFF);
		hoverBar.alpha = 0.06;
		hoverBar.visible = false;
		add(hoverBar);
		thumb = CodeDraw.rect(x + w - 5, rowsY, 3, 20, CodeTheme.DIM);
		thumb.visible = false;
		add(thumb);

		for (i in 0...capacity)
		{
			var yy = rowsY + i * CodeTheme.ROW_H + 3;
			var s:RowSlot = {
				arrow: CodeDraw.label(0, yy, "", CodeTheme.FONT_SMALL, CodeTheme.MUTED),
				badge: CodeDraw.label(0, yy, "", CodeTheme.FONT_SMALL, CodeTheme.TEXT),
				name: CodeDraw.label(0, yy, "", CodeTheme.FONT_SMALL + 1, CodeTheme.TEXT),
				tail: CodeDraw.label(0, yy, "", CodeTheme.FONT_SMALL, CodeTheme.MUTED)
			};
			add(s.arrow);
			add(s.badge);
			add(s.name);
			add(s.tail);
			slots.push(s);
		}
		emptyText = CodeDraw.label(x + 14, rowsY + 10, "No hay archivos", CodeTheme.FONT_SMALL, CodeTheme.DIM);
		emptyText.visible = false;
		add(emptyText);
	}

	public function setTitle(value:String):Void
		titleText.text = "EXPLORADOR  ·  " + CodeDraw.fit(value, 22);

	public function setFiles(list:Array<CodeStudioFile>, current:Null<CodeStudioFile>):Void
	{
		files = list;
		activeFile = current;
		root = build(list);
		reflow();
	}

	public function setActive(current:Null<CodeStudioFile>, reveal:Bool = true):Void
	{
		activeFile = current;
		if (reveal && current != null)
		{

			var parts = current.name.split("/");
			var p = "";
			for (i in 0...parts.length - 1)
			{
				p = p == "" ? parts[i] : p + "/" + parts[i];
				collapsed.remove(p);
			}
			flatten();
			var idx = -1;
			for (i in 0...flat.length)
				if (flat[i].file == current) idx = i;
			if (idx >= 0)
			{
				if (idx < scroll) scroll = idx;
				else if (idx >= scroll + capacity) scroll = idx - capacity + 1;
			}
		}
		layoutRows();
	}

	public function refreshMarks():Void
		layoutRows();

	function build(list:Array<CodeStudioFile>):TreeNode
	{
		var r:TreeNode = {name: "", path: "", depth: -1, folder: true, file: null, children: []};
		for (f in list)
		{
			var parts = f.name.split("/");
			var node = r;
			var p = "";
			for (i in 0...parts.length)
			{
				p = p == "" ? parts[i] : p + "/" + parts[i];
				var last = i == parts.length - 1;
				var found:Null<TreeNode> = null;
				if (!last)
					for (c in node.children)
						if (c.folder && c.name == parts[i]) found = c;
				if (found == null)
				{
					found = {name: parts[i], path: p, depth: i, folder: !last, file: last ? f : null, children: []};
					node.children.push(found);
				}
				node = found;
			}
		}
		sortNode(r);
		return r;
	}

	function sortNode(n:TreeNode):Void
	{
		n.children.sort(function(a, b)
		{
			if (a.folder != b.folder) return a.folder ? -1 : 1;
			return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase());
		});
		for (c in n.children) sortNode(c);
	}

	function flatten():Void
	{
		flat = [];
		if (root == null) return;
		function walk(n:TreeNode)
		{
			for (c in n.children)
			{
				flat.push(c);
				if (c.folder && !collapsed.exists(c.path)) walk(c);
			}
		}
		walk(root);
		var maxScroll = Std.int(Math.max(0, flat.length - capacity));
		if (scroll > maxScroll) scroll = maxScroll;
		if (scroll < 0) scroll = 0;
	}

	function reflow():Void
	{
		flatten();
		layoutRows();
	}

	function badgeFor(f:CodeStudioFile):{text:String, color:Int}
	{
		return switch (f.kind)
		{
			case "haxe": {text: "HX", color: CodeTheme.SYN_KEYWORD};
			case "json": {text: "{}", color: CodeTheme.WARN};
			default: {text: "··", color: CodeTheme.MUTED};
		};
	}

	function layoutRows():Void
	{
		emptyText.visible = flat.length == 0;
		selBar.visible = false;
		for (i in 0...capacity)
		{
			var s = slots[i];
			var idx = scroll + i;
			if (idx >= flat.length)
			{
				s.arrow.visible = s.badge.visible = s.name.visible = s.tail.visible = false;
				continue;
			}
			var n = flat[idx];
			var yy = rowsY + i * CodeTheme.ROW_H + 3;
			var x = tx + 10 + n.depth * 16;
			s.arrow.visible = s.badge.visible = s.name.visible = s.tail.visible = true;
			s.arrow.y = s.badge.y = s.name.y = s.tail.y = yy;
			if (n.folder)
			{
				s.arrow.text = collapsed.exists(n.path) ? "►" : "▼";
				s.arrow.x = x;
				s.badge.visible = false;
				s.name.text = n.name;
				s.name.color = CodeTheme.TEXT;
				s.name.x = x + 20;
				s.tail.visible = false;
			}
			else
			{
				var f = n.file;
				var b = badgeFor(f);
				s.arrow.visible = false;
				s.badge.text = b.text;
				s.badge.color = b.color;
				s.badge.x = x + 2;
				s.name.text = CodeDraw.fit(n.name, Std.int((tw - 90 - n.depth * 16) / 8));
				s.name.color = f == activeFile ? 0xFFFFFFFF : (f.editable ? CodeTheme.TEXT : CodeTheme.MUTED);
				s.name.x = x + 26;
				if (f.dirty)
				{
					s.tail.text = "●";
					s.tail.color = CodeTheme.WARN;
				}
				else if (!f.editable)
				{
					s.tail.text = "RO";
					s.tail.color = CodeTheme.DIM;
				}
				else
					s.tail.visible = false;
				s.tail.x = tx + tw - 26 - s.tail.width;
				if (f == activeFile)
				{
					selBar.visible = true;
					selBar.y = rowsY + i * CodeTheme.ROW_H;
				}
			}
		}

		var overflow = flat.length > capacity;
		thumb.visible = overflow;
		if (overflow)
		{
			var track = capacity * CodeTheme.ROW_H;
			var hh = Math.max(20, track * capacity / flat.length);
			CodeDraw.remake(thumb, 3, hh, CodeTheme.DIM);
			thumb.y = rowsY + (track - hh) * scroll / Math.max(1, flat.length - capacity);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		hoverBar.visible = false;
		if (CodeDraw.blocked || !CodeDraw.over(tx, rowsY, tw, capacity * CodeTheme.ROW_H)) return;

		if (FlxG.mouse.wheel != 0 && flat.length > capacity)
		{
			scroll = Std.int(Math.max(0, Math.min(flat.length - capacity, scroll - FlxG.mouse.wheel * 2)));
			layoutRows();
		}

		var i = Std.int((FlxG.mouse.y - rowsY) / CodeTheme.ROW_H);
		var idx = scroll + i;
		if (i < 0 || i >= capacity || idx >= flat.length) return;
		hoverBar.visible = true;
		hoverBar.y = rowsY + i * CodeTheme.ROW_H;

		if (FlxG.mouse.justPressed)
		{
			var n = flat[idx];
			if (n.folder)
			{
				if (collapsed.exists(n.path)) collapsed.remove(n.path);
				else collapsed.set(n.path, true);
				reflow();
			}
			else if (n.file != null && onOpen != null)
				onOpen(n.file);
		}
	}
}
