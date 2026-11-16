package funkin.editors.charter;

import flixel.FlxCamera;
import flixel.FlxG;
import funkin.backend.chart.Chart;
import funkin.backend.system.Conductor;
import funky.core.Log;
import funky.game.Eventos;
import funky.game.SongData;
import funky.game.Stage;
import funky.menus.LoadingOverlay;

/**
 * Vista previa EN VIVO dentro del charter (port nativo del "Seamless Charter"): el escenario (scene.json), sus objetos y los eventos
 * se ven detras de la grilla mientras tocas o recorres la cancion. Las notas hacen cantar a los objetos de su strumline (0 jugador,
 * 1 oponente, 2+ extra), igual que en el juego, y los eventos del charter se ejecutan con el mismo `Eventos` del juego.
 *
 * No usa PlayState: no cambia de pantalla, no vuelve a cargar la cancion y no cuesta nada si se apaga (`enabled = false`).
 * El escenario se arma en pocos frames detras de una pantalla de carga (LoadingOverlay) para que el charter abra rapido.
 */
class CharterPreview {
	/** Se recuerda mientras el juego este abierto. */
	public static var enabled:Bool = true;

	/** Segundos sin moverse hacia atras antes de reconstruir el escenario (un salto atras obliga a reiniciar los eventos). */
	static inline var REBUILD_DELAY:Float = 0.3;

	/** Cada cuanto se revisa (en pausa) si cambiaron notas o eventos. */
	static inline var CHECK_EVERY:Float = 0.5;

	/** Si el charter avanza mas pasos que esto de un frame, es un salto: no se hace cantar a todas las notas del medio. */
	static inline var JUMP_STEPS:Float = 16;

	public var camera(default, null):FlxCamera;
	public var stage(default, null):Null<Stage>;

	var charter:Charter;
	var eventos:Null<Eventos>;
	var song:Null<SongData>;

	var overlay:Null<LoadingOverlay>;
	var phase:Int = 0;
	var overlayTimer:Float = 0;

	var notes:Array<CharterNote> = [];
	var nextNote:Int = 0;
	var holdEnds:Array<Float> = [];

	var lastStep:Float = 0;
	var rebuildIn:Float = -1;
	var checkIn:Float = CHECK_EVERY;
	var signature:String = "";
	var builtOnce:Bool = false;

	public function new(charter:Charter) {
		this.charter = charter;
	}

	/** Crea la camara (detras de las del charter) y arranca la carga del escenario. */
	public function create():Void {
		camera = new FlxCamera();
		camera.bgColor = 0xFF000000;
		FlxG.cameras.add(camera, false);
		FlxG.cameras.list.remove(camera);
		FlxG.cameras.list.insert(0, camera);
		camera.antialiasing = true;

		applyVisibility();
		if (enabled) startLoading();
	}

	/** Prende o apaga la vista previa (menu Ver). Apagada no actualiza nada. */
	public function setEnabled(value:Bool):Void {
		enabled = value;
		applyVisibility();
		if (enabled && stage == null && phase == 0) startLoading();
	}

	function applyVisibility():Void {
		camera.visible = enabled;
		// Con escenario: la grilla se ve sobre el escenario oscurecido; sin escenario: el fondo de siempre.
		charter.charterCamera.bgColor = enabled ? 0x00000000 : 0xFF000000;
		charter.charterBG.color = enabled ? 0xFF000000 : 0xFF181818;
		charter.charterBG.alpha = enabled ? 0.5 : 1;
	}

	// CARGA (repartida en frames para que la pantalla de carga alcance a dibujarse)

	function startLoading():Void {
		overlay = new LoadingOverlay(TU.exists("editor.chart.loadingStage") ? TU.translate("editor.chart.loadingStage") : "Cargando escenario");
		overlay.cameras = [charter.uiCamera];
		charter.add(overlay);
		overlay.setProgress(0.05, "preparando");
		phase = 1;
	}

	function stepLoading(elapsed:Float):Void {
		switch (phase) {
			case 1:
				overlay.setProgress(0.2, "leyendo el nivel");
				phase = 2;
			case 2:
				try {
					song = SongData.fromPath(Chart.levelDir);
				} catch (e:Dynamic) {
					Log.warn('[CharterPreview] no se pudo leer el nivel: ' + e);
					song = null;
				}
				overlay.setProgress(0.45, "armando el escenario");
				phase = 3;
			case 3:
				buildStage();
				overlay.setProgress(0.85, "eventos");
				phase = 4;
			case 4:
				syncToChart(true);
				overlay.finish("listo");
				overlayTimer = 0.35;
				phase = 5;
			default:
				overlayTimer -= elapsed;
				if (overlayTimer <= 0) {
					charter.remove(overlay, true);
					overlay.destroy();
					overlay = null;
					phase = 0;
					builtOnce = true;
				}
		}
	}

	function buildStage():Void {
		if (song == null) return;
		var built = new Stage(song, camera);
		if (!built.loaded) {
			built.destroy();
			Log.info('[CharterPreview] el nivel no tiene scene.json con objetos: sin vista previa');
			return;
		}
		built.cameras = [camera];
		stage = built;
		charter.add(stage);
		eventos = new Eventos(song, stage);
	}

	function destroyStage():Void {
		if (eventos != null) eventos.destroy();
		eventos = null;
		if (stage != null) {
			charter.remove(stage, true);
			stage.destroy();
		}
		stage = null;
	}

	/** Reinicia el escenario y los eventos y los pone al dia con la posicion actual. */
	function rebuild():Void {
		destroyStage();
		buildStage();
		syncToChart(true);
	}

	// LISTAS DEL CHARTER

	function currentTime():Float
		return Conductor.getTimeForStep(Conductor.curStepFloat);

	function chartSignature():String {
		var h:Int = charter.notesGroup.members.length * 31 + charter.eventsGroup.members.length;
		for (n in charter.notesGroup.members) h = (h * 33) ^ Std.int(n.step * 64 + n.id * 7 + n.strumLineID + n.susLength * 13);
		for (e in charter.eventsGroup.members) h = (h * 33) ^ Std.int(e.step * 64 + e.events.length);
		return Std.string(h);
	}

	/** Reconstruye la lista de eventos para `Eventos` desde lo que hay en el charter, y la lista de notas ordenada. */
	function syncToChart(full:Bool):Void {
		signature = chartSignature();

		notes = charter.notesGroup.members.copy();
		notes.sort((a, b) -> a.step < b.step ? -1 : (a.step > b.step ? 1 : 0));
		seekNotes(Conductor.curStepFloat);
		holdEnds = [];
		lastStep = Conductor.curStepFloat;

		if (song == null) return;

		var groups = charter.eventsGroup.members.copy();
		groups.sort((a, b) -> a.step < b.step ? -1 : (a.step > b.step ? 1 : 0));
		var raw:Array<Dynamic> = [];
		for (g in groups) {
			var actions:Array<Dynamic> = [];
			for (e in g.events) {
				var action = Chart.eventToAction(e);
				if (action != null) actions.push(action);
			}
			if (actions.length > 0) raw.push({time: Conductor.getTimeForStep(g.step) / 1000, actions: actions});
		}
		song.events = raw;
		var packs:Array<Array<Dynamic>> = [];
		if (PlayState.SONG != null && PlayState.SONG.actionPacks != null)
			for (p in PlayState.SONG.actionPacks) {
				var list:Array<Dynamic> = [];
				if (p != null && p.actions != null)
					for (e in p.actions) {
						var action = e == null ? null : Chart.eventToAction(e);
						if (action != null) list.push(action);
					}
				packs.push(list);
			}
		song.actionPacks = packs;

		if (full && stage != null) {
			if (eventos != null) eventos.destroy();
			eventos = new Eventos(song, stage);
			stage.songTime = currentTime();
			eventos.update(stage.songTime);
		}
	}

	function seekNotes(step:Float):Void {
		nextNote = 0;
		while (nextNote < notes.length && notes[nextNote].step <= step) nextNote++;
	}

	// UPDATE

	public function update(elapsed:Float):Void {
		if (phase > 0) {
			stepLoading(elapsed);
			return;
		}
		if (!enabled || stage == null || !builtOnce) return;

		var playing = FlxG.sound.music != null && FlxG.sound.music.playing;
		var step = Conductor.curStepFloat;

		// Cambios en notas o eventos (solo en pausa, cada medio segundo).
		if (!playing) {
			checkIn -= elapsed;
			if (checkIn <= 0) {
				checkIn = CHECK_EVERY;
				if (chartSignature() != signature) {
					signature = "";
					rebuildIn = REBUILD_DELAY;
				}
			}
		}

		// Salto hacia atras: los eventos ya ejecutados no se pueden deshacer, hay que reiniciar (con espera, para no
		// reconstruir en cada frame mientras se arrastra la barra).
		if (step < lastStep - 0.01) {
			rebuildIn = REBUILD_DELAY;
			seekNotes(step);
		}
		lastStep = step;

		if (rebuildIn >= 0) {
			rebuildIn -= elapsed;
			if (rebuildIn < 0) {
				rebuild();
				return;
			}
		}

		var time = currentTime();
		stage.songTime = time;
		if (eventos != null) eventos.update(time);

		// Notas: cada una hace cantar a su strumline.
		var jumped = false;
		if (nextNote < notes.length && step - notes[nextNote].step > JUMP_STEPS) {
			seekNotes(step);
			jumped = true;
		}
		if (!jumped) {
			while (nextNote < notes.length && step >= notes[nextNote].step) {
				hit(notes[nextNote]);
				nextNote++;
			}
		}

		// Sustains: mientras dura la nota larga el personaje sigue cantando.
		for (line in 0...holdEnds.length) {
			var end = holdEnds[line];
			if (end > 0 && time < end) stage.hold(line);
			else if (end > 0) holdEnds[line] = 0;
		}
	}

	function hit(note:CharterNote):Void {
		var line = note.strumLineID;
		if (line < 0) return;
		stage.sing(line, note.id);
		if (note.susLength > 0) {
			while (holdEnds.length <= line) holdEnds.push(0);
			holdEnds[line] = Conductor.getTimeForStep(note.step + note.susLength);
		}
	}

	public function destroy():Void {
		if (eventos != null) eventos.destroy();
		eventos = null;
		stage = null;
	}
}
