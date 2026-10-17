package funkin.game;

import funkin.backend.chart.ChartData;

/** Estado que el charter de Codename espera de PlayState. El juego real es `funky.game.PlayState`. */
class PlayState {
	public static var SONG:ChartData;
	public static var chartingMode:Bool = false;
	public static var opponentMode:Bool = false;
	public static var instance:Dynamic = null;

	/** Carga el nivel abierto (`Chart.levelDir`): chart.json + events.json + meta.json. */
	public static function loadSong():Void {
		SONG = funkin.backend.chart.Chart.load(funkin.backend.chart.Chart.levelDir);
	}
}
