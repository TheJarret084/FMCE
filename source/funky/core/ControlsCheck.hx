package funky.core;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;

class ControlsCheck
{
	public static function justPressed(lane:Int):Bool
		return keyboardJustPressed(lane) || gamepadJustPressed(lane);

	public static function pressed(lane:Int):Bool
		return keyboardPressed(lane) || gamepadPressed(lane);

	public static function justReleased(lane:Int):Bool
		return keyboardJustReleased(lane) || gamepadJustReleased(lane);

	static function keyboardJustPressed(lane:Int):Bool
	{
		var keys = resolveKeys(lane);
		return keys.length > 0 && FlxG.keys.anyJustPressed(keys);
	}

	static function keyboardPressed(lane:Int):Bool
	{
		var keys = resolveKeys(lane);
		return keys.length > 0 && FlxG.keys.anyPressed(keys);
	}

	static function keyboardJustReleased(lane:Int):Bool
	{
		var keys = resolveKeys(lane);
		return keys.length > 0 && FlxG.keys.anyJustReleased(keys);
	}

	static function gamepadJustPressed(lane:Int):Bool
	{
		var id = resolveButton(lane);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyJustPressed(id);
	}

	static function gamepadPressed(lane:Int):Bool
	{
		var id = resolveButton(lane);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyPressed(id);
	}

	static function gamepadJustReleased(lane:Int):Bool
	{
		var id = resolveButton(lane);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyJustReleased(id);
	}

	static function resolveKeys(lane:Int):Array<FlxKey>
	{
		var names = ClientPrefs.getLaneKeys(lane);
		var out = new Array<FlxKey>();

		for (n in names)
		{
			if (n == "") continue;

			var k:FlxKey = FlxKey.fromString(n);
			if (k != FlxKey.NONE) out.push(k);
		}

		return out;
	}

	static function resolveButton(lane:Int):FlxGamepadInputID
	{
		if (lane < 0) return FlxGamepadInputID.NONE;

		var buttons = ClientPrefs.getGamepadLaneButtons();
		if (lane >= buttons.length) return FlxGamepadInputID.NONE;

		var name = buttons[lane];
		if (name.length == 0) return FlxGamepadInputID.NONE;

		return FlxGamepadInputID.fromString(name);
	}
}
