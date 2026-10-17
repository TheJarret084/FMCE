package funkin.game;

/** FMCE no tiene personajes tipo Codename: solo se usan los nombres para elegir iconos. */
class Character {
	/** Nombres de iconos disponibles (carpetas `sprites/` del nivel abierto, si hay). */
	public static var iconNames:Array<String> = [];

	public static function getList(mods:Bool = false, ?source:Dynamic):Array<String> return iconNames.copy();
	public static function getIconFromCharName(name:String):String return name == null ? "face" : name;
}
