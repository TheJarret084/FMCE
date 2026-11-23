package funky.advanced.ui;

import flixel.util.FlxColor;
import funky.editors.ui.UICompactColorwheel;

class ColorField extends UICompactColorwheel
{
	public function setValue(newColor:FlxColor):Void
	{
		setColor(newColor);
		hue = newColor.hue;
	}
}
