package funkin.editors.charter;

import flixel.FlxState;
import funkin.backend.chart.Chart;
import haxe.io.Path;

/** Punto de entrada del charter: `go(CharterLauncher.open("MiNivel"))` desde el modo avanzado (solo escritorio). */
class CharterLauncher {
	static var inited:Bool = false;

	public static function open(levelName:String):FlxState {
		if (!inited) {
			inited = true;
			funkin.backend.system.Conductor.init();
		}
		Chart.levelDir = Path.join([funky.core.Paths.levelsRoot(), levelName]);
		Paths.levelDir = Chart.levelDir;
		return new Charter(levelName, true);
	}
}
