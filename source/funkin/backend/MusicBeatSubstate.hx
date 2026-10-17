package funkin.backend;

import flixel.FlxState;
import flixel.FlxSubState;
import funkin.backend.system.Conductor;
import funkin.backend.system.interfaces.IBeatReceiver;

/** Base de los substates del charter (equivalente al MusicBeatSubstate de Codename, sin scripting). */
class MusicBeatSubstate extends FlxSubState implements IBeatReceiver {
	/** State que abrio este substate (lo asigna MusicBeatState.openSubState). */
	public var parent:FlxState;

	public var curStep(get, never):Int; inline function get_curStep() return Conductor.curStep;
	public var curBeat(get, never):Int; inline function get_curBeat() return Conductor.curBeat;
	public var curMeasure(get, never):Int; inline function get_curMeasure() return Conductor.curMeasure;

	public function new(?scriptsAllowed:Bool = true, ?scriptName:String) {
		super();
		openCallback = function() onSubstateOpen();
		closeCallback = function() onSubstateClose();
	}

	public function onSubstateOpen():Void {}
	public function onSubstateClose():Void {}

	public function stepHit(curStep:Int):Void {}
	public function beatHit(curBeat:Int):Void {}
	public function measureHit(curMeasure:Int):Void {}
}
