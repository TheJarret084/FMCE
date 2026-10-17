package funky.backend.system.framerate;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.Lib;
import openfl.text.TextField;
import openfl.text.TextFormat;
import flixel.math.FlxMath;

class FramerateCounter extends Sprite
{
    public var fpsNum:TextField;
    public var fpsLabel:TextField;
    public var lastFPS:Float = 0;

    private var frameCount:Int = 0;
    private var accumulatedTime:Float = Lib.getTimer();
    private var elapsed:Float = 0;
    private static inline var UPDATE_INTERVAL:Float = 1 / 15;

    public function new()
    {
        super();
        fpsNum = makeText(18);
        fpsLabel = makeText(12);
        fpsNum.text = "0";
        fpsLabel.text = " FPS";
        addChild(fpsNum);
        addChild(fpsLabel);
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        updateLabelPosition();
    }

    private function makeText(size:Int):TextField
    {
        var field = new TextField();
        field.autoSize = LEFT;
        field.multiline = field.wordWrap = false;
        field.defaultTextFormat = new TextFormat(Framerate.fontName, size, 0xFFFFFFFF);
        field.selectable = false;
        return field;
    }

    private function onEnterFrame(_):Void
    {
        if (Framerate.debugMode <= 0) return;

        frameCount++;
        elapsed += 1 / 60;
        if (elapsed < UPDATE_INTERVAL)
        {
            updateLabelPosition();
            return;
        }

        var now = Lib.getTimer();
        var ms = now - accumulatedTime;
        accumulatedTime = now;
        var measured = ms <= 0 ? 0 : (1000 / ms * frameCount);
        lastFPS = FlxMath.lerp(lastFPS, measured, 0.25);
        fpsNum.text = Std.string(Math.round(lastFPS));
        frameCount = 0;
        elapsed = 0;
        updateLabelPosition();
    }

    private function updateLabelPosition():Void
    {
        fpsLabel.x = fpsNum.width;
        fpsLabel.y = Math.max(0, fpsNum.height - fpsLabel.height);
    }

    public function reload():Void
    {
        frameCount = 0;
        elapsed = 0;
        accumulatedTime = Lib.getTimer();
    }

    public function destroy():Void
    {
        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
    }
}
