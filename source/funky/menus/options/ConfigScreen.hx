package funky.menus.options;

/** Una pantalla del arbol de opciones (como un TreeMenuScreen de Codename). */
class ConfigScreen
{
	public var title:String;
	public var desc:String;
	public var items:Array<ConfigItem>;
	public var selected:Int = 0;
	/** Imagen de fondo de esta pantalla (ruta dentro de assets/images/, sin .png). null = la de por defecto del host. */
	public var background:Null<String> = null;

	public function new(title:String, desc:String, items:Array<ConfigItem>)
	{
		this.title = title;
		this.desc = desc;
		this.items = items;
	}
}
