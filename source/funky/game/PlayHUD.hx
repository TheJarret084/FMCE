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
	/** Escala de los digitos de puntos y precision (mas chicos que los del combo) y cuantos digitos caben en cada fila. */
	public static inline var PRESS_SCALE:Float = 0.3;
	static inline var SCORE_SLOTS:Int = 4;
	static inline var PRECISION_SLOTS:Int = 3;

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
	var scoreText:FlxText;
	var ratingText:FlxText;
	/** Debajo del rating: puntos, precision y desfase de la ultima pulsacion. */
	var pressText:FlxText;
	var comboText:FlxText;
	var ratingImages:Map<String, FlxSprite> = new Map();
	var comboImages:Array<FlxSprite> = [];
	/** Puntos y precision de la ultima pulsacion con los mismos sprites num0..9 del combo (`percent.png` es opcional). */
	var scoreSlots:Array<FlxSprite> = [];
	var precisionSlots:Array<FlxSprite> = [];
	var percentImage:FlxSprite;
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
		timeBar = new FlxBar(FlxG.width / 2 - 200, timeText.y + timeText.height / 4, FlxBarFillDirection.LEFT_TO_RIGHT, 400, 18, this, "songTime", 0, this.songLength);
		timeBar.createFilledBar(0xFF000000, 0xFFFFFFFF, true, 0xFF000000); // (el flixel del fork no trae el grosor del borde)
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
		pressText = new FlxText(0, 0, 0, "", 28);
		pressText.setFormat(defaultFont, 28, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pressText.borderSize = 2;
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
			for (_ in 0...SCORE_SLOTS)
			{
				var image = new FlxSprite();
				image.alpha = 0;
				scoreSlots.push(image);
				add(image);
			}
			for (_ in 0...PRECISION_SLOTS)
			{
				var image = new FlxSprite();
				image.alpha = 0;
				precisionSlots.push(image);
				add(image);
			}
			var percentFile = Paths.image(SCORE_DIR + "percent");
			if (Assets.exists(percentFile))
			{
				percentImage = new FlxSprite().loadGraphic(percentFile);
				percentImage.alpha = 0;
				add(percentImage);
			}
		}

		// Botplay se guarda en las opciones y no cuenta fallos ni puntos: se deja a la vista para no jugar con el sin querer.
		if (ClientPrefs.isBotplay())
		{
			var botplayText = new FlxText(0, down ? FlxG.height - 100 : 76, FlxG.width, "BOTPLAY", 32);
			botplayText.setFormat(defaultFont, 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			botplayText.borderSize = 2;
			add(botplayText);
		}

		onUpdateScore(0, -1, 0);
		updateTime(0);
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
		var accText = played ? Std.string(Math.round(accuracy * 100) / 100) + "%" : "N/A";
		var rank = played ? letterRank(accuracy, misses) : "N/A";
		scoreText.text = "Score: " + FlxStringUtil.formatMoney(score, false) + " | Misses: " + misses + " | Accuracy: " + accText + " | Rank: " + rank + "\n";
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
		return "F";
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

	/** "+350  |  91.3%  |  -12 ms" entre el rating y el combo. */
	function showPress(press:PressScore, posX:Float, delay:Float):Void
	{
		// con los sprites num0..9: una fila "350  91%" entre el rating y el combo, a la escala que quepa en ese hueco
		if (scoreSlots.length > 0)
		{
			pressText.alpha = 0;
			var scorePieces = prepareDigits(scoreSlots, press.score, null);
			var precisionPieces = prepareDigits(precisionSlots, Math.round(press.precision), percentImage);

			var ratingImage = ratingImages.get(press.rating);
			var ratingBottom = FlxG.height / 2 - 60 + (ratingImage != null ? ratingImage.frameHeight * RATING_SCALE : ratingText.height) / 2;
			var comboTop = FlxG.height / 2 + 80 - (comboImages.length > 0 ? comboImages[0].frameHeight * COMBO_SCALE : comboText.height) / 2;

			var digitHeight = 1.0;
			for (piece in scorePieces.concat(precisionPieces)) digitHeight = Math.max(digitHeight, piece.frameHeight);
			var scale = Math.max(0.12, Math.min(PRESS_SCALE, (comboTop - ratingBottom - 8) / digitHeight));

			var scoreWidth = piecesWidth(scorePieces, scale);
			var gap = 80 * scale;
			var left = posX - 40 - (scoreWidth + gap + piecesWidth(precisionPieces, scale)) / 2;
			var top = ratingBottom + 4;
			placePieces(scorePieces, left, top, scale, delay);
			placePieces(precisionPieces, left + scoreWidth + gap, top, scale, delay);
			return;
		}

		var ms = Math.round(press.ms);
		pressText.text = "+" + press.score + "  |  " + Std.string(Math.round(press.precision * 10) / 10) + "%  |  " + (ms > 0 ? "+" : "") + ms + " ms";
		pressText.color = RATING_COLORS.exists(press.rating) ? RATING_COLORS.get(press.rating) : FlxColor.WHITE;
		pressText.updateHitbox();
		pressText.setPosition(posX - 40 - pressText.width / 2, FlxG.height / 2 + 15);
		FlxTween.cancelTweensOf(pressText, ["alpha"]);
		pressText.alpha = 1;
		FlxTween.tween(pressText, {alpha: 0}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
	}

	/** Carga los sprites num0..9 de `value` en `slots` (y suma `tail` al final); devuelve las piezas en orden. Todas quedan ocultas. */
	function prepareDigits(slots:Array<FlxSprite>, value:Int, tail:Null<FlxSprite>):Array<FlxSprite>
	{
		var digits = Std.string(Std.int(Math.max(0, value)));
		if (digits.length > slots.length) digits = digits.substr(digits.length - slots.length);

		for (slot in slots)
		{
			FlxTween.cancelTweensOf(slot, ["alpha"]);
			FlxTween.cancelTweensOf(slot.scale);
			slot.alpha = 0;
		}
		var pieces:Array<FlxSprite> = [];
		for (i in 0...digits.length)
		{
			slots[i].loadGraphic(Paths.image(SCORE_DIR + "num" + digits.charAt(i)));
			pieces.push(slots[i]);
		}
		if (tail != null)
		{
			FlxTween.cancelTweensOf(tail, ["alpha"]);
			FlxTween.cancelTweensOf(tail.scale);
			tail.alpha = 0;
			pieces.push(tail);
		}
		return pieces;
	}

	function piecesWidth(pieces:Array<FlxSprite>, scale:Float):Float
	{
		var width = 0.0;
		for (piece in pieces) width += piece.frameWidth * scale;
		return width;
	}

	/** Pone las piezas una tras otra desde `left`, con el mismo pop y fade que el combo. */
	function placePieces(pieces:Array<FlxSprite>, left:Float, topY:Float, scale:Float, delay:Float):Void
	{
		var height = 0.0;
		for (piece in pieces) height = Math.max(height, piece.frameHeight * scale);
		for (piece in pieces)
		{
			var cell = piece.frameWidth * scale;
			piece.setPosition(left + cell / 2 - piece.frameWidth / 2, topY + height / 2 - piece.frameHeight / 2);
			left += cell;
			piece.alpha = 1;
			piece.scale.set(scale * COMBO_POP, scale * COMBO_POP);
			FlxTween.tween(piece.scale, {x: scale, y: scale}, 0.5, {ease: FlxEase.expoOut});
			FlxTween.tween(piece, {alpha: 0}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
		}
	}

	/** "Time Left" de Psych: lo que falta de cancion, una vez por segundo. */
	public function updateTime(time:Float):Void
	{
		songTime = Math.min(time, songLength);
		var second = Std.int(songTime / 1000);
		if (second == shownSecond) return;
		shownSecond = second;
		timeText.text = FlxStringUtil.formatTime(Math.floor(Math.max(0, songLength - songTime) / 1000), false);
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
