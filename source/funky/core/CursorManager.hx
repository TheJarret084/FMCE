package funky.core;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import funky.core.Paths;

/**
 * Cambia el cursor normal de Flixel por el frame "idle0000" de
 * assets/images/cursor.png + cursor.xml. Se llama una vez, despues de crear el FlxGame
 * (por ejemplo en el create() del primer state).
 */
class CursorManager
{
	static inline var ATLAS_NAME:String = "cursor";
	static inline var FRAME_NAME:String = "idle0000";

	public static function init():Void
	{
		var atlas:FlxAtlasFrames = Paths.getSparrowAtlas(ATLAS_NAME);
		if (atlas == null) return;

		var frame = atlas.getByName(FRAME_NAME);
		if (frame == null)
		{
			trace('[CursorManager] no existe el frame $FRAME_NAME en el atlas $ATLAS_NAME.');
			return;
		}

		FlxG.mouse.load(frame.paint());
	}
}
