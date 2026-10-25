package advanced.ui.code;

import flixel.FlxG;
import openfl.display.Sprite;

/**
 * Capa de OpenFL donde viven los TextField (editor, buscador). Cuelga de FlxG.game y copia la escala del
 * modo de escala de Flixel, asi los campos de texto quedan alineados con la UI aunque cambies el tamano de la ventana.
 */
class StudioOverlay
{
	public var root(default, null):Sprite;

	public function new()
	{
		root = new Sprite();
		FlxG.game.addChild(root);
		sync();
	}

	/** Llamar cada frame. */
	public function sync():Void
	{
		if (root == null) return;
		var scale = FlxG.scaleMode.scale;
		root.scaleX = scale.x;
		root.scaleY = scale.y;
		// siempre encima de todo lo demas
		if (root.parent != null && root.parent.getChildIndex(root) != root.parent.numChildren - 1)
			root.parent.setChildIndex(root, root.parent.numChildren - 1);
	}

	public function destroy():Void
	{
		if (root != null && root.parent != null) root.parent.removeChild(root);
		root = null;
	}
}
