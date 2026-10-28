package funkin.editors.charter;

import funkin.backend.chart.Chart;
import funkin.backend.chart.ChartImporter;
import funkin.backend.chart.FnfcPackage;
import haxe.io.Bytes;
import haxe.io.Path;

/**
 * Importa las notas de un chart de FNMM (data.json), Codename, Legacy/Psych (o FMCE) y reemplaza las del chart abierto.
 * Tambien abre un `.fnfc` de Friday Night Funkin' (un zip con -chart.json, -metadata.json y los .ogg): se elige la dificultad,
 * se ajusta el BPM del nivel y se puede copiar Inst y Voices a `music/`.
 * Un nivel de FMCE tiene un solo chart (`chart.json`): importar reemplaza sus notas, sin dificultades.
 */
class CharterImportScreen extends UISubstateWindow {
	public var explorer:UIFileExplorer;
	public var info:UIText;
	public var importButton:UIButton;
	public var closeButton:UIButton;

	var result:ImportResult = null;
	var pack:Null<FnfcPackage> = null;
	var rawText:String = null;
	var diffLabel:UIText;
	var diffDrop:UIDropDown;
	var audioCheck:UICheckbox;

	public function new() {
		super();
	}

	public override function create() {
		winTitle = TU.translate("charterImport.win-title");
		winWidth = 560; winHeight = 500;
		super.create();

		var title:UIText;
		add(title = new UIText(windowSpr.x + 20, windowSpr.y + 30 + 16, 0, TU.translate("charterImport.title"), 28));

		explorer = new UIFileExplorer(title.x, title.y + title.height + 20, 320, 58, "json;fnfc", onFile);
		add(explorer);

		info = new UIText(title.x, explorer.y + explorer.bHeight + 20, windowSpr.bWidth - 40, TU.translate("charterImport.pickFile"), 14);
		add(info);

		// solo para .fnfc: dificultad y audio
		diffLabel = new UIText(title.x, windowSpr.y + 318, 0, "Dificultad (.fnfc)", 14);
		diffDrop = new UIDropDown(title.x, diffLabel.y + 22, 200, 32, ["-"], 0);
		diffDrop.onChange = function(i:Int) {
			if (result != null && result.difficulties != null && i >= 0 && i < result.difficulties.length) parseNow(result.difficulties[i]);
		};
		var hasMusic = Chart.musicPath != null;
		audioCheck = new UICheckbox(title.x, diffDrop.y + 44, "Copiar Inst y Voices a music/" + (hasMusic ? " (reemplaza el audio actual)" : ""), !hasMusic);
		add(audioCheck);
		add(diffDrop);
		add(diffLabel);
		showPackageControls(false);

		importButton = new UIButton(windowSpr.x + windowSpr.bWidth - 20 - 125, windowSpr.y + windowSpr.bHeight - 16 - 32, TU.translate("charterImport.import"), doImport, 125);
		add(importButton);
		closeButton = new UIButton(importButton.x - 20 - 125, importButton.y, TU.translate("editor.close"), function() close(), 125);
		closeButton.color = 0xFFFF0000;
		add(closeButton);
	}

	function showPackageControls(on:Bool):Void {
		diffLabel.exists = diffDrop.exists = audioCheck.exists = on;
	}

	function onFile(path:String, bytes:Bytes):Void {
		result = null;
		pack = null;
		rawText = null;
		showPackageControls(false);
		if (path == null || bytes == null) {
			info.text = TU.translate("charterImport.pickFile");
			return;
		}
		try {
			if (FnfcPackage.isFnfc(path)) {
				pack = FnfcPackage.read(bytes);
				rawText = pack.chart;
			} else
				rawText = bytes.toString();
			parseNow(null);
			if (pack != null) {
				var diffs = result.difficulties != null ? result.difficulties : [];
				diffDrop.options = diffs.copy();
				diffDrop.items = [for (i => d in diffs) {label: d, value: i}];
				diffDrop.index = Std.int(Math.max(0, diffs.indexOf(result.difficulty)));
				diffDrop.label.text = result.difficulty;
				showPackageControls(true);
				diffLabel.exists = diffDrop.exists = diffs.length > 1;
			}
		} catch (e:Dynamic) {
			result = null;
			info.text = TU.translate("charterImport.error", ["" + e]);
		}
	}

	/** Lee `rawText` (con la dificultad elegida, si es un FNF) y muestra el resumen. */
	function parseNow(difficulty:Null<String>):Void {
		var lanes = 4;
		for (sl in PlayState.SONG.strumLines) if (sl.keyCount != null && sl.keyCount > lanes) lanes = sl.keyCount;
		result = ChartImporter.parse(rawText, lanes, difficulty);
		if (pack != null && pack.bpm != null) result.bpm = pack.bpm;
		var lines = [TU.translate("charterImport.format", [formatName(result.format)]),
			TU.translate("charterImport.summary", ["" + result.notes, "" + result.sustains, "" + result.lines.length])];
		if (result.format == "fnf" && result.difficulty != null) lines.push("Dificultad: " + result.difficulty);
		if (result.droppedLanes > 0) lines.push(TU.translate("charterImport.droppedLanes", ["" + result.droppedLanes, "" + result.lanes]));
		if (result.duplicates > 0) lines.push("Notas repetidas descartadas: " + result.duplicates);
		if (result.droppedEvents > 0) lines.push(TU.translate("charterImport.droppedEvents", ["" + result.droppedEvents]));
		if (result.droppedKinds != null && result.droppedKinds > 0) lines.push("Notas con tipo especial (se importan normales): " + result.droppedKinds);
		if (pack != null) {
			var names = [for (a in pack.audio) a.name];
			lines.push("Audio del paquete: " + (names.length > 0 ? names.join(", ") : "ninguno"));
			if (result.bpm != null) lines.push("BPM del paquete: " + result.bpm + " (se aplica al nivel al importar)");
		} else if (result.bpm != null && PlayState.SONG.meta.bpm != null && Math.abs(result.bpm - PlayState.SONG.meta.bpm) > 0.5)
			lines.push(TU.translate("charterImport.bpmMismatch", ["" + result.bpm, "" + PlayState.SONG.meta.bpm]));
		info.text = lines.join("\n");
	}

	/** Copia Inst/Voices del .fnfc a `<nivel>/music/`. Devuelve cuantos archivos copio. */
	function copyAudio():Int {
		var copied = 0;
		#if sys
		if (pack == null || Chart.levelDir == null) return 0;
		var dir = Path.join([Chart.levelDir, "music"]);
		if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
		for (a in pack.audio) {
			sys.io.File.saveBytes(Path.join([dir, a.target]), a.bytes);
			copied++;
		}
		#end
		return copied;
	}

	static function formatName(f:String):String return switch (f) {
		case "fnmm": "FNMM (data.json)";
		case "codename": "Codename Engine";
		case "legacy": "Legacy / Psych";
		case "fnf": "Friday Night Funkin' (.fnfc)";
		default: "FMCE";
	}

	function doImport():Void {
		if (result == null) return;
		UIUtil.confirmUISelections(this);
		var bpmMsg = "";
		if (pack != null && result.bpm != null && PlayState.SONG.meta.bpm != null && Math.abs(result.bpm - PlayState.SONG.meta.bpm) > 0.01) {
			// las notas vienen en ms: con el BPM del paquete caen justo en la rejilla
			PlayState.SONG.meta.bpm = result.bpm;
			Charter.instance.updateBPMEvents();
			bpmMsg = "\nBPM del nivel: " + result.bpm;
		}
		var r = Charter.instance.replaceNotes(result.lines);
		var msg = TU.translate("charterImport.done", ["" + r.created]) + bpmMsg;
		if (pack != null && audioCheck.exists && audioCheck.checked) {
			var n = copyAudio();
			if (n > 0) msg += "\nAudio copiado a music/ (" + n + "). Reabre el nivel para oirlo; las voces se asignan en cada strumline.";
		}
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
