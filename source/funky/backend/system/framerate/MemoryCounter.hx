package funky.backend.system.framerate;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import funky.core.MemoryUtil;

/**
 * Linea 1: RAM que usa el juego (proceso) / pico.
 * Linea 2: RAM usada de todo el dispositivo / total (si el sistema deja leerla).
 */
class MemoryCounter extends Sprite
{
    /** Cada cuanto se relee /proc (ms): leerlo cada frame no hace falta. */
    static inline var PROC_INTERVAL:Int = 500;

    public var memoryText:TextField;
    public var memoryPeakText:TextField;
    public var deviceText:TextField;
    public var memory:Float = 0;
    public var memoryPeak:Float = 0;

    private var lastRead:Int = -PROC_INTERVAL;

    public function new()
    {
        super();
        memoryText = makeText(0xFFD6E0F5);
        memoryPeakText = makeText(0xFFD6E0F5);
        memoryPeakText.alpha = 0.5;
        deviceText = makeText(0xFF8F9BB3);
        addChild(memoryText);
        addChild(memoryPeakText);
        addChild(deviceText);
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function makeText(color:Int):TextField
    {
        var field = new TextField();
        field.autoSize = LEFT;
        field.multiline = field.wordWrap = false;
        field.defaultTextFormat = new TextFormat(Framerate.textFont, 11, 0xFFFFFFFF);
        field.textColor = color & 0xFFFFFF;
        field.selectable = false;
        field.mouseEnabled = false;
        return field;
    }

    private function onEnterFrame(_):Void
    {
        if (Framerate.debugMode <= 0) return;

        var now = Lib.getTimer();
        if (now - lastRead < PROC_INTERVAL) return;
        lastRead = now;

        memory = MemoryUtil.processMemUsage();
        if (memory > memoryPeak) memoryPeak = memory;
        memoryText.text = 'Juego ${formatSize(memory)}';
        memoryPeakText.text = ' / ${formatSize(memoryPeak)}';
        memoryPeakText.x = memoryText.width;

        var device = MemoryUtil.deviceMem();
        deviceText.visible = device != null;
        if (device != null)
        {
            deviceText.text = 'Dispositivo ${formatSize(device.used)} / ${formatSize(device.total)}';
            deviceText.y = memoryText.height;
        }
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
