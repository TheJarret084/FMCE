package funky.core;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import funky.core.Paths;
import funky.game.PlayState;

class CursorManager
{

	public static var forceHidden:Bool = false;

	static var ready:Bool = false;

	public static function init():Void
	{
		if (ready) return;
		ready = true;

		var atlas:FlxAtlasFrames = Paths.getSparrowAtlas("cursor");
		if (atlas != null)
		{
			var frame = atlas.getByName("idle0000");
			if (frame == null)
				trace('[CursorManager] no existe el frame en el atlas');
			else
				FlxG.mouse.load(frame.paint());
		}

		FlxG.signals.postUpdate.add(apply);
		apply();
	}

	public static function shouldHide():Bool
	{
		if (forceHidden) return true;

		var state = FlxG.state;
		return state != null && Std.isOfType(state, PlayState) && state.subState == null;
	}

	public static function apply():Void
	{
		#if FLX_MOUSE
		FlxG.mouse.enabled = true;
		FlxG.mouse.visible = !shouldHide();
		#end
	}
}
