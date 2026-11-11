package funkin.editors.ui;

import funky.core.Log;
import haxe.CallStack;

class UIWarningSubstate extends UISubstateWindow {
	var message:String;
	var buttons:Array<WarningButton>;
	var isError:Bool = true;

	public function new(title:String, message:String, buttons:Array<WarningButton>, ?isError:Bool = true) {
		super();
		this.message = message;
		this.buttons = buttons;
		this.isError = isError;

		winTitle = title;
		winWidth = CoolUtil.maxInt(560, 30 + (170 * buttons.length));
		winHeight = 232;
		winSkin = 'editors/ui/${isError ? "normal" : "grayscale"}-popup';
	}

	public override function create() {

		try {
			build();
		} catch (e:Dynamic) {
			Log.error('[UIWarningSubstate] no se pudo armar el aviso: ' + Std.string(e) + '\n' + CallStack.toString(CallStack.exceptionStack()));
			close();
		}
	}

	function build():Void {
		super.create();

		windowSpr.color = isError ? 0xFFFF0000 : 0xFFFFFF00;

		var sprIcon:FlxSprite = new FlxSprite(windowSpr.x + 18, windowSpr.y + 28 + 26);
		sprIcon.loadGraphic(Paths.image('editors/warnings/${isError ? "error" : "warning"}'));
		sprIcon.scale.set(1.4, 1.4);
		sprIcon.updateHitbox();
		sprIcon.antialiasing = true;
		add(sprIcon);

		var messageSpr = new UIText(sprIcon.x + 70 + 16 + 20, sprIcon.y, windowSpr.bWidth - 100 - (26 * 2), message);
		add(messageSpr);

		windowSpr.bHeight = Std.int(winHeight + Math.abs(Math.min(sprIcon.height - messageSpr.height, 0)));

		var xPos = (windowSpr.bWidth - (30 + (170 * buttons.length))) / 2;
		for (k => b in buttons) {
			var button = new UIButton(windowSpr.x + xPos + 20 + (170 * k), windowSpr.y + windowSpr.bHeight - (36 + 16), b.label, function() {
				b.onClick(this);
				close();
			}, 160, 30);
			if (b.color != null) button.color = b.color;
			add(button);
		}

		UIState.playEditorSound(Flags.DEFAULT_EDITOR_WARNING_SOUND);
	}
}

typedef WarningButton = {
	var label:String;
	var ?color:Int;
	var onClick:UIWarningSubstate->Void;
}
