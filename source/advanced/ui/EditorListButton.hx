package advanced.ui;

import funkin.editors.ui.UIButton;

/** Boton de las listas de los editores: guarda el elemento que representa y se tine cuando esta elegido. */
class EditorListButton extends UIButton
{
	public var item:Dynamic = null;

	public function mark(selected:Bool):Void
		color = selected ? 0xFF8CC4FF : 0xFFFFFFFF;
}
