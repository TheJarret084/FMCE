package funkin.menus.ui;

import flixel.group.FlxSpriteGroup;

/** Stub: el charter portado no usa texto Alphabet. */
class Alphabet extends FlxSpriteGroup
{
	public var text:String = "";
	public function new(x:Float = 0, y:Float = 0, text:String = "", bold:Bool = false) { super(x, y); this.text = text; }
}
