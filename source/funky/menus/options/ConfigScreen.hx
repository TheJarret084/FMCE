package funky.menus.options;

class ConfigScreen
{
	public var title:String;
	public var desc:String;
	public var items:Array<ConfigItem>;
	public var selected:Int = 0;

	public var background:Null<String> = null;

	public function new(title:String, desc:String, items:Array<ConfigItem>)
	{
		this.title = title;
		this.desc = desc;
		this.items = items;
	}
}
