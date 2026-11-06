package funky.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import funky.core.KeyBinds;
import funky.core.Paths;
import funky.core.Log;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import funkin.backend.utils.TranslationUtil as TU;

/**
 * Pantalla de titulo basica: degradado, logo, GF bailando y el aviso de "Press Enter", todo al ritmo
 * de la musica del menu. Sin franjas de lane ni notas cayendo.
 */
class TitleState extends FlxState
{
	public static final TITLE:String = "FMCE";

	var COMPILATION:String = "";

	private static final TITLE_COLOR:Int = 0xFFFFFFFF;
	private static final HINT_COLOR:Int = 0xFFB8B8C6;
	private static final DIM_COLOR:Int = 0xFF6E6E7A;
	private static final OUTLINE_COLOR:Int = 0xFF00FFFF;
	private static final BPM:Float = 102;

	private var background:FlxSprite;
	private var logo:FlxSprite;
	private var gf:FlxSprite;
	private var enterSprite:FlxSprite;
	private var fallbackTitle:FlxText;
	private var lastBeat:Int = -1;
	private var tagText:FlxText;
	private var hintText:FlxText;
	private var footerText:FlxText;
	private var clock:Float = 0;
	private var confirmed:Bool = false;

	override public function create():Void
	{
		super.create();

		#if desktop
		COMPILATION = TU.translate("title.desktop", null, "DESKTOP");
		#else
		COMPILATION = TU.translate("title.mobile", null, "MOBILE");
		#end

		background = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [0xFF0B0B16, 0xFF1B1030, 0xFF2D1646], 24);
		background.scrollFactor.set();
		add(background);

		// Logo y GF salen de assets/images/menus/titlescreen. Siempre con escala UNIFORME (misma en x e y):
		// asi nada se aplasta, solo se reduce para que quepa.
		var logoFrames = Paths.getSparrowAtlas("menus/titlescreen/logo");
		if (logoFrames != null)
		{
			logo = new FlxSprite();
			logo.frames = logoFrames;
			logo.animation.addByPrefix("bump", "logo bumpin", 24, false);
			logo.animation.play("bump", true);
			logo.antialiasing = true;
			logo.scrollFactor.set();
			fit(logo, FlxG.width * 0.52, FlxG.height * 0.62);
			logo.setPosition(FlxG.width * 0.04, FlxG.height * 0.5 - logo.height * 0.5 - 10);
			add(logo);
		}

		var gfFrames = Paths.getSparrowAtlas("menus/titlescreen/gf");
		if (gfFrames != null)
		{
			gf = new FlxSprite();
			gf.frames = gfFrames;
			gf.animation.addByIndices("danceLeft", "gfDance", [for (i in 0...15) i], "", 24, false);
			gf.animation.addByIndices("danceRight", "gfDance", [for (i in 15...30) i], "", 24, false);
			gf.animation.play("danceLeft");
			gf.antialiasing = true;
			gf.scrollFactor.set();
			fit(gf, FlxG.width * 0.42, FlxG.height * 0.82);
			gf.setPosition(FlxG.width * 0.97 - gf.width, FlxG.height - gf.height - 8);
			add(gf);
		}

		// Sin los atlas (build sin assets) queda un titulo de texto normal, sin deformar.
		if (logo == null)
		{
			fallbackTitle = new FlxText(0, FlxG.height * 0.3, FlxG.width * 0.55, TITLE, 110);
			fallbackTitle.alignment = FlxTextAlign.CENTER;
			fallbackTitle.setBorderStyle(FlxTextBorderStyle.OUTLINE, OUTLINE_COLOR, 6);
			fallbackTitle.scrollFactor.set();
			fitText(fallbackTitle, FlxG.width * 0.55 - 12);
			add(fallbackTitle);
		}

		tagText = new FlxText(FlxG.width * 0.04, FlxG.height * 0.5 + FlxG.height * 0.31 - 6, FlxG.width * 0.52, COMPILATION, 20);
		tagText.alignment = FlxTextAlign.CENTER;
		tagText.color = HINT_COLOR;
		tagText.setBorderStyle(FlxTextBorderStyle.SHADOW, 0xFF000000, 2);
		fitText(tagText, FlxG.width * 0.52 - 8);
		add(tagText);

		// "Press Enter" solo en escritorio: el atlas dice exactamente eso. En el celular, texto normal.
		var enterFrames = TouchNav.MOBILE ? null : Paths.getSparrowAtlas("menus/titlescreen/titleEnter");
		if (enterFrames != null)
		{
			enterSprite = new FlxSprite();
			enterSprite.frames = enterFrames;
			enterSprite.animation.addByPrefix("idle", "Press Enter to Begin", 24, true);
			enterSprite.animation.addByPrefix("pressed", "ENTER PRESSED", 24, true);
			enterSprite.animation.play("idle");
			enterSprite.antialiasing = true;
			enterSprite.scrollFactor.set();
			fit(enterSprite, FlxG.width * 0.42, FlxG.height * 0.1);
			enterSprite.setPosition(FlxG.width * 0.04 + (FlxG.width * 0.52 - enterSprite.width) / 2, FlxG.height - enterSprite.height - 36);
			add(enterSprite);
		}
		else
		{
			hintText = new FlxText(FlxG.width * 0.04, FlxG.height - 110, FlxG.width * 0.52,
				TouchNav.MOBILE ? TU.translate("title.tap", null, "TOCA LA PANTALLA") : KeyBinds.labelWithGamepad(KeyBinds.ACCEPT), 28);
			hintText.alignment = FlxTextAlign.CENTER;
			hintText.color = TITLE_COLOR;
			hintText.setBorderStyle(FlxTextBorderStyle.SHADOW, 0xFF000000, 3);
			fitText(hintText, FlxG.width * 0.52 - 8);
			add(hintText);
		}

		footerText = new FlxText(0, FlxG.height - 30, FlxG.width, "TheJarretLabs 2026", 14);
		footerText.alignment = FlxTextAlign.CENTER;
		footerText.color = DIM_COLOR;
		add(footerText);

		funky.core.CoolUtil.playMenuSong();

		Log.info('[TitleState] created');

		TransitionHandler.playIn(this);
	}

	/** Escala UNIFORME para que quepa en maxW x maxH sin deformar (nunca agranda mas de 1.5x). */
	private function fit(sprite:FlxSprite, maxW:Float, maxH:Float):Void
	{
		// El frame MAS GRANDE de todas las animaciones, no el primero: si no, "bump" o
		// "ENTER PRESSED" (mas grandes que el frame 0) se salen de su caja.
		var w:Float = Math.max(1, sprite.frameWidth);
		var h:Float = Math.max(1, sprite.frameHeight);
		if (sprite.frames != null)
			for (f in sprite.frames.frames)
			{
				w = Math.max(w, f.sourceSize.x);
				h = Math.max(h, f.sourceSize.y);
			}
		var k = Math.min(1.5, Math.min(maxW / w, maxH / h));
		sprite.scale.set(k, k);
		sprite.updateHitbox();
	}

	/**
	 * Achica la letra hasta que el texto quepa en `maxWidth` en UNA linea. Asi nada se parte en dos
	 * renglones ni se sale de su caja en pantallas angostas (el ancho del campo es fijo, la letra no).
	 */
	private function fitText(text:FlxText, maxWidth:Float, minSize:Int = 10):Void
	{
		text.wordWrap = false;
		while (text.size > minSize && text.textField.textWidth > maxWidth)
			text.size -= 1;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		clock += elapsed;

		// Latido: una vez por beat el logo rebota y GF cambia de lado.
		var beatInt = Math.floor(clock * BPM / 60);
		if (beatInt != lastBeat)
		{
			lastBeat = beatInt;
			if (logo != null) logo.animation.play("bump", true);
			if (gf != null) gf.animation.play(beatInt % 2 == 0 ? "danceLeft" : "danceRight", true);
		}
		if (fallbackTitle != null) fallbackTitle.borderColor = FlxColor.fromHSB((clock * 40) % 360, 0.65, 1);
		if (hintText != null) hintText.alpha = 0.45 + 0.55 * Math.sin(clock * 3);

		if (KeyBinds.justPressed(KeyBinds.ACCEPT) || TouchNav.tapped()) confirm();
	}

	private function confirm():Void
	{
		if (confirmed) return;
		confirmed = true;

		FlxG.camera.flash(0xFFFFFFFF, 0.3);
		if (enterSprite != null) enterSprite.animation.play("pressed");

		Log.info('[TitleState] -> MainMenuState');
		TransitionHandler.switchState(new MainMenuState());
	}

	override public function destroy():Void
	{
		super.destroy();

		background = null;
		logo = null;
		gf = null;
		enterSprite = null;
		fallbackTitle = null;
		tagText = null;
		hintText = null;
		footerText = null;
	}
}
