package funky.core;

class Conductor
{
	private static var _bpm:Float = DEFAULT_BPM;

	public static final DEFAULT_BPM:Float = 100;
	public static final STEPS_PER_BEAT:Int = 4;

	public static var bpm(get, set):Float;
	public static var crochet:Float    = 600;
	public static var stepCrochet:Float = 150;
	public static var songPosition:Float = 0;

	public static var lastBeat:Int    = 0;
	public static var lastStep:Int    = 0;
	public static var currentBeat:Int = 0;
	public static var currentStep:Int = 0;

	public static var justHitStep(default, null):Bool = false;

	public static var justHitBeat(default, null):Bool = false;

	static function get_bpm():Float
	{
		return _bpm;
	}

	static function set_bpm(v:Float):Float
	{
		if (Math.isNaN(v) || v <= 0) return _bpm;

		_bpm = v;
		crochet = (60 / v) * 1000;
		stepCrochet = crochet / STEPS_PER_BEAT;
		return _bpm;
	}

	public static function update(songMs:Float):Void
	{
		songPosition = songMs;
		lastBeat = currentBeat;
		lastStep = currentStep;

		var safeStep = stepCrochet > 0 ? stepCrochet : 1;
		currentStep = Math.floor(songPosition / safeStep);
		currentBeat = Math.floor(currentStep / STEPS_PER_BEAT);

		justHitStep = currentStep != lastStep;
		justHitBeat = currentBeat != lastBeat;
	}

	public static function reset():Void
	{
		songPosition = 0;
		currentBeat  = 0;
		currentStep  = 0;
		lastBeat     = 0;
		lastStep     = 0;
		justHitStep  = false;
		justHitBeat  = false;
	}
}
