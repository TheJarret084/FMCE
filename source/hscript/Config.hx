package hscript;

/** Sobrescribe `hscript.Config` de hscript-improved (igual que hace Codename Engine). */
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
		"funky.backend.FunkinSprite", // PlayAnimContext y XMLAnimType
	];

	// Si alguna clase falla al compilar con el macro, agregala aqui (nombre de modulo).
	public static final DISALLOW_CUSTOM_CLASSES:Array<String> = [];

	public static final DISALLOW_ABSTRACT_AND_ENUM:Array<String> = [];

	@:unreflective
	public static final IMPORT_BLACKLIST:Array<String> = [];
}
