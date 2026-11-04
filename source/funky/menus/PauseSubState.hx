package funky.menus;

import funky.api.DiscordClient;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import funky.core.ClientPrefs;
import funky.core.CoolUtil;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.Paths;
import funky.core.NavPad;
import funky.core.TouchNav;
import funky.game.PlayState;
import funky.menus.options.BackButton;
import funky.menus.options.ConfigSubState;

private enum Page
{
	MAIN;
	CONFIRM;
}

private typedef Row =
{
	var text:String;
	var action:String;
}

/**
 * Pausa estilo Impostor Legacy: fondo que se oscurece, opciones grandes con borde pegadas a la
 * izquierda que se deslizan al elegirlas, titulo de la cancion arriba a la derecha y un boton para
 * "echar un vistazo" al juego sin salir de la pausa (el `looksie` de Legacy; TAB o tocar en
 * movil).
 */
class PauseSubState extends FlxSubState
{
	/** Acciones que piden confirmacion. */
	static final CONFIRMED = ["convert", "freeplay", "quit"];

	/** Escala del Among Us bailarin (el frame original mide 17x15). */
	static inline var DANCER_SCALE:Int = 4;

	/** Franja de la derecha y espacio del banner dentro de ella (entre el titulo de arriba y el bailarin de abajo). */
	static inline var STRIP_W:Int = 420;
	static inline var BANNER_TOP:Float = 112;
	static inline var BANNER_BOTTOM:Float = 628;

	static var font:Null<String> = null;
	static var fontLoaded:Bool = false;

	var playState:PlayState;
	var page:Page = MAIN;
	var selected:Int = 0;
	var rows:Array<Row> = [];
	var labels:Array<FlxText> = [];
	var alphas:Array<Float> = [];

	var bg:FlxSprite;
	var strip:FlxSprite;
	var banner:Null<FlxSprite>;
	var bannerFrame:Null<FlxSprite>;
	var infoTitle:FlxText;
	var infoSub:FlxText;
	var peekButton:FlxText;
	var dancer:Null<FlxSprite>;
	var backIcon:BackButton;
	var navPad:Null<NavPad>;

	var uiAlpha:Float = 0;
	var viewing:Bool = false;
	var chosen:Bool = false;
	var pending:String = null;
	var grace:Int = 0;
	/** Las opciones cambiaron algo que solo se aplica al reiniciar (scroll, middlescroll, botplay, velocidad): se reinicia al volver. */
	var pendingRestart:Bool = false;
	/** Punto de la cancion (ms) al que se salta al dar continuar. Empieza en el tiempo actual; ADELANTAR / RETROCEDER lo mueven. */
	var seekTarget:Float = 0;
	var timeInfo:FlxText;

	public function new(playState:PlayState)
	{
		super();
		this.playState = playState;
		playState.pauseSong();
		seekTarget = playState.songTime;
		DiscordClient.pausePresence(playState.songLabel());
	}

	override public function create():Void
	{
		super.create();

		if (!fontLoaded)
		{
			fontLoaded = true;
			font = Paths.fontPath("Akira_Expanded_Demo.otf");
		}

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		bg.alpha = 0;
		add(bg);

		// Franja lateral a la derecha, donde Legacy pone el retrato del rival.
		strip = new FlxSprite(FlxG.width, 0).makeGraphic(420, FlxG.height, 0xFFFFFFFF);
		strip.scrollFactor.set();
		strip.alpha = 0;
		add(strip);
		FlxTween.tween(strip, {x: FlxG.width - 420}, 0.3, {ease: FlxEase.circOut});

		// Banner en la franja (imagen fija `menus/pause/banner`, el mismo molde que el de Freeplay pero con su propio sprite).
		createBanner();

		var pad = 15;
		infoTitle = new FlxText(0, pad, FlxG.width - pad, playState.songLabel(), 36);
		infoTitle.setFormat(font, 36, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoTitle.borderSize = 2;
		add(infoTitle);

		infoSub = new FlxText(0, pad + 44, FlxG.width - pad, "", 22);
		infoSub.setFormat(font, 22, 0xFFD8D8E0, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(infoSub);

		// Timer de referencia: tiempo actual / duracion; con un salto pendiente muestra a donde se va a saltar.
		timeInfo = new FlxText(0, pad + 44 + 30, FlxG.width - pad, "", 22);
		timeInfo.setFormat(font, 22, 0xFF8CC4FF, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(timeInfo);
		refreshTimeInfo();

		peekButton = new FlxText(20, FlxG.height - 56, 0, TouchNav.MOBILE ? "VER JUEGO" : "TAB: VER JUEGO", 22);
		peekButton.setFormat(font, 22, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(peekButton);

		dancer = makeDancer();
		if (dancer != null) add(dancer);

		// En movil no hay tecla BACK: el boton hace lo mismo (reanudar / volver desde la confirmacion).
		if (TouchNav.MOBILE && BackButton.available())
		{
			backIcon = new BackButton(14, 10);
			add(backIcon);
		}

		navPad = NavPad.make(() -> navigate(-1), () -> navigate(1));
		if (navPad != null) add(navPad);

		CoolUtil.playSound("swoosh", 0.5);
		openPage(MAIN);
	}

	/** Banner fijo: marco oscuro + imagen, centrado en la franja de la derecha. Si la imagen falta, no se muestra. */
	function createBanner():Void
	{
		try
		{
			var sprite = new FlxSprite().loadGraphic(Paths.image("menus/pause/banner"));
			if (sprite.graphic == null || sprite.frameWidth <= 1)
			{
				sprite.destroy();
				return;
			}

			sprite.setGraphicSize(0, Std.int(BANNER_BOTTOM - BANNER_TOP));
			sprite.updateHitbox();
			sprite.antialiasing = true;
			sprite.scrollFactor.set();
			sprite.alpha = 0;

			var finalX = FlxG.width - STRIP_W + (STRIP_W - sprite.width) / 2;
			sprite.setPosition(FlxG.width + (finalX - (FlxG.width - STRIP_W)), BANNER_TOP);

			var frame = new FlxSprite().makeGraphic(1, 1, 0xFF000000);
			frame.scale.set(sprite.width + 16, sprite.height + 16);
			frame.updateHitbox();
			frame.setPosition(sprite.x - 8, sprite.y - 8);
			frame.scrollFactor.set();
			frame.alpha = 0;

			add(frame);
			add(sprite);
			banner = sprite;
			bannerFrame = frame;

			// entra junto con la franja
			FlxTween.tween(sprite, {x: finalX}, 0.3, {ease: FlxEase.circOut});
			FlxTween.tween(frame, {x: finalX - 8}, 0.3, {ease: FlxEase.circOut});
		}
		catch (e:Dynamic)
		{
			Log.warn('[PauseSubState] no se pudo cargar el banner: ' + Std.string(e));
			banner = null;
			bannerFrame = null;
		}
	}

	/** El mini Among Us de `menus/pause/texture` (animacion "dance", en bucle), abajo a la derecha. */
	function makeDancer():Null<FlxSprite>
	{
		var atlas = Paths.getFrames("menus/pause/texture");
		if (atlas == null)
		{
			Log.warn("[PauseSubState] falta menus/pause/texture, no hay bailarin");
			return null;
		}

		var sprite = new FlxSprite();
		sprite.frames = atlas;
		sprite.animation.addByPrefix("dance", "dance", 24, true);
		if (sprite.animation.getByName("dance") == null)
		{
			Log.warn("[PauseSubState] menus/pause/texture no tiene la animacion \"dance\"");
			sprite.destroy();
			return null;
		}

		sprite.animation.play("dance");
		sprite.antialiasing = false; // pixel art
		sprite.scale.set(DANCER_SCALE, DANCER_SCALE);
		sprite.updateHitbox();
		sprite.scrollFactor.set();
		sprite.setPosition(FlxG.width - sprite.width - 28, FlxG.height - sprite.height - 22);
		return sprite;
	}

	function openPage(next:Page):Void
	{
		page = next;
		selected = 0;
		rows = switch (next)
		{
			case MAIN:
				[
					{text: "REANUDAR", action: "resume"},
					{text: "REINICIAR", action: "restart"},
					{text: "ADELANTAR " + Std.int(PlayState.SEEK_STEP_MS / 1000) + "S", action: "forward"},
					{text: "RETROCEDER " + Std.int(PlayState.SEEK_STEP_MS / 1000) + "S", action: "backward"},
					{text: "OPCIONES", action: "options"},
					{text: "CONVERTIDOR", action: "convert"},
					{text: "SALIR", action: "freeplay"}
				];
			case CONFIRM:
				[
					{text: "NO, VOLVER", action: "no"},
					{text: "SI, " + describe(pending), action: "yes"}
				];
		}
		infoSub.text = next == MAIN ? "PAUSA" : "SE PIERDE EL PROGRESO DE LA CANCION";
		if (timeInfo != null) timeInfo.visible = next == MAIN;
		buildLabels();
	}

	function buildLabels():Void
	{
		for (label in labels)
		{
			remove(label, true);
			label.destroy();
		}
		labels = [];
		alphas = [];

		var scale = Math.min(300 / (rows.length * 60), 1);
		for (i in 0...rows.length)
		{
			var item = new FlxText(-640, 0, 0, rows[i].text, Std.int(48 * scale));
			item.setFormat(font, Std.int(48 * scale), FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			item.borderSize = 2;
			item.y = FlxG.height / 2 + i * 60 * scale - item.height;
			add(item);
			labels.push(item);
			alphas.push(0.3);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var r = FlxMath.bound(elapsed * 15.6, 0, 1);
		uiAlpha = FlxMath.lerp(uiAlpha, viewing ? 0 : 1, r);
		bg.alpha = FlxMath.lerp(bg.alpha, viewing ? 0 : 0.8, r);
		strip.alpha = 0.16 * uiAlpha;
		if (banner != null) banner.alpha = uiAlpha;
		if (bannerFrame != null) bannerFrame.alpha = 0.45 * uiAlpha;
		infoTitle.alpha = uiAlpha;
		infoSub.alpha = uiAlpha;
		timeInfo.alpha = uiAlpha;
		peekButton.alpha = FlxMath.lerp(peekButton.alpha, viewing ? 0.3 : 1, r);
		if (dancer != null) dancer.alpha = uiAlpha;
		if (backIcon != null) backIcon.alpha = uiAlpha;
		if (navPad != null) navPad.visible = !viewing;

		for (i in 0...labels.length)
		{
			var label = labels[i];
			label.x = FlxMath.lerp(label.x, (i == selected ? 75 : 55) + (navPad != null ? NavPad.WIDTH : 0), r);
			alphas[i] = FlxMath.lerp(alphas[i], i == selected ? 1 : 0.3, r);
			label.alpha = alphas[i] * uiAlpha;
		}

		// Volvio de Opciones con algo que pide reiniciar: se reinicia aqui (ya sin el substate de opciones encima).
		if (pendingRestart && !chosen && subState == null)
		{
			pendingRestart = false;
			chosen = true;
			playState.restartSong();
			return;
		}

		// Ignorar input una vez elegida una salida (la cortina va a tomar el control) o justo al volver de Opciones.
		if (chosen) return;
		if (grace > 0)
		{
			grace--;
			return;
		}

		#if desktop
		if (FlxG.keys.justPressed.TAB) setViewing(!viewing);
		#end
		if (TouchNav.hit(peekButton)) setViewing(!viewing);

		if (viewing)
		{
			// Cualquier toque, ENTER o BACK vuelve al menu.
			if (KeyBinds.justPressed(KeyBinds.BACK) || KeyBinds.justPressed(KeyBinds.ACCEPT) || TouchNav.tapped()) setViewing(false);
			return;
		}

		if (KeyBinds.justPressed(KeyBinds.UP)) changeSelection(-1);
		if (KeyBinds.justPressed(KeyBinds.DOWN)) changeSelection(1);

		var backTapped = backIcon != null && TouchNav.hit(backIcon);
		if (backTapped) backIcon.press();
		if (KeyBinds.justPressed(KeyBinds.BACK) || backTapped)
		{
			switch (page)
			{
				case MAIN:
					CoolUtil.playMenuSound("cancel", 0.5);
					choose("resume");
				case CONFIRM:
					openPage(MAIN);
			}
			return;
		}
		if (KeyBinds.justPressed(KeyBinds.ACCEPT)) choose(rows[selected].action);

		var tapped = TouchNav.rowTapped(labels);
		if (tapped >= 0 && (navPad == null || !navPad.tapped()))
		{
			if (tapped == selected) choose(rows[selected].action);
			else
			{
				selected = tapped;
				CoolUtil.playMenuSound("scroll", 0.5);
			}
		}
	}

	/** Botones arriba/abajo del movil (mismas reglas que el teclado: no mientras se mira el juego o se sale). */
	function navigate(by:Int):Void
	{
		if (chosen || grace > 0 || viewing) return;
		changeSelection(by);
	}

	function changeSelection(by:Int):Void
	{
		selected = (selected + by + rows.length) % rows.length;
		CoolUtil.playMenuSound("scroll", 0.5);
	}

	function setViewing(value:Bool):Void
	{
		if (viewing == value) return;
		viewing = value;
		CoolUtil.playMenuSound("scroll", 0.5);
	}

	function choose(action:String):Void
	{
		switch (action)
		{
			case "resume":
				chosen = true;
				// Con un salto pendiente (ADELANTAR / RETROCEDER) continuar lo aplica: recarga el nivel en ese punto y entra sin countdown.
				if (!(hasPendingSeek() && playState.seekTo(seekTarget)))
				{
					playState.resumeSong();
					close();
				}
			case "restart":
				chosen = true;
				// The substate is torn down by the state switch, so go through
				// the parent's transition rather than opening a second curtain.
				playState.restartSong();
			case "forward" | "backward":
				moveSeek(action == "forward" ? PlayState.SEEK_STEP_MS : -PlayState.SEEK_STEP_MS);
			case "options":
				openOptions();
			case "no":
				pending = null;
				openPage(MAIN);
			case "convert" | "freeplay" | "quit":
				pending = action;
				openPage(CONFIRM);
			case "yes":
				leave(pending);
		}
	}

	function hasPendingSeek():Bool
		return Math.abs(seekTarget - playState.songTime) >= 1;

	/** Mueve el punto de salto (sin saltar todavia): lo muestra el timer y se aplica al dar continuar. */
	function moveSeek(deltaMs:Float):Void
	{
		var next = playState.clampSeek(seekTarget + deltaMs);
		if (Math.abs(next - seekTarget) < 1)
		{
			CoolUtil.playMenuSound("cancel", 0.5);
			return;
		}
		seekTarget = next;
		CoolUtil.playMenuSound("scroll", 0.5);
		refreshTimeInfo();
	}

	static function clock(ms:Float):String
		return FlxStringUtil.formatTime(Math.floor(Math.max(0, ms) / 1000), false);

	function refreshTimeInfo():Void
	{
		var total = clock(playState.songLengthMs());
		if (!hasPendingSeek())
		{
			timeInfo.text = clock(playState.songTime) + " / " + total;
			return;
		}

		var diff = Math.round((seekTarget - playState.songTime) / 1000);
		timeInfo.text = clock(playState.songTime) + "  >  " + clock(seekTarget) + " / " + total + "  (" + (diff > 0 ? "+" : "") + diff + "S)";
	}

	function openOptions():Void
	{
		// Las opciones traen su propio fondo: esconder el nuestro mientras estan abiertas.
		setPauseVisible(false);
		var before = restartSignature();
		var options = new ConfigSubState();
		options.closeCallback = () ->
		{
			setPauseVisible(true);
			grace = 2;
			// Si cambio algo que "se aplica al reiniciar", se reinicia al volver (en el siguiente update, sin el substate encima).
			if (restartSignature() != before) pendingRestart = true;
		};
		options.cameras = cameras;
		openSubState(options);
	}

	/** Las opciones que solo se aplican al crear el nivel: si cambian, hace falta reiniciar. */
	static function restartSignature():String
		return ClientPrefs.isDownScroll() + "|" + ClientPrefs.isMiddleScroll() + "|" + ClientPrefs.isBotplay() + "|" + ClientPrefs.getScrollSpeed();

	function setPauseVisible(value:Bool):Void
	{
		bg.visible = value;
		strip.visible = value;
		if (banner != null) banner.visible = value;
		if (bannerFrame != null) bannerFrame.visible = value;
		infoTitle.visible = value;
		infoSub.visible = value;
		timeInfo.visible = value;
		peekButton.visible = value;
		if (dancer != null) dancer.visible = value;
		if (backIcon != null) backIcon.visible = value;
		if (navPad != null) navPad.visible = value;
		for (label in labels) label.visible = value;
	}

	/** Salida definitiva ya confirmada. */
	function leave(action:String):Void
	{
		chosen = true;
		// Salir tras un adelantar / retroceder: que el siguiente nivel no herede ese punto de partida (desde el charter si se queda).
		if (PlayState.returnToEditor == null) PlayState.startFromMs = 0;
		switch (action)
		{
			case "convert":
				FlxG.sound.music?.stop();
		playState.stopVoices();
				playState.transitionTo(new ConverterMenuState());
			case "freeplay":
				FlxG.sound.music?.stop();
		playState.stopVoices();
				playState.transitionTo(PlayState.menuState());
			case "quit":
				#if sys
				ClientPrefs.save();
				lime.system.System.exit(0);
				#else
				// There is no exit on this platform. Keep the menu usable
				// rather than leaving the game paused with input locked out.
				chosen = false;
				openPage(MAIN);
				#end
			default:
				chosen = false;
				openPage(MAIN);
		}
	}

	static function describe(action:String):String
	{
		return switch (action)
		{
			case "convert": "IR AL CONVERTIDOR";
			case "freeplay": "SALIR";
			default: "CONTINUAR";
		}
	}

	override public function destroy():Void
	{
		super.destroy();
		labels = [];
		// Log.info('[PauseSubState] closed');
	}
}
