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

import flixel.util.FlxColor;
import funky.core.Log;

/** Creditos desde el menu principal (estilo CreditsMain de Codename). La lista esta hardcodeada en ConfigScreens.CREDITS. */
class CreditsState extends FlxState
{
	var menu:ConfigMenu;
	var leaving:Bool = false;

	public var bg:FlxSprite;

	/** Fondo por defecto (dentro de assets/images/). */
	var fallback:String = "menus/menuDesat";

	override public function create():Void
	{
		super.create();

		bg = new FlxSprite();
		bg.scrollFactor.set();
		changeBG(fallback);
		add(bg);

		menu = new ConfigMenu();
		menu.setRoot(ConfigScreens.credits(menu));
		menu.onBackgroundChange = changeBG;
		menu.onExit = leave;
		add(menu);

		DiscordClient.menuPresence();
		TransitionHandler.playIn(this);
	}

	/** `image` va relativa a assets/images/ y sin .png (ej. "credits_1" o "menus/menuDesat"); null = el por defecto. */
	public function changeBG(?image:String):Void
	{
		if (image == null || image == "") image = fallback;

		if (!OpenFlAssets.exists(Paths.image(image)))
		{
			Log.warn("[CreditsState] hijo, tu sprite " + image + " no existe... checa eso");
			image = fallback;
		}

		bg.scale.set(1, 1);
		if (OpenFlAssets.exists(Paths.image(image)))
		{
			bg.loadGraphic(Paths.image(image));
			var cover = Math.max(FlxG.width / bg.width, FlxG.height / bg.height) * 1.15;
			bg.scale.set(cover, cover);
			bg.updateHitbox();
		}
		else
			bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(102, 18, 18));
		bg.screenCenter();
	}

	function leave():Void
	{
		if (leaving) return;
		leaving = true;
		TransitionHandler.switchState(new MainMenuState());
	}
}
