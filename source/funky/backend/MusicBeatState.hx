package funky.backend;

import flixel.FlxState;
import funky.core.TransitionHandler;

class MusicBeatState extends FlxState
{

	var transitioning:Bool = false;

	public function transitionTo(nextState:FlxState):Void
	{
		if (transitioning) return;
		transitioning = true;
		persistentDraw = true;
		TransitionHandler.switchState(nextState);
	}

	public function transitionIn():Void
	{
		persistentDraw = true;
		TransitionHandler.playIn(this);
	}
}
