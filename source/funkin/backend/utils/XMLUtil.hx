package funkin.backend.utils;

typedef TextFormat = {
	var format:Dynamic;
	var text:String;
}

/** Solo lo que usa el UI portado (los `<image>` de ventanas XML no se usan en FMCE). */
class XMLUtil {
	public static function createSpriteFromXML(node:Dynamic, ?folder:String, ?anim:Dynamic):funkin.backend.FunkinSprite
		return new funkin.backend.FunkinSprite();
}
