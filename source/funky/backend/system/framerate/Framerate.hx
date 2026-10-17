package funky.backend.system.framerate;

import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextFormat;

class Framerate extends Sprite
{
    public static var instance:Framerate;
    public static var isLoaded:Bool = false;
    public static var debugMode:Int = 1;
    public static var offsetX:Float = 5;
    public static var offsetY:Float = 20;
    public static var textFormat:TextFormat;
    public static var fontName:String = "_typewriter";

    public var fpsCounter:FramerateCounter;
    public var memoryCounter:MemoryCounter;
    public var buildField:EngineBuildField;

    public function new()
    {
        super();
        if (instance != null) throw "Cannot create another Framerate instance";
        instance = this;
        isLoaded = true;

        x = 30;
        y = 5;

        textFormat = new TextFormat(fontName, 12, 0xFFFFFFFF);

        fpsCounter = new FramerateCounter();
        memoryCounter = new MemoryCounter();
        buildField = new EngineBuildField();

        addChild(fpsCounter);
        addChild(memoryCounter);
        addChild(buildField);

        updateLayout();
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function onEnterFrame(_):Void
    {
        visible = debugMode > 0;
        alpha = visible ? 1 : 0;
        x = 10 + offsetX;
        y = 2 + offsetY;
        updateLayout();
    }

    private function updateLayout():Void
    {
        memoryCounter.y = fpsCounter.height;
        buildField.y = memoryCounter.y + memoryCounter.height;
    }

    public function reload():Void
    {
        fpsCounter.reload();
        memoryCounter.reload();
        buildField.reload();
    }

    public function destroy():Void
    {
        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
        if (instance == this) instance = null;
        isLoaded = false;
    }
}
