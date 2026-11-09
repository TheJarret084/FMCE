package funky.core;

/** Dificultad = velocidad de scroll. */
class Difficulty
{
	public static final NAMES:Array<String> = ["EASY", "NORMAL", "HARD", "VERY HARD"];
	/** Clave estable de cada dificultad (para guardar puntajes): no cambia aunque se renombren los NAMES. */
	public static final KEYS:Array<String> = ["easy", "normal", "hard", "veryhard"];
	public static final SPEEDS:Array<Float> = [2.0, 2.6, 3.2, 4.0];

	public static var current:Int = 1;

	public static inline function name():String return NAMES[current];

	public static inline function key():String return KEYS[current];

	public static inline function speed():Float return SPEEDS[current];

	public static function next(step:Int = 1):Void
		current = (current + step + NAMES.length) % NAMES.length;
}
