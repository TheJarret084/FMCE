package funkin.game;

import funkin.backend.chart.ChartData;

class PlayState {
	public static var SONG:ChartData;
	public static var chartingMode:Bool = false;
	public static var opponentMode:Bool = false;
	public static var instance:Dynamic = null;

	public static function loadSong():Void {
		SONG = funkin.backend.chart.Chart.load(funkin.backend.chart.Chart.levelDir);
	}
}
