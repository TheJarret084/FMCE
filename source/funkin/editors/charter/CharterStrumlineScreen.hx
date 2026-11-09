package funkin.editors.charter;

import funkin.backend.chart.Chart;
import funkin.backend.chart.ChartData.ChartStrumLine;
import funkin.game.Character;
import funkin.game.HealthIcon;
import haxe.io.Path;

/** Ventana de strumline del charter de FMCE. */
class CharterStrumlineScreen extends UISubstateWindow {
	public var strumLineID:Int = -1;
	public var strumLine:ChartStrumLine;

	public var vocalsSuffixDropDown:UIDropDown;

	public var saveButton:UIButton;
	public var closeButton:UIButton;

	private var onSave:ChartStrumLine -> Void = null;

	public function new(strumLineID:Int, strumLine:ChartStrumLine, ?onSave:ChartStrumLine->Void) {
		super();
		this.strumLineID = strumLineID;
		this.strumLine = strumLine;
		if (onSave != null) this.onSave = onSave;
	}

	public override function create() {
		var creatingStrumLine:Bool = strumLine == null;

		if (creatingStrumLine)
			strumLine = {
				characters: [Flags.DEFAULT_OPPONENT],
				type: OPPONENT,
				notes: [],
				position: "dad",
				visible: true,
				keyCount: 4
			};

		winTitle = TU.translate("charterStrumlineScreen.win-title" + (creatingStrumLine ? "-creating" : "-editing"), ["#" + strumLineID]);
		winWidth = 420; winHeight = 240;

		// sin musica/voces (nivel sin audio) no hay nada que pausar
		if (FlxG.sound.music != null) FlxG.sound.music.pause();
		if (Charter.instance.vocals != null) Charter.instance.vocals.pause();
		for (strumLine in Charter.instance.strumLines.members) if (strumLine.vocals != null) strumLine.vocals.pause();

		super.create();

		var title:UIText;
		add(title = new UIText(windowSpr.x + 20, windowSpr.y + 30 + 16, 0, TU.translate("charterStrumlineScreen.title" + (creatingStrumLine ? "-creating" : "-editing")), 28));

		// Voices<sufijo>.ogg en <nivel>/music (o en la raiz del nivel)
		var suffixList = ["NONE"];
		#if sys
		for (dir in [Path.join([Chart.levelDir, "music"]), Chart.levelDir]) {
			if (!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir)) continue;
			for (file in sys.FileSystem.readDirectory(dir)) {
				if (!StringTools.startsWith(file, "Voices")) continue;
				var suffix = Path.withoutExtension(file.substr("Voices".length));
				if (suffix == "") continue;
				suffixList.pushOnce(suffix);
			}
		}
		#end
		var current = strumLine.vocalsSuffix;
		if (current != null && current != "") suffixList.pushOnce(current);
		var currentIndex = current != null && current != "" ? suffixList.indexOf(current) : 0;

		vocalsSuffixDropDown = new UIDropDown(windowSpr.x + 20, title.y + title.height + 40, 200, 32, suffixList, currentIndex);
		add(vocalsSuffixDropDown);
		add(new UIText(vocalsSuffixDropDown.x, vocalsSuffixDropDown.y - 24, 0, TU.translate("charterStrumLine.vocalSuffix")));

		saveButton = new UIButton(windowSpr.x + windowSpr.bWidth - 20 - 125, windowSpr.y + windowSpr.bHeight - 16 - 32, TU.translate("editor.saveClose"), function() {
			saveStrumline();
			for (e in Charter.instance.eventsGroup.members) e.refreshEventIcons();
			close();
		}, 125);
		add(saveButton);

		closeButton = new UIButton(saveButton.x - 20 - saveButton.bWidth, saveButton.y, TU.translate("editor." + (creatingStrumLine ? "cancel" : "close")), function() {
			if (creatingStrumLine && onSave != null) onSave(null);
			close();
		}, 125);
		add(closeButton);
		closeButton.color = 0xFFFF0000;
	}

	function saveStrumline() {
		UIUtil.confirmUISelections(this);

		// se conserva todo lo que ya traia la strumline; solo cambia el sufijo de voces
		var picked = vocalsSuffixDropDown.options[vocalsSuffixDropDown.index];
		var newStrumLine:ChartStrumLine = Reflect.copy(strumLine);
		newStrumLine.vocalsSuffix = picked != "NONE" ? picked : "";
		if (onSave != null) onSave(newStrumLine);
	}
}

class CharacterButton extends UIButton {
	public var charIcon:HealthIcon;
	public var textBox:UIAutoCompleteTextBox;
	public var deleteButton:UIButton;
	public var deleteIcon:FlxSprite;

	public function new(x:Float, y:Float, char:String, charsList:Array<String>, parent:UIButtonList<CharacterButton>) {
		super(x, y, null, null, 250, 54);

		charIcon = new HealthIcon(Character.getIconFromCharName(char));
		var size = Std.int(150 * 0.3);
		charIcon.setUnstretchedGraphicSize(size, size, true);
		charIcon.updateHitbox();
		charIcon.setPosition(x + 10, bHeight/2 - charIcon.height / 2);
		charIcon.scrollFactor.set(1,1);

		members.push(charIcon);

		members.push(textBox = new UIAutoCompleteTextBox(charIcon.x + charIcon.width + 16, bHeight/2 - (32/2), char, 115));
		textBox.suggestItems = charsList;
		textBox.antialiasing = true;
		textBox.onChange = function(char:String) {
			char = Character.getIconFromCharName(char);
			charIcon.setIcon(char);
			charIcon.setUnstretchedGraphicSize(size, size, true);
			charIcon.updateHitbox();
			charIcon.setPosition(x + 10, bHeight/2 - charIcon.height / 2);
		}

		deleteButton = new UIButton(textBox.x + 115 + 16, bHeight/2 - (32/2), null, function () {
			parent.remove(this);
		}, 32);
		deleteButton.color = 0xFFFF0000;
		deleteButton.autoAlpha = false;
		members.push(deleteButton);

		deleteIcon = new FlxSprite(deleteButton.x + (15/2), deleteButton.y + 8).loadGraphic(Paths.image('editors/delete-button'));
		deleteIcon.antialiasing = false;
		members.push(deleteIcon);
	}

	override function update(elapsed) {
		charIcon.y = y + bHeight / 2 - charIcon.height / 2;
		deleteButton.y = y + bHeight / 2 - deleteButton.bHeight / 2;
		textBox.y = y + bHeight/2 - 16;
		deleteIcon.x = deleteButton.x + (15/2); deleteIcon.y = deleteButton.y + 8;

		deleteButton.selectable = selectable;
		deleteButton.shouldPress = shouldPress;

		super.update(elapsed);
	}
}
