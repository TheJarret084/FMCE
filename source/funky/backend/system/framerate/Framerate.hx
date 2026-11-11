package funky.backend.system.framerate;

import flixel.FlxG;
import flixel.math.FlxPoint;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextFormat;
import funky.core.Paths;
import flixel.util.FlxColor;
import haxe.io.Path;
import funky.core.Log;
import openfl.utils.Assets as OpenFlAssets;

class Framerate extends Sprite
{
	public static var instance:Framerate;
	public static var isLoaded:Bool = false;
	public static var debugMode:Int = 1;

	public static var offsetX:Float = DEFAULT_X;
	public static var offsetY:Float = DEFAULT_Y;

	public static var offset:FlxPoint = FlxPoint.get(0, 0);

	public static var panelAlpha:Float = 1;
	public static var textFormat:TextFormat;
	public static var fontName:String = "_typewriter";
	public static var otherNewFont:String = "Daydream";

	public static var textFont:String = "_typewriter";

	public var otherColor:Bool = true;

	static inline var DEFAULT_X:Float = 6;
	static inline var DEFAULT_Y:Float = 6;
	static inline var PAD_X:Float = 12;
	static inline var PAD_Y:Float = 7;
	static inline var GAP:Float = 2;
	static inline var REFRESH_MS:Int = 500;

	static inline var BASE_HEIGHT:Float = 720;

	public var panel:Sprite;
	public var fpsCounter:FramerateCounter;
	public var memoryCounter:MemoryCounter;
	public var buildField:EngineBuildField;

	private var panelW:Float = -1;
	private var panelH:Float = -1;
	private var lastRefresh:Int = 0;

	public function new()
	{
		super();
		if (instance != null) throw "Cannot create another Framerate instance";
		instance = this;
		isLoaded = true;

		textFont = resolveFont();
		textFormat = new TextFormat(textFont, 10, otherColor ? 0xFFA5D6D1 : 0xFFFFFFFF);

		panel = new Sprite();
		panel.mouseEnabled = false;
		fpsCounter = new FramerateCounter();
		memoryCounter = new MemoryCounter();
		buildField = new EngineBuildField();

		addChild(panel);
		addChild(fpsCounter);
		addChild(memoryCounter);
		addChild(buildField);

		mouseEnabled = false;
		mouseChildren = false;

		updateLayout();
		addEventListener(Event.ENTER_FRAME, onEnterFrame);

		FlxG.signals.preStateSwitch.add(onPreStateSwitch);
		FlxG.signals.postStateSwitch.add(onPostStateSwitch);
		onPostStateSwitch();
	}

	public static function setPosition(x:Float, y:Float):Void
	{
		offsetX = x;
		offsetY = y;
	}

	public static function move(dx:Float, dy:Float):Void
	{
		offsetX += dx;
		offsetY += dy;
	}

	public static function resetPosition():Void
	{
		offsetX = DEFAULT_X;
		offsetY = DEFAULT_Y;
		offset.set(0, 0);
		panelAlpha = 1;
	}

	public static function setAlpha(value:Float):Void
		panelAlpha = value < 0 ? 0 : (value > 1 ? 1 : value);

	public static function setVisible(value:Bool):Void
		debugMode = value ? 1 : 0;

	public static inline var EDITOR_ALPHA:Float = 0.1;

	static var inEditor:Bool = false;

	static function onPostStateSwitch():Void
	{
		var name = FlxG.state != null ? Type.getClassName(Type.getClass(FlxG.state)) : "";
		inEditor = StringTools.startsWith(name, "funkin.editors.")
			|| StringTools.startsWith(name, "advanced.editors.")
			|| name == "advanced.AdvancedEditorState";
	}

	static function onPreStateSwitch():Void
	{

		offset.set(0, 0);
		panelAlpha = 1;
	}

	public static function resolveFont():String
	{
		for (ext in [".otf", ".ttf"])
		{
			var path = Paths.Font(otherNewFont, ext);
			if (OpenFlAssets.exists(path))
			{
				var f = OpenFlAssets.getFont(path);
				if (f != null && f.fontName != null) return f.fontName;
			}
		}
		Log.warn('Framerate: no se encontro la fuente "' + otherNewFont + '" en assets/fonts, usando ' + fontName);
		return fontName;
	}

	private function onEnterFrame(_):Void
	{
		visible = debugMode > 0;
		alpha = visible ? (inEditor ? EDITOR_ALPHA : panelAlpha) : 0;
		if (!visible) return;

		if (stage != null)
		{
			var fit = Math.max(1, stage.stageHeight / BASE_HEIGHT);
			scaleX = scaleY = fit;
		}

		x = offsetX + offset.x;
		y = offsetY + offset.y;

		var now = Lib.getTimer();
		if (now - lastRefresh >= REFRESH_MS)
		{
			lastRefresh = now;
			buildField.reload();
		}

		updateLayout();
	}

	private function updateLayout():Void
	{
		fpsCounter.x = PAD_X;
		fpsCounter.y = PAD_Y;
		memoryCounter.x = PAD_X;
		memoryCounter.y = fpsCounter.y + fpsCounter.height + GAP;
		buildField.x = PAD_X;
		buildField.y = memoryCounter.y + memoryCounter.height + GAP;

		var w = Math.max(fpsCounter.width, Math.max(memoryCounter.width, buildField.width)) + PAD_X * 2;
		var h = buildField.y + buildField.height + PAD_Y;
		if (Math.abs(w - panelW) > 0.5 || Math.abs(h - panelH) > 0.5)
			drawPanel(w, h);
	}

	private function drawPanel(w:Float, h:Float):Void
	{
		panelW = w;
		panelH = h;

		var g = panel.graphics;
		g.clear();
		g.beginFill(0x0B0E14, 0.82);
		g.drawRoundRect(0, 0, w, h, 12, 12);
		g.endFill();
		g.beginFill(FramerateCounter.GOOD & 0xFFFFFF, 1);
		g.drawRoundRect(0, 7, 3, h - 14, 3, 3);
		g.endFill();
	}

	public function reload():Void
	{
		fpsCounter.reload();
		memoryCounter.reload();
		buildField.reload();
	}

	public function destroy():Void
	{
		removeEventListener(Event.ENTER_FRAME, onEnterFrame);
		FlxG.signals.preStateSwitch.remove(onPreStateSwitch);
		FlxG.signals.postStateSwitch.remove(onPostStateSwitch);
		fpsCounter.destroy();
		memoryCounter.destroy();
		if (instance == this) instance = null;
		isLoaded = false;
	}
}
