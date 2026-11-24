package funky.editors.charter;
import funky.game.PlayState;

import flixel.FlxCamera;
import flixel.FlxG;
import funky.backend.chart.Chart;
import funky.backend.system.Conductor;
import funky.backend.system.Log;
import funky.game.Eventos;
import funky.game.SongData;
import funky.game.SpriteBuilder;
import funky.game.SpriteCache;
import funky.game.Stage;
import haxe.ds.ObjectMap;
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

	/** Opacidad del fondo negro que va encima del escenario (0 = escenario a full, 0.8 = casi negro). */
	public static var dim:Float = 0.5;

	static final DIMS:Array<Float> = [0, 0.2, 0.35, 0.5, 0.65, 0.8];

	/**
	 * true = el escenario se dibuja en un area con la misma proporcion que el juego (centrada, con barras negras a los lados, como en el PlayState).
	 * false = ocupa toda la pantalla del charter.
	 */
	public static var letterbox:Bool = true;

	/** Proporcion (ancho / alto) que se usa si no se puede leer la del juego. */
	public static var fallbackAspect:Float = 16 / 9;

	/** Segundos sin moverse hacia atras antes de reconstruir el escenario (un salto atras obliga a reiniciar los eventos). */
	static inline var REBUILD_DELAY:Float = 0.3;

	/** Cada cuanto se revisa (en pausa) si cambiaron notas o eventos. */
	static inline var CHECK_EVERY:Float = 0.5;

	/** Si el charter avanza mas pasos que esto de un frame, es un salto: no se hace cantar a todas las notas del medio. */
	static inline var JUMP_STEPS:Float = 16;

	/** Camaras del PlayState (juego) que muestran el escenario: la del mundo y la de los objetos fixed. */
	public var camera(default, null):FlxCamera;
	public var hudCamera(default, null):FlxCamera;

	var game:funky.game.PlayState;
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
	var notesSig:Int = 0;
	var groupHash:ObjectMap<CharterEvent, Int> = new ObjectMap();
	var groupStep:ObjectMap<CharterEvent, Float> = new ObjectMap();
	var warmNames:Array<String> = [];
	var warmNext:Int = 0;
	var warmDir:String = "";
	var builtOnce:Bool = false;
	var fitW:Int = -1;
	var fitH:Int = -1;

	public function new(charter:Charter) {
		this.charter = charter;
	}

	/** Crea la camara (detras de las del charter) y arranca la carga del escenario. */
	public function create():Void {
		// El escenario es el del PlayState que esta detras del charter: se usan sus camaras y el es quien lo sostiene.
		game = funky.game.PlayState.instance;
		camera = game.camGame;
		hudCamera = game.camHUD;
		SpriteCache.attach();
		fitView();

		applyVisibility();
		if (enabled) startLoading();
	}

	/** true mientras carga el escenario (no se puede probar todavia). */
	public function isBusy():Bool
		return phase > 0;

	/**
	 * "Probar": deja un escenario NUEVO (el de la vista previa quedo a medias por los eventos), con sus eventos al inicio,
	 * a pantalla completa y se lo entrega al PlayState, que lo usa tal cual para el nivel.
	 */
	public function enterGame():Void {
		try {
			song = SongData.fromPath(Chart.levelDir);
		} catch (e:Dynamic) {
			Log.warn('[CharterPreview] no se pudo leer el nivel para probar: ' + e);
		}

		destroyStage();
		buildStage();

		for (c in [camera, hudCamera]) if (c != null) {
			c.x = 0;
			c.y = 0;
			c.setSize(FlxG.width, FlxG.height);
			c.visible = true;
		}
		if (stage != null) stage.setView(-1, -1);

		// Desde aqui el escenario y los eventos son del juego (el los destruye al terminar).
		stage = null;
		eventos = null;
	}

	/** El juego termino y descargo su escenario: se arma el de la vista previa en la posicion actual del charter. */
	public function resume():Void {
		fitView();
		applyVisibility();
		if (enabled && song != null && builtOnce) {
			buildStage();
			syncToChart(true);
		}
	}

	/** Prende o apaga la vista previa (menu Ver). Apagada no actualiza nada. */
	public function setEnabled(value:Bool):Void {
		enabled = value;
		applyVisibility();
		if (enabled && stage == null && phase == 0) startLoading();
	}

	/** Cambia cuanto se oscurece el escenario detras de la grilla. */
	public function setDim(value:Float):Void {
		dim = value < 0 ? 0 : (value > 1 ? 1 : value);
		applyVisibility();
	}

	/** Siguiente valor de oscurecimiento (menu Ver). Devuelve el nuevo valor. */
	public static function nextDim():Float {
		var index = -1;
		for (i in 0...DIMS.length)
			if (Math.abs(DIMS[i] - dim) < 0.001) {
				index = i;
				break;
			}
		dim = DIMS[(index + 1) % DIMS.length];
		return dim;
	}

	/** Prende o apaga las barras negras (menu Ver). */
	public function setLetterbox(value:Bool):Void {
		letterbox = value;
		fitView();
	}

	/** Proporcion del juego (ancho / alto): la del modo de escala del juego si se conoce, si no 16:9. */
	static function gameAspect():Float {
		var mode = funky.backend.system.Main.scaleMode;
		if (mode != null && !Std.isOfType(mode, funky.editors.ui.UIScaleMode) && mode.gameSize != null && mode.gameSize.y > 0) {
			var aspect = mode.gameSize.x / mode.gameSize.y;
			if (aspect >= 1 && aspect <= 3) return aspect;
		}
		return fallbackAspect;
	}

	/** Acomoda la camara del escenario: toda la pantalla, o un rectangulo centrado con la proporcion del juego. */
	public function fitView():Void {
		if (camera == null) return;
		fitW = FlxG.width;
		fitH = FlxG.height;

		if (!letterbox) {
			setViewport(0, 0, FlxG.width, FlxG.height);
			if (stage != null) stage.setView(-1, -1);
			return;
		}

		var aspect = gameAspect();
		var w = FlxG.width;
		var h = Math.round(w / aspect);
		if (h > FlxG.height) {
			h = FlxG.height;
			w = Math.round(h * aspect);
		}
		setViewport(Math.round((FlxG.width - w) / 2), Math.round((FlxG.height - h) / 2), w, h);
		if (stage != null) stage.setView(w, h);
	}

	function setViewport(x:Float, y:Float, w:Int, h:Int):Void {
		for (c in [camera, hudCamera]) if (c != null) {
			c.x = x;
			c.y = y;
			c.setSize(w, h);
		}
	}

	function applyVisibility():Void {
		camera.visible = enabled;
		if (hudCamera != null) hudCamera.visible = enabled;
		// Con escenario: la grilla se ve sobre el escenario oscurecido; sin escenario: el fondo de siempre.
		charter.charterCamera.bgColor = enabled ? 0x00000000 : 0xFF000000;
		charter.charterBG.color = enabled ? 0xFF000000 : 0xFF181818;
		charter.charterBG.alpha = enabled ? dim : 1;
	}

	// CARGA (repartida en frames para que la pantalla de carga alcance a dibujarse)

	function startLoading():Void {
		makeOverlay();
		overlay.setProgress(0.05, "preparando");
		phase = 1;
	}

	function makeOverlay():Void {
		overlay = new LoadingOverlay(TU.exists("editor.chart.loadingStage") ? TU.translate("editor.chart.loadingStage") : "Cargando escenario");
		overlay.cameras = [charter.uiCamera];
		charter.add(overlay);
	}

	/** El tamano de la pantalla cambio: la pantalla de carga se arma de nuevo para quedar centrada (se dibuja con el ancho de FlxG). */
	public function onResized():Void {
		if (overlay == null) return;
		charter.remove(overlay, true);
		overlay.destroy();
		makeOverlay();
		overlay.setProgress(0.2, "cargando");
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
				prepareWarmup();
				overlay.setProgress(0.3, warmNames.length > 0 ? "sprites" : "armando el escenario");
				phase = warmNames.length > 0 ? 20 : 3;
			case 20:
				// Precarga de sprites repartida en frames (lo que hacia la pantalla de carga del juego): despues "Jugar ya" no carga nada.
				var start = haxe.Timer.stamp();
				while (warmNext < warmNames.length) {
					var name = warmNames[warmNext++];
					try {
						if (SpriteBuilder.videoCount(warmDir, name) == 0) SpriteCache.preload(warmDir, name);
					} catch (e:Dynamic) {
						Log.warn('[CharterPreview] fallo precargando "' + name + '": ' + e);
					}
					overlay.setProgress(0.3 + 0.5 * (warmNext / warmNames.length), "sprites");
					if (haxe.Timer.stamp() - start >= 0.012) return;
				}
				overlay.setProgress(0.8, "armando el escenario");
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

	/** Arma el cache de sprites del nivel (si no estaba ya armado, por ejemplo al volver del juego) y lista lo que hay que precargar. */
	function prepareWarmup():Void {
		warmNames = [];
		warmNext = 0;
		if (song == null) return;

		// Se usa el mismo texto de ruta que usan el Stage y el juego (song.levelDir), para que el cache los reconozca.
		warmDir = song.levelDir != null ? song.levelDir : Chart.levelDir;
		if (SpriteCache.isWarm(warmDir)) return;

		SpriteCache.begin(warmDir);
		var present = SpriteBuilder.listSprites(warmDir);
		warmNames = [for (name in SpriteCache.referenced(song)) if (present.indexOf(name) >= 0) name];
	}

	function buildStage():Void {
		if (song == null) return;
		var built = new Stage(song, hudCamera);
		if (!built.loaded) {
			built.destroy();
			Log.info('[CharterPreview] el nivel no tiene scene.json con objetos: sin vista previa');
			return;
		}
		built.cameras = [camera];
		stage = built;
		fitView();
		// Lo sostiene el PlayState (detras del charter): queda en sus camaras, debajo de todo lo del charter.
		game.insert(0, stage);
		game.stage = stage;
		eventos = new Eventos(song, stage);
		game.eventos = eventos;
	}

	function destroyStage():Void {
		if (eventos != null) {
			if (game != null && game.eventos == eventos) game.eventos = null;
			eventos.destroy();
		}
		eventos = null;
		if (stage != null) {
			if (game != null) {
				game.remove(stage, true);
				if (game.stage == stage) game.stage = null;
			}
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

	static inline function mix(h:Int, v:Int):Int
		return (h * 31 + v) | 0;

	static function hashText(h:Int, text:String):Int {
		for (i in 0...text.length) h = mix(h, text.charCodeAt(i));
		return h;
	}

	/** Firma de las notas (posicion, lane, strumline, sustain): cambia si se agrega, mueve o borra alguna. */
	function notesSignature():Int {
		var h = charter.notesGroup.members.length;
		for (n in charter.notesGroup.members) h = mix(h, Std.int(n.step * 64 + n.id * 7 + n.strumLineID + n.susLength * 13));
		return h;
	}

	/**
	 * Compara los eventos del charter con la ultima revision y devuelve el step mas temprano donde cambio algo
	 * (Math.POSITIVE_INFINITY si no cambio nada). Un evento movido cuenta tanto en su lugar viejo como en el nuevo.
	 */
	function earliestEventChange():Float {
		var earliest = Math.POSITIVE_INFINITY;
		var hashes = new ObjectMap<CharterEvent, Int>();
		var steps = new ObjectMap<CharterEvent, Float>();

		for (g in charter.eventsGroup.members) {
			if (g == null) continue;
			var h = mix(Std.int(g.step * 64), g.events.length);
			for (e in g.events) {
				h = hashText(h, e.name);
				if (e.params != null) for (p in e.params) h = hashText(h, Std.string(p));
			}
			hashes.set(g, h);
			steps.set(g, g.step);

			var before = groupHash.get(g);
			if (before == null || before != h) {
				earliest = Math.min(earliest, g.step);
				var oldStep = groupStep.get(g);
				if (oldStep != null) earliest = Math.min(earliest, oldStep);
			}
		}

		for (g in groupHash.keys())
			if (!hashes.exists(g)) earliest = Math.min(earliest, groupStep.get(g));

		groupHash = hashes;
		groupStep = steps;
		return earliest;
	}

	/** Hay algun evento entre from (sin incluir) y to (incluido)? Sirve para saber si un salto hacia atras obliga a reiniciar el escenario. */
	function eventsBetween(from:Float, to:Float):Bool {
		for (g in charter.eventsGroup.members)
			if (g != null && g.step > from && g.step <= to) return true;
		return false;
	}

	/** Reconstruye la lista de eventos para `Eventos` desde lo que hay en el charter, y la lista de notas ordenada. */
	function syncToChart(full:Bool):Void {
		if (full) {
			notesSig = notesSignature();
			earliestEventChange();
		}

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
		var packs:Array<funky.backend.chart.ChartData.ChartActionPack> = [];
		if (PlayState.SONG != null && PlayState.SONG.actionPacks != null)
			for (p in PlayState.SONG.actionPacks) {
				var list:Array<Dynamic> = [];
				if (p != null && p.actions != null)
					for (e in p.actions) {
						var action = e == null ? null : Chart.eventToAction(e);
						if (action != null) list.push(action);
					}
				packs.push({actions: cast list});
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
		if (camera != null && (FlxG.width != fitW || FlxG.height != fitH)) fitView();

		if (phase > 0) {
			stepLoading(elapsed);
			return;
		}
		if (!enabled || stage == null || !builtOnce) return;

		var playing = FlxG.sound.music != null && FlxG.sound.music.playing;
		var step = Conductor.curStepFloat;

		// Cambios en notas o eventos (solo en pausa, cada medio segundo). Reconstruir el escenario es lo caro, asi que solo se hace
		// si cambio un evento que YA paso (no se puede deshacer). Notas o eventos que faltan por venir solo refrescan las listas.
		if (!playing && rebuildIn < 0) {
			checkIn -= elapsed;
			if (checkIn <= 0) {
				checkIn = CHECK_EVERY;

				var notesChanged = false;
				var sigNow = notesSignature();
				if (sigNow != notesSig) {
					notesSig = sigNow;
					notesChanged = true;
				}

				var earliest = earliestEventChange();
				if (earliest <= step + 0.001) rebuildIn = REBUILD_DELAY;
				else if (earliest != Math.POSITIVE_INFINITY || notesChanged) {
					syncToChart(false);
					if (earliest != Math.POSITIVE_INFINITY && stage != null) {
						if (eventos != null) eventos.destroy();
						eventos = new Eventos(song, stage);
						eventos.skipTo(currentTime());
					}
				}
			}
		}

		// Salto hacia atras: los eventos ya ejecutados no se pueden deshacer, asi que solo se reinicia el escenario si entre
		// la posicion nueva y la vieja habia eventos (con espera, para no reconstruir en cada frame mientras se arrastra la barra).
		if (step < lastStep - 0.01) {
			if (eventsBetween(step, lastStep)) rebuildIn = REBUILD_DELAY;
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
		if (overlay != null) {
			charter.remove(overlay, true);
			overlay.destroy();
			overlay = null;
		}
		destroyStage();
		camera = null;
		hudCamera = null;
		game = null;
	}
}
