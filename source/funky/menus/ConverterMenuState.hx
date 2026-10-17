package funky.menus;

import flixel.util.FlxAxes;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import funky.backend.converter.ConversionJob;
import funky.backend.converter.FNMMToFMCEConverter;
import funky.backend.converter.FNMMToFMCEConverter.ConversionResult;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import haxe.io.Path;

using StringTools;

/** Runs FNMM -> FMCE conversion on the .fnmm archives sitting in the levels folder. */
class ConverterMenuState extends FlxState
{
	private static final BG_COLOR:Int = 0xFF141419;
	private static final ITEM_ACTIVE:Int = 0xFFFFFFFF;
	private static final ITEM_IDLE:Int = 0xFF6E6E7A;
	private static final OK_COLOR:Int = 0xFF6BD968;
	private static final FAIL_COLOR:Int = 0xFFE05A5A;
	private static final HEADING:String = "CONVERTIDOR FMCE";

	private var selected:Int = 0;
	private var rows:Array<FlxText> = [];
	private var statusText:FlxText;
	private var detailText:FlxText;
	private var archives:Array<String> = [];
	/** Que hace cada fila: 0 = todos los .fnmm, 2 = un .fnmm (`rowArchive`), 3 = jugar el ultimo nivel convertido. */
	private var rowKind:Array<Int> = [];
	private var rowArchive:Array<Null<String>> = [];
	private var leaving:Bool = false;
	/** Carpeta del ultimo nivel convertido que quedo jugable (fila JUGAR). */
	private var playablePath:Null<String> = null;
	private var backButton:FlxText;
	private var refreshButton:FlxText;

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

		var background = new FlxSprite(0, 0);
		background.makeGraphic(FlxG.width, FlxG.height, BG_COLOR);
		background.scrollFactor.set();
		add(background);

		var heading = new FlxText(0, 0, FlxG.width, HEADING, 32);
		heading.size = 32;
		heading.color = ITEM_ACTIVE;
		heading.alignment = FlxTextAlign.CENTER;
		heading.screenCenter(FlxAxes.X);
		heading.y = 70;
		add(heading);

		statusText = new FlxText(0, 0, FlxG.width, "", 18);
		statusText.size = 18;
		statusText.color = ITEM_IDLE;
		statusText.alignment = FlxTextAlign.CENTER;
		statusText.screenCenter(FlxAxes.X);
		statusText.y = 130;
		add(statusText);

		detailText = new FlxText(40, FlxG.height - 190, FlxG.width - 80, "", 16);
		detailText.size = 16;
		detailText.color = ITEM_IDLE;
		add(detailText);

		// R and F are screen-specific shortcuts and stay literal; navigation
		// and accept come from the rebindable set.
		if (TouchNav.MOBILE)
		{
			// Buttons go on the heading row: the bottom holds the result log.
			backButton = TouchNav.button("< VOLVER", 30, 64);
			refreshButton = TouchNav.button("REFRESCAR", FlxG.width - 250, 64);
			add(backButton);
			add(refreshButton);
		}
		else
		{
			var hint = new FlxText(0, 0, FlxG.width,
				KeyBinds.label(KeyBinds.ACCEPT) + " convertir  |  F convertir todo  |  "
				+ KeyBinds.label(KeyBinds.BACK) + " volver  |  R refrescar", 16);
			hint.size = 16;
			hint.color = ITEM_IDLE;
			hint.alignment = FlxTextAlign.CENTER;
			hint.screenCenter(FlxAxes.X);
			hint.y = FlxG.height - 50;
			add(hint);
		}

		FlxG.mouse.visible = false;
		FlxG.mouse.enabled = false;

		refresh();

		TransitionHandler.playIn(this);
	}

	private function refresh():Void
	{
		for (row in rows) remove(row);
		rows = [];
		rowKind = [];
		rowArchive = [];

		archives = scanArchives();
		var root = Paths.levelsRoot();
		statusText.text = archives.length == 0 ? "No hay archivos .fnmm en " + root : archives.length + (archives.length == 1 ? " archivo encontrado" : " archivos encontrados");

		var options:Array<{label:String, kind:Int, path:Null<String>}> = [];
		if (playablePath != null) options.push({label: "JUGAR  " + Path.withoutDirectory(playablePath), kind: 3, path: playablePath});
		if (archives.length > 0) options.push({label: "CONVERTIR TODOS", kind: 0, path: null});
		for (archive in archives)
		{
			var resumable = FNMMToFMCEConverter.hasProgress(archive, Paths.levelsRoot());
			options.push({label: Path.withoutExtension(Path.withoutDirectory(archive)) + (resumable ? "  [continuar]" : ""), kind: 2, path: archive});
		}

		selected = Std.int(Math.max(0, Math.min(selected, options.length - 1)));

		for (index in 0...options.length)
		{
			var row = new FlxText(0, 0, FlxG.width, options[index].label, 24);
			row.size = 24;
			row.alignment = FlxTextAlign.CENTER;
			row.screenCenter(FlxAxes.X);
			row.y = 190 + index * 38;
			add(row);
			rows.push(row);
			rowKind.push(options[index].kind);
			rowArchive.push(options[index].path);
		}
		refreshSelection();
	}

	private function refreshSelection():Void
	{
		for (index in 0...rows.length)
		{
			rows[index].color = index == selected ? ITEM_ACTIVE : ITEM_IDLE;
			rows[index].alpha = index == selected ? 1 : 0.6;
		}
	}

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
			refresh();
			return;
		}

		// Touch: buttons first, then the rows (row 0 = convert all).
		if (TouchNav.hit(backButton)) { leave(new MainMenuState()); return; }
		if (TouchNav.hit(refreshButton))
		{
			refresh();
			return;
		}
		var tappedRow = TouchNav.rowTapped(rows);
		if (tappedRow >= 0)
		{
			selected = tappedRow;
			refreshSelection();
			activate(selected);
			return;
		}

		if (rows.length == 0) return;

		if (KeyBinds.justPressed(KeyBinds.UP))
		{
			selected = (selected - 1 + rows.length) % rows.length;
			refreshSelection();
		}
		if (KeyBinds.justPressed(KeyBinds.DOWN))
		{
			selected = (selected + 1) % rows.length;
			refreshSelection();
		}
		if (KeyBinds.justPressed(KeyBinds.ACCEPT)) activate(selected);
		if (FlxG.keys.justPressed.F) run(null);
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
		detailText.text = "La conversion necesita una build de escritorio (sys).";
		detailText.color = FAIL_COLOR;
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
		statusText.text = "Cancelado: se puede continuar mas tarde";
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
		detailText.text = lines.join("\n");
		if (results.length == 1)
		{
			detailText.color = results[0].ok ? OK_COLOR : FAIL_COLOR;
			statusText.text = results[0].ok ? "Convertido: " + results[0].id : "Error en " + results[0].id;
		}
		else
		{
			detailText.color = failed > 0 ? FAIL_COLOR : OK_COLOR;
			statusText.text = "Terminadas: " + results.length + "  |  fallidas: " + failed;
		}
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
		rows = [];
		archives = [];
		rowKind = [];
		rowArchive = [];
		queue = [];
		job = null;
		overlay = null;
		backButton = null;
		refreshButton = null;
	}
}
