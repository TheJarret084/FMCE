package funky.menus;

import advanced.AdvancedModeState;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import funky.api.DiscordClient;
import funky.core.CoolUtil;
import funky.core.KeyBinds;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import funky.menus.options.BackButton;
import funkin.backend.utils.TranslationUtil as TU;

class MainMenuState extends FlxState
{
	static final ITEMS:Array<String> = ["freeplay", "options", "credits"];

	var curSelected:Int = 0;
	var selectedSomething:Bool = false;

	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;
	var menuItems:FlxTypedGroup<FlxSprite>;
	var versionText:FlxText;
	var backButton:FlxObject;

	override public function create():Void
	{
		super.create();

		CoolUtil.playMenuSong();
		DiscordClient.menuPresence();

		bg = new FlxSprite(-80).loadGraphic(Paths.image("menus/menuBG"));
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image("menus/menuDesat"));
		magenta.visible = false;
		magenta.color = 0xFFFD719B;
		add(magenta);

		for (layer in [bg, magenta])
		{
			layer.scrollFactor.set(0, 0.18);
			layer.scale.set(1.15, 1.15);
			layer.updateHitbox();
			layer.screenCenter();
			layer.antialiasing = true;
		}

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (i in 0...ITEMS.length)
		{
			var option = ITEMS[i];
			var item:FlxSprite;
			var frames = Paths.getSparrowAtlas("menus/mainmenu/" + option);
			if (frames != null)
			{
				item = new FlxSprite(0, 60 + i * 160);
				item.frames = frames;
				item.animation.addByPrefix("idle", option + " basic", 24);
				item.animation.addByPrefix("selected", option + " white", 24);
				item.animation.play("idle");
			}
			else
			{

				var label = new FlxText(0, 60 + i * 160, 0, TU.translate("mainMenu." + option, null, option.toUpperCase()), 64);
				item = label;
			}
			item.ID = i;
			item.screenCenter(X);
			item.scrollFactor.set();
			item.antialiasing = true;
			menuItems.add(item);
		}

		FlxG.camera.follow(camFollow, null, 0.06);

		versionText = new FlxText(5, 0, 0, "V" + lime.app.Application.current.meta.get("version") + "\n"
			+ (TouchNav.MOBILE ? TU.translate("mainMenu.hintMobile", null, "toca una opcion")
				: TU.translate("mainMenu.hint", [KeyBinds.label(KeyBinds.ACCEPT), KeyBinds.label(KeyBinds.BACK)],
					"{0} elegir  |  {1} volver") + (AdvancedModeState.antiGay ? "" : TU.translate("mainMenu.hintAdvanced", null, "  |  7 avanzado"))), 16);
		versionText.setBorderStyle(OUTLINE, 0xFF000000, 1.5);
		versionText.y = FlxG.height - versionText.height - 4;
		versionText.scrollFactor.set();
		add(versionText);

		backButton = BackButton.place();
		add(backButton);

		changeItem();
		TransitionHandler.playIn(this);
	}

	override public function update(elapsed:Float):Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume += 0.5 * elapsed;

		if (!selectedSomething)
		{

			if (!AdvancedModeState.antiGay && FlxG.keys.justPressed.SEVEN)
			{
				leave(new AdvancedModeState());
				return;
			}

			hoverItem();

			var up = KeyBinds.justPressed(KeyBinds.UP);
			var down = KeyBinds.justPressed(KeyBinds.DOWN);
			if (up || down) changeItem((up ? -1 : 0) + (down ? 1 : 0));

			if (KeyBinds.justPressed(KeyBinds.BACK) || BackButton.clicked(backButton))
			{
				CoolUtil.playMenuSound("cancel", 0.7);
				leave(new TitleState());
			}
			else if (KeyBinds.justPressed(KeyBinds.ACCEPT))
				selectItem();
			else
			{
				var tapped = tappedItem();
				if (tapped >= 0)
				{
					if (tapped == curSelected) selectItem();
					else changeItem(tapped - curSelected);
				}
			}
		}

		super.update(elapsed);

		menuItems.forEach(spr -> spr.screenCenter(X));
	}

	function tappedItem():Int
	{
		var tap = TouchNav.pressPoint();
		if (tap == null) return -1;

		var found = -1;
		for (spr in menuItems)
		{

			if (TouchNav.contains(spr, tap.x, tap.y, 20))
			{
				found = spr.ID;
				break;
			}
		}
		tap.put();
		return found;
	}

	function hoverItem():Void
	{
		#if (FLX_MOUSE && !(android || ios))
		if (!FlxG.mouse.justMoved) return;
		for (spr in menuItems)
		{
			if (spr.ID != curSelected && TouchNav.contains(spr, FlxG.mouse.screenX, FlxG.mouse.screenY, 0))
			{
				changeItem(spr.ID - curSelected);
				return;
			}
		}
		#end
	}

	function leave(next:FlxState):Void
	{
		selectedSomething = true;
		menuItems.forEach(spr -> FlxTween.tween(spr, {alpha: 0}, 0.5, {ease: FlxEase.quintOut}));
		TransitionHandler.switchState(next);
	}

	function selectItem():Void
	{
		selectedSomething = true;
		CoolUtil.playMenuSound("confirm", 0.7);

		FlxFlicker.flicker(magenta, 1.1, 0.15, false);
		FlxFlicker.flicker(menuItems.members[curSelected], 1, 0.06, false, false, function(_)
		{
			switch (ITEMS[curSelected])
			{
				case "freeplay": TransitionHandler.switchState(new FreeplayState());
				case "options": TransitionHandler.switchState(new ConfigState());
				case "credits": TransitionHandler.switchState(new CreditsState());
			}
		});
	}

	function changeItem(step:Int = 0):Void
	{
		curSelected = Std.int(FlxMath.wrap(curSelected + step, 0, ITEMS.length - 1));
		if (step != 0) CoolUtil.playMenuSound("scroll", 0.7);

		menuItems.forEach(function(spr:FlxSprite)
		{
			var selected = spr.ID == curSelected;
			if (spr.animation.exists("idle"))
				spr.animation.play(selected ? "selected" : "idle");
			else
				spr.alpha = selected ? 1 : 0.6;

			if (selected)
			{
				var mid = spr.getGraphicMidpoint();
				camFollow.setPosition(mid.x, mid.y);
				mid.put();
			}

			spr.updateHitbox();
			spr.centerOffsets();
		});
	}

	override public function destroy():Void
	{
		super.destroy();
		FlxG.camera.follow(null);
		bg = null;
		magenta = null;
		camFollow = null;
		menuItems = null;
		versionText = null;
	}
}
