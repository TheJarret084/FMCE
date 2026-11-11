package funkin.backend.utils;

import funkin.backend.utils.Translations;

class TranslationUtil
{

	public static var curLanguage(get, set):String;

	public static var curLanguageName(get, set):String;

	public static var foundLanguages(get, never):Array<String>;

	public static var config(get, never):Map<String, String>;

	public static var isDefaultLanguage(get, never):Bool;

	public static var isLanguageLoaded(get, never):Bool;

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
