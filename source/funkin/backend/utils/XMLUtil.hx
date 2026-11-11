package funkin.backend.utils;

typedef TextFormat = {
	var format:Dynamic;
	var text:String;
}

class XMLUtil {
	public static function createSpriteFromXML(node:Dynamic, ?folder:String, ?anim:Dynamic):funkin.backend.FunkinSprite
		return new funkin.backend.FunkinSprite();
}
