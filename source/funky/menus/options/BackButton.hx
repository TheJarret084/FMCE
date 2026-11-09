package funky.menus.options;

import flixel.FlxObject;
import flixel.FlxSprite;
import funky.core.MenuButton;
import funky.core.Paths;
import funky.core.TouchNav;
import funkin.backend.utils.TranslationUtil as TU;

/** Boton de retroceso para movil: `assets/images/backButton/texture` (atlas con el prefijo "back"). */
class BackButton extends FlxSprite
{
	/** Atlas: images/backButton/texture.png + texture.xml. */
	static inline var ATLAS:String = "backButton/texture";

	/** Ancho en pantalla (px). */
	public static inline var SIZE:Int = 96;

	/** Lugar UNICO del boton atras en todos los menus: esquina de arriba a la izquierda. */
	public static inline var X:Float = 12;
	public static inline var Y:Float = 4;

	/** Ancho que ocupa por la izquierda (con su margen): los titulos y listas de arriba arrancan despues de esto. */
	public static inline var WIDTH:Float = X + SIZE + 10;

	/**
	 * El boton atras ya puesto en su lugar de siempre. Usa el sprite del atlas, o un boton de texto si el atlas no esta.
	 * Pruebalo con `BackButton.clicked(boton)`.
	 */
	public static function place():FlxObject
	{
		if (available()) return new BackButton(X, Y);
		return new MenuButton(TU.translate("ui.back", null, "< ATRAS"), X, Y + 10, 150);
	}

	/** Desvanece el boton atras (sprite o texto) sin importar de cual de los dos sea. */
	public static function fade(button:Null<FlxObject>, value:Float):Void
	{
		if (Std.isOfType(button, BackButton)) cast(button, BackButton).alpha = value;
		else if (Std.isOfType(button, MenuButton)) cast(button, MenuButton).fade = value;
	}

	/** true en el frame en que un dedo o el mouse toca el boton atras (sprite o texto); ya reproduce su animacion. */
	public static function clicked(button:Null<FlxObject>):Bool
	{
		if (button == null || !TouchNav.hit(button)) return false;
		if (Std.isOfType(button, BackButton)) cast(button, BackButton).press();
		else if (Std.isOfType(button, MenuButton)) cast(button, MenuButton).press();
		return true;
	}

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
