package funky.backend.system;

import flixel.FlxG;
import lime.app.Application;

/** Small editor-facing subset of Codename's Flags. */
class Flags
{
	public static inline var DEFAULT_FONT:String = "_typewriter";
	public static inline var DEFAULT_FONT_SIZE:Int = 15;

	public static inline var DEFAULT_EDITOR_CLICK_SOUND:String = "editor/click";
	public static inline var DEFAULT_EDITOR_BUTTONCLICK_SOUND:String = "editor/button-click";
	public static inline var DEFAULT_EDITOR_WINDOWAPPEAR_SOUND:String = "editor/window-open";
	public static inline var DEFAULT_EDITOR_WINDOWCLOSE_SOUND:String = "editor/window-close";
	public static inline var DEFAULT_EDITOR_DROPDOWNAPPEAR_SOUND:String = "editor/dropdown";
	public static inline var DEFAULT_EDITOR_TEXTREMOVE_SOUND:String = "editor/text-remove";
	public static inline var DEFAULT_EDITOR_TEXTTYPE_SOUND:String = "editor/text-type";
	public static inline var DEFAULT_EDITOR_PASTE_SOUND:String = "editor/paste";
	public static inline var DEFAULT_EDITOR_COPY_SOUND:String = "editor/copy";
	public static inline var DEFAULT_EDITOR_CUT_SOUND:String = "editor/cut";

	public static var VERSION(get, never):String;
	// public static var STATE(get, never):String;

	static function get_VERSION():String
	{
		var version = "0.0.1";

		try
		{
			var meta = Application.current.meta;

			if (meta != null && meta.exists("version"))
			{
				var value = meta.get("version");

				if (value != null && Std.string(value).length > 0)
					version = Std.string(value);
			}
		}
		catch (_:Dynamic) {}

		#if debug
		return "TEST V" + version;
		#else
		return "V " + version;
		#end
	}

  /*
   * static function get_STATE():String {}
   */
}