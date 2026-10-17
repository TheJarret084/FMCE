package funkin.game;

/** Solo lo que usa el preview de strumline del charter. */
class StrumLine {
	public static function calculateStartingXPosFromInitialWidth(x:Float, scale:Float, spacing:Float, keyCount:Int):Float
		return x - (Note.swagWidth * scale * spacing * (keyCount - 1)) / 2 + 0 * keyCount;
}
