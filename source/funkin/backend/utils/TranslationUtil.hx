package funkin.backend.utils;

import funkin.backend.utils.Translations;

/**
 * Fachada compatible con Codename Engine (`TU`).
 *
 * Todo el trabajo lo hace `Translations`; aqui solo queda la API que usan
 * los editores portados y los menus de FMCE.
 */
class TranslationUtil
{
	/** Idioma actual (`es`, `en`...). */
	public static var curLanguage(get, set):String;
	/** Nombre visible del idioma actual. */
	public static var curLanguageName(get, set):String;
	/** Lista `codigo/Nombre` de los idiomas encontrados. */
	public static var foundLanguages(get, never):Array<String>;
	/** Config del idioma actual. */
	public static var config(get, never):Map<String, String>;
	/** `true` si el idioma actual es el de por defecto. */
	public static var isDefaultLanguage(get, never):Bool;
	/** `true` si hay alguna traduccion cargada. */
	public static var isLanguageLoaded(get, never):Bool;

	/** Carga los idiomas y el guardado. Llamar una vez al arrancar. */
	public static function init():Void
	{
		Translations.ensureLoaded();
	}

	public static function ensureLoaded():Void
		Translations.ensureLoaded();

	public static function setLanguage(?name:String):Void
	{
		Translations.ensureLoaded();
		Translations.setLanguage(name == null ? Translations.getLanguage() : name);
	}

	public static function rescan():Void
		Translations.rescan();

	public static function exists(id:String):Bool
		return Translations.exists(id);

	public static function translate(?id:String, ?params:Array<Dynamic>, ?def:String):String
		return Translations.translate(id, params, def);

	public static function get(?id:String, ?params:Array<Dynamic>, ?def:String):String
		return Translations.translate(id, params, def);

	public static function translateDiff(?id:String, ?params:Array<Dynamic>):String
		return Translations.translateDiff(id, params);

	/** Texto sin formatear; conserva `.format([...])` gracias a `using CoolUtil`. */
	public static function getRaw(id:String, ?def:String):String
		return Translations.raw(id, def);

	public static function raw(id:String, ?def:String):String
		return Translations.raw(id, def);

	public static function raw2Id(raw:String):String
		return Translations.raw2Id(raw);

	public static function getLanguageName(code:String):String
		return Translations.getLanguageName(code);

	public static function getLanguageFromName(name:String):String
		return Translations.getLanguageFromName(name);

	public static function getConfig(code:String):Map<String, String>
		return Translations.getConfig(code);

	public static function humanize(id:String):String
		return Translations.humanize(id);

	// getters/setters

	static function get_curLanguage():String
	{
		Translations.ensureLoaded();
		return Translations.getLanguage();
	}

	static function set_curLanguage(value:String):String
	{
		Translations.setLanguage(value);
		return Translations.getLanguage();
	}

	static function get_curLanguageName():String
		return Translations.getLanguageName(get_curLanguage());

	static function set_curLanguageName(value:String):String
	{
		set_curLanguage(Translations.getLanguageFromName(value));
		return get_curLanguageName();
	}

	static function get_foundLanguages():Array<String>
	{
		Translations.ensureLoaded();
		return Translations.foundLanguages;
	}

	static function get_config():Map<String, String>
	{
		Translations.ensureLoaded();
		return Translations.getConfig(Translations.getLanguage());
	}

	static function get_isDefaultLanguage():Bool
	{
		Translations.ensureLoaded();
		return Translations.isDefaultLanguage();
	}

	static function get_isLanguageLoaded():Bool
		return Translations.isLanguageLoaded();
}
