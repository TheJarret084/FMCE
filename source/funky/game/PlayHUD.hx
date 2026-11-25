package funky.game;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
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
import funky.backend.assets.Paths;
import funky.backend.system.ClientPrefs;
import funky.backend.system.Conductor;
import funky.backend.skins.HudSkin;
import funky.backend.utils.TranslationUtil as TU;

typedef PressScore =
{
	var rating:String;
	var score:Int;
	var precision:Float;
	var ms:Float;
}

enum abstract TimeBarStyle(String) to String
{

	var PINK_LIME = "pinklime";

	var MONO = "mono";

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

@:keep
class PlayHUD extends FlxGroup
{

	public static inline var MAX_HEALTH:Float = 1;
	public static inline var START_HEALTH:Float = 0.5;

	static inline var ICON_OVERLAP:Float = 0.3;

	public static inline var RATING_SCALE:Float = 0.7;
	public static inline var RATING_POP:Float = 0.785 / 0.7;
	public static inline var COMBO_SCALE:Float = 0.5;
	public static inline var COMBO_POP:Float = 0.6 / 0.5;
	public static inline var MIN_COMBO_DIGITS:Int = 3;

	var scoreDir:String = "game/score";

	static inline var COMBO_SLOTS:Int = 5;

	static final RATING_COLORS:Map<String, FlxColor> = [
		"sick" => 0xFF4DC9FF,
		"good" => 0xFF6BE06B,
		"bad" => 0xFFFFB347,
		"shit" => 0xFFFF5555
	];

	public static var PINK:FlxColor = 0xFFFF8AFF;
	public static var LIME:FlxColor = 0xFF8FFF8A;

	public var healthBar(default, null):HealthBar;
	public var timeBar(default, null):FlxBar;
	public var timeBarBG(default, null):FlxSprite;
	public var timeText(default, null):FlxText;

	public var timeBarStyle(default, null):TimeBarStyle = TimeBarStyle.PINK_LIME;
	var laneCount:Int = 4;

	var songName:String;

	public var botplayText(default, null):FlxText;
	var botplaySine:Float = 0;

	var botplayLine:Null<StrumLine>;

	public static inline var STAT_SIDE_PAD:Float = 110;

	public var scoreTxt(default, null):FlxText;
	public var missesTxt(default, null):FlxText;
	public var accuracyTxt(default, null):FlxText;
	var ratingText:FlxText;

	var pressText:FlxText;
	var comboText:FlxText;
	var ratingImages:Map<String, FlxSprite> = new Map();
	var comboImages:Array<FlxSprite> = [];

	/** Digitos del combo ya decodificados (antes se leian del disco y se subian a la GPU en cada acierto). */
	var digitGraphics:Array<FlxGraphic> = [];

	/** Sprites casi transparentes que obligan a subir las texturas a la GPU antes del primer acierto. */
	var warmDigits:Array<FlxSprite> = [];
	var warmFrames:Int = 0;
	var songLength:Float;
	var barY:Float;
	var shownSecond:Int = -1;

	public var defaultFont:String;

	var hudSkin:HudSkin;
	var timeBarWidth:Int = 400;
	var timeBarHeight:Int = 18;
	var timeBarBgPad:Int = 4;

	public var health:Float = START_HEALTH;
	@:keep public var shownHealth:Float = START_HEALTH;
	public var songTime:Float = 0;

	public var iconPlayer(default, null):HealthIcon;
	public var iconOpponent(default, null):HealthIcon;

	public function new(songName:String, songLength:Float, ?levelDir:String, ?playerIcon:String, ?opponentIcon:String, ?laneCount:Int)
	{
		super();

		if (laneCount != null) this.laneCount = laneCount;

		hudSkin = HudSkin.current();
		scoreDir = hudSkin.scoreDir;
		timeBarWidth = hudSkin.timeBarWidth;
		timeBarHeight = hudSkin.timeBarHeight;
		timeBarBgPad = hudSkin.timeBarBgPad;

		var skinFont = hudSkin.fontPath();
		if (defaultFont == null || defaultFont == "") defaultFont = skinFont;
		if (defaultFont == null || defaultFont == "") defaultFont = Paths.fontPath("PhantomMuff.ttf");

		this.songLength = Math.max(songLength, 1);
		this.songName = songName;
		var down = ClientPrefs.isDownScroll();

		barY = FlxG.height * (down ? 0.11 : 0.89);

		healthBar = new HealthBar(FlxColor.RED, FlxColor.GREEN);

		healthBar.setPosition(FlxG.width / 2 - healthBar.frameWidth / 2, barY);
		add(healthBar);

		iconOpponent = SpriteBuilder.icon(levelDir, opponentIcon, false);
		iconPlayer = SpriteBuilder.icon(levelDir, playerIcon, true);
		add(iconOpponent);
		add(iconPlayer);
		placeIcons();

		var pad = Math.max(0, Math.min(STAT_SIDE_PAD, healthBar.x - 10));
		var textX = healthBar.x - pad;
		var textY = barY + 40;
		var textWidth = Std.int(Math.max(1, healthBar.frameWidth + pad * 2));
		scoreTxt = makeStatText(textX, textY, textWidth, FlxTextAlign.RIGHT, "score");
		missesTxt = makeStatText(textX, textY, textWidth, FlxTextAlign.CENTER, "misses");
		accuracyTxt = makeStatText(textX, textY, textWidth, FlxTextAlign.LEFT, "accuracy");

		timeText = new FlxText(0, down ? FlxG.height - 44 : 19, FlxG.width, "", hudSkin.text("time").size);
		applyTextStyle(timeText, "time", 32, FlxColor.WHITE, FlxTextAlign.CENTER, 2);
		timeText.color = hudSkin.timeBarTextColor;
		timeText.alpha = 0;

		timeBar = new FlxBar(FlxG.width / 2 - timeBarWidth / 2, timeText.y + timeText.height / 4, FlxBarFillDirection.LEFT_TO_RIGHT, timeBarWidth, timeBarHeight, null, "", 0, this.songLength);

		timeBar.numDivisions = timeBarWidth;
		setTimeBarStyle(TimeBarStyle.parse(hudSkin.timeBarStyle));
		timeBar.alpha = 0;

		timeBarBG = new FlxSprite().makeGraphic(timeBarWidth + timeBarBgPad * 2, timeBarHeight + timeBarBgPad * 2, FlxColor.BLACK);
		timeBarBG.alpha = 0;
		syncTimeBarBG();
		add(timeBarBG);
		add(timeBar);
		add(timeText);

		ratingText = new FlxText(0, 0, 0, "", hudSkin.text("rating").size);
		applyTextStyle(ratingText, "rating", 64, FlxColor.WHITE, FlxTextAlign.CENTER, 3);
		ratingText.alpha = 0;
		add(ratingText);
		comboText = new FlxText(0, 0, 0, "", hudSkin.text("combo").size);
		applyTextStyle(comboText, "combo", 64, FlxColor.WHITE, FlxTextAlign.CENTER, 3);
		comboText.alpha = 0;
		add(comboText);
		pressText = new FlxText(0, 0, 0, "", hudSkin.text("press").size);
		applyTextStyle(pressText, "press", 22, 0xFF5CF0DC, FlxTextAlign.CENTER, 1.5);
		pressText.alpha = 0;
		add(pressText);

		var hudSkin = HudSkin.current();
		hudSkin.notify("onHudCreate", null, [timeBar, timeBarBG, timeText, scoreTxt, missesTxt, accuracyTxt, ratingText, comboText, pressText]);
		hudSkin.notify("onTimeBarCreate", null, [timeBar, timeBarBG, timeText]);
		hudSkin.notify("onScoreTextCreate", null, [scoreTxt, missesTxt, accuracyTxt]);

		for (name in ["sick", "good", "bad", "shit"])
		{
			var bmp = scoreBitmap(name);
			if (bmp == null) continue;
			var image = new FlxSprite().loadGraphic(bmp);
			image.alpha = 0;
			ratingImages.set(name, image);
			add(image);
		}

		var hasNumbers = true;
		for (digit in 0...10)
		{
			var bmp = scoreBitmap("num" + digit);
			if (bmp == null)
			{
				hasNumbers = false;
				break;
			}
			var graphic = FlxG.bitmap.add(bmp, true);
			graphic.destroyOnNoUse = false; // el warm-up y los slots cargan/sueltan el mismo grafico: que no se destruya al bajar a 0 usos.
			digitGraphics.push(graphic);
		}
		if (!hasNumbers) digitGraphics = [];

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

		if (ClientPrefs.isBotplay())
		{
			botplayText = new FlxText(0, 0, FlxG.width, TU.translate("game.botplay", null, "BOTPLAY"), hudSkin.text("botplay").size);
			applyTextStyle(botplayText, "botplay", 32, FlxColor.WHITE, FlxTextAlign.CENTER, 2);
			add(botplayText);
		}

		onUpdateScore(0, -1, 0);
		updateTime(0);
		warmUp();
	}

	/**
	 * Dibuja un par de frames las imagenes de rating y los digitos con alpha casi 0. Asi la textura ya esta en la GPU
	 * cuando llega el primer acierto y no hay trabadon justo al tocar.
	 */
	function warmUp():Void
	{
		for (graphic in digitGraphics)
		{
			var warm = new FlxSprite();
			warm.loadGraphic(graphic);
			warm.scale.set(0.02, 0.02);
			warm.alpha = 0.004;
			warmDigits.push(warm);
			add(warm);
		}

		var hasRatings = false;
		for (image in ratingImages)
		{
			image.alpha = 0.004;
			hasRatings = true;
		}

		warmFrames = (warmDigits.length > 0 || hasRatings) ? 3 : 0;
	}

	function finishWarmUp():Void
	{
		for (warm in warmDigits)
		{
			remove(warm, true);
			warm.destroy();
		}
		warmDigits = [];

		for (image in ratingImages)
			image.alpha = 0;
	}

	public function placeBotplay(lineX:Float, lineY:Float, lineWidth:Float):Void
	{
		if (botplayText == null) return;

		var slot = lineWidth / Math.max(4, laneCount);
		setBotplayRect(lineX, lineY, lineY + slot, lineWidth);
	}

	public function followBotplay(line:StrumLine):Void
	{
		botplayLine = line;
		syncBotplay();
	}

	function setBotplayRect(left:Float, top:Float, bottom:Float, width:Float):Void
	{
		if (botplayText.fieldWidth != width) botplayText.fieldWidth = width;
		botplayText.x = left;

		var textHeight = botplayText.textField.textHeight + 4;
		if (!(textHeight > 4)) textHeight = botplayText.size * 1.3;

		botplayText.y = top + ((bottom - top) - textHeight) / 2;
	}

	function syncBotplay():Void
	{
		if (botplayText == null || botplayLine == null) return;

		var left = Math.POSITIVE_INFINITY;
		var right = Math.NEGATIVE_INFINITY;
		var top = Math.POSITIVE_INFINITY;
		var bottom = Math.NEGATIVE_INFINITY;
		for (strum in botplayLine.members)
		{
			if (strum == null || !strum.exists) continue;
			left = Math.min(left, strum.x);
			right = Math.max(right, strum.x + strum.width);
			top = Math.min(top, strum.y);
			bottom = Math.max(bottom, strum.y + strum.height);
		}
		if (left > right) return;

		setBotplayRect(left, top, bottom, right - left);
	}

	function makeStatText(x:Float, y:Float, width:Int, align:FlxTextAlign, key:String):FlxText
	{
		var text = new FlxText(x, y, width, "", hudSkin.text(key).size);
		applyTextStyle(text, key, 20, FlxColor.WHITE, align, 1.25);
		text.scrollFactor.set();
		add(text);
		return text;
	}

	function applyTextStyle(text:FlxText, key:String, fallbackSize:Int, fallbackColor:FlxColor, fallbackAlign:FlxTextAlign, fallbackBorder:Float):Void
	{
		var s = hudSkin.text(key);
		var align:FlxTextAlign = switch (s.align.toLowerCase())
		{
			case "left": FlxTextAlign.LEFT;
			case "right": FlxTextAlign.RIGHT;
			default: fallbackAlign;
		};
		text.setFormat(defaultFont, s.size > 0 ? s.size : fallbackSize, s.color, align, FlxTextBorderStyle.OUTLINE, s.border);
		text.borderSize = s.borderSize >= 0 ? s.borderSize : fallbackBorder;
	}

	function scoreBitmap(name:String):Null<openfl.display.BitmapData>
	{
		return hudSkin.image(scoreDir + "/" + name);
	}

	public function setTimeBarStyle(style:TimeBarStyle):Void
	{
		timeBarStyle = style;
		refreshTimeBarColors();
	}

	public function refreshTimeBarColors():Void
	{
		if (timeBar == null) return;
		// El tipo de barra sale solo del hudSkin.xml (<timeBar mode="legacy|allowColor">). HudSkin lo guarda en minusculas.
		var mode = hudSkin.timeBarMode;
		if ((mode == "allowcolor" || mode == "allow_color" || mode == "healthbar") && healthBar != null)
		{
			var fill:FlxColor = healthBar.playerColor;
			var empty:FlxColor = FlxColor.interpolate(fill, FlxColor.BLACK, 0.75);
			timeBar.createFilledBar(empty, fill, true, FlxColor.BLACK);
			timeBar.value = songTime;
			return;
		}

		switch (timeBarStyle)
		{
			case TimeBarStyle.MONO:
				timeBar.createFilledBar(FlxColor.BLACK, FlxColor.WHITE, true, FlxColor.WHITE);
			case TimeBarStyle.MULTI:
				var fill = laneColors();
				var empty = [for (color in fill) FlxColor.interpolate(color, FlxColor.BLACK, 0.75)];
				timeBar.createGradientBar(empty, fill, 1, 180, true, FlxColor.BLACK);
			case TimeBarStyle.PINK_LIME:
				timeBar.createFilledBar(hudSkin.timeBarEmpty, hudSkin.timeBarFill, true, hudSkin.timeBarBorder);
		}

		timeBar.value = songTime;
	}

	public function setTimeBarColors(empty:FlxColor, fill:FlxColor, border:FlxColor = FlxColor.BLACK):Void
	{
		timeBarStyle = TimeBarStyle.PINK_LIME;
		timeBar.createFilledBar(empty, fill, true, border);
		timeBar.value = songTime;
	}

	function laneColors():Array<FlxColor>
	{
		var skin = HudSkin.current();
		var out:Array<FlxColor> = [];

		for (lane in 0...laneCount)
		{
			var color:Null<Int> = skin.colorFor(lane, false, laneCount);
			if (color == null) color = ClientPrefs.noteColorForLane(lane, false, laneCount);
			out.push(FlxColor.fromInt(0xFF000000 | color));
		}

		if (out.length == 1) out.push(out[0]);
		return out;
	}

	function syncTimeBarBG():Void
	{
		if (timeBarBG == null || timeBar == null) return;
		timeBarBG.setPosition(timeBar.x - timeBarBgPad, timeBar.y - timeBarBgPad);
		timeBarBG.alpha = timeBar.alpha;
		timeBarBG.visible = timeBar.visible;
	}

	public function onSongStart():Void
	{
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeText, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
	}

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

	public static function letterRank(accuracy:Float, misses:Int = 0):String
	{
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
		for (text in [scoreTxt, accuracyTxt, missesTxt])
		{
			FlxTween.cancelTweensOf(text.scale);
			text.scale.set(1.075, 1.075);
			FlxTween.tween(text.scale, {x: 1, y: 1}, 0.2);
		}
	}

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

			image.setPosition(posX - 40 - image.frameWidth / 2, FlxG.height / 2 - image.frameHeight / 2 - 60);
			image.alpha = 1;
			FlxTween.cancelTweensOf(image.scale);
			image.scale.set(RATING_SCALE * RATING_POP, RATING_SCALE * RATING_POP);
			FlxTween.tween(image.scale, {x: RATING_SCALE, y: RATING_SCALE}, 0.5, {ease: FlxEase.expoOut});
			FlxTween.tween(image, {alpha: 0, y: image.y + 100}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
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
			FlxTween.tween(ratingText, {alpha: 0, y: ratingText.y + 100}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
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
				var digit = Std.parseInt(digits.charAt(i));
				var graphic = digit == null ? null : digitGraphics[digit];
				if (graphic != null && slot.graphic != graphic) slot.loadGraphic(graphic);
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
				FlxTween.tween(slot, {alpha: 0, y: slot.y + 100}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
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
			FlxTween.tween(comboText, {alpha: 0, y: comboText.y + 100}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
		}

		if (press != null) showPress(press, posX, delay);
	}

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
		FlxTween.tween(pressText, {alpha: 0, y: pressText.y + 50}, 0.5, {startDelay: delay, ease: FlxEase.expoOut});
	}

	public static function formatPercent(value:Float):String
		return Std.string(Math.round(value * 10) / 10) + "%";

	public static function formatMs(ms:Float):String
	{
		var rounded = Math.round(ms * 10) / 10;
		return (rounded > 0 ? "+" : "") + Std.string(rounded) + "ms";
	}

	public static function formatNumber(value:Int):String
	{
		var abs = Math.abs(value);
		if (abs >= 1000000000) return Std.string(Math.round(value / 100000000) / 10) + "B";
		if (abs >= 10000000) return Std.string(Math.round(value / 100000) / 10) + "M";
		return FlxStringUtil.formatMoney(value, false);
	}

	public function updateTime(time:Float):Void
	{
		songTime = Math.min(time, songLength);
		timeBar.value = songTime;
		var second = Std.int(songTime / 1000);
		if (second == shownSecond) return;
		shownSecond = second;
		timeText.text = FlxStringUtil.formatTime(Math.floor(Math.max(0, songLength - songTime) / 1000), false);
	}

	public function addHealth(amount:Float):Void
	{
		setHealth(health + amount);
	}

	public function setHealth(value:Float):Void
	{
		health = Math.max(0, Math.min(MAX_HEALTH, value));
	}

	public function beatHit():Void
	{
		iconPlayer.bop();
		iconOpponent.bop();
	}

	override public function update(elapsed:Float):Void
	{
		shownHealth += (health - shownHealth) * Math.min(1, elapsed * 8);
		super.update(elapsed);
		syncTimeBarBG();

		if (warmFrames > 0 && --warmFrames == 0)
			finishWarmUp();

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

	function placeIcons():Void
	{
		var edge = healthBar.edgeX(shownHealth);
		var centerY = healthBar.centerY();
		var reach = HealthIcon.FIT * ICON_OVERLAP;
		iconPlayer.centerAt(edge + reach, centerY);
		iconOpponent.centerAt(edge - reach, centerY);
	}
}
