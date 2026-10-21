package funkin.editors.charter;

import funkin.backend.chart.ChartData.ChartMetaData;

/**
 * Datos del nivel que se guardan en `meta.json`: nombre a mostrar, bpm, compas y color de la tarjeta.
 * (Dificultades, modos, iconos y valores custom ya no existen: la dificultad es la velocidad de scroll
 * y los iconos viven en `meta.icons`.)
 */
class CharterMetaDataScreen extends UISubstateWindow {
	public var metadata:ChartMetaData;
	public var saveButton:UIButton;
	public var closeButton:UIButton;

	public var displayNameTextBox:UITextBox;
	public var bpmStepper:UINumericStepper;
	public var beatsPerMeasureStepper:UINumericStepper;
	public var denominatorStepper:UINumericStepper;
	public var needsVoicesCheckbox:UICheckbox;
	public var colorWheel:UIColorwheel;

	public function new(metadata:ChartMetaData) {
		super();
		this.metadata = metadata;
	}

	inline function translate(id:String):String
		return TU.translate("charterMetaDataScreen." + id);

	public override function create() {
		funky.core.Log.info('[CharterMetaDataScreen] create: inicio');
		winTitle = translate("title");
		winWidth = 700;
		winHeight = 390;

		super.create();

		Charter.pauseAudio();

		function addLabelOn(ui:UISprite, text:String)
			add(new UIText(ui.x, ui.y - 24, 0, text));

		var title:UIText;
		add(title = new UIText(windowSpr.x + 20, windowSpr.y + 30 + 16, 0, translate("songData"), 28));

		var row1:Float = title.y + title.height + 36;
		var row2:Float = row1 + 78;

		displayNameTextBox = new UITextBox(title.x, row1, metadata.displayName);
		add(displayNameTextBox);
		addLabelOn(displayNameTextBox, translate("displayName"));

		bpmStepper = new UINumericStepper(displayNameTextBox.x + 320 + 26, row1, metadata.bpm, 1, 2, 1, null, 90);
		add(bpmStepper);
		addLabelOn(bpmStepper, translate("bpm"));

		beatsPerMeasureStepper = new UINumericStepper(title.x, row2, metadata.beatsPerMeasure, 1, 0, 1, null, 54);
		add(beatsPerMeasureStepper);
		addLabelOn(beatsPerMeasureStepper, translate("timeSignature"));

		add(new UIText(beatsPerMeasureStepper.x + 30, beatsPerMeasureStepper.y + 3, 0, "/", 22));

		denominatorStepper = new UINumericStepper(beatsPerMeasureStepper.x + 30 + 24, row2, Math.floor(16 / metadata.stepsPerBeat), 1, 0, 1, null, 54);
		add(denominatorStepper);

		needsVoicesCheckbox = new UICheckbox(beatsPerMeasureStepper.x, row2 + 32 + 26, translate("needsVoices"), metadata.needsVoices);
		add(needsVoicesCheckbox);

		colorWheel = new UIColorwheel(bpmStepper.x, row2, metadata.color);
		add(colorWheel);
		addLabelOn(colorWheel, translate("color"));

		saveButton = new UIButton(windowSpr.x + windowSpr.bWidth - 20, windowSpr.y + windowSpr.bHeight - 20, TU.translate("editor.saveClose"), function() {
			saveMeta();
			close();
		}, 125);
		saveButton.x -= saveButton.bWidth;
		saveButton.y -= saveButton.bHeight;

		closeButton = new UIButton(saveButton.x - 20, saveButton.y, TU.translate("editor.close"), function() {
			close();
		}, 125);
		closeButton.color = 0xFFFF0000;
		closeButton.x -= closeButton.bWidth;
		add(closeButton);
		add(saveButton);
		funky.core.Log.info('[CharterMetaDataScreen] create: listo');
	}

	public function saveMeta() {
		UIUtil.confirmUISelections(this);

		var meta = PlayState.SONG.meta;
		meta.bpm = bpmStepper.value;
		meta.needsVoices = needsVoicesCheckbox.checked;
		meta.beatsPerMeasure = Std.int(beatsPerMeasureStepper.value);
		meta.stepsPerBeat = Std.int(16 / denominatorStepper.value);
		meta.displayName = displayNameTextBox.label.text;
		meta.color = colorWheel.curColor;

		Charter.instance.updateBPMEvents();
		if (Charter.instance.vocals != null) Charter.instance.vocals.volume = needsVoicesCheckbox.checked ? 1 : 0;
	}
}
