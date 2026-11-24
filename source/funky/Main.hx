package funky;

import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.Sprite;
import funky.backend.system.Log;
import funky.backend.system.CrashHandler;
import funky.backend.system.MemoryUtil;
import funky.backend.utils.WindowUtils;
import funky.backend.assets.Paths;
import funky.backend.addons.AssetPack;
import funky.backend.system.ClientPrefs;
import funky.backend.utils.TranslationUtil;
import funky.api.DiscordClient;
import funky.backend.system.framerate.Framerate;
import funky.backend.system.LogOverlay;
import funky.menus.other.CheckerState;

import flixel.system.FlxSplash;

class Main extends Sprite
{
	public static var instance:Main;

	public function new()
	{
		super();
		instance = this;

		Log.init();
		CrashHandler.init();

		AssetPack.mount();
		Paths.init();
		ClientPrefs.load();

		lime.app.Application.current.onExit.add(function(_:Int) ClientPrefs.save());
		TranslationUtil.init();

		#if desktop
		WindowUtils.init("FMCE");
		#end

		#if (desktop || android)
		DiscordClient.initialize();
		#end

		MemoryUtil.enable();
		FlxG.signals.postStateSwitch.add(() -> MemoryUtil.clearMajor());

		addChild(new FlxGame(1280, 720, CheckerState, 60, 60, true));
		FlxG.signals.focusLost.add(function() ClientPrefs.save());
		funky.backend.system.CursorManager.init();
		addChild(new Framerate());
		addChild(new LogOverlay());
		Log.info("Juego iniciado :happy:");
	}
}
