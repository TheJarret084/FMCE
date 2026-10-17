package funky.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import funky.core.Paths;

/**
 * Pantalla de carga: fondo oscuro, la Jazmin de `menus/Loading/JazminDeliveryMode` trabajando
 * (`work`), un titulo, la barra de avance y lo que se esta haciendo.
 */
class LoadingOverlay extends FlxGroup
{
	static inline var ATLAS:String = "menus/Loading/JazminDeliveryMode";
	static inline var BAR_WIDTH:Int = 520;
	static inline var BAR_HEIGHT:Int = 14;
	static inline var BACK_COLOR:Int = 0xF0101016;

	var jazmin:Null<FlxSprite>;
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

		var frames = Paths.getSparrowAtlas(ATLAS);
		if (frames != null)
		{
			var sprite = new FlxSprite();
			sprite.frames = frames;
			sprite.animation.addByPrefix("work", "work", 6, true);
			sprite.animation.addByPrefix("give", "give", 24, false);
			sprite.animation.play("work");
			sprite.antialiasing = true;
			sprite.scrollFactor.set();
			// Escala UNIFORME (el cuadro mide 300x300) para que no se deforme.
			var k = Math.min(1.4, FlxG.height * 0.34 / Math.max(1, sprite.frameHeight));
			sprite.scale.set(k, k);
			sprite.updateHitbox();
			sprite.setPosition((FlxG.width - sprite.width) / 2, FlxG.height * 0.16);
			add(sprite);
			jazmin = sprite;
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

	/** @param value 0..1 */
	public function setProgress(value:Float, label:String):Void
	{
		target = Math.max(0, Math.min(1, value));
		labelText.text = label;
	}

	/** La barra alcanza el valor poco a poco, no a saltos. */
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		shown += (target - shown) * Math.min(1, elapsed * 10);
		applyFill(shown);
		percentText.text = Std.int(shown * 100) + "%";
	}

	/** Termino: la barra se llena y Jazmin reparte una vez. */
	public function finish(message:String):Void
	{
		target = 1;
		labelText.text = message;
		if (jazmin != null) jazmin.animation.play("give", true);
	}

	function applyFill(value:Float):Void
	{
		fill.scale.x = Math.max(0.001, value);
	}
}
