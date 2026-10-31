package funky.menus;

import flixel.util.FlxAxes;
import flixel.FlxG;
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
import funky.core.NavPad;
import funky.core.Log;
import funky.core.Scores;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import funky.game.HealthIcon;
import funky.game.PlayState;
import haxe.io.Path;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

/**
 * Lista de niveles: fondo `menuDesat` que cambia de color por nivel, nombres en fuente bold en una lista recta que se desliza
 * alrededor del seleccionado, barra arriba (nivel, dificultad y mejor puntaje guardado) y un banner fijo a la derecha.
 * Lista las carpetas de niveles ya convertidas.
 */
class FreeplayState extends FlxState
{
	private static final ACTIVE:Int = 0xFFFFFFFF;
	private static final IDLE:Int = 0xFFB8B8C6;
	private static final ARCHIVE_COLOR:Int = 0xFFFFC14D;
	/** Colores del fondo, por nivel (el primero es el morado de Codename). */
	private static final PALETTE:Array<Int> = [0xFF9271FD, 0xFFFD719B, 0xFF71FDB3, 0xFFFDC571, 0xFF71C5FD, 0xFFB871FD];

	/** Alto de la barra de arriba (nivel, dificultad y mejor puntaje). */
	private static inline var BAR_H:Float = 96;
	/** Separacion vertical entre filas y x de la lista (recta: ya no se inclina). */
	private static inline var ROW_GAP:Float = 92;
	private static inline var LIST_X:Float = 60;
	/** Cuanto se corre a la derecha la fila seleccionada. */
	private static inline var SELECTED_SHIFT:Float = 34;
	/** Margen del banner (imagen fija a la derecha: `assets/images/menus/freeplay/banner.png`). */
	private static inline var BANNER_MARGIN:Float = 36;

	/** Sparrow de la Jazmin que avisa que no hay niveles (`assets/images/menus/freeplay/void.png` + `.xml`, anim `idle`). */
	private static inline var VOID_IMAGE:String = "menus/freeplay/void";
	private static inline var VOID_ANIM:String = "idle";

	private var entries:Array<{label:String, path:String}> = [];
	private var archiveFlags:Array<Bool> = [];
	/** Icono del oponente de cada nivel (null si no trae); se crean al acercarse a la fila para no cargar todos de golpe. */
	private var icons:Array<Null<HealthIcon>> = [];
	private var iconTried:Array<Bool> = [];
	private var selected:Int = 0;
	private var rows:Array<BoldText> = [];
	private var bg:FlxSprite;
	private var scoreBG:FlxSprite;
	private var banner:Null<FlxSprite>;
	private var bannerFrame:Null<FlxSprite>;
	private var bannerBaseY:Float = 0;
	/** Jazmin "no hay niveles": solo existe mientras la lista esta vacia (el sparrow pesa mucho, no se deja en memoria). */
	private var voidSprite:Null<FlxSprite>;
	private var bannerTime:Float = 0;
	private var scoreText:FlxText;
	private var countText:FlxText;
	private var statusText:FlxText;
	private var leaving:Bool = false;
	private var backButton:FlxText;
	private var convertButton:FlxText;
	private var refreshButton:FlxText;
	private var difficultyText:FlxText;
	private var navPad:Null<NavPad>;

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

		// Banner fijo a la derecha (en el Freeplay viejo era el oponente del nivel; aca es una imagen fija).
		createBanner();

		// Barra de arriba: nivel y dificultad a la izquierda, mejor puntaje a la derecha.
		scoreBG = new FlxSprite(0, 0).makeGraphic(1, 1, 0xFF000000);
		scoreBG.scale.set(FlxG.width, BAR_H);
		scoreBG.updateHitbox();
		scoreBG.alpha = 0.6;
		scoreBG.scrollFactor.set();
		add(scoreBG);

		// En movil el boton VOLVER ocupa la esquina: los textos arrancan despues de el.
		var textX:Float = TouchNav.MOBILE ? 240 : 30;
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

		if (TouchNav.MOBILE)
		{
			// Sin teclado: los atajos pasan a botones, las filas se tocan.
			backButton = TouchNav.button("< VOLVER", 30, 14, 180);
			convertButton = TouchNav.button("CONVERTIDOR", 30, FlxG.height - 60, 220);
			refreshButton = TouchNav.button("REFRESCAR", FlxG.width / 2 - 110, FlxG.height - 60);
			for (button in [backButton, convertButton, refreshButton])
			{
				button.setBorderStyle(OUTLINE, 0xFF000000, 2);
				add(button);
			}
		}
		else
		{
			var strip = new FlxSprite(0, FlxG.height - 34).makeGraphic(FlxG.width, 34, 0xFF000000);
			strip.alpha = 0.6;
			strip.scrollFactor.set();
			add(strip);

			var hint = new FlxText(0, FlxG.height - 28, FlxG.width,
				KeyBinds.label(KeyBinds.ACCEPT) + " jugar  |  < > dificultad  |  R refrescar  |  "
				+ KeyBinds.label(KeyBinds.BACK) + " volver  |  C convertidor", 16);
			hint.alignment = FlxTextAlign.CENTER;
			hint.color = ACTIVE;
			add(hint);
		}

		navPad = NavPad.make(() -> if (!leaving) move(-1), () -> if (!leaving) move(1));
		if (navPad != null) add(navPad);

		FlxG.mouse.visible = false;
		FlxG.mouse.enabled = false;

		showDifficulty();
		refresh();

		TransitionHandler.playIn(this);
	}

	/** Lista vacia: la Jazmin `void` con un texto de ayuda abajo; sin el sparrow, solo el texto de siempre. */
	private function showEmpty():Void
	{
		var hint = TouchNav.MOBILE ? "Toca CONVERTIDOR para importar un .fnmm" : "Convertí un .fnmm con la tecla C";
		var hasVoid = false;
		if (OpenFlAssets.exists(Paths.image(VOID_IMAGE)) && OpenFlAssets.exists(Paths.imageXml(VOID_IMAGE)))
		{
			statusText.size = 20;
			statusText.y = FlxG.height - (TouchNav.MOBILE ? 160 : 110);
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
		statusText.text = "No hay niveles en " + Paths.levelsRoot() + "\n" + hint;
	}

	/** Crea la Jazmin animada (`idle`, en bucle) centrada entre la barra de arriba y el texto de ayuda. */
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
				// Sparrow sin frames "idle0000": mientras no lo termines, reproduce todos los frames en orden.
				Log.warn('[FreeplayState] ' + VOID_IMAGE + ' no trae frames "' + VOID_ANIM + '", uso todos');
				sprite.animation.add(VOID_ANIM, [for (i in 0...frames.frames.length) i], 24, true);
			}
			sprite.animation.play(VOID_ANIM);
			sprite.antialiasing = true;
			sprite.scrollFactor.set();

			// Escala uniforme (nunca se agranda): cabe en el area libre sin deformarse.
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

	/** Quita la Jazmin y libera su textura (Paths marca los atlas como persistentes, aca se suelta para que no se quede en RAM). */
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

	/** Color de fondo de un nivel: fijo por nombre, asi no cambia entre sesiones. */
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
			countText.text = "0 NIVELES";
			scoreText.text = "";
			return;
		}

		setBannerVisible(true);
		statusText.text = "";
		selected = Std.int(Math.min(Std.int(Math.max(selected, 0)), entries.length - 1));

		for (index in 0...entries.length)
		{
			var row = new BoldText(0, 0, entries[index].label, 0.9);
			// Nombres largos: se achican para no pisar el banner.
			if (row.width > maxRowWidth())
			{
				var fit = Math.max(0.35, 0.9 * maxRowWidth() / row.width);
				row.destroy();
				row = new BoldText(0, 0, entries[index].label, fit);
			}
			row.scrollFactor.set();
			// Tracked separately: refreshSelection recolors rows constantly.
			archiveFlags.push(LevelLoader.isArchive(entries[index].path));
			icons.push(null);
			iconTried.push(false);
			add(row);
			rows.push(row);
		}
		refreshSelection();
		// La primera vez las filas aparecen ya en su lugar, no deslizandose desde (0,0).
		for (index in 0...rows.length) placeRow(index, 1);
		bg.color = colorFor(entries[selected].label);
	}

	/**
	 * Posicion de una fila segun su distancia al seleccionado: lista recta (misma x para todas, la seleccionada un poco
	 * corrida), centrada en el area bajo la barra. Las filas que quedan fuera del area se ocultan.
	 */
	private function placeRow(index:Int, lerp:Float):Void
	{
		var row = rows[index];
		var targetY = index - selected;
		var areaTop = BAR_H;
		var areaBottom:Float = TouchNav.MOBILE ? FlxG.height - 70 : FlxG.height - 40;
		var centerY = (areaTop + areaBottom) / 2;
		var wantY = centerY + targetY * ROW_GAP - row.height / 2;
		var wantX = LIST_X + (targetY == 0 ? SELECTED_SHIFT : 0);
		row.x = FlxMath.lerp(row.x, wantX, lerp);
		row.y = FlxMath.lerp(row.y, wantY, lerp);

		// Fuera del area (bajo la barra o contra los botones) no se dibuja.
		var inside = wantY >= areaTop - 10 && wantY + row.height <= areaBottom + 10;
		row.visible = inside;

		// Icono del oponente a la derecha del nombre, con el mismo brillo que la fila.
		var icon = iconFor(index);
		if (icon != null)
		{
			icon.visible = inside;
			icon.centerAt(row.x + row.width + 16 + HealthIcon.FIT / 2, row.y + row.height / 2);
			icon.alpha = row.alpha;
		}
	}

	/** Icono del oponente del nivel `index`; se carga la primera vez que la fila queda cerca del seleccionado. */
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

	/** Banner fijo: marco oscuro + imagen, a la derecha, bajo la barra de arriba. Si la imagen falta, no se muestra. */
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

	/** Ancho maximo de una fila: hasta donde empieza el banner (menos el icono del oponente). */
	private function maxRowWidth():Float
	{
		var bannerX = banner != null ? banner.x : FlxG.width;
		return bannerX - LIST_X - SELECTED_SHIFT - HealthIcon.FIT - 40;
	}

	private function collect():Array<{label:String, path:String}>
	{
		var found:Array<{label:String, path:String}> = [];
		// levels/ solo tiene carpetas de niveles ya descomprimidas. Los .fnmm originales
		// quedan en levels/.tmp/ (los guarda el convertidor) y no se listan.
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

	/** Fila que un dedo acaba de tocar, o -1. */
	private function tappedRow():Int
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (!touch.justPressed) continue;
			if (navPad != null && navPad.covers(touch.screenX, touch.screenY)) continue;
			for (index in 0...rows.length)
			{
				var row = rows[index];
				if (!row.visible) continue;
				if (touch.screenX >= row.x - 14 && touch.screenX <= row.x + row.width + 14 && touch.screenY >= row.y - 8 && touch.screenY <= row.y + row.height + 8)
					return index;
			}
		}
		#end
		return -1;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		for (index in 0...rows.length) placeRow(index, Math.min(1, elapsed * 18));

		// El banner flota apenas (4 px) para que no quede una imagen muerta.
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

		// Literal shortcuts: see the hint text in create().
		if (FlxG.keys.justPressed.C) leave(new ConverterMenuState());
		if (FlxG.keys.justPressed.R)
		{
			refresh();
			return;
		}

		// Touch: buttons first, then the level rows.
		if (TouchNav.hit(difficultyText)) { Difficulty.next(); showDifficulty(); return; }
		if (TouchNav.hit(backButton)) { leave(new MainMenuState()); return; }
		if (TouchNav.hit(convertButton)) { leave(new ConverterMenuState()); return; }
		if (TouchNav.hit(refreshButton))
		{
			refresh();
			return;
		}
		// Tocar otra fila la selecciona; tocar la seleccionada la juega.
		var tapped = tappedRow();
		if (tapped >= 0)
		{
			if (tapped == selected) play(entries[selected].path);
			else move(tapped - selected);
			return;
		}

		// Izquierda/derecha cambia la dificultad (velocidad de scroll).
		if (FlxG.keys.justPressed.LEFT) { Difficulty.next(-1); showDifficulty(); }
		if (FlxG.keys.justPressed.RIGHT) { Difficulty.next(1); showDifficulty(); }

		if (rows.length == 0) return;

		if (KeyBinds.justPressed(KeyBinds.UP)) move(-1);
		if (KeyBinds.justPressed(KeyBinds.DOWN)) move(1);
		if (FlxG.mouse.wheel != 0) move(-Std.int(FlxG.mouse.wheel));
	}

	private function showDifficulty():Void
	{
		difficultyText.text = "< " + Difficulty.name() + " >  (velocidad " + Difficulty.speed() + ")"
			+ (TouchNav.MOBILE ? "  toca para cambiar" : "");
		showScore();
	}

	/** Mejor puntaje guardado del nivel seleccionado en la dificultad actual. */
	private function showScore():Void
	{
		if (entries.length == 0 || selected >= entries.length)
		{
			scoreText.text = "";
			return;
		}

		var best = Scores.get(Scores.levelId(entries[selected].path), Difficulty.current);
		scoreText.text = best == null
			? "SIN PUNTAJE"
			: "MEJOR " + best.score + "   " + Std.string(Math.round(best.accuracy * 10) / 10) + "%   " + best.misses + " FALLOS";
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
		PlayState.startFromMs = 0;
		PlayState.returnToEditor = null;
		Log.info('[FreeplayState] launching ' + path);
		TransitionHandler.switchState(new LoadingLevelState());
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
