package funky.core;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;

class MenuButton extends FlxSpriteGroup
{
	public static inline var HEIGHT:Int = 52;

	public static inline var MARGIN:Float = 20;
	public static inline var GAP:Float = 14;

	static inline var BASE_ALPHA:Float = 0.82;
	static inline var BORDER:Int = 3;

	var bg:FlxSprite;
	var label:FlxText;
	var pop:Float = 0;
	var hot:Bool = false;

	public var text(get, set):String;

	public var fade:Float = 1;

	public function new(text:String, x:Float = 0, y:Float = 0, width:Float = 0)
	{
		super(x, y);

		label = new FlxText(0, 0, 0, text, 22);
		label.setFormat(font(), 22, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1.5;

		var w = Std.int(width > 0 ? width : Math.max(140, label.width + 48));
		bg = new FlxSprite();
		bg.makeGraphic(w, HEIGHT, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(bg, BORDER / 2, BORDER / 2, w - BORDER, HEIGHT - BORDER, 22, 22, 0xE6101828, {thickness: BORDER, color: FlxColor.WHITE});

		label.fieldWidth = w;
		label.y = (HEIGHT - label.height) / 2;

		add(bg);
		add(label);

		scrollFactor.set();
		alpha = BASE_ALPHA;
		antialiasing = true;
	}

	static var fontPath:Null<String>;
	static var fontChecked:Bool = false;

	static function font():Null<String>
	{
		if (!fontChecked)
		{
			fontChecked = true;
			fontPath = Paths.fontPath("PhantomMuff.ttf");
		}
		return fontPath;
	}

	function get_text():String
		return label.text;

	function set_text(value:String):String
	{
		label.text = value;
		label.y = y + (HEIGHT - label.height) / 2;
		return value;
	}

	public function clicked():Bool
	{
		if (!exists || !visible || fade < 0.2 || !TouchNav.hit(this)) return false;
		press();
		return true;
	}

	public function press():Void
		pop = 1;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		hot = TouchNav.over(this);
		pop = Math.max(0, pop - elapsed * 7);

		var targetAlpha = (hot ? 1 : BASE_ALPHA) * fade;
		alpha = FlxMath.lerp(alpha, targetAlpha, Math.min(1, elapsed * 14));
		var s = 1 - 0.08 * pop;
		bg.scale.set(s, s);
		label.scale.set(s, s);
	}

	public static function bottomRow(buttons:Array<MenuButton>, bottomInset:Float = 0):Void
	{
		var cursor = MARGIN;
		var rowY = FlxG.height - HEIGHT - MARGIN * 0.6 - bottomInset;
		for (button in buttons)
		{
			if (button == null) continue;
			button.setPosition(cursor, rowY);
			cursor += button.bg.width + GAP;
		}
	}
}
