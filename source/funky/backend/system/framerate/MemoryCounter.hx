package funky.backend.system.framerate;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import funky.core.MemoryUtil;

class MemoryCounter extends Sprite
{
    public var memoryText:TextField;
    public var memoryPeakText:TextField;
    public var memory:Float = 0;
    public var memoryPeak:Float = 0;

    public function new()
    {
        super();
        memoryText = makeText();
        memoryPeakText = makeText();
        memoryPeakText.alpha = 0.5;
        addChild(memoryText);
        addChild(memoryPeakText);
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function makeText():TextField
    {
        var field = new TextField();
        field.autoSize = LEFT;
        field.multiline = field.wordWrap = false;
        field.defaultTextFormat = new TextFormat(Framerate.fontName, 12, 0xFFFFFFFF);
        field.selectable = false;
        return field;
    }

    private function onEnterFrame(_):Void
    {
        if (Framerate.debugMode <= 0) return;
        var mem = MemoryUtil.currentMemUsage();
        memory = mem;
        if (memory > memoryPeak) memoryPeak = memory;
		memoryText.text = formatSize(memory);
		memoryPeakText.text = ' / ${formatSize(memoryPeak)}';
        memoryPeakText.x = memoryText.width;
    }

    public function reload():Void {}

	public function destroy():Void
    {
        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
	}

	static function formatSize(bytes:Float):String
	{
		var units = ["B", "KB", "MB", "GB"];
		var value = bytes;
		var unit = 0;
		while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++; }
		return Std.int(value) + (unit > 1 ? "." + StringTools.lpad(Std.string(Std.int((value % 1) * 100)), "0", 2) : "") + units[unit];
	}
}
