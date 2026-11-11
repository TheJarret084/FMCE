package funky.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import funky.backend.FunkinSprite;

class LoadingOverlay extends FlxGroup
{
	static inline var ATLAS:String = "menus/Loading/JazminDeliveryMode";
	static inline var BAR_WIDTH:Int = 520;
	static inline var BAR_HEIGHT:Int = 14;
	static inline var BACK_COLOR:Int = 0xF0101016;

	static inline var GIVE_SHIFT_X:Float = 16.66;
	static inline var GIVE_SHIFT_Y:Float = -105.35;

	var jazmin:Null<FunkinSprite>;
	var fit:Float = 1;
	var homeX:Float = 0;
	var homeY:Float = 0;
	var fill:FlxSprite;
	var titleText:FlxText;
	var labelText:FlxText;
	var percentText:FlxText;
	var shown:Float = 0;
	var target:Float = 0;

	public function new(title:String)
	{
		super();

		var back = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, BACK_COLOR);
		back.scrollFactor.set();
		add(back);

		var sprite = new FunkinSprite();
		sprite.loadSprite(ATLAS);
		if (sprite.frames != null)
		{

			sprite.addAnim("work", "anims/walk", 24, true);
			sprite.addAnim("give", "anims/give", 24, false);
			sprite.playAnim("work", true);
			sprite.antialiasing = true;
			sprite.scrollFactor.set();
			jazmin = sprite;

			fit = Math.min(1.6, FlxG.height * 0.34 / Math.max(1, sprite.frameHeight));
			layout(false);
			homeX = jazmin.x;
			homeY = jazmin.y;
			add(sprite);
		}

		var barX = (FlxG.width - BAR_WIDTH) / 2;
		var barY = FlxG.height * 0.62;

		titleText = new FlxText(0, barY - 62, FlxG.width, title, 30);
		titleText.alignment = FlxTextAlign.CENTER;
		titleText.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF000000, 2);
		add(titleText);

		var track = new FlxSprite(barX - 3, barY - 3).makeGraphic(BAR_WIDTH + 6, BAR_HEIGHT + 6, 0xFF000000);
		track.scrollFactor.set();
		add(track);

		fill = new FlxSprite(barX, barY).makeGraphic(BAR_WIDTH, BAR_HEIGHT, 0xFF64DDAA);
		fill.origin.set(0, 0);
		fill.scrollFactor.set();
		add(fill);
		applyFill(0);

		percentText = new FlxText(0, barY + BAR_HEIGHT + 8, FlxG.width, "0%", 18);
		percentText.alignment = FlxTextAlign.CENTER;
		add(percentText);

		labelText = new FlxText(40, barY + BAR_HEIGHT + 36, FlxG.width - 80, "", 16);
		labelText.alignment = FlxTextAlign.CENTER;
		labelText.color = 0xFFB8B8C6;
		add(labelText);
	}

	public function setProgress(value:Float, label:String):Void
	{
		target = Math.max(0, Math.min(1, value));
		labelText.text = label;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		shown += (target - shown) * Math.min(1, elapsed * 10);
		applyFill(shown);
		percentText.text = Std.int(shown * 100) + "%";
	}

	public function finish(message:String):Void
	{
		target = 1;
		labelText.text = message;
		if (jazmin != null)
		{
			jazmin.playAnim("give", true);
			layout(true);
		}
	}

	function layout(giving:Bool):Void
	{
		jazmin.scale.set(fit, fit);
		jazmin.updateHitbox();

		if (giving)
			jazmin.setPosition(homeX + GIVE_SHIFT_X * fit, homeY + GIVE_SHIFT_Y * fit);
		else
			jazmin.setPosition((FlxG.width - jazmin.width) / 2, FlxG.height * 0.16);
	}

	function applyFill(value:Float):Void
	{
		fill.scale.x = Math.max(0.001, value);
	}
}
