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

/**
 * Menu principal con la vista de Codename Engine: fondo que se desplaza con la camara,
 * botones de los atlas `menus/mainmenu/<nombre>` (animaciones "basic" y "white"),
 * parpadeo magenta al elegir.
 *
 * El convertidor sigue en Freeplay (tecla C) y en Opciones > Miscelanea.
 */
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
				// Sin atlas: texto plano, no rompe el menu.
				var label = new FlxText(0, 60 + i * 160, 0, option.toUpperCase(), 64);
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
			+ (TouchNav.MOBILE ? "toca una opcion" : KeyBinds.label(KeyBinds.ACCEPT) + " elegir  |  " + KeyBinds.label(KeyBinds.BACK) + " volver"
				+ (AdvancedModeState.antiGay ? "" : "  |  7 avanzado")), 16);
		versionText.setBorderStyle(OUTLINE, 0xFF000000, 1.5);
		versionText.y = FlxG.height - versionText.height - 4;
		versionText.scrollFactor.set();
		add(versionText);

		FlxG.mouse.visible = false;
		FlxG.mouse.enabled = false;

		changeItem();
		TransitionHandler.playIn(this);
	}

	override public function update(elapsed:Float):Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume += 0.5 * elapsed;

		if (!selectedSomething)
		{
			// Atajo al modo avanzado. antiGay = true lo bloquea.
			if (!AdvancedModeState.antiGay && FlxG.keys.justPressed.SEVEN)
			{
				leave(new AdvancedModeState());
				return;
			}

			var up = KeyBinds.justPressed(KeyBinds.UP);
			var down = KeyBinds.justPressed(KeyBinds.DOWN);
			if (up || down) changeItem((up ? -1 : 0) + (down ? 1 : 0));

			if (KeyBinds.justPressed(KeyBinds.BACK))
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

	/** Indice del boton que un dedo acaba de tocar, o -1. Los botones tienen scrollFactor 0: x/y ya son de pantalla. */
	function tappedItem():Int
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (!touch.justPressed) continue;
			for (spr in menuItems)
			{
				// Margen generoso (dedo gordo) y se ignora el offset: los botones son scrollFactor 0, x/y ya son de pantalla.
				if (touch.screenX >= spr.x - 24 && touch.screenX <= spr.x + spr.width + 24 && touch.screenY >= spr.y - 16 && touch.screenY <= spr.y + spr.height + 16)
					return spr.ID;
			}
		}
		#end
		return -1;
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
