package funky.menus;

import funky.api.DiscordClient;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funky.core.ClientPrefs;
import funky.core.CoolUtil;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.game.PlayState;
import funky.menus.options.BackButton;

private enum Phase
{
	DYING;
	LOOP;
	ENDING;
}

/** Game over: el BF muerto de `menus/gameover/bf-dead` sobre fondo negro. */
class GameOverSubState extends FlxSubState
{
	/** Frame de "BF dies" en el que entra la musica, como en el FNF original. */
	static inline var MUSIC_FRAME:Int = 12;

	/** Segundos sin input al morir: evita que los dedos/teclas del juego reinicien sin querer. */
	static inline var INPUT_DELAY:Float = 0.6;

	/** "BF Dead confirm" tiene el frame 64px mas alto por arriba: se sube el sprite para que BF no salte. */
	static inline var CONFIRM_SHIFT:Float = 64;

	static var font:Null<String> = null;
	static var fontLoaded:Bool = false;

	var playState:PlayState;
	var phase:Phase = DYING;
	var age:Float = 0;
	var musicStarted:Bool = false;
	var leaving:Bool = false;
	var hasBf:Bool = false;

	var bg:FlxSprite;
	var bf:FlxSprite;
	var hint:FlxText;
	var exitButton:FlxSprite;

	public function new(playState:PlayState)
	{
		super();
		this.playState = playState;
	}

	override public function create():Void
	{
		super.create();

		if (!fontLoaded)
		{
			fontLoaded = true;
			font = Paths.fontPath("PhantomMuff.ttf");
		}

		playState.pauseSong();
		DiscordClient.gameOverPresence(playState.songLabel(), playState.misses, true);

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		bg.alpha = 0;
		add(bg);
		FlxTween.tween(bg, {alpha: 1}, 0.25);

		bf = new FlxSprite();
		var frames = Paths.getFrames("menus/gameover/bf-dead");
		if (frames != null)
		{
			bf.frames = frames;
			bf.animation.addByPrefix("firstDeath", "BF dies", 24, false);
			bf.animation.addByPrefix("deathLoop", "BF Dead Loop", 24, true);
			bf.animation.addByPrefix("deathConfirm", "BF Dead confirm", 24, false);
			hasBf = bf.animation.getByName("firstDeath") != null && bf.animation.getByName("deathLoop") != null
				&& bf.animation.getByName("deathConfirm") != null;
		}

		if (hasBf)
		{
			bf.antialiasing = true;
			bf.animation.play("firstDeath");
			bf.screenCenter();
			bf.y += 30;
			add(bf);
		}
		else
		{
			Log.warn("[GameOverSubState] falta menus/gameover/bf-dead (o sus animaciones), se muestra solo el texto");
			var title = new FlxText(0, FlxG.height / 2 - 60, FlxG.width, "GAME OVER", 72);
			title.setFormat(font, 72, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			add(title);
		}

		var hintText = TouchNav.MOBILE ? "TOCA PARA REINTENTAR" : KeyBinds.label(KeyBinds.ACCEPT) + " REINTENTAR   |   " + KeyBinds.label(KeyBinds.BACK) + " SALIR";
		hint = new FlxText(0, FlxG.height - 70, FlxG.width, hintText, 24);
		hint.setFormat(font, 24, 0xFFD8D8E0, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.alpha = 0;
		add(hint);

		if (TouchNav.MOBILE)
		{
			exitButton = BackButton.available() ? new BackButton(FlxG.width - BackButton.SIZE - 20, FlxG.height - 110) : TouchNav.button("SALIR", FlxG.width - 240, FlxG.height - 76, 220);
			exitButton.alpha = 0;
			add(exitButton);
		}

		CoolUtil.playSound("gameOverSFX");
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		age += elapsed;

		// BF dies -> musica a mitad -> BF Dead Loop.
		if (phase == DYING)
		{
			if (hasBf)
			{
				var current = bf.animation.curAnim;
				if (current != null)
				{
					if (!musicStarted && current.curFrame >= MUSIC_FRAME) startMusic();
					if (current.finished) enterLoop();
				}
			}
			else if (age > 1)
				enterLoop();
		}

		if (phase == LOOP)
		{
			hint.alpha = Math.min(1, hint.alpha + elapsed * 2);
			if (exitButton != null) exitButton.alpha = hint.alpha;
		}

		if (leaving || age < INPUT_DELAY) return;

		if (KeyBinds.justPressed(KeyBinds.BACK) || TouchNav.hit(exitButton))
		{
			exit();
			return;
		}

		// Tocar la pantalla solo reintenta cuando BF ya termino de caer.
		if (KeyBinds.justPressed(KeyBinds.ACCEPT) || (phase == LOOP && TouchNav.tapped())) retry();
	}

	function enterLoop():Void
	{
		phase = LOOP;
		if (hasBf) bf.animation.play("deathLoop");
		startMusic();
	}

	function startMusic():Void
	{
		if (musicStarted) return;
		musicStarted = true;
		try
		{
			FlxG.sound.playMusic(Paths.music("GameOver"), 1, true);
			ClientPrefs.applyAudio();
		}
		catch (e:Dynamic)
		{
			Log.warn("[GameOverSubState] no se pudo cargar GameOver.ogg: " + e);
		}
	}

	function retry():Void
	{
		leaving = true;
		phase = ENDING;
		FlxG.sound.music?.stop();
		playState.stopVoices();
		CoolUtil.playSound("gameOverEnd");

		if (hasBf)
		{
			bf.animation.play("deathConfirm", true);
			bf.y -= CONFIRM_SHIFT;
		}
		hint.visible = false;
		if (exitButton != null) exitButton.visible = false;

		new FlxTimer().start(1.6, function(_)
		{
			playState.transitionTo(new LoadingLevelState());
		});
	}

	function exit():Void
	{
		leaving = true;
		FlxG.sound.music?.stop();
		playState.stopVoices();
		playState.transitionTo(new FreeplayState());
	}

	override public function destroy():Void
	{
		super.destroy();
		Log.info("[GameOverSubState] closed");
	}
}
