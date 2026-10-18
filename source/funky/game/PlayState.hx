package funky.game;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funky.backend.MusicBeatState;
import funky.backend.chart.FNMMNote;
import funky.backend.chart.LevelLoader;
import funky.core.ClientPrefs;
import funky.core.Conductor;
import funky.core.ControlsCheck;
import funky.core.Difficulty;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.Paths;
import funky.game.Note.NoteSharedTailState;
import funky.menus.FreeplayState;
import funky.menus.GameOverSubState;
import funky.menus.PauseSubState;
import funky.scripting.Scripts;

/** FNMM runner: notas + escenario (scene.json) + eventos (events.json). Todo lo de la cancion sale de `SongData`. */
class PlayState extends MusicBeatState
{
	public var instance:PlayState;

	public static var archivePath:String;

	/** Chart editor ("probar desde aqui"): empieza la cancion en este ms; 0 = desde el inicio. */
	public static var startFromMs:Float = 0;

	/** Nivel al que se vuelve al salir del juego cuando se abrio desde el chart editor. null = Freeplay. */
	public static var returnToEditor:Null<String> = null;


	/** State al que se sale del juego: el chart editor si vino de ahi, o Freeplay. */
	public static function menuState():FlxState
	{
		if (returnToEditor == null) return new FreeplayState();

		// vuelve al charter con el mismo nivel
		return funkin.editors.charter.CharterLauncher.open(returnToEditor);
	}

	/** Ventana (ms, a cada lado) en la que una nota cuenta como acertada. */
	static inline var HIT_WINDOW:Float = 160;

	/** Pasado este retraso (ms) la nota se da por fallada. */
	static inline var MISS_AFTER:Float = HIT_WINDOW;

	/** Margen lateral de las strumlines. */
	static inline var SIDE_MARGIN:Float = 70;

	/** Y de las strums en upscroll: justo debajo del marcador del HUD. */
	static inline var STRUM_TOP:Float = 96;

	/** Distancia del borde inferior a la que quedan las strums en downscroll. */
	static inline var STRUM_BOTTOM_GAP:Float = 250;

	static inline var HEALTH_HIT:Float = 0.023;
	static inline var HEALTH_MISS:Float = -0.0475;

	/** Ventanas de rating (ms) y valores, los de Psych. */
	static inline var SICK_MS:Float = 45;
	static inline var GOOD_MS:Float = 90;
	static inline var BAD_MS:Float = 135;

	/** Tiempo (ms) que se puede soltar un sustain sin que se cuente como fallo. */
	static inline var COYOTE_MS:Float = 120;

	static inline var SUSTAIN_SCORE:Int = 20;

	/** Margen (px) extra fuera de pantalla para que una nota ya exista antes de entrar a cuadro. */
	static inline var SPAWN_MARGIN_PX:Float = 160;

	/** En cuantas partes por beat se cortan las piezas de un sustain. */
	static inline var SUSTAIN_DIV:Float = 4;

	public var song:SongData;
	public var playerLine:StrumLine;
	public var opponentLine:StrumLine;
	var mobileControls:MobileControls;
	public var songTime:Float = 0;
	public var hud:PlayHUD;
	public var stage:Stage;

	/** Camara del mundo (la default de Flixel): fondo y objetos no-fixed del stage. */
	public var camGame:FlxCamera;

	/** Camara del HUD (transparente, sin zoom): strums, notas, HUD, controles y sprites `fixed`. */
	public var camHUD:FlxCamera;

	/** Strumlines extra del chart (2, 3, ...), por indice. Son CPU y van separadas del oponente. */
	public var extraLines:Map<Int, StrumLine> = new Map<Int, StrumLine>();

	/** Strumlines que se dibujan y se actualizan (la 1 queda fuera si no tiene notas). */
	var hudLines:Array<StrumLine> = [];

	/** Todas las strumlines creadas, incluida la 1 aunque este vacia y oculta. */
	function allLines():Array<StrumLine>
	{
		var out = [playerLine, opponentLine];

		for (line in extraLines)
			out.push(line);

		return out;
	}

	/** Strumline por indice del chart: 0 jugador, 1 oponente, 2+ extras. */
	public function lineFor(index:Int):Null<StrumLine>
	{
		return index == 0 ? playerLine : (index == 1 ? opponentLine : extraLines.get(index));
	}

	/** Grupos que oculta el evento GUI: strums, notas, confirms y HUD. */
	var guiGroups:Array<FlxBasic> = [];

	/** Evento GUI: muestra u oculta toda la interfaz de juego. Los objetos fixed del stage se quedan. */
	public function setGuiVisible(value:Bool):Void
	{
		for (group in guiGroups)
			group.visible = value;
	}

	/** Camara para substates (pausa, game over): queda por encima del HUD. */
	var camSub:FlxCamera;
	public var eventos:Eventos;
	public var started:Bool = false;
	public var score:Int = 0;
	public var combo:Int = 0;
	public var misses:Int = 0;
	var totalPlayed:Int = 0;
	var totalNotesHit:Float = 0;
	var stepMs:Float = 125;
	var spawnAheadMs:Float = 2100;
	var scrollDirection:Float = 1;

	/** Un sonido y (opcional) un sprite por cuenta: 3, 2, 1, GO. El "3" no lleva imagen, como en FNF. */
	var introSounds:Array<String> = [
		'intro3',
		'intro2',
		'intro1',
		'introGo'
	];

	var introSprites:Array<Null<String>> = [
		null,
		'game/countdown/ready',
		'game/countdown/set',
		'game/countdown/go'
	];

	/** Timers del countdown, para poder cancelarlos si el state se destruye a la mitad. */
	var countdownTimers:Array<FlxTimer> = [];

	/** Un script cancelo `onEndSong`: no se vuelve a preguntar hasta `endSong(true)`. */
	var endBlocked:Bool = false;

	/** Estado de cada lane en el frame anterior, para `onKeyRelease`. */
	var prevHeld:Array<Bool> = [];

	override public function create():Void
	{
		super.create();

		camGame = FlxG.camera;
		camHUD = new FlxCamera();
		camHUD.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(camHUD, false);

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF151722));

		try
		{
			song = SongData.fromPath(archivePath);
		}
		catch (error:Dynamic)
		{
			showError(Std.string(error));
			return;
		}

		Scripts.load(song.levelDir, ["game" => this, "song" => song, "levelDir" => song.levelDir]);
		Scripts.call("onLoad");

		stage = new Stage(song, camHUD);

		if (stage.loaded)
			add(stage);
		else
			stage = null;

		eventos = new Eventos(song, stage);
		Scripts.set("stage", stage);
		Scripts.set("eventos", eventos);

		if (Scripts.has)
			for (event in eventos.lista)
				Scripts.call("onEventPush", [event]);

		var span = 4 * StrumLine.BASE_SPACE;
		var middle = ClientPrefs.isMiddleScroll();
		var strumX = middle ? (FlxG.width - span) / 2 : FlxG.width - span - SIDE_MARGIN;
		var strumY = ClientPrefs.isDownScroll() ? FlxG.height - STRUM_BOTTOM_GAP : STRUM_TOP;

		// Strumlines CPU visibles, de izquierda a derecha: la 1 (si tiene notas, o si no hay extras)
		// y cada extra (2, 3, ...) con notas. Una linea vacia no se dibuja.
		var showOpponent = song.hasOpponentNotes || song.extraLines.length == 0;
		var cpuIndexes:Array<Int> = [];

		if (showOpponent)
			cpuIndexes.push(1);

		for (extra in song.extraLines)
			cpuIndexes.push(extra);

		// Todas las strumlines CPU (la 1 y las extras) se apilan en la posicion de la strumline 1;
		// solo el jugador queda aparte.
		var lineWidth = span;
		var cpuX:Array<Float> = [for (_ in cpuIndexes) middle ? -span - 80 : SIDE_MARGIN];

		playerLine = new StrumLine(strumX, strumY, false, false, song.laneCount, lineWidth);
		playerLine.index = 0;

		// opponentLine siempre existe (los scripts la usan); si esta vacia no se agrega al juego.
		opponentLine = new StrumLine(cpuX[0], strumY, true, true, song.laneCount, lineWidth);
		opponentLine.index = 1;

		var activeLines:Array<StrumLine> = [];

		for (i in 0...cpuIndexes.length)
		{
			if (cpuIndexes[i] == 1)
			{
				activeLines.push(opponentLine);
				continue;
			}

			var extraLine = new StrumLine(cpuX[i], strumY, true, true, song.laneCount, lineWidth);
			extraLine.index = cpuIndexes[i];
			extraLines.set(cpuIndexes[i], extraLine);
			activeLines.push(extraLine);
		}

		activeLines.push(playerLine);
		hudLines = activeLines;

		Scripts.set("playerLine", playerLine);
		Scripts.set("opponentLine", opponentLine);

		// confirms() crea un grupo nuevo en cada llamada: se guarda y se usa ESE mismo
		var confirmGroups:Array<FlxTypedGroup<FlxSprite>> = [for (line in activeLines) line.confirms()];

		for (line in activeLines)
			add(line);

		for (group in confirmGroups)
			add(group);

		for (line in activeLines)
			add(line.notes);

		// todo lo que oculta el evento GUI (los fixed del stage y el boton de pausa no)
		guiGroups = [];

		for (line in activeLines)
		{
			guiGroups.push(line);
			guiGroups.push(line.notes);
		}

		for (group in confirmGroups)
			guiGroups.push(group);

		for (group in guiGroups)
			group.cameras = [camHUD];

		Scripts.call("onAddSpriteGroups");

		Note.PX_PER_MS = Note.BASE_PX_PER_MS * Difficulty.speed();
		spawnAheadMs = Math.ceil((FlxG.height + SPAWN_MARGIN_PX) / Note.PX_PER_MS);

		stepMs = song.beatMs / SUSTAIN_DIV;

		for (chartNote in song.notes)
			createNotes(chartNote);

		for (line in allLines())
			line.finishQueue();

		// El nivel dura lo que dura la musica, no lo que dura el chart: el final sale del audio (sin musica, del ultimo
		// note + cola). Asi la escena, los eventos y los videos siguen hasta que la cancion termina de verdad.
		var musicSound = song.musicPath != null ? LevelLoader.loadSound(song.musicPath) : null;
		if (musicSound != null && musicSound.length > 0)
			song.endTime = musicSound.length;

		hud = new PlayHUD(
			song.name,
			song.endTime,
			song.levelDir,
			song.iconPlayer,
			song.iconOpponent
		);

		hud.cameras = [camHUD];
		add(hud);
		guiGroups.push(hud);
		eventos.hud = hud;
		eventos.onGui = setGuiVisible;
		Scripts.set("hud", hud);

		if (song.musicPath != null)
		{
			var sound = musicSound;

			if (sound != null)
			{
				FlxG.sound.playMusic(sound, 1, false);
				FlxG.sound.music.pause();
				ClientPrefs.applyAudio();
			}
		}

		// voces separadas (opcional): music/Voices.ogg, sincronizadas con la musica
		if (song.voicesPath != null)
		{
			var voicesSnd = LevelLoader.loadSound(song.voicesPath);
			if (voicesSnd != null)
			{
				voices = new FlxSound().loadEmbedded(voicesSnd);
				FlxG.sound.list.add(voices);
				voices.play(true);
				voices.pause();
				if (FlxG.sound.music != null) voices.volume = FlxG.sound.music.volume;
			}
		}

		Conductor.reset();
		Conductor.bpm = song.bpm;

		if (startFromMs > 0)
		{
			songTime = startFromMs;

			if (FlxG.sound.music != null)
				FlxG.sound.music.time = startFromMs;
			if (voices != null)
				voices.time = startFromMs;
		}

		startCountdown();

		#if (android || ios)
		mobileControls = new MobileControls(requestPause, song.laneCount);
		mobileControls.cameras = [camHUD];
		add(mobileControls);
		#end

		prevHeld = [for (_ in 0...song.laneCount) false];

		Scripts.call("onCreatePost");
		transitionIn();
	}

	override public function update(elapsed:Float):Void
	{
		if (KeyBinds.justPressed(KeyBinds.PAUSE) && started && subState == null)
		{
			requestPause();
			return;
		}

		if (KeyBinds.justPressed(KeyBinds.BACK))
		{
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
			stopVoices();

			transitionTo(menuState());
			return;
		}

		if (Scripts.has)
			Scripts.call("onUpdate", [elapsed]);

		if (song == null)
		{
			super.update(elapsed);
			return;
		}

		if (!started)
		{
			super.update(elapsed);

			if (Scripts.has)
				Scripts.call("onUpdatePost", [elapsed]);
			return;
		}

		if (mobileControls != null)
			mobileControls.poll();

		songTime = FlxG.sound.music != null && FlxG.sound.music.playing
			? FlxG.sound.music.time
			: songTime + elapsed * 1000;

		// corrige la deriva de las voces respecto a la musica
		if (voices != null && voices.playing && FlxG.sound.music != null && FlxG.sound.music.playing
			&& Math.abs(voices.time - FlxG.sound.music.time) > 60)
			voices.time = FlxG.sound.music.time;

		if (stage != null)
			stage.songTime = songTime;

		if (eventos != null)
			eventos.update(songTime);

		Conductor.update(songTime);

		for (line in hudLines)
			line.spawnDue(songTime, spawnAheadMs);

		if (Conductor.justHitStep && Scripts.has)
			Scripts.call("onStepHit");

		if (Conductor.justHitBeat)
		{
			hud.beatHit();

			if (Scripts.has)
			{
				Scripts.call("onBeatHit");

				if (Conductor.currentBeat % 4 == 0)
					Scripts.call("onSectionHit");
			}
		}

		for (line in hudLines)
		{
			if (line == playerLine)
				line.updateInput(laneHeld, lanePressed);
			else
				line.updateInput(function(_) return false, function(_) return false);
		}

		scrollDirection = ClientPrefs.isDownScroll() ? -1 : 1;

		for (line in hudLines)
			updateNotes(line);

		hud.updateTime(songTime);

		// Vida a 0 = game over (con botplay no se muere).
		if (hud.health <= 0 && !ClientPrefs.isBotplay() && !transitioning && !Scripts.call("onGameOver"))
		{
			if (voices != null) voices.pause();
			openSubState(new GameOverSubState(this));
			return;
		}

		if (songTime > song.endTime)
			endSong();

		super.update(elapsed);

		if (Scripts.has)
			Scripts.call("onUpdatePost", [elapsed]);
	}

	/**
	 * Ends the song and goes back to freeplay.
	 * @param force Skip `onEndSong` (for a script that cancelled it and ends later).
	 */
	public function endSong(force:Bool = false):Void
	{
		if (transitioning || (endBlocked && !force))
			return;

		if (!force && Scripts.call("onEndSong"))
		{
			endBlocked = true;
			return;
		}

		transitionTo(menuState());
	}

	/**
	 * Creates a note in the proper strumline.
	 * @param chartNote Chart note data.
	 */
	function createNotes(chartNote:FNMMNote):Void
	{
		// "probar desde aqui": las notas anteriores al punto de inicio no existen
		if (startFromMs > 0 && chartNote.time < startFromMs)
			return;

		var target = lineFor(SongData.lineOf(chartNote));

		if (target != null)
			target.queueChartNote(chartNote, stepMs);
	}

	/**
	 * Updates every active note in a strumline.
	 * @param line Strumline to update.
	 */
	function updateNotes(line:StrumLine):Void
	{
		if (!line.cpu)
			processPresses(line);

		for (note in line.notes.members)
			if (note != null && note.exists)
				updateNote(note);
	}

	/**
	 * Processes player key presses and finds the earliest matching note.
	 * @param line Player strumline.
	 */
	function processPresses(line:StrumLine):Void
	{
		for (lane in 0...line.laneCount)
		{
			if (Scripts.has && lane < prevHeld.length)
			{
				var held = laneHeld(lane);

				if (prevHeld[lane] && !held)
					Scripts.call("onKeyRelease", [lane]);

				prevHeld[lane] = held;
			}

			if (!lanePressed(lane))
				continue;

			if (Scripts.has)
				Scripts.call("onKeyPress", [lane]);

			var best:Null<Note> = null;

			for (n in line.notes.members)
			{
				if (n == null || !n.exists || n.isSustainNote || n.tooLate || n.noteData != lane)
					continue;

				if (Math.abs(n.strumTime - songTime) >= HIT_WINDOW)
					continue;

				if (best == null || n.strumTime < best.strumTime)
					best = n;
			}

			if (best != null)
				hitNote(best, best.strumTime - songTime);
			else if (Scripts.has)
				Scripts.call("onGhostTap", [lane]);
		}
	}

	/**
	 * Updates one note's position, hit state and sustain state.
	 * @param note Note to update.
	 */
	function updateNote(note:Note):Void
	{
		var line = note.strumLine;
		var receptor = line.receptor(note.noteData);

		if (receptor == null)
		{
			note.kill();
			return;
		}

		var state = note.tailState;
		var cpu = line.cpu;
		var held = cpu || laneHeld(note.noteData);

		var consuming = note.isSustainNote && !state.missed && (cpu || state.hit) && held;
		var delta = note.updatePosition(receptor, songTime, scrollDirection, consuming);

		if (!note.isSustainNote)
		{
			if (cpu)
			{
				if (delta <= 0)
				{
					if (Scripts.has)
						Scripts.call("opponentNoteHitPre", [note]);

					receptor.confirm(songTime);
					state.hit = true;

					if (stage != null)
						stage.sing(stageSide(line), note.noteData);

					if (Scripts.has)
						Scripts.call("opponentNoteHit", [note]);

					note.kill();
				}

				return;
			}

			if (!note.tooLate && delta < -MISS_AFTER)
				missNote(note);

			killIfOffscreen(note, delta);
			return;
		}

		if (cpu)
		{
			if (delta <= 0)
			{
				receptor.confirm(songTime, false);

				if (stage != null)
					stage.hold(stageSide(line));

				if (songTime >= note.endTime())
					note.kill();
			}

			return;
		}

		if (state.missed)
		{
			killIfOffscreen(note, delta);
			return;
		}

		if (state.hit)
		{
			if (held)
				state.lastHeld = songTime;

			if (delta <= 0)
			{
				if (held)
				{
					receptor.confirm(songTime, false);

					if (stage != null)
						stage.hold(stageSide(line));

					if (songTime >= note.endTime())
					{
						if (!note.isSustainEnd)
						{
							score += SUSTAIN_SCORE;
							refreshScore(false);
						}

						note.kill();
					}
				}
				else if (songTime - state.lastHeld > COYOTE_MS)
				{
					dropSustain(note);
				}
			}

			return;
		}

		killIfOffscreen(note, delta);
	}

	static inline function ratingFor(ms:Float):String
		return ms <= SICK_MS ? "sick" : ms <= GOOD_MS ? "good" : ms <= BAD_MS ? "bad" : "shit";

	static inline function ratingPoints(rating:String):Int
		return rating == "sick" ? 350 : rating == "good" ? 200 : rating == "bad" ? 100 : 50;

	static inline function ratingWeight(rating:String):Float
		return rating == "sick" ? 1 : rating == "good" ? 0.67 : rating == "bad" ? 0.34 : 0;

	/**
	 * Registers a successful note hit.
	 * @param note Note that was hit.
	 * @param delta Difference between note time and current song time.
	 */
	function hitNote(note:Note, delta:Float):Void
	{
		var rating = ratingFor(Math.abs(delta));

		if (Scripts.has)
			Scripts.call("goodNoteHitPre", [note]);

		note.wasGoodHit = true;
		note.tailState.hit = true;
		note.tailState.lastHeld = songTime;

		playerLine.receptor(note.noteData).confirm(songTime);

		if (stage != null)
			stage.sing(0, note.noteData);

		score += ratingPoints(rating);
		totalNotesHit += ratingWeight(rating);
		totalPlayed++;
		combo++;

		hud.addHealth(HEALTH_HIT);

		if (Scripts.has)
			Scripts.call("onPopUpScore", [note, rating]);

		hud.popUpScore(rating, combo);

		if (Scripts.has)
			Scripts.call("onPopUpScorePost", [note, rating]);

		refreshScore(false);

		if (Scripts.has)
			Scripts.call("goodNoteHit", [note]);

		note.kill();
	}

	/**
	 * Registers a missed note head.
	 * @param note Note that was missed.
	 */
	function missNote(note:Note):Void
	{
		note.tooLate = true;
		registerMiss(note.tailState);
		note.alpha = 0.3;

		if (Scripts.has)
			Scripts.call("noteMiss", [note]);
	}

	/**
	 * Registers a dropped sustain.
	 * @param note Sustain piece that was dropped.
	 */
	function dropSustain(note:Note):Void
	{
		registerMiss(note.tailState);

		if (Scripts.has)
			Scripts.call("noteMiss", [note]);
	}

	/**
	 * Registers one miss for an entire sustain chain.
	 * @param state Shared state of the note tail.
	 */
	function registerMiss(state:NoteSharedTailState):Void
	{
		if (state.missed)
			return;

		state.missed = true;
		misses++;
		totalPlayed++;
		combo = 0;

		hud.addHealth(HEALTH_MISS);
		refreshScore(true);

		for (piece in state.tail)
			if (piece.exists && piece.tailState == state)
				piece.alpha = 0.3;
	}

	/**
	 * Updates the HUD score data.
	 * @param missed Whether this update was caused by a miss.
	 */
	function refreshScore(missed:Bool):Void
	{
		hud.onUpdateScore(
			score,
			totalPlayed == 0 ? -1 : totalNotesHit / totalPlayed * 100,
			misses,
			missed
		);

		if (Scripts.has)
		{
			Scripts.call("onUpdateScore", [missed]);
			Scripts.call("onRecalculateRating");
		}
	}

	/** 0 = jugador, 1 = oponente. */
	inline function stageSide(line:StrumLine):Int
		return line.index;

	/**
	 * Removes a note after it leaves the screen.
	 * @param note Note to check.
	 * @param delta Difference between note time and current song time.
	 */
	inline function killIfOffscreen(note:Note, delta:Float):Void
	{
		if (delta < 0 && (note.y + note.height < -20 || note.y > FlxG.height + 20))
			note.kill();
	}

	function lanePressed(lane:Int):Bool
	{
		return (mobileControls != null && mobileControls.justPressed(lane))
			|| ControlsCheck.justPressed(lane);
	}

	function laneHeld(lane:Int):Bool
	{
		return (mobileControls != null && mobileControls.isHeld(lane))
			|| ControlsCheck.pressed(lane);
	}

	/** Voces separadas opcionales (music/Voices.ogg). */
	public var voices:FlxSound;

	public function stopVoices():Void
	{
		if (voices == null) return;
		voices.stop();
		FlxG.sound.list.remove(voices, true);
		voices.destroy();
		voices = null;
	}

	public function pauseSong():Void
	{
		if (stage != null) stage.pauseVideos();
		if (FlxG.sound.music != null)
			FlxG.sound.music.pause();
		if (voices != null)
			voices.pause();
	}

	public function resumeSong():Void
	{
		if (stage != null) stage.resumeVideos();
		if (started && FlxG.sound.music != null)
			FlxG.sound.music.resume();
		if (started && voices != null)
			voices.resume();

		Scripts.call("onResume");
	}

	public function songLabel():String
	{
		return song == null ? "UNKNOWN" : song.name.toUpperCase();
	}

	function requestPause():Void
	{
		if (started && subState == null && !Scripts.call("onPause"))
			openSubState(new PauseSubState(this));
	}

	override public function openSubState(substate:FlxSubState):Void
	{
		// los substates se dibujan en su propia camara, encima de camHUD
		if (camSub == null)
		{
			camSub = new FlxCamera();
			camSub.bgColor = FlxColor.TRANSPARENT;
			FlxG.cameras.add(camSub, false);
		}

		substate.cameras = [camSub];

		super.openSubState(substate);
		Scripts.call("onSubstateOpen");
	}

	override public function closeSubState():Void
	{
		super.closeSubState();

		if (camSub != null)
		{
			FlxG.cameras.remove(camSub);
			camSub = null;
		}

		Scripts.call("onSubstateClose");
	}

	/**
	 * Displays a level loading error.
	 * @param message Error text.
	 */
	function showError(message:String):Void
	{
		var status = new FlxText(
			30,
			300,
			FlxG.width - 60,
			"No se pudo cargar el nivel:\n"
			+ message
			+ "\n\nPulsa "
			+ KeyBinds.label(KeyBinds.BACK)
			+ " para volver",
			20
		);

		status.alignment = FlxTextAlign.CENTER;
		if (camHUD != null)
			status.cameras = [camHUD];

		add(status);
	}

	/**
	 * Cuenta regresiva antes de la cancion: 4 tiempos de un beat (3, 2, 1, GO) y la musica arranca un
	 * beat despues del GO.
	 */
	public function startCountdown(force:Bool = false):Void
	{
		if (!force && Scripts.call("onStartCountdown"))
			return;

		var beat = Conductor.crochet / 1000;

		for (index in 0...introSounds.length)
		{
			countdownTimers.push(new FlxTimer().start(beat * (index + 1), function(_)
			{
				countdown(index);
			}));
		}

		countdownTimers.push(new FlxTimer().start(beat * (introSounds.length + 1), function(_)
		{
			started = true;
			hud.onSongStart();
			if (stage != null) stage.startVideos();

			if (FlxG.sound.music != null)
				FlxG.sound.music.resume();
			if (voices != null)
				voices.resume();

			Scripts.call("onSongStart");
		}));

		Scripts.call("onCountdownStarted");

		Log.info('[PlayState] countdown: ${introSounds.length} cuentas de ${Std.int(Conductor.crochet)} ms');
	}

	/**
	 * Muestra una cuenta del countdown y reproduce su sonido.
	 * @param swagCounter 0 = "3", 1 = "2" (ready), 2 = "1" (set), 3 = GO.
	 */
	public function countdown(swagCounter:Int):Void
	{
		Scripts.set("countdownTick", swagCounter);
		Scripts.call("onCountdownTick");

		var spritePath = introSprites[swagCounter];
		var soundName = introSounds[swagCounter];

		if (spritePath != null)
		{
			var file = Paths.image(spritePath);

			if (!sys.FileSystem.exists(file) && !openfl.utils.Assets.exists(file))
			{
				Log.warn('[PlayState] countdown: falta la imagen $file');
			}
			else
			{
				var sprite = new FlxSprite().loadGraphic(file);
				sprite.scrollFactor.set();
				sprite.antialiasing = true;
				sprite.screenCenter();
				sprite.cameras = [camHUD];
				add(sprite);

				FlxTween.tween(sprite, {y: sprite.y + 100, alpha: 0}, Conductor.crochet / 1000, {
					ease: FlxEase.cubeInOut,
					onComplete: function(_)
					{
						remove(sprite, true);
						sprite.destroy();
					}
				});
			}
		}

		if (soundName != null)
		{
			var file = Paths.sound(soundName);

			if (!sys.FileSystem.exists(file) && !openfl.utils.Assets.exists(file))
				Log.warn('[PlayState] countdown: falta el sonido $file');
			else
				FlxG.sound.play(file, 0.6);
		}
	}

	override public function destroy():Void
	{
		Scripts.call("onDestroy");
		Scripts.clear();

		for (timer in countdownTimers)
			timer.cancel();
		countdownTimers = [];

		if (eventos != null)
			eventos.destroy();

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		stopVoices();

		Conductor.reset();

		super.destroy();
	}
}