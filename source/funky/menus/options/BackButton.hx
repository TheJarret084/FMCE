package funky.menus.options;

import flixel.FlxObject;
import flixel.FlxSprite;
import funky.core.MenuButton;
import funky.core.Paths;
import funky.core.TouchNav;
import funkin.backend.utils.TranslationUtil as TU;

class BackButton extends FlxSprite
{

	static inline var ATLAS:String = "backButton/texture";

	public static inline var SIZE:Int = 96;

	public static inline var X:Float = 12;
	public static inline var Y:Float = 4;

	public static inline var WIDTH:Float = X + SIZE + 10;

	public static function place():FlxObject
	{
		if (available()) return new BackButton(X, Y);
		return new MenuButton(TU.translate("ui.back", null, "< ATRAS"), X, Y + 10, 150);
	}

	public static function fade(button:Null<FlxObject>, value:Float):Void
	{
		if (Std.isOfType(button, BackButton)) cast(button, BackButton).alpha = value;
		else if (Std.isOfType(button, MenuButton)) cast(button, MenuButton).fade = value;
	}

	public static function clicked(button:Null<FlxObject>):Bool
	{
		if (button == null || !TouchNav.hit(button)) return false;
		if (Std.isOfType(button, BackButton)) cast(button, BackButton).press();
		else if (Std.isOfType(button, MenuButton)) cast(button, MenuButton).press();
		return true;
	}

	public static function available():Bool
		return Paths.framesExists(ATLAS);

	public function new(x:Float, y:Float)
	{
		super(x, y);
		scrollFactor.set();
		antialiasing = true;

		var atlas = Paths.getFrames(ATLAS);
		if (atlas != null)
		{
			frames = atlas;
			animation.addByPrefix("back", "back", 24, false);
			setGraphicSize(SIZE);
			updateHitbox();
		}
		else
			makeGraphic(SIZE, SIZE, 0xFF55555F);
	}

	public function press():Void
	{
		if (animation.getByName("back") != null) animation.play("back", true);
	}
}
