package funky.game;

import flixel.FlxSprite;
import funky.core.NoteRGBShader;
import funky.core.NoteSkin;

class QueueNote
{
	public var strumTime:Float;
	public var sustainLength:Float;
	public var noteData:Int;
	public var mustPress:Bool;
	public var isSustainNote:Bool = false;
	public var isSustainEnd:Bool = false;
	/** Piezas del sustain. Ya no se rellena al encolar: `StrumLine.spawnQueued` las arma cuando la nota entra a camara. */
	public var tail:Null<Array<QueueNote>> = null;
	/** > 0 si la nota tiene sustain; es el largo de un step en ms con el que se arma el tail al salir. */
	public var tailStepMs:Float = 0;
	/** Action pack (events.json) a correr al acertar / fallar. -1 = ninguno. Solo la cabeza lo trae. */
	public var onPress:Int = -1;
	public var onMiss:Int = -1;

	/**
	 * @param strumTime Tiempo de inicio de la nota en ms.
	 * @param sustainLength Duracion del sustain en ms.
	 * @param noteData Lane de la nota.
	 * @param mustPress Indica si la nota pertenece al jugador.
	 */
	public function new(
		strumTime:Float,
		sustainLength:Float,
		noteData:Int,
		mustPress:Bool
	)
	{
		this.strumTime = strumTime;
		this.sustainLength = sustainLength;
		this.noteData = noteData;
		this.mustPress = mustPress;
	}
}

class NoteSharedTailState
{
	public var parent:Note;
	public var tail:Array<Note> = [];

	public var hit:Bool = false;
	public var missed:Bool = false;
	public var lastHeld:Float = 0;
	/** Action packs de la cabeza del sustain: onMiss si se falla la nota o se suelta el sustain; onPress para saber si es trampa. */
	public var onMiss:Int = -1;
	public var onPress:Int = -1;

	/**
	 * @param parent Cabeza del sustain.
	 */
	public function new(parent:Note)
	{
		this.parent = parent;
	}
}

class Note extends FlxSprite
{

	/** Pixeles por ms con scroll speed 1. */
	public static inline var BASE_PX_PER_MS:Float = 0.45;
	/** Pixeles por ms actuales: PlayState lo fija segun la dificultad antes de crear notas. */
	public static var PX_PER_MS:Float = BASE_PX_PER_MS;
	public static inline var HOLD_WIDTH:Float = 0.45;

	public var queueNote:Null<QueueNote>;
	public var parent:Null<Note>;
	public var prevNote:Null<Note>;
	public var nextNote:Null<Note>;
	public var tailState:NoteSharedTailState;
	public var strumLine:StrumLine;

	public var strumTime:Float = 0;
	public var sustainLength:Float = 0;
	public var noteData:Int = 0;
	public var mustPress:Bool = false;
	public var isSustainNote:Bool = false;
	public var isSustainEnd:Bool = false;
	public var wasGoodHit:Bool = false;
	public var tooLate:Bool = false;

	public var holdHeight(default, null):Float = 0;

	var baseScaleY:Float = 1;
	var animLane:Int = -1;
	var usingAtlas:Bool = false;
	var skinId:String = "";

	public function new()
	{
		super();
	}

	/**
	 * @return Tiempo en ms en que termina de llegar al receptor.
	 */
	public inline function endTime():Float
	{
		return isSustainNote
			? strumTime + holdHeight / PX_PER_MS
			: strumTime;
	}

	/**
	 * @param q Datos de la nota.
	 * @param parent Cabeza del sustain al que pertenece.
	 * @param prevNote Nota anterior de la cadena.
	 * @param slotWidth Ancho disponible del lane.
	 * @param laneCount Cantidad total de lanes.
	 * @return Esta misma nota ya configurada.
	 */
	public function preRecycle(
		q:QueueNote,
		?parent:Note,
		?prevNote:Note,
		slotWidth:Float = 110,
		laneCount:Int = 4
	):Note
	{
		queueNote = q;
		this.parent = parent;
		this.prevNote = prevNote;
		nextNote = null;

		if (prevNote != null)
			prevNote.nextNote = this;

		if (parent != null)
		{
			tailState = parent.tailState;
		}
		else if (tailState == null || tailState.tail.length > 0)
		{
			tailState = new NoteSharedTailState(this);
		}
		else
		{
			tailState.parent = this;
			tailState.hit = false;
			tailState.missed = false;
			tailState.lastHeld = 0;
		}

		if (parent == null)
		{
			tailState.onMiss = q.onMiss;
			tailState.onPress = q.onPress;
		}

		strumTime = q.strumTime;
		sustainLength = q.sustainLength;
		noteData = q.noteData;
		mustPress = q.mustPress;

		isSustainNote = q.isSustainNote;
		isSustainEnd = q.isSustainEnd;

		wasGoodHit = false;
		tooLate = false;
		alpha = 1;
		flipY = false;

		var skin = NoteSkin.current();

		if (frames == null || (usingAtlas && skinId != skin.id))
		{
			skinId = skin.id;
			frames = skin.frames();
			usingAtlas = frames != null;
			animLane = -1;
			animation.destroyAnimations();

			if (!usingAtlas) makeGraphic(50, 50, 0xFFFFFFFF);
		}

		if (usingAtlas)
		{
			if (animLane != noteData)
			{
				animation.destroyAnimations();

				animation.addByPrefix("scroll", skin.animFor("note", noteData), 24, false);
				animation.addByPrefix("hold", skin.animFor("hold", noteData), 24, false);
				animation.addByPrefix("holdend", skin.animFor("holdEnd", noteData), 24, false);

				animLane = noteData;
			}

			animation.play(
				isSustainNote
					? (isSustainEnd ? "holdend" : "hold")
					: "scroll",
				true
			);
		}

		var widthScale = slotWidth / Math.max(1, frameWidth);
		var holdWidthScale = widthScale * HOLD_WIDTH;

		if (!isSustainNote)
		{
			scale.set(widthScale, widthScale);
			holdHeight = 0;
		}
		else if (isSustainEnd)
		{
			scale.set(holdWidthScale, 1);
			holdHeight = frameHeight * widthScale;
		}
		else
		{
			holdHeight = sustainLength * PX_PER_MS + 1;

			scale.set(
				holdWidthScale,
				holdHeight / Math.max(1, frameHeight)
			);
		}

		baseScaleY = scale.y;
		updateHitbox();

		if (isSustainNote)
			alpha = skin.holdAlpha;

		// Segun el tipo del skin: shader RGB, tinte (color) o nada (atlas ya pintado). Tambien limpia lo del uso anterior.
		skin.applyTo(this, noteData, false, laneCount);

		// Script del skin (si trae): puede cambiar shader, tinte, escala, animacion...
		skin.notify("onNoteCreate", "onNote", [this, noteData]);

		return this;
	}

	/**
	 * @param receptor Strum receptor usado como referencia.
	 * @param songTime Tiempo actual de la canción en ms.
	 * @param scrollDirection Direccion del scroll.
	 * @param consuming Indica si el sustain se esta consumiendo.
	 * @return Distancia temporal hasta el receptor.
	 */
	public function updatePosition(
		receptor:Strum,
		songTime:Float,
		scrollDirection:Float,
		consuming:Bool = false
	):Float
	{
		var distance = strumTime - songTime;
		var cx = receptor.x + (receptor.width - width) * 0.5;

		if (!isSustainNote)
		{
			x = cx;
			y = receptor.y + distance * PX_PER_MS * scrollDirection;
			return distance;
		}

		var cy = receptor.y + receptor.height * 0.5;
		var y0 = cy + distance * PX_PER_MS * scrollDirection;

		var consumed = consuming && distance < 0;
		var visible = consumed
			? Math.max(0, holdHeight + distance * PX_PER_MS)
			: holdHeight;

		flipY = scrollDirection < 0;

		scale.y = Math.max(
			0.0001,
			baseScaleY * visible / Math.max(1, holdHeight)
		);

		updateHitbox();

		x = cx;

		if (scrollDirection > 0)
			y = consumed ? cy : y0;
		else
			y = y0 - holdHeight;

		return distance;
	}
}
