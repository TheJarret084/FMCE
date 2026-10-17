package funkin.game;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import openfl.utils.Assets;

/** Icono simple para el editor: busca `assets/images/editors/charter/icons-chars/<icono>.png`; si no existe, un cuadro gris. */
class HealthIcon extends funkin.backend.FunkinSprite {
	public var curCharacter:String = "";

	public function new(?icon:String) {
		super();
		setIcon(icon);
	}

	public function setIcon(?icon:String):Void {
		curCharacter = icon == null ? "" : icon;
		var key = 'assets/images/editors/charter/icons-chars/$curCharacter.png';
		if (curCharacter != "" && Assets.exists(key)) {
			loadGraphic(key);
		} else {
			var fallback = 'assets/images/editors/charter/icons-chars/opponent.png';
			if (Assets.exists(fallback)) loadGraphic(fallback);
			else makeGraphic(32, 32, 0xFF808080);
		}
		updateHitbox();
	}
}
