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
import funky.core.NoteSkin;
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

/** Estilos de la barra de tiempo (opcion `timeBarStyle`). */
enum abstract TimeBarStyle(String) to String
{
	/** Rosa y lima. */
	var PINK_LIME = "pinklime";
	/** Blanco y negro. */
	var MONO = "mono";
	/** Degradado con los colores de las notas del skin (los de cada lane). */
	var MULTI = "multi";

	public static function parse(value:Null<String>):TimeBarStyle
	{
		return switch (value == null ? "" : StringTools.trim(value).toLowerCase())
		{
			case "mono" | "bw" | "blackwhite": MONO;
			case "multi" | "multicolor" | "notes": MULTI;
			default: PINK_LIME;
		}
	}
}

/**
 * HUD con la misma distribucion que `PsychHUD` del legacy.
 *
 * `@:keep` para que los scripts (que resuelven `healthBar`, `timeBar`, `scoreTxt`... por reflexion sobre el PlayState)
 * puedan ver todos los campos aunque el DCE los vea sin uso.
 */
@:keep
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

	/** Colores de la barra de tiempo (FlxColor ARGB, opacos). Publicos por si un script los quiere cambiar. */
	public static var PINK:FlxColor = 0xFFFF8AFF;
	public static var LIME:FlxColor = 0xFF8FFF8A;

	/** Ancho / alto de la barra de tiempo. */
	static inline var TIME_BAR_WIDTH:Int = 400;
	static inline var TIME_BAR_HEIGHT:Int = 18;

	public var healthBar(default, null):HealthBar;
	public var timeBar(default, null):FlxBar;
	public var timeText(default, null):FlxText;
	/** Estilo actual de la barra de tiempo. Cambiarlo con `setTimeBarStyle`. */
	public var timeBarStyle(default, null):TimeBarStyle = TimeBarStyle.PINK_LIME;
	var laneCount:Int = 4;
	/** Nombre de la cancion: el texto de la barra de tiempo es `songName - tiempo`. */
	var songName:String;
	/** Texto de botplay (null si no esta activo). Lo coloca `placeBotplay` y parpadea. */
	public var botplayText(default, null):FlxText;
	var botplaySine:Float = 0;
	/** Strumline del jugador: el texto de botplay se pega a sus receptores y los sigue (si un script o evento los mueve). */
	var botplayLine:Null<StrumLine>;
	/** Separacion (px) entre el borde de abajo del texto de botplay y el borde de arriba de los receptores. */
	public static inline var BOTPLAY_GAP:Float = 6;
	/** Debajo de la barra de vida, como en Codename: puntos (derecha), fallos (centro) y precision (izquierda). */
	public var scoreTxt(default, null):FlxText;
	public var missesTxt(default, null):FlxText;
	public var accuracyTxt(default, null):FlxText;
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

	public function new(songName:String, songLength:Float, ?levelDir:String, ?playerIcon:String, ?opponentIcon:String, ?laneCount:Int)
	{
		super();

		if (laneCount != null) this.laneCount = laneCount;

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

		// Tres textos separados bajo la barra, igual que Codename: mismo rectangulo (barra menos 50px por lado), cada uno alineado distinto.
		var textX = healthBar.x + 50;
		var textY = barY + 40;
		var textWidth = Std.int(Math.max(1, healthBar.frameWidth - 100));
		scoreTxt = makeStatText(textX, textY, textWidth, FlxTextAlign.RIGHT);
		missesTxt = makeStatText(textX, textY, textWidth, FlxTextAlign.CENTER);
		accuracyTxt = makeStatText(textX, textY, textWidth, FlxTextAlign.LEFT);

		timeText = new FlxText(0, down ? FlxG.height - 44 : 19, FlxG.width, "", 32);
		timeText.setFormat(defaultFont, 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeText.borderSize = 2;
		timeText.alpha = 0;
		// Sin parentRef: `updateTime` le pasa el valor a mano (antes apuntaba a una variable que no existe y la barra nunca se llenaba).
		timeBar = new FlxBar(FlxG.width / 2 - TIME_BAR_WIDTH / 2, timeText.y + timeText.height / 4, FlxBarFillDirection.LEFT_TO_RIGHT, TIME_BAR_WIDTH, TIME_BAR_HEIGHT, null, "", 0, this.songLength);
		// Un paso por pixel (por defecto son 100 y la barra avanzaba a saltos).
		timeBar.numDivisions = TIME_BAR_WIDTH;
		setTimeBarStyle(TimeBarStyle.parse(ClientPrefs.getTimeBarStyle()));
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

	/**
	 * Pone el texto de botplay encima de la strumline del jugador, centrado sobre ella. Esta version usa los numeros que se
	 * pasan (sirve antes de que existan los receptores); `followBotplay` lo deja pegado a los receptores de verdad.
	 */
	public function placeBotplay(lineX:Float, lineY:Float, lineWidth:Float):Void
	{
		if (botplayText == null) return;
		setBotplayRect(lineX, lineY, lineWidth);
	}

	/** El texto de botplay se pega a los receptores de `line` (su x, ancho y alto reales) y los sigue cada frame. */
	public function followBotplay(line:StrumLine):Void
	{
		botplayLine = line;
		syncBotplay();
	}

	/** Centra el texto sobre [left, left + width] con su borde de abajo `BOTPLAY_GAP` px arriba de `top`. */
	function setBotplayRect(left:Float, top:Float, width:Float):Void
	{
		if (botplayText.fieldWidth != width) botplayText.fieldWidth = width;
		botplayText.x = left;

		// textHeight sale del texto ya armado: no depende de que el FlxText se haya redibujado todavia.
		var textHeight = botplayText.textField.textHeight + 4;
		if (!(textHeight > 4)) textHeight = botplayText.size * 1.3;
		botplayText.y = top - textHeight - BOTPLAY_GAP;
	}

	function syncBotplay():Void
	{
		if (botplayText == null || botplayLine == null) return;

		var left = Math.POSITIVE_INFINITY;
		var right = Math.NEGATIVE_INFINITY;
		var top = Math.POSITIVE_INFINITY;
		for (strum in botplayLine.members)
		{
			if (strum == null || !strum.exists) continue;
			left = Math.min(left, strum.x);
			right = Math.max(right, strum.x + strum.width);
			top = Math.min(top, strum.y);
		}
		if (left > right) return; // la linea no tiene receptores

		setBotplayRect(left, top, right - left);
	}

	function makeStatText(x:Float, y:Float, width:Int, align:FlxTextAlign):FlxText
	{
		var text = new FlxText(x, y, width, "", 20);
		text.setFormat(defaultFont, 20, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 1.25;
		text.scrollFactor.set();
		add(text);
		return text;
	}

	/** Cambia el estilo de la barra de tiempo (un script puede llamarlo en cualquier momento). */
	public function setTimeBarStyle(style:TimeBarStyle):Void
	{
		timeBarStyle = style;

		switch (style)
		{
			case TimeBarStyle.MONO:
				// Blanco sobre negro; el borde blanco deja ver la parte vacia aunque el fondo sea oscuro.
				timeBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE, true, FlxColor.WHITE);
			case TimeBarStyle.MULTI:
				var fill = laneColors();
				var empty = [for (color in fill) FlxColor.interpolate(color, FlxColor.BLACK, 0.75)];
				timeBar.createGradientBar(empty, fill, 1, 180, true, FlxColor.BLACK);
			case TimeBarStyle.PINK_LIME:
				// Los colores van en ARGB: antes eran `0x8fff8aff` / `0x1f0038ff` (RGBA), asi que salian con alfa raro y casi transparentes.
				timeBar.createFilledBar(LIME, PINK, true, FlxColor.BLACK);
		}

		timeBar.value = songTime;
	}

	/** Colores de la barra con dos colores sueltos (empty = lo que falta, fill = lo avanzado). Deja el estilo en `PINK_LIME`. */
	public function setTimeBarColors(empty:FlxColor, fill:FlxColor, border:FlxColor = FlxColor.BLACK):Void
	{
		timeBarStyle = TimeBarStyle.PINK_LIME;
		timeBar.createFilledBar(empty, fill, true, border);
		timeBar.value = songTime;
	}

	/** Un color por lane (los del skin de notas o, si no define, los de settings.xml): el degradado del modo multicolor. */
	function laneColors():Array<FlxColor>
	{
		var skin = NoteSkin.current();
		var out:Array<FlxColor> = [];

		for (lane in 0...laneCount)
		{
			var color:Null<Int> = skin.colorFor(lane, false, laneCount);
			if (color == null) color = ClientPrefs.noteColorForLane(lane, false, laneCount);
			out.push(FlxColor.fromInt(0xFF000000 | color));
		}

		// el degradado necesita 2 colores como minimo
		if (out.length == 1) out.push(out[0]);
		return out;
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
		scoreTxt.text = TU.translate("game.score", [formatNumber(score)], "Score: {0}");
		missesTxt.text = TU.translate("game.misses", [misses], "Misses: {0}");
		accuracyTxt.text = TU.translate("game.accuracy", [accText, rank], "Accuracy: {0} ({1})");
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
		FlxTween.cancelTweensOf(scoreTxt.scale);
		scoreTxt.scale.set(1.075, 1.075);
		FlxTween.tween(scoreTxt.scale, {x: 1, y: 1}, 0.2);
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
		timeBar.value = songTime;
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
			syncBotplay();
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
