package funky.core;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import openfl.Assets;

/** The single transition system for FMCE. */
class TransitionHandler
{
	/** Seconds for one half of a full out+in pair. */
	public static var duration:Float = 2.0 / 3.0;

	/** The transition currently on screen, or null. */
	public static var active:Null<TransitionSubState> = null;

	/** Curtain out of `FlxG.state` and into `next`. */
	public static function switchState(next:FlxState):Void
	{
		if (next == null) return;

		// No state yet (very early boot) or a transition already running.
		if (FlxG.state == null || active != null)
		{
			FlxG.switchState(next);
			return;
		}

		FlxG.state.openSubState(new TransitionSubState(next, true));
	}

	/** Curtain into `state`, revealing what `state` just built. */
	public static function playIn(state:FlxState):Void
	{
		if (state == null || active != null) return;
		state.openSubState(new TransitionSubState(null, false));
	}
}

/** The curtain itself. Instantiated only by TransitionHandler. */
class TransitionSubState extends FlxSubState
{
	var nextState:FlxState;
	var transOut:Bool;
	var transitionCamera:FlxCamera;
	var edgeTop:FlxSprite;
	var body:FlxSprite;
	var edgeBottom:FlxSprite;
	var tween:FlxTween;
	var finished:Bool = false;

	public function new(nextState:FlxState, transOut:Bool)
	{
		super();
		this.nextState = nextState;
		this.transOut = transOut;
	}

	override public function create():Void
	{
		super.create();

		TransitionHandler.active = this;

		transitionCamera = new FlxCamera();
		transitionCamera.bgColor = 0;
		FlxG.cameras.add(transitionCamera, false);
		cameras = [transitionCamera];

		var height = FlxG.height;

		// Solid body, 1px taller on each side so the soft edges never leave a seam.
		body = new FlxSprite(0, -1);
		body.makeGraphic(1, 1, FlxColor.BLACK);
		body.scale.set(FlxG.width, height + 2);
		body.updateHitbox();
		add(body);

		// The soft edges are decoration. If the asset is missing the black body
		// still covers and slides, so fail soft instead of leaving a half-built curtain.
		var path = Paths.image("menus/transitionSpr");
		if (Assets.exists(path))
		{
			edgeTop = makeEdge(path, -height, true);
			edgeBottom = makeEdge(path, height, false);
		}

		var travel = height * 2;
		if (transOut)
		{
			// Comes in from above and STAYS covering: the state change happens hidden.
			transitionCamera.scroll.y = travel;
			tween = FlxTween.tween(transitionCamera.scroll, {y: 0}, TransitionHandler.duration,
				{ease: FlxEase.sineOut, onComplete: function(_) finish()});
		}
		else
		{
			// Starts already covering (where the out curtain stopped) and keeps
			// going down, uncovering the new state.
			transitionCamera.scroll.y = 0;
			tween = FlxTween.tween(transitionCamera.scroll, {y: -travel}, TransitionHandler.duration,
				{ease: FlxEase.sineIn, onComplete: function(_) finish()});
		}
	}

	/** One soft edge: opaque side toward the body, fading away from it. */
	function makeEdge(path:String, y:Float, flip:Bool):FlxSprite
	{
		var edge = new FlxSprite(0, y);
		edge.loadGraphic(path);
		edge.setGraphicSize(FlxG.width, FlxG.height);
		edge.updateHitbox();
		edge.antialiasing = true;
		edge.flipY = flip;
		add(edge);
		return edge;
	}

	function finish():Void
	{
		if (finished) return;
		finished = true;

		if (tween != null)
		{
			tween.cancel();
			tween = null;
		}

		if (nextState != null)
			FlxG.switchState(nextState);
		else
			close();
	}

	override public function destroy():Void
	{
		if (tween != null) tween.cancel();
		tween = null;

		if (transitionCamera != null && FlxG.cameras.list.contains(transitionCamera))
			FlxG.cameras.remove(transitionCamera);
		transitionCamera = null;

		edgeTop = null;
		body = null;
		edgeBottom = null;

		// Must happen before super.destroy() so a state opening another
		// transition from its own destroy() is not rejected as re-entrant.
		if (TransitionHandler.active == this) TransitionHandler.active = null;

		super.destroy();
	}
}
