package funky.menus;

import flixel.FlxG;
import flixel.FlxState;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funky.backend.FunkinVideoSprite;
import funky.core.ClientPrefs;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.TouchNav;
#if hxvlc
import flixel.util.FlxAxes;
import hxvlc.flixel.FlxVideo;
#end

class SplashState extends FlxState
{

	static inline var START_TIMEOUT:Float = 6;

	static inline var PLAY_DELAY:Float = 0.05;
	static inline var PLAY_RETRIES:Int = 10;

	#if hxvlc
	var video:Null<FlxVideo>;
	var startTimer:Null<FlxTimer>;
	#end

	var finished:Bool = false;

	var ready:Bool = false;

	var ended:Bool = false;
	var waited:Float = 0;

	override public function create():Void
	{
		super.create();

		FlxG.cameras.bgColor = FlxColor.BLACK;

		if (ClientPrefs.isSkipIntro() || ClientPrefs.isSplashSeen())
		{
			finishSplash();
			return;
		}

		#if hxvlc
		video = new FlxVideo();

		video.onFormatSetup.add(fitVideo);
		video.onEndReached.add(() -> ended = true);
		video.onEncounteredError.add(error ->
		{
			Log.warn('[SplashState] error del video: $error');
			ended = true;
		});
		FlxG.signals.gameResized.add(onGameResized);
		FlxG.addChildBelowMouse(video);

		var loaded = false;
		try
		{
			loaded = video.load(FunkinVideoSprite.resolve("splash"));
		}
		catch (e:Dynamic)
		{
			Log.error('[SplashState] error cargando el video: $e');
		}

		if (!loaded)
		{
			Log.warn('[SplashState] no se pudo cargar addons/videos/splash.mp4');
			finishSplash();
			return;
		}

		startTimer = new FlxTimer().start(PLAY_DELAY, function(_) tryPlay(PLAY_RETRIES));
		#else

		Log.warn('[SplashState] este build no incluye hxvlc, se omite el splash');
		finishSplash();
		#end
	}

	#if hxvlc
	function tryPlay(retries:Int):Void
	{
		startTimer = null;
		if (finished || video == null) return;

		var started = false;
		try
		{
			started = video.play();
		}
		catch (e:Dynamic)
		{
			Log.error('[SplashState] error al reproducir: $e');
		}

		if (!started && retries > 0)
			startTimer = new FlxTimer().start(PLAY_DELAY * 2, function(_) tryPlay(retries - 1));
	}

	function fitVideo():Void
	{
		if (video == null || video.bitmapData == null || video.bitmapData.width <= 0 || video.bitmapData.height <= 0) return;

		video.resizeMode = FlxAxes.NONE;

		var game = FlxG.scaleMode.gameSize;
		var factor = Math.min(game.x / video.bitmapData.width, game.y / video.bitmapData.height);
		video.width = video.bitmapData.width * factor;
		video.height = video.bitmapData.height * factor;
		video.x = (game.x - video.width) / 2;
		video.y = (game.y - video.height) / 2;
		ready = true;
	}

	function onGameResized(width:Int, height:Int):Void
		fitVideo();

	function releaseVideo():Void
	{
		if (startTimer != null)
		{
			startTimer.cancel();
			startTimer = null;
		}
		FlxG.signals.gameResized.remove(onGameResized);

		if (video == null) return;
		var old = video;
		video = null;
		try
		{
			old.stop();
		}
		catch (e:Dynamic) {}
		FlxG.removeChild(old);
		old.dispose();
	}
	#end

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (finished)
			return;

		if (TouchNav.tapped() || FlxG.mouse.justPressed || FlxG.keys.justPressed.ANY || KeyBinds.justPressed(KeyBinds.ACCEPT))
		{
			finishSplash();
			return;
		}

		if (ended)
		{
			finishSplash();
			return;
		}

		if (!ready)
		{
			waited += elapsed;
			if (waited > START_TIMEOUT)
			{
				Log.warn('[SplashState] el video no arranco en ${START_TIMEOUT}s, se salta');
				finishSplash();
			}
		}
	}

	function finishSplash():Void
	{
		if (finished)
			return;

		finished = true;

		// Solo cuenta como "ya se vio" si el video llego a arrancar (si faltaba el addon, se vuelve a intentar luego).
		if (ready)
		{
			ClientPrefs.setSplashSeen(true);
			ClientPrefs.save();
		}

		#if hxvlc
		releaseVideo();
		#end
		FlxG.switchState(new TitleState());
	}

	override public function destroy():Void
	{
		#if hxvlc
		releaseVideo();
		#end
		super.destroy();
	}
}
