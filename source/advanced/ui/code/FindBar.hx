package advanced.ui.code;

import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;

class FindBar extends FlxSpriteGroup
{
	public var isOpen(default, null):Bool = false;

	public var onToggle:Void->Void;

	var editor:CodeEditor;
	var input:TextField;
	var root:Sprite;
	var info:FlxText;
	var frozenText:FlxText;
	var caseButton:CodeButton;
	var barY:Int;
	var barW:Int;
	var caseSensitive:Bool = false;
	var frozen:Bool = false;

	public function new(overlay:Sprite, editor:CodeEditor, y:Int, w:Int)
	{
		super();
		this.editor = editor;
		barY = y;
		barW = w;

		add(CodeDraw.rect(0, y, w, CodeTheme.FIND_H, CodeTheme.MENU));
		add(CodeDraw.rect(0, y + CodeTheme.FIND_H - 1, w, 1, CodeTheme.BORDER));
		add(CodeDraw.label(12, y + 9, CodeLang.t("find.label", null, "Buscar"), CodeTheme.FONT_SMALL + 1, CodeTheme.MUTED));
		add(CodeDraw.rect(76, y + 5, 300, 24, CodeTheme.EDITOR));
		add(CodeDraw.rect(76, y + 28, 300, 1, CodeTheme.ACCENT));
		frozenText = CodeDraw.label(82, y + 8, "", CodeTheme.FONT_SMALL + 1, CodeTheme.TEXT);
		frozenText.visible = false;
		add(frozenText);

		caseButton = new CodeButton(386, y + 5, 34, 24, "Aa", function()
		{
			caseSensitive = !caseSensitive;
			caseButton.toggled = caseSensitive;
			search(false);
		});
		add(caseButton);
		add(new CodeButton(424, y + 5, 70, 24, CodeLang.t("find.prev", null, "◄ Ant"), function() step(false)));
		add(new CodeButton(498, y + 5, 70, 24, CodeLang.t("find.next", null, "Sig ►"), function() step(true)));
		info = CodeDraw.label(580, y + 9, "", CodeTheme.FONT_SMALL + 1, CodeTheme.MUTED);
		add(info);
		add(new CodeButton(w - 34, y + 5, 26, 24, "×", close, CodeTheme.MUTED, 16));

		root = new Sprite();
		overlay.addChild(root);
		input = new TextField();
		input.type = TextFieldType.INPUT;
		input.multiline = false;
		input.wordWrap = false;
		input.background = false;
		input.embedFonts = CodeTheme.fontEmbedded();
		var fmt = new TextFormat(CodeTheme.fontName(), CodeTheme.FONT_SMALL + 2, CodeTheme.rgb(CodeTheme.TEXT));
		input.defaultTextFormat = fmt;
		input.x = 80;
		input.y = y + 7;
		input.width = 292;
		input.height = 22;
		input.addEventListener(Event.CHANGE, function(_) search(true));
		input.addEventListener(KeyboardEvent.KEY_DOWN, onInputKey);
		root.addChild(input);
		root.visible = false;
		visible = false;
	}

	public function open(prefill:String = ""):Void
	{
		var wasOpen = isOpen;
		isOpen = true;
		visible = true;
		root.visible = !frozen;
		if (prefill != "") input.text = prefill;
		if (prefill == "" && input.text == "")
		{

			var sel = editor.field.text.substring(editor.field.selectionBeginIndex, editor.field.selectionEndIndex);
			if (sel.length > 0 && sel.indexOf("\n") < 0) input.text = sel;
		}
		input.setSelection(prefill != "" ? input.text.length : 0, input.text.length);
		if (!frozen && flixel.FlxG.stage != null) flixel.FlxG.stage.focus = input;
		if (!wasOpen && onToggle != null) onToggle();
		search(true);
	}

	public function close():Void
	{
		if (!isOpen) return;
		isOpen = false;
		visible = false;
		root.visible = false;
		editor.focus();
		if (onToggle != null) onToggle();
	}

	public function freeze():Void
	{
		frozen = true;
		if (!isOpen) return;
		frozenText.text = input.text;
		frozenText.visible = true;
		root.visible = false;
	}

	public function thaw():Void
	{
		frozen = false;
		frozenText.visible = false;
		if (isOpen) root.visible = true;
	}

	function onInputKey(event:KeyboardEvent):Void
	{
		if (event.keyCode == Keyboard.ENTER || event.keyCode == Keyboard.NUMPAD_ENTER)
		{
			event.preventDefault();
			step(!event.shiftKey);
		}
	}

	function gotoQuery():Int
	{
		var q = input.text;
		if (q.length > 0 && q.charAt(0) == ":")
		{
			var n = Std.parseInt(q.substr(1));
			return n == null ? -2 : n;
		}
		return -1;
	}

	function search(fromStart:Bool):Void
	{
		var line = gotoQuery();
		if (line != -1)
		{
			if (line > 0)
			{
				editor.goToLine(line);
				info.text = CodeLang.t("find.goto", [line], "Ir a la línea {0}");
			}
			else
				info.text = CodeLang.t("find.typeLine", null, "Escribe un número de línea");
			return;
		}
		if (input.text == "")
		{
			info.text = "";
			return;
		}
		var idx = editor.find(input.text, true, caseSensitive, fromStart);
		updateInfo(idx);
	}

	function step(forward:Bool):Void
	{
		var line = gotoQuery();
		if (line != -1)
		{
			search(false);
			return;
		}
		if (input.text == "") return;
		var idx = editor.find(input.text, forward, caseSensitive);
		updateInfo(idx);
	}

	function updateInfo(idx:Int):Void
	{
		if (idx < 0)
		{
			info.text = CodeLang.t("find.noResults", null, "Sin resultados");
			info.color = CodeTheme.ERROR;
			return;
		}
		var m = editor.matchInfo(input.text, caseSensitive);
		info.text = CodeLang.t("find.matchCount", [m.current, m.total], "{0} de {1}");
		info.color = CodeTheme.MUTED;
	}

	override public function destroy():Void
	{
		if (root != null && root.parent != null) root.parent.removeChild(root);
		root = null;
		super.destroy();
	}
}
