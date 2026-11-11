package funky.backend.chart;

typedef FNMMChart = {
	var name:String;
	var bpm:Float;
	var notes:Array<FNMMNote>;
	var events:Array<Dynamic>;
	var musicPath:Null<String>;

	@:optional var voicesPath:Null<String>;

	@:optional var levelDir:Null<String>;

	@:optional var laneCount:Int;

	@:optional var iconPlayer:Null<String>;
	@:optional var iconOpponent:Null<String>;

	@:optional var stepsPerBeat:Float;

	@:optional var actionPacks:Array<Array<Dynamic>>;

	@:optional var stage:Null<String>;

	@:optional var color:Null<String>;
}
