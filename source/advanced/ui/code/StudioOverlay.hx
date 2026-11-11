package advanced.ui.code;

import flixel.FlxG;
import openfl.display.Sprite;

class StudioOverlay
{
	public var root(default, null):Sprite;

	public function new()
	{
		root = new Sprite();
		FlxG.game.addChild(root);
		sync();
	}

	public function sync():Void
	{
		if (root == null) return;
		var scale = FlxG.scaleMode.scale;
		root.scaleX = scale.x;
		root.scaleY = scale.y;

		if (root.parent != null && root.parent.getChildIndex(root) != root.parent.numChildren - 1)
			root.parent.setChildIndex(root, root.parent.numChildren - 1);
	}

	public function destroy():Void
	{
		if (root != null && root.parent != null) root.parent.removeChild(root);
		root = null;
	}
}
