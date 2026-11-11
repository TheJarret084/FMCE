package funky.backend;

import openfl.display.BitmapData;
import openfl.geom.Point;
import openfl.geom.Rectangle;

typedef PageSlot =
{
	var page:Int;
	var x:Int;
	var y:Int;
}

class AtlasPager
{

	public var pageCount(get, never):Int;

	public var placedCount(default, null):Int = 0;

	final maxW:Int;
	final maxH:Int;
	final gap:Int;
	final onPage:Int->BitmapData->Void;

	var current:Int = -1;
	var canvas:Null<BitmapData> = null;
	var placed:Map<String, PageSlot> = new Map<String, PageSlot>();
	var cursorX:Int = 0;
	var cursorY:Int = 0;
	var rowH:Int = 0;
	var usedW:Int = 0;
	var usedH:Int = 0;
	var empty:Bool = true;

	public function new(maxW:Int, maxH:Int, gap:Int, onPage:Int->BitmapData->Void)
	{
		this.maxW = maxW;
		this.maxH = maxH;
		this.gap = gap;
		this.onPage = onPage;
	}

	function get_pageCount():Int return current + 1;

	public function place(key:String, w:Int, h:Int, source:BitmapData, rect:Rectangle):PageSlot
	{
		if (canvas != null)
		{
			var known = placed.get(key);
			if (known != null) return known;
		}
		else
			startPage();

		var px = cursorX;
		var py = cursorY;
		var rh = rowH;

		if (px + w + gap > maxW && px > gap)
		{
			py = cursorY + rowH + gap;
			px = gap;
			rh = 0;
		}

		if (py + h + gap > maxH && !empty)
		{
			flush();
			startPage();
			px = cursorX;
			py = cursorY;
			rh = 0;
		}

		ensure(px + w + gap, py + h + gap);
		canvas.copyPixels(source, rect, new Point(px, py));

		var slot:PageSlot = {page: current, x: px, y: py};
		placed.set(key, slot);
		placedCount++;

		cursorX = px + w + gap;
		cursorY = py;
		rowH = rh > h ? rh : h;
		empty = false;
		if (cursorX > usedW) usedW = cursorX;
		if (py + h + gap > usedH) usedH = py + h + gap;

		return slot;
	}

	public function finish():Void
	{
		flush();
	}

	public function dispose():Void
	{
		if (canvas != null) canvas.dispose();
		canvas = null;
		placed = new Map<String, PageSlot>();
	}

	function startPage():Void
	{
		current++;
		canvas = new BitmapData(256, 256, true, 0x00000000);
		placed = new Map<String, PageSlot>();
		cursorX = gap;
		cursorY = gap;
		rowH = 0;
		usedW = 0;
		usedH = 0;
		empty = true;
	}

	function ensure(needW:Int, needH:Int):Void
	{
		if (needW <= canvas.width && needH <= canvas.height) return;

		var newW = canvas.width;
		var newH = canvas.height;
		if (needW > newW) newW = Std.int(Math.max(needW, Math.min(maxW, newW * 2)));
		if (needH > newH) newH = Std.int(Math.max(needH, Math.min(maxH, newH * 2)));

		var bigger = new BitmapData(newW, newH, true, 0x00000000);
		bigger.copyPixels(canvas, canvas.rect, new Point(0, 0));
		canvas.dispose();
		canvas = bigger;
	}

	function flush():Void
	{
		if (canvas == null) return;

		var out = canvas;
		canvas = null;

		var w = Std.int(Math.max(1, usedW));
		var h = Std.int(Math.max(1, usedH));
		if (out.width != w || out.height != h)
		{
			var exact = new BitmapData(w, h, true, 0x00000000);
			exact.copyPixels(out, new Rectangle(0, 0, w, h), new Point(0, 0));
			out.dispose();
			out = exact;
		}

		onPage(current, out);
	}
}
