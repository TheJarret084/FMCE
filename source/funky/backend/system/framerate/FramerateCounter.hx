package funky.backend.system.framerate;

import flixel.FlxG;
import flixel.math.FlxMath;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;

/** FPS grandes con color segun el objetivo y mini grafica. */
class FramerateCounter extends Sprite
{
	public static inline var GOOD:Int = 0xFF64DDAA;
	public static inline var MID:Int = 0xFFFFD166;
	public static inline var BAD:Int = 0xFFFF6B6B;

	static inline var SAMPLES:Int = 40;
	static inline var BAR_W:Int = 2;
	static inline var BAR_GAP:Int = 1;
	static inline var GRAPH_H:Int = 18;
	static inline var GRAPH_X:Int = 88;
	/** Cada cuanto se calcula el promedio y se agrega una barra (ms). */
	static inline var UPDATE_MS:Int = 66;

	public var fpsNum:TextField;
	public var fpsLabel:TextField;
	public var graph:Sprite;
	public var lastFPS:Float = 0;

	private var frameCount:Int = 0;
	private var lastTick:Int = 0;
	private var samples:Array<Float> = [];

	public function new()
	{
		super();
		fpsNum = makeText(20);
		fpsLabel = makeText(11);
		fpsNum.text = "0";
		fpsLabel.text = " FPS";
		fpsLabel.alpha = 0.6;
		graph = new Sprite();
		graph.x = GRAPH_X;
		addChild(fpsNum);
		addChild(fpsLabel);
		addChild(graph);
		lastTick = Lib.getTimer();
		addEventListener(Event.ENTER_FRAME, onEnterFrame);
		updateLabelPosition();
	}

	private function makeText(size:Int):TextField
	{
		var field = new TextField();
		field.autoSize = LEFT;
		field.multiline = field.wordWrap = false;
		field.defaultTextFormat = new TextFormat(Framerate.textFont, size, 0xFFFFFFFF);
		field.selectable = false;
		field.mouseEnabled = false;
		return field;
	}

	private function onEnterFrame(_):Void
	{
		if (Framerate.debugMode <= 0) return;

		frameCount++;
		var now = Lib.getTimer();
		var ms = now - lastTick;
		if (ms < UPDATE_MS) return;

		lastTick = now;
		var measured = 1000 / ms * frameCount;
		var frameMs = ms / frameCount;
		frameCount = 0;

		lastFPS = lastFPS == 0 ? measured : FlxMath.lerp(lastFPS, measured, 0.35);
		fpsNum.text = Std.string(Math.round(lastFPS));
		fpsNum.textColor = colorFor(lastFPS / target()) & 0xFFFFFF;

		samples.push(frameMs);
		if (samples.length > SAMPLES) samples.shift();
		drawGraph();
		updateLabelPosition();
	}

	/** FPS a los que el juego intenta correr. */
	private function target():Float
	{
		return Math.max(1, FlxG.drawFramerate);
	}

	private static function colorFor(ratio:Float):Int
	{
		return ratio >= 0.9 ? GOOD : (ratio >= 0.55 ? MID : BAD);
	}

	private function drawGraph():Void
	{
		var g = graph.graphics;
		g.clear();

		var targetMs = 1000 / target();
		for (i in 0...samples.length)
		{
			var ms = samples[i];
			var h = Math.max(1, Math.min(GRAPH_H, (ms / (targetMs * 2)) * GRAPH_H));
			var color = ms <= targetMs * 1.15 ? GOOD : (ms <= targetMs * 1.8 ? MID : BAD);
			g.beginFill(color & 0xFFFFFF, 0.9);
			g.drawRect(i * (BAR_W + BAR_GAP), GRAPH_H - h, BAR_W, h);
			g.endFill();
		}
	}

	private function updateLabelPosition():Void
	{
		fpsLabel.x = fpsNum.width;
		fpsLabel.y = Math.max(0, fpsNum.height - fpsLabel.height - 2);
		graph.y = Math.max(0, fpsNum.height - GRAPH_H - 3);
	}

	public function reload():Void
	{
		frameCount = 0;
		lastTick = Lib.getTimer();
		samples = [];
		graph.graphics.clear();
	}

	public function destroy():Void
	{
		removeEventListener(Event.ENTER_FRAME, onEnterFrame);
	}
}
