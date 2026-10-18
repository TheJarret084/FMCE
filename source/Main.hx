package;

import flixel.FlxG;
import flixel.FlxGame;
import openfl.display.Sprite;
import funky.core.Log;
import funky.core.CrashHandler;
import funky.core.MemoryUtil;
import funky.core.WindowUtils;
import funky.core.Paths;
import funky.core.ClientPrefs;
import funky.api.DiscordClient;
import funky.backend.system.framerate.Framerate;
import funky.backend.system.LogOverlay;
import funky.menus.SplashState;

import flixel.system.FlxSplash;

class Main extends Sprite
{
	public static var instance:Main;

	static inline var GAME_WIDTH:Int = 1280;
	static inline var GAME_HEIGHT:Int = 720;

	public function new()
	{
		super();
		instance = this;

		Log.init();
		CrashHandler.init();
		Paths.init();
		ClientPrefs.load();

		#if desktop
		WindowUtils.init("FMCE");
		DiscordClient.initialize();
		#end

		MemoryUtil.enable();
		FlxG.signals.postStateSwitch.add(() -> MemoryUtil.clearMajor());

		addChild(new FlxGame(GAME_WIDTH, GAME_HEIGHT, SplashState, 60, 60, true));
		addChild(new Framerate());
		addChild(new LogOverlay()); // logs en pantalla (F2)
		Log.info("Juego iniciado :happy:");
	}
}
