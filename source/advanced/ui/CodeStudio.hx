package advanced.ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;
import funky.api.DiscordClient;

class CodeStudio extends FlxSpriteGroup
{
	static inline var HEADER_H:Int = 50;
	static inline var SIDEBAR_W:Int = 270;
	static inline var OUTPUT_H:Int = 112;
	static inline var BG:Int = 0xFF090B0F;
	static inline var PANEL:Int = 0xFF11141A;
	static inline var HEADER:Int = 0xFF171B22;
	static inline var BORDER:Int = 0xFF292F3A;
	static inline var TEXT:Int = 0xFFE7E9ED;
	static inline var MUTED:Int = 0xFF8B919D;
	static inline var ACCENT:Int = 0xFF5B8CFF;
	static inline var WARN:Int = 0xFFFFC857;

	public var files:Array<CodeStudioFile> = [];
	public var currentFile(default, null):Int = -1;

	var onSave:CodeStudioFile->Bool;
	var onRun:CodeStudioFile->Void;
	var onPreview:Void->Void;
	var onNewScript:Void->CodeStudioFile;
	var editor:TextField;
	var jsonEditor:JsonInspector;
	var fileList:FlxText;
	var lineNumbers:FlxText;
	var output:FlxText;
	var status:FlxText;
	var title:FlxText;
	var suppressChange:Bool = false;
	var lastScroll:Int = -1;
	var lastCaret:Int = -1;
	var listRowHeight:Int = 22;

	public function new(
		?initialFiles:Array<CodeStudioFile>,
		?saveHandler:CodeStudioFile->Bool,
		?runHandler:CodeStudioFile->Void,
		?previewHandler:Void->Void,
		?newScriptHandler:Void->CodeStudioFile)
	{
		super();

		files = initialFiles != null ? initialFiles : [];
		onSave = saveHandler != null ? saveHandler : function(_) return true;
		onRun = runHandler != null ? runHandler : function(_) {};
		onPreview = previewHandler != null ? previewHandler : function() {};
		onNewScript = newScriptHandler != null ? newScriptHandler : function() return null;

		buildChrome();
		buildEditor();
		refreshFileList();

		if (files.length > 0) openFile(0);
		else setEditorText("");

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		DiscordClient.customPresence("Modo Avanzado", "Editor de nivel", "fmce", "", false);
	}

	function buildChrome():Void
	{
		add(box(0, 0, FlxG.width, FlxG.height, BG));
		add(box(0, 0, FlxG.width, HEADER_H, HEADER));
		add(box(0, HEADER_H, SIDEBAR_W, FlxG.height - HEADER_H, PANEL));
		add(box(SIDEBAR_W, HEADER_H, FlxG.width - SIDEBAR_W, FlxG.height - HEADER_H - OUTPUT_H, BG));
		add(box(SIDEBAR_W, FlxG.height - OUTPUT_H, FlxG.width - SIDEBAR_W, OUTPUT_H, PANEL));
		add(box(SIDEBAR_W, HEADER_H, 1, FlxG.height - HEADER_H, BORDER));

		title = label(16, 13, "FMCE Advanced", 18, TEXT);
		add(title);
		add(label(235, 16, "JSON / HAXE", 13, MUTED));

		var run = label(FlxG.width - 330, 13, "F5  GUARDAR  |  F6  PREVIEW SPRITES", 13, TEXT);
		run.alignment = FlxTextAlign.RIGHT;
		run.width = 310;
		add(run);

		add(label(18, 68, "NIVEL", 12, MUTED));
		fileList = label(18, 92, "", 14, TEXT);
		add(fileList);

		status = label(SIDEBAR_W + 18, FlxG.height - 27, "Ready", 12, MUTED);
		add(status);

		output = label(SIDEBAR_W + 18, FlxG.height - OUTPUT_H + 14, "OUTPUT\n[FMCE] Advanced ready.", 13, MUTED);
		add(output);

		var hint = label(18, FlxG.height - 54, "Ctrl+S guardar  |  Ctrl+N nuevo script  |  ESC volver", 11, MUTED);
		add(hint);
	}

	function buildEditor():Void
	{
		lineNumbers = label(SIDEBAR_W + 12, HEADER_H + 20, "1", 16, MUTED);
		lineNumbers.alignment = FlxTextAlign.RIGHT;
		lineNumbers.width = 34;
		add(lineNumbers);

		editor = new TextField();
		editor.type = TextFieldType.DYNAMIC;
		editor.multiline = true;
		editor.wordWrap = false;
		editor.selectable = true;
		editor.background = true;
		editor.backgroundColor = BG;
		editor.textColor = TEXT;
		editor.defaultTextFormat = new TextFormat("Courier New", 16, TEXT);
		editor.width = FlxG.width - SIDEBAR_W - 28;
		editor.height = FlxG.height - HEADER_H - OUTPUT_H - 24;
		editor.x = SIDEBAR_W + 56;
		editor.y = HEADER_H + 16;
		editor.addEventListener(Event.CHANGE, onEditorChange);
		FlxG.stage.addChild(editor);
	}

	inline function box(x:Float, y:Float, w:Float, h:Float, color:Int):FlxSprite
		return new FlxSprite(x, y).makeGraphic(Std.int(w), Std.int(h), color);

	inline function label(x:Float, y:Float, value:String, size:Int, color:Int):FlxText
	{
		var text = new FlxText(x, y, 0, value, size);
		text.setFormat(null, size, color, FlxTextAlign.LEFT);
		return text;
	}

	public function openFile(index:Int):Void
	{
		if (index < 0 || index >= files.length) return;
		currentFile = index;
		setEditorText(files[index].content);
		applyFileMode(files[index]);
		refreshFileList();
		updateTitle();
	}

	public function getCode():String
	{
		if (currentFile >= 0 && currentFile < files.length && files[currentFile].kind == "json" && jsonEditor != null)
			return jsonEditor.getJson();
		return editor != null ? editor.text : "";
	}

	public function save():Void
	{
		if (files.length == 0 || currentFile < 0) return;
		syncCurrentFile();
		var file = files[currentFile];
		if (!file.editable)
		{
			status.text = file.name + "  •  SOLO LECTURA";
			log("[FMCE] No se puede modificar " + file.name + ". " + file.readOnlyReason);
			return;
		}

		var ok = onSave(file);
		if (ok)
		{
			status.text = file.name + "  •  Guardado";
			log("[FMCE] Saved " + file.path);
		}
		else
			status.text = file.name + "  •  error al guardar";
	}

	public function run():Void
	{
		if (currentFile < 0 || currentFile >= files.length) return;
		syncCurrentFile();
		var file = files[currentFile];
		if (file.kind != "haxe")
		{
			log("[FMCE] F5 solo prepara Haxe. Los scripts todavía no se ejecutan en PlayState.");
			return;
		}
		onRun(file);
	}

	public function previewSprites():Void
	{
		onPreview();
	}

	public function log(message:String):Void
	{
		var lines = output.text.split("\n");
		lines.push(message);
		while (lines.length > 7) lines.shift();
		output.text = lines.join("\n");
	}

	function setEditorText(value:String):Void
	{
		suppressChange = true;
		editor.text = value != null ? value : "";
		editor.setSelection(0, 0);
		editor.scrollV = 1;
		suppressChange = false;
		updateEditorInfo();
	}

	function applyFileMode(file:CodeStudioFile):Void
	{
		if (jsonEditor != null)
		{
			remove(jsonEditor, true);
			jsonEditor = null;
		}

		if (file.kind == "json")
		{
			editor.visible = false;
			lineNumbers.visible = false;
			jsonEditor = new JsonInspector(file.content, function()
			{
				if (currentFile >= 0 && currentFile < files.length)
					files[currentFile].content = jsonEditor.getJson();
			});
			add(jsonEditor);
			status.text = file.name + "  •  JSON visual" + (file.editable ? "" : "  •  SOLO LECTURA");
			if (!file.editable) log("[FMCE] " + file.readOnlyReason);
			return;
		}

		editor.visible = true;
		lineNumbers.visible = true;
		editor.type = file.editable ? TextFieldType.INPUT : TextFieldType.DYNAMIC;
		editor.textColor = file.editable ? TEXT : MUTED;
		status.text = file.name + (file.editable ? "  •  Haxe / Visual Studio" : "  •  SOLO LECTURA");
		if (!file.editable) log("[FMCE] " + file.readOnlyReason);
	}

	function syncCurrentFile():Void
	{
		if (currentFile < 0 || currentFile >= files.length) return;
		if (files[currentFile].kind == "json" && jsonEditor != null)
		{
			if (jsonEditor.isValid()) files[currentFile].content = jsonEditor.getJson();
			return;
		}
		files[currentFile].content = editor.text;
	}

	function refreshFileList():Void
	{
		var out = "";
		for (i in 0...files.length)
		{
			var file = files[i];
			var marker = i == currentFile ? "> " : "  ";
			var lock = file.editable ? "" : "  [RO]";
			out += marker + file.name + lock;
			if (i < files.length - 1) out += "\n";
		}
		fileList.text = out;
	}

	function updateTitle():Void
	{
		if (currentFile < 0 || currentFile >= files.length)
		{
			title.text = "FMCE Advanced";
			return;
		}
		var file = files[currentFile];
		title.text = "FMCE Advanced  •  " + file.name;
	}

	function updateEditorInfo():Void
	{
		if (editor == null) return;
		var before = editor.text.substr(0, editor.caretIndex);
		var parts = before.split("\n");
		var line = parts.length;
		var column = parts[parts.length - 1].length + 1;
		var total = editor.text.split("\n").length;
		var name = currentFile >= 0 && currentFile < files.length ? files[currentFile].name : "untitled";
		status.text = name + "  •  Ln " + line + ", Col " + column + "  •  " + total + " lines";
		lineNumbers.text = [for (i in 1...total + 1) Std.string(i)].join("\n");
		lineNumbers.y = HEADER_H + 20 - (editor.scrollV - 1) * 19;
	}

	function onEditorChange(_):Void
	{
		if (suppressChange) return;
		syncCurrentFile();
		updateEditorInfo();
	}

	function onKeyDown(event:KeyboardEvent):Void
	{
		if (event.keyCode == Keyboard.F5)
		{
			event.preventDefault();
			save();
			return;
		}
		if (event.keyCode == Keyboard.F6)
		{
			event.preventDefault();
			previewSprites();
			return;
		}
		if (event.ctrlKey && event.keyCode == Keyboard.S)
		{
			event.preventDefault();
			save();
			return;
		}
		if (event.ctrlKey && event.keyCode == Keyboard.N)
		{
			event.preventDefault();
			var file = onNewScript();
			if (file != null)
			{
				files.push(file);
				files.sort(function(a, b) return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase()));
				openFile(files.indexOf(file));
				log("[FMCE] Nuevo script preparado: " + file.name);
			}
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (editor == null) return;

		if (lastScroll != editor.scrollV || lastCaret != editor.caretIndex)
		{
			lastScroll = editor.scrollV;
			lastCaret = editor.caretIndex;
			updateEditorInfo();
		}

		if (FlxG.mouse.justPressed && FlxG.mouse.x < SIDEBAR_W && FlxG.mouse.y >= 88)
		{
			var index = Std.int((FlxG.mouse.y - 88) / listRowHeight);
			if (index >= 0 && index < files.length) openFile(index);
		}
	}

	override public function destroy():Void
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		if (jsonEditor != null)
		{
			remove(jsonEditor, true);
			jsonEditor = null;
		}
		if (editor != null)
		{
			editor.removeEventListener(Event.CHANGE, onEditorChange);
			if (editor.parent != null) editor.parent.removeChild(editor);
			editor = null;
		}
		super.destroy();
	}
}
