package funky.menus.options;

enum ConfigKind
{
	ACTION;
	CHECK;
	NUMBER;
	SLIDER;
	SEPARATOR;
}

/** Una fila del menu de opciones (estilo Codename: accion, checkbox, numero, slider, separador). */
class ConfigItem
{
	public var kind:ConfigKind;
	public var label:String = "";
	public var desc:String = "";
	public var color:Int = 0xFFFFFFFF;
	public var suffix:String = "";

	/** Icono a la izquierda (creditos): URL a descargar y asset de respaldo en images/credits/. */
	public var hasIcon:Bool = false;
	public var iconUrl:Null<String>;
	public var iconAsset:Null<String>;

	public var onSelect:Void->Void;
	public var getBool:Void->Bool;
	public var setBool:Bool->Void;
	public var getNum:Void->Float;
	public var setNum:Float->Void;
	/** Si existe, reemplaza el texto de la fila cada frame (ej: "CARRIL 1: A"). */
	public var dynamicLabel:Void->String;

	public var min:Float = 0;
	public var max:Float = 1;
	public var step:Float = 1;
	public var decimals:Int = 0;
	public var percent:Bool = false;

	function new(kind:ConfigKind)
	{
		this.kind = kind;
	}

	public static function action(label:String, desc:String, onSelect:Void->Void):ConfigItem
	{
		var item = new ConfigItem(ACTION);
		item.label = label;
		item.desc = desc;
		item.onSelect = onSelect;
		return item;
	}

	/** Accion que abre otra pantalla: lleva " >" al final como en Codename. */
	public static function submenu(label:String, desc:String, onSelect:Void->Void):ConfigItem
	{
		var item = action(label, desc, onSelect);
		item.suffix = " >";
		return item;
	}

	public static function check(label:String, desc:String, get:Void->Bool, set:Bool->Void):ConfigItem
	{
		var item = new ConfigItem(CHECK);
		item.label = label;
		item.desc = desc;
		item.getBool = get;
		item.setBool = set;
		return item;
	}

	public static function number(label:String, desc:String, min:Float, max:Float, step:Float, decimals:Int, get:Void->Float, set:Float->Void):ConfigItem
	{
		var item = new ConfigItem(NUMBER);
		item.label = label;
		item.desc = desc;
		item.min = min;
		item.max = max;
		item.step = step;
		item.decimals = decimals;
		item.getNum = get;
		item.setNum = set;
		return item;
	}

	/** Slider 0..1 en pasos de `step`, mostrado como porcentaje. */
	public static function slider(label:String, desc:String, step:Float, get:Void->Float, set:Float->Void):ConfigItem
	{
		var item = new ConfigItem(SLIDER);
		item.label = label;
		item.desc = desc;
		item.step = step;
		item.percent = true;
		item.getNum = get;
		item.setNum = set;
		return item;
	}

	public static function separator():ConfigItem
	{
		return new ConfigItem(SEPARATOR);
	}

	public function valueText():String
	{
		if (getNum == null) return "";
		var v = getNum();
		if (percent) return Std.int(Math.round(v * 100)) + "%";
		var p = Math.pow(10, decimals);
		var shown = Math.round(v * p) / p;
		var text = Std.string(shown);
		if (decimals > 0 && text.indexOf(".") < 0) text += ".0";
		return "<  " + text + "  >";
	}
}
