package funky.backend.chart;

typedef FNMMNote = {
	var time:Float;
	var lane:Int;
	var length:Float;
	var mustPress:Bool;

	@:optional var line:Int;

	@:optional var onPress:Int;
	@:optional var onMiss:Int;
}
