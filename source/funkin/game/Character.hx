package funkin.game;

class Character {

	public static var iconNames:Array<String> = [];

	public static function getList(mods:Bool = false, ?source:Dynamic):Array<String> return iconNames.copy();
	public static function getIconFromCharName(name:String):String return name == null ? "face" : name;
}
