package funky.menus;

import flixel.util.FlxAxes;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funky.api.DiscordClient;
import funky.core.CoolUtil;
import funky.backend.chart.LevelLoader;
import funky.core.Difficulty;
import funky.core.KeyBinds;
import funky.core.MenuButton;
import funky.core.NavPad;
import funky.core.Log;
import funky.core.Scores;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import funky.game.HealthIcon;
import funky.game.PlayState;
import funky.menus.options.BackButton;
import funkin.backend.utils.TranslationUtil as TU;
import haxe.io.Path;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

class FreeplayState extends FlxState
{
	private static final ACTIVE:Int = 0xFFFFFFFF;
	private static final IDLE:Int = 0xFFB8B8C6;
	private static final ARCHIVE_COLOR:Int = 0xFFFFC14D;

	private static final PALETTE:Array<Int> = [0xFF9271FD, 0xFFFD719B, 0xFF71FDB3, 0xFFFDC571, 0xFF71C5FD, 0xFFB871FD];

	private static inline var BAR_H:Float = 104;

	private static inline var STRIP_H:Float = 34;

	private static inline var ROW_GAP:Float = 92;
	private static inline var LIST_X:Float = 60;

	private static inline var SELECTED_SHIFT:Float = 34;

	private static inline var BANNER_MARGIN:Float = 36;

	private static inline var VOID_IMAGE:String = "menus/freeplay/void";
	private static inline var VOID_ANIM:String = "idle";

	private var entries:Array<{label:String, path:String}> = [];
	private var archiveFlags:Array<Bool> = [];

	private var icons:Array<Null<HealthIcon>> = [];
	private var iconTried:Array<Bool> = [];
	private var selected:Int = 0;
	private var rows:Array<BoldText> = [];
	private var bg:FlxSprite;
	private var scoreBG:FlxSprite;
	private var banner:Null<FlxSprite>;
	private var bannerFrame:Null<FlxSprite>;
	private var bannerBaseY:Float = 0;

	private var voidSprite:Null<FlxSprite>;
	private var bannerTime:Float = 0;
	private var scoreText:FlxText;
	private var countText:FlxText;
	private var statusText:FlxText;
	private var leaving:Bool = false;
	private var backButton:FlxObject;
	private var convertButton:MenuButton;
	private var refreshButton:MenuButton;
	private var difficultyText:FlxText;
	private var navPad:Null<NavPad>;

	private var listBottom:Float = 600;

	override public function create():Void
	{
		super.create();

		CoolUtil.playMenuSong();
		DiscordClient.freeplayPresence();

		bg = new FlxSprite().loadGraphic(Paths.image("menus/menuDesat"));
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.antialiasing = true;
		bg.scrollFactor.set();
		bg.color = PALETTE[0];
		add(bg);

		statusText = new FlxText(0, FlxG.height * 0.45, FlxG.width, "", 24);
		statusText.alignment = FlxTextAlign.CENTER;
		statusText.color = ACTIVE;
		statusText.setBorderStyle(OUTLINE, 0xFF000000, 2);
		add(statusText);

		createBanner();

		scoreBG = new FlxSprite(0, 0).makeGraphic(1, 1, 0xFF000000);
		scoreBG.scale.set(FlxG.width, BAR_H);
		scoreBG.updateHitbox();
		scoreBG.alpha = 0.6;
		scoreBG.scrollFactor.set();
		add(scoreBG);

		var textX:Float = BackButton.WIDTH;
		countText = new FlxText(textX, 10, 420, "", 30);
		difficultyText = new FlxText(textX, 52, 420, "", 22);
		difficultyText.color = ARCHIVE_COLOR;
		scoreText = new FlxText(FlxG.width * 0.5, 14, FlxG.width * 0.5 - 30, "", 34);
		scoreText.alignment = FlxTextAlign.RIGHT;
		var vcr = Paths.fontPath("vcr.ttf");
		if (vcr != null)
		{
			countText.font = vcr;
			difficultyText.font = vcr;
			scoreText.font = vcr;
		}
		for (text in [countText, difficultyText, scoreText])
		{
			text.scrollFactor.set();
			text.setBorderStyle(OUTLINE, 0xFF000000, 2);
			add(text);
		}

		backButton = BackButton.place();
		add(backButton);

		convertButton = new MenuButton(TU.translate("freeplay.converter", null, "CONVERTIDOR"), 0, 0, 230);
		refreshButton = new MenuButton(TU.translate("freeplay.refresh", null, "REFRESCAR"), 0, 0, 200);

		var bottomInset:Float = TouchNav.MOBILE ? 0 : STRIP_H;
		MenuButton.bottomRow([convertButton, refreshButton], bottomInset);
		listBottom = convertButton.y - 8;
		add(convertButton);
		add(refreshButton);

		if (!TouchNav.MOBILE)
		{
			var strip = new FlxSprite(0, FlxG.height - STRIP_H).makeGraphic(FlxG.width, Std.int(STRIP_H), 0xFF000000);
			strip.alpha = 0.6;
			strip.scrollFactor.set();
			add(strip);

			var hint = new FlxText(0, FlxG.height - 28, FlxG.width,
				TU.translate("freeplay.hint", [KeyBinds.label(KeyBinds.ACCEPT), KeyBinds.label(KeyBinds.BACK)],
					"{0} jugar  |  < > dificultad  |  R refrescar  |  {1} volver  |  C convertidor  |  7 avanzado"), 16);
			hint.alignment = FlxTextAlign.CENTER;
			hint.color = ACTIVE;
			add(hint);
		}

		navPad = NavPad.make(() -> if (!leaving) move(-1), () -> if (!leaving) move(1));
		if (navPad != null) add(navPad);

		showDifficulty();
		refresh();

		TransitionHandler.playIn(this);
	}

	private function showEmpty():Void
	{
		var hint = TouchNav.MOBILE
			? TU.translate("freeplay.empty.hintMobile", null, "Toca CONVERTIDOR para importar un .fnmm")
			: TU.translate("freeplay.empty.hintDesktop", null, "Converti un .fnmm con la tecla C");
		var hasVoid = false;
		if (OpenFlAssets.exists(Paths.image(VOID_IMAGE)) && OpenFlAssets.exists(Paths.imageXml(VOID_IMAGE)))
		{
			statusText.size = 20;
			statusText.y = listBottom - 62;
			hasVoid = createVoid();
		}

		setBannerVisible(!hasVoid);
		if (hasVoid)
		{
			statusText.text = hint + "\n" + Paths.levelsRoot();
			return;
		}
		statusText.size = 24;
		statusText.y = FlxG.height * 0.45;
		statusText.text = TU.translate("freeplay.empty.noLevels", [Paths.levelsRoot(), hint],
			"No hay niveles en {0}\n{1}");
	}

	private function createVoid():Bool
	{
		try
		{
			var frames = Paths.getSparrowAtlas(VOID_IMAGE);
			if (frames == null) return false;

			var sprite = new FlxSprite();
			sprite.frames = frames;
			sprite.animation.addByPrefix(VOID_ANIM, VOID_ANIM, 24, true);
			if (sprite.animation.getByName(VOID_ANIM) == null)
			{

				Log.warn('[FreeplayState] ' + VOID_IMAGE + ' no trae frames "' + VOID_ANIM + '", uso todos');
				sprite.animation.add(VOID_ANIM, [for (i in 0...frames.frames.length) i], 24, true);
			}
			sprite.animation.play(VOID_ANIM);
			sprite.antialiasing = true;
			sprite.scrollFactor.set();

			var areaTop = BAR_H + 10;
			var areaH = statusText.y - 10 - areaTop;
			var fit = Math.min(1, Math.min(FlxG.width * 0.8 / Math.max(1, sprite.frameWidth), areaH / Math.max(1, sprite.frameHeight)));
			sprite.scale.set(fit, fit);
			sprite.updateHitbox();
			sprite.x = (FlxG.width - sprite.width) / 2;
			sprite.y = areaTop + (areaH - sprite.height) / 2;

			add(sprite);
			voidSprite = sprite;
			return true;
		}
		catch (e:Dynamic)
		{
			Log.warn('[FreeplayState] no se pudo cargar ' + VOID_IMAGE + ': ' + Std.string(e));
			clearVoid();
			return false;
		}
	}

	private function clearVoid():Void
	{
		if (voidSprite == null) return;
		if (voidSprite.graphic != null) voidSprite.graphic.persist = false;
		remove(voidSprite);
		voidSprite.destroy();
		voidSprite = null;
	}

	private function setBannerVisible(value:Bool):Void
	{
		if (banner != null) banner.visible = value;
		if (bannerFrame != null) bannerFrame.visible = value;
	}

	private function colorFor(label:String):Int
	{
		var hash = 0;
		for (i in 0...label.length) hash = (hash * 31 + StringTools.fastCodeAt(label, i)) & 0x7FFFFFFF;
		return PALETTE[hash % PALETTE.length];
	}

	private function refresh():Void
	{
		for (row in rows)
		{
			remove(row);
			row.destroy();
		}
		rows = [];
		for (icon in icons)
			if (icon != null)
			{
				remove(icon);
				icon.destroy();
			}

		clearVoid();

		entries = collect();
		archiveFlags = [];
		icons = [];
		iconTried = [];

		if (entries.length == 0)
		{
			showEmpty();
			countText.text = TU.translate("freeplay.noLevels", null, "0 NIVELES");
			scoreText.text = "";
			return;
		}

		setBannerVisible(true);
		statusText.text = "";
		selected = Std.int(Math.min(Std.int(Math.max(selected, 0)), entries.length - 1));

		for (index in 0...entries.length)
		{
			var row = new BoldText(0, 0, entries[index].label, 0.9);

			if (row.width > maxRowWidth())
			{
				var fit = Math.max(0.35, 0.9 * maxRowWidth() / row.width);
				row.destroy();
				row = new BoldText(0, 0, entries[index].label, fit);
			}
			row.scrollFactor.set();

			archiveFlags.push(LevelLoader.isArchive(entries[index].path));
			icons.push(null);
			iconTried.push(false);
			add(row);
			rows.push(row);
		}
		refreshSelection();

		for (index in 0...rows.length) placeRow(index, 1);
		bg.color = colorFor(entries[selected].label);
	}

	private function placeRow(index:Int, lerp:Float):Void
	{
		var row = rows[index];
		var targetY = index - selected;
		var areaTop = BAR_H;
		var areaBottom:Float = listBottom;
		var centerY = (areaTop + areaBottom) / 2;
		var wantY = centerY + targetY * ROW_GAP - row.height / 2;
		var wantX = LIST_X + (targetY == 0 ? SELECTED_SHIFT : 0);
		row.x = FlxMath.lerp(row.x, wantX, lerp);
		row.y = FlxMath.lerp(row.y, wantY, lerp);

		var inside = wantY >= areaTop - 10 && wantY + row.height <= areaBottom + 10;
		row.visible = inside;

		var icon = iconFor(index);
		if (icon != null)
		{
			icon.visible = inside;
			icon.centerAt(row.x + row.width + 16 + HealthIcon.FIT / 2, row.y + row.height / 2);
			icon.alpha = row.alpha;
		}
	}

	private function iconFor(index:Int):Null<HealthIcon>
	{
		if (icons[index] != null) return icons[index];
		if (iconTried[index] || Math.abs(index - selected) > 3) return null;
		iconTried[index] = true;

		#if sys
		var path = entries[index].path;
		if (LevelLoader.isArchive(path)) return null;
		var name = LevelLoader.opponentIcon(path);
		if (name == null) return null;

		var icon = new HealthIcon(path, name, false);
		if (!icon.loaded)
		{
			icon.destroy();
			return null;
		}
		add(icon);
		icons[index] = icon;
		return icon;
		#else
		return null;
		#end
	}

	private function createBanner():Void
	{
		try
		{
			var sprite = new FlxSprite().loadGraphic(Paths.image("menus/freeplay/banner"));
			var height = Std.int(FlxG.height - BAR_H - BANNER_MARGIN - 20);
			sprite.setGraphicSize(0, height);
			sprite.updateHitbox();
			sprite.antialiasing = true;
			sprite.scrollFactor.set();
			sprite.x = FlxG.width - sprite.width - BANNER_MARGIN;
			sprite.y = BAR_H + 14;
			bannerBaseY = sprite.y;

			var frame = new FlxSprite(sprite.x - 8, sprite.y - 8).makeGraphic(1, 1, 0xFF000000);
			frame.scale.set(sprite.width + 16, sprite.height + 16);
			frame.updateHitbox();
			frame.alpha = 0.45;
			frame.scrollFactor.set();
			add(frame);
			add(sprite);
			banner = sprite;
			bannerFrame = frame;
		}
		catch (e:Dynamic)
		{
			Log.warn('[FreeplayState] no se pudo cargar el banner: ' + Std.string(e));
			banner = null;
		}
	}

	private function maxRowWidth():Float
	{
		var bannerX = banner != null ? banner.x : FlxG.width;
		return bannerX - LIST_X - SELECTED_SHIFT - HealthIcon.FIT - 40;
	}

	private function collect():Array<{label:String, path:String}>
	{
		var found:Array<{label:String, path:String}> = [];

		#if sys
		for (id in Paths.listLevels())
		{
			var path = Paths.levelsRoot() + id;
			found.push({label: id, path: path});
		}
		#end
		return found;
	}

	private function refreshSelection():Void
	{
		for (index in 0...rows.length)
		{
			var active = index == selected;
			rows[index].alpha = active ? 1 : 0.6;
			rows[index].color = active ? ACTIVE : (archiveFlags[index] ? ARCHIVE_COLOR : ACTIVE);
		}
		if (entries.length > 0)
		{
			countText.text = entries[selected].label + "  " + (selected + 1) + "/" + entries.length;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 0.35, bg.color, colorFor(entries[selected].label));
		}
		showDifficulty();
	}

	private function move(step:Int):Void
	{
		if (rows.length == 0) return;
		selected = (selected + step + rows.length) % rows.length;
		CoolUtil.playMenuSound("scroll", 0.4);
		refreshSelection();
	}

	private function tappedRow():Int
	{
		var tap = TouchNav.pressPoint();
		if (tap == null) return -1;

		var found = -1;
		if (navPad == null || !navPad.covers(tap.x, tap.y))
		{
			for (index in 0...rows.length)
			{
				var row = rows[index];
				if (!row.visible) continue;
				if (tap.x >= row.x - 14 && tap.x <= row.x + row.width + 14 && tap.y >= row.y - 8 && tap.y <= row.y + row.height + 8)
				{
					found = index;
					break;
				}
			}
		}
		tap.put();
		return found;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		for (index in 0...rows.length) placeRow(index, Math.min(1, elapsed * 18));

		if (banner != null)
		{
			bannerTime += elapsed;
			banner.y = bannerBaseY + Math.sin(bannerTime * 1.2) * 4;
		}

		if (leaving) return;

		if (KeyBinds.justPressed(KeyBinds.BACK))
		{
			CoolUtil.playMenuSound("cancel", 0.7);
			leave(new MainMenuState());
			return;
		}
		if (KeyBinds.justPressed(KeyBinds.ACCEPT) && rows.length > 0) play(entries[selected].path);

		if (FlxG.keys.justPressed.C) leave(new ConverterMenuState());

		if (!advanced.AdvancedModeState.antiGay && FlxG.keys.justPressed.SEVEN && entries.length > 0)
		{
			leave(new advanced.AdvancedModeState(entries[selected].label));
			return;
		}
		if (FlxG.keys.justPressed.R)
		{
			refresh();
			return;
		}

		if (TouchNav.hit(difficultyText)) { Difficulty.next(); showDifficulty(); return; }
		if (BackButton.clicked(backButton)) { CoolUtil.playMenuSound("cancel", 0.7); leave(new MainMenuState()); return; }
		if (convertButton.clicked()) { leave(new ConverterMenuState()); return; }
		if (refreshButton.clicked())
		{
			refresh();
			return;
		}

		var tapped = tappedRow();
		if (tapped >= 0)
		{
			if (tapped == selected) play(entries[selected].path);
			else move(tapped - selected);
			return;
		}

		if (FlxG.keys.justPressed.LEFT) { Difficulty.next(-1); showDifficulty(); }
		if (FlxG.keys.justPressed.RIGHT) { Difficulty.next(1); showDifficulty(); }

		if (rows.length == 0) return;

		if (KeyBinds.justPressed(KeyBinds.UP)) move(-1);
		if (KeyBinds.justPressed(KeyBinds.DOWN)) move(1);
		if (FlxG.mouse.wheel != 0) move(-Std.int(FlxG.mouse.wheel));
	}

	private function showDifficulty():Void
	{
		difficultyText.text = TU.translate("freeplay.difficulty", [Difficulty.name(), Difficulty.speed()],
			"< {0} >  (velocidad {1})")
			+ (TouchNav.MOBILE ? TU.translate("freeplay.difficulty.touch", null, "  toca para cambiar") : "");
		showScore();
	}

	private function showScore():Void
	{
		if (entries.length == 0 || selected >= entries.length)
		{
			scoreText.text = "";
			return;
		}

		var best = Scores.get(Scores.levelId(entries[selected].path), Difficulty.current);
		scoreText.text = best == null
			? TU.translate("freeplay.noScore", null, "SIN PUNTAJE")
			: TU.translate("freeplay.best", [best.score, Std.string(Math.round(best.accuracy * 10) / 10), best.misses],
				"MEJOR {0}   {1}%   {2} FALLOS");
	}

	private function leave(next:FlxState):Void
	{
		leaving = true;
		TransitionHandler.switchState(next);
	}

	private function play(path:String):Void
	{
		leaving = true;
		PlayState.archivePath = path;
		PlayState.resetLaunch();
		PlayState.returnToEditor = null;
		Log.info('[FreeplayState] launching ' + path);
		FlxG.switchState(new LoadingLevelState());
	}

	override public function destroy():Void
	{
		if (voidSprite != null && voidSprite.graphic != null) voidSprite.graphic.persist = false;
		super.destroy();
		rows = [];
		entries = [];
		archiveFlags = [];
		icons = [];
		iconTried = [];
		bg = null;
		scoreBG = null;
		banner = null;
		bannerFrame = null;
		voidSprite = null;
		scoreText = null;
		countText = null;
		statusText = null;
		navPad = null;
		backButton = null;
		convertButton = null;
		refreshButton = null;
		difficultyText = null;
	}
}
