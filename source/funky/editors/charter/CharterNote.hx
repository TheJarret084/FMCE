package funky.editors.charter;

import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funky.backend.system.Conductor;
import funky.editors.charter.Charter.ICharterSelectable;

class CharterNote extends UISprite implements ICharterSelectable {
	var angleTween:FlxTween;
	var __doAnim:Bool = false;
	var __animSpeed:Float = 1;
	var __susInstaLerp:Bool = false;

	private static var colors:Array<FlxColor> = [
		0xFFC24B99,
		0xFF00FFFF,
		0xFF12FA05,
		0xFFF9393F
	];

	public var sustainSpr:UISprite;
	public var tempSusLength:Float = 0;
	public var sustainDraggable:Bool = false;

	/** Texto "P/M" que se dibuja encima de la nota: P = onPress, M = onMiss. 0 = sin pack, N = pack #N (1-based). */
	public var packText:UIText;

	public var selected:Bool = false;
	public var draggable:Bool = true;

	static var packTexts:Map<String, UIText> = new Map<String, UIText>();

	public function new() {
		super();

		antialiasing = true; ID = -1;
		var notePath = Paths.image('editors/charter/note');
		if (Assets.exists(notePath)) loadGraphic(notePath, true, 157, 154);
		else loadGraphic(getFallbackGraphic(), true, 157, 154);
		animation.add("note", [for(i in 0...frames.frames.length) i], 0, true);
		animation.play("note");
		this.setUnstretchedGraphicSize(40, 40, false);

		sustainSpr = new UISprite(10, 20);
		sustainSpr.makeSolid(1, 1, -1, false, "note-sustain");
		sustainSpr.scale.set(10, 0);
		members.push(sustainSpr);

		refreshPackText();

		cursor = sustainSpr.cursor = CLICK;
		moves = false;
	}

	static function getFallbackGraphic():flixel.graphics.FlxGraphic {
		var key = "__charter_note_fallback";
		var cached = FlxG.bitmap.get(key);
		if (cached != null) return cached;
		var bmp = new openfl.display.BitmapData(157 * 4, 154, true, 0);
		for (i in 0...4)
			bmp.fillRect(new openfl.geom.Rectangle(i * 157 + 8, 8, 141, 138), colors[i]);
		return FlxG.bitmap.add(bmp, false, key);
	}

	public override function updateButtonHandler() {
		__rect.set(x, y, 40, 40);
		UIState.state.updateRectButtonHandler(this, __rect, onHovered);
	}

	public var step:Float;
	public var id:Int;
	public var susLength:Float;

	public var onPress(default, set):Int = -1;
	public var onMiss(default, set):Int = -1;

	public var packVisible:Bool = true;
	public var packAlpha:Float = 1;

	function set_onPress(v:Int):Int {
		onPress = v < -1 ? -1 : v;
		refreshPackText();
		return onPress;
	}

	function set_onMiss(v:Int):Int {
		onMiss = v < -1 ? -1 : v;
		refreshPackText();
		return onMiss;
	}

	/** Los packs se guardan 0-based (-1 = ninguno) pero en el charter se ven 1-based para que "ninguno" sea 0: 0/0 = sin press ni miss. */
	public static inline function packLabel(press:Int, miss:Int):String
		return (press + 1) + "/" + (miss + 1);

	function refreshPackText():Void {
		var label = packLabel(onPress, onMiss);
		var cached = packTexts.get(label);
		if (cached == null || cached.graphic == null || cached.graphic.isDestroyed) {
			cached = new UIText(x, y, 0, label, 12);
			packTexts.set(label, cached);
		}
		packText = cached;
	}

	public var strumLine:CharterStrumline;
	public var strumLineID(get, default):Int = -1;
	public function get_strumLineID():Int
		return strumLineID = (strumLine == null ? strumLineID : Charter.instance.strumLines.members.indexOf(strumLine));

	public var snappedToGrid:Bool = true;

	public var fullID(get, never):Int;
	public function get_fullID():Int
		return strumLine.startingID + id;

	public function updatePos(step:Float, id:Int, susLength:Float = 0, ?strumLine:CharterStrumline = null) {
		this.step = step;
		this.id = id;
		this.susLength = Math.max(susLength, 0);
		if (strumLine != null) this.strumLine = strumLine;

		sustainSpr.exists = susLength != 0;

		y = step * 40;

		if (angleTween != null) angleTween.cancel();

		var destAngle:Float = switch(animation.curAnim.curFrame = (id % 4)) {
			case 0: 270;
			case 1: 180;
			case 2: 0;
			case 3: 90;
			default: 0;
		};

		sustainSpr.color = colors[animation.curAnim.curFrame];

		if (!__doAnim) {
			angle = destAngle;
			return;
		}

		if (angle == destAngle) return;

		if(angleTween != null)
			angleTween.cancel();

		destAngle = CoolUtil.getClosestAngle(angle, destAngle);

		angleTween = FlxTween.angle(this, angle, destAngle, (2/3)/__animSpeed, {ease: function(t) {
			return ((Math.sin(t * Math.PI) * 0.35) * 3 * t * Math.sqrt(1 - t)) + t;
		}});
	}

	public override function kill() {
		if (angleTween != null) {
			angleTween.cancel();
			angleTween = null;
			angle = switch(animation.curAnim.curFrame = (id % 4)) {
				case 0: 270;
				case 1: 180;
				case 2: 0;
				case 3: 90;
				default: 0;
			};
			__doAnim = false;
		}
		super.kill();
	}

	var __passed:Bool = false;
	public override function update(elapsed:Float) {
		super.update(elapsed);

		if(susLength != 0) {
			var sprLength:Float = (40 * (susLength+tempSusLength)) + ((susLength+tempSusLength) != 0 ? (height/2) : 0);
			sustainSpr.scale.set(10, __susInstaLerp ? sprLength : CoolUtil.fpsLerp(sustainSpr.scale.y, sprLength, 1/2));
			sustainSpr.updateHitbox();
			sustainSpr.follow(this, 15, 20);
		}

		sustainDraggable = false;
		if (!hovered && susLength != 0) {
			sustainSpr.updateSpriteRect();
			sustainDraggable = UIState.state.isOverlapping(sustainSpr, @:privateAccess sustainSpr.__rect);
		}

		if (__passed != (__passed = step < Conductor.curStepFloat + (Options.songOffsetAffectEditors ? (Conductor.songOffset / Conductor.stepCrochet) : 0))) {
			if (__passed && FlxG.sound.music.playing) {
				Charter.instance.playHitsound(strumLineID);
			}
		}

		if (strumLine != null) {
			var isVisible = strumLine.strumLine.visible;
			sustainSpr.alpha = alpha = !isVisible ? (__passed ? 0.2 : 0.4) : (__passed ? 0.6 : 1);
			packAlpha = !isVisible ? (__passed ? 0.4 : 0.6) : (__passed ? 0.8 : 1);
		}

		colorTransform.redMultiplier = colorTransform.greenMultiplier = colorTransform.blueMultiplier = selected ? 0.75 : 1;
		colorTransform.redOffset = colorTransform.greenOffset = selected ? 96 : 0;
		colorTransform.blueOffset = selected ? 168 : 0;

		__doAnim = true;
	}

	public function handleSelection(selectionBox:UISliceSprite):Bool {
		var minX = Std.int(selectionBox.x / 40);
		var minY = (selectionBox.y / 40) - 1;
		var maxX = Std.int(Math.ceil((selectionBox.x + selectionBox.bWidth) / 40));
		var maxY = ((selectionBox.y + selectionBox.bHeight) / 40);

		return this.fullID >= minX && this.fullID < maxX && this.step >= minY && this.step < maxY;
	}

	public function handleDrag(change:FlxPoint) {
		var newStep = CoolUtil.bound(step + change.x, 0, Charter.instance.__endStep-1);
		var newID:Int = Std.int(FlxMath.bound(fullID + Std.int(change.y), 0, Charter.instance.strumLines.totalKeyCount-1));
		var newStrumLine = Charter.instance.strumLines.getStrumlineFromID(newID);

		updatePos(newStep, (newID - newStrumLine.startingID) % newStrumLine.keyCount, susLength, newStrumLine);
	}

	public override function draw() {
		if (snappedToGrid)
			x = (strumLine != null ? strumLine.x : 0) + (id % (strumLine != null ? strumLine.keyCount : 4)) * 40;

		drawMembers();
		drawSuper();
		drawPackText();
	}

	public inline function drawPackText() {
		if (packText != null && packText.exists && packText.visible && packVisible) {
			packText.alpha = packAlpha;
			packText.follow(this, 20 - (packText.frameWidth / 2), -packText.frameHeight - 1);
			packText.draw();
		}
	}
}
