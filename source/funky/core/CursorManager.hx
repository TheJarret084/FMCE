package funky.core;

import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.ui.Mouse;
import flixel.graphics.frames.FlxAtlasFrames;
import funky.core.Paths;

/**
 * CursorManager
 *
 * Usa exclusivamente el pack de cursores estilo Windows:
 * assets/images/Cursors.png + Cursors.xml (Kasane Teto Cursor Set).
 * El cursor normal tiene animación idle, reacción "squeaky"
 * al hacer click, y variantes contextuales (link/text/wait/etc) que
 * cualquier state puede pedir con CursorManager.setContext("link").
 * El teclado se procesa directamente mediante FlxG.keys.
 */
class CursorManager
{
	static inline var ATLAS_NAME:String = "Cursors";
	static inline var IDLE_FRAME_TIME:Float  = 0.5;  // ritmo del parpadeo idle
	static inline var CLICK_FRAME_TIME:Float = 0.06; // ritmo de la reacción de click

	static var bmp:Bitmap;
	static var enabled:Bool = false;
	static var atlas:FlxAtlasFrames;

	static var context:String = "normal"; // pedido desde afuera: "link", "text", "wait", "help"...
	static var idleFlip:Bool  = false;
	static var frameTimer:Float = 0;

	static var clicking:Bool = false;
	static var clickFrames:Array<BitmapData>;
	static var clickIndex:Int = 0;

	public static function init():Void
	{
		if (enabled) return;
		if (Lib.current == null || Lib.current.stage == null) return;

		atlas = Paths.getSparrowAtlas(ATLAS_NAME);

		if (atlas == null)
		{
			trace('[CursorManager] no se encontró el atlas $ATLAS_NAME.');
			return;
		}

		bmp = new Bitmap(frameBitmap("normal", 0));
		if (bmp.bitmapData == null) return;

		bmp.visible = false;
    #if flash
		bmp.mouseEnabled = false;
    #end
		bmp.smoothing = true;
		Lib.current.stage.addChild(bmp);

		// Ocultamos el cursor nativo para mostrar el cursor del atlas.
		Mouse.hide();

		Lib.current.stage.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
		Lib.current.stage.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
		if (atlas != null) Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
		enabled = true;
	}

	/**
	 * Pide un cursor contextual: "link" (hover de botón/opción), "text" (input),
	 * "wait" (cargando), "help", "move", "precision", "unavailable", etc — el
	 * nombre de cualquier carpeta que exista en Cursors.xml. Llamar sin
	 * argumento (o con null) vuelve al cursor "normal".
	 */
	public static function setContext(?key:String):Void
	{
		context = (key == null || key == "") ? "normal" : key;
	}

	public static function clearContext():Void
		setContext(null);

	static function frameName(key:String, i:Int):String
		return 'cursors/$key/$key' + StringTools.lpad(Std.string(i), "0", 4);

	static function frameBitmap(key:String, i:Int):BitmapData
	{
		if (atlas == null) return null;
		try
		{
			var f = atlas.getByName(frameName(key, i));
			if (f == null) return null;
			return f.paint();
		}
		catch (e:Dynamic)
		{
			// El FlxGraphic detrás del atlas puede quedar inválido si el cache
			// de Flixel lo descarta (ej. tras un cambio de state o un GC
			// mayor); mejor perder un frame del cursor que crashear el juego.
			trace('[CursorManager] frameBitmap($key, $i) falló: $e');
			return null;
		}
	}

	static function onMouseMove(e:MouseEvent):Void
	{
		if (bmp == null) return;
		bmp.visible = true;
		bmp.x = e.stageX;
		bmp.y = e.stageY;

		// Aseguramos que quede siempre arriba de todo lo demás.
		if (Lib.current.stage.getChildIndex(bmp) != Lib.current.stage.numChildren - 1)
			Lib.current.stage.setChildIndex(bmp, Lib.current.stage.numChildren - 1);
	}

	static function onMouseDown(e:MouseEvent):Void
	{
		if (atlas == null || clicking) return;

		// "squeaky" trae 4 frames en el pack: un lindo feedback de click.
		// Si por lo que sea no está, no pasa nada, seguimos con el idle.
		var frames = [for (i in 0...4) frameBitmap("squeaky", i)];
		if (frames[0] == null) return;

		clickFrames = frames;
		clicking = true;
		clickIndex = 0;
		frameTimer = 0;
	}

	static function onEnterFrame(e:Event):Void
	{
		if (bmp == null || atlas == null) return;
		frameTimer += 1 / 60;

		if (clicking)
		{
			if (frameTimer < CLICK_FRAME_TIME) return;
			frameTimer = 0;
			clickIndex++;
			if (clickIndex >= clickFrames.length)
			{
				clicking = false;
				clickFrames = null;
			}
			else if (clickFrames[clickIndex] != null)
				bmp.bitmapData = clickFrames[clickIndex];
			return;
		}

		if (frameTimer < IDLE_FRAME_TIME) return;
		frameTimer = 0;
		idleFlip = !idleFlip;

		var data = frameBitmap(context, idleFlip ? 1 : 0);
		if (data == null) data = frameBitmap(context, 0); // el contexto no tiene 2do frame, usamos el fijo
		if (data != null) bmp.bitmapData = data;
	}
}
