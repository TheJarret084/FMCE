package funkin.editors.charter;

import flixel.ui.FlxBar;
import flixel.ui.FlxBar.FlxBarFillDirection;
import flixel.util.FlxColor;

/**
 * Mini barra de vida del Charter: solo la FlxBar (sin marco ni iconos), igual de colores que la del juego
 * (rojo = oponente, verde = jugador). Va chiquita en la esquina de abajo a la izquierda, sobre la camara de la interfaz,
 * asi que se oculta con "Ocultar interfaz" y no estorba la grilla.
 *
 * El valor lo calcula Charter.updateBarIcons a partir de los eventos PlayerHealth que ya pasaron en el chart.
 */
class CharterHealthBar {
	/** Se recuerda mientras el juego este abierto. */
	public static var enabled:Bool = true;

	/** Tamano de la barra en px. */
	public static var barWidth:Int = 200;
	public static var barHeight:Int = 8;

	/** Distancia a la esquina de abajo a la izquierda. */
	public static var margin:Int = 14;

	public var bar(default, null):FlxBar;

	/** Vida que debe mostrar (0 a 1). */
	public var health(default, null):Float = funky.game.PlayHUD.START_HEALTH;

	var shown:Float = funky.game.PlayHUD.START_HEALTH;
	var charter:Charter;
	var placedW:Int = -1;
	var placedH:Int = -1;

	public function new(charter:Charter) {
		this.charter = charter;
	}

	public function create():Void {
		bar = new FlxBar(0, 0, FlxBarFillDirection.RIGHT_TO_LEFT, barWidth, barHeight, null, "", 0, 1, true);
		bar.scrollFactor.set();
		bar.numDivisions = barWidth;
		bar.createFilledBar(FlxColor.RED, FlxColor.GREEN, true, 0xFF000000);
		bar.alpha = 0.9;
		bar.value = shown;
		bar.cameras = [charter.uiCamera];
		bar.visible = enabled;
		charter.uiGroup.add(bar);
		place();
	}

	public function setEnabled(value:Bool):Void {
		enabled = value;
		if (bar != null) bar.visible = value;
	}

	public function setHealth(value:Float):Void {
		health = value < 0 ? 0 : (value > 1 ? 1 : value);
	}

	function place():Void {
		placedW = FlxG.width;
		placedH = FlxG.height;
		bar.setPosition(margin, FlxG.height - barHeight - margin);
	}

	public function update(elapsed:Float):Void {
		if (bar == null) return;
		if (FlxG.width != placedW || FlxG.height != placedH) place();
		if (!enabled) return;

		// Se acerca al valor real con la misma suavidad que la barra del HUD.
		shown += (health - shown) * Math.min(1, elapsed * 8);
		if (Math.abs(health - shown) < 0.002) shown = health;
		if (bar.value != shown) bar.value = shown;
	}
}
