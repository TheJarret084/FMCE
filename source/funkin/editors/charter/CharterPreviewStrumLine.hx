package funkin.editors.charter;

import funky.core.NoteSkin;
import funkin.game.Note;

class CharterPreviewStrumLine extends FlxTypedGroup<FlxSprite>
{
	public function new(x:Float, y:Float, scale:Float, spacing:Float, keyCount:Int, scrollSpeed:Float){
		super();
		updatePos(x, y, scale, spacing, keyCount, scrollSpeed);
	}

	private var note:FlxSprite;

	public function generateStrums(x:Float, y:Float, scale:Float, spacing:Float, keyCount:Int, scrollSpeed:Float){
		for (member in members){
			member.destroy();
		}
		clear();

		var skin = NoteSkin.current();
		var frames = skin.frames();
		for (i in 0...keyCount){
			var strum = new FlxSprite();
			strum.frames = frames;
			if (strum.frames != null) {
				strum.animation.addByPrefix('static', skin.animFor('receptor', i), 24, false);
				strum.animation.play('static');
			}
			else strum.makeGraphic(Std.int(Note.swagWidth), Std.int(Note.swagWidth), 0xFF808080);
			strum.setGraphicSize(Std.int((strum.width * Flags.DEFAULT_NOTE_SCALE) * scale));
			strum.updateHitbox();
			strum.alpha = 0.4;
			add(strum);
		}

		note = new FlxSprite();
		note.frames = frames;
		if (note.frames != null) {
			note.animation.addByPrefix('note', skin.animFor('note', 0), 24, false);
			note.animation.play('note');
		}
		else note.makeGraphic(Std.int(Note.swagWidth), Std.int(Note.swagWidth), 0xFFC24B99);
		note.setGraphicSize(Std.int((note.width * Flags.DEFAULT_NOTE_SCALE) * scale));
		note.updateHitbox();
		note.alpha = 0.4;
		add(note);
	}

	var noteTime:Float = FlxG.initialHeight;
	var scroll:Float = 1.0;

	public function updatePos(x:Float, y:Float, scale:Float, spacing:Float, keyCount:Int, scrollSpeed:Float){
		if (members.length-1 != keyCount) //strumline + note
			generateStrums(x, y, scale, spacing, keyCount, scrollSpeed);

		for (i in 0...keyCount){
			var strum = members[i];

			strum.x = CoolUtil.fpsLerp(strum.x, x + (Note.swagWidth * scale * spacing * i), 0.2);
			strum.y = CoolUtil.fpsLerp(strum.y, y + (Note.swagWidth*0.5) - (Note.swagWidth * scale * 0.5), 0.2);
			strum.scale.x = strum.scale.y = CoolUtil.fpsLerp(strum.scale.x, Flags.DEFAULT_NOTE_SCALE * scale, 0.2);
			strum.updateHitbox();
		}


		scroll = CoolUtil.fpsLerp(scroll, scrollSpeed, 0.2);
		noteTime -= FlxG.elapsed * scroll * 1000 * 0.45;
		if (noteTime <= 0.0)
			noteTime = FlxG.initialHeight;

		note.x = members[0].x;
		note.y = members[0].y + noteTime;
		note.scale.x = note.scale.y = members[0].scale.x;
		note.updateHitbox();
		note.alpha = CoolUtil.fpsLerp(note.alpha, scrollSpeed == 0.0 ? 0.0 : 0.4, 0.2);
	}
}