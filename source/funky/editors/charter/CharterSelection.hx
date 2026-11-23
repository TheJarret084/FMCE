package funky.editors.charter;

import flixel.FlxG;
import flixel.FlxState;
import funky.backend.chart.Chart;

class CharterSelection extends FlxState {
	public override function create() {
		super.create();
		var level = Chart.levelName;
		FlxG.switchState(new funky.advanced.AdvancedToolsState(level));
	}
}
