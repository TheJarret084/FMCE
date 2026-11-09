package funky.core;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import funky.core.Paths;
import funky.game.PlayState;

/** Cursor del juego y su regla unica: el mouse esta SIEMPRE activo (visible y funcionando) en todos los states, menos en el PlayState. */
class CursorManager
{
	/** true = el mouse se esconde en cualquier state (para cinematicas o videos). Acuerdate de regresarlo a false. */
	public static var forceHidden:Bool = false;

	static var ready:Bool = false;

	public static function init():Void
	{
		if (ready) return;
		ready = true;

		var atlas:FlxAtlasFrames = Paths.getSparrowAtlas("cursor");
		if (atlas != null)
		{
			var frame = atlas.getByName("idle0000");
			if (frame == null)
				trace('[CursorManager] no existe el frame en el atlas');
			else
				FlxG.mouse.load(frame.paint());
		}

		FlxG.signals.postUpdate.add(apply);
		apply();
	}

	/** true cuando el mouse no debe verse: dentro del PlayState (sin substate encima) o con `forceHidden`. */
	public static function shouldHide():Bool
	{
		if (forceHidden) return true;
		// Misma regla en PC y mobile: solo se oculta dentro del PlayState. En mobile tambien vale
		// (con un mouse fisico conectado se comporta igual que en PC).
		var state = FlxG.state;
		return state != null && Std.isOfType(state, PlayState) && state.subState == null;
	}

	/** Aplica la regla. Se llama sola cada frame; llamala tu si necesitas el resultado en el mismo frame. */
	public static function apply():Void
	{
		#if FLX_MOUSE
		FlxG.mouse.enabled = true;
		FlxG.mouse.visible = !shouldHide();
		#end
	}
}
