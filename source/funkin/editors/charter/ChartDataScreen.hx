package funkin.editors.charter;

import flixel.math.FlxPoint;
import funkin.backend.chart.ChartData.ChartMetaData;
import funkin.backend.chart.ChartData;
import funkin.game.Stage;

using StringTools;

class ChartDataScreen extends UISubstateWindow {
	public var data:ChartData;
	public var saveButton:UIButton;
	public var closeButton:UIButton;

	public var stageTextBox:UIAutoCompleteTextBox;

	public function new(data:ChartData) {
		super();
		this.data = data;
	}

	public override function create() {
		Charter.pauseAudio();

		winTitle = TU.translate("chartDataScreen.title");
		winWidth = 420; winHeight = 230; // guys look, the funny numbers!

		super.create();

		function addLabelOn(ui:UISprite, text:String)
			add(new UIText(ui.x, ui.y - 24, 0, text));

		var title:UIText;
		add(title = new UIText(windowSpr.x + 20, windowSpr.y + 30 + 16, 0, TU.translate("chartDataScreen.editChartData"), 28));

		var stageFileList = Stage.getList(true);
		if (stageFileList.length == 0) stageFileList = Stage.getList(false);

		stageTextBox = new UIAutoCompleteTextBox(title.x, title.y + title.height + 38, PlayState.SONG.stage, 200);
		stageTextBox.suggestItems = stageFileList;
		add(stageTextBox);
		addLabelOn(stageTextBox, TU.translate("chartDataScreen.stage"));

		saveButton = new UIButton(windowSpr.x + windowSpr.bWidth - 20 - 125, windowSpr.y + windowSpr.bHeight - 16 - 32, TU.translate("editor.saveClose"), function() {
			saveInfo();
			close();
		}, 125);
		add(saveButton);

		closeButton = new UIButton(saveButton.x - 20, saveButton.y, TU.translate("editor.close"), function() {
			close();
		}, 125);
		add(closeButton);
		closeButton.color = 0xFFFF0000;
		closeButton.x -= closeButton.bWidth;
	}

	public function saveInfo() {
		UIUtil.confirmUISelections(this);

		var oldData:{stage:String} = {stage: PlayState.SONG.stage};

		PlayState.SONG.stage = stageTextBox.label.text;

		Charter.undos.addToUndo(CEditChartData(oldData, {stage: stageTextBox.label.text}));
	}
}