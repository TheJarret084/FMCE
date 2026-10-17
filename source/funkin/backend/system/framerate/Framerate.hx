package funkin.backend.system.framerate;

class FramerateStub { public var visible:Bool = false; public var alpha:Float = 1; public function new() {} }

class Framerate
{
	public static var isLoaded:Bool = false;
	public static var offset:flixel.math.FlxPoint = flixel.math.FlxPoint.get();
	public static var fpsCounter:FramerateStub = new FramerateStub();
	public static var memoryCounter:FramerateStub = new FramerateStub();
	public static var codenameBuildField:FramerateStub = new FramerateStub();
}
