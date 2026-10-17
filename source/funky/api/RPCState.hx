package funky.api;

enum RPCState
{
	Menu;
	Freeplay;
	Story;
	Settings;
	Credits;

	Pause(song:String);

	Playing(
		song:String,
		difficulty:String,
		icon:String,
		smallIcon:String,
		withTime:Bool
	);

	GameOverFade(song:String, misses:Int);

	GameOver(song:String, misses:Int, willRestart:Bool);

	Custom(
		details:String,
		state:String,
		icon:String,
		smallIcon:String,
		withTime:Bool,
		endTimestamp:Float
	);
}