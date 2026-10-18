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
import funky.core.CoolUtil;
import funky.backend.chart.LevelLoader;
import funky.core.Difficulty;
import funky.core.KeyBinds;
import funky.core.NavPad;
import funky.core.Log;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import funky.game.HealthIcon;
import funky.game.PlayState;
import haxe.io.Path;

using StringTools;

/**
 * Lista de niveles con la vista de Codename Engine: fondo `menuDesat` que cambia de color por nivel,
 * nombres en fuente bold que se deslizan alrededor del seleccionado y un panel arriba a la derecha.
 * Lista las carpetas de niveles ya convertidas.
 */
class FreeplayState extends FlxState
{
	private static final ACTIVE:Int = 0xFFFFFFFF;
	private static final IDLE:Int = 0xFFB8B8C6;
	private static final ARCHIVE_COLOR:Int = 0xFFFFC14D;
	/** Colores del fondo, por nivel (el primero es el morado de Codename). */
	private static final PALETTE:Array<Int> = [0xFF9271FD, 0xFFFD719B, 0xFF71FDB3, 0xFFFDC571, 0xFF71C5FD, 0xFFB871FD];

	private var entries:Array<{label:String, path:String}> = [];
	private var archiveFlags:Array<Bool> = [];
	/** Icono del oponente de cada nivel (null si no trae); se crean al acercarse a la fila para no cargar todos de golpe. */
	private var icons:Array<Null<HealthIcon>> = [];
	private var iconTried:Array<Bool> = [];
	private var selected:Int = 0;
	private var rows:Array<BoldText> = [];
	private var bg:FlxSprite;
	private var scoreBG:FlxSprite;
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

		// Panel de arriba a la derecha (como el de puntaje de Codename).
		var panelX = FlxG.width * 0.62;
		scoreBG = new FlxSprite(panelX - 6, 0).makeGraphic(1, 1, 0xFF000000);
		scoreBG.alpha = 0.6;
		scoreBG.scrollFactor.set();
		add(scoreBG);

		countText = new FlxText(panelX, 5, FlxG.width - panelX - 6, "", 32);
		countText.alignment = FlxTextAlign.RIGHT;
		difficultyText = new FlxText(panelX, 44, FlxG.width - panelX - 6, "", 20);
		difficultyText.alignment = FlxTextAlign.RIGHT;
		difficultyText.color = ARCHIVE_COLOR;
		var vcr = Paths.fontPath("vcr.ttf");
		if (vcr != null)
		{
			countText.font = vcr;
			difficultyText.font = vcr;
		}
		add(difficultyText);
		add(countText);

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

		entries = collect();
		archiveFlags = [];
		icons = [];
		iconTried = [];

		if (entries.length == 0)
		{
			statusText.text = "No hay niveles en " + Paths.levelsRoot() + "\nConverti un .fnmm con la tecla C";
			countText.text = "0 NIVELES";
			layoutPanel();
			return;
		}

		statusText.text = "";
		selected = Std.int(Math.min(Std.int(Math.max(selected, 0)), entries.length - 1));

		for (index in 0...entries.length)
		{
			var row = new BoldText(0, 0, entries[index].label, 0.9);
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

	/** Posicion de una fila segun su distancia al seleccionado (efecto "isMenuItem" de Codename). */
	private function placeRow(index:Int, lerp:Float):Void
	{
		var row = rows[index];
		var targetY = index - selected;
		var wantY = FlxG.height * 0.45 + targetY * 105 - row.height / 2;
		var wantX = 90 + targetY * 20;
		row.x = FlxMath.lerp(row.x, wantX, lerp);
		row.y = FlxMath.lerp(row.y, wantY, lerp);

		// Icono del oponente a la derecha del nombre, con el mismo brillo que la fila.
		var icon = iconFor(index);
		if (icon != null)
		{
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

	private function layoutPanel():Void
	{
		var bottom = difficultyText.y + difficultyText.height + 6;
		scoreBG.scale.set(FlxG.width - scoreBG.x, bottom);
		scoreBG.updateHitbox();
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
			countText.text = "NIVEL " + (selected + 1) + "/" + entries.length;
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
			+ (TouchNav.MOBILE ? "\ntoca para cambiar" : "");
		layoutPanel();
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
		TransitionHandler.switchState(new PlayState());
	}

	override public function destroy():Void
	{
		super.destroy();
		rows = [];
		entries = [];
		archiveFlags = [];
		icons = [];
		iconTried = [];
		bg = null;
		scoreBG = null;
		countText = null;
		statusText = null;
		navPad = null;
		backButton = null;
		convertButton = null;
		refreshButton = null;
		difficultyText = null;
	}
}
