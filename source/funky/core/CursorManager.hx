package funky.core;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import funky.core.Paths;

class CursorManager
{
	public static function init():Void
	{
		var atlas:FlxAtlasFrames = Paths.getSparrowAtlas("cursor");
		if (atlas == null) return;

		var frame = atlas.getByName("idle0000");
		if (frame == null)
		{
			trace('[CursorManager] no existe el frame en el atlas');
			return;
		}

		FlxG.mouse.load(frame.paint());
	}
}
