package funky.advanced.ui;

import funky.editors.ui.UIButton;

class EditorListButton extends UIButton
{
	public var item:Dynamic = null;

	public var ghost:Bool = false;

	// Boton "X" opcional al borde derecho de la fila.
	public var deleteBtn:UIButton = null;

	public function mark(selected:Bool, multi:Bool = false):Void
		color = multi ? (selected ? 0xFFB48CFF : 0xFF8CC4FF) : (selected ? 0xFF8CC4FF : (ghost ? 0xFFC9A8FF : 0xFFFFFFFF));

	public function setDelete(callback:Void->Void):Void
	{
		if (deleteBtn != null) return;
		deleteBtn = new UIButton(x, y, "X", callback, 24, 22);
		deleteBtn.color = 0xFFFF8080;
		members.push(deleteBtn);
		if (field != null) field.fieldWidth = bWidth - 28;
	}

	public override function update(elapsed:Float):Void
	{
		// Va antes del super para que el hover use la posicion de este frame.
		if (deleteBtn != null) deleteBtn.setPosition(x + bWidth - 27, y + (bHeight - deleteBtn.bHeight) / 2);
		super.update(elapsed);
	}
}
