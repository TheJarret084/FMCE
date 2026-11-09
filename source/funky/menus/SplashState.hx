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

/** Intro del juego con el video splash y su audio. */
class SplashState extends FlxState
{
	/** Si el video no arranca en este tiempo (seg) se pasa al TITLE para no quedarse en negro. */
	static inline var START_TIMEOUT:Float = 6;

	/** Espera (s) entre `load` y `play`, y reintentos si `play` aun no arranca (hxvlc pide no llamarlo en el mismo instante). */
	static inline var PLAY_DELAY:Float = 0.05;
	static inline var PLAY_RETRIES:Int = 10;

	#if hxvlc
	var video:Null<FlxVideo>;
	var startTimer:Null<FlxTimer>;
	#end

	var finished:Bool = false;

	/** El video ya conoce su tamano (hxvlc avisa en `onFormatSetup`). */
	var ready:Bool = false;
	/** El video llego al final o dio error: se atiende en `update` (los eventos no tocan el State). */
	var ended:Bool = false;
	var waited:Float = 0;

	override public function create():Void
	{
		funky.core.Storage.init();
		super.create();

		FlxG.cameras.bgColor = FlxColor.BLACK;

		// Preferencia "saltar intro": directo al TITLE, sin cargar el video.
		if (ClientPrefs.isSkipIntro())
		{
			finishSplash();
			return;
		}

		#if hxvlc
		video = new FlxVideo();
		// Con el tamano ya conocido se ajusta a la pantalla manteniendo la proporcion (el FlxVideo por defecto la estira).
		video.onFormatSetup.add(fitVideo);
		video.onEndReached.add(() -> ended = true);
		video.onEncounteredError.add(error ->
		{
			Log.warn('[SplashState] error del video: $error');
			ended = true;
		});
		FlxG.signals.gameResized.add(onGameResized);
		FlxG.addChildBelowMouse(video);

		// Sin ":no-audio": el splash suena (el volumen es el del juego).
		var loaded = false;
		try
		{
			loaded = video.load(FunkinVideoSprite.resolve("splash"));
		}
		catch (e:Dynamic)
		{
			Log.error('[SplashState] error cargando el video: $e');
		}

		// Con el video roto no hay nada que mostrar: al TITLE.
		if (!loaded)
		{
			Log.warn('[SplashState] no se pudo cargar addons/videos/splash.mp4');
			finishSplash();
			return;
		}

		startTimer = new FlxTimer().start(PLAY_DELAY, function(_) tryPlay(PLAY_RETRIES));
		#else
		// Sin hxvlc no hay video: al TITLE.
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

	/** Ajusta el video al tamano real del juego en pantalla manteniendo la proporcion (bandas negras si no coincide). */
	function fitVideo():Void
	{
		if (video == null || video.bitmapData == null || video.bitmapData.width <= 0 || video.bitmapData.height <= 0) return;

		// Deja de estirarlo a todo el juego (el `onFormatSetup` del propio FlxVideo ya corrio antes que este).
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

	/** Quita el video de la pantalla y libera el player. */
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

		// Tocar la pantalla (o click / tecla aceptar / cualquier tecla) salta el splash.
		if (TouchNav.tapped() || FlxG.mouse.justPressed || FlxG.keys.justPressed.ANY || KeyBinds.justPressed(KeyBinds.ACCEPT))
		{
			finishSplash();
			return;
		}

		// Termino el video (o fallo): al TITLE.
		if (ended)
		{
			finishSplash();
			return;
		}

		// Si nunca arranca, no dejar al jugador en negro.
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
