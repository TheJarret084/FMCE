package funkin.editors.charter;

class CharterEventAdd extends UISliceSprite {
	var text:UIText;
	public var sprAlpha:Float = 0;
	public var step:Float = 0;

	public var curCharterEvent:CharterEvent = null;

	public function new() {
		super(0, 0, 100, 34, 'editors/charter/event-spr-add');

		flipX = true;

		text = new UIText(0, 0, 0, "");
		members.push(text);

		cursor = CLICK;
	}

	public override function onHovered() {
		super.onHovered();
		if (FlxG.mouse.justReleased && FlxG.state.subState == null) {
			if (curCharterEvent != null)
				Charter.instance.openSubState(new CharterEventScreenNew(curCharterEvent));
			else {
				CharterEventGroup.stopThisFuckingShitDudeIstg = true;
				var chartEvent = new CharterEvent(step, []);

				Charter.instance.createSelection([chartEvent]);
				Charter.instance.openSubState(new CharterEventScreenNew(chartEvent));
				sprAlpha = 0;
				alpha = sprAlpha * 0.75;
				text.alpha = sprAlpha;
			}
		}
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);

		if (FlxG.state.subState != null) return;
		text.follow(this, bWidth - text.width - (text.text == TU.translate("charter.addEvent") ? 15 : 20), (bHeight - text.height) / 2);
		alpha = sprAlpha * 0.75;
		text.alpha = sprAlpha;
	}

	public function updatePos(step:Float) {
		if (FlxG.state.subState != null) return;
		curCharterEvent = null;
		this.step = step;
		this.y = (step * 40) - (bHeight / 2);
		text.text = TU.translate("charter.addEvent");
		framesOffset = 0; bWidth = 37 + Math.ceil(text.width);
		x = eventsX();
	}

	inline function eventsX():Float {
		var last = Charter.instance.strumLines.members[Charter.instance.strumLines.members.length-1];
		return last.x + (40 * last.keyCount);
	}

	public function updateEdit(event:CharterEvent) {
		if (FlxG.state.subState != null) return;
		curCharterEvent = event;
		this.y = event.y;
		text.text = TU.translate("charter.editEvent");
		framesOffset = 9; bWidth = 27 + Math.ceil(text.width) + event.bWidth;
		x = eventsX();
	}
}
