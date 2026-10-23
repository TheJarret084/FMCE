package advanced.ui;

import flixel.addons.display.FlxBackdrop;
import flixel.util.FlxAxes;
import funky.core.Paths;

/**
 * Fondo de las pantallas del modo avanzado: `editors/bgs/default` en mosaico (se repite en X e Y) que se desliza
 * de izquierda a derecha, tenue sobre negro.
 */
class EditorBackdrop extends FlxBackdrop
{
	/** Pixeles por segundo hacia la derecha. */
	public static inline var SPEED:Float = 36;

	public function new(alpha:Float = 0.55)
	{
		super(Paths.image("editors/bgs/default"), FlxAxes.XY);
		velocity.set(SPEED, 0);
		scrollFactor.set();
		this.alpha = alpha;
	}
}
