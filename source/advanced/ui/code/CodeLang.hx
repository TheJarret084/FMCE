package advanced.ui.code;

import funkin.backend.utils.TranslationUtil as TU;

/**
 * Atajo para las traducciones de Code Studio (languages/<idioma>/CodeStudio.xml).
 * Todas las claves viven bajo el prefijo "codeStudio.".
 * `def` es el texto de respaldo si la clave no existe en ningun idioma.
 */
class CodeLang
{
	public static inline function t(id:String, ?params:Array<Dynamic>, ?def:String):String
		return TU.translate("codeStudio." + id, params, def);
}
