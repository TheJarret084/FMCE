package funkin.backend;

import flixel.group.FlxGroup;

class MusicBeatGroup extends FlxTypedGroup<flixel.FlxBasic> implements funkin.backend.system.interfaces.IBeatReceiver
{
	public var curStep(get, never):Int; inline function get_curStep() return funkin.backend.system.Conductor.curStep;
	public var curBeat(get, never):Int; inline function get_curBeat() return funkin.backend.system.Conductor.curBeat;
	public var curMeasure(get, never):Int; inline function get_curMeasure() return funkin.backend.system.Conductor.curMeasure;
	public function stepHit(curStep:Int):Void {}
	public function beatHit(curBeat:Int):Void {}
	public function measureHit(curMeasure:Int):Void {}
}
