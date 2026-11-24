package funky.editors.charter;

import flixel.FlxState;
import funky.backend.chart.Chart;
import haxe.io.Path;

class CharterLauncher {
	static var inited:Bool = false;

	public static function open(levelName:String):FlxState {
		if (!inited) {
			inited = true;
			funky.backend.system.Conductor.init();
		}
		Chart.levelDir = Path.join([funky.backend.core.Paths.levelsRoot(), levelName]);
		Paths.levelDir = Chart.levelDir;
		// El juego es la base y el charter se abre encima como substate (ver PlayState.editorHost).
		funky.game.PlayState.editorHost = true;
		funky.game.PlayState.hostLevel = levelName;
		return new funky.game.PlayState();
	}
}
