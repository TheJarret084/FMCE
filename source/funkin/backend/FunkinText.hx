package funkin.backend;

import flixel.text.FlxText;
import flixel.util.FlxColor;

class FunkinText extends FlxText {
	public function new(x:Float = 0, y:Float = 0, width:Float = 0, text:String = "", size:Int = 16, bold:Bool = true) {
		super(x, y, width, text, size);
		font = Paths.font("vcr.ttf");
		this.bold = false;
	}
}
