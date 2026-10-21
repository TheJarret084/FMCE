package funkin.backend.chart;

/** Tipos de parametro que entiende la pantalla de eventos del charter. */
enum EventParamType {
	TString;
	TBool;
	TInt(?min:Int, ?max:Int, ?step:Float);
	TFloat(?min:Float, ?max:Float, ?step:Float, ?precision:Int);
	TStrumLine;
	TColorWheel;
	TDropDown(options:Array<String>);
	TCharacter;
	TStage;
	/** Indice dentro de `action_packs` (se elige en una lista). */
	TActionPack;
}

typedef EventParamInfo = {
	var name:String;
	var type:EventParamType;
	var defValue:Dynamic;
	/** Nombre de la propiedad dentro de `props` en events.json. */
	var key:String;
	var ?saveIfDefault:Bool;
}

/**
 * Los eventos del charter son las acciones de `events.json` de FMCE (ver docs/eventos.md):
 * el nombre del evento es el `type` de la accion y sus parametros son los `props`, en el orden de abajo.
 */
class EventsData {
	static final UNITS:Array<String> = ["seconds", "beats", "steps"];

	static inline function p(key:String, name:String, type:EventParamType, def:Dynamic):EventParamInfo
		return {key: key, name: name, type: type, defValue: def};

	static inline function transition():Array<EventParamInfo>
		return [
			p("transitionTime", "Duracion", TFloat(0, 9999, 0.25, 3), 0.0),
			p("transitionTimeUnit", "Unidad", TDropDown(UNITS), "seconds"),
			p("easingType", "Curva (default, quad, cubeOut...)", TString, "default")
		];

	public static var eventsList:Array<String> = [];
	static var defs:Map<String, Array<EventParamInfo>> = new Map();

	public static function reloadEvents():Void {
		defs = new Map();
		eventsList = [];
		function add(name:String, params:Array<EventParamInfo>) {
			defs.set(name, params);
			eventsList.push(name);
		}
		add("CameraSet", [
			p("mode", "Modo", TDropDown(["auto", "focus"]), "auto"),
			p("target", "Punto de camara (scene.json)", TInt(0, 999, 1), 0)
		].concat(transition()));
		add("CameraZoom", [p("value", "Zoom", TFloat(0.05, 10, 0.05, 3), 1.0)].concat(transition()));
		add("CameraShake", [
			p("shakes", "Sacudidas", TInt(1, 99, 1), 4),
			p("delay", "Retraso entre sacudidas", TFloat(0, 9999, 0.05, 3), 0.1),
			p("timeUnit", "Unidad", TDropDown(UNITS), "seconds"),
			p("strength", "Fuerza (px)", TFloat(0, 999, 1, 1), 10.0)
		]);
		add("ObjectPositionSet", [
			p("object", "Objeto (scene.json)", TInt(0, 999, 1), 0),
			p("transform", "Transformacion", TInt(0, 99, 1), 0)
		].concat(transition()));
		add("ObjectVisibilitySet", [
			p("object", "Objeto (scene.json)", TInt(0, 999, 1), 0),
			p("value", "Visible", TBool, true)
		]);
		add("ObjectOpacitySet", [
			p("object", "Objeto (scene.json)", TInt(0, 999, 1), 0),
			p("value", "Opacidad (0 a 1)", TFloat(0, 1, 0.05, 2), 1.0)
		].concat(transition()));
		add("ObjectAnimationSet", [
			p("object", "Objeto (scene.json)", TInt(0, 999, 1), 0),
			p("anim", "Animacion (0 = idle)", TInt(0, 999, 1), 0)
		]);
		add("ObjectSpriteSet", [
			p("object", "Objeto (scene.json)", TInt(0, 999, 1), 0),
			p("sprite", "Sprite (carpeta en sprites/)", TString, "")
		]);
		add("ObjectChartChange", [
			p("object", "Objeto (scene.json)", TInt(0, 999, 1), 0),
			p("strumLine", "Strumline (-1 ninguna, 0 jugador, 1 oponente)", TInt(-1, 99, 1), 0)
		]);
		add("BarIconChange", [
			p("target", "Icono (0 oponente, 1 jugador)", TInt(0, 1, 1), 1),
			p("sprite", "Sprite del icono", TString, "")
		]);
		add("ScreenFlash", [
			p("color_r", "Rojo", TInt(0, 255, 1), 255),
			p("color_g", "Verde", TInt(0, 255, 1), 255),
			p("color_b", "Azul", TInt(0, 255, 1), 255),
			p("alpha", "Opacidad (0 a 1)", TFloat(0, 1, 0.05, 2), 1.0),
			p("duration", "Duracion", TFloat(0, 9999, 0.25, 3), 0.5),
			p("timeUnit", "Unidad", TDropDown(UNITS), "seconds")
		]);
		add("RunActionPack", [p("actionPack", "Action pack", TActionPack, 0)]);
		// Los dos que faltaban: el juego ya los ejecuta (Eventos.hx) y vienen en los niveles .fnmm (sobre todo dentro de action packs).
		add("PlayerHealth", [
			p("operation", "Operacion (set, add, remove)", TDropDown(["set", "add", "remove"]), "set"),
			p("value", "Valor", TFloat(0, 9999, 0.5, 3), 0.0),
			p("minHealth", "Vida minima (solo remove)", TFloat(0, 9999, 0.5, 3), 0.0)
		]);
		add("GUI", [p("visible", "Visible", TBool, true)]);
	}

	public static function getEventParams(name:String):Array<EventParamInfo> {
		if (eventsList.length == 0) reloadEvents();
		var d = defs.get(name);
		return d == null ? [] : d;
	}

	public static function isKnown(name:String):Bool {
		if (eventsList.length == 0) reloadEvents();
		return defs.exists(name);
	}
}
