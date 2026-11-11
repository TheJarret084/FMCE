package funkin.backend.system.framerate;

import flixel.math.FlxPoint;
import openfl.display.DisplayObject;
import funky.backend.system.framerate.Framerate as RealFramerate;

class FramerateStub
{
	var target:Void->DisplayObject;

	public var visible(get, set):Bool;
	public var alpha(get, set):Float;

	public function new(target:Void->DisplayObject)
		this.target = target;

	function part():Null<DisplayObject>
		return RealFramerate.instance == null ? null : target();

	function get_visible():Bool
	{
		var p = part();
		return p != null && p.visible;
	}

	function set_visible(value:Bool):Bool
	{
		var p = part();
		if (p != null) p.visible = value;
		return value;
	}

	function get_alpha():Float
	{
		var p = part();
		return p == null ? 1 : p.alpha;
	}

	function set_alpha(value:Float):Float
	{
		var p = part();
		if (p != null) p.alpha = value;
		return value;
	}
}

class Framerate
{
	public static var isLoaded(get, never):Bool;
	public static var offset(get, never):FlxPoint;

	public static var fpsCounter:FramerateStub = new FramerateStub(() -> RealFramerate.instance.fpsCounter);
	public static var memoryCounter:FramerateStub = new FramerateStub(() -> RealFramerate.instance.memoryCounter);
	public static var codenameBuildField:FramerateStub = new FramerateStub(() -> RealFramerate.instance.buildField);

	static inline function get_isLoaded():Bool
		return RealFramerate.isLoaded && RealFramerate.instance != null;

	static inline function get_offset():FlxPoint
		return RealFramerate.offset;

	public static inline function setPosition(x:Float, y:Float):Void
		RealFramerate.setPosition(x, y);

	public static inline function move(dx:Float, dy:Float):Void
		RealFramerate.move(dx, dy);

	public static inline function resetPosition():Void
		RealFramerate.resetPosition();
}
