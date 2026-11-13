package funky.scripting;

/** Script vacio (null object): se puede llamar sin comprobar null y no hace nada. Como el DummyScript de Codename. */
class DummyScript extends Script
{
	public function new(name:String = "dummy")
		super(name, "Dummy " + name, new Map<String, Dynamic>(), new Map<String, Dynamic>(), new Map<String, Dynamic>());

	override public function load():Void {}

	override public function call(func:String, ?args:Array<Dynamic>):Dynamic
		return null;

	override public function exists(func:String):Bool
		return false;

	override function report(message:String):Void {}
}
