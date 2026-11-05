package funky.game;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxBar;
import flixel.ui.FlxBar.FlxBarFillDirection;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import funky.core.Paths;
import funky.core.ClientPrefs;
import funky.core.Conductor;
import funkin.backend.utils.TranslationUtil as TU;
import openfl.utils.Assets;

/**
 * Resultado de tocar una nota: lo que se muestra y lo que reciben los scripts (`onNoteScored`).
 *  - rating:    sick / good / bad / shit
 *  - score:     puntos que dio esa pulsacion
 *  - precision: 100 = justo en el tiempo de la nota, 0 = al borde de la ventana de golpe
 *  - ms:        desfase de la pulsacion: negativo = temprano, positivo = tarde
 */
typedef PressScore =
{
	var rating:String;
	var score:Int;
	var precision:Float;
	var ms:Float;
}

/** HUD con la misma distribucion que `PsychHUD` del legacy: */
class PlayHUD extends FlxGroup
{
	/** Vida inicial del jugador, como en FNF. */
	/** Vida maxima (el minimo es 0). */
	public static inline var MAX_HEALTH:Float = 1;
	public static inline var START_HEALTH:Float = 0.5;

	/** Cuanto se mete cada icono en la barra respecto del borde de relleno. */
	static inline var ICON_OVERLAP:Float = 0.3;

	// Igual que PsychHUD: el rating nace ampliado y se encoge.
	public static inline var RATING_SCALE:Float = 0.7;
	public static inline var RATING_POP:Float = 0.785 / 0.7;
	public static inline var COMBO_SCALE:Float = 0.5;
	public static inline var COMBO_POP:Float = 0.6 / 0.5;
	public static inline var MIN_COMBO_DIGITS:Int = 3;

	/** Imagenes del popup: `images/game/score/<sick|good|bad|shit>.png` y `num0.png`..`num9.png`. */
	static inline var SCORE_DIR:String = "game/score/";
	/** Cifras maximas que muestra el combo con imagenes (si pasa, se ven las ultimas). */
	static inline var COMBO_SLOTS:Int = 5;

	static final RATING_COLORS:Map<String, FlxColor> = [
		"sick" => 0xFF4DC9FF,
		"good" => 0xFF6BE06B,
		"bad" => 0xFFFFB347,
		"shit" => 0xFFFF5555
	];

	var healthBar:HealthBar;
	var timeBar:FlxBar;
	var timeText:FlxText;
	/** Nombre de la cancion: el texto de la barra de tiempo es `songName - tiempo`. */
	var songName:String;
	/** Texto de botplay (null si no esta activo). Lo coloca `placeBotplay` y parpadea. */
	public var botplayText(default, null):FlxText;
	var botplaySine:Float = 0;
	var scoreText:FlxText;
	var ratingText:FlxText;
	/** Debajo del rating: puntos, precision y desfase de la ultima pulsacion. */
	var pressText:FlxText;
	var comboText:FlxText;
	var ratingImages:Map<String, FlxSprite> = new Map();
	var comboImages:Array<FlxSprite> = [];
	var songLength:Float;
	var barY:Float;
	var shownSecond:Int = -1;

    public var defaultFont:String;

	/** Vida del jugador, 0..1. La barra sigue a `shownHealth`, que la alcanza suavizada. */
	public var health:Float = START_HEALTH;
	@:keep public var shownHealth:Float = START_HEALTH;
	public var songTime:Float = 0;

    // estos
	public var iconPlayer(default, null):HealthIcon;
	public var iconOpponent(default, null):HealthIcon;

	public function new(songName:String, songLength:Float, ?levelDir:String, ?playerIcon:String, ?opponentIcon:String)
	{
		super();

        if (defaultFont == null || defaultFont == "") defaultFont = Paths.fontPath("PhantomMuff.ttf");
        
		this.songLength = Math.max(songLength, 1);
		this.songName = songName;
		var down = ClientPrefs.isDownScroll();

		barY = FlxG.height * (down ? 0.11 : 0.89);
		
		healthBar = new HealthBar(FlxColor.RED, FlxColor.GREEN); // BRUH, en otra actualizacion los hago custom
	
		healthBar.setPosition(FlxG.width / 2 - healthBar.frameWidth / 2, barY);
		add(healthBar);

		iconOpponent = SpriteBuilder.icon(levelDir, opponentIcon, false);
		iconPlayer = SpriteBuilder.icon(levelDir, playerIcon, true);
		add(iconOpponent);
		add(iconPlayer);
		placeIcons();

		scoreText = new FlxText(0, barY + 40, FlxG.width, "", 20);
		scoreText.setFormat(defaultFont, 20, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreText.borderSize = 1.25;
		add(scoreText);

		timeText = new FlxText(0, down ? FlxG.height - 44 : 19, FlxG.width, "", 32);
		timeText.setFormat(defaultFont, 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeText.borderSize = 2;
		timeText.alpha = 0;
		timeBar = new FlxBar(FlxG.width / 2 - 200, timeText.y + timeText.height / 4, FlxBarFillDirection.LEFT_TO_RIGHT, 400, 18, this, "YOU ARE GAY?", 0, this.songLength);
		timeBar.createFilledBar(0x8fff8aff, 0x1f0038ff, true, 0xFF000000); // (el flixel del fork no trae el grosor del borde)
		timeBar.alpha = 0;
		add(timeBar);
		add(timeText);

		ratingText = new FlxText(0, 0, 0, "", 64);
		ratingText.setFormat(defaultFont, 64, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		ratingText.borderSize = 3;
		ratingText.alpha = 0;
		add(ratingText);
		comboText = new FlxText(0, 0, 0, "", 64);
		comboText.setFormat(defaultFont, 64, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		comboText.borderSize = 3;
		comboText.alpha = 0;
		add(comboText);
		pressText = new FlxText(0, 0, 0, "", 22);
		pressText.setFormat(defaultFont, 22, 0xFF5CF0DC, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pressText.borderSize = 1.5;
		pressText.alpha = 0;
		add(pressText);

		// Rating y combo con las imagenes de images/game/score/. Lo que falte se queda con el texto de siempre.
		for (name in ["sick", "good", "bad", "shit"])
		{
			var file = Paths.image(SCORE_DIR + name);
			if (!Assets.exists(file)) continue;
			var image = new FlxSprite().loadGraphic(file);
			image.alpha = 0;
			ratingImages.set(name, image);
			add(image);
		}

		var hasNumbers = true;
		for (digit in 0...10)
			if (!Assets.exists(Paths.image(SCORE_DIR + "num" + digit))) hasNumbers = false;

		if (hasNumbers)
		{
			for (_ in 0...COMBO_SLOTS)
			{
				var image = new FlxSprite();
				image.alpha = 0;
				comboImages.push(image);
				add(image);
			}
		}

		// Botplay se guarda en las opciones y no cuenta fallos ni puntos: se deja a la vista para no jugar con el sin querer.
		if (ClientPrefs.isBotplay())
		{
			botplayText = new FlxText(0, 0, FlxG.width, TU.translate("game.botplay", null, "BOTPLAY"), 32);
			botplayText.setFormat(defaultFont, 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			botplayText.borderSize = 2;
			add(botplayText);
		}

		onUpdateScore(0, -1, 0);
		updateTime(0);
	}

	/** Pone el texto de botplay justo encima de la strumline del jugador, centrado sobre ella. */
	public function placeBotplay(lineX:Float, lineY:Float, lineWidth:Float):Void
	{
		if (botplayText == null) return;
		botplayText.fieldWidth = lineWidth;
		botplayText.x = lineX;
		botplayText.y = lineY - botplayText.height + 20;
	}

	/** El tiempo y su barra aparecen al empezar la cancion. */
	public function onSongStart():Void
	{
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeText, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
	}

	/** @param accuracy porcentaje 0..100, o negativo si todavia no se juzgo ninguna nota. */
	public function onUpdateScore(score:Int, accuracy:Float, misses:Int, missed:Bool = false):Void
	{
		var played = accuracy >= 0;
		var na = TU.translate("game.notAvailable", null, "N/A");
		var accText = played ? Std.string(Math.round(accuracy * 100) / 100) + "%" : na;
		var rank = played ? letterRank(accuracy, misses) : na;
		scoreText.text = TU.translate("game.stats", [formatNumber(score), misses, accText, rank],
			"Score: {0} | Misses: {1} | Accuracy: {2} | Rank: {3}") + "\n";
		if (!missed) doScoreBop();
	}

	/** Misma tabla de rangos que `Highscore.getLetterRank` del legacy. */
	public static function letterRank(accuracy:Float, misses:Int = 0):String
	{
		if (accuracy == 100 && misses == 0) return "P";
		if (accuracy > 99 && misses == 0) return "P";
		if (accuracy > 95 && misses == 0) return "S";
		if (accuracy > 90 && misses <= 20) return "A";
		if (accuracy > 85 && misses <= 30) return "B";
		if (accuracy > 70 && misses <= 50) return "C";
		if (accuracy > 50 && misses <= 70) return "D";
		return "F??";
	}

	public function doScoreBop():Void
	{
		FlxTween.cancelTweensOf(scoreText.scale);
		scoreText.scale.set(1.075, 1.075);
		FlxTween.tween(scoreText.scale, {x: 1, y: 1}, 0.2);
	}

	/** Popup de rating + combo, como `PsychHUD.popUpScore`. Con imagenes si estan en `game/score/`, si no con texto. */
	public function popUpScore(rating:String, combo:Int, ?press:PressScore):Void
	{
		var posX = FlxG.width * 0.35;
		var delay = Conductor.stepCrochet * 0.01;

		var image = ratingImages.get(rating);
		if (image != null)
		{
			for (other in ratingImages)
			{
				FlxTween.cancelTweensOf(other, ["alpha"]);
				other.alpha = 0;
			}
			ratingText.alpha = 0;
			// el origen es el centro: se coloca por el centro sin escalar y la escala crece desde ahi
			image.setPosition(posX - 40 - image.frameWidth / 2, FlxG.height / 2 - image.frameHeight / 2 - 60);
			image.alpha = 1;
			FlxTween.cancelTweensOf(image.scale);
			image.scale.set(RATING_SCALE * RATING_POP, RATING_SCALE * RATING_POP);
			FlxTween.tween(image.scale, {x: RATING_SCALE, y: RATING_SCALE}, 0.5, {ease: FlxEase.expoOut});
			FlxTween.tween(image, {alpha: 0}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
		}
		else
		{
			ratingText.text = rating.toUpperCase() + "!";
			ratingText.color = RATING_COLORS.exists(rating) ? RATING_COLORS.get(rating) : FlxColor.WHITE;
			ratingText.updateHitbox();
			ratingText.alpha = 1;
			ratingText.setPosition(posX - 40 - ratingText.width / 2, FlxG.height / 2 - ratingText.height / 2 - 60);
			FlxTween.cancelTweensOf(ratingText, ["alpha"]);
			FlxTween.cancelTweensOf(ratingText.scale);
			ratingText.scale.set(RATING_SCALE * RATING_POP, RATING_SCALE * RATING_POP);
			FlxTween.tween(ratingText.scale, {x: RATING_SCALE, y: RATING_SCALE}, 0.5, {ease: FlxEase.expoOut});
			FlxTween.tween(ratingText, {alpha: 0}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
		}

		var digits = Std.string(combo);
		while (digits.length < MIN_COMBO_DIGITS) digits = "0" + digits;

		if (comboImages.length > 0)
		{
			comboText.alpha = 0;
			if (digits.length > comboImages.length) digits = digits.substr(digits.length - comboImages.length);

			for (slot in comboImages)
			{
				FlxTween.cancelTweensOf(slot, ["alpha"]);
				FlxTween.cancelTweensOf(slot.scale);
				slot.alpha = 0;
			}

			var centerY = FlxG.height / 2 + 80;
			var width = 0.0;
			for (i in 0...digits.length)
			{
				var slot = comboImages[i];
				slot.loadGraphic(Paths.image(SCORE_DIR + "num" + digits.charAt(i)));
				width += slot.frameWidth * COMBO_SCALE;
			}

			var left = posX - width / 2;
			for (i in 0...digits.length)
			{
				var slot = comboImages[i];
				var cell = slot.frameWidth * COMBO_SCALE;
				slot.setPosition(left + cell / 2 - slot.frameWidth / 2, centerY - slot.frameHeight / 2);
				left += cell;
				slot.alpha = 1;
				slot.scale.set(COMBO_SCALE * COMBO_POP, COMBO_SCALE * COMBO_POP);
				FlxTween.tween(slot.scale, {x: COMBO_SCALE, y: COMBO_SCALE}, 0.5, {ease: FlxEase.expoOut});
				FlxTween.tween(slot, {alpha: 0}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
			}
		}
		else
		{
			comboText.text = digits;
			comboText.updateHitbox();
			comboText.alpha = 1;
			comboText.setPosition(posX - comboText.width / 2, FlxG.height / 2 - comboText.height / 2 + 80);
			FlxTween.cancelTweensOf(comboText, ["alpha"]);
			FlxTween.cancelTweensOf(comboText.scale);
			comboText.scale.set(COMBO_SCALE * COMBO_POP, COMBO_SCALE * COMBO_POP);
			FlxTween.tween(comboText.scale, {x: COMBO_SCALE, y: COMBO_SCALE}, 0.5, {ease: FlxEase.expoOut});
			FlxTween.tween(comboText, {alpha: 0}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
		}

		if (press != null) showPress(press, posX, delay);
	}

	/** Texto chico (celeste) arriba del rating con la precision de la pulsacion. Entra con un mini pop. */
	function showPress(press:PressScore, posX:Float, delay:Float):Void
	{
		pressText.text = formatPercent(press.precision);
		pressText.updateHitbox();

		var ratingImage = ratingImages.get(press.rating);
		var ratingTop = FlxG.height / 2 - 60 - (ratingImage != null ? ratingImage.frameHeight * RATING_SCALE : ratingText.height) / 2;
		pressText.setPosition(posX - 40 - pressText.width / 2, ratingTop - pressText.height - 4);

		FlxTween.cancelTweensOf(pressText, ["alpha"]);
		FlxTween.cancelTweensOf(pressText.scale);
		pressText.alpha = 1;
		pressText.scale.set(1.2, 1.2);
		FlxTween.tween(pressText.scale, {x: 1, y: 1}, 0.15, {ease: FlxEase.expoOut});
		FlxTween.tween(pressText, {alpha: 0}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
	}

	/** "91.3%" (precision 0..100, un decimal). */
	public static function formatPercent(value:Float):String
		return Std.string(Math.round(value * 10) / 10) + "%";

	/** "-12.4ms" / "+8ms": negativo = temprano, positivo = tarde. */
	public static function formatMs(ms:Float):String
	{
		var rounded = Math.round(ms * 10) / 10;
		return (rounded > 0 ? "+" : "") + Std.string(rounded) + "ms";
	}

	/**
	 * Numero para el HUD: con separador de miles (`55,150`) y, de 10 millones para arriba, abreviado (`12.3M`) para que nunca
	 * salgan filas enormes de digitos.
	 */
	public static function formatNumber(value:Int):String
	{
		var abs = Math.abs(value);
		if (abs >= 1000000000) return Std.string(Math.round(value / 100000000) / 10) + "B";
		if (abs >= 10000000) return Std.string(Math.round(value / 100000) / 10) + "M";
		return FlxStringUtil.formatMoney(value, false);
	}

	/** "Time Left" de Psych: lo que falta de cancion, una vez por segundo. */
	public function updateTime(time:Float):Void
	{
		songTime = Math.min(time, songLength);
		var second = Std.int(songTime / 1000);
		if (second == shownSecond) return;
		shownSecond = second;
		timeText.text = /*songName + " - " + */ FlxStringUtil.formatTime(Math.floor(Math.max(0, songLength - songTime) / 1000), false);
	}

	/** Suma (o resta) vida del jugador, limitada a 0..1. */
	public function addHealth(amount:Float):Void
	{
		setHealth(health + amount);
	}

	/** Pone la vida del jugador, limitada a 0..MAX_HEALTH. */
	public function setHealth(value:Float):Void
	{
		health = Math.max(0, Math.min(MAX_HEALTH, value));
	}

	/** Llamar una vez por beat: los iconos hacen su pulso. */
	public function beatHit():Void
	{
		iconPlayer.bop();
		iconOpponent.bop();
	}

	override public function update(elapsed:Float):Void
	{
		shownHealth += (health - shownHealth) * Math.min(1, elapsed * 8);
		super.update(elapsed);

		if (botplayText != null)
		{
			botplaySine += 180 * elapsed;
			botplayText.alpha = 1 - Math.sin(Math.PI * botplaySine / 180);
		}
		healthBar.setHealth(shownHealth);
		iconPlayer.updateHealth(shownHealth);
		iconOpponent.updateHealth(shownHealth);
		placeIcons();
	}

	/** Cada icono se apoya en el borde del relleno, hacia su propio lado. */
	function placeIcons():Void
	{
		var edge = healthBar.edgeX(shownHealth);
		var centerY = healthBar.centerY();
		var reach = HealthIcon.FIT * ICON_OVERLAP;
		iconPlayer.centerAt(edge + reach, centerY);
		iconOpponent.centerAt(edge - reach, centerY);
	}
}
