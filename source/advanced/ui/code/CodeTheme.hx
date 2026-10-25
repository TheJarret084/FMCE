package advanced.ui.code;

import funky.core.Paths;

/** Medidas y colores de CodeStudio (tema oscuro tipo Visual Studio). Todo en coordenadas del juego. */
class CodeTheme
{
	// ---- medidas ----
	public static inline var MENU_H:Int = 28;
	public static inline var TOOL_H:Int = 34;
	public static inline var TAB_H:Int = 32;
	public static inline var FIND_H:Int = 34;
	public static inline var STATUS_H:Int = 24;
	public static inline var EXPLORER_W:Int = 280;
	public static inline var OUTPUT_H:Int = 150;
	public static inline var PANEL_HEAD_H:Int = 26;
	public static inline var ROW_H:Int = 22;
	public static inline var GUTTER_W:Int = 58;
	public static inline var FONT:Int = 14;
	public static inline var FONT_SMALL:Int = 12;
	public static inline var EDITOR_FONT:Int = 16;

	// ---- colores de la interfaz ----
	public static inline var BG:Int = 0xFF0B1020;
	public static inline var MENU:Int = 0xFF111833;
	public static inline var TOOLBAR:Int = 0xFF0F1630;
	public static inline var PANEL:Int = 0xFF0D1428;
	public static inline var EDITOR:Int = 0xFF0A0F1F;
	public static inline var TAB_BAR:Int = 0xFF0C1226;
	public static inline var TAB_IDLE:Int = 0xFF141C38;
	public static inline var BORDER:Int = 0xFF1F2A4D;
	public static inline var HOVER:Int = 0xFF1C2750;
	public static inline var SELECT:Int = 0xFF24366B;
	public static inline var CURRENT_LINE:Int = 0xFF121A36;
	public static inline var ERROR_LINE:Int = 0xFF3A1620;
	public static inline var TEXT:Int = 0xFFD7DCEB;
	public static inline var MUTED:Int = 0xFF7C87A8;
	public static inline var DIM:Int = 0xFF4F5A7D;
	public static inline var ACCENT:Int = 0xFF4C8DFF;
	public static inline var STATUS:Int = 0xFF007ACC;
	public static inline var STATUS_ERROR:Int = 0xFFCA5100;
	public static inline var ERROR:Int = 0xFFFF6B6B;
	public static inline var WARN:Int = 0xFFFFC857;
	public static inline var OK:Int = 0xFF6BD968;

	// ---- colores de sintaxis ----
	public static inline var SYN_DEFAULT:Int = 0xFFD4D4D4;
	public static inline var SYN_KEYWORD:Int = 0xFF569CD6;
	public static inline var SYN_CONTROL:Int = 0xFFC586C0;
	public static inline var SYN_TYPE:Int = 0xFF4EC9B0;
	public static inline var SYN_FUNC:Int = 0xFFDCDCAA;
	public static inline var SYN_STRING:Int = 0xFFCE9178;
	public static inline var SYN_NUMBER:Int = 0xFFB5CEA8;
	public static inline var SYN_COMMENT:Int = 0xFF6A9955;
	public static inline var SYN_META:Int = 0xFF9CDCFE;
	public static inline var SYN_KEY:Int = 0xFF9CDCFE;
	public static inline var SYN_PREPROC:Int = 0xFF9B9B9B;

	static var fontLoaded:Bool = false;
	static var cachedPath:Null<String> = null;
	static var cachedName:String = "_typewriter";

	/** Ruta de Consola.ttf para los FlxText (null = fuente por defecto). */
	public static function fontPath():Null<String>
	{
		load();
		return cachedPath;
	}

	/** Nombre de la fuente para los TextField de OpenFL. */
	public static function fontName():String
	{
		load();
		return cachedName;
	}

	/** true si Consola.ttf cargo (hace falta embedFonts en los TextField). */
	public static function fontEmbedded():Bool
	{
		load();
		return cachedPath != null;
	}

	static function load():Void
	{
		if (fontLoaded) return;
		fontLoaded = true;
		cachedPath = Paths.fontPath("Consola.ttf");
		if (cachedPath == null) return;
		try
		{
			var font = openfl.utils.Assets.getFont(cachedPath);
			if (font != null && font.fontName != null) cachedName = font.fontName;
			else cachedPath = null;
		}
		catch (e:Dynamic)
		{
			cachedPath = null;
		}
	}

	/** Los TextFormat quieren RGB sin alpha. */
	public static inline function rgb(color:Int):Int
		return color & 0xFFFFFF;
}
