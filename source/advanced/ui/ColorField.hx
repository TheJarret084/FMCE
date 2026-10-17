package advanced.ui;

import flixel.util.FlxColor;
import funkin.editors.ui.UICompactColorwheel;

/** `UICompactColorwheel` al que se le puede asignar un color desde afuera (el selector sigue el tono). */
class ColorField extends UICompactColorwheel
{
	public function setValue(newColor:FlxColor):Void
	{
		setColor(newColor);
		hue = newColor.hue;
	}
}
