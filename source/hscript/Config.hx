package hscript;

class Config
{
	public static final ALLOWED_CUSTOM_CLASSES:Array<String> = [
		"flixel",
		"funky.backend.FunkinSprite",
		"funky.game.LevelSprite",
	];

	public static final ALLOWED_ABSTRACT_AND_ENUM:Array<String> = [
		"flixel",
		"openfl.display.BlendMode",
		"funky.backend.FunkinSprite",
	];

	public static final DISALLOW_CUSTOM_CLASSES:Array<String> = [];

	public static final DISALLOW_ABSTRACT_AND_ENUM:Array<String> = [];

	@:unreflective
	public static final IMPORT_BLACKLIST:Array<String> = [];
}
