package funky.game;

import funky.backend.chart.FNMMChart;
import funky.backend.chart.FNMMNote;
import funky.backend.chart.LevelLoader;
import funky.core.ClientPrefs;

/** El nivel entero ya parseado desde disco: notas, eventos, audio y metadata. */
class SongData
{
	/** Cola que se deja despues de la ultima nota antes de cortar a Freeplay. */
	public static final TAIL:Float = 2000;

	/** Cargo o carpeta de donde salio el nivel. Sirve para resolver sprites y audio. */
	public var path:Null<String>;
	public var name:String;
	public var bpm:Float;
	public var levelDir:Null<String>;
	public var musicPath:Null<String>;
	/** Voces separadas (`music/Voices.ogg`); null si el nivel no trae. */
	public var voicesPath:Null<String>;
	public var iconPlayer:Null<String>;
	public var iconOpponent:Null<String>;
	/** Eventos crudos de `events.json` (`{time, actions}`), tal como vienen del archivo. */
	public var events:Array<Dynamic>;
	/** `action_packs` de `events.json`: lo que corre un `RunActionPack`. */
	public var actionPacks:Array<Array<Dynamic>>;
	/** Pasos por beat del nivel (`meta.stepsPerBeat` o `npb`). Es la rejilla del chart y de los eventos. */
	public var stepsPerBeat:Float;
	/** Nombre del escenario que dice `meta.json` (`stage`), o null si el nivel no trae escena. */
	public var stage:Null<String>;
	/** `meta.color`, o null. */
	public var color:Null<String>;

	/** Todas las notas del nivel, ordenadas por tiempo. */
	public var notes:Array<FNMMNote>;
	/** Solo las del jugador, en el mismo orden. */
	/** Strumlines extra (2, 3, ...) que tienen notas, en orden. Cada una es CPU y va aparte. */
	public var extraLines:Array<Int> = [];

	/** false si la strumline 1 no tiene notas (ej: el oponente canta por una extra). */
	public var hasOpponentNotes:Bool = true;

	public var playerNotes:Array<FNMMNote>;
	/** Solo las del oponente, en el mismo orden. */
	public var opponentNotes:Array<FNMMNote>;

	/** Cuantas lanes tiene el nivel. 4 si el chart no lo dice. */
	public var laneCount:Int;
	/** `max(time + length)` de todas las notas. 0 si el nivel esta vacio. */
	public var lastNoteTime:Float;
	/** `lastNoteTime + TAIL`: cuando PlayState vuelve a Freeplay. */
	public var endTime:Float;

	/** Duracion (ms) de un beat. */
	public var beatMs(get, never):Float;
	/** Duracion (ms) de un step de la rejilla del nivel (`beatMs / stepsPerBeat`). */
	public var stepMs(get, never):Float;

	/**
	 * @param path Carpeta de nivel o `.fnmm`. `LevelLoader` decide cual de las dos es.
	 */
	public static function fromPath(path:String):SongData
	{
		final data = new SongData(LevelLoader.loadAny(path));
		data.path = path;
		return data;
	}

	/** Para cuando el chart ya esta en memoria (editor, tests, replay). */
	public function new(chart:FNMMChart)
	{
		path = chart.levelDir;
		name = chart.name;
		bpm = chart.bpm;
		levelDir = chart.levelDir;
		musicPath = chart.musicPath;
		voicesPath = chart.voicesPath;
		iconPlayer = chart.iconPlayer;
		iconOpponent = chart.iconOpponent;
		events = chart.events == null ? [] : chart.events;
		actionPacks = chart.actionPacks == null ? [] : chart.actionPacks;
		stepsPerBeat = chart.stepsPerBeat != null && chart.stepsPerBeat > 0 ? chart.stepsPerBeat : 4;
		stage = chart.stage;
		color = chart.color;
		laneCount = chart.laneCount > 0 ? chart.laneCount : 4;

		notes = [];
		if (chart.notes != null)
		{
			for (note in chart.notes)
			{
				if (note == null || note.lane < 0) continue;
				notes.push(note);
			}
		}
		// `FNMMLoader` deja las notas como vienen en el zip, asi que el orden hay que
		// garantiza aca. El desempate por lane y por strumline es para que dos notas al
		// mismo tiempo siempre salgan en el mismo orden.
		notes.sort(function(a, b)
		{
			if (a.time != b.time) return a.time < b.time ? -1 : 1;
			if (a.lane != b.lane) return a.lane < b.lane ? -1 : 1;
			if (a.mustPress != b.mustPress) return a.mustPress ? -1 : 1;
			return 0;
		});

		playerNotes = [];
		opponentNotes = [];
		extraLines = [];
		lastNoteTime = 0;
		var highestLane:Int = 0;
		for (note in notes)
		{
			var line = lineOf(note);

			if (line == 0) playerNotes.push(note);
			else if (line == 1) opponentNotes.push(note);
			else if (extraLines.indexOf(line) < 0) extraLines.push(line);

			lastNoteTime = Math.max(lastNoteTime, note.time + note.length);
			highestLane = Std.int(Math.max(highestLane, note.lane));
		}
		extraLines.sort(function(a, b) return a - b);
		hasOpponentNotes = opponentNotes.length > 0;
		if (laneCount < highestLane + 1) laneCount = highestLane + 1;
		if (laneCount > ClientPrefs.MAX_LANES) laneCount = ClientPrefs.MAX_LANES;
		endTime = lastNoteTime + TAIL;
	}

	/** Strumline de una nota: 0 jugador, 1 oponente, 2+ extras. */
	public static inline function lineOf(note:FNMMNote):Int
		return note.line != null ? note.line : (note.mustPress ? 0 : 1);

	public function notesFor(mustPress:Bool):Array<FNMMNote> return mustPress ? playerNotes : opponentNotes;

	/** Convierte un tiempo de evento (`seconds`, `beats` o `steps`) a milisegundos. */
	public function unitToMs(value:Float, unit:String):Float
	{
		return switch (unit.toLowerCase())
		{
			case "beats" | "beat": value * beatMs;
			case "steps" | "step": value * stepMs;
			case "ms" | "milliseconds": value;
			default: value * 1000;
		};
	}

	public var isEmpty(get, never):Bool;

	inline function get_beatMs():Float return 60000 / Math.max(1, bpm);

	inline function get_stepMs():Float return beatMs / stepsPerBeat;

	inline function get_isEmpty():Bool return notes.length == 0;
}
