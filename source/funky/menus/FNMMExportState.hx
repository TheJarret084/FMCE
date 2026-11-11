package funky.menus;

import advanced.AdvancedToolsState;
import advanced.ui.EditorBackdrop;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import funkin.editors.ui.*;
import funkin.editors.ui.UIWarningSubstate.WarningButton;
import funky.backend.converter.FMCEToFNMMExporter;
import funky.backend.converter.FNMMExportJob;
import funky.backend.converter.FMCEToFNMMExporter.FNMMExportPlan;
import funky.core.KeyBinds;

class FNMMExportState extends UIState
{
	static inline var WIN_W:Int = 640;
	static inline var WIN_H:Int = 380;
	static inline var BAR_H:Int = 14;
	static inline var OK_COLOR:Int = 0xFF8FE388;
	static inline var FAIL_COLOR:Int = 0xFFFF8A8A;
	static inline var MUTED:Int = 0xFFB4BAC6;

	var levelName:String;
	var back:Null<Void->FlxState>;
	var plan:FNMMExportPlan;

	var statusText:UIText;
	var barBack:FlxSprite;
	var barFill:FlxSprite;
	var exportButton:UIButton;
	var backButton:UIButton;
	var barW:Int = 0;

	var job:Null<FNMMExportJob> = null;

	var warmup:Int = 0;

	public function new(levelName:String, ?back:Void->FlxState)
	{
		super();
		this.levelName = levelName;
		this.back = back;
	}

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		FlxG.mouse.enabled = true;

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000));
		try
		{
			add(new EditorBackdrop());
		}
		catch (e:Dynamic) {}

		plan = FMCEToFNMMExporter.plan(levelName);

		var x = (FlxG.width - WIN_W) / 2;
		var y = (FlxG.height - WIN_H) / 2;
		add(new UIWindow(x, y, WIN_W, WIN_H, "Exportar .FNMM"));

		var textW = WIN_W - 40;
		var line = y + 46;
		add(new UIText(x + 20, line, textW, "Nivel: " + levelName, 18));
		line += 34;
		add(new UIText(x + 20, line, textW, "Destino: " + FMCEToFNMMExporter.outputPath(levelName), 14, MUTED));
		line += 52;
		add(new UIText(x + 20, line, textW, "Se exporta: chart, events, scene, audio, sprites y videos (todo como tiras de PNG indexado, igual que un .FNMM de Funky Maker: Mobile; los videos van a 12-24 fps).", 14));
		line += 56;
		add(new UIText(x + 20, line, textW, ignoredSummary(), 14, plan.ignored.length > 0 ? 0xFFFFD866 : MUTED));
		line += 62;

		barW = textW;
		barBack = new FlxSprite(x + 20, line).makeGraphic(barW, BAR_H, 0xFF2A2F3A);
		add(barBack);
		barFill = new FlxSprite(x + 20, line).makeGraphic(1, BAR_H, 0xFF6BD968);
		barFill.visible = false;
		add(barFill);
		line += BAR_H + 10;

		statusText = new UIText(x + 20, line, textW, "", 14, MUTED);
		add(statusText);

		exportButton = new UIButton(x + WIN_W - 20 - 150, y + WIN_H - 20 - 32, "Exportar", onExport, 150, 32);
		add(exportButton);
		backButton = new UIButton(x + WIN_W - 20 - 150 - 16 - 150, y + WIN_H - 20 - 32, "Volver", leave, 150, 32);
		add(backButton);
	}

	function ignoredSummary():String
	{
		if (plan.ignored.length == 0) return "No queda nada fuera del .FNMM.";
		var folders = 0;
		for (file in plan.ignored) if (file.indexOf("/") > 0 && StringTools.startsWith(file, "data/")) folders++;
		return "Se ignora: " + plan.ignored.length + (plan.ignored.length == 1 ? " archivo" : " archivos")
			+ (folders > 0 ? " (data/ y otros)" : "") + ". El .FNMM no guarda scripts ni shaders.";
	}

	function onExport():Void
	{
		if (job != null) return;
		if (plan.ignored.length == 0)
		{
			start();
			return;
		}
		var shown = plan.ignored.slice(0, 6);
		var message = "El .FNMM no guarda estos archivos del nivel:\n" + [for (file in shown) "  " + file].join("\n");
		if (plan.ignored.length > shown.length) message += "\n  (+" + (plan.ignored.length - shown.length) + " mas)";
		var buttons:Array<WarningButton> = [
			{label: "Cancelar", onClick: function(_) {}},
			{label: "Exportar igual", onClick: function(_) start()}
		];
		openSubState(new UIWarningSubstate("Se ignora data/", message, buttons, false));
	}

	function start():Void
	{
		job = FMCEToFNMMExporter.begin(levelName);
		warmup = 2;
		setBusy(true);
		statusText.text = "Exportando...";
		statusText.color = MUTED;
	}

	function setBusy(busy:Bool):Void
	{
		exportButton.shouldPress = exportButton.selectable = !busy;
		backButton.shouldPress = backButton.selectable = !busy;
		barFill.visible = busy;
		if (busy) setBar(0);
	}

	function setBar(progress:Float):Void
	{
		barFill.makeGraphic(Std.int(Math.max(1, barW * Math.min(1, progress))), BAR_H, 0xFF6BD968);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (job != null)
		{
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

			setBar(job.progress);
			statusText.text = job.label;
			if (!more) finish();
			return;
		}

		if (subState == null && (KeyBinds.justPressed(KeyBinds.BACK) || FlxG.keys.justPressed.ESCAPE)) leave();
	}

	function finish():Void
	{
		var result = job.result;
		job = null;
		setBusy(false);
		if (!result.ok)
		{
			statusText.text = "Error: " + result.error;
			statusText.color = FAIL_COLOR;
			openSubState(new UIWarningSubstate("No se pudo exportar", result.error, [{label: "Cerrar", onClick: function(_) {}}]));
			return;
		}

		statusText.text = "Exportado: " + result.path + " (" + result.files + " archivos, " + result.notes + " notas, " + result.sprites + " sprites)";
		statusText.color = OK_COLOR;
		if (result.warnings.length == 0) return;

		var shown = result.warnings.slice(0, 7);
		var message = [for (warning in shown) "- " + warning].join("\n");
		if (result.warnings.length > shown.length) message += "\n(+" + (result.warnings.length - shown.length) + " avisos mas, en el log)";
		openSubState(new UIWarningSubstate("Exportado con avisos", message, [{label: "Aceptar", onClick: function(_) {}}], false));
	}

	function leave():Void
	{
		FlxG.switchState(back != null ? back() : new AdvancedToolsState(levelName));
	}
}
