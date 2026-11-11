package advanced.ui;

import funkin.editors.ui.UIButton;

class EditorListButton extends UIButton
{
	public var item:Dynamic = null;

	public var ghost:Bool = false;

	public function mark(selected:Bool, multi:Bool = false):Void
		color = multi ? (selected ? 0xFFB48CFF : 0xFF8CC4FF) : (selected ? 0xFF8CC4FF : (ghost ? 0xFFC9A8FF : 0xFFFFFFFF));
}
