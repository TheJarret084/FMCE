package advanced.ui.code;

class CodeStudioFile
{
	public var name:String;
	public var path:String;
	public var content:String;
	public var editable:Bool;

	public var kind:String;
	public var readOnlyReason:String;

	public var saved:Null<String>;

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

	public function editorText():String
		return StringTools.replace(content, "\r\n", "\n");

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
			default: CodeLang.t("kind.text", null, "Texto");
		};
	}
}
