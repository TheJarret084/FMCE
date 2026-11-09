package advanced.ui;

import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxAxes;
import funky.core.Paths;

/** Fondo en mosaico que se desliza, usado por el modo avanzado. */
class EditorBackdrop extends FlxBackdrop
{
	/** Pixeles por segundo hacia la derecha. */
	public static inline var SPEED:Float = 36;

	/** Mosaico por defecto (el de las pantallas del modo avanzado). */
	public static inline var DEFAULT_IMAGE:String = "editors/bgs/default";

	/** @param image Mosaico (ruta bajo `assets/images`, sin extension); cada pantalla puede usar el suyo. */
	public function new(alpha:Float = 0.55, image:String = DEFAULT_IMAGE)
	{
		super(Paths.image(image), FlxAxes.XY);
		velocity.set(SPEED, 0);
		scrollFactor.set();
		this.alpha = alpha;
	}
}
