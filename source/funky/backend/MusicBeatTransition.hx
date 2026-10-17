package funky.backend;

import flixel.FlxState;
import funky.core.TransitionHandler.TransitionSubState;

/** This was the original FMCE curtain. */
@:deprecated("Use TransitionHandler.switchState() / TransitionHandler.playIn()")
class MusicBeatTransition extends TransitionSubState
{
	/** `transOut` is always true: this class only ever left a state. */
	public function new(nextState:FlxState)
	{
		super(nextState, true);
	}
}
