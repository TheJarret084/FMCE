package funky.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import funky.api.DiscordClient;
import funky.core.Paths;
import funky.core.TransitionHandler;
import funky.menus.options.ConfigMenu;
import funky.menus.options.ConfigScreens;
import openfl.Assets as OpenFlAssets;

import advanced.AdvancedModeState;
import funky.core.ClientPrefs;

class ConfigState extends FlxState
{
	/** Lo pone PlayState.openConfig(): al salir de la config se vuelve a cargar el nivel en vez de ir al menu principal. */
	public static var returnToLevel:Bool = false;

	var menu:ConfigMenu;
	var leaving:Bool = false;
	var backToLevel:Bool = false;

	override public function create():Void
	{
		super.create();

		// Se consume aqui: si desde la config se va a otro lado (modo avanzado, convertidor) la marca no queda colgada.
		backToLevel = returnToLevel;
		returnToLevel = false;

		var bg = new FlxSprite();
		if (OpenFlAssets.exists(Paths.image("menus/menuBGBlue")))
		{
			bg.loadGraphic(Paths.image("menus/menuBGBlue"));
			var cover = Math.max(FlxG.width / bg.width, FlxG.height / bg.height) * 1.15;
			bg.scale.set(cover, cover);
			bg.updateHitbox();
		}
		else
			bg.makeGraphic(FlxG.width, FlxG.height, 0xFF16161D);
		bg.screenCenter();
		bg.scrollFactor.set();
		add(bg);

		menu = new ConfigMenu();
		menu.setRootFactory(() -> ConfigScreens.root(menu, false));
		menu.openSubState = openSubState;
		menu.onExit = leave;
		add(menu);

		DiscordClient.menuPresence();
		TransitionHandler.playIn(this);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (leaving) return;

		if (!AdvancedModeState.antiGay && FlxG.keys.justPressed.SEVEN)
		{
			leaving = true;
			ClientPrefs.save();
			TransitionHandler.switchState(new AdvancedModeState());
		}
	}

	function leave():Void
	{
		if (leaving) return;
		leaving = true;
		var next:FlxState = backToLevel ? new LoadingLevelState() : new MainMenuState();
		TransitionHandler.switchState(next);
	}
}
