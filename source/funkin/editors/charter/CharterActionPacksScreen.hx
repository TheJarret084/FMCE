package funkin.editors.charter;

import flixel.math.FlxPoint;
import funkin.backend.chart.ChartData;

/**
 * Editor de `action_packs` de events.json. Un pack es una lista de acciones (las mismas que un evento)
 * que corre el evento `RunActionPack`. Cada pack se edita con la misma pantalla que los eventos.
 */
class CharterActionPacksScreen extends UISubstateWindow {
	public static inline var WIN_WIDTH:Int = 440;

	public var packs:Array<ChartActionPack> = [];
	public var packsList:UIButtonList<ActionPackButton>;

	public var saveButton:UIButton;
	public var closeButton:UIButton;

	var original:Array<ChartActionPack>;
	var emptyText:UIText;

	public function new() {
		super();
	}

	public override function create() {
		original = PlayState.SONG.actionPacks == null ? [] : PlayState.SONG.actionPacks;
		packs = [for (p in original) copyPack(p)];

		winTitle = TU.translate("charterActionPacks.win-title");
		winWidth = WIN_WIDTH; winHeight = 420;

		super.create();

		var title:UIText;
		add(title = new UIText(windowSpr.x + 20, windowSpr.y + 30 + 16, 0, TU.translate("charterActionPacks.title"), 28));

		packsList = new UIButtonList<ActionPackButton>(15, title.y + title.height + 20, WIN_WIDTH - 30, 250, null, FlxPoint.get(WIN_WIDTH - 50, 40), null, 0);
		packsList.frames = Paths.getFrames('editors/ui/inputbox');
		packsList.cameraSpacing = 0;
		packsList.addButton.callback = () -> {
			packs.push({actions: []});
			addButtonFor(packs[packs.length - 1]);
			editPack(packs[packs.length - 1]);
		};
		for (p in packs) addButtonFor(p);
		add(packsList);

		emptyText = new UIText(packsList.x + 16, packsList.y + 50, packsList.bWidth - 32, TU.translate("charterActionPacks.empty"), 14);
		emptyText.alpha = 0.6;
		add(emptyText);

		saveButton = new UIButton(windowSpr.x + windowSpr.bWidth - 20 - 125, windowSpr.y + windowSpr.bHeight - 16 - 32, TU.translate("editor.saveClose"), function() {
			saveInfo();
			close();
		}, 125);
		add(saveButton);

		closeButton = new UIButton(saveButton.x - 20, saveButton.y, TU.translate("editor.close"), function() close(), 125);
		closeButton.color = 0xFFFF0000;
		closeButton.x -= closeButton.bWidth;
		add(closeButton);
	}

	static function copyPack(p:ChartActionPack):ChartActionPack {
		var c:ChartActionPack = {actions: [for (a in p.actions) copyAction(a)]};
		if (p.name != null) c.name = p.name;
		return c;
	}

	static function copyAction(a:ChartEvent):ChartEvent {
		var c:ChartEvent = {name: a.name, time: a.time, params: a.params.copy()};
		if (a.raw != null) c.raw = a.raw;
		return c;
	}

	function addButtonFor(pack:ChartActionPack):Void {
		var button = new ActionPackButton(pack, this);
		packsList.add(button);
	}

	/** Abre los eventos del pack con la misma ventana que usan los eventos del grid. */
	public function editPack(pack:ChartActionPack):Void {
		var holder = new CharterEvent(0, [for (a in pack.actions) copyAction(a)]);
		var screen = new CharterEventScreenNew(holder);
		screen.onQuit = function(actions:Array<ChartEvent>) {
			pack.actions = actions;
			refreshButtons();
		};
		openSubState(screen);
	}

	public function deletePack(pack:ChartActionPack):Void {
		var index = packs.indexOf(pack);
		if (index < 0) return;
		// borrar un pack corre los indices de los siguientes: solo se permite si nadie apunta a el ni a los que le siguen
		var uses = countReferences(index);
		if (uses > 0) {
			Logs.trace('No se puede borrar el pack #$index: $uses accion(es) RunActionPack apuntan a el o a uno posterior. Cambialas antes.', WARNING);
			return;
		}
		packs.splice(index, 1);
		for (b in packsList.buttons.members.copy()) if (b != null && b.pack == pack) packsList.remove(b);
		refreshButtons();
	}

	function refreshButtons():Void {
		for (b in packsList.buttons.members) if (b != null) b.refreshLabel(packs.indexOf(b.pack));
	}

	/** Cuantas acciones `RunActionPack` (en eventos o en otros packs) apuntan al pack `index` o a uno posterior. */
	function countReferences(index:Int):Int {
		var n = 0;
		function check(e:ChartEvent) if (e.name == "RunActionPack" && e.params.length > 0 && Std.int(e.params[0]) >= index) n++;
		for (e in Charter.instance.eventsGroup.members) for (a in e.events) check(a);
		for (p in packs) for (a in p.actions) check(a);
		return n;
	}

	public function saveInfo():Void {
		UIUtil.confirmUISelections(this);
		var old = original;
		var neu = [for (p in packs) copyPack(p)];
		PlayState.SONG.actionPacks = neu;
		Charter.undos.addToUndo(CEditActionPacks(old, [for (p in neu) copyPack(p)]));
		Charter.instance.buildEvents();
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		emptyText.visible = packs.length == 0;
	}
}

class ActionPackButton extends UIButton {
	public var pack:ChartActionPack;
	public var deleteButton:UIButton;
	public var deleteIcon:FlxSprite;

	public function new(pack:ChartActionPack, screen:CharterActionPacksScreen) {
		this.pack = pack;
		super(0, 0, "", function() screen.editPack(pack), CharterActionPacksScreen.WIN_WIDTH - 50, 40);
		autoAlpha = false;
		field.alignment = LEFT;
		field.fieldWidth = 0;
		refreshLabel(screen.packs.indexOf(pack));

		deleteButton = new UIButton(bWidth - 34, y + 7, null, function() screen.deletePack(pack), 26, 26);
		deleteButton.color = 0xFFFF0000;
		deleteButton.autoAlpha = false;
		members.push(deleteButton);

		deleteIcon = new FlxSprite(deleteButton.x + 5, deleteButton.y + 4).loadGraphic(Paths.image('editors/delete-button'));
		deleteIcon.antialiasing = false;
		members.push(deleteIcon);
	}

	public function refreshLabel(index:Int):Void {
		var name = pack.name != null && pack.name != "" ? ' ${pack.name}' : "";
		field.text = TU.translate("charterActionPacks.packLabel", ["" + index, "" + pack.actions.length]) + name;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		field.follow(this, 12, (bHeight - field.height) / 2);
		deleteButton.selectable = selectable;
		deleteButton.shouldPress = shouldPress;
		deleteButton.setPosition(x + (bWidth - 34), y + (bHeight - 26) / 2);
		deleteIcon.setPosition(deleteButton.x + 5, deleteButton.y + 4);
	}
}
