package funky.game;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tweens.FlxTween;
import funky.backend.chart.FNMMNote;
import funky.core.NoteSkin;
import funky.game.Note.QueueNote;
import funky.scripting.Scripts;

/**
 * Reduced Codename-style strumline: owns receptors and its note group.
 * Input, characters, scripting and vocals remain PlayState concerns for now.
 */
class StrumLine extends FlxTypedGroup<Strum>
{
	/** Lane spacing of a 4-lane line. Wider lines keep the same 440px total width. */
	public static inline var BASE_SPACE:Float = 110;

	/** How much of its slot the receptor artwork fills, leaving a thin gutter. */
	static inline var SLOT_FILL:Float = 0.96;

	public var notes(default, null):FlxTypedGroup<Note> = new FlxTypedGroup<Note>();
	/** Splashes de esta linea (pool). PlayState lo agrega a la escena encima de las notas. */
	public var splashes(default, null):FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();
	public var cpu(default, null):Bool;
	public var opponentSide(default, null):Bool;
	public var laneCount(default, null):Int;
	public var spacing(default, null):Float;
	public var slotWidth(default, null):Float;

	/** Strumline del chart: 0 jugador, 1 oponente, 2+ extras. Lo asigna PlayState. */
	public var index:Int = 0;

	/** @param lineWidth ancho total de la linea (440 normal; menor cuando hay mas de dos strumlines en pantalla). */
	public function new(x:Float, y:Float, cpu:Bool, opponentSide:Bool, laneCount:Int = 4, lineWidth:Float = 440)
	{
		super();
		this.cpu = cpu;
		this.opponentSide = opponentSide;
		this.laneCount = laneCount < 1 ? 1 : laneCount;
		spacing = lineWidth / Math.max(4, this.laneCount);
		slotWidth = spacing * SLOT_FILL;

		// El atlas del splash se pide ya (como el de los receptores): si se pidiera recien al primer SICK, el Flixel de Codename
		// lo habria marcado como destruible al cambiar de estado (ver NoteSkin.hook) y habria que recargarlo en pleno juego.
		NoteSkin.current().splashFrames();

		for (lane in 0...this.laneCount)
		{
			Scripts.call("preReceptorGeneration", [this, lane]);
			add(new Strum(lane, x + lane * spacing, y, slotWidth, this.laneCount));
		}

		Scripts.call("postReceptorGeneration");
	}

	/** Notas del chart que todavia no salieron, ordenadas por tiempo. Son datos, no sprites. */
	var queue:Array<QueueNote> = [];
	var queueIndex:Int = 0;

	/**
	 * Encola una nota del chart. Solo guarda datos (una `QueueNote` por nota, sin sprites ni piezas de sustain):
	 * el tail se arma en `spawnQueued`, cuando la nota esta por entrar a camara.
	 */
	public function queueChartNote(data:FNMMNote, stepMs:Float):Void
	{
		var q = new QueueNote(data.time, data.length, data.lane, data.mustPress);
		q.onPress = data.onPress != null ? data.onPress : -1;
		q.onMiss = data.onMiss != null ? data.onMiss : -1;
		if (data.length > 0 && stepMs > 0) q.tailStepMs = stepMs;
		queue.push(q);
	}

	/**
	 * Piezas del sustain de `q`: una por step (alineadas a la cuadricula) y una pieza final, igual que el legacy.
	 * Se arma al salir la nota para no tener miles de `QueueNote` de sustains que todavia no se ven.
	 */
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

	/** Llamar una vez despues de encolar todo el chart. */
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

	/**
	 * Fin de la cancion: no sale ninguna nota mas y las que siguen en pantalla se desvanecen y se van
	 * (en vez de desaparecer de golpe o volver a aparecer).
	 */
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

	/** Activa las notas que faltan menos de `aheadMs` para llegar al receptor. */
	public function spawnDue(songTime:Float, aheadMs:Float):Void
	{
		while (queueIndex < queue.length && queue[queueIndex].strumTime - songTime < aheadMs)
			spawnQueued(queue[queueIndex++]);
	}

	/** Igual que `PlayState.recycleNote` del legacy: cabeza primero y luego sus piezas. */
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

	/** Splash del skin actual sobre el receptor de `lane` (centrado en el, con el color de la lane). */
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

	/** Confirm sprites are held here so PlayState can draw them above the receptors. */
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
