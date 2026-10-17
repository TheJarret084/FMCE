package funky.game;

import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.ui.FlxBar;
import flixel.ui.FlxBar.FlxBarFillDirection;
import flixel.util.FlxColor;
import funky.core.Log;
import funky.core.Paths;

/**
 * Barra de vida con el sprite `assets/images/game/healthBar.png` (el marco negro) como en el
 * legacy (`funkin.objects.Bar`): debajo del marco va un `FlxBar` de derecha a izquierda: el
 * relleno es el color del jugador y el fondo vacio el del oponente.
 */
class HealthBar extends FlxGroup
{
	public static inline var IMAGE:String = "game/healthBar";
	/** Grosor del borde si no se puede medir el PNG. */
	static inline var FALLBACK_BORDER:Int = 6;

	public var x(default, null):Float = 0;
	public var y(default, null):Float = 0;
	/** Tamano total del marco (px). */
	public var frameWidth(default, null):Int;
	public var frameHeight(default, null):Int;
	/** Tamano del hueco donde se ve el relleno (px). */
	public var innerWidth(default, null):Int;
	public var innerHeight(default, null):Int;

	var insetX:Int;
	var insetY:Int;
	var frame:FlxSprite;
	var bar:FlxBar;
	var opponentColor:FlxColor;
	var playerColor:FlxColor;
	var lastSplit:Int = -1;

	/** Cuanto del relleno es del jugador, 0..1 (el ultimo valor que recibio `setHealth`). */
	public var health(default, null):Float = 0.5;

	public function new(opponentColor:FlxColor, playerColor:FlxColor)
	{
		super();
		this.opponentColor = opponentColor;
		this.playerColor = playerColor;
		frame = new FlxSprite().loadGraphic(Paths.image(IMAGE));
		frame.scrollFactor.set();
		frameWidth = Std.int(frame.frameWidth);
		frameHeight = Std.int(frame.frameHeight);
		measureInside();

		// Sin parentRef: `setHealth` le pasa el valor (0..1) a mano, asi no depende de reflexion.
		bar = new FlxBar(0, 0, FlxBarFillDirection.RIGHT_TO_LEFT, innerWidth, innerHeight, null, "", 0, 1, false);
		bar.scrollFactor.set();
		// Un paso por pixel (por defecto son 100 y la barra saltaba a trozos).
		bar.numDivisions = innerWidth;
		bar.createFilledBar(opponentColor, playerColor);
		// Primero la barra y encima el marco, que tapa los bordes.
		add(bar);
		add(frame);
		setHealth(health);
	}

	/** Busca el hueco transparente del marco recorriendo su fila y su columna central. */
	function measureInside():Void
	{
		insetX = FALLBACK_BORDER;
		insetY = FALLBACK_BORDER;
		try
		{
			var pixels = frame.pixels;
			var midX = Std.int(frameWidth / 2);
			var midY = Std.int(frameHeight / 2);
			var left = 0;
			while (left < midX && (pixels.getPixel32(left, midY) >>> 24) != 0) left++;
			var top = 0;
			while (top < midY && (pixels.getPixel32(midX, top) >>> 24) != 0) top++;
			if (left > 0 && left < midX) insetX = left;
			if (top > 0 && top < midY) insetY = top;
		}
		catch (e:Dynamic)
		{
			Log.warn('[HealthBar] no se pudo medir el marco, uso borde ' + FALLBACK_BORDER + ': ' + Std.string(e));
		}
		innerWidth = Std.int(Math.max(1, frameWidth - insetX * 2));
		innerHeight = Std.int(Math.max(1, frameHeight - insetY * 2));
	}

	public function setPosition(newX:Float, newY:Float):Void
	{
		x = newX;
		y = newY;
		frame.setPosition(x, y);
		bar.setPosition(x + insetX, y + insetY);
	}

	/** X (pantalla) del borde entre los dos rellenos para una vida de jugador `value` (0..1). */
	public inline function edgeX(value:Float):Float
		return x + insetX + innerWidth * (1 - Math.max(0, Math.min(1, value)));

	public inline function centerY():Float return y + frameHeight / 2;

	/** Vida del jugador, 0..1. Solo se actualiza la barra cuando el borde cambia de pixel. */
	public function setHealth(value:Float):Void
	{
		health = Math.max(0, Math.min(1, value));
		var split = Math.round(innerWidth * (1 - health));
		if (split == lastSplit) return;
		lastSplit = split;
		bar.value = health;
	}

	public function setColors(opponentColor:FlxColor, playerColor:FlxColor):Void
	{
		this.opponentColor = opponentColor;
		this.playerColor = playerColor;
		bar.createFilledBar(opponentColor, playerColor);
		bar.value = health;
	}
}
