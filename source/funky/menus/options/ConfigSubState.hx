package funky.menus.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;

/** Las mismas opciones, pero encima de la pausa: no se pierde la cancion. */
class ConfigSubState extends FlxSubState
{
	var menu:ConfigMenu;

	override public function create():Void
	{
		super.create();

		var dim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xE6000000);
		dim.scrollFactor.set();
		add(dim);

		menu = new ConfigMenu();
		menu.setRoot(ConfigScreens.root(menu, true));
		menu.onExit = close;
		add(menu);
	}
}
