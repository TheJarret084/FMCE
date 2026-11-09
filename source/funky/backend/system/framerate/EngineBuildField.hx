package funky.backend.system.framerate;

import flixel.FlxG;
import funky.game.PlayState;
import haxe.io.Path;
import lime.app.Application;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;

/** Linea de abajo del contador: version de FMCE y donde estas (el nivel si estas jugando, si no la pantalla). */
class EngineBuildField extends Sprite
{
	public var textField:TextField;

	public function new()
	{
		super();
		textField = new TextField();
		textField.autoSize = LEFT;
		textField.multiline = textField.wordWrap = false;
		textField.defaultTextFormat = new TextFormat(Framerate.textFont, 11, 0xFFFFFFFF);
		textField.textColor = 0x8F9BB3;
		textField.selectable = false;
		textField.mouseEnabled = false;
		addChild(textField);
		reload();
	}

	public function reload():Void
	{
		var text = 'FMCE ' + version() + '  |  ' + place();
		if (textField.text != text) textField.text = text;
	}

	static function version():String
	{
		var app = Application.current;
		var value = app != null && app.meta != null ? app.meta.get("version") : null;
		return value == null || value == "" ? "" : "v" + value;
	}

	static function place():String
	{
		var state = FlxG.state;
		if (state == null) return "...";

		if (Std.isOfType(state, PlayState) && PlayState.archivePath != null)
			return Path.withoutExtension(Path.withoutDirectory(PlayState.archivePath));

		var name = Type.getClassName(Type.getClass(state)).split(".").pop();
		return StringTools.replace(name, "State", "");
	}

	override function get_width():Float return textField.width;
	override function get_height():Float return textField.height;
}
