package funkin.game;

import flixel.FlxCamera;

class HudCamera extends FlxCamera {
	public var downscroll:Bool = false;
	public var zoomFactor:Float = 1;
	public function new(x:Int = 0, y:Int = 0, width:Int = 0, height:Int = 0, zoom:Float = 0) super(x, y, width, height, zoom);
}
