package advanced.ui.code;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;

private typedef JNode =
{
	var key:String;
	var path:String;
	var depth:Int;
	var kind:Int;
	var preview:String;
	/** Posicion en el texto: inicio de la clave (o del valor si es un elemento de array). */
	var offset:Int;
	/** Largo de la clave con comillas (0 si no tiene). */
	var klen:Int;
	/** Posicion justo despues del valor. */
	var last:Int;
	var parent:Int;
	/** Indice del primer nodo que ya no es hijo de este. */
	var end:Int;
}

private typedef Slot =
{
	var arrow:FlxText;
	var key:FlxText;
	var value:FlxText;
}

/** Recorre el texto JSON sin parsearlo a objetos: guarda el orden original y la posicion de cada valor. Nunca lanza errores. */
private class JsonScan
{
	public static inline var K_OBJ:Int = 0;
	public static inline var K_ARR:Int = 1;
	public static inline var K_STR:Int = 2;
	public static inline var K_NUM:Int = 3;
	public static inline var K_BOOL:Int = 4;
	public static inline var K_NULL:Int = 5;

	static inline var MAX_NODES:Int = 60000;
	static inline var MAX_DEPTH:Int = 48;

	public var nodes:Array<JNode> = [];
	public var partial:Bool = false;

	var t:String;
	var n:Int;
	var i:Int = 0;

	public function new(text:String)
	{
		t = text == null ? "" : text;
		n = t.length;
	}

	public function run():Void
	{
		skipSpace();
		if (i < n) value("root", "", -1, 0, -1, 0);
	}

	inline function at(p:Int):Int
		return StringTools.fastCodeAt(t, p);

	function skipSpace():Void
	{
		while (i < n)
		{
			var c = at(i);
			if (c == 32 || c == 9 || c == 10 || c == 13 || c == 0xFEFF) i++;
			else break;
		}
	}

	/** Empieza en la comilla de apertura y deja `i` despues de la de cierre. Devuelve el texto sin comillas. */
	function readString():String
	{
		i++;
		var s = i;
		while (i < n)
		{
			var c = at(i);
			if (c == 92)
			{
				i += 2;
				continue;
			}
			if (c == 34) break;
			i++;
		}
		var e = i > n ? n : i;
		var out = t.substring(s, e);
		if (i < n) i++;
		return out;
	}

	function value(key:String, parentPath:String, parent:Int, depth:Int, keyStart:Int, keyLen:Int):Void
	{
		skipSpace();
		if (i >= n) return;
		if (nodes.length >= MAX_NODES || depth > MAX_DEPTH)
		{
			partial = true;
			i = n;
			return;
		}

		var c = at(i);
		var idx = nodes.length;
		var node:JNode = {
			key: key,
			path: parent < 0 ? "$" : parentPath + "/" + key,
			depth: depth,
			kind: K_NUM,
			preview: "",
			offset: keyStart >= 0 ? keyStart : i,
			klen: keyLen,
			last: n,
			parent: parent,
			end: 0
		};
		nodes.push(node);

		if (c == 123) // {
		{
			node.kind = K_OBJ;
			i++;
			var count = 0;
			while (i < n)
			{
				skipSpace();
				if (i >= n) break;
				var d = at(i);
				if (d == 125)
				{
					i++;
					break;
				}
				if (d == 44)
				{
					i++;
					continue;
				}
				if (d != 34)
				{
					partial = true;
					i = n;
					break;
				}
				var ks = i;
				var k = readString();
				var kl = i - ks;
				skipSpace();
				if (i < n && at(i) == 58) i++;
				value(k, node.path, idx, depth + 1, ks, kl);
				count++;
			}
			node.preview = "{" + count + "}";
		}
		else if (c == 91) // [
		{
			node.kind = K_ARR;
			i++;
			var count = 0;
			while (i < n)
			{
				skipSpace();
				if (i >= n) break;
				var d = at(i);
				if (d == 93)
				{
					i++;
					break;
				}
				if (d == 44)
				{
					i++;
					continue;
				}
				value("[" + count + "]", node.path, idx, depth + 1, -1, 0);
				count++;
			}
			node.preview = "[" + count + "]";
		}
		else if (c == 34) // "
		{
			node.kind = K_STR;
			var s = readString();
			node.preview = "\"" + (s.length > 80 ? s.substr(0, 80) + "…" : s) + "\"";
		}
		else
		{
			var s = i;
			while (i < n)
			{
				var d = at(i);
				if (d == 44 || d == 125 || d == 93 || d == 32 || d == 9 || d == 10 || d == 13) break;
				i++;
			}
			if (i == s) i++; // nunca quedarse quieto
			var w = t.substring(s, i > n ? n : i);
			node.kind = (w == "true" || w == "false") ? K_BOOL : (w == "null" ? K_NULL : K_NUM);
			node.preview = w.length > 40 ? w.substr(0, 40) + "…" : w;
		}

		node.last = i > n ? n : i;
		node.end = nodes.length;
	}
}

/**
 * Inspector JSON (panel de la derecha, reemplaza al explorador mientras hay un .json abierto).
 *
 * - Arbol plegable con el orden real del archivo, colores por tipo y scroll con la rueda.
 * - Clic en una fila: el editor salta a esa clave. La flecha pliega/despliega.
 * - Sigue al cursor: al moverte por el texto se marca la fila que estas editando y abajo sale su ruta.
 */
class JsonPanel extends FlxSpriteGroup
{
	/** Pide al editor ir a una posicion: (inicio, largo). */
	public var onJump:Int->Int->Void;
	/** Boton "Archivos": volver al explorador. */
	public var onClose:Void->Void;

	static inline var INDENT:Int = 14;
	static inline var FOOT_H:Int = 24;

	var tx:Int;
	var ty:Int;
	var tw:Int;
	var th:Int;
	var rowsY:Int;
	var capacity:Int;

	var slots:Array<Slot> = [];
	var nodes:Array<JNode> = [];
	var vis:Array<Int> = [];
	var scroll:Int = 0;
	var selNode:Int = -1;
	var partial:Bool = false;
	var sourceName:String = "";
	var followCaret:Int = -1;
	var expanded:Map<String, Bool> = new Map();
	var expandedByFile:Map<String, Map<String, Bool>> = new Map();

	var selBar:FlxSprite;
	var hoverBar:FlxSprite;
	var thumb:FlxSprite;
	var titleText:FlxText;
	var emptyText:FlxText;
	var pathText:FlxText;

	public function new(x:Int, y:Int, w:Int, h:Int)
	{
		super();
		tx = x;
		ty = y;
		tw = w;
		th = h;
		rowsY = y + CodeTheme.PANEL_HEAD_H + 2;
		capacity = Std.int(Math.max(1, Std.int((h - CodeTheme.PANEL_HEAD_H - 4 - FOOT_H) / CodeTheme.ROW_H)));

		add(CodeDraw.rect(x, y, w, h, CodeTheme.PANEL));
		add(CodeDraw.rect(x, y, 1, h, CodeTheme.BORDER));
		add(CodeDraw.rect(x, y, w, CodeTheme.PANEL_HEAD_H, CodeTheme.MENU));
		add(CodeDraw.rect(x, y + CodeTheme.PANEL_HEAD_H - 1, w, 1, CodeTheme.BORDER));
		titleText = CodeDraw.label(x + 12, y + 6, "INSPECTOR JSON", CodeTheme.FONT_SMALL, CodeTheme.MUTED);
		add(titleText);
		add(new CodeButton(x + 124, y + 2, 66, 22, "Archivos", function()
		{
			if (onClose != null) onClose();
		}, CodeTheme.ACCENT, CodeTheme.FONT_SMALL));
		add(new CodeButton(x + w - 56, y + 2, 24, 22, "−", collapseAll, CodeTheme.TEXT, 16));
		add(new CodeButton(x + w - 30, y + 2, 24, 22, "+", expandAll, CodeTheme.TEXT, 16));

		selBar = CodeDraw.rect(x + 1, rowsY, w - 1, CodeTheme.ROW_H, CodeTheme.SELECT);
		selBar.visible = false;
		add(selBar);
		hoverBar = CodeDraw.rect(x + 1, rowsY, w - 1, CodeTheme.ROW_H, 0xFFFFFFFF);
		hoverBar.alpha = 0.06;
		hoverBar.visible = false;
		add(hoverBar);
		thumb = CodeDraw.rect(x + w - 5, rowsY, 3, 20, CodeTheme.DIM);
		thumb.visible = false;
		add(thumb);

		for (i in 0...capacity)
		{
			var yy = rowsY + i * CodeTheme.ROW_H + 3;
			var s:Slot = {
				arrow: CodeDraw.label(0, yy, "", CodeTheme.FONT_SMALL, CodeTheme.MUTED),
				key: CodeDraw.label(0, yy, "", CodeTheme.FONT_SMALL + 1, CodeTheme.TEXT),
				value: CodeDraw.label(0, yy, "", CodeTheme.FONT_SMALL, CodeTheme.MUTED)
			};
			add(s.arrow);
			add(s.key);
			add(s.value);
			slots.push(s);
		}

		emptyText = CodeDraw.label(x + 14, rowsY + 10, "No hay datos JSON", CodeTheme.FONT_SMALL, CodeTheme.DIM);
		emptyText.visible = false;
		add(emptyText);

		add(CodeDraw.rect(x + 1, y + h - FOOT_H, w - 1, FOOT_H, CodeTheme.MENU));
		add(CodeDraw.rect(x + 1, y + h - FOOT_H, w - 1, 1, CodeTheme.BORDER));
		pathText = CodeDraw.label(x + 10, y + h - FOOT_H + 6, "", CodeTheme.FONT_SMALL, CodeTheme.MUTED);
		add(pathText);
	}

	// ------------------------------------------------------------------ datos

	/** Lee el texto del editor y reconstruye el arbol. Se llama al abrir el archivo y despues de editar. */
	public function setSource(f:CodeStudioFile, text:String):Void
	{
		if (f.name != sourceName)
		{
			sourceName = f.name;
			scroll = 0;
			var m = expandedByFile.get(sourceName);
			if (m == null)
			{
				m = new Map();
				expandedByFile.set(sourceName, m);
			}
			expanded = m;
		}

		var scan = new JsonScan(text);
		scan.run();
		nodes = scan.nodes;
		partial = scan.partial;
		if (nodes.length > 0 && !expanded.exists(nodes[0].path)) expanded.set(nodes[0].path, true);

		selNode = -1;
		followCaret = -1;
		pathText.text = partial ? "Archivo grande: se muestra solo una parte" : "";
		rebuildVisible();
		clampScroll();
		layoutRows();
	}

	function isContainer(nd:JNode):Bool
		return nd.kind == JsonScan.K_OBJ || nd.kind == JsonScan.K_ARR;

	function isExpanded(nd:JNode):Bool
		return expanded.get(nd.path) == true;

	function rebuildVisible():Void
	{
		vis = [];
		var i = 0;
		while (i < nodes.length)
		{
			var nd = nodes[i];
			vis.push(i);
			if (isContainer(nd) && !isExpanded(nd)) i = Std.int(Math.max(i + 1, nd.end));
			else i++;
		}
	}

	function clampScroll():Void
		scroll = vis.length > capacity ? Std.int(Math.max(0, Math.min(scroll, vis.length - capacity))) : 0;

	/** Fila visible de un nodo (busqueda binaria: `vis` esta ordenado). -1 si esta oculto. */
	function visRow(k:Int):Int
	{
		var lo = 0;
		var hi = vis.length - 1;
		while (lo <= hi)
		{
			var mid = (lo + hi) >> 1;
			if (vis[mid] == k) return mid;
			if (vis[mid] < k) lo = mid + 1;
			else hi = mid - 1;
		}
		return -1;
	}

	/** Nodo mas profundo que contiene esa posicion del texto. */
	function nodeAt(pos:Int):Int
	{
		var lo = 0;
		var hi = nodes.length;
		while (lo < hi)
		{
			var mid = (lo + hi) >> 1;
			if (nodes[mid].offset <= pos) lo = mid + 1;
			else hi = mid;
		}
		var k = lo - 1;
		while (k >= 0 && pos >= nodes[k].last) k = nodes[k].parent;
		return k;
	}

	function pathLabel(k:Int):String
	{
		var parts:Array<String> = [];
		var p = k;
		while (p > 0)
		{
			parts.push(nodes[p].key);
			p = nodes[p].parent;
		}
		parts.reverse();
		return parts.length == 0 ? "raíz" : parts.join(" > ");
	}

	// ------------------------------------------------------------------ acciones

	/** Marca la fila del texto donde esta el cursor, despliega sus padres y muestra su ruta. */
	public function follow(caret:Int):Void
	{
		if (nodes.length == 0 || caret == followCaret) return;
		followCaret = caret;
		var k = nodeAt(caret);
		selNode = k;
		if (k < 0)
		{
			pathText.text = "";
			layoutRows();
			return;
		}

		var changed = false;
		var p = nodes[k].parent;
		while (p >= 0)
		{
			if (!isExpanded(nodes[p]))
			{
				expanded.set(nodes[p].path, true);
				changed = true;
			}
			p = nodes[p].parent;
		}
		if (changed) rebuildVisible();

		var row = visRow(k);
		if (row >= 0 && (row < scroll || row >= scroll + capacity))
		{
			scroll = row - Std.int(capacity / 2);
			clampScroll();
		}
		pathText.text = CodeDraw.fit(pathLabel(k), Std.int((tw - 20) / 7));
		layoutRows();
	}

	function toggle(k:Int):Void
	{
		var nd = nodes[k];
		expanded.set(nd.path, !isExpanded(nd));
		rebuildVisible();
		clampScroll();
		layoutRows();
	}

	function jump(k:Int):Void
	{
		selNode = k;
		var nd = nodes[k];
		pathText.text = CodeDraw.fit(pathLabel(k), Std.int((tw - 20) / 7));
		layoutRows();
		if (onJump != null) onJump(nd.offset, nd.klen);
	}

	public function collapseAll():Void
	{
		if (nodes.length == 0) return;
		expanded = new Map();
		expandedByFile.set(sourceName, expanded);
		expanded.set(nodes[0].path, true);
		scroll = 0;
		rebuildVisible();
		layoutRows();
	}

	public function expandAll():Void
	{
		for (nd in nodes)
			if (isContainer(nd)) expanded.set(nd.path, true);
		rebuildVisible();
		clampScroll();
		layoutRows();
	}

	// ------------------------------------------------------------------ dibujo

	function kindColor(kind:Int):Int
	{
		if (kind == JsonScan.K_STR) return CodeTheme.SYN_STRING;
		if (kind == JsonScan.K_NUM) return CodeTheme.SYN_NUMBER;
		if (kind == JsonScan.K_BOOL || kind == JsonScan.K_NULL) return CodeTheme.SYN_KEYWORD;
		return CodeTheme.MUTED;
	}

	function layoutRows():Void
	{
		emptyText.visible = vis.length == 0;
		selBar.visible = false;
		for (i in 0...capacity)
		{
			var s = slots[i];
			var row = scroll + i;
			if (row >= vis.length)
			{
				s.arrow.visible = false;
				s.key.visible = false;
				s.value.visible = false;
				continue;
			}

			var k = vis[row];
			var nd = nodes[k];
			var x = tx + 10 + nd.depth * INDENT;
			var container = isContainer(nd);

			s.arrow.visible = container;
			if (container)
			{
				s.arrow.text = isExpanded(nd) ? "▼" : "►";
				s.arrow.x = x;
			}

			s.key.visible = true;
			s.key.text = CodeDraw.fit(nd.key, 28);
			s.key.x = x + 16;
			s.key.color = container ? CodeTheme.TEXT : CodeTheme.SYN_KEY;

			var vx = s.key.x + s.key.width + 10;
			var room = Std.int((tx + tw - 12 - vx) / 7);
			if (room < 3)
				s.value.visible = false;
			else
			{
				s.value.visible = true;
				s.value.text = CodeDraw.fit(nd.preview, room);
				s.value.x = vx;
				s.value.color = kindColor(nd.kind);
			}

			if (k == selNode)
			{
				selBar.visible = true;
				selBar.y = rowsY + i * CodeTheme.ROW_H;
			}
		}

		var overflow = vis.length > capacity;
		thumb.visible = overflow;
		if (overflow)
		{
			var track = capacity * CodeTheme.ROW_H;
			var hh = Math.max(20, track * capacity / vis.length);
			CodeDraw.remake(thumb, 3, hh, CodeTheme.DIM);
			thumb.y = rowsY + (track - hh) * scroll / Math.max(1, vis.length - capacity);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		hoverBar.visible = false;
		if (CodeDraw.blocked || !CodeDraw.over(tx, rowsY, tw, capacity * CodeTheme.ROW_H)) return;

		if (FlxG.mouse.wheel != 0 && vis.length > capacity)
		{
			scroll -= FlxG.mouse.wheel * 3;
			clampScroll();
			layoutRows();
		}

		var i = Std.int((FlxG.mouse.y - rowsY) / CodeTheme.ROW_H);
		var row = scroll + i;
		if (i < 0 || i >= capacity || row >= vis.length) return;
		hoverBar.visible = true;
		hoverBar.y = rowsY + i * CodeTheme.ROW_H;

		if (FlxG.mouse.justPressed)
		{
			var k = vis[row];
			var nd = nodes[k];
			var arrowEnd = tx + 10 + nd.depth * INDENT + 18;
			if (isContainer(nd) && FlxG.mouse.x < arrowEnd) toggle(k);
			else jump(k);
		}
	}
}
