package funky.advanced;

import flixel.group.FlxGroup;
import funky.advanced.AdvLang;
import funky.editors.ui.*;
import funky.backend.LevelCreator;

/**
 * Asistente NUEVO NIVEL inspirado en el flujo original de Codename:
 * 1) datos de la cancion y seleccion de audio;
 * 2) metadatos del menu, icono, modos, dificultades y color.
 * Los datos se guardan en el formato nativo de FMCE (meta.json + chart.json).
 */
class LevelCreateScreen extends UISubstateWindow
{
	var onCreated:String->Void;

	var songPage:FlxGroup;
	var menuPage:FlxGroup;
	var pageTitle:UIText;
	var error:UIText;

	var songNameBox:UITextBox;
	var bpmStepper:UINumericStepper;
	var beatsPerMeasureStepper:UINumericStepper;
	var denominatorStepper:UINumericStepper;
	var instrumentalExplorer:UIFileExplorer;
	var voicesExplorer:UIFileExplorer;
	var instrumentalInfo:UIText;
	var voicesInfo:UIText;
	var importExplorer:UIFileExplorer;
	var importInfo:UIText;
	var importResult:Null<funky.backend.chart.ChartImporter.ImportResult> = null;

	var displayNameBox:UITextBox;
	var iconBox:UITextBox;
	var opponentModeCheck:UICheckbox;
	var coopCheck:UICheckbox;
	var stageBox:UITextBox;
	var lanesStepper:UINumericStepper;
	var difficultiesBox:UITextBox;
	var colorWheel:UIColorwheel;
	var spritesCheck:UICheckbox;

	var cancelButton:UIButton;
	var nextButton:UIButton;
	var backButton:UIButton;
	var createButton:UIButton;
	var currentPage:Int = 0;

	public function new(onCreated:String->Void)
	{
		super();
		this.onCreated = onCreated;
	}

	public override function create():Void
	{
		winTitle = AdvLang.t("levelCreate.title", null, "Nuevo nivel");
		winWidth = 760;
		winHeight = 640;
		super.create();

		var x = windowSpr.x + 22;
		var y = windowSpr.y + 62;
		var right = windowSpr.x + windowSpr.bWidth - 22;

		songPage = new FlxGroup();
		menuPage = new FlxGroup();
		add(songPage);
		add(menuPage);

		// PAGINA 1 — Datos principales y archivos de audio.
		pageTitle = new UIText(x, y, 700, "Datos de la canción  ·  1/2", 25, 0xFF5FE36B);
		songPage.add(pageTitle);

		songPage.add(new UIText(x, y + 54, 0, "Nombre interno de la canción", 14));
		songNameBox = new UITextBox(x, y + 77, "", 365, 34);
		songPage.add(songNameBox);

		var bpmX = x + 390;
		songPage.add(new UIText(bpmX, y + 54, 0, "BPM", 14));
		bpmStepper = new UINumericStepper(bpmX, y + 77, LevelCreator.DEFAULT_BPM, 1, 2, 1, 1000, 125, 34);
		songPage.add(bpmStepper);

		var signatureX = x + 535;
		songPage.add(new UIText(signatureX, y + 54, 0, "Compás", 14));
		beatsPerMeasureStepper = new UINumericStepper(signatureX, y + 77, 4, 1, 0, 1, 32, 74, 34);
		songPage.add(beatsPerMeasureStepper);
		songPage.add(new UIText(signatureX + 48, y + 82, 0, "/", 21));
		denominatorStepper = new UINumericStepper(signatureX + 67, y + 77, 4, 1, 0, 1, 16, 74, 34);
		songPage.add(denominatorStepper);

		var audioY = y + 166;
		songPage.add(new UIText(x, audioY, 330, "Instrumental  ·  obligatorio", 17));
		songPage.add(new UIText(x + 360, audioY, 330, "Voces  ·  opcional", 17));

		instrumentalExplorer = new UIFileExplorer(x, audioY + 30, 330, 66, "ogg;mp3;wav;m4a", function(path:String, bytes:haxe.io.Bytes)
		{
			instrumentalInfo.text = path == null ? "Sin instrumental seleccionado" : "Seleccionado: " + haxe.io.Path.withoutDirectory(path);
		});
		songPage.add(instrumentalExplorer);
		voicesExplorer = new UIFileExplorer(x + 360, audioY + 30, 330, 66, "ogg;mp3;wav;m4a", function(path:String, bytes:haxe.io.Bytes)
		{
			voicesInfo.text = path == null ? "Sin voces (opcional)" : "Seleccionado: " + haxe.io.Path.withoutDirectory(path);
		});
		songPage.add(voicesExplorer);

		instrumentalInfo = new UIText(x, audioY + 105, 330, "Sin instrumental seleccionado", 12);
		instrumentalInfo.alpha = 0.72;
		songPage.add(instrumentalInfo);
		voicesInfo = new UIText(x + 360, audioY + 105, 330, "Sin voces (opcional)", 12);
		voicesInfo.alpha = 0.72;
		songPage.add(voicesInfo);

		songPage.add(new UIText(x, audioY + 153, 700,
			"Los archivos se copian dentro de music/ como Inst y Voices. Puedes cambiar el audio después desde el nivel.", 13));

		// Importar chart (opcional): .json de FNF / Psych / Codename / FNMM o un .fnfc. Si el paquete trae audio, se usa como Inst y Voices.
		songPage.add(new UIText(x, audioY + 186, 700, "Importar chart  ·  opcional (.json, .fnfc)", 17));
		importExplorer = new UIFileExplorer(x, audioY + 216, 330, 50, "json;fnfc", onImportFile);
		songPage.add(importExplorer);
		importInfo = new UIText(x + 345, audioY + 216, 350, "Sin chart: el nivel se crea vacío. Un .fnfc trae su audio y se usa solo.", 12);
		importInfo.alpha = 0.72;
		songPage.add(importInfo);

		// PAGINA 2 — Metadatos y opciones que aparecen en los menus.
		menuPage.add(new UIText(x, y, 700, "Opciones del menú  ·  2/2", 25, 0xFF5FE36B));

		menuPage.add(new UIText(x, y + 54, 0, "Nombre visible", 14));
		displayNameBox = new UITextBox(x, y + 77, "", 335, 34);
		menuPage.add(displayNameBox);

		var iconX = x + 365;
		menuPage.add(new UIText(iconX, y + 54, 0, "Icono de salud (P2)", 14));
		iconBox = new UITextBox(iconX, y + 77, "face", 300, 34);
		menuPage.add(iconBox);

		opponentModeCheck = new UICheckbox(x, y + 132, "Permitir modo oponente", false, 310);
		menuPage.add(opponentModeCheck);
		coopCheck = new UICheckbox(iconX, y + 132, "Permitir modo cooperativo", false, 310);
		menuPage.add(coopCheck);

		menuPage.add(new UIText(x, y + 179, 0, "Escenario", 14));
		stageBox = new UITextBox(x, y + 202, LevelCreator.DEFAULT_STAGE, 335, 34);
		menuPage.add(stageBox);
		menuPage.add(new UIText(iconX, y + 179, 0, "Carriles", 14));
		lanesStepper = new UINumericStepper(iconX, y + 202, LevelCreator.DEFAULT_LANES, 1, 0, 1, 9, 105, 34);
		menuPage.add(lanesStepper);

		menuPage.add(new UIText(x, y + 258, 0, "Dificultades (separadas por coma)", 14));
		difficultiesBox = new UITextBox(x, y + 282, "normal", 335, 34);
		menuPage.add(difficultiesBox);
		spritesCheck = new UICheckbox(x, y + 333, "Copiar la plantilla de ejemplo (escenario y sprites)", true, 360);
		menuPage.add(spritesCheck);

		menuPage.add(new UIText(iconX, y + 258, 0, "Color del nivel", 14));
		colorWheel = new UIColorwheel(iconX, y + 282, funky.backend.system.Flags.DEFAULT_COLOR);
		menuPage.add(colorWheel);

		error = new UIText(x, windowSpr.y + winHeight - 76, 710, "", 13);
		error.color = 0xFFFF8A8A;
		add(error);

		var buttonY = windowSpr.y + winHeight - 18 - 34;
		cancelButton = new UIButton(right - 280, buttonY, "Cancelar", function() close(), 130, 34);
		cancelButton.color = 0xFFFF0000;
		add(cancelButton);
		nextButton = new UIButton(right - 140, buttonY, "Continuar  →", goToMenuPage, 140, 34);
		add(nextButton);
		backButton = new UIButton(right - 280, buttonY, "←  Atrás", goToSongPage, 130, 34);
		add(backButton);
		createButton = new UIButton(right - 140, buttonY, "Crear nivel", doCreate, 140, 34);
		createButton.color = 0xFF5FE36B;
		add(createButton);

		showPage(0);
	}

	function onImportFile(path:String, bytes:haxe.io.Bytes):Void
	{
		importResult = null;
		if (path == null || bytes == null)
		{
			importInfo.text = "Sin chart: el nivel se crea vacío. Un .fnfc trae su audio y se usa solo.";
			return;
		}

		try
		{
			var pack:funky.backend.chart.FnfcPackage = null;
			var text:String;
			if (funky.backend.chart.FnfcPackage.isFnfc(path))
			{
				pack = funky.backend.chart.FnfcPackage.read(bytes);
				text = pack.chart;
			}
			else
				text = bytes.toString();

			var res = funky.backend.chart.ChartImporter.parse(text, Std.int(Math.max(1, lanesStepper.value)));
			if (pack != null && pack.bpm != null) res.bpm = pack.bpm;
			importResult = res;

			var lines = [res.notes + " notas, " + res.sustains + " sustains en " + res.lines.length + " strumlines"];
			if (res.bpm != null && res.bpm > 0)
			{
				bpmStepper.value = res.bpm;
				lines.push("BPM: " + res.bpm);
			}

			if (StringTools.trim(songNameBox.label.text) == "")
			{
				var name = pack != null && pack.songName != null && pack.songName != "" ? pack.songName : haxe.io.Path.withoutExtension(haxe.io.Path.withoutDirectory(path));
				songNameBox.label.text = name;
			}

			// Audio del paquete: el "inst" es el instrumental y el primer "voices" las voces (solo si no se eligieron a mano).
			if (pack != null)
			{
				var voices:Null<funky.backend.chart.FnfcPackage.FnfcAudio> = null;
				for (a in pack.audio)
				{
					if (StringTools.startsWith(a.target, "music."))
					{
						if (instrumentalExplorer.file == null) instrumentalExplorer.setFileData(a.name, a.bytes);
					}
					else if (voices == null)
						voices = a;
				}
				if (voices != null && voicesExplorer.file == null) voicesExplorer.setFileData(voices.name, voices.bytes);
				lines.push(pack.audio.length > 0 ? "Audio del paquete cargado (Inst" + (voices != null ? " y Voces" : "") + ")" : "El paquete no trae audio: elige el instrumental.");
			}
			else if (instrumentalExplorer.file == null)
				lines.push("Este formato no trae audio: elige el instrumental para poder escuchar la canción.");

			importInfo.text = lines.join("\n");
		}
		catch (e:Dynamic)
		{
			importResult = null;
			importInfo.text = "No se pudo leer el chart: " + Std.string(e);
		}
	}

	function confirmSelections():Void
	{
		// Las paginas son FlxGroups: confirmUISelections(this) no entra automaticamente en ellos.
		// Confirmarlas por separado asegura que los UINumericStepper apliquen el texto recien escrito.
		if (songPage != null) UIUtil.confirmUISelections(songPage);
		if (menuPage != null) UIUtil.confirmUISelections(menuPage);
		// No dejes el foco apuntando a un campo de la pagina que acabamos de ocultar.
		UIState.state.currentFocus = null;
	}

	function showPage(page:Int):Void
	{
		currentPage = page;
		songPage.visible = songPage.active = page == 0;
		menuPage.visible = menuPage.active = page == 1;
		cancelButton.visible = cancelButton.active = page == 0;
		nextButton.visible = nextButton.active = page == 0;
		backButton.visible = backButton.active = page == 1;
		createButton.visible = createButton.active = page == 1;
		error.text = "";
	}

	function goToMenuPage():Void
	{
		confirmSelections();
		if (songNameBox.label.text == null || StringTools.trim(songNameBox.label.text) == "")
		{
			error.text = "Escribe el nombre interno de la canción.";
			return;
		}
		if (instrumentalExplorer.file == null)
		{
			error.text = "Selecciona el audio instrumental para continuar.";
			return;
		}
		if (StringTools.trim(displayNameBox.label.text) == "")
			displayNameBox.label.text = StringTools.trim(songNameBox.label.text);
		showPage(1);
	}

	function goToSongPage():Void
	{
		confirmSelections();
		showPage(0);
	}

	function doCreate():Void
	{
		confirmSelections();

		var difficulties:Array<String> = [];
		for (part in difficultiesBox.label.text.split(","))
		{
			var value = StringTools.trim(part);
			if (value != "" && difficulties.indexOf(value) < 0) difficulties.push(value);
		}

		var denominator = Std.int(Math.max(1, denominatorStepper.value));
		var stepsPerBeat = Std.int(Math.max(1, Math.min(16, Math.round(16 / denominator))));
		// Sin anotacion: se unifica con LevelCreator.CreateOptions al llamar a createWithOptions.
		var options = {
			songName: StringTools.trim(songNameBox.label.text),
			displayName: StringTools.trim(displayNameBox.label.text),
			bpm: bpmStepper.value,
			beatsPerMeasure: Std.int(beatsPerMeasureStepper.value),
			stepsPerBeat: stepsPerBeat,
			lanes: Std.int(lanesStepper.value),
			stage: stageBox.label.text,
			withSprites: spritesCheck.checked,
			icon: iconBox.label.text,
			color: colorWheel.curColorString,
			difficulties: difficulties,
			opponentModeAllowed: opponentModeCheck.checked,
			coopAllowed: coopCheck.checked,
			instrumentalBytes: instrumentalExplorer.file,
			instrumentalPath: instrumentalExplorer.filePath,
			voicesBytes: voicesExplorer.file,
			voicesPath: voicesExplorer.filePath
		};

		var result = LevelCreator.createWithOptions(options);
		if (!result.ok)
		{
			error.text = result.error;
			return;
		}

		var folder = result.folder;
		// El chart importado se aplica al abrir el charter DE ESTE nivel (no de otro).
		funky.editors.charter.Charter.importOnStart = importResult;
		funky.editors.charter.Charter.importOnStartFolder = importResult != null ? folder : null;
		close();
		if (onCreated != null) onCreated(folder);
	}
}
