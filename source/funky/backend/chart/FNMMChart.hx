package funky.backend.chart;

/**
 * Chart normalizado que consume PlayState. Todos los tiempos (`FNMMNote.time`,
 * `FNMMNote.length`) estan en milisegundos, sin importar el formato de origen.
 */
typedef FNMMChart = {
	var name:String;
	var bpm:Float;
	var notes:Array<FNMMNote>;
	var events:Array<Dynamic>;
	var musicPath:Null<String>;

	/** Voces separadas (`music/Voices.ogg`), opcional. */
	@:optional var voicesPath:Null<String>;

	/** Carpeta del nivel en disco (de aca salen `sprites/<nombre>/`). null si no aplica. */
	@:optional var levelDir:Null<String>;
	/** Cantidad de lanes por strumline. 4 si no se sabe. */
	@:optional var laneCount:Int;
	/** Nombre de la carpeta de sprites del icono del jugador / del oponente. */
	@:optional var iconPlayer:Null<String>;
	@:optional var iconOpponent:Null<String>;
	/** Pasos por beat (`meta.stepsPerBeat` o `npb` del chart). 4 si no se sabe. */
	@:optional var stepsPerBeat:Float;
	/** `action_packs` de events.json (para `RunActionPack`). */
	@:optional var actionPacks:Array<Array<Dynamic>>;
	/** Nombre de `scene.json` dentro de meta (`stage`), o null si el nivel no trae escena. */
	@:optional var stage:Null<String>;
	/** Color de la tarjeta (`meta.color`), tal cual. */
	@:optional var color:Null<String>;
}
