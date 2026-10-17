package funky.menus.options;

import flixel.FlxSprite;
import funky.core.Paths;

/**
 * Boton de retroceso para movil: `assets/images/backButton/texture` (atlas con el prefijo "back").
 * Queda quieto en su primer frame y `press()` reproduce la animacion una vez; el ultimo frame
 * es igual al primero, asi que no hace falta volver a poner el idle.
 */
class BackButton extends FlxSprite
{
	/** Atlas: images/backButton/texture.png + texture.xml. */
	static inline var ATLAS:String = "backButton/texture";

	/** Ancho en pantalla (px). */
	public static inline var SIZE:Int = 96;

	/** Si el atlas no esta en los assets, quien lo use cae a un boton de texto. */
	public static function available():Bool
		return Paths.framesExists(ATLAS);

	public function new(x:Float, y:Float)
	{
		super(x, y);
		scrollFactor.set();
		antialiasing = true;

		var atlas = Paths.getFrames(ATLAS);
		if (atlas != null)
		{
			frames = atlas;
			animation.addByPrefix("back", "back", 24, false);
			setGraphicSize(SIZE);
			updateHitbox();
		}
		else
			makeGraphic(SIZE, SIZE, 0xFF55555F);
	}

	public function press():Void
	{
		if (animation.getByName("back") != null) animation.play("back", true);
	}
}
