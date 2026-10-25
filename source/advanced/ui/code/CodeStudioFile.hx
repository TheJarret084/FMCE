package advanced.ui.code;

/** Un archivo abierto en CodeStudio. `content` es el texto tal cual va a disco; el editor trabaja con `editorText()`. */
class CodeStudioFile
{
	public var name:String;
	public var path:String;
	public var content:String;
	public var editable:Bool;
	/** "haxe", "json" o "text". */
	public var kind:String;
	public var readOnlyReason:String;
	/** Contenido que hay en disco. null = archivo nuevo que todavia no se guardo. */
	public var saved:Null<String>;
	/** Cerrar una pestana con cambios pide un segundo intento: true despues del primero. */
	public var closeArmed:Bool = false;
	public var crlf(default, null):Bool;

	public var dirty(get, never):Bool;
	public var baseName(get, never):String;

	public function new(name:String, content:String = "", path:String = "", editable:Bool = true, kind:String = "text", readOnlyReason:String = "",
			unsaved:Bool = false)
	{
		this.name = name;
		this.content = content == null ? "" : content;
		this.path = path;
		this.editable = editable;
		this.kind = kind == null ? "text" : kind;
		this.readOnlyReason = readOnlyReason == null ? "" : readOnlyReason;
		this.saved = unsaved ? null : this.content;
		this.crlf = this.content.indexOf("\r\n") >= 0;
	}

	function get_dirty():Bool
		return saved == null || content != saved;

	function get_baseName():String
	{
		var i = name.lastIndexOf("/");
		return i < 0 ? name : name.substr(i + 1);
	}

	/** Texto para el editor (siempre con \n). */
	public function editorText():String
		return StringTools.replace(content, "\r\n", "\n");

	/** Guarda lo que escribio el editor devolviendole su tipo de salto de linea original. */
	public function setFromEditor(text:String):Void
		content = crlf ? StringTools.replace(text, "\n", "\r\n") : text;

	public function markSaved():Void
	{
		saved = content;
		closeArmed = false;
	}

	public function kindLabel():String
	{
		return switch (kind)
		{
			case "haxe": "Haxe";
			case "json": "JSON";
			default: "Texto";
		};
	}
}
