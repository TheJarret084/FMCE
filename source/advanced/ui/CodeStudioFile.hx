package advanced.ui;

class CodeStudioFile
{
	public var name:String;
	public var path:String;
	public var content:String;
	public var editable:Bool;
	public var kind:String;
	public var readOnlyReason:String;

	public function new(
		name:String,
		content:String = "",
		?path:String = "",
		editable:Bool = true,
		?kind:String = "text",
		?readOnlyReason:String = "")
	{
		this.name = name;
		this.content = content;
		this.path = path;
		this.editable = editable;
		this.kind = kind;
		this.readOnlyReason = readOnlyReason == null ? "" : readOnlyReason;
	}
}
