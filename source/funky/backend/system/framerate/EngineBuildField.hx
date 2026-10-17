package funky.backend.system.framerate;

import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
import funky.backend.system.Flags;

class EngineBuildField extends Sprite
{
    public var textField:TextField;

    public function new()
    {
        super();
        textField = new TextField();
        textField.autoSize = LEFT;
        textField.multiline = textField.wordWrap = false;
        textField.defaultTextFormat = new TextFormat(Framerate.fontName, 12, 0xFFFFFFFF);
        textField.selectable = false;
        addChild(textField);
        reload();
    }

    public function reload():Void
    {
        textField.text = 'Funky Maker | Codename Engine';
    }

    override function get_width():Float return textField.width;
    override function get_height():Float return textField.height;
}
