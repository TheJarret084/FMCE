package funky.core;

import openfl.Lib;
import funky.backend.system.Flags;

/** WindowUtils. */
final class WindowUtils
{
	public static var preventClosing:Bool = false;
	public static var onClosing:Void->Void;

	static var triedClosing:Bool = false;
	static var initialized:Bool = false;

	public static var state(default, null):String = "GameState";

	public static function init(?initialState:String = "GameState"):Void
	{
		if (initialized)
			return;

		initialized = true;

		if (initialState != null)
			state = initialState;

		if (Lib.application != null && Lib.application.window != null)
		{
			Lib.application.window.onClose.add(handleClosing);
			updateTitle(state);
		}
	}

	static function handleClosing():Void
	{
		if (preventClosing)
		{
			Lib.application.window.onClose.cancel();

			if (!triedClosing)
			{
				triedClosing = true;

				if (onClosing != null)
					onClosing();
			}

			return;
		}

		if (onClosing != null)
			onClosing();
	}

	public static function getTitle(?stateName:String):String
	{
    var name:String = stateName;
    if (stateName == null) name = state;
		return 'FMCE REWORK — ${Flags.VERSION} — $name';
	}

	public static function updateTitle(?stateName:String):Void
	{
		if (stateName != null)
			state = stateName;

		if (Lib.application == null || Lib.application.window == null)
			return;

		Lib.application.window.title = getTitle(state);
	}

	public static inline function resetClosing():Void
	{
		triedClosing = false;
	}

	public static inline function refresh(?stateName:String):Void
	{
		updateTitle(stateName != null ? stateName : state);
	}
}
