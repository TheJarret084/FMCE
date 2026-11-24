package funky.backend.system;

import flixel.util.FlxColor;
import lime.app.Application;

class Flags
{
	public static inline var DEFAULT_FONT:String = "_typewriter";
	public static inline var DEFAULT_FONT_SIZE:Int = 15;

	// Editor sounds (funky naming)
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
	public static inline var DEFAULT_EDITOR_SAVE_SOUND:String = "editor/save";
	public static inline var DEFAULT_EDITOR_UNDO_SOUND:String = "editor/undo";
	public static inline var DEFAULT_EDITOR_REDO_SOUND:String = "editor/redo";
	public static inline var DEFAULT_EDITOR_DELETE_SOUND:String = "editor/delete";
	public static inline var DEFAULT_EDITOR_AUTOSAVE_SOUND:String = "editor/autosave";
	public static inline var DEFAULT_EDITOR_CHECKBOXCHECKED_SOUND:String = "editor/checkbox-checked";
	public static inline var DEFAULT_EDITOR_CHECKBOXUNCHECKED_SOUND:String = "editor/checkbox-unchecked";
	public static inline var DEFAULT_EDITOR_WARNING_SOUND:String = "editor/warning";
	public static inline var DEFAULT_EDITOR_OFFSETDRAG_SOUND:String = "editor/offset-drag";

	// Menu sounds
	public static inline var DEFAULT_MENU_SCROLL_SOUND:String = "menu/scroll";
	public static inline var DEFAULT_MENU_CONFIRM_SOUND:String = "menu/confirm";
	public static inline var DEFAULT_MENU_CANCEL_SOUND:String = "menu/cancel";
	public static inline var DEFAULT_MENU_VOLUME_SOUND:String = "menu/volume";

	// Charter sounds
	public static inline var DEFAULT_CHARTER_HITSOUND_SOUND:String = "editors/charter/hitsound";
	public static inline var DEFAULT_CHARTER_METRONOME_SOUND:String = "editors/charter/metronome";
	public static inline var DEFAULT_CHARTER_NOTEDELETE_SOUND:String = "editors/charter/noteDelete";
	public static inline var DEFAULT_CHARTER_NOTEPLACE_SOUND:String = "editors/charter/notePlace";
	public static inline var DEFAULT_CHARTER_SCROLL_SOUND:String = "editors/charter/scroll";
	public static inline var DEFAULT_CHARTER_SNAPPINGCHANGE_SOUND:String = "editors/charter/snappingChange";
	public static inline var DEFAULT_CHARTER_STRUMLOCK_SOUND:String = "editors/charter/strumLock";
	public static inline var DEFAULT_CHARTER_STRUMUNLOCK_SOUND:String = "editors/charter/strumUnlock";
	public static inline var DEFAULT_CHARTER_SUSTAINADD_SOUND:String = "editors/charter/sustainAdd";
	public static inline var DEFAULT_CHARTER_SUSTAINDELETE_SOUND:String = "editors/charter/sustainDelete";

	// Character editor sounds
	public static inline var DEFAULT_CHARACTER_GHOSTDISABLE_SOUND:String = "editors/character/ghostDisable";
	public static inline var DEFAULT_CHARACTER_GHOSTENABLE_SOUND:String = "editors/character/ghostEnable";

	// General defaults (Codename-compat, used by ported editors/utils)
	public static var JSON_PRETTY_PRINT:String = "\t";
	public static var TITLE:String = "FUNKYAKER";
	public static var WINDOW_TITLE_USE_MOD_NAME:Bool = false;
	public static var MOD_NAME:String = "FMCE";
	public static var MOD_ICON:String = "";
	public static var UNDO_PREFIX:String = "* ";
	public static var DEFAULT_DISCORD_LOGO_KEY:String = "icon";
	public static var DEFAULT_DISCORD_CLIENT_ID:String = "1383853614589673472";
	public static var DEFAULT_DISCORD_LOGO_TEXT:String = "Codename Engine";
	public static var DEFAULT_CHARACTER:String = "bf";
	public static var DEFAULT_GIRLFRIEND:String = "gf";
	public static var DEFAULT_OPPONENT:String = "dad";
	public static var DEFAULT_DIFFICULTY:String = "normal";
	public static var DEFAULT_STAGE:String = "stage";
	public static var DEFAULT_SCROLL_SPEED:Float = 2.0;
	public static var DEFAULT_HEALTH_ICON:String = "face";
	public static var DEFAULT_LANGUAGE:String = "en";
	public static var DEFAULT_LANGUAGE_NAME:String = "English";
	public static var DEFAULT_BPM:Float = 100.0;
	public static var DEFAULT_BEATS_PER_MEASURE:Int = 4;
	public static var DEFAULT_STEPS_PER_BEAT:Int = 4;
	public static var DEFAULT_LOOP_TIME:Float = 0.0;
	public static var DEFAULT_COLOR:FlxColor = 0xFF9271FD;
	public static var DEFAULT_WEEK_COLOR:FlxColor = 0xFFF9CF51;
	public static var DEFAULT_COOP_ALLOWED:Bool = false;
	public static var DEFAULT_OPPONENT_MODE_ALLOWED:Bool = false;
	public static var DEFAULT_OPPONENT_MODE:Bool = false;
	public static var DEFAULT_NOTE_MS_LIMIT:Float = 1500;
	public static var DEFAULT_NOTE_SCALE:Float = 0.7;
	public static var DEFAULT_MODCHART_HOLD_SUBDIVISIONS:Int = 4;
	public static var DEFAULT_GAMEOVER_CHARACTER:String = "bf-dead";
	public static var DEFAULT_CAM_ZOOM_INTERVAL:Int = 1;
	public static var DEFAULT_CAM_ZOOM_OFFSET:Float = 0;
	public static var DEFAULT_CAM_ZOOM_STRENGTH:Int = 1;
	public static var DEFAULT_HUD_ZOOM:Float = 1.0;
	public static var DEFAULT_ZOOM:Float = 1.0;
	public static var DEFAULT_ZOOM_LERP:Float = 0.05;
	public static var DEFAULT_CAM_ZOOM_MULT:Float = 0.015;
	public static var DEFAULT_HUD_ZOOM_MULT:Float = 0.03;
	public static var DEFAULT_CAM_ZOOM_LERP:Float = 0.05;
	public static var DEFAULT_HUD_ZOOM_LERP:Float = 0.05;
	public static var DEFAULT_ALT_ANIM_SUFFIX:String = "-alt";
	public static var DEFAULT_PAUSE_ITEMS:Array<String> = ['Resume', 'Restart Song', 'Change Controls', 'Change Options', 'Exit to menu', "Exit to charter"];
	public static var DEFAULT_CUTSCENE_PAUSE_ITEMS:Array<String> = ['Resume Cutscene', 'Skip Cutscene', 'Restart Cutscene', 'Exit to menu'];
	public static var DEFAULT_GITAROO:Bool = true;
	public static var DEFAULT_MUTE_VOCALS_ON_MISS:Bool = true;
	public static var DEFAULT_MAX_HEALTH:Float = 2.0;
	public static var DEFAULT_HEALTH:Null<Float> = null;
	public static var DEFAULT_ICONBOP:Bool = true;
	public static var DEFAULT_INTRO_LENGTH:Int = 5;
	public static var DEFAULT_INTRO_SPRITES:Array<String> = [null, 'game/ready', 'game/set', 'game/go'];
	public static var DEFAULT_COMBO_GROUP_MAX_SIZE:Int = 25;
	public static var DEFAULT_STRUM_AMOUNT:Int = 4;
	public static var DEFAULT_CAMERA_FOLLOW_SPEED:Float = 0.04;
	public static var DEFAULT_TRANSITION_SCRIPT:String = "";
	public static var DEFAULT_PAUSE_SCRIPT:String = "";
	public static var DEFAULT_GAMEOVER_SCRIPT:String = "";
	public static var DEFAULT_MENU_MUSIC:String = "freakyMenu";
	public static var DEFAULT_PAUSE_MENU_MUSIC:String = "breakfast";
	public static var DEFAULT_GAMEOVER_MUSIC:String = "gameOver";
	public static var DEFAULT_MISS_SOUNDS:Array<String> = ["missnote1", "missnote2", "missnote3"];
	public static var DEFAULT_INTRO_SOUNDS:Array<String> = ["intro3", "intro2", "intro1", "introGo"];
	public static var DEFAULT_GAMEOVERSFX_SOUND:String = "gameOverSFX";
	public static var DEFAULT_GAMEOVEREND_SOUND:String = "gameOverEnd";
	public static var SOUND_EXT:String = "ogg";
	public static var USER_AGENT:String = "request";

	public static var VERSION(get, never):String;

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
}
