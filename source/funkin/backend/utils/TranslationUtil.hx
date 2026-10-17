package funkin.backend.utils;

/** Traducciones del editor (se llena en Translations.hx). */
class TranslationUtil
{
	public static function exists(id:String):Bool { funkin.backend.utils.Translations.ensureLoaded(); return funkin.backend.utils.Translations.table.exists(id); }
	/** Nunca devuelve null: si falta la clave usa el id en palabras. */
	public static function getRaw(id:String):String return raw(id);
	public static function raw(id:String):String
	{
		funkin.backend.utils.Translations.ensureLoaded();
		var s = funkin.backend.utils.Translations.table.get(id);
		return s != null ? s : funkin.backend.utils.Translations.humanize(id);
	}

	public static function raw2Id(raw:String):String return StringTools.replace(raw, " ", "");

	public static function translate(id:String, ?params:Array<Dynamic>):String
	{
		funkin.backend.utils.Translations.ensureLoaded();
		var s = funkin.backend.utils.Translations.table.get(id);
		if (s == null) s = funkin.backend.utils.Translations.humanize(id);
		if (params != null) for (i in 0...params.length) s = StringTools.replace(s, '{$i}', Std.string(params[i]));
		return s;
	}
}
