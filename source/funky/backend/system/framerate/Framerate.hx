package funky.backend.system.framerate;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextFormat;
import funky.core.Paths;
import flixel.util.FlxColor;

/**
 * Contador propio de FMCE: panel oscuro redondeado con una barra de acento verde a la izquierda y tres bloques:
 * FPS (con su grafica de frames), memoria, y version/lugar. Se reajusta solo al tamano de su contenido.
 */
class Framerate extends Sprite
{
    public static var instance:Framerate;
    public static var isLoaded:Bool = false;
    public static var debugMode:Int = 1;
    public static var offsetX:Float = 6;
    public static var offsetY:Float = 6;
    public static var textFormat:TextFormat;
    public static var fontName:String = "_typewriter";
    public static var otherNewFont:String = "Daydream";

    public var otherColor:Bool = false;

    static inline var PAD_X:Float = 12;
    static inline var PAD_Y:Float = 7;
    static inline var GAP:Float = 2;
    static inline var REFRESH_MS:Int = 500;
    /** Alto de pantalla (px) para el que esta pensado el tamano del panel: en pantallas mas altas se agranda. */
    static inline var BASE_HEIGHT:Float = 720;

    public var panel:Sprite;
    public var fpsCounter:FramerateCounter;
    public var memoryCounter:MemoryCounter;
    public var buildField:EngineBuildField;

    private var panelW:Float = -1;
    private var panelH:Float = -1;
    private var lastRefresh:Int = 0;

    public function new()
    {
        super();
        if (instance != null) throw "Cannot create another Framerate instance";
        instance = this;
        isLoaded = true;
                                                                                                                                            // valor     si es true   si es false
        textFormat = new TextFormat(OpenFlAssets.exists(Paths.Font(otherNewFont, ".otf")) ? Paths.Font(otherNewFont, ".otf") : fontName, 12, otherColor ? 0xFFA5D6D1 : 0xFFFFFFFF);  //FlxColor.fromRGB(145, 214, 209)); 0xFFFFFFFF

        panel = new Sprite();
        panel.mouseEnabled = false;
        fpsCounter = new FramerateCounter();
        memoryCounter = new MemoryCounter();
        buildField = new EngineBuildField();

        addChild(panel);
        addChild(fpsCounter);
        addChild(memoryCounter);
        addChild(buildField);

        mouseEnabled = false;
        mouseChildren = false;

        updateLayout();
        addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    private function onEnterFrame(_):Void
    {
        visible = debugMode > 0;
        alpha = visible ? 1 : 0;
        if (!visible) return;

        // en pantallas altas (celulares) el panel se agranda para seguir siendo legible
        if (stage != null)
        {
            var fit = Math.max(1, stage.stageHeight / BASE_HEIGHT);
            scaleX = scaleY = fit;
        }

        x = offsetX;
        y = offsetY;

        var now = Lib.getTimer();
        if (now - lastRefresh >= REFRESH_MS)
        {
            lastRefresh = now;
            buildField.reload();
        }

        updateLayout();
    }

    private function updateLayout():Void
    {
        fpsCounter.x = PAD_X;
        fpsCounter.y = PAD_Y;
        memoryCounter.x = PAD_X;
        memoryCounter.y = fpsCounter.y + fpsCounter.height + GAP;
        buildField.x = PAD_X;
        buildField.y = memoryCounter.y + memoryCounter.height + GAP;

        var w = Math.max(fpsCounter.width, Math.max(memoryCounter.width, buildField.width)) + PAD_X * 2;
        var h = buildField.y + buildField.height + PAD_Y;
        if (Math.abs(w - panelW) > 0.5 || Math.abs(h - panelH) > 0.5)
            drawPanel(w, h);
    }

    private function drawPanel(w:Float, h:Float):Void
    {
        panelW = w;
        panelH = h;

        var g = panel.graphics;
        g.clear();
        g.beginFill(0x0B0E14, 0.82);
        g.drawRoundRect(0, 0, w, h, 12, 12);
        g.endFill();
        g.beginFill(FramerateCounter.GOOD & 0xFFFFFF, 1);
        g.drawRoundRect(0, 7, 3, h - 14, 3, 3);
        g.endFill();
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
        fpsCounter.destroy();
        memoryCounter.destroy();
        if (instance == this) instance = null;
        isLoaded = false;
    }
}
