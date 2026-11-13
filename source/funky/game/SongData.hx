package funky.game;

import funky.backend.chart.FNMMChart;
import funky.backend.chart.FNMMNote;
import funky.backend.chart.LevelLoader;
import funky.core.ClientPrefs;

class SongData
{

	public static final TAIL:Float = 2000;

	public var path:Null<String>;
	public var name:String;
	public var bpm:Float;
	public var levelDir:Null<String>;
	public var musicPath:Null<String>;

	public var voicesPath:Null<String>;
	public var iconPlayer:Null<String>;
	public var iconOpponent:Null<String>;

	public var events:Array<Dynamic>;

	public var actionPacks:Array<Array<Dynamic>>;

	public var stepsPerBeat:Float;

	public var stage:Null<String>;

	public var color:Null<String>;

	public var notes:Array<FNMMNote>;

	public var hasOpponentNotes:Bool = true;

	public var playerNotes:Array<FNMMNote>;

	public var opponentNotes:Array<FNMMNote>;

	public var laneCount:Int;

	public var lastNoteTime:Float;

	public var endTime:Float;

	public var beatMs(get, never):Float;

	public var stepMs(get, never):Float;

	public static function fromPath(path:String):SongData
	{
		final data = new SongData(LevelLoader.loadAny(path));
		data.path = path;
		return data;
	}

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

		notes.sort(function(a, b)
		{
			if (a.time != b.time) return a.time < b.time ? -1 : 1;
			if (a.lane != b.lane) return a.lane < b.lane ? -1 : 1;
			if (a.mustPress != b.mustPress) return a.mustPress ? -1 : 1;
			return 0;
		});

		playerNotes = [];
		opponentNotes = [];
		lastNoteTime = 0;
		var highestLane:Int = 0;
		for (note in notes)
		{
			var line = lineOf(note);

			if (line == 0) playerNotes.push(note);
			else if (line == 1) opponentNotes.push(note);
			else continue;

			lastNoteTime = Math.max(lastNoteTime, note.time + note.length);
			highestLane = Std.int(Math.max(highestLane, note.lane));
		}
		hasOpponentNotes = opponentNotes.length > 0;
		if (laneCount < highestLane + 1) laneCount = highestLane + 1;
		if (laneCount > ClientPrefs.MAX_LANES) laneCount = ClientPrefs.MAX_LANES;
		endTime = lastNoteTime + TAIL;
	}

	public static inline function lineOf(note:FNMMNote):Int
		return note.line != null ? note.line : (note.mustPress ? 0 : 1);

	public function notesFor(mustPress:Bool):Array<FNMMNote> return mustPress ? playerNotes : opponentNotes;

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
