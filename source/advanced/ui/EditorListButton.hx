package advanced.ui;

import funkin.editors.ui.UIButton;

/** Boton de las listas de los editores: guarda el elemento que representa y se tine cuando esta elegido. */
class EditorListButton extends UIButton
{
	public var item:Dynamic = null;

	/** Se muestra como ghost en el lienzo (se tine de lila si no es el elegido). */
	public var ghost:Bool = false;

	public function mark(selected:Bool):Void
		color = selected ? 0xFF8CC4FF : (ghost ? 0xFFC9A8FF : 0xFFFFFFFF);
}
