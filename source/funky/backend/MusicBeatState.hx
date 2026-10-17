package funky.backend;

import flixel.FlxState;
import funky.core.TransitionHandler;

/** Shared state base, placed like Codename's state foundation. */
class MusicBeatState extends FlxState
{
	/** true en cuanto empieza una transicion: evita que una tecla sostenida salte estados. */
	var transitioning:Bool = false;

	/** Curtain out of this state and into `nextState`. */
	public function transitionTo(nextState:FlxState):Void
	{
		if (transitioning) return;
		transitioning = true;
		persistentDraw = true;
		TransitionHandler.switchState(nextState);
	}

	/** Curtain into this state, uncovering whatever `create()` just built. */
	public function transitionIn():Void
	{
		persistentDraw = true;
		TransitionHandler.playIn(this);
	}
}
