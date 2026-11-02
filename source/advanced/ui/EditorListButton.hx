package advanced.ui;

import funkin.editors.ui.UIButton;

/** Boton de las listas de los editores: guarda el elemento que representa y se tine cuando esta elegido. */
class EditorListButton extends UIButton
{
	public var item:Dynamic = null;

	/** Se muestra como ghost en el lienzo (se tine de lila si no es el elegido). */
	public var ghost:Bool = false;

	/** Con `multi` (seleccion multiple activa) todos los bloques se ven azules y los elegidos en morado. */
	public function mark(selected:Bool, multi:Bool = false):Void
		color = multi ? (selected ? 0xFFB48CFF : 0xFF8CC4FF) : (selected ? 0xFF8CC4FF : (ghost ? 0xFFC9A8FF : 0xFFFFFFFF));
}
