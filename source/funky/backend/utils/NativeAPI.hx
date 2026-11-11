package funky.backend.utils;

import openfl.ui.Mouse;
import openfl.ui.MouseCursor;
import funky.backend.utils.native.*;
import funky.core.Log;

class NativeAPI
{
	public static function setCursorIcon(icon:CodeCursor):Void
	{
		Mouse.cursor = icon.toOpenFL();
	}

	public static function hasVersion(version:String):Bool
	{
		#if sys
		return Sys.systemName().toLowerCase().indexOf(version.toLowerCase()) != -1;
		#else
		return false;
		#end
	}

	public static function showMessageBox(caption:String, message:String, icon:MessageBoxIcon = MSG_WARNING):Void
	{
		#if android

		if (icon == MSG_ERROR) Log.error('$caption: $message');
		else Log.warn('$caption: $message');
		#elseif windows
		try
		{
			Windows.showMessageBox(caption, message, icon);
		}
		catch (_:Dynamic)
		{
			Log.trace('$caption: $message');
		}
		#elseif (sys || html5)

		try
		{
			lime.app.Application.current.window.alert(message, caption);
		}
		catch (_:Dynamic)
		{
			Log.trace('$caption: $message');
		}
		#else
		Log.trace('$caption: $message');
		#end
	}
}

enum abstract MessageBoxIcon(Int)
{
	var MSG_ERROR = 0x00000010;
	var MSG_QUESTION = 0x00000020;
	var MSG_WARNING = 0x00000030;
	var MSG_INFORMATION = 0x00000040;
}

enum abstract CodeCursor(String) from String to String
{
	var CUSTOM = "custom";
	var ARROW = "arrow";
	var CLICK = "click";
	var CROSSHAIR = "crosshair";
	var HAND = "hand";
	var IBEAM = "ibeam";
	var MOVE = "move";
	var RESIZE_H = "resize_h";
	var RESIZE_V = "resize_v";
	var RESIZE_TL = "resize_tl";
	var RESIZE_TR = "resize_tr";
	var RESIZE_BL = "resize_bl";
	var RESIZE_BR = "resize_br";
	var RESIZE_T = "resize_t";
	var RESIZE_B = "resize_b";
	var RESIZE_L = "resize_l";
	var RESIZE_R = "resize_r";
	var RESIZE_TLBR = "resize_tlbr";
	var RESIZE_TRBL = "resize_trbl";
	var WAIT = "wait";
	var WAIT_ARROW = "wait_arrow";
	var DISABLED = "disabled";
	var DRAG = "drag";
	var DRAG_OPEN = "drag_open";

	@:to public function toOpenFL():MouseCursor
	{
		return switch (cast this:String)
		{
			case "arrow": MouseCursor.ARROW;
			case "click": MouseCursor.BUTTON;
			case "hand" | "drag": MouseCursor.HAND;
			case "ibeam": MouseCursor.IBEAM;

			case "crosshair": cast "crosshair";
			case "move": cast "move";
			case "wait": cast "wait";
			case "wait_arrow": cast "wait_arrow";
			case "resize_tr" | "resize_bl" | "resize_trbl": cast "resize_nesw";
			case "resize_tl" | "resize_br" | "resize_tlbr": cast "resize_nwse";
			case "resize_h" | "resize_l" | "resize_r": cast "resize_we";
			case "resize_v" | "resize_t" | "resize_b": cast "resize_ns";

			case "custom" | "disabled" | "drag_open":
				MouseCursor.ARROW;

			default:
				MouseCursor.ARROW;
		}
	}
}
