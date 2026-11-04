package funky.menus;

import advanced.ui.EditorBackdrop;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import funkin.editors.ui.*;
import funkin.editors.ui.UIWarningSubstate.WarningButton;
import funky.backend.converter.ConversionJob;
import funky.backend.converter.FMCEToFNMMExporter;
import funky.backend.converter.FNMMToFMCEConverter;
import funky.backend.converter.FNMMToFMCEConverter.ConversionResult;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.Paths;
import funky.core.TransitionHandler;
import haxe.io.Path;

using StringTools;

private typedef ConverterRow =
{
	var label:String;
	/** 0 = todos los .fnmm, 2 = un .fnmm, 3 = jugar el ultimo nivel, 4 = exportar un nivel. */
	var kind:Int;
	var path:Null<String>;
}

/** Convierte los .fnmm de `levels/` a niveles FMCE (y al reves, en modo exportar). Con la UI de Codename. */
class ConverterMenuState extends UIState
{
	static inline var OK_COLOR:Int = 0xFF8FE388;
	static inline var FAIL_COLOR:Int = 0xFFFF8A8A;
	static inline var MUTED:Int = 0xFFB4BAC6;
	static inline var ACTIVE:Int = 0xFF8CC4FF;
	static inline var BACKDROP_IMAGE:String = "editors/bgs/converter";

	static inline var MARGIN:Int = 20;
	static inline var LIST_W:Int = 480;
	static inline var ROW_STEP:Int = 40;
	static inline var LIST_TOP:Int = 56;
	static inline var LINE_H:Int = 18;

	var exportMode:Bool;
	var rows:Array<ConverterRow> = [];
	var rowButtons:Array<UIButton> = [];
	var archives:Array<String> = [];
	var selected:Int = 0;
	var topIndex:Int = 0;
	var visibleRows:Int = 1;

	var listWindow:UIWindow;
	var listTitle:UIText;
	var statusText:UIText;
	var detailText:UIText;
	var detailLines:Int = 1;
	var modeButton:UIButton;
	var refreshButton:UIButton;
	var backButton:UIButton;
	var upButton:UIButton;
	var downButton:UIButton;
	var cancelButton:Null<UIButton> = null;

	var statusNote:Null<String> = null;
	var statusColor:Int = MUTED;
	var playablePath:Null<String> = null;
	var leaving:Bool = false;

	var queue:Array<String> = [];
	var job:Null<ConversionJob>;
	var overlay:Null<LoadingOverlay>;
	var results:Array<ConversionResult> = [];
	/** Frames a esperar antes del primer `step()` de un job, para que la pantalla de carga se dibuje antes del trabajo pesado. */
	var warmup:Int = 0;
	/** Segundos de pausa al terminar, antes de mostrar el resultado. */
	var closing:Float = -1;

	public function new(?exportMode:Bool = false)
	{
		super();
		this.exportMode = exportMode;
	}

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		FlxG.mouse.enabled = true;

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000));
		try
		{
			add(new EditorBackdrop(0.55, BACKDROP_IMAGE));
		}
		catch (e:Dynamic) {}

		// ventana izquierda: la lista
		var winH = FlxG.height - MARGIN * 2;
		listWindow = new UIWindow(MARGIN, MARGIN, LIST_W, winH, "");
		add(listWindow);
		listTitle = new UIText(MARGIN + 25, MARGIN + 6, LIST_W - 50, "", 15);
		add(listTitle);
		visibleRows = Std.int(Math.max(1, Math.floor((winH - LIST_TOP - 60) / ROW_STEP)));

		upButton = new UIButton(MARGIN + 20, MARGIN + winH - 48, "Subir", function() scroll(-visibleRows), 100, 32);
		add(upButton);
		downButton = new UIButton(MARGIN + 130, MARGIN + winH - 48, "Bajar", function() scroll(visibleRows), 100, 32);
		add(downButton);

		// ventana derecha: resultado y botones
		var rightX = MARGIN * 2 + LIST_W;
		var rightW = FlxG.width - rightX - MARGIN;
		add(new UIWindow(rightX, MARGIN, rightW, winH, "Resultado"));
		statusText = new UIText(rightX + 20, MARGIN + 44, rightW - 40, "", 16, MUTED);
		add(statusText);
		detailLines = Std.int(Math.max(1, Math.floor((winH - 44 - 40 - 80) / LINE_H)));
		detailText = new UIText(rightX + 20, MARGIN + 80, rightW - 40, "", 14, MUTED);
		add(detailText);

		var buttonY = MARGIN + winH - 48;
		var buttonW = Std.int(Math.min(170, (rightW - 40 - 20) / 3));
		modeButton = new UIButton(rightX + 20, buttonY, "", toggleMode, buttonW, 32);
		add(modeButton);
		refreshButton = new UIButton(rightX + 30 + buttonW, buttonY, "Refrescar", userRefresh, buttonW, 32);
		add(refreshButton);
		backButton = new UIButton(rightX + 40 + buttonW * 2, buttonY, "Volver", function() leave(new MainMenuState()), buttonW, 32);
		add(backButton);

		refresh();
	}

	function scroll(amount:Int):Void
	{
		if (busy()) return;
		topIndex = Std.int(Math.max(0, Math.min(topIndex + amount, rows.length - visibleRows)));
		buildButtons();
	}

	function toggleMode():Void
	{
		if (busy()) return;
		exportMode = !exportMode;
		statusNote = null;
		selected = 0;
		topIndex = 0;
		refresh();
	}

	function userRefresh():Void
	{
		if (busy()) return;
		statusNote = null;
		refresh();
	}

	inline function busy():Bool
		return leaving || job != null || closing >= 0;

	function refresh():Void
	{
		rows = [];
		archives = exportMode ? [] : scanArchives();

		if (exportMode)
		{
			for (level in FMCEToFNMMExporter.listLevels()) rows.push({label: level, kind: 4, path: level});
			listTitle.text = "Niveles de FMCE";
			modeButton.field.text = "Modo: exportar";
			statusText.text = statusNote != null ? statusNote : rows.length + (rows.length == 1 ? " nivel" : " niveles");
			showDetail(rows.length == 0 ? "No hay niveles en " + Paths.levelsRoot() : "Elige un nivel para exportarlo a .FNMM en exports/. La carpeta data/ del nivel no entra al .FNMM.", MUTED);
		}
		else
		{
			if (playablePath != null) rows.push({label: "JUGAR  " + Path.withoutDirectory(playablePath), kind: 3, path: playablePath});
			if (archives.length > 0) rows.push({label: "Convertir todos (" + archives.length + ")", kind: 0, path: null});
			for (archive in archives)
			{
				var resumable = FNMMToFMCEConverter.hasProgress(archive, Paths.levelsRoot());
				rows.push({label: Path.withoutExtension(Path.withoutDirectory(archive)) + (resumable ? "   [CONTINUAR]" : ""), kind: 2, path: archive});
			}
			listTitle.text = "Archivos .FNMM";
			modeButton.field.text = "Modo: importar";
			statusText.text = statusNote != null ? statusNote : archives.length == 0 ? "Sin archivos .fnmm" : archives.length + (archives.length == 1 ? " archivo encontrado" : " archivos encontrados");
			showDetail(archives.length == 0 ? "No hay archivos .fnmm. Copialos a esta carpeta y toca Refrescar:\n" + Paths.levelsRoot()
				: "Elige un archivo para convertirlo. \"Convertir todos\" los hace uno detras de otro.", MUTED);
		}
		statusText.color = statusNote != null ? statusColor : MUTED;

		selected = Std.int(Math.max(0, Math.min(selected, rows.length - 1)));
		topIndex = Std.int(Math.max(0, Math.min(topIndex, rows.length - visibleRows)));
		buildButtons();
	}

	function buildButtons():Void
	{
		for (button in rowButtons)
		{
			remove(button);
			button.destroy();
		}
		rowButtons = [];

		var last = Std.int(Math.min(rows.length, topIndex + visibleRows));
		for (index in topIndex...last)
		{
			var row = rows[index];
			var button = new UIButton(MARGIN + 20, MARGIN + LIST_TOP + (index - topIndex) * ROW_STEP, ellipsize(row.label, 44), function() activate(index), LIST_W - 40, 32);
			button.color = index == selected ? ACTIVE : (row.kind == 3 ? OK_COLOR : 0xFFFFFFFF);
			rowButtons.push(button);
			add(button);
		}
		var enabled = !busy();
		for (button in rowButtons) button.shouldPress = button.selectable = enabled;
		upButton.selectable = upButton.shouldPress = enabled && topIndex > 0;
		downButton.selectable = downButton.shouldPress = enabled && topIndex + visibleRows < rows.length;
	}

	static function ellipsize(text:String, max:Int):String
		return text.length <= max ? text : text.substr(0, max - 1) + "~";

	function select(step:Int):Void
	{
		if (rows.length == 0 || busy()) return;
		selected = (selected + step + rows.length) % rows.length;
		if (selected < topIndex) topIndex = selected;
		if (selected >= topIndex + visibleRows) topIndex = selected - visibleRows + 1;
		buildButtons();
	}

	function activate(index:Int):Void
	{
		if (busy() || index < 0 || index >= rows.length) return;
		selected = index;
		var row = rows[index];
		switch (row.kind)
		{
			case 0: run(null);
			case 3: play(row.path);
			case 4: exportLevel(row.path);
			default: run(row.path);
		}
	}

	function exportLevel(level:Null<String>):Void
	{
		if (level == null) return;
		leaving = true;
		FlxG.switchState(new FNMMExportState(level, function():FlxState return new ConverterMenuState(true)));
	}

	function play(levelDir:Null<String>):Void
	{
		if (levelDir == null) return;
		leaving = true;
		funky.game.PlayState.archivePath = levelDir;
		funky.game.PlayState.resetLaunch();
		TransitionHandler.switchState(new funky.menus.LoadingLevelState());
	}

	function leave(next:FlxState):Void
	{
		if (busy()) return;
		leaving = true;
		TransitionHandler.switchState(next);
	}

	/** Muestra el texto del panel; si es mas largo de lo que cabe, lo corta. */
	function showDetail(text:String, color:Int):Void
	{
		var lines = text.split("\n");
		if (lines.length > detailLines)
		{
			var extra = lines.length - (detailLines - 1);
			lines = lines.slice(0, detailLines - 1);
			lines.push("    (+" + extra + " lineas mas)");
		}
		detailText.text = lines.join("\n");
		detailText.color = color;
	}

	function scanArchives():Array<String>
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
		if (leaving) return;

		// Mientras convierte solo se puede cancelar: lo hecho queda en `.convert.json` y la siguiente vez continua.
		if (job != null || closing >= 0)
		{
			if (KeyBinds.justPressed(KeyBinds.BACK) || FlxG.keys.justPressed.ESCAPE) cancelJobs();
			else tickJobs(elapsed);
			return;
		}
		if (subState != null) return;

		if (KeyBinds.justPressed(KeyBinds.BACK) || FlxG.keys.justPressed.ESCAPE) leave(new MainMenuState());
		if (FlxG.keys.justPressed.R) userRefresh();
		if (FlxG.keys.justPressed.E) toggleMode();
		if (FlxG.mouse.wheel != 0) scroll(-FlxG.mouse.wheel);
		if (KeyBinds.justPressed(KeyBinds.UP)) select(-1);
		if (KeyBinds.justPressed(KeyBinds.DOWN)) select(1);
		if (KeyBinds.justPressed(KeyBinds.ACCEPT)) activate(selected);
		if (FlxG.keys.justPressed.F && !exportMode) run(null);
	}

	function run(archive:Null<String>):Void
	{
		#if sys
		queue = archive == null ? archives.copy() : [archive];
		if (queue.length == 0) return;
		results = [];
		overlay = new LoadingOverlay("Convirtiendo...");
		add(overlay);
		cancelButton = new UIButton(FlxG.width / 2 - 80, FlxG.height - 64, "Cancelar", cancelJobs, 160, 32);
		add(cancelButton);
		buildButtons();
		startNext();
		#else
		showDetail("La conversion necesita una build de escritorio (sys).", FAIL_COLOR);
		#end
	}

	function startNext():Void
	{
		var path = queue.shift();
		job = new ConversionJob(path, Paths.levelsRoot());
		warmup = 2;
		overlay.setProgress(0, Path.withoutExtension(Path.withoutDirectory(path)));
	}

	/** Un pedazo de la conversion por frame, con presupuesto de tiempo para que el juego siga respondiendo. */
	function tickJobs(elapsed:Float):Void
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

	function cancelJobs():Void
	{
		Log.info('[ConverterMenu] cancelado; lo hecho queda guardado para continuar');
		job = null;
		queue = [];
		closing = -1;
		hideOverlay();
		statusNote = "Cancelado: se puede continuar mas tarde";
		statusColor = 0xFFFFD866;
		refresh();
	}

	function hideOverlay():Void
	{
		if (overlay != null)
		{
			remove(overlay);
			overlay.destroy();
			overlay = null;
		}
		if (cancelButton != null)
		{
			remove(cancelButton);
			cancelButton.destroy();
			cancelButton = null;
		}
	}

	/** Terminaron todos los jobs: muestra el resultado (y avisa con una ventana si algo fallo). */
	function conclude():Void
	{
		hideOverlay();
		closing = -1;
		var failed = 0;
		var lines:Array<String> = [];
		var errors:Array<String> = [];
		for (result in results)
		{
			if (!result.ok)
			{
				failed++;
				errors.push(result.id + ": " + result.error);
			}
			if (result.ok && result.playable) playablePath = result.target;
			lines.push(format(result));
			if (lines.length > detailLines) lines.shift();
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
		Log.info('[ConverterMenu] done, failed=' + failed);
		refresh();
		showDetail(lines.join("\n"), color);

		if (failed > 0)
		{
			var shown = errors.slice(0, 5);
			var message = shown.join("\n");
			if (errors.length > shown.length) message += "\n(+" + (errors.length - shown.length) + " mas)";
			openSubState(new UIWarningSubstate("No se pudo convertir", message, [{label: "Cerrar", onClick: function(_) {}}]));
		}
	}

	function format(result:ConversionResult):String
	{
		if (!result.ok) return "- " + result.id + " -> FALLO: " + result.error;
		var text = "- " + result.id + " -> " + result.notes + " notas, " + result.laneCount + " lanes, " + result.strips + (result.strips == 1 ? " sprite" : " sprites")
			+ (result.playable ? "  |  LISTO PARA JUGAR" : "  |  REVISAR") + (result.resumed ? "  (retomada)" : "");
		for (warning in result.warnings) text += "\n    aviso: " + warning;
		return text;
	}

	override public function destroy():Void
	{
		super.destroy();
		rows = [];
		rowButtons = [];
		archives = [];
		queue = [];
		job = null;
		overlay = null;
		cancelButton = null;
	}
}
