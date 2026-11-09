package advanced.ui.code;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.events.TextEvent;
import openfl.geom.Matrix;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.ui.Keyboard;

private typedef Snap =
{
	var text:String;
	var start:Int;
	var end:Int;
	var scroll:Int;
}

private class History
{
	public var undo:Array<Snap> = [];
	public var redo:Array<Snap> = [];
	public var base:Null<Snap> = null;
	public var caretStart:Int = 0;
	public var caretEnd:Int = 0;
	public var scroll:Int = 1;

	public function new() {}
}

/** Editor de texto: numeros de linea, linea actual, colores de sintaxis, deshacer/rehacer, auto-indentado y busqueda. */
class CodeEditor extends FlxSpriteGroup
{
	static inline var HL_MARGIN:Int = 30;
	static inline var MAX_HIGHLIGHT:Int = 400000;
	static inline var MAX_HISTORY:Int = 120;
	static inline var INDENT:String = "    ";

	/** El usuario cambio el texto. */
	public var onChange:Void->Void;
	/** Linea (1..), columna (1..) y caracteres seleccionados. */
	public var onCaret:Int->Int->Int->Void;

	public var file(default, null):Null<CodeStudioFile>;
	public var field(default, null):TextField;
	public var frozen(default, null):Bool = false;

	var overlay:Sprite;
	var box:Sprite;
	var gutter:TextField;
	var bg:FlxSprite;
	var gutterBg:FlxSprite;
	var gutterLine:FlxSprite;
	var curLine:FlxSprite;
	var errLine:FlxSprite;
	var snapshot:FlxSprite;

	var ex:Float;
	var ey:Float;
	var ew:Float;
	var eh:Float;

	var baseFmt:TextFormat;
	var gutterFmt:TextFormat;
	var colorFmts:Map<Int, TextFormat> = new Map();
	var spans:Array<Int> = [];
	var histories:Map<CodeStudioFile, History> = new Map();

	var hlDirty:Bool = false;
	var hlDelay:Float = 0;
	var appliedFirst:Int = -1;
	var appliedLast:Int = -1;
	var lastScroll:Int = -1;
	var lastCaret:Int = -1;
	var lastSel:Int = -1;
	var lastLines:Int = -1;
	var lineH:Float = 20;
	var errorLine:Int = -1;
	var suppress:Bool = false;
	var burstOpen:Bool = false;
	var burstTimer:Float = 0;
	/** true = hay que recolorear toda la ventana (editar, cambiar de archivo); false = solo las lineas nuevas al hacer scroll. */
	var hlFull:Bool = true;
	/** La rueda del mouse se uso en este frame: ese scroll es del usuario, no un salto raro de OpenFL. */
	var wheelTick:Bool = false;

	public function new(overlay:Sprite, x:Float, y:Float, w:Float, h:Float)
	{
		super();
		this.overlay = overlay;
		ex = x;
		ey = y;
		ew = w;
		eh = h;

		bg = CodeDraw.rect(x, y, w, h, CodeTheme.EDITOR);
		add(bg);
		gutterBg = CodeDraw.rect(x, y, CodeTheme.GUTTER_W, h, CodeTheme.EDITOR);
		add(gutterBg);
		gutterLine = CodeDraw.rect(x + CodeTheme.GUTTER_W - 1, y, 1, h, CodeTheme.BORDER);
		add(gutterLine);
		curLine = CodeDraw.rect(x, y, w, 20, CodeTheme.CURRENT_LINE);
		add(curLine);
		errLine = CodeDraw.rect(x, y, w, 20, CodeTheme.ERROR_LINE);
		errLine.visible = false;
		add(errLine);
		snapshot = new FlxSprite(x, y);
		snapshot.visible = false;
		snapshot.scrollFactor.set(0, 0);
		add(snapshot);

		var fontName = CodeTheme.fontName();
		baseFmt = new TextFormat(fontName, CodeTheme.EDITOR_FONT, CodeTheme.rgb(CodeTheme.SYN_DEFAULT));
		baseFmt.leading = 0;
		gutterFmt = new TextFormat(fontName, CodeTheme.EDITOR_FONT, CodeTheme.rgb(CodeTheme.DIM));
		gutterFmt.align = TextFormatAlign.RIGHT;
		gutterFmt.leading = 0;

		box = new Sprite();
		overlay.addChild(box);

		gutter = new TextField();
		gutter.type = TextFieldType.DYNAMIC;
		gutter.multiline = true;
		gutter.wordWrap = false;
		gutter.selectable = false;
		gutter.mouseEnabled = false;
		gutter.embedFonts = CodeTheme.fontEmbedded();
		gutter.defaultTextFormat = gutterFmt;
		gutter.text = "1";
		box.addChild(gutter);

		field = new TextField();
		field.type = TextFieldType.INPUT;
		field.multiline = true;
		field.wordWrap = false;
		field.selectable = true;
		field.background = false;
		field.border = false;
		field.tabEnabled = false;
		field.mouseWheelEnabled = true;
		field.embedFonts = CodeTheme.fontEmbedded();
		field.defaultTextFormat = baseFmt;
		field.text = "";
		field.addEventListener(Event.CHANGE, onFieldChange);
		field.addEventListener(TextEvent.TEXT_INPUT, onTextInput);
		field.addEventListener(MouseEvent.MOUSE_WHEEL, onWheel);
		box.addChild(field);

		place();
		box.visible = false;
		curLine.visible = false;
	}

	// ------------------------------------------------------------------ geometria

	/** Mueve/redimensiona el editor (cuando abres el buscador o la salida). */
	public function setRect(x:Float, y:Float, w:Float, h:Float):Void
	{
		ex = x;
		ey = y;
		ew = w;
		eh = h;
		bg.setPosition(x, y);
		CodeDraw.remake(bg, w, h, CodeTheme.EDITOR);
		gutterBg.setPosition(x, y);
		CodeDraw.remake(gutterBg, CodeTheme.GUTTER_W, h, CodeTheme.EDITOR);
		gutterLine.setPosition(x + CodeTheme.GUTTER_W - 1, y);
		CodeDraw.remake(gutterLine, 1, h, CodeTheme.BORDER);
		snapshot.setPosition(x, y);
		place();
		hlDirty = true;
		hlFull = true;
		hlDelay = 0;
		lastScroll = -1;
	}

	function place():Void
	{
		gutter.x = ex;
		gutter.y = ey;
		gutter.width = CodeTheme.GUTTER_W - 10;
		gutter.height = eh;
		field.x = ex + CodeTheme.GUTTER_W + 4;
		field.y = ey;
		field.width = ew - CodeTheme.GUTTER_W - 4;
		field.height = eh;
	}

	// ------------------------------------------------------------------ archivo

	public function setFile(f:Null<CodeStudioFile>):Void
	{
		stash();
		file = f;
		if (f == null)
		{
			box.visible = false;
			curLine.visible = false;
			errLine.visible = false;
			return;
		}

		box.visible = !frozen;
		suppress = true;
		field.type = f.editable ? TextFieldType.INPUT : TextFieldType.DYNAMIC;
		field.text = f.editorText();
		var h = histories.get(f);
		if (h == null)
		{
			h = new History();
			histories.set(f, h);
		}
		var len = field.text.length;
		field.setSelection(Std.int(Math.min(h.caretStart, len)), Std.int(Math.min(h.caretEnd, len)));
		suppress = false;
		field.scrollV = Std.int(Math.max(1, Math.min(h.scroll, field.maxScrollV)));
		h.base = snap();
		burstOpen = false;
		errorLine = -1;
		errLine.visible = false;
		updateGutter(true);
		recalcLineHeight();
		spans = [];
		retokenize();
		appliedFirst = appliedLast = -1;
		hlDirty = true;
		hlFull = true;
		hlDelay = 0;
		lastScroll = -1;
		lastCaret = -1;
		lastSel = -1;
	}

	/** Recuerda cursor y scroll del archivo actual antes de cambiar. */
	function stash():Void
	{
		if (file == null) return;
		var h = histories.get(file);
		if (h == null) return;
		h.caretStart = field.selectionBeginIndex;
		h.caretEnd = field.selectionEndIndex;
		h.scroll = field.scrollV;
	}

	public function forget(f:CodeStudioFile):Void
		histories.remove(f);

	public function getText():String
		return field.text;

	public function focus():Void
	{
		if (file != null && !frozen && FlxG.stage != null) FlxG.stage.focus = field;
	}

	public function isFocused():Bool
		return FlxG.stage != null && FlxG.stage.focus == field;

	public function setErrorLine(line:Int):Void
	{
		errorLine = line;
		lastScroll = -1;
	}

	// ------------------------------------------------------------------ congelar (para que los menus tapen el texto)

	/** Los TextField siempre estan encima de Flixel: al abrir un menu se cambian por una foto para poder taparlos. */
	public function freeze():Void
	{
		if (frozen) return;
		frozen = true;
		if (file == null) return;
		try
		{
			var bmp = new BitmapData(Std.int(Math.max(1, ew)), Std.int(Math.max(1, eh)), true, 0x00000000);
			var m = new Matrix();
			m.translate(-ex, -ey);
			bmp.draw(box, m);
			var g = FlxGraphic.fromBitmapData(bmp, true);
			var old = snapshot.graphic;
			snapshot.loadGraphic(g);
			if (old != null) FlxG.bitmap.removeIfNoUse(old);
			snapshot.setPosition(ex, ey);
			snapshot.visible = true;
		}
		catch (e:Dynamic) {}
		box.visible = false;
	}

	public function thaw():Void
	{
		if (!frozen) return;
		frozen = false;
		snapshot.visible = false;
		box.visible = file != null;
	}

	// ------------------------------------------------------------------ texto

	function snap():Snap
		return {text: field.text, start: field.selectionBeginIndex, end: field.selectionEndIndex, scroll: field.scrollV};

	function onFieldChange(_):Void
	{
		if (suppress || file == null) return;
		afterEdit();
	}

	/** Todo cambio de texto pasa por aqui. */
	function afterEdit():Void
	{
		noteEdit();
		updateGutter(false);
		hlDirty = true;
		hlFull = true;
		hlDelay = 0.12;
		retokenize();
		recalcLineHeight();
		lastScroll = -1;
		if (onChange != null) onChange();
	}

	function noteEdit():Void
	{
		if (file == null) return;
		var h = histories.get(file);
		if (h == null) return;
		if (!burstOpen)
		{
			if (h.base != null)
			{
				h.undo.push(h.base);
				if (h.undo.length > MAX_HISTORY) h.undo.shift();
			}
			h.redo = [];
			burstOpen = true;
		}
		burstTimer = 0.6;
	}

	function retokenize():Void
	{
		if (file == null)
		{
			spans = [];
			return;
		}
		var t = field.text;
		spans = t.length > MAX_HIGHLIGHT ? [] : Highlighter.tokenize(t, file.kind);
	}

	function countLines(t:String):Int
	{
		var n = 1;
		for (i in 0...t.length)
			if (StringTools.fastCodeAt(t, i) == 10) n++;
		return n;
	}

	function updateGutter(force:Bool):Void
	{
		var n = countLines(field.text);
		if (!force && n == lastLines) return;
		lastLines = n;
		var buf = new StringBuf();
		for (i in 1...n + 1)
		{
			buf.add(Std.string(i));
			if (i < n) buf.add("\n");
		}
		gutter.text = buf.toString();
		gutter.setTextFormat(gutterFmt);
		gutter.scrollV = field.scrollV;
	}

	function recalcLineHeight():Void
	{
		try
		{
			var m = field.getLineMetrics(0);
			if (m != null && m.height > 4) lineH = m.height;
		}
		catch (e:Dynamic) {}
	}

	function fmtFor(color:Int):TextFormat
	{
		var f = colorFmts.get(color);
		if (f == null)
		{
			f = new TextFormat();
			f.color = CodeTheme.rgb(color);
			colorFmts.set(color, f);
		}
		return f;
	}

	function applyHighlight():Void
	{
		hlDirty = false;
		if (file == null) return;
		var n = field.numLines;
		if (n <= 0) return;

		// setTextFormat hace que OpenFL lleve la vista al cursor: en archivos largos eso te mandaba al inicio.
		// Se guarda el scroll y se devuelve despues de colorear.
		var keepScroll = field.scrollV;
		var first = Std.int(Math.max(0, keepScroll - 1 - HL_MARGIN));
		var last = Std.int(Math.min(n - 1, field.bottomScrollV - 1 + HL_MARGIN));

		if (hlFull || appliedFirst < 0 || first > appliedLast + 1 || last < appliedFirst - 1)
		{
			formatLines(first, last, n);
			appliedFirst = first;
			appliedLast = last;
		}
		else
		{
			// al hacer scroll solo se colorean las lineas que todavia no tienen color (antes se repintaba toda la ventana)
			if (first < appliedFirst)
			{
				formatLines(first, Std.int(Math.min(last, appliedFirst - 1)), n);
				appliedFirst = first;
			}
			if (last > appliedLast)
			{
				formatLines(Std.int(Math.max(first, appliedLast + 1)), last, n);
				appliedLast = last;
			}
		}
		hlFull = false;

		if (field.scrollV != keepScroll) field.scrollV = keepScroll;
	}

	/** Pinta de la linea `first` a la `last` (indices desde 0) con los colores de `spans`. */
	function formatLines(first:Int, last:Int, n:Int):Void
	{
		if (last < first) return;
		var a = field.getLineOffset(first);
		var b = last + 1 < n ? field.getLineOffset(last + 1) : field.text.length;
		if (b <= a) return;

		field.setTextFormat(baseFmt, a, b);
		var count = Std.int(spans.length / 3);
		var lo = 0;
		var hi = count;
		while (lo < hi)
		{
			var mid = (lo + hi) >> 1;
			if (spans[mid * 3 + 1] <= a) lo = mid + 1;
			else hi = mid;
		}
		var k = lo;
		while (k < count)
		{
			var s = spans[k * 3];
			if (s >= b) break;
			var e = spans[k * 3 + 1];
			field.setTextFormat(fmtFor(spans[k * 3 + 2]), s < a ? a : s, e > b ? b : e);
			k++;
		}
	}

	/** Colorea ya (sin esperar al retraso). Se usa antes de congelar la pantalla para que la foto salga con colores. */
	public function flushHighlight():Void
	{
		if (file == null || !hlDirty) return;
		hlDelay = 0;
		applyHighlight();
	}

	function onWheel(_):Void
		wheelTick = true;

	// ------------------------------------------------------------------ frame

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (file == null) return;

		if (burstOpen)
		{
			burstTimer -= elapsed;
			if (burstTimer <= 0)
			{
				burstOpen = false;
				var h = histories.get(file);
				if (h != null) h.base = snap();
			}
		}

		var sv = field.scrollV;
		var ci = field.caretIndex;
		var sel = field.selectionEndIndex - field.selectionBeginIndex;

		// Si el scroll cambio solo (sin rueda, sin mover el cursor y sin que lo pidiera el codigo) es OpenFL
		// llevando la vista al cursor tras recolorear: se devuelve a donde estaba el usuario.
		if (wheelTick)
			wheelTick = false;
		else if (lastScroll > 0 && sv != lastScroll && ci == lastCaret && sel == lastSel)
		{
			field.scrollV = lastScroll;
			sv = field.scrollV;
		}
		var scrolled = sv != lastScroll;

		if (scrolled)
		{
			lastScroll = sv;
			if (gutter.scrollV != sv) gutter.scrollV = sv;
			var vFirst = sv - 1;
			var vLast = field.bottomScrollV - 1;
			if (appliedFirst < 0 || (vFirst < appliedFirst + 8 && appliedFirst > 0) || vLast > appliedLast - 8)
			{
				hlDirty = true;
				hlDelay = Math.min(hlDelay, 0.02);
			}
		}

		if (scrolled || ci != lastCaret || sel != lastSel)
		{
			lastCaret = ci;
			lastSel = sel;
			placeMarks();
			reportCaret();
		}

		if (hlDirty)
		{
			hlDelay -= elapsed;
			if (hlDelay <= 0) applyHighlight();
		}
	}

	function caretLine():Int
	{
		var line = field.getLineIndexOfChar(field.caretIndex);
		return line < 0 ? Std.int(Math.max(0, field.numLines - 1)) : line;
	}

	function placeMarks():Void
	{
		var rel = caretLine() - (field.scrollV - 1);
		var y = ey + 2 + rel * lineH;
		var inView = rel >= 0 && y + lineH <= ey + eh + 1;
		curLine.visible = inView && !frozen;
		if (inView)
		{
			curLine.y = y;
			curLine.scale.set(1, lineH / 20);
			curLine.updateHitbox();
			curLine.y = y;
		}

		if (errorLine >= 0)
		{
			var er = errorLine - (field.scrollV - 1);
			var ey2 = ey + 2 + er * lineH;
			errLine.visible = er >= 0 && ey2 + lineH <= ey + eh + 1;
			if (errLine.visible)
			{
				errLine.scale.set(1, lineH / 20);
				errLine.updateHitbox();
				errLine.y = ey2;
			}
		}
		else
			errLine.visible = false;
	}

	function reportCaret():Void
	{
		if (onCaret == null) return;
		var line = caretLine();
		var col = field.caretIndex - field.getLineOffset(line) + 1;
		onCaret(line + 1, col, field.selectionEndIndex - field.selectionBeginIndex);
	}

	// ------------------------------------------------------------------ teclado

	/** Enter: mantiene la sangria de la linea (y suma una si abre un bloque). */
	function onTextInput(e:TextEvent):Void
	{
		if (file == null || !file.editable || e.text != "\n") return;
		e.preventDefault();
		var line = caretLine();
		var lineText = field.getLineText(line);
		var col = field.caretIndex - field.getLineOffset(line);
		var before = lineText.substr(0, col);
		var indent = "";
		for (i in 0...before.length)
		{
			var c = before.charAt(i);
			if (c == " " || c == "\t") indent += c;
			else break;
		}
		var trimmed = StringTools.rtrim(before);
		if (trimmed.length > 0)
		{
			var last = trimmed.charAt(trimmed.length - 1);
			if (last == "{" || last == "(" || last == "[") indent += INDENT;
		}
		field.replaceSelectedText("\n" + indent);
		afterEdit();
	}

	/** Atajos del editor. Devuelve true si se uso la tecla. */
	public function onKey(event:KeyboardEvent):Bool
	{
		if (file == null || !file.editable || !isFocused()) return false;
		var ctrl = event.ctrlKey || event.commandKey;
		switch (event.keyCode)
		{
			case Keyboard.TAB:
				if (ctrl) return false;
				event.preventDefault();
				indentSelection(event.shiftKey);
				return true;
			case Keyboard.Z if (ctrl):
				event.preventDefault();
				if (event.shiftKey) redo();
				else undo();
				return true;
			case Keyboard.Y if (ctrl):
				event.preventDefault();
				redo();
				return true;
			case Keyboard.SLASH if (ctrl):
				event.preventDefault();
				toggleComment();
				return true;
			case Keyboard.D if (ctrl):
				event.preventDefault();
				duplicateLine();
				return true;
		}
		return false;
	}

	static function lineStart(t:String, i:Int):Int
	{
		var j = i;
		while (j > 0 && StringTools.fastCodeAt(t, j - 1) != 10) j--;
		return j;
	}

	static function lineEnd(t:String, i:Int):Int
	{
		var j = i;
		while (j < t.length && StringTools.fastCodeAt(t, j) != 10) j++;
		return j;
	}

	/** Reemplaza todo el texto sin perder el scroll. */
	function replaceAll(newText:String, selA:Int, selB:Int):Void
	{
		suppress = true;
		var sv = field.scrollV;
		field.text = newText;
		field.setSelection(selA, selB);
		field.scrollV = Std.int(Math.min(sv, Math.max(1, field.maxScrollV)));
		suppress = false;
		afterEdit();
	}

	function indentSelection(back:Bool):Void
	{
		var a = field.selectionBeginIndex;
		var b = field.selectionEndIndex;
		if (a == b && !back)
		{
			field.replaceSelectedText(INDENT);
			afterEdit();
			return;
		}
		var t = field.text;
		var ls = lineStart(t, a);
		var endRef = (b > a && b > 0 && StringTools.fastCodeAt(t, b - 1) == 10) ? b - 1 : b;
		var le = lineEnd(t, endRef);
		var lines = t.substring(ls, le).split("\n");
		var out:Array<String> = [];
		for (l in lines)
		{
			if (back)
			{
				if (StringTools.startsWith(l, INDENT)) l = l.substr(INDENT.length);
				else if (StringTools.startsWith(l, "\t")) l = l.substr(1);
				else
				{
					var k = 0;
					while (k < INDENT.length && k < l.length && l.charAt(k) == " ") k++;
					l = l.substr(k);
				}
			}
			else if (l.length > 0)
				l = INDENT + l;
			out.push(l);
		}
		var block = out.join("\n");
		replaceAll(t.substr(0, ls) + block + t.substr(le), ls, ls + block.length);
	}

	function toggleComment():Void
	{
		var a = field.selectionBeginIndex;
		var b = field.selectionEndIndex;
		var t = field.text;
		var ls = lineStart(t, a);
		var endRef = (b > a && b > 0 && StringTools.fastCodeAt(t, b - 1) == 10) ? b - 1 : b;
		var le = lineEnd(t, endRef);
		var lines = t.substring(ls, le).split("\n");
		var allCommented = true;
		for (l in lines)
			if (StringTools.trim(l) != "" && !StringTools.startsWith(StringTools.ltrim(l), "//")) allCommented = false;
		var out:Array<String> = [];
		for (l in lines)
		{
			if (StringTools.trim(l) == "")
			{
				out.push(l);
				continue;
			}
			var lead = l.length - StringTools.ltrim(l).length;
			var rest = l.substr(lead);
			if (allCommented)
			{
				rest = rest.substr(2);
				if (StringTools.startsWith(rest, " ")) rest = rest.substr(1);
			}
			else
				rest = "// " + rest;
			out.push(l.substr(0, lead) + rest);
		}
		var block = out.join("\n");
		replaceAll(t.substr(0, ls) + block + t.substr(le), ls, ls + block.length);
	}

	function duplicateLine():Void
	{
		var t = field.text;
		var a = field.selectionBeginIndex;
		var b = field.selectionEndIndex;
		if (a == b)
		{
			var ls = lineStart(t, a);
			var le = lineEnd(t, a);
			var line = t.substring(ls, le);
			var col = a - ls;
			replaceAll(t.substr(0, le) + "\n" + line + t.substr(le), le + 1 + col, le + 1 + col);
		}
		else
		{
			var sel = t.substring(a, b);
			replaceAll(t.substr(0, b) + sel + t.substr(b), b, b + sel.length);
		}
	}

	function restore(s:Snap):Void
	{
		suppress = true;
		field.text = s.text;
		field.setSelection(s.start, s.end);
		field.scrollV = Std.int(Math.max(1, Math.min(s.scroll, field.maxScrollV)));
		suppress = false;
		updateGutter(false);
		retokenize();
		hlDirty = true;
		hlFull = true;
		hlDelay = 0;
		lastScroll = -1;
		if (onChange != null) onChange();
	}

	public function undo():Void
	{
		if (file == null) return;
		var h = histories.get(file);
		if (h == null || h.undo.length == 0) return;
		burstOpen = false;
		h.redo.push(snap());
		var s = h.undo.pop();
		restore(s);
		h.base = snap();
	}

	public function redo():Void
	{
		if (file == null) return;
		var h = histories.get(file);
		if (h == null || h.redo.length == 0) return;
		burstOpen = false;
		h.undo.push(snap());
		var s = h.redo.pop();
		restore(s);
		h.base = snap();
	}

	/** Reemplaza el contenido entero (formatear JSON, recargar...) como una edicion mas. */
	public function setTextAsEdit(newText:String):Void
	{
		if (file == null || !file.editable) return;
		replaceAll(newText, 0, 0);
	}

	// ------------------------------------------------------------------ busqueda / navegacion

	function reveal(idx:Int):Void
	{
		var line = field.getLineIndexOfChar(idx);
		if (line < 0) return;
		if (line < field.scrollV - 1 || line >= field.bottomScrollV)
		{
			var visible = Std.int(Math.max(1, field.bottomScrollV - field.scrollV + 1));
			field.scrollV = Std.int(Math.max(1, Math.min(field.maxScrollV, line - Std.int(visible / 2) + 1)));
		}
		lastScroll = -1;
	}

	/** Busca y selecciona. `fromStart` busca desde el inicio de la seleccion (para buscar mientras escribes). */
	public function find(query:String, forward:Bool, caseSensitive:Bool, fromStart:Bool = false):Int
	{
		if (file == null || query == "") return -1;
		var t = field.text;
		var hay = caseSensitive ? t : t.toLowerCase();
		var needle = caseSensitive ? query : query.toLowerCase();
		var idx:Int;
		if (forward)
		{
			var start = fromStart ? field.selectionBeginIndex : field.selectionEndIndex;
			idx = hay.indexOf(needle, start);
			if (idx < 0) idx = hay.indexOf(needle, 0);
		}
		else
		{
			var start = field.selectionBeginIndex - 1;
			idx = start < 0 ? -1 : hay.lastIndexOf(needle, start);
			if (idx < 0) idx = hay.lastIndexOf(needle);
		}
		if (idx >= 0)
		{
			field.setSelection(idx, idx + query.length);
			reveal(idx);
		}
		return idx;
	}

	/** {total, current}: cuantas coincidencias hay y cual es la seleccionada (1..). */
	public function matchInfo(query:String, caseSensitive:Bool):{total:Int, current:Int}
	{
		var total = 0;
		var current = 0;
		if (file == null || query == "") return {total: 0, current: 0};
		var t = field.text;
		var hay = caseSensitive ? t : t.toLowerCase();
		var needle = caseSensitive ? query : query.toLowerCase();
		var from = 0;
		var sel = field.selectionBeginIndex;
		while (true)
		{
			var i = hay.indexOf(needle, from);
			if (i < 0) break;
			total++;
			if (i == sel) current = total;
			from = i + Std.int(Math.max(1, needle.length));
			if (total > 99999) break;
		}
		return {total: total, current: current};
	}

	/** Lleva el cursor a un caracter (y selecciona `len`). Lo usa el inspector JSON. */
	public function goToOffset(idx:Int, len:Int = 0):Void
	{
		if (file == null) return;
		var total = field.text.length;
		var a = Std.int(Math.max(0, Math.min(idx, total)));
		var b = Std.int(Math.max(a, Math.min(a + len, total)));
		field.setSelection(a, b);
		reveal(a);
	}

	public function goToLine(n:Int):Void
	{
		if (file == null) return;
		var lines = field.numLines;
		var line = Std.int(Math.max(0, Math.min(lines - 1, n - 1)));
		var idx = field.getLineOffset(line);
		field.setSelection(idx, idx);
		reveal(idx);
	}

	// ------------------------------------------------------------------ limpieza

	override public function destroy():Void
	{
		field.removeEventListener(Event.CHANGE, onFieldChange);
		field.removeEventListener(TextEvent.TEXT_INPUT, onTextInput);
		field.removeEventListener(MouseEvent.MOUSE_WHEEL, onWheel);
		if (box != null && box.parent != null) box.parent.removeChild(box);
		box = null;
		super.destroy();
	}
}
