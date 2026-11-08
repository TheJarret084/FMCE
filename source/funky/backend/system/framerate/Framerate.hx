package funky.backend.system.framerate;

import flixel.FlxG;
import flixel.math.FlxPoint;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextFormat;
import funky.core.Paths;
import flixel.util.FlxColor;
import haxe.io.Path;
import funky.core.Log;
import openfl.utils.Assets as OpenFlAssets;

/**
 * Contador propio de FMCE: panel oscuro redondeado con una barra de acento verde a la izquierda y tres bloques:
 * FPS (con su grafica de frames), memoria, y version/lugar. Se reajusta solo al tamano de su contenido.
 */
class Framerate extends Sprite
{
    public static var instance:Framerate;
    public static var isLoaded:Bool = false;
    public static var debugMode:Int = 1;
    /** Posicion base del contador (px). Cambiala con `setPosition`, `move` o `resetPosition`. */
    public static var offsetX:Float = DEFAULT_X;
    public static var offsetY:Float = DEFAULT_Y;
    /**
     * Desplazamiento extra encima de la posicion base. Los editores lo usan para bajar el contador y que no tape el menu de
     * arriba (UIState pone `offset.y = 30`). Se limpia solo al cambiar de state, asi que no se queda corrido en el juego.
     */
    public static var offset:FlxPoint = FlxPoint.get(0, 0);
    /** Opacidad de TODO el contador (0..1). `setAlpha` la cambia; se restablece sola al cambiar de state. */
    public static var panelAlpha:Float = 1;
    public static var textFormat:TextFormat;
    public static var fontName:String = "_typewriter";
    public static var otherNewFont:String = "Daydream";
    /** Nombre real de la fuente ya cargada (lo que usan todos los TextField del contador). */
    public static var textFont:String = "_typewriter";

    public var otherColor:Bool = true;

    static inline var DEFAULT_X:Float = 6;
    static inline var DEFAULT_Y:Float = 6;
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
        textFont = resolveFont();
        textFormat = new TextFormat(textFont, 10, otherColor ? 0xFFA5D6D1 : 0xFFFFFFFF);

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

        // Cada state arranca con el contador en su lugar: lo que muevan los editores no se arrastra al juego.
        FlxG.signals.preStateSwitch.add(onPreStateSwitch);
        FlxG.signals.postStateSwitch.add(onPostStateSwitch);
        onPostStateSwitch();
    }

    // ------------------------------------------------------------------ mover el contador

    /** Pone el contador en (x, y) de pantalla (px, antes del escalado). `Framerate.setPosition(6, 40)`. */
    public static function setPosition(x:Float, y:Float):Void
    {
        offsetX = x;
        offsetY = y;
    }

    /** Mueve el contador `dx`, `dy` px desde donde esta ahora. `Framerate.move(0, 30)` lo baja 30 px. */
    public static function move(dx:Float, dy:Float):Void
    {
        offsetX += dx;
        offsetY += dy;
    }

    /** Lo regresa a su lugar de siempre (arriba a la izquierda) y quita el desplazamiento extra y la transparencia. */
    public static function resetPosition():Void
    {
        offsetX = DEFAULT_X;
        offsetY = DEFAULT_Y;
        offset.set(0, 0);
        panelAlpha = 1;
    }

    /** Opacidad de todo el contador (0 = invisible, 1 = normal). */
    public static function setAlpha(value:Float):Void
        panelAlpha = value < 0 ? 0 : (value > 1 ? 1 : value);

    /** Muestra u oculta el contador (mismo efecto que `debugMode`: 0 oculto, 1 visible). */
    public static function setVisible(value:Bool):Void
        debugMode = value ? 1 : 0;

    /** Opacidad del contador dentro de los editores: ahi estorba, asi que baja solo al 10%. */
    public static inline var EDITOR_ALPHA:Float = 0.1;

    static var inEditor:Bool = false;

    static function onPostStateSwitch():Void
    {
        var name = FlxG.state != null ? Type.getClassName(Type.getClass(FlxG.state)) : "";
        inEditor = StringTools.startsWith(name, "funkin.editors.")
            || StringTools.startsWith(name, "advanced.editors.")
            || name == "advanced.AdvancedEditorState";
    }

    static function onPreStateSwitch():Void
    {
        // La posicion base se respeta (por si un script la movio a proposito); solo se limpia lo temporal.
        offset.set(0, 0);
        panelAlpha = 1;
    }

    /** Busca assets/fonts/<otherNewFont>.otf o .ttf y devuelve su fontName; si no existe, usa la fuente por defecto. */
    public static function resolveFont():String
    {
        for (ext in [".otf", ".ttf"])
        {
            var path = Paths.Font(otherNewFont, ext);
            if (OpenFlAssets.exists(path))
            {
                var f = OpenFlAssets.getFont(path);
                if (f != null && f.fontName != null) return f.fontName;
            }
        }
        Log.warn('Framerate: no se encontro la fuente "' + otherNewFont + '" en assets/fonts, usando ' + fontName);
        return fontName;
    }

    private function onEnterFrame(_):Void
    {
        visible = debugMode > 0;
        alpha = visible ? (inEditor ? EDITOR_ALPHA : panelAlpha) : 0;
        if (!visible) return;

        // en pantallas altas (celulares) el panel se agranda para seguir siendo legible
        if (stage != null)
        {
            var fit = Math.max(1, stage.stageHeight / BASE_HEIGHT);
            scaleX = scaleY = fit;
        }

        x = offsetX + offset.x;
        y = offsetY + offset.y;

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
        FlxG.signals.preStateSwitch.remove(onPreStateSwitch);
        FlxG.signals.postStateSwitch.remove(onPostStateSwitch);
        fpsCounter.destroy();
        memoryCounter.destroy();
        if (instance == this) instance = null;
        isLoaded = false;
    }
}
