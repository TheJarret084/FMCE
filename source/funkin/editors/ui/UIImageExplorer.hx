package funkin.editors.ui;

import flixel.math.FlxPoint;
import funky.backend.converter.SparrowToAseprite;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import openfl.display.BitmapData;
import sys.FileSystem;
import sys.io.File;

/**
 * Cuadro para elegir una imagen, adaptado del `UIImageExplorer` del character editor de Codename: se elige un
 * `.png`/`.jpg`, se muestra una vista previa y, si al lado hay un `.xml` (Sparrow) o un `.json` (Aseprite) con el
 * mismo nombre, se toma como atlas y se listan sus animaciones. No guarda nada: eso lo hace `SpriteImporter.importBytes`.
 */
class UIImageExplorer extends UIFileExplorer
{
	/** Nombre limpio del sprite (sin extension, solo letras/numeros/`_`/`-`). */
	public var imageName:String = null;

	public var imageBytes:Bytes = null;
	public var isJpg:Bool = false;

	/** `"xml"` (Sparrow), `"json"` (Aseprite) o null si la imagen va sola. */
	public var dataKind:Null<String> = null;
	public var dataText:Null<String> = null;
	public var animationList:Array<String> = [];

	public var fileText:UIText;
	public var maxSize:FlxPoint = FlxPoint.get(320, 220);

	var userOnFile:Null<(String, Bytes) -> Void>;

	public function new(x:Float, y:Float, ?w:Int, ?h:Int, ?onFile:(String, Bytes) -> Void)
	{
		super(x, y, w, h, "png, jpg");
		userOnFile = onFile;
		this.onFile = function(path:String, bytes:Bytes)
		{
			if (path != null && bytes != null) uploadImage(path, bytes);
			else resetData();
			if (userOnFile != null) userOnFile(path, bytes);
		};
		deleteButton.bWidth = 26;
		deleteButton.bHeight = 26;
	}

	public function uploadImage(path:String, bytes:Bytes):Void
	{
		resetData();
		path = Path.normalize(path);

		imageBytes = bytes;
		isJpg = ["jpg", "jpeg"].contains(Path.extension(path).toLowerCase());
		imageName = cleanName(Path.withoutExtension(Path.withoutDirectory(path)));

		// datos del atlas junto a la imagen: primero Sparrow (.xml), si no Aseprite (.json)
		try
		{
			var xmlPath = Path.withExtension(path, "xml");
			var jsonPath = Path.withExtension(path, "json");
			if (FileSystem.exists(xmlPath))
			{
				var text = stripBom(File.getContent(xmlPath));
				if (SparrowToAseprite.isSparrow(text))
				{
					dataKind = "xml";
					dataText = text;
					animationList = SparrowToAseprite.prefixes(text);
				}
			}
			if (dataKind == null && FileSystem.exists(jsonPath))
			{
				var text = stripBom(File.getContent(jsonPath));
				dataKind = "json";
				dataText = text;
				animationList = animsFromAseprite(text);
			}
		}
		catch (e:Dynamic)
		{
			dataKind = null;
			dataText = null;
			animationList = [];
		}
		if (dataKind == null) animationList = ["anim0"];

		// vista previa
		var bmp:BitmapData = null;
		try bmp = BitmapData.fromBytes(bytes) catch (e:Dynamic) {}
		if (bmp == null)
		{
			fileText = new UIText(x + 20, y + 16, bWidth - 20 - deleteButton.bWidth - 16, "No se pudo leer la imagen");
			members.push(fileText);
			imageBytes = null;
			return;
		}

		uiElement = new FlxSprite().loadGraphic(bmp);
		var scale:Float = 1;
		if (uiElement.width < Math.min(300, maxSize.x) || uiElement.height < Math.min(200, maxSize.y))
			scale = Math.max(Math.min(300, maxSize.x) / uiElement.width, Math.min(200, maxSize.y) / uiElement.height);
		else if (uiElement.width > maxSize.x || uiElement.height > maxSize.y)
			scale = Math.min(maxSize.x / uiElement.width, maxSize.y / uiElement.height);
		// una imagen diminuta no se estira sin limite
		scale = Math.min(scale, 4);
		uiElement.scale.set(scale, scale);
		uiElement.updateHitbox();
		uiElement.antialiasing = false;

		bWidth = Std.int(Math.max(320, uiElement.width + 32));
		bHeight = Std.int(uiElement.height) + 32 + deleteButton.bHeight + 4;
		uiElement.x = x + 16;
		uiElement.y = y + 16 + deleteButton.bHeight + 4;
		members.push(uiElement);

		var kind = dataKind == "xml" ? "atlas Sparrow (.xml)" : (dataKind == "json" ? "atlas Aseprite (.json)" : "imagen suelta (1 frame)");
		var count = animationList.length;
		fileText = new UIText(x + 20, y + 16, bWidth - 20 - deleteButton.bWidth - 16, "");
		fileText.text = Path.withoutDirectory(path) + " (" + bmp.width + "x" + bmp.height + ", " + count + (count == 1 ? " animacion" : " animaciones") + ") - " + kind;
		members.push(fileText);

		deleteButton.x = x + bWidth - deleteButton.bWidth - 16;
		deleteButton.y = y + 12;
		deleteIcon.x = deleteButton.x + deleteButton.bWidth / 2 - 8;
		deleteIcon.y = deleteButton.y + deleteButton.bHeight / 2 - 8;
	}

	public override function removeFile():Void
	{
		if (!selectable) return;
		resetData();
		bWidth = 320;
		bHeight = 58;
		if (fileText != null)
		{
			members.remove(fileText);
			fileText.destroy();
			fileText = null;
		}
		super.removeFile();
	}

	function resetData():Void
	{
		imageBytes = null;
		imageName = null;
		isJpg = false;
		dataKind = null;
		dataText = null;
		animationList = [];
	}

	public override function destroy():Void
	{
		if (maxSize != null) maxSize.put();
		maxSize = null;
		super.destroy();
	}

	static function stripBom(s:String):String
		return StringTools.replace(s, String.fromCharCode(0xFEFF), "");

	static function cleanName(base:String):String
	{
		var name = ~/[^A-Za-z0-9_\-]+/g.replace(base, "_");
		return ~/^_+|_+$/g.replace(name, "");
	}

	/** Animaciones de un JSON estilo Aseprite: sus `frameTags`; si no tiene, una sola (`anim0`). */
	static function animsFromAseprite(text:String):Array<String>
	{
		var out:Array<String> = [];
		var data:Dynamic = Json.parse(text);
		var tags:Array<Dynamic> = (data != null && data.meta != null) ? data.meta.frameTags : null;
		if (tags != null)
			for (t in tags)
				if (t != null && t.name != null && !out.contains(t.name)) out.push(t.name);
		if (out.length == 0) out.push("anim0");
		return out;
	}
}
