package funkin.backend.chart;

import flixel.util.FlxColor;

typedef ChartData = {
	public var strumLines:Array<ChartStrumLine>;
	public var events:Array<ChartEvent>;
	public var meta:ChartMetaData;
	public var stage:String;
	public var noteTypes:Array<String>;
	public var ?bookmarks:Array<ChartBookmark>;

	public var ?actionPacks:Array<ChartActionPack>;

	public var ?chartVersion:String;
}

typedef ChartMetaData = {
	public var name:String;
	public var ?displayName:String;

	public var ?bpm:Float;
	public var ?beatsPerMeasure:Float;
	public var ?stepsPerBeat:Int;

	public var ?color:FlxColor;

	public var ?iconPlayer:String;
	public var ?iconOpponent:String;

	public var ?instSuffix:String;
	public var ?vocalsSuffix:String;
	public var ?needsVoices:Bool;
}

typedef ChartStrumLine = {
	var characters:Array<String>;
	var type:ChartStrumLineType;
	var notes:Array<ChartNote>;
	var position:String;
	var ?visible:Null<Bool>;
	var ?strumPos:Array<Float>;
	var ?strumScale:Float;
	var ?strumSpacing:Float;
	var ?vocalsSuffix:String;
	var ?keyCount:Int;

	var ?strumLinePos:Float;
}

typedef ChartNote = {
	var time:Float;
	var id:Int;
	var type:Int;
	var sLen:Float;
	var ?onPress:Int;
	var ?onMiss:Int;
}

typedef ChartBookmark = {
	var time:Float;
	var name:String;
	var color:String;
}

typedef ChartActionPack = {
	var actions:Array<ChartEvent>;
	var ?name:String;
}

typedef ChartEvent = {

	var ?raw:Dynamic;
	var name:String;
	var time:Float;
	var params:Array<Dynamic>;

}

enum abstract ChartStrumLineType(Int) from Int to Int {

	var OPPONENT = 0;

	var PLAYER = 1;

	var ADDITIONAL = 2;
}
