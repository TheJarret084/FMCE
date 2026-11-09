package funky.core;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;

/** Controles abstractos de interfaz/menú. */
class KeyBinds
{
	public static inline final UP:String = "up";
	public static inline final DOWN:String = "down";
	public static inline final LEFT:String = "left";
	public static inline final RIGHT:String = "right";
	public static inline final ACCEPT:String = "accept";
	public static inline final BACK:String = "back";
	public static inline final PAUSE:String = "pause";

	public static function justPressed(action:String):Bool
		return keyboardJustPressed(action) || gamepadJustPressed(action);

	public static function pressed(action:String):Bool
		return keyboardPressed(action) || gamepadPressed(action);

	public static function justReleased(action:String):Bool
		return keyboardJustReleased(action) || gamepadJustReleased(action);

	public static function keyboardJustPressed(action:String):Bool
	{
		var keys = resolveKeys(action);
		return keys.length > 0 && FlxG.keys.anyJustPressed(keys);
	}

	public static function keyboardPressed(action:String):Bool
	{
		var keys = resolveKeys(action);
		return keys.length > 0 && FlxG.keys.anyPressed(keys);
	}

	public static function keyboardJustReleased(action:String):Bool
	{
		var keys = resolveKeys(action);
		return keys.length > 0 && FlxG.keys.anyJustReleased(keys);
	}

	public static function gamepadJustPressed(action:String):Bool
	{
		var id = resolveGamepad(action);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyJustPressed(id);
	}

	public static function gamepadPressed(action:String):Bool
	{
		var id = resolveGamepad(action);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyPressed(id);
	}

	public static function gamepadJustReleased(action:String):Bool
	{
		var id = resolveGamepad(action);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyJustReleased(id);
	}

	public static function getKeyboard(action:String):Array<String>
	{
		// Typed as Null<> on purpose: settings.xml may simply have no entry.
		var keys:Null<Array<String>> = ClientPrefs.getMenuKeyboard(action);
		return (keys != null && keys.length > 0) ? keys : legacyKeyboardFallback(action);
	}

	public static function getGamepad(action:String):String
	{
		var button:Null<String> = ClientPrefs.getMenuGamepad(action);
		return (button != null && button.length > 0) ? button : legacyGamepadFallback(action);
	}

	public static function setKeyboard(action:String, slot:Int, key:String):Void
		ClientPrefs.setMenuKeyboard(action, slot, key);

	public static function setGamepad(action:String, button:String):Void
		ClientPrefs.setMenuGamepad(action, button);

	/** A human-readable name for the current keyboard binding of `action`, for on-screen hints. */
	public static function label(action:String, ?separator:String = " / "):String
	{
		var names = getKeyboard(action);
		if (names.length == 0) return "NINGUN TECLA";
		return [for (n in names) keyDisplayName(n)].join(separator);
	}

	/**
	 * Like `label`, but also mentions the bound gamepad button when there is
	 * one. Used by menus that want to advertise controller support.
	 */
	public static function labelWithGamepad(action:String, ?separator:String = " / "):String
	{
		var keyboard = label(action, separator);
		var button = getGamepad(action);
		if (button.length == 0) return keyboard;
		return keyboard + separator + "[" + button + "]";
	}

	/** Localized name for a key, for on-screen hints. Falls back to the raw name. */
	public static function keyDisplayName(name:String):String
	{
		var display = KEY_DISPLAY.get(name.toUpperCase());
		return (display != null) ? display : name.toUpperCase();
	}

	static final KEY_DISPLAY = [
		"UP" => "ARRIBA",
		"DOWN" => "ABAJO",
		"LEFT" => "IZQ",
		"RIGHT" => "DER",
		"ENTER" => "ENTER",
		"RETURN" => "ENTER",
		"SPACE" => "ESPACIO",
		"ESCAPE" => "ESC",
		"BACKSPACE" => "BORRARR"
	];

	static function legacyKeyboardFallback(action:String):Array<String>
	{
		return switch (action)
		{
			case UP: ["UP", "K"];
			case DOWN: ["DOWN", "S"];
			case LEFT: ["LEFT", "A"];
			case RIGHT: ["RIGHT", "L"];
			case ACCEPT: ["ENTER", "SPACE"];
			case BACK: ["ESCAPE"] ;
			case PAUSE: ["ENTER"];
			default: [];
		};
	}

	static function legacyGamepadFallback(action:String):String
	{
		return switch (action)
		{
			case UP: "DPAD_UP";
			case DOWN: "DPAD_DOWN";
			case LEFT: "DPAD_LEFT";
			case RIGHT: "DPAD_RIGHT";
			case ACCEPT: "A";
			case BACK: "B";
			case PAUSE: "START";
			default: "";
		};
	}

	static function resolveKeys(action:String):Array<FlxKey>
	{
		var names = getKeyboard(action);
		var out:Array<FlxKey> = [];
		for (name in names)
		{
			if (name.length == 0) continue;
			var key:FlxKey = FlxKey.fromString(name);
			if (key != FlxKey.NONE) out.push(key);
		}
		return out;
	}

	static function resolveGamepad(action:String):FlxGamepadInputID
	{
		var name = getGamepad(action);
		if (name.length == 0) return FlxGamepadInputID.NONE;
		return FlxGamepadInputID.fromString(name);
	}
}
