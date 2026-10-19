package funky.backend.chart;

/** Una nota del chart ya normalizada. `time` y `length` van en milisegundos. */
typedef FNMMNote = {
	var time:Float;
	var lane:Int;
	var length:Float;
	var mustPress:Bool;

	/** Strumline: 0 jugador, 1 oponente, 2+ extras (CPU). Si falta, sale de `mustPress`. */
	@:optional var line:Int;

		/** Indice de `action_packs` (events.json) que corre al acertar / fallar la nota. -1 o falta = ninguno. */
		@:optional var onPress:Int;
		@:optional var onMiss:Int;
}
