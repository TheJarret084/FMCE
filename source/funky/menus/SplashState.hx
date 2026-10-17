package funky.menus;

import flixel.FlxG;
import flixel.FlxState;
import flixel.util.FlxColor;
import funky.backend.FunkinVideoSprite;
import funky.core.ClientPrefs;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.TouchNav;

class SplashState extends FlxState
{
	/** Si el video no arranca en este tiempo (seg) se pasa al TITLE para no quedarse en negro. */
	static inline var START_TIMEOUT:Float = 6;

	var video:FunkinVideoSprite;
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

		video = new FunkinVideoSprite();
		video.scrollFactor.set(0, 0);
		add(video);

		#if hxvlc
		// Hasta que el video no avisa su formato no hay textura: ahi recien se puede escalar y centrar.
		video.bitmap.onFormatSetup.add(fitVideo);
		video.bitmap.onEndReached.add(() -> ended = true);
		video.bitmap.onEncounteredError.add(error ->
		{
			Log.warn('[SplashState] error del video: $error');
			ended = true;
		});
		#end

		var loaded = video.loadVideo("splash", false);

		// Sin hxvlc o con el video roto no hay nada que mostrar: al TITLE.
		if (!loaded)
		{
			finishSplash();
			return;
		}

		video.play();
	}

	/** Ajusta el video a la pantalla manteniendo la proporcion (bandas negras si no coincide). */
	function fitVideo():Void
	{
		if (video == null || video.frameWidth <= 0 || video.frameHeight <= 0) return;

		var factor = Math.min(FlxG.width / video.frameWidth, FlxG.height / video.frameHeight);
		video.setGraphicSize(Std.int(video.frameWidth * factor), Std.int(video.frameHeight * factor));
		video.updateHitbox();
		video.screenCenter();
		ready = true;
	}

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
		if (video != null) video.stop();
		#end
		FlxG.switchState(TitleState.new);
	}
}
