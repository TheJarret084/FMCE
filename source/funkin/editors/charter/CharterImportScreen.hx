package funkin.editors.charter;

import funkin.backend.chart.ChartImporter;
import haxe.io.Bytes;

/**
 * Importa las notas de un chart de FNMM (data.json), Codename, Legacy/Psych (o FMCE) y reemplaza las del chart abierto.
 * Un nivel de FMCE tiene un solo chart (`chart.json`): importar reemplaza sus notas, sin dificultades.
 */
class CharterImportScreen extends UISubstateWindow {
	public var explorer:UIFileExplorer;
	public var info:UIText;
	public var importButton:UIButton;
	public var closeButton:UIButton;

	var result:ImportResult = null;

	public function new() {
		super();
	}

	public override function create() {
		winTitle = TU.translate("charterImport.win-title");
		winWidth = 560; winHeight = 440;
		super.create();

		var title:UIText;
		add(title = new UIText(windowSpr.x + 20, windowSpr.y + 30 + 16, 0, TU.translate("charterImport.title"), 28));

		explorer = new UIFileExplorer(title.x, title.y + title.height + 20, 320, 58, "json", onFile);
		add(explorer);

		info = new UIText(title.x, explorer.y + explorer.bHeight + 20, windowSpr.bWidth - 40, TU.translate("charterImport.pickFile"), 14);
		add(info);

		importButton = new UIButton(windowSpr.x + windowSpr.bWidth - 20 - 125, windowSpr.y + windowSpr.bHeight - 16 - 32, TU.translate("charterImport.import"), doImport, 125);
		add(importButton);
		closeButton = new UIButton(importButton.x - 20 - 125, importButton.y, TU.translate("editor.close"), function() close(), 125);
		closeButton.color = 0xFFFF0000;
		add(closeButton);
	}

	function onFile(path:String, bytes:Bytes):Void {
		result = null;
		if (path == null || bytes == null) {
			info.text = TU.translate("charterImport.pickFile");
			return;
		}
		try {
			var lanes = 4;
			for (sl in PlayState.SONG.strumLines) if (sl.keyCount != null && sl.keyCount > lanes) lanes = sl.keyCount;
			result = ChartImporter.parse(bytes.toString(), lanes);
			var lines = [TU.translate("charterImport.format", [formatName(result.format)]),
				TU.translate("charterImport.summary", ["" + result.notes, "" + result.sustains, "" + result.lines.length])];
			if (result.droppedLanes > 0) lines.push(TU.translate("charterImport.droppedLanes", ["" + result.droppedLanes, "" + result.lanes]));
			if (result.duplicates > 0) lines.push("Notas repetidas descartadas: " + result.duplicates);
			if (result.droppedEvents > 0) lines.push(TU.translate("charterImport.droppedEvents", ["" + result.droppedEvents]));
			if (result.bpm != null && PlayState.SONG.meta.bpm != null && Math.abs(result.bpm - PlayState.SONG.meta.bpm) > 0.5)
				lines.push(TU.translate("charterImport.bpmMismatch", ["" + result.bpm, "" + PlayState.SONG.meta.bpm]));
			info.text = lines.join("\n");
		} catch (e:Dynamic) {
			info.text = TU.translate("charterImport.error", ["" + e]);
		}
	}

	static function formatName(f:String):String return switch (f) {
		case "fnmm": "FNMM (data.json)";
		case "codename": "Codename Engine";
		case "legacy": "Legacy / Psych";
		default: "FMCE";
	}

	function doImport():Void {
		if (result == null) return;
		UIUtil.confirmUISelections(this);
		var r = Charter.instance.replaceNotes(result.lines);
		var msg = TU.translate("charterImport.done", ["" + r.created]);
		if (r.skipped > 0) msg += "\n" + TU.translate("charterImport.skippedLines", ["" + r.skipped]);
		if (result.scrollSpeed != null) msg += "\n" + TU.translate("charterImport.speedNote", ["" + result.scrollSpeed, "" + PlayState.SONG.scrollSpeed]);
		info.text = msg;
		result = null; // ya aplicado: evita importar dos veces sin querer
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		importButton.selectable = result != null;
	}
}
