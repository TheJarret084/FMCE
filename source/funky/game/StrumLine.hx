package funky.game;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import funky.backend.chart.FNMMNote;
import funky.core.NoteSkin;
import funky.game.Note.QueueNote;
import funky.scripting.Scripts;

class StrumLine extends FlxTypedGroup<Strum>
{

	public static inline var BASE_SPACE:Float = 110;

	static inline var SLOT_FILL:Float = 0.96;

	public var notes(default, null):FlxTypedGroup<Note> = new FlxTypedGroup<Note>();

	public var splashes(default, null):FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();
	public var cpu(default, null):Bool;
	public var opponentSide(default, null):Bool;
	public var laneCount(default, null):Int;
	public var spacing(default, null):Float;
	public var slotWidth(default, null):Float;

	public var index:Int = 0;

	public function new(x:Float, y:Float, cpu:Bool, opponentSide:Bool, laneCount:Int = 4, lineWidth:Float = 440)
	{
		super();
		this.cpu = cpu;
		this.opponentSide = opponentSide;
		this.laneCount = laneCount < 1 ? 1 : laneCount;
		spacing = lineWidth / Math.max(4, this.laneCount);
		slotWidth = spacing * SLOT_FILL;

		NoteSkin.current().splashFrames();

		for (lane in 0...this.laneCount)
		{
			Scripts.call("preReceptorGeneration", [this, lane]);
			add(new Strum(lane, x + lane * spacing, y, slotWidth, this.laneCount));
		}

		Scripts.call("postReceptorGeneration");
	}

	var queue:Array<QueueNote> = [];
	var queueIndex:Int = 0;

	public function queueChartNote(data:FNMMNote, stepMs:Float):Void
	{
		var q = new QueueNote(data.time, data.length, data.lane, data.mustPress);
		q.onPress = data.onPress != null ? data.onPress : -1;
		q.onMiss = data.onMiss != null ? data.onMiss : -1;
		if (data.length > 0 && stepMs > 0) q.tailStepMs = stepMs;
		queue.push(q);
	}

	function buildTail(q:QueueNote):Array<QueueNote>
	{
		var stepMs = q.tailStepMs;
		var tail:Array<QueueNote> = [];
		var endTime = q.strumTime + q.sustainLength;
		var step = Math.floor((q.strumTime + 3) / stepMs);
		while (step * stepMs < endTime)
		{
			var time = Math.max(step * stepMs, q.strumTime);
			var length = Math.min((step + 1) * stepMs, endTime) - time;
			if (length >= 1)
			{
				var piece = new QueueNote(time, length, q.noteData, q.mustPress);
				piece.isSustainNote = true;
				tail.push(piece);
			}
			step++;
		}
		var end = new QueueNote(endTime, stepMs, q.noteData, q.mustPress);
		end.isSustainNote = true;
		end.isSustainEnd = true;
		tail.push(end);
		return tail;
	}

	public function finishQueue():Void
	{
		queue.sort(function(a, b)
		{
			if (a.strumTime != b.strumTime) return a.strumTime < b.strumTime ? -1 : 1;
			if (a.noteData != b.noteData) return a.noteData < b.noteData ? -1 : 1;
			return 0;
		});
		queueIndex = 0;
	}

	public function clearNotes(fadeSeconds:Float = 0.25):Void
	{
		queueIndex = queue.length;

		for (note in notes.members)
		{
			if (note == null || !note.exists)
				continue;

			if (fadeSeconds <= 0)
			{
				note.kill();
				continue;
			}

			var target = note;
			FlxTween.tween(target, {alpha: 0}, fadeSeconds, {
				onComplete: function(_) if (target != null) target.kill()
			});
		}
	}

	public function spawnDue(songTime:Float, aheadMs:Float):Void
	{
		while (queueIndex < queue.length && queue[queueIndex].strumTime - songTime < aheadMs)
			spawnQueued(queue[queueIndex++]);
	}

	function spawnQueued(q:QueueNote):Note
	{
		var head = notes.recycle(Note, Note.new).preRecycle(q, null, null, slotWidth, laneCount);
		head.strumLine = this;
		if (Scripts.has) Scripts.call("onSpawnNote", [head]);
		head.tailState.tail.resize(0);
		if (q.tailStepMs > 0)
		{
			var prev = head;
			for (t in buildTail(q))
			{
				var piece = notes.recycle(Note, Note.new).preRecycle(t, head, prev, slotWidth, laneCount);
				piece.strumLine = this;
				head.tailState.tail.push(piece);
				prev = piece;
			}
		}
		if (Scripts.has) Scripts.call("onSpawnNotePost", [head]);
		return head;
	}

	public function splash(lane:Int):Void
	{
		var strum = receptor(lane);
		if (strum == null) return;

		var splash = splashes.recycle(NoteSplash, NoteSplash.new);
		splash.cameras = strum.cameras;
		splash.burst(NoteSkin.current(), lane, laneCount, strum);
	}

	public inline function receptor(lane:Int):Null<Strum> return lane >= 0 && lane < members.length ? members[lane] : null;

	public function updateInput(held:Int->Bool, justPressed:Int->Bool):Void
		for (strum in members) if (strum != null) strum.updateInput(held(strum.lane), justPressed(strum.lane));

	public inline function confirms():FlxTypedGroup<FlxSprite>
	{
		var out = new FlxTypedGroup<FlxSprite>();
		for (strum in members)
		{
			if (strum == null) continue;
			var confirm = strum.confirmSprite;
			if (confirm != null) out.add(confirm);
		}
		return out;
	}
}
