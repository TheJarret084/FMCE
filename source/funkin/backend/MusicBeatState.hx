package funkin.backend;

import flixel.FlxState;
import flixel.FlxSubState;
import funkin.backend.system.Conductor;
import funkin.backend.utils.CoolUtil;
import funkin.backend.system.interfaces.IBeatCancellableReceiver;

class MusicBeatState extends FlxState implements IBeatCancellableReceiver {
	public var cancelConductorUpdate:Bool = false;

	public var curStep(get, never):Int; inline function get_curStep() return Conductor.curStep;
	public var curBeat(get, never):Int; inline function get_curBeat() return Conductor.curBeat;
	public var curMeasure(get, never):Int; inline function get_curMeasure() return Conductor.curMeasure;
	public var curStepFloat(get, never):Float; inline function get_curStepFloat() return Conductor.curStepFloat;
	public var curBeatFloat(get, never):Float; inline function get_curBeatFloat() return Conductor.curBeatFloat;
	public var curMeasureFloat(get, never):Float; inline function get_curMeasureFloat() return Conductor.curMeasureFloat;

	public function new(?scriptsAllowed:Bool = true, ?scriptName:String) {
		super();
	}

	public inline function lerp(a:Float, b:Float, ratio:Float):Float return CoolUtil.fpsLerp(a, b, ratio);

	public function stepHit(curStep:Int):Void {}
	public function beatHit(curBeat:Int):Void {}
	public function measureHit(curMeasure:Int):Void {}

	public override function openSubState(subState:FlxSubState) {
		if (subState is MusicBeatSubstate)
			cast(subState, MusicBeatSubstate).parent = this;

		funky.core.Log.info('[Substate] ' + Type.getClassName(Type.getClass(this)) + ' abre ' + Type.getClassName(Type.getClass(subState)));
		super.openSubState(subState);
	}

	public static function swapState(next:FlxState):Void
		FlxG.switchState(next);
}
