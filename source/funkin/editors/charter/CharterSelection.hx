package funkin.editors.charter;

import flixel.FlxG;
import flixel.FlxState;
import funkin.backend.chart.Chart;

/** "Salir del charter": no muestra nada, vuelve a las herramientas del modo avanzado del nivel. */
class CharterSelection extends FlxState {
	public override function create() {
		super.create();
		var level = Chart.levelName;
		FlxG.switchState(() -> new advanced.AdvancedToolsState(level));
	}
}
