package funky.game;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import funky.core.Paths;
import openfl.utils.Assets;

/**
 * Controles tactiles sobre el `Hitbox`: la franja inferior de la pantalla (`Hitbox.HEIGHT_RATIO`)
 * se divide en columnas iguales, una por lane.
 */
class MobileControls extends FlxGroup
{
	/** Lado (px) con el que se dibuja el boton de pausa. */
	static inline var PAUSE_SIZE:Float = 96;
	static inline var PAUSE_MARGIN:Float = 14;
	/** Margen tactil extra alrededor del boton; ahi tampoco se pulsan lanes. */
	static inline var PAUSE_PAD:Float = 40;

	var laneCount:Int;
	var held:Array<Bool> = [];
	var previous:Array<Bool> = [];
	var pressedNow:Array<Bool> = [];
	var hitbox:Hitbox;
	var pauseBtn:FlxSprite;
	var onPause:Void->Void;

	public function new(onPause:Void->Void, laneCount:Int)
	{
		super();
		this.onPause = onPause;
		this.laneCount = laneCount < 1 ? 1 : laneCount;
		for (_ in 0...this.laneCount)
		{
			held.push(false);
			previous.push(false);
			pressedNow.push(false);
		}

		hitbox = new Hitbox(this.laneCount);
		add(hitbox);

		pauseBtn = new FlxSprite();
		var pausePath = Paths.uiImage("pause");
		if (Assets.exists(pausePath)) pauseBtn.loadGraphic(pausePath);
		else pauseBtn.makeGraphic(140, 140, 0xFF8C6CFF);
		pauseBtn.setGraphicSize(Std.int(PAUSE_SIZE), Std.int(PAUSE_SIZE));
		pauseBtn.updateHitbox();
		pauseBtn.setPosition(FlxG.width - pauseBtn.width - PAUSE_MARGIN, PAUSE_MARGIN);
		pauseBtn.scrollFactor.set();
		add(pauseBtn);
	}

	/** true si `poll()` ya leyo los toques de este frame (para no leerlos dos veces). */
	var polled:Bool = false;
	var pauseRequested:Bool = false;

	/**
	 * Lee los dedos y deja `isHeld` / `justPressed` al dia. PlayState lo llama al INICIO de su update:
	 * antes se leia al final del frame, asi que cada pulsacion se juzgaba un frame tarde.
	 */
	public function poll():Void
	{
		if (polled) return;
		polled = true;
		for (lane in 0...laneCount) held[lane] = false;
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			// Pausa: vale al tocar o al soltar encima del boton (un toque muy rapido a veces solo
			// deja el "soltar"), y siempre se descarta para las lanes.
			if ((touch.justPressed || touch.justReleased) && inPause(touch.screenX, touch.screenY)) pauseRequested = true;
			if (inPause(touch.screenX, touch.screenY)) continue;
			if (!touch.pressed || touch.screenY < hitbox.zoneTop) continue;
			held[hitbox.laneAt(touch.screenX)] = true;
		}
		#end
		// Algunos Android mandan el toque tambien como raton: se acepta igual.
		if (FlxG.mouse.justPressed && inPause(FlxG.mouse.screenX, FlxG.mouse.screenY)) pauseRequested = true;
		for (lane in 0...laneCount)
		{
			pressedNow[lane] = held[lane] && !previous[lane];
			previous[lane] = held[lane];
			hitbox.setDown(lane, held[lane]);
		}
	}

	override public function update(elapsed:Float):Void
	{
		poll();
		polled = false;
		super.update(elapsed);
		// La pausa se abre al final del frame, no en medio de procesar las notas.
		if (pauseRequested)
		{
			pauseRequested = false;
			onPause();
		}
	}

	function inPause(x:Float, y:Float):Bool
		return x >= pauseBtn.x - PAUSE_PAD && x <= pauseBtn.x + pauseBtn.width + PAUSE_PAD
			&& y >= pauseBtn.y - PAUSE_PAD && y <= pauseBtn.y + pauseBtn.height + PAUSE_PAD;

	public inline function isHeld(lane:Int):Bool return lane >= 0 && lane < laneCount && held[lane];
	public inline function justPressed(lane:Int):Bool return lane >= 0 && lane < laneCount && pressedNow[lane];
}
