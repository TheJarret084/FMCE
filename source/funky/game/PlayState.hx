package funky.game;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import funky.api.DiscordClient;
import funky.backend.JarretVideo;
import funky.backend.MusicBeatState;
import funky.backend.chart.FNMMNote;
import funky.backend.chart.LevelLoader;
import funky.core.ClientPrefs;
import funky.core.Conductor;
import funky.core.ControlsCheck;
import funky.core.Difficulty;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.NoteSkin;
import funky.core.Paths;
import funky.game.Note.NoteSharedTailState;
import funky.game.PlayHUD.PressScore;
import funky.menus.FreeplayState;
import funky.menus.GameOverSubState;
import funky.menus.PauseSubState;
import funky.scripting.Scripts;
import funkin.editors.ui.UIWarningSubstate;

/**
 * Juego: HUD, notas, escenario, eventos y scripts.
 */
@:keep
class PlayState extends MusicBeatState
{
	/**
	 * Instancia actual del juego (null fuera de una cancion).
	 */
	public static var instance:PlayState;

	var forceExit:Bool = #if (debug || mobile) true #else false #end;

	// SESION

	/**
	 * Nivel que se esta jugando (null si se entro sin chart).
	 */
	public static var archivePath:String;

	/**
	 * Punto de inicio del chart editor ("probar desde aqui"), en ms. 0 = desde el principio.
	 */
	public static var startFromMs:Float = 0;

	/**
	 * Punto desde el que se abrio el nivel. REINICIAR siempre vuelve aqui, aunque se haya saltado desde la pausa.
	 */
	public static var launchStartMs:Float = 0;

	/**
	 * Nivel al que se vuelve al salir: el chart editor si se abrio desde ahi, o Freeplay.
	 */
	public static var returnToEditor:Null<String> = null;

	/**
	 * true justo despues de un salto de la pausa: el create siguiente no toma `startFromMs` como punto de partida.
	 */
	static var seeking:Bool = false;

	/**
	 * true tras continuar con un salto de la pausa: el create siguiente arranca sin countdown.
	 */
	static var skipCountdown:Bool = false;

	/**
	 * Estado de cada lane en el frame anterior, para `onKeyRelease`.
	 */
	var prevHeld:Array<Bool> = [];

	/**
	 * Entrada limpia a un nivel (Freeplay, convertidor...): olvida cualquier salto anterior de la pausa.
	 */
	public static function resetLaunch():Void
	{
		startFromMs = 0;
		launchStartMs = 0;
		seeking = false;
		skipCountdown = false;
	}

	/**
	 * State al que se sale del juego: el chart editor si vino de ahi, o Freeplay.
	 */
	public static function menuState():FlxState
	{
		if (returnToEditor == null)
			return new FreeplayState();

		return funkin.editors.charter.CharterLauncher.open(returnToEditor);
	}

	// CONSTANTES DE JUEGO

	/**
	 * Ventana (ms, a cada lado) en la que una nota cuenta como acertada.
	 */
	static inline var HIT_WINDOW:Float = 160;

	/**
	 * Pasado este retraso (ms) la nota se da por fallada.
	 */
	static inline var MISS_AFTER:Float = HIT_WINDOW;

	/**
	 * Margen lateral de las strumlines.
	 */
	static inline var SIDE_MARGIN:Float = 70;

	/**
	 * Y de las strums en upscroll: justo debajo del marcador del HUD.
	 */
	static inline var STRUM_TOP:Float = 96;

	/**
	 * Distancia del borde inferior a la que quedan las strums en downscroll.
	 */
	static inline var STRUM_BOTTOM_GAP:Float = 160;

	/**
	 * Tamano de la strumline CPU en middlescroll respecto a la normal (una mini, a la izquierda, sin notas).
	 */
	static inline var MINI_LINE_SCALE:Float = 0.5;

	static inline var HEALTH_HIT:Float = 0.023;
	static inline var HEALTH_MISS:Float = -0.0475;

	/**
	 * Ventanas de rating (ms), las de Psych.
	 */
	static inline var SICK_MS:Float = 45;
	static inline var GOOD_MS:Float = 90;
	static inline var BAD_MS:Float = 135;

	static inline var COYOTE_MS:Float = 120;

	static inline var SUSTAIN_SCORE:Int = 20;

	/**
	 * Puntos que resta tocar sin nota al alcance con ghost tapping apagado.
	 */
	static inline var GHOST_MISS_SCORE:Int = 10;

	/**
	 * Margen (px) extra fuera de pantalla para que una nota ya exista antes de entrar a cuadro.
	 */
	static inline var SPAWN_MARGIN_PX:Float = 160;

	/**
	 * En cuantas partes por beat se cortan las piezas de un sustain.
	 */
	static inline var SUSTAIN_DIV:Float = 4;

	/**
	 * Cuanto adelanta / retrocede la pausa, y lo minimo que se deja antes del final para que el salto no caiga en el cierre.
	 */
	public static inline var SEEK_STEP_MS:Float = 10000;
	static inline var SEEK_END_MARGIN:Float = 3000;

	/**
	 * Sin countdown, la cancion arranca este rato (s) despues de crear el nivel: lo que tarda la cortina en abrirse.
	 */
	static inline var SEEK_START_DELAY:Float = 0.5;

	// CANCION

	/**
	 * Datos del nivel: chart, meta, escenario y rutas de audio.
	 */
	public var song:SongData;

	public var playerLine:StrumLine;
	public var opponentLine:StrumLine;
	var mobileControls:MobileControls;

	/**
	 * Posicion actual de la cancion en ms.
	 */
	public var songTime:Float = 0;

	public var hud:PlayHUD;
	public var stage:Stage;

	/**
	 * Camara del mundo (la default de Flixel): fondo y objetos no-fixed del stage.
	 */
	public var camGame:FlxCamera;

	/**
	 * Camara del HUD (transparente, sin zoom): strums, notas, HUD, controles y sprites `fixed`.
	 */
	public var camHUD:FlxCamera;

	/**
	 * Camara para substates (pausa, game over): queda por encima del HUD.
	 */
	var camSub:FlxCamera;

	public var eventos:Eventos;

	/**
	 * Strumlines extra del chart (2, 3, ...), por indice. Son CPU y van separadas del oponente.
	 */
	public var extraLines:Map<Int, StrumLine> = new Map<Int, StrumLine>();

	/**
	 * Strumlines que se dibujan y se actualizan (la 1 queda fuera si no tiene notas).
	 */
	var hudLines:Array<StrumLine> = [];

	/**
	 * Grupos que oculta el evento GUI: strums, notas, confirms y HUD.
	 */
	var guiGroups:Array<FlxBasic> = [];

	/**
	 * Cuanto se ve la interfaz (0..1). Lo anima el evento GUI con un mini tween.
	 */
	var guiFade:Float = 1;
	var guiFadeTween:FlxTween;

	/**
	 * Alpha propio de cada sprite de la interfaz mientras `guiFade` se lo esta multiplicando.
	 */
	var guiBaseAlpha:haxe.ds.ObjectMap<FlxSprite, Float> = new haxe.ds.ObjectMap();

	static inline var GUI_FADE_SECONDS:Float = 0.25;

	// PROGRESO

	public var started:Bool = false;
	public var score:Int = 0;
	public var combo:Int = 0;
	public var misses:Int = 0;

	var totalPlayed:Int = 0;
	var totalNotesHit:Float = 0;

	/**
	 * Suma de la precision (0..100) de cada nota tocada y cuantas fueron.
	 */
	var precisionSum:Float = 0;
	var pressCount:Int = 0;

	/**
	 * Ultima pulsacion puntuada (para scripts).
	 */
	public var lastPress:PressScore;

	var stepMs:Float = 125;
	var spawnAheadMs:Float = 2100;
	var scrollDirection:Float = 1;

	/**
	 * Un script cancelo `onEndSong`: no se vuelve a preguntar hasta `endSong(true)`.
	 */
	var endBlocked:Bool = false;

	/**
	 * La cancion ya termino (endSong paso el chequeo de scripts): el tiempo, las notas y los eventos se congelan.
	 */
	var songEnded:Bool = false;

	/**
	 * El audio de la musica llego a su final (`onComplete`).
	 */
	var musicEnded:Bool = false;

	/**
	 * Voces separadas opcionales (music/Voices.ogg).
	 */
	public var voices:FlxSound;

	// COUNTDOWN

	/**
	 * Un sonido por cuenta: 3, 2, 1, GO. El "3" no lleva imagen, como en FNF.
	 */
	public var introSounds:Array<String> = ['intro3', 'intro2', 'intro1', 'introGo'];

	public var introSprites:Array<Null<String>> = [null, 'game/countdown/ready', 'game/countdown/set', 'game/countdown/go'];

	/**
	 * Timers del countdown, para poder cancelarlos si el state se destruye a la mitad.
	 */
	var countdownTimers:Array<FlxTimer> = [];

	// ERRORES PENDIENTES

	/**
	 * Error de carga pendiente: el create no puede abrir substates todavia, asi que se muestra en el primer update.
	 */
	var pendingError:Null<String> = null;

	/**
	 * Error de un script en modo test: sale la ventana directo (sin el video, que es solo para errores graves de chart / escena).
	 */
	var pendingScriptError:Null<String> = null;
	var warningInstanced:Bool = false;

	/**
	 * Strumlines creadas, incluida la 1 aunque este vacia y oculta.
	 */
	function allLines():Array<StrumLine>
	{
		var out = [playerLine, opponentLine];

		for (line in extraLines)
			out.push(line);

		return out;
	}

	/**
	 * Strumline por indice del chart: 0 jugador, 1 oponente, 2+ extras.
	 */
	public function lineFor(index:Int):Null<StrumLine>
	{
		return index == 0 ? playerLine : (index == 1 ? opponentLine : extraLines.get(index));
	}

	// EVENTO GUI

	/**
	 * Muestra u oculta toda la interfaz de juego con un fade corto. Los objetos fixed del stage se quedan.
	 * No toca `visible` de ningun grupo: lo que ya estaba oculto sigue oculto.
	 */
	public function setGuiVisible(value:Bool):Void
	{
		if (guiFadeTween != null)
			guiFadeTween.cancel();

		guiFadeTween = FlxTween.num(guiFade, value ? 1 : 0, GUI_FADE_SECONDS, {ease: FlxEase.quadOut}, function(v:Float) guiFade = v);
	}

	/**
	 * Antes del update: devuelve a cada sprite su alpha real, para que el resto del juego no vea el fade.
	 */
	function releaseGuiFade():Void
	{
		for (sprite in guiBaseAlpha.keys())
			if (sprite.colorTransform != null)
				sprite.alpha = guiBaseAlpha.get(sprite);

		guiBaseAlpha = new haxe.ds.ObjectMap();
	}

	/**
	 * Despues del update: multiplica el alpha de toda la interfaz por `guiFade`.
	 */
	function applyGuiFade():Void
	{
		if (guiFade >= 1)
			return;

		for (group in guiGroups)
			paintGuiFade(group);
	}

	function paintGuiFade(basic:FlxBasic):Void
	{
		if (basic == null)
			return;

		if (Std.isOfType(basic, FlxTypedGroup))
		{
			for (member in (cast basic : FlxTypedGroup<FlxBasic>).members)
				paintGuiFade(member);

			return;
		}

		if (Std.isOfType(basic, FlxTypedSpriteGroup))
		{
			for (member in (cast basic : FlxTypedSpriteGroup<FlxSprite>).members)
				paintGuiFade(member);

			return;
		}

		var sprite = Std.downcast(basic, FlxSprite);

		if (sprite == null || sprite.colorTransform == null || guiBaseAlpha.exists(sprite))
			return;

		guiBaseAlpha.set(sprite, sprite.alpha);
		sprite.alpha *= guiFade;
	}

	// LIFECYCLE

	override public function create():Void
	{
		super.create();
		instance = this;
		SpriteCache.attach();

		if (!seeking)
			launchStartMs = startFromMs;

		seeking = false;

		// CAMARAS
		camGame = FlxG.camera;
		camGame.bgColor = FlxColor.BLACK;
		camHUD = new FlxCamera();
		camHUD.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(camHUD, false);

		// NIVEL Y SCRIPTS
		try
		{
			song = funky.menus.LoadingLevelState.takeSong();

			if (song == null)
				song = SongData.fromPath(archivePath);
		}
		catch (error:Dynamic)
		{
			pendingError = Std.string(error);
			return;
		}

		funky.core.Paths.currentLevel = song.levelDir;
		DiscordClient.playingPresence(songLabel(), Difficulty.name());
		Scripts.load(song.levelDir, ["game" => this, "song" => song, "levelDir" => song.levelDir]);
		Scripts.call("onLoad");

		// ESCENARIO Y EVENTOS
		stage = new Stage(song, camHUD);

		if (stage.loaded)
			add(stage);
		else
		{
			Log.warn('[PlayState] el stage no cargo ningun objeto (' + song.levelDir + ')');
			stage = null;
		}

		eventos = new Eventos(song, stage);
		Scripts.set("stage", stage);
		Scripts.set("eventos", eventos);

		if (Scripts.has)
			for (event in eventos.lista)
				Scripts.call("onEventPush", [event]);

		// STRUMLINES
		var span = 4 * StrumLine.BASE_SPACE;
		var middle = ClientPrefs.isMiddleScroll();
		var strumX = middle ? (FlxG.width - span) / 2 : FlxG.width - span - SIDE_MARGIN;
		var strumY = ClientPrefs.isDownScroll() ? FlxG.height - STRUM_BOTTOM_GAP : STRUM_TOP;

		var showOpponent = song.hasOpponentNotes;
		var cpuIndexes:Array<Int> = [];

		if (showOpponent)
			cpuIndexes.push(1);

		for (extra in song.extraLines)
			cpuIndexes.push(extra);

		var lineWidth = span;
		var cpuWidth = middle ? span * MINI_LINE_SCALE : span;
		var cpuX:Array<Float> = [for (_ in cpuIndexes) SIDE_MARGIN];

		playerLine = new StrumLine(strumX, strumY, ClientPrefs.isBotplay(), false, song.laneCount, lineWidth);
		playerLine.index = 0;

		opponentLine = new StrumLine(cpuX[0], strumY, true, true, song.laneCount, cpuWidth);
		opponentLine.index = 1;

		var activeLines:Array<StrumLine> = [];

		for (i in 0...cpuIndexes.length)
		{
			if (cpuIndexes[i] == 1)
			{
				activeLines.push(opponentLine);
				continue;
			}

			var extraLine = new StrumLine(cpuX[i], strumY, true, true, song.laneCount, cpuWidth);
			extraLine.index = cpuIndexes[i];
			extraLines.set(cpuIndexes[i], extraLine);
			activeLines.push(extraLine);
		}

		activeLines.push(playerLine);
		hudLines = activeLines;

		Scripts.set("playerLine", playerLine);
		Scripts.set("opponentLine", opponentLine);

		var confirmGroups:Array<FlxTypedGroup<FlxSprite>> = [for (line in activeLines) line.confirms()];

		for (line in activeLines)
			add(line);

		for (group in confirmGroups)
			add(group);

		for (line in activeLines)
			add(line.notes);

		for (line in activeLines)
			add(line.splashes);

		if (middle)
			for (line in activeLines)
				if (line != playerLine)
					line.notes.visible = false;

		guiGroups = [];

		for (line in activeLines)
		{
			guiGroups.push(line);
			guiGroups.push(line.notes);
			guiGroups.push(line.splashes);
		}

		for (group in confirmGroups)
			guiGroups.push(group);

		for (group in guiGroups)
			group.cameras = [camHUD];

		Scripts.call("onAddSpriteGroups");

		// NOTAS
		Note.PX_PER_MS = Note.BASE_PX_PER_MS * Difficulty.speed();
		spawnAheadMs = Math.ceil((camHUD.height / camHUD.zoom + SPAWN_MARGIN_PX) / Note.PX_PER_MS);
		stepMs = song.beatMs / SUSTAIN_DIV;

		for (chartNote in song.notes)
			createNotes(chartNote);

		for (line in allLines())
			line.finishQueue();

		var musicSound = song.musicPath != null ? LevelLoader.loadSound(song.musicPath) : null;

		if (musicSound != null && musicSound.length > 0)
			song.endTime = musicSound.length;

		// HUD
		hud = new PlayHUD(song.name, song.endTime, song.levelDir, song.iconPlayer, song.iconOpponent, song.laneCount);

		hud.cameras = [camHUD];
		add(hud);
		hud.placeBotplay(strumX, strumY, lineWidth);
		hud.followBotplay(playerLine);
		guiGroups.push(hud);
		eventos.hud = hud;
		eventos.onGui = setGuiVisible;
		FlxG.signals.preUpdate.add(releaseGuiFade);
		FlxG.signals.postUpdate.add(applyGuiFade);
		Scripts.set("hud", hud);

		// AUDIO
		if (song.musicPath != null)
		{
			var sound = musicSound;

			if (sound != null)
			{
				FlxG.sound.playMusic(sound, 1, false);
				FlxG.sound.music.pause();
				FlxG.sound.music.onComplete = onMusicComplete;
				ClientPrefs.applyAudio();
			}
		}

		if (song.voicesPath != null)
		{
			var voicesSnd = LevelLoader.loadSound(song.voicesPath);

			if (voicesSnd != null)
			{
				voices = new FlxSound().loadEmbedded(voicesSnd);
				FlxG.sound.list.add(voices);
				voices.play(true);
				voices.pause();

				if (FlxG.sound.music != null)
					voices.volume = FlxG.sound.music.volume;
			}
		}

		Conductor.reset();
		Conductor.bpm = song.bpm;

		// PUNTO DE INICIO
		if (startFromMs > 0)
		{
			songTime = startFromMs;

			if (FlxG.sound.music != null)
				FlxG.sound.music.time = startFromMs;

			if (voices != null)
				voices.time = startFromMs;
		}

		if (skipCountdown)
		{
			skipCountdown = false;
			countdownTimers.push(new FlxTimer().start(SEEK_START_DELAY, function(_) beginSong()));
		}
		else
			startCountdown();

		// CONTROLES MOVILES
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
		if (pendingError != null)
		{
			var message = pendingError;
			pendingError = null;
			showError(message);
			return;
		}

		if (pendingScriptError != null)
		{
			var message = pendingScriptError;
			pendingScriptError = null;
			showScriptError(message);
			return;
		}

		if (KeyBinds.justPressed(KeyBinds.PAUSE) && started && !songEnded && subState == null)
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

		// SCRIPTS
		if (Scripts.has)
			Scripts.call("onUpdate", [elapsed]);

		var noteSkin = NoteSkin.current();

		if (noteSkin.script != null)
			noteSkin.script.call("onUpdate", [elapsed]);

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

		if (songEnded)
		{
			super.update(elapsed);

			if (Scripts.has)
				Scripts.call("onUpdatePost", [elapsed]);

			return;
		}

		// TIEMPO
		if (mobileControls != null)
			mobileControls.poll();

		songTime = nextSongTime(elapsed);

		if (voices != null
			&& voices.playing
			&& FlxG.sound.music != null
			&& FlxG.sound.music.playing
			&& Math.abs(voices.time - FlxG.sound.music.time) > 60)
			voices.time = FlxG.sound.music.time;

		if (stage != null)
			stage.songTime = songTime;

		if (eventos != null)
			eventos.update(songTime);

		Conductor.update(songTime);

		// NOTAS Y BEATS
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

		// GAME OVER Y FIN
		if (hud.health <= 0 && !ClientPrefs.isBotplay() && !transitioning && !Scripts.call("onGameOver"))
		{
			if (voices != null)
				voices.pause();

			openSubState(new GameOverSubState(this));
			return;
		}

		if (songTime > song.endTime)
			endSong();

		super.update(elapsed);

		if (Scripts.has)
			Scripts.call("onUpdatePost", [elapsed]);
	}

	override public function destroy():Void
	{
		Scripts.call("onDestroy");
		Scripts.clear();

		if (instance == this)
			instance = null;

		FlxG.signals.preUpdate.remove(releaseGuiFade);
		FlxG.signals.postUpdate.remove(applyGuiFade);

		if (guiFadeTween != null)
			guiFadeTween.cancel();

		releaseGuiFade();
		cancelCountdown();

		if (eventos != null)
			eventos.destroy();

		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		stopVoices();
		Conductor.reset();

		super.destroy();
	}

	// FIN DE CANCION Y PUNTAJE

	/**
	 * Termina la cancion y vuelve a Freeplay (o al charter).
	 * @param force Salta `onEndSong`, para un script que lo cancelo y termina despues.
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

		songEnded = true;

		if (FlxG.sound.music != null)
			FlxG.sound.music.onComplete = null;

		for (line in allLines())
			if (line != null)
				line.clearNotes();

		stopVoices();
		saveScore();
		transitionTo(menuState());
	}

	/**
	 * Lo llama el audio al llegar a su final. El fin real lo decide `update` (ver `nextSongTime`).
	 */
	function onMusicComplete():Void
	{
		musicEnded = true;
	}

	/**
	 * Tiempo de la cancion de este frame. Sigue a la musica pero nunca retrocede: al terminar el audio puede
	 * devolver 0 por un frame, y eso reiniciaba el temporizador, los eventos y las notas.
	 */
	function nextSongTime(elapsed:Float):Float
	{
		var music = FlxG.sound.music;
		var next = songTime + elapsed * 1000;

		if (music != null && music.playing)
		{
			var t = music.time;

			if (t + 250 < songTime)
				musicEnded = true;
			else
				next = t;
		}

		if (musicEnded && next <= song.endTime)
			next = song.endTime + 1;

		return next;
	}

	/**
	 * Guarda el puntaje del nivel (por nivel y dificultad) si es el mejor. No cuenta con botplay, ni si se
	 * probo desde un editor o desde un punto a mitad de la cancion.
	 */
	function saveScore():Void
	{
		if (ClientPrefs.isBotplay() || returnToEditor != null || startFromMs > 0 || archivePath == null)
			return;

		var accuracy = totalPlayed == 0 ? 0 : totalNotesHit / totalPlayed * 100;
		funky.core.Scores.submit(funky.core.Scores.levelId(archivePath), Difficulty.current, score, accuracy, misses);
	}

	// NOTAS

	/**
	 * Crea una nota en su strumline.
	 * @param chartNote Nota del chart.
	 */
	function createNotes(chartNote:FNMMNote):Void
	{
		if (startFromMs > 0 && chartNote.time < startFromMs)
			return;

		var target = lineFor(SongData.lineOf(chartNote));

		if (target != null)
			target.queueChartNote(chartNote, stepMs);
	}

	/**
	 * Actualiza todas las notas activas de una strumline.
	 * @param line Strumline a actualizar.
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
	 * Procesa las pulsaciones del jugador y busca la nota valida mas cercana.
	 * @param line Strumline del jugador.
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
			else
			{
				if (Scripts.has)
					Scripts.call("onGhostTap", [lane]);

				if (!ClientPrefs.isGhostTapping())
					ghostMiss(lane);
			}
		}
	}

	/**
	 * Actualiza la posicion, el acierto y el sustain de una nota.
	 * @param note Nota a actualizar.
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
					if (line == playerLine && esTrampa(note.queueNote != null ? note.queueNote.onPress : -1))
					{
						note.kill();
						return;
					}

					if (Scripts.has)
						Scripts.call("opponentNoteHitPre", [note]);

					receptor.confirm(songTime);
					state.hit = true;

					if (stage != null)
						stage.sing(stageSide(line), note.noteData);

					runNoteEvent(note.queueNote != null ? note.queueNote.onPress : -1);

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

	/**
	 * Elimina una nota que ya salio de pantalla.
	 * @param note Nota a revisar.
	 * @param delta Diferencia entre el tiempo de la nota y el actual.
	 */
	inline function killIfOffscreen(note:Note, delta:Float):Void
	{
		if (delta < 0 && (note.y + note.height < -20 || note.y > FlxG.height + 20))
			note.kill();
	}

	// PUNTAJE

	/**
	 * Precision de una pulsacion: 100 justo en el tiempo de la nota, bajando lineal hasta 0 en el borde de `HIT_WINDOW`.
	 */
	static inline function precisionFor(absMs:Float):Float
		return Math.max(0, 1 - absMs / HIT_WINDOW) * 100;

	/**
	 * Precision media de todas las notas tocadas (0..100); -1 si todavia no se toco ninguna.
	 */
	public var averagePrecision(get, never):Float;

	inline function get_averagePrecision():Float
		return pressCount == 0 ? -1 : precisionSum / pressCount;

	/**
	 * Rating, puntos y precision de tocar una nota con ese `delta` (strumTime - songTime).
	 */
	function pressScore(delta:Float):PressScore
	{
		var rating = ratingFor(Math.abs(delta));
		return {rating: rating, score: ratingPoints(rating), precision: precisionFor(Math.abs(delta)), ms: -delta};
	}

	static inline function ratingFor(ms:Float):String
		return ms <= SICK_MS ? "sick" : ms <= GOOD_MS ? "good" : ms <= BAD_MS ? "bad" : "shit";

	static inline function ratingPoints(rating:String):Int
		return rating == "sick" ? 350 : rating == "good" ? 200 : rating == "bad" ? 100 : 50;

	static inline function ratingWeight(rating:String):Float
		return rating == "sick" ? 1 : rating == "good" ? 0.67 : rating == "bad" ? 0.34 : 0;

	/**
	 * Registra un acierto.
	 * @param note Nota acertada.
	 * @param delta Diferencia entre el tiempo de la nota y el actual.
	 */
	function hitNote(note:Note, delta:Float):Void
	{
		var press = pressScore(delta);
		var rating = press.rating;
		lastPress = press;

		if (Scripts.has)
			Scripts.call("goodNoteHitPre", [note]);

		note.wasGoodHit = true;
		note.tailState.hit = true;
		note.tailState.lastHeld = songTime;

		playerLine.receptor(note.noteData).confirm(songTime);

		if (rating == "sick" && ClientPrefs.isNoteSplashes())
			playerLine.splash(note.noteData);

		if (stage != null)
			stage.sing(0, note.noteData);

		runNoteEvent(note.queueNote != null ? note.queueNote.onPress : -1);

		score += press.score;
		totalNotesHit += ratingWeight(rating);
		totalPlayed++;
		precisionSum += press.precision;
		pressCount++;
		combo++;

		hud.addHealth(HEALTH_HIT);

		if (Scripts.has)
			Scripts.call("onPopUpScore", [note, rating]);

		hud.popUpScore(rating, combo, press);

		if (Scripts.has)
			Scripts.call("onPopUpScorePost", [note, rating]);

		if (Scripts.has)
			Scripts.call("onNoteScored", [note, rating, press.score, press.precision, press.ms]);

		refreshScore(false);

		if (Scripts.has)
			Scripts.call("goodNoteHit", [note]);

		note.kill();
	}

	/**
	 * Registra una nota fallada.
	 * @param note Nota fallada.
	 */
	function missNote(note:Note):Void
	{
		note.tooLate = true;
		registerMiss(note.tailState);
		note.alpha = 0.3;

		if (Scripts.has && !esTrampa(note.tailState.onPress))
			Scripts.call("noteMiss", [note]);
	}

	/**
	 * Tocar un carril sin nota al alcance con ghost tapping apagado: cuenta como fallo.
	 * @param lane Carril que se toco.
	 */
	function ghostMiss(lane:Int):Void
	{
		if (stage != null)
			stage.miss(stageSide(playerLine));

		misses++;
		totalPlayed++;
		combo = 0;
		score -= GHOST_MISS_SCORE;

		hud.addHealth(HEALTH_MISS);
		playMissSound();
		refreshScore(true);

		if (Scripts.has)
			Scripts.call("noteMissPress", [lane]);
	}

	/**
	 * Efecto de fallo (assets/sounds/missSFX.ogg). Se apaga en Opciones > Gameplay > Sonido de fallo.
	 */
	function playMissSound():Void
	{
		if (!ClientPrefs.isMissSound())
			return;

		try
		{
			funky.core.CoolUtil.playSound("missSFX" + Std.string(FlxG.random.int(0, 4)), FlxG.random.float(0.2, 0.8));
		}
		catch (e:Dynamic) {}
	}

	/**
	 * Registra un sustain soltado.
	 * @param note Pieza del sustain que se solto.
	 */
	function dropSustain(note:Note):Void
	{
		registerMiss(note.tailState);

		if (Scripts.has && !esTrampa(note.tailState.onPress))
			Scripts.call("noteMiss", [note]);
	}

	/**
	 * Registra un fallo para toda la cadena de un sustain.
	 * @param state Estado compartido de la cola de la nota.
	 */
	function registerMiss(state:NoteSharedTailState):Void
	{
		if (state.missed)
			return;

		state.missed = true;

		if (!esTrampa(state.onPress))
		{
			runNoteEvent(state.onMiss);

			if (stage != null)
				stage.miss(stageSide(playerLine));

			misses++;
			totalPlayed++;
			combo = 0;

			hud.addHealth(HEALTH_MISS);
			playMissSound();
			refreshScore(true);
		}

		for (piece in state.tail)
			if (piece.exists && piece.tailState == state)
				piece.alpha = 0.3;
	}

	/**
	 * Actualiza los datos de puntaje del HUD.
	 * @param missed Si la actualizacion viene de un fallo.
	 */
	function refreshScore(missed:Bool):Void
	{
		hud.onUpdateScore(score, totalPlayed == 0 ? -1 : totalNotesHit / totalPlayed * 100, misses, missed);

		if (Scripts.has)
		{
			Scripts.call("onUpdateScore", [missed]);
			Scripts.call("onRecalculateRating");
		}
	}

	/**
	 * Nota "trampa": su onPress resta vida al jugador (ver Eventos.restaVida).
	 */
	function esTrampa(pack:Int):Bool
		return pack >= 0 && eventos != null && eventos.restaVida(pack);

	/**
	 * `onPressEvent` / `onMissEvent` de una nota: corre ese action pack de events.json (-1 = ninguno).
	 */
	function runNoteEvent(pack:Int):Void
	{
		if (pack >= 0 && eventos != null)
			eventos.runPack(pack, songTime);
	}

	/**
	 * Lado del escenario de una strumline: 0 = jugador, 1 = oponente.
	 */
	inline function stageSide(line:StrumLine):Int
		return line.index;

	// INPUT

	function lanePressed(lane:Int):Bool
	{
		return (mobileControls != null && mobileControls.justPressed(lane)) || ControlsCheck.justPressed(lane);
	}

	function laneHeld(lane:Int):Bool
	{
		return (mobileControls != null && mobileControls.isHeld(lane)) || ControlsCheck.pressed(lane);
	}

	// AUDIO

	public function stopVoices():Void
	{
		if (voices == null)
			return;

		voices.stop();
		FlxG.sound.list.remove(voices, true);
		voices.destroy();
		voices = null;
	}

	public function pauseSong():Void
	{
		if (stage != null)
			stage.pauseVideos();

		if (FlxG.sound.music != null)
			FlxG.sound.music.pause();

		if (voices != null)
			voices.pause();
	}

	public function resumeSong():Void
	{
		if (stage != null)
			stage.resumeVideos();

		if (started && FlxG.sound.music != null)
			FlxG.sound.music.resume();

		if (started && voices != null)
			voices.resume();

		Scripts.call("onResume");
		DiscordClient.playingPresence(songLabel(), Difficulty.name());
	}

	// REINICIO Y SALTO

	/**
	 * Reinicia la cancion desde donde se abrio el nivel (ignora los saltos hechos desde la pausa).
	 */
	public function restartSong():Void
	{
		startFromMs = launchStartMs;
		seeking = false;
		skipCountdown = false;
		leaveSong();
		transitionTo(new funky.menus.LoadingLevelState());
	}

	/**
	 * Deja `target` (ms) dentro de la cancion: con margen antes del final y, cerca del inicio (menos de 1 s), en 0.
	 */
	public function clampSeek(target:Float):Float
	{
		if (song == null)
			return songTime;

		var limit = Math.max(0, song.endTime - SEEK_END_MARGIN);
		var clamped = Math.max(0, Math.min(limit, target));

		return clamped < 1000 ? 0 : clamped;
	}

	/**
	 * Duracion de la cancion (ms), para mostrarla en la pausa.
	 */
	public function songLengthMs():Float
		return song == null ? 0 : song.endTime;

	/**
	 * Salta a `target` (ms), igual que "probar desde aqui" del charter: se vuelve a cargar el nivel empezando en ese punto.
	 * Lo llama la pausa al darle continuar; entra sin countdown (salvo que el punto sea el inicio, que es como reiniciar).
	 * @return false si ya se estaba ahi.
	 */
	public function seekTo(target:Float):Bool
	{
		var point = clampSeek(target);

		if (Math.abs(point - songTime) < 1)
			return false;

		startFromMs = point;
		seeking = true;
		skipCountdown = point > 0;
		leaveSong();

		funky.menus.LoadingLevelState.keep(song);
		SpriteCache.keepAlive();
		SpriteCache.detach();
		transitionTo(new PlayState());

		return true;
	}

	/**
	 * Corta la musica y las voces antes de cambiar de state.
	 */
	function leaveSong():Void
	{
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();

		stopVoices();
	}

	/**
	 * Sale al menu desde una pantalla de error: corta la musica y las voces y cambia de state.
	 */
	function exitToMenu():Void
	{
		leaveSong();
		transitionTo(PlayState.menuState());
	}

	public function songLabel():String
	{
		return song == null ? "UNKNOWN" : song.name.toUpperCase();
	}

	// PAUSA

	function requestPause():Void
	{
		if (started && subState == null && !Scripts.call("onPause"))
			openSubState(new PauseSubState(this));
	}

	override public function openSubState(substate:FlxSubState):Void
	{
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

	// ERRORES

	/**
	 * Muestra el error de carga de un nivel: primero un video solo (`fatalerrorisocurred`) y al terminar (o si el video
	 * falta o falla) la ventana de aviso con el mensaje y un boton para salir.
	 * @param message Texto del error.
	 */
	function showError(message:String):Void
	{
		safely("transitionIn (error)", function() transitionIn());
		safely("music.stop (error)", function() if (FlxG.sound.music != null) FlxG.sound.music.stop());

		var showWarning = function():Void
		{
			openSubState(new UIWarningSubstate("Error al cargar el nivel", message, [
				{
					label: "Salir",
					color: FlxG.random.color(),
					onClick: function(_) exitToMenu()
				}
			], false));
		};

		var cutscene = new JarretVideo();
		openSubState(cutscene);
		cutscene.play("fatalerrorisocurred", showWarning);
		warningInstanced = true;
	}

	/**
	 * Un script fallo (lo llama `LevelScript`). En modo test (el nivel se abrio desde el editor) el juego se detiene y sale la
	 * ventana de error, directo y sin video; jugando normal (Freeplay) solo queda en el log y todo sigue.
	 */
	public function scriptFailed(message:String):Void
	{
		if (returnToEditor == null || pendingError != null || pendingScriptError != null || warningInstanced)
			return;

		pendingScriptError = message;
	}

	/**
	 * Para el juego y abre la ventana de error de un script (sin el video de `showError`).
	 */
	function showScriptError(message:String):Void
	{
		warningInstanced = true;
		safely("music.stop (script error)", function() if (FlxG.sound.music != null) FlxG.sound.music.stop());

		openSubState(new UIWarningSubstate("Error en un script", message, [
			{
				label: "Salir",
				onClick: function(_) exitToMenu()
			}
		], true));
	}

	/**
	 * Corre `action`. Si truena, lo manda al log (F2) con `label` y el juego sigue: un detalle no debe tumbar el countdown.
	 */
	function safely(label:String, action:Void->Void):Void
	{
		try
		{
			action();
		}
		catch (error:Dynamic)
		{
			Log.error('[PlayState] $label: ' + Std.string(error));
		}
	}

	// COUNTDOWN

	/**
	 * Duracion de un tiempo del countdown (s). Con un BPM invalido (0, NaN, infinito) usa el del chart, o 500 ms como ultimo recurso.
	 */
	function countdownBeat():Float
	{
		var ms = Conductor.crochet;

		if (Math.isNaN(ms) || !Math.isFinite(ms) || ms <= 0)
		{
			var bpm = song != null ? song.bpm : 0;
			ms = (!Math.isNaN(bpm) && Math.isFinite(bpm) && bpm > 0) ? 60000 / bpm : 500;
			Log.warn('[PlayState] countdown: BPM invalido, se usan ${Std.int(ms)} ms por tiempo');
		}

		return Math.max(0.1, ms / 1000);
	}

	/**
	 * Cancela los timers del countdown (al reiniciarlo o al destruir el state).
	 */
	function cancelCountdown():Void
	{
		for (timer in countdownTimers)
			if (timer != null)
				timer.cancel();

		countdownTimers = [];
	}

	/**
	 * Cuenta regresiva antes de la cancion: 4 tiempos de un beat (3, 2, 1, GO) y la musica arranca un beat despues del GO.
	 * A prueba de errores: si algo falla se avisa en el log y la cuenta sigue; la cancion siempre arranca.
	 */
	public function startCountdown(force:Bool = false):Void
	{
		if (started)
			return;

		if (!force)
		{
			var cancelled = false;
			safely("onStartCountdown", function() cancelled = Scripts.call("onStartCountdown"));

			if (cancelled)
				return;
		}

		cancelCountdown();

		var beat = countdownBeat();
		var ticks = Std.int(Math.max(introSounds.length, introSprites.length));

		for (index in 0...ticks)
			countdownTimers.push(new FlxTimer().start(beat * (index + 1), function(_) countdown(index)));

		countdownTimers.push(new FlxTimer().start(beat * (ticks + 1), function(_) beginSong()));

		safely("onCountdownStarted", function() Scripts.call("onCountdownStarted"));

		Log.info('[PlayState] countdown: $ticks cuentas de ${Std.int(beat * 1000)} ms');
	}

	/**
	 * Empieza la cancion de verdad: tiempo, musica, voces y videos del stage. Lo llama el fin del countdown (o el salto sin countdown).
	 */
	function beginSong():Void
	{
		if (started)
			return;

		started = true;

		safely("hud.onSongStart", function() hud.onSongStart());
		safely("stage.startVideos", function() if (stage != null) stage.startVideos());
		safely("music.resume", function() if (FlxG.sound.music != null) FlxG.sound.music.resume());
		safely("voices.resume", function() if (voices != null) voices.resume());
		safely("onSongStart", function() Scripts.call("onSongStart"));
	}

	/**
	 * Muestra una cuenta del countdown y reproduce su sonido. Cada parte falla por separado: si falta la imagen, el
	 * sonido suena igual y la cuenta no se detiene.
	 * @param swagCounter 0 = "3", 1 = "2" (ready), 2 = "1" (set), 3 = GO.
	 */
	public function countdown(swagCounter:Int):Void
	{
		if (songEnded)
			return;

		safely("onCountdownTick", function()
		{
			Scripts.set("countdownTick", swagCounter);
			Scripts.call("onCountdownTick");
		});
		safely("imagen del countdown", function() showCountdownImage(swagCounter));
		safely("sonido del countdown", function() playCountdownSound(swagCounter));
	}

	/**
	 * Ruta de un archivo del countdown que SI existe, o null. Desde el charter se prueba primero la version "-test"
	 * (intro3-test, game/countdown/ready-test...) y si falta se usa la normal.
	 */
	function countdownAsset(name:String, image:Bool):Null<String>
	{
		var names = returnToEditor != null ? [name + "-test", name] : [name];

		for (candidate in names)
		{
			var file = image ? Paths.image(candidate) : Paths.sound(candidate);

			if (sys.FileSystem.exists(file) || openfl.utils.Assets.exists(file))
				return file;
		}

		return null;
	}

	function showCountdownImage(index:Int):Void
	{
		var spritePath = index >= 0 && index < introSprites.length ? introSprites[index] : null;

		if (spritePath == null)
			return;

		var file = countdownAsset(spritePath, true);

		if (file == null)
		{
			Log.warn('[PlayState] countdown: falta la imagen ${Paths.image(spritePath)}');
			return;
		}

		var sprite = new FlxSprite().loadGraphic(file);

		if (sprite.graphic == null || sprite.frameWidth <= 1)
		{
			Log.warn('[PlayState] countdown: la imagen $file no se pudo cargar');
			sprite.destroy();
			return;
		}

		sprite.scrollFactor.set();
		sprite.antialiasing = true;
		sprite.screenCenter();
		sprite.cameras = [camHUD];
		add(sprite);

		FlxTween.tween(sprite, {y: sprite.y + 100, alpha: 0}, countdownBeat(), {
			ease: FlxEase.cubeInOut,
			onComplete: function(_)
			{
				remove(sprite, true);
				sprite.destroy();
			}
		});
	}

	function playCountdownSound(index:Int):Void
	{
		var soundName = index >= 0 && index < introSounds.length ? introSounds[index] : null;

		if (soundName == null)
			return;

		var file = countdownAsset(soundName, false);

		if (file == null)
		{
			Log.warn('[PlayState] countdown: falta el sonido ${Paths.sound(soundName)}');
			return;
		}

		FlxG.sound.play(file, 0.6);
	}

	// GETTERS Y SETTERS

	/**
	 * Vida del jugador, 0..1 (la del HUD).
	 */
	public var health(get, set):Float;

	/**
	 * Posicion del compas actual, como en Codename / Psych.
	 */
	public var curBeat(get, never):Int;
	public var curStep(get, never):Int;
	public var curSection(get, never):Int;
	public var curMeasure(get, never):Int;

	public var healthBar(get, never):HealthBar;
	public var iconP1(get, never):HealthIcon;
	public var iconP2(get, never):HealthIcon;
	public var timeBar(get, never):flixel.ui.FlxBar;
	public var timeTxt(get, never):FlxText;
	public var scoreTxt(get, never):FlxText;
	public var missesTxt(get, never):FlxText;
	public var accuracyTxt(get, never):FlxText;

	function get_curBeat():Int
		return Conductor.currentBeat;

	function get_curStep():Int
		return Conductor.currentStep;

	function get_curSection():Int
		return Std.int(Conductor.currentBeat / 4);

	function get_curMeasure():Int
		return get_curSection();

	function get_healthBar():HealthBar
		return hud == null ? null : hud.healthBar;

	function get_iconP1():HealthIcon
		return hud == null ? null : hud.iconPlayer;

	function get_iconP2():HealthIcon
		return hud == null ? null : hud.iconOpponent;

	function get_timeBar():flixel.ui.FlxBar
		return hud == null ? null : hud.timeBar;

	function get_timeTxt():FlxText
		return hud == null ? null : hud.timeText;

	function get_scoreTxt():FlxText
		return hud == null ? null : hud.scoreTxt;

	function get_missesTxt():FlxText
		return hud == null ? null : hud.missesTxt;

	function get_accuracyTxt():FlxText
		return hud == null ? null : hud.accuracyTxt;

	function get_health():Float
		return hud == null ? PlayHUD.START_HEALTH : hud.health;

	function set_health(value:Float):Float
	{
		if (hud != null)
			hud.setHealth(value);

		return get_health();
	}
}
