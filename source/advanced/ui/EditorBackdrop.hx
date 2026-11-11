package advanced.ui;

import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxAxes;
import funky.core.Paths;

class EditorBackdrop extends FlxBackdrop
{

	public static inline var SPEED:Float = 36;

	public static inline var DEFAULT_IMAGE:String = "editors/bgs/default";

	public function new(alpha:Float = 0.55, image:String = DEFAULT_IMAGE)
	{
		super(Paths.image(image), FlxAxes.XY);
		velocity.set(SPEED, 0);
		scrollFactor.set();
		this.alpha = alpha;
	}
}
