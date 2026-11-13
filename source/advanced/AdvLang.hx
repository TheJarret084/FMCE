package advanced;

import funkin.backend.utils.TranslationUtil as TU;

class AdvLang
{
	public static inline function t(id:String, ?params:Array<Dynamic>, ?def:String):String
		return TU.translate("advanced." + id, params, def);
}
