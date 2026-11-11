package funkin.backend.utils;

import openfl.Lib;

final class WindowUtils {
	public static var title(default, set):String;
	private static function set_title(value:String):String {
		title = value;
		updateTitle();
		return value;
	}
	public static var prefix(default, set):String = "";
	private static function set_prefix(value:String):String {
		prefix = value;
		updateTitle();
		return value;
	}
	public static var suffix(default, set):String = "";
	private static function set_suffix(value:String):String {
		suffix = value;
		updateTitle();
		return value;
	}

	public static var preventClosing:Bool = true;
	public static var onClosing:Void->Void;

	static var __triedClosing:Bool = false;
	public static inline function resetClosing() __triedClosing = false;

	@:dox(hide) public static inline function init() {
		Lib.application.window.onClose.add(function () {
			if (preventClosing && !__triedClosing) {
				Lib.application.window.onClose.cancel();
				__triedClosing = true;
			}
			if (onClosing != null) onClosing();
		});
	}

	public static inline function resetTitle() {
		resetAffixes(false);
		title = Flags.TITLE;
	}

	public static inline function resetAffixes(update = true) {
		prefix = suffix = "";
		if (update) updateTitle();
	}

	public static inline function setWindow(?title:String, ?image:String)
	{

		WindowUtils.title = title != null ? title : (Flags.WINDOW_TITLE_USE_MOD_NAME ? Flags.MOD_NAME : Flags.TITLE);

		var iconPath = image != null ? image : Flags.MOD_ICON;
		if (Assets.exists(Paths.image(iconPath))) Lib.application.window.setIcon(lime.graphics.Image.fromBytes(Assets.getBytes(Paths.image(iconPath))));
	}

	public static inline function updateTitle()
		Lib.application.window.title = '$prefix$title$suffix';

	@:noCompletion public static var endfix(get, set):String;
	@:noCompletion private inline static function set_endfix(value:String):String {
		return suffix = value;
	}
	@:noCompletion private inline static function get_endfix():String {
		return suffix;
	}

	@:noCompletion public static var winTitle(get, set):String;
	@:noCompletion private inline static function get_winTitle():String {
		return title;
	}
	@:noCompletion private inline static function set_winTitle(value:String):String {
		return title = value;
	}
}
