package funky.backend.system;

import funky.backend.system.framerate.Framerate;
import funky.core.Log.Severity;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;

private enum Phase
{
	IN;
	HOLD;
	OUT;
}

private class Item
{
	public var view:Sprite;
	public var field:TextField;
	public var bar:Sprite;
	public var severity:Severity;
	public var text:String;
	public var count:Int = 1;
	public var phase:Phase = IN;
	public var t:Float = 0;
	public var hold:Float;
	public var w:Float = 0;
	public var h:Float = 0;
	public var targetY:Float = 0;

	public function new(severity:Severity, text:String, hold:Float)
	{
		this.severity = severity;
		this.text = text;
		this.hold = hold;
	}
}

/**
 * Logs en pantalla (el `DebugText` del legacy, pero bonito): cada linea de `Log` aparece como una
 * tarjeta con fondo negro que ENTRA por la izquierda (alpha 0 -> 1 y X de fuera de pantalla a su
 * sitio), se queda unos segundos y SALE por la izquierda otra vez (alpha 1 -> 0 y X hacia fuera).
 */
class LogOverlay extends Sprite
{
	public static var instance:LogOverlay;

	/** F2 lo cambia. Apagado: no se dibuja nada y se descarta lo que llegue. */
	public static var enabled:Bool = true;

	static inline var MAX_VISIBLE:Int = 6;
	static inline var MAX_PER_FRAME:Int = 4;
	static inline var MAX_QUEUE:Int = 60;
	static inline var MAX_CHARS:Int = 240;
	static inline var MARGIN:Float = 10;
	static inline var GAP:Float = 4;
	static inline var PAD:Float = 7;
	static inline var BAR_W:Float = 4;
	static inline var IN_TIME:Float = 0.38;
	static inline var OUT_TIME:Float = 0.32;
	static inline var HOLD_NORMAL:Float = 3.2;
	static inline var HOLD_ERROR:Float = 6.5;
	static inline var FONT_SIZE:Int = 12;

	static var queue:Array<{severity:Severity, text:String}> = [];
	#if target.threaded
	static var lock:sys.thread.Mutex = new sys.thread.Mutex();
	#end

	var items:Array<Item> = [];
	var last:Int = 0;

	public function new()
	{
		super();
		instance = this;
		mouseEnabled = false;
		mouseChildren = false;
		last = Lib.getTimer();
		addEventListener(Event.ADDED_TO_STAGE, onAdded);
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	/** Lo llama `Log.log` con cada mensaje. Sin overlay todavia (arranque) se guarda un rato. */
	public static function push(severity:Severity, text:String):Void
	{
		if (!enabled) return;
		#if target.threaded
		lock.acquire();
		#end
		queue.push({severity: severity, text: text});
		if (queue.length > MAX_QUEUE) queue.shift();
		#if target.threaded
		lock.release();
		#end
	}

	function onAdded(_):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAdded);
		stage.addEventListener(KeyboardEvent.KEY_DOWN, function(e:KeyboardEvent)
		{
			if (e.keyCode == Keyboard.F2) enabled = !enabled;
		});
	}

	function onFrame(_):Void
	{
		if (stage == null) return;
		var now = Lib.getTimer();
		var dt = Math.min(0.1, (now - last) / 1000);
		last = now;

		visible = enabled;
		if (!enabled)
		{
			clear();
			return;
		}

		drain();
		layout(dt);
		for (item in items.copy()) animate(item, dt);
	}

	function drain():Void
	{
		#if target.threaded
		lock.acquire();
		#end
		var incoming = queue.splice(0, MAX_PER_FRAME);
		var skipped = queue.length;
		queue = [];
		#if target.threaded
		lock.release();
		#end

		for (entry in incoming) add(entry.severity, entry.text);
		if (skipped > 0) add(NOTICE, "(" + skipped + " logs mas, mira latest.log)");
	}

	function add(severity:Severity, raw:String):Void
	{
		var text = raw.length > MAX_CHARS ? raw.substr(0, MAX_CHARS - 1) + "…" : raw;

		// Igual a la ultima tarjeta viva: se suma el contador en vez de apilar otra.
		var newest = items.length > 0 ? items[items.length - 1] : null;
		if (newest != null && newest.phase != OUT && newest.text == text && newest.severity == severity)
		{
			newest.count++;
			newest.phase = HOLD;
			newest.t = 0;
			render(newest);
			return;
		}

		var item = new Item(severity, text, severity == ERROR ? HOLD_ERROR : HOLD_NORMAL);
		item.view = new Sprite();
		item.bar = new Sprite();
		item.field = new TextField();
		item.field.selectable = false;
		item.field.mouseEnabled = false;
		item.field.multiline = true;
		item.field.wordWrap = true;
		item.field.autoSize = TextFieldAutoSize.LEFT;
		item.field.x = PAD + BAR_W;
		item.field.y = PAD - 2;
		item.view.addChild(item.bar);
		item.view.addChild(item.field);
		item.view.alpha = 0;
		item.view.mouseEnabled = false;
		item.view.mouseChildren = false;
		render(item);
		item.view.x = -item.w - 16;
		item.view.y = bottomY();
		addChild(item.view);
		items.push(item);

		// Demasiadas: las mas viejas se van ya.
		var live = [for (i in items) if (i.phase != OUT) i];
		var extra = live.length - MAX_VISIBLE;
		for (i in 0...Std.int(Math.max(0, extra)))
		{
			live[i].phase = OUT;
			live[i].t = 0;
		}
	}

	/** (Re)dibuja el fondo negro, la barra de color y el texto de una tarjeta. */
	function render(item:Item):Void
	{
		var maxW = Math.max(220, Math.min(560, stage != null ? stage.stageWidth * 0.62 : 560));
		var label = item.severity.toString();
		var body = item.count > 1 ? item.text + "  x" + item.count : item.text;

		item.field.width = maxW - PAD * 2 - BAR_W;
		item.field.defaultTextFormat = new TextFormat(Framerate.textFont, FONT_SIZE, 0xFFFFFFFF);
		item.field.text = label + body;
		item.field.setTextFormat(new TextFormat(Framerate.textFont, FONT_SIZE, color(item.severity), true), 0, label.length);

		item.w = Math.min(maxW, item.field.textWidth + PAD * 2 + BAR_W + 6);
		item.h = item.field.height + PAD * 2 - 4;

		item.view.graphics.clear();
		item.view.graphics.beginFill(0x000000, 0.84);
		item.view.graphics.drawRoundRect(0, 0, item.w, item.h, 8, 8);
		item.view.graphics.endFill();

		item.bar.graphics.clear();
		item.bar.graphics.beginFill(color(item.severity), 1);
		item.bar.graphics.drawRoundRect(0, 0, BAR_W, item.h, 4, 4);
		item.bar.graphics.endFill();
	}

	inline function bottomY():Float
		return (stage != null ? stage.stageHeight : 720) - MARGIN;

	/** Apila de abajo hacia arriba; la Y se acerca sola a su sitio (las de arriba bajan suave). */
	function layout(dt:Float):Void
	{
		var y = bottomY();
		var k = Math.min(1, dt * 12);
		var i = items.length - 1;
		while (i >= 0)
		{
			var item = items[i];
			y -= item.h;
			item.targetY = y;
			item.view.y += (y - item.view.y) * k;
			y -= GAP;
			i--;
		}
	}

	function animate(item:Item, dt:Float):Void
	{
		item.t += dt;
		var hidden = -item.w - 16;
		switch (item.phase)
		{
			case IN:
				var k = Math.min(1, item.t / IN_TIME);
				var e = easeOutCubic(k);
				item.view.x = hidden + (MARGIN - hidden) * e;
				item.view.alpha = e;
				if (k >= 1)
				{
					item.phase = HOLD;
					item.t = 0;
				}
			case HOLD:
				item.view.x = MARGIN;
				item.view.alpha = 1;
				if (item.t >= item.hold)
				{
					item.phase = OUT;
					item.t = 0;
				}
			case OUT:
				var k = Math.min(1, item.t / OUT_TIME);
				var e = easeInCubic(k);
				item.view.x = MARGIN + (hidden - MARGIN) * e;
				item.view.alpha = 1 - e;
				if (k >= 1) remove(item);
		}
	}

	function remove(item:Item):Void
	{
		items.remove(item);
		if (item.view.parent == this) removeChild(item.view);
	}

	function clear():Void
	{
		for (item in items.copy()) remove(item);
		#if target.threaded
		lock.acquire();
		#end
		queue = [];
		#if target.threaded
		lock.release();
		#end
	}

	static inline function easeOutCubic(k:Float):Float
		return 1 - Math.pow(1 - k, 3);

	static inline function easeInCubic(k:Float):Float
		return k * k * k;

	static function color(severity:Severity):Int
	{
		return switch (severity)
		{
			case WARN: 0xFFD23F;
			case ERROR: 0xFF4D4D;
			case NOTICE: 0x4CD97B;
			default: 0x8FB4FF;
		}
	}
}
