package funky.backend.system;

import flixel.FlxG;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;

class ControlsCheck
{
	static final NO_KEYS:Array<FlxKey> = [];

	/** Teclas ya resueltas por carril (null = todavia no resuelto). */
	static var keyCache:Array<Null<Array<FlxKey>>> = [];

	/** Botones de gamepad ya resueltos por carril. */
	static var buttonCache:Null<Array<FlxGamepadInputID>> = null;

	/** Llamar cuando cambian las teclas o botones asignados (PlayState.create y los setters de ClientPrefs lo hacen). */
	public static function invalidate():Void
	{
		keyCache = [];
		buttonCache = null;
	}

	public static function justPressed(lane:Int):Bool
		return keyboardJustPressed(lane) || gamepadJustPressed(lane);

	public static function pressed(lane:Int):Bool
		return keyboardPressed(lane) || gamepadPressed(lane);

	public static function justReleased(lane:Int):Bool
		return keyboardJustReleased(lane) || gamepadJustReleased(lane);

	static function keyboardJustPressed(lane:Int):Bool
	{
		var keys = keysFor(lane);
		return keys.length > 0 && FlxG.keys.anyJustPressed(keys);
	}

	static function keyboardPressed(lane:Int):Bool
	{
		var keys = keysFor(lane);
		return keys.length > 0 && FlxG.keys.anyPressed(keys);
	}

	static function keyboardJustReleased(lane:Int):Bool
	{
		var keys = keysFor(lane);
		return keys.length > 0 && FlxG.keys.anyJustReleased(keys);
	}

	static function gamepadJustPressed(lane:Int):Bool
	{
		if (FlxG.gamepads.numActiveGamepads == 0) return false;
		var id = buttonFor(lane);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyJustPressed(id);
	}

	static function gamepadPressed(lane:Int):Bool
	{
		if (FlxG.gamepads.numActiveGamepads == 0) return false;
		var id = buttonFor(lane);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyPressed(id);
	}

	static function gamepadJustReleased(lane:Int):Bool
	{
		if (FlxG.gamepads.numActiveGamepads == 0) return false;
		var id = buttonFor(lane);
		return id != FlxGamepadInputID.NONE && FlxG.gamepads.anyJustReleased(id);
	}

	static function keysFor(lane:Int):Array<FlxKey>
	{
		if (lane < 0) return NO_KEYS;
		while (keyCache.length <= lane) keyCache.push(null);

		var cached = keyCache[lane];
		if (cached == null)
		{
			cached = resolveKeys(lane);
			keyCache[lane] = cached;
		}
		return cached;
	}

	static function buttonFor(lane:Int):FlxGamepadInputID
	{
		if (lane < 0) return FlxGamepadInputID.NONE;

		if (buttonCache == null)
		{
			buttonCache = [];
			for (name in ClientPrefs.getGamepadLaneButtons())
				buttonCache.push(name.length == 0 ? FlxGamepadInputID.NONE : FlxGamepadInputID.fromString(name));
		}

		return lane < buttonCache.length ? buttonCache[lane] : FlxGamepadInputID.NONE;
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
}
