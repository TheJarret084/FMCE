package funky.menus.options;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;

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
		menu.setRootFactory(() -> ConfigScreens.root(menu, true));
		menu.openSubState = function(sub)
		{
			sub.cameras = cameras;
			openSubState(sub);
		};
		menu.onExit = close;
		add(menu);
	}
}
