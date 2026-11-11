package funkin.backend.scripting;

class Script {
	public static function create(path:String):Script return new DummyScript(path);
	public static function fromString(code:String, path:String):Script return new DummyScript(path);

	public var path:String;
	public function new(?path:String) { this.path = path; }
	public function set(name:String, value:Dynamic):Void {}
	public function get(name:String):Dynamic return null;
	public function call(name:String, ?args:Array<Dynamic>):Dynamic return null;
	public function load():Void {}
	public function destroy():Void {}
}
