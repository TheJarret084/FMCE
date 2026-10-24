package funky.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import advanced.ui.EditorBackdrop;
import funky.backend.converter.ConversionJob;
import funky.backend.converter.FNMMToFMCEConverter;
import funky.backend.converter.FNMMToFMCEConverter.ConversionResult;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.NavPad;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import haxe.io.Path;

using StringTools;

/** Una fila de la lista: tarjeta de fondo + titulo + etiqueta (chip) a la derecha. */
private typedef ConverterCard =
{
	var index:Int;
	var kind:Int;
	var accent:Int;
	var chip:Int;
	var bg:FlxSprite;
	var title:FlxText;
	var tag:FlxText;
}

/** Runs FNMM -> FMCE conversion on the .fnmm archives sitting in the levels folder. */
class ConverterMenuState extends FlxState
{
	// Paleta oscura (morado) con acento dorado, para que se lea bien sobre el mosaico.
	private static final ITEM_ACTIVE:Int = 0xFFFFFFFF;
	private static final ITEM_IDLE:Int = 0xFF9A93B0;
	private static final OK_COLOR:Int = 0xFF6BD968;
	private static final FAIL_COLOR:Int = 0xFFE05A5A;
	private static final ACCENT:Int = 0xFFFFC93C;
	private static final CARD_IDLE:Int = 0xFF1A1428;
	private static final CARD_SELECTED:Int = 0xFF2B1D47;
	private static final CARD_BORDER:Int = 0xFF3B3055;
	private static final PANEL_BG:Int = 0xE60F0B1A;
	private static final HEADING:String = "CONVERTIDOR";
	/** Mosaico del fondo (bajo `assets/images`, sin extension). */
	private static inline var BACKDROP_IMAGE:String = "editors/bgs/converter";
	private static final TIP:String = "Toca un archivo para convertirlo. CONVERTIR TODOS los hace uno detras de otro.";

	private static inline var CARD_H:Int = 62;
	private static inline var CARD_STEP:Int = 72;
	private static inline var VISIBLE_ROWS:Int = 5;
	private static inline var LIST_Y:Int = 168;
	private static inline var CHIP_W:Int = 150;
	private static inline var LINE_H:Int = 19;

	private var font:Null<String>;
	private var colX:Int = 0;
	private var colW:Int = 0;
	private var panelH:Int = 0;
	private var maxLines:Int = 1;

	private var selected:Int = 0;
	private var topIndex:Int = 0;
	private var cards:Array<ConverterCard> = [];
	private var emptyItems:Array<FlxSprite> = [];
	private var statusText:FlxText;
	private var counterText:FlxText;
	private var detailText:FlxText;
	private var panel:FlxSprite;
	private var trackBar:FlxSprite;
	private var thumbBar:FlxSprite;
	private var navPad:Null<NavPad>;
	private var archives:Array<String> = [];
	/** Que hace cada fila: 0 = todos los .fnmm, 2 = un .fnmm (`rowArchive`), 3 = jugar el ultimo nivel convertido. */
	private var rowKind:Array<Int> = [];
	private var rowArchive:Array<Null<String>> = [];
	private var leaving:Bool = false;
	/** Carpeta del ultimo nivel convertido que quedo jugable (fila JUGAR). */
	private var playablePath:Null<String> = null;
	private var backButton:FlxSprite;
	private var refreshButton:FlxSprite;
	/** Mensaje fijo de la linea de estado (resultado de la ultima conversion); null = mostrar el conteo de archivos. */
	private var statusNote:Null<String> = null;
	private var statusColor:Int = ITEM_IDLE;

	// Conversion en curso: un job por .fnmm, uno por frame (la pantalla no se congela) y la pantalla de carga encima.
	private var queue:Array<String> = [];
	private var job:Null<ConversionJob>;
	private var overlay:Null<LoadingOverlay>;
	private var results:Array<ConversionResult> = [];
	/** Frames a esperar antes del primer `step()` de un job, para que la pantalla de carga se dibuje antes del trabajo pesado. */
	private var warmup:Int = 0;
	/** Segundos que se deja a Jazmin repartir antes de mostrar el resultado. */
	private var closing:Float = -1;

	override public function create():Void
	{
		super.create();

		font = Paths.fontPath("vcr.ttf");

		// Mismo fondo que el selector de niveles y el de herramientas del modo avanzado (negro + mosaico que se desliza),
		// pero con su propio mosaico: `assets/images/editors/bgs/converter.png` (placeholder, se cambia por otro PNG).
		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000));
		try
		{
			add(new EditorBackdrop(0.55, BACKDROP_IMAGE));
		}
		catch (e:Dynamic) {}

		// Columna central; en el celular se deja libre el lado izquierdo para las flechas (NavPad).
		var margin:Float = TouchNav.MOBILE ? NavPad.WIDTH + 24 : 80;
		colW = Std.int(Math.min(900, FlxG.width - margin * 2));
		colX = Std.int((FlxG.width - colW) / 2);

		var heading = makeText(0, 18, FlxG.width, HEADING, 44, ITEM_ACTIVE, FlxTextAlign.CENTER);
		heading.setBorderStyle(FlxTextBorderStyle.OUTLINE, 0xFF000000, 3);
		add(heading);

		add(makeText(0, 70, FlxG.width, "FNMM  >>  FMCE", 18, ACCENT, FlxTextAlign.CENTER));

		var rule = new FlxSprite(colX, 104);
		rule.makeGraphic(colW, 3, ACCENT);
		rule.alpha = 0.55;
		rule.scrollFactor.set();
		add(rule);

		statusText = makeText(colX, 120, colW, "", 18, ITEM_IDLE, FlxTextAlign.LEFT);
		add(statusText);
		counterText = makeText(colX, 120, colW, "", 18, ITEM_IDLE, FlxTextAlign.RIGHT);
		add(counterText);

		// Barra de desplazamiento (solo se ve cuando hay mas filas de las que caben).
		trackBar = new FlxSprite(colX + colW + 16, LIST_Y);
		trackBar.makeGraphic(6, VISIBLE_ROWS * CARD_STEP - 10, 0x33FFFFFF);
		trackBar.scrollFactor.set();
		trackBar.visible = false;
		add(trackBar);
		thumbBar = new FlxSprite(colX + colW + 16, LIST_Y);
		thumbBar.makeGraphic(6, 30, ACCENT);
		thumbBar.scrollFactor.set();
		thumbBar.visible = false;
		add(thumbBar);

		// Panel de resultados (abajo).
		var panelY = LIST_Y + VISIBLE_ROWS * CARD_STEP + 6;
		panelH = FlxG.height - panelY - (TouchNav.MOBILE ? 14 : 46);
		maxLines = Std.int(Math.max(1, (panelH - 24) / LINE_H));
		panel = new FlxSprite(colX, panelY);
		panel.makeGraphic(colW, panelH, FlxColor.TRANSPARENT, true);
		panel.scrollFactor.set();
		add(panel);
		detailText = makeText(colX + 34, panelY + 12, colW - 54, "", 15, ITEM_IDLE, FlxTextAlign.LEFT);
		detailText.clipRect = new FlxRect(0, 0, colW - 54, panelH - 24);
		add(detailText);
		showDetail(TIP, ITEM_IDLE);

		// R and F are screen-specific shortcuts and stay literal; navigation
		// and accept come from the rebindable set.
		if (TouchNav.MOBILE)
		{
			// Los botones van en la fila del titulo: abajo esta el registro de resultados.
			backButton = makePill("< VOLVER", 24, 22, 170, 52);
			refreshButton = makePill("REFRESCAR", FlxG.width - 24 - 200, 22, 200, 52);

			navPad = NavPad.make(() -> move(-1), () -> move(1));
			if (navPad != null) add(navPad);
		}
		else
		{
			add(makeText(0, FlxG.height - 32, FlxG.width,
				KeyBinds.label(KeyBinds.ACCEPT) + " convertir  |  F convertir todo  |  "
				+ KeyBinds.label(KeyBinds.BACK) + " volver  |  R refrescar", 16, ITEM_IDLE, FlxTextAlign.CENTER));
		}

		FlxG.mouse.visible = false;
		FlxG.mouse.enabled = false;

		refresh();

		TransitionHandler.playIn(this);
	}

	private function makeText(x:Float, y:Float, width:Float, text:String, size:Int, color:Int, align:FlxTextAlign):FlxText
	{
		var item = new FlxText(x, y, width, text, size);
		item.setFormat(font, size, color, align);
		item.scrollFactor.set();
		return item;
	}

	/** Boton tactil en forma de pastilla. Devuelve el fondo (es el que se prueba con `TouchNav.hit`). */
	private function makePill(label:String, x:Float, y:Float, width:Int, height:Int):FlxSprite
	{
		var pill = new FlxSprite(x, y);
		pill.makeGraphic(width, height, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(pill, 1, 1, width - 2, height - 2, height, height, CARD_SELECTED, {thickness: 2, color: ACCENT});
		pill.scrollFactor.set();
		add(pill);
		add(makeText(x, y + (height - 24) / 2, width, label, 22, ITEM_ACTIVE, FlxTextAlign.CENTER));
		return pill;
	}

	private function refresh():Void
	{
		clearCards();

		archives = scanArchives();
		rowKind = [];
		rowArchive = [];

		statusText.text = statusNote != null ? statusNote : archives.length == 0 ? "Sin archivos .fnmm" : archives.length + (archives.length == 1 ? " archivo encontrado" : " archivos encontrados");
		statusText.color = statusNote != null ? statusColor : ITEM_IDLE;

		var options:Array<{label:String, tag:String, kind:Int, path:Null<String>, resumable:Bool}> = [];
		if (playablePath != null)
			options.push({label: Path.withoutDirectory(playablePath), tag: "JUGAR", kind: 3, path: playablePath, resumable: false});
		if (archives.length > 0)
			options.push({label: "Convertir todos", tag: archives.length + " ARCHIVOS", kind: 0, path: null, resumable: false});
		for (archive in archives)
		{
			var resumable = FNMMToFMCEConverter.hasProgress(archive, Paths.levelsRoot());
			options.push({
				label: Path.withoutExtension(Path.withoutDirectory(archive)),
				tag: resumable ? "CONTINUAR" : "FNMM",
				kind: 2,
				path: archive,
				resumable: resumable
			});
		}

		selected = Std.int(Math.max(0, Math.min(selected, options.length - 1)));
		topIndex = Std.int(Math.max(0, Math.min(topIndex, options.length - VISIBLE_ROWS)));

		if (options.length == 0) buildEmpty();

		for (index in 0...options.length)
		{
			var option = options[index];
			rowKind.push(option.kind);
			rowArchive.push(option.path);
			cards.push(makeCard(index, option.label, option.tag, option.kind, option.resumable));
		}

		ensureVisible();
		setupScrollbar(options.length);
		refreshSelection();
	}

	private function makeCard(index:Int, label:String, tagLabel:String, kind:Int, resumable:Bool):ConverterCard
	{
		var accent = kind == 3 ? OK_COLOR : kind == 0 ? ACCENT : resumable ? 0xFF35C6E8 : 0xFF8B5CF6;
		var chip = kind == 3 ? 0xFF1F6B2E : kind == 0 ? 0xFF7A5A00 : resumable ? 0xFF0B5C70 : 0xFF3B2A63;

		var bg = new FlxSprite(colX + 46, LIST_Y + (index - topIndex) * CARD_STEP);
		bg.makeGraphic(colW, CARD_H, FlxColor.TRANSPARENT, true);
		bg.scrollFactor.set();
		bg.alpha = 0; // entra deslizando y apareciendo (ver `animateCards`)
		add(bg);

		var title = makeText(0, 0, colW - 40 - CHIP_W - 40, ellipsize(label, 36), 26, ITEM_ACTIVE, FlxTextAlign.LEFT);
		title.wordWrap = false;
		add(title);

		var tag = makeText(0, 0, CHIP_W, tagLabel, 16, ITEM_ACTIVE, FlxTextAlign.CENTER);
		add(tag);

		return {
			index: index,
			kind: kind,
			accent: accent,
			chip: chip,
			bg: bg,
			title: title,
			tag: tag
		};
	}

	private function drawCard(card:ConverterCard, isSelected:Bool):Void
	{
		var bg = card.bg;
		FlxSpriteUtil.fill(bg, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(bg, 1, 1, colW - 2, CARD_H - 2, 24, 24, isSelected ? CARD_SELECTED : CARD_IDLE,
			{thickness: isSelected ? 3 : 2, color: isSelected ? ACCENT : CARD_BORDER});
		// franja de color segun el tipo de fila
		FlxSpriteUtil.drawRoundRect(bg, 14, 15, 6, CARD_H - 30, 6, 6, card.accent, {thickness: 1, color: card.accent});
		// chip con la etiqueta
		FlxSpriteUtil.drawRoundRect(bg, colW - CHIP_W - 16, (CARD_H - 34) / 2, CHIP_W, 34, 34, 34, card.chip, {thickness: 1, color: card.chip});
	}

	private function clearCards():Void
	{
		for (card in cards)
		{
			remove(card.bg);
			remove(card.title);
			remove(card.tag);
			card.bg.destroy();
			card.title.destroy();
			card.tag.destroy();
		}
		cards = [];

		for (item in emptyItems)
		{
			remove(item);
			item.destroy();
		}
		emptyItems = [];
	}

	/** Mensaje de "no hay nada" en el area de la lista, con la carpeta donde dejar los .fnmm. */
	private function buildEmpty():Void
	{
		var box = new FlxSprite(colX, LIST_Y);
		box.makeGraphic(colW, 3 * CARD_STEP, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRoundRect(box, 1, 1, colW - 2, 3 * CARD_STEP - 2, 28, 28, CARD_IDLE, {thickness: 2, color: CARD_BORDER});
		box.scrollFactor.set();
		add(box);
		emptyItems.push(box);

		var title = makeText(colX, LIST_Y + 26, colW, "No hay archivos .fnmm", 30, ITEM_ACTIVE, FlxTextAlign.CENTER);
		var line = makeText(colX, LIST_Y + 76, colW, "Copialos a esta carpeta:", 18, ITEM_IDLE, FlxTextAlign.CENTER);
		var path = makeText(colX + 20, LIST_Y + 104, colW - 40, Paths.levelsRoot(), 18, ACCENT, FlxTextAlign.CENTER);
		var then = makeText(colX, LIST_Y + 160, colW, TouchNav.MOBILE ? "y despues toca REFRESCAR" : "y despues presiona R", 18, ITEM_IDLE, FlxTextAlign.CENTER);
		for (item in [title, line, path, then])
		{
			add(item);
			emptyItems.push(item);
		}
	}

	private function setupScrollbar(total:Int):Void
	{
		var needed = total > VISIBLE_ROWS;
		trackBar.visible = needed;
		thumbBar.visible = needed;
		if (!needed) return;

		var trackH = VISIBLE_ROWS * CARD_STEP - 10;
		thumbBar.makeGraphic(6, Std.int(Math.max(30, trackH * VISIBLE_ROWS / total)), ACCENT);
	}

	/** Mueve la ventana de la lista para que la fila seleccionada siempre se vea. */
	private function ensureVisible():Void
	{
		if (selected < topIndex) topIndex = selected;
		if (selected >= topIndex + VISIBLE_ROWS) topIndex = selected - VISIBLE_ROWS + 1;
		topIndex = Std.int(Math.max(0, Math.min(topIndex, cards.length - VISIBLE_ROWS)));
	}

	private function refreshSelection():Void
	{
		for (card in cards) drawCard(card, card.index == selected);
		counterText.text = cards.length > 0 ? (selected + 1) + " / " + cards.length : "";
	}

	private function move(step:Int):Void
	{
		if (cards.length == 0 || busy()) return;
		selected = (selected + step + cards.length) % cards.length;
		ensureVisible();
		refreshSelection();
	}

	private inline function busy():Bool
		return leaving || job != null || closing >= 0;

	/** Cada tarjeta se desliza hacia su lugar (y el seleccionado se adelanta un poco). */
	private function animateCards(elapsed:Float):Void
	{
		var k = Math.min(1, elapsed * 14);
		for (card in cards)
		{
			var slot = card.index - topIndex;
			var onScreen = slot >= 0 && slot < VISIBLE_ROWS;
			var isSelected = card.index == selected;

			var bg = card.bg;
			bg.x = FlxMath.lerp(bg.x, colX + (isSelected ? 12 : 0), k);
			bg.y = FlxMath.lerp(bg.y, LIST_Y + slot * CARD_STEP, k);
			bg.alpha = FlxMath.lerp(bg.alpha, onScreen ? (isSelected ? 1 : 0.72) : 0, k);
			bg.visible = bg.alpha > 0.02;

			card.title.setPosition(bg.x + 40, bg.y + (CARD_H - card.title.height) / 2);
			card.tag.setPosition(bg.x + colW - CHIP_W - 16, bg.y + (CARD_H - card.tag.height) / 2);
			card.title.alpha = bg.alpha;
			card.tag.alpha = bg.alpha;
			card.title.visible = bg.visible;
			card.tag.visible = bg.visible;
		}

		if (thumbBar.visible)
		{
			var trackH = VISIBLE_ROWS * CARD_STEP - 10;
			var range = Math.max(1, cards.length - VISIBLE_ROWS);
			var targetY = LIST_Y + (trackH - thumbBar.height) * (topIndex / range);
			thumbBar.y = FlxMath.lerp(thumbBar.y, targetY, k);
		}
	}

	/** Indice de la fila que un dedo acaba de tocar (sin margen extra: las filas estan pegadas), o -1. */
	private function tappedCard():Int
	{
		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (!touch.justPressed) continue;
			if (navPad != null && navPad.covers(touch.screenX, touch.screenY)) continue;

			var point = touch.getWorldPosition(FlxG.camera);
			var found = -1;
			for (card in cards)
			{
				var bg = card.bg;
				if (!bg.visible || bg.alpha < 0.5) continue;
				if (point.x >= bg.x && point.x <= bg.x + bg.width && point.y >= bg.y && point.y <= bg.y + bg.height)
				{
					found = card.index;
					break;
				}
			}
			point.put();
			if (found >= 0) return found;
		}
		#end
		return -1;
	}

	/** Pinta el panel de resultados: la franja izquierda toma el color del resultado. */
	private function showDetail(text:String, color:Int):Void
	{
		var lines = text.split("\n");
		if (lines.length > maxLines)
		{
			var extra = lines.length - (maxLines - 1);
			lines = lines.slice(0, maxLines - 1);
			lines.push("    (+" + extra + " lineas mas)");
		}
		detailText.text = lines.join("\n");
		detailText.color = color;

		var stripe = color == ITEM_IDLE ? ACCENT : color;
		FlxSpriteUtil.fill(panel, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(panel, 1, 1, colW - 2, panelH - 2, 24, 24, PANEL_BG, {thickness: 2, color: CARD_BORDER});
		FlxSpriteUtil.drawRoundRect(panel, 14, 14, 6, panelH - 28, 6, 6, stripe, {thickness: 1, color: stripe});
	}

	private static function ellipsize(text:String, max:Int):String
		return text.length <= max ? text : text.substr(0, max - 1) + "~";

	private function scanArchives():Array<String>
	{
		#if sys
		var found:Array<String> = [];
		if (!Paths.ensureLevelsRoot()) return found;
		try
		{
			for (file in sys.FileSystem.readDirectory(Paths.levelsRoot()))
				if (StringTools.endsWith(file.toLowerCase(), ".fnmm")) found.push(Paths.levelsRoot() + file);
		}
		catch (e:Dynamic)
		{
			Log.error('[ConverterMenuState] no se pudo leer ' + Paths.levelsRoot() + ': ' + Std.string(e));
		}
		found.sort(Reflect.compare);
		return found;
		#else
		return [];
		#end
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		animateCards(elapsed);

		if (leaving) return;

		// Mientras convierte, solo se puede cancelar: el avance queda en `.convert.json` y la siguiente vez continua.
		if (job != null || closing >= 0)
		{
			if (KeyBinds.justPressed(KeyBinds.BACK) || TouchNav.hit(backButton)) cancelJobs();
			else tickJobs(elapsed);
			return;
		}

		if (KeyBinds.justPressed(KeyBinds.BACK)) leave(new MainMenuState());
		if (FlxG.keys.justPressed.R)
		{
			userRefresh();
			return;
		}

		// Touch: buttons first, then the rows (row 0 = convert all).
		if (TouchNav.hit(backButton)) { leave(new MainMenuState()); return; }
		if (TouchNav.hit(refreshButton))
		{
			userRefresh();
			return;
		}
		var tappedRow = tappedCard();
		if (tappedRow >= 0)
		{
			selected = tappedRow;
			ensureVisible();
			refreshSelection();
			activate(selected);
			return;
		}

		if (cards.length == 0) return;

		if (KeyBinds.justPressed(KeyBinds.UP)) move(-1);
		if (KeyBinds.justPressed(KeyBinds.DOWN)) move(1);
		if (KeyBinds.justPressed(KeyBinds.ACCEPT)) activate(selected);
		if (FlxG.keys.justPressed.F) run(null);
	}

	/** Refrescar pedido por la persona: suelta el mensaje fijo y vuelve a contar los archivos. */
	private function userRefresh():Void
	{
		statusNote = null;
		refresh();
	}

	private function leave(next:FlxState):Void
	{
		leaving = true;
		TransitionHandler.switchState(next);
	}

	/** Lo que hace la fila `index` (ver `rowKind`). */
	private function activate(index:Int):Void
	{
		if (index < 0 || index >= rowKind.length) return;
		switch (rowKind[index])
		{
			case 0: run(null);
			case 3: play(rowArchive[index]);
			default: run(rowArchive[index]);
		}
	}

	private function play(levelDir:Null<String>):Void
	{
		if (levelDir == null) return;
		leaving = true;
		funky.game.PlayState.archivePath = levelDir;
		TransitionHandler.switchState(new funky.game.PlayState());
	}

	private function run(archive:Null<String>):Void
	{
		#if sys
		queue = archive == null ? archives.copy() : [archive];
		if (queue.length == 0) return;
		results = [];
		overlay = new LoadingOverlay("Convirtiendo...");
		add(overlay);
		startNext();
		#else
		showDetail("La conversion necesita una build de escritorio (sys).", FAIL_COLOR);
		#end
	}

	private function startNext():Void
	{
		var path = queue.shift();
		job = new ConversionJob(path, Paths.levelsRoot());
		warmup = 2;
		overlay.setProgress(0, Path.withoutExtension(Path.withoutDirectory(path)));
	}

	/** Un pedazo de la conversion por frame, con presupuesto de tiempo para que el juego siga respondiendo. */
	private function tickJobs(elapsed:Float):Void
	{
		if (closing >= 0)
		{
			closing -= elapsed;
			if (closing < 0) conclude();
			return;
		}
		if (warmup > 0)
		{
			warmup--;
			return;
		}
		var t0 = haxe.Timer.stamp();
		var more = true;
		do
		{
			more = job.step();
		}
		while (more && haxe.Timer.stamp() - t0 < 0.012);
		overlay.setProgress((results.length + job.progress) / (results.length + queue.length + 1), job.result.id + ": " + job.label);

		if (more) return;
		results.push(job.result);
		job = null;
		if (queue.length > 0)
		{
			startNext();
			return;
		}
		var failed = 0;
		for (result in results) if (!result.ok) failed++;
		overlay.finish(failed == 0 ? "Listo" : "Terminado, con " + failed + " fallo(s)");
		closing = 1.2;
	}

	private function cancelJobs():Void
	{
		Log.info('[ConverterMenu] cancelado; lo hecho queda guardado para continuar');
		job = null;
		queue = [];
		closing = -1;
		hideOverlay();
		statusNote = "Cancelado: se puede continuar mas tarde";
		statusColor = ACCENT;
		refresh();
	}

	private function hideOverlay():Void
	{
		if (overlay == null) return;
		remove(overlay);
		overlay.destroy();
		overlay = null;
	}

	/** Todos los jobs terminaron y Jazmin ya repartio: muestra el resultado. */
	private function conclude():Void
	{
		hideOverlay();
		closing = -1;
		var failed = 0;
		var lines:Array<String> = [];
		for (result in results)
		{
			if (!result.ok) failed++;
			if (result.ok && result.playable) playablePath = result.target;
			lines.push(format(result));
			if (lines.length > 6) lines.shift();
		}

		var color:Int;
		if (results.length == 1)
		{
			color = results[0].ok ? OK_COLOR : FAIL_COLOR;
			statusNote = results[0].ok ? "Convertido: " + results[0].id : "Error en " + results[0].id;
		}
		else
		{
			color = failed > 0 ? FAIL_COLOR : OK_COLOR;
			statusNote = "Terminadas: " + results.length + "  |  fallidas: " + failed;
		}
		statusColor = color;
		showDetail(lines.join("\n"), color);

		Log.info('[ConverterMenu] done, failed=' + failed);
		refresh();
	}

	private function format(result:ConversionResult):String
	{
		if (!result.ok) return "· " + result.id + " -> FALLO: " + result.error;
		var text = "· " + result.id + " -> " + result.notes + " notas, " + result.laneCount + " lanes, " + result.strips + (result.strips == 1 ? " sprite" : " sprites")
			+ (result.playable ? "  |  LISTO PARA JUGAR" : "  |  REVISAR") + (result.resumed ? "  (retomada)" : "");
		for (warning in result.warnings) text += "\n    aviso: " + warning;
		return text;
	}

	override public function destroy():Void
	{
		super.destroy();
		cards = [];
		emptyItems = [];
		archives = [];
		rowKind = [];
		rowArchive = [];
		queue = [];
		job = null;
		overlay = null;
		backButton = null;
		refreshButton = null;
		navPad = null;
	}
}
