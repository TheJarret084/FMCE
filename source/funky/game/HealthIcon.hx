package funky.game;

class HealthIcon extends LevelSprite
{

	public static inline var FIT:Float = 96;
	public static inline var LOSE_BELOW:Float = 0.2;
	public static inline var WIN_ABOVE:Float = 0.8;

	static final NORMAL_NAMES = ["anim0"];
	static final LOSING_NAMES = ["anim1"];
	static final WINNING_NAMES = ["anim2"];

	public var isPlayer(default, null):Bool;

	public var state(default, null):String = "";

	var baseScale:Float = 1;
	var normalAnim:Null<String> = null;
	var losingAnim:Null<String> = null;
	var winningAnim:Null<String> = null;
	var levelDirectory:Null<String>;

	public function new(levelDir:Null<String>, name:Null<String>, isPlayer:Bool)
	{
		super();
		this.isPlayer = isPlayer;
		this.levelDirectory = levelDir;
		scrollFactor.set();
		if (levelDir != null && name != null && name != "") load(levelDir, name);

		if (loaded)
		{
			normalAnim = pick(NORMAL_NAMES);
			if (normalAnim == null) normalAnim = firstAnim;
			losingAnim = pick(LOSING_NAMES);
			winningAnim = pick(WINNING_NAMES);
			baseScale = FIT / Math.max(1, Math.max(frameWidth, frameHeight));
			setSpriteScale(baseScale);
		}
		else
		{

			makeGraphic(Std.int(FIT), Std.int(FIT), isPlayer ? 0xFF64DDAA : 0xFFE0505A);
			baseScale = 1;
		}

		antialiasing = true;

		setState("anim0");
	}

	function pick(names:Array<String>):Null<String>
	{
		for (name in names) if (hasAnim(name)) return name;
		return null;
	}

	public function updateHealth(playerHealth:Float):Void
	{
		var mine = isPlayer ? playerHealth : 1 - playerHealth;
		setState(mine < LOSE_BELOW ? "anim1" : (mine > WIN_ABOVE ? "anim2" : "anim0"));
	}

	public function setState(next:String):Void
	{
		if (next == state) return;
		state = next;
		if (!loaded) return;
		var anim = switch (next)
		{
			case "anim1": losingAnim;
			case "anim2": winningAnim;
			default: normalAnim;
		};
		if (anim == null) anim = normalAnim;
		if (anim != null) playAnim(anim, true);
	}

	public function bop(amount:Float = 1.2):Void
	{
		scale.set(baseScale * amount, baseScale * amount);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var target = baseScale;
		var rate = Math.exp(-elapsed * 9);
		var next = target + (scale.x - target) * rate;
		scale.set(next, next);
	}

	public function changeIcon(name:String = ""):Void
	{
		if (name == "" || levelDirectory == null) return;

		if (!load(levelDirectory, name))
		{
			normalAnim = null;
			losingAnim = null;
			winningAnim = null;
			return;
		}

		normalAnim = pick(NORMAL_NAMES);
		if (normalAnim == null) normalAnim = firstAnim;

		losingAnim = pick(LOSING_NAMES);
		winningAnim = pick(WINNING_NAMES);

		baseScale = FIT / Math.max(1, Math.max(frameWidth, frameHeight));

		setSpriteScale(baseScale);

		state = "";
		setState("anim0");

		antialiasing = true;

	}
}
