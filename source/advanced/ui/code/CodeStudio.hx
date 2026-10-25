package advanced.ui.code;

import advanced.ui.code.MenuBar.MenuDef;
import advanced.ui.code.MenuBar.MenuItem;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import haxe.Json;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;

/**
 * Code Studio del modo avanzado: menu, barra de herramientas, pestanas, editor con colores,
 * explorador de archivos a la derecha, panel de salida y barra de estado. Solo PC (teclado y mouse).
 *
 * Los pedazos viven en esta carpeta (`advanced/ui/code/`): cada uno hace una sola cosa y CodeStudio los conecta.
 */
class CodeStudio extends FlxSpriteGroup
{
	public var files:Array<CodeStudioFile> = [];
	public var currentFile(default, null):Int = -1;
	/** true en el frame en que CodeStudio uso ESC (cerrar menu o buscador): el state no debe salir. */
	public var escapeHandled(default, null):Bool = false;
	/** Lo llama "Archivo > Volver". */
	public var onExit:Void->Void;

	var onSave:CodeStudioFile->Bool;
	var onRun:CodeStudioFile->Void;
	var onPreview:Void->Void;
	var onNewScript:Void->CodeStudioFile;

	var overlay:StudioOverlay;
	var menu:MenuBar;
	var toolbar:ToolBar;
	var tabs:TabBar;
	var tree:FileTree;
	var editor:CodeEditor;
	var findBar:FindBar;
	var output:OutputPanel;
	var status:StatusBar;
	var welcome:FlxText;

	var openTabs:Array<CodeStudioFile> = [];
	var jsonTimer:Float = -1;
	var mainW:Int;
	var statusY:Int;
	var oldMute:Array<FlxKey>;
	var oldUp:Array<FlxKey>;
	var oldDown:Array<FlxKey>;

	public function new(?initialFiles:Array<CodeStudioFile>, ?saveHandler:CodeStudioFile->Bool, ?runHandler:CodeStudioFile->Void,
			?previewHandler:Void->Void, ?newScriptHandler:Void->CodeStudioFile, ?levelName:String)
	{
		super();
		files = initialFiles != null ? initialFiles : [];
		onSave = saveHandler != null ? saveHandler : function(_) return true;
		onRun = runHandler != null ? runHandler : function(_) {};
		onPreview = previewHandler != null ? previewHandler : function() {};
		onNewScript = newScriptHandler != null ? newScriptHandler : function() return null;

		mainW = FlxG.width - CodeTheme.EXPLORER_W;
		statusY = FlxG.height - CodeTheme.STATUS_H;
		var tabsY = CodeTheme.MENU_H + CodeTheme.TOOL_H;
		var bodyY = tabsY + CodeTheme.TAB_H;
		var outH = CodeTheme.OUTPUT_H;
		var editorH = statusY - outH - bodyY;

		// el teclado de Flixel no debe silenciar/subir volumen mientras escribes ("0", "+", "-")
		oldMute = FlxG.sound.muteKeys;
		oldUp = FlxG.sound.volumeUpKeys;
		oldDown = FlxG.sound.volumeDownKeys;
		FlxG.sound.muteKeys = null;
		FlxG.sound.volumeUpKeys = null;
		FlxG.sound.volumeDownKeys = null;

		overlay = new StudioOverlay();
		add(CodeDraw.rect(0, 0, FlxG.width, FlxG.height, CodeTheme.BG));

		editor = new CodeEditor(overlay.root, 0, bodyY, mainW, editorH);
		editor.onChange = onEditorChange;
		editor.onCaret = function(line, col, sel) status.setCaret(line, col, sel);

		welcome = CodeDraw.label(0, bodyY + Std.int(editorH / 2) - 30, "Elige un archivo del explorador", 18, CodeTheme.DIM, mainW);
		welcome.alignment = CENTER;

		tabs = new TabBar(tabsY, mainW);
		tabs.onSelect = function(f) activate(f);
		tabs.onClose = closeTab;

		tree = new FileTree(mainW, tabsY, CodeTheme.EXPLORER_W, statusY - tabsY);
		tree.setTitle(levelName != null ? levelName : "Nivel");
		tree.onOpen = function(f) activate(f);
		tree.onNewScript = newScript;

		output = new OutputPanel(0, statusY - outH, mainW, outH);
		output.onToggle = relayout;

		findBar = new FindBar(overlay.root, editor, bodyY, mainW);
		findBar.onToggle = relayout;

		toolbar = buildToolbar(levelName);
		status = new StatusBar(statusY, FlxG.width);
		menu = new MenuBar(buildMenus(), FlxG.width);
		menu.onOpen = function()
		{
			editor.freeze();
			findBar.freeze();
		};
		menu.onClose = function()
		{
			editor.thaw();
			findBar.thaw();
		};

		// el orden de add es el orden de dibujo: el menu va al final para tapar todo
		add(tabs);
		add(editor);
		add(welcome);
		add(findBar);
		add(output);
		add(tree);
		add(toolbar);
		add(status);
		add(menu);

		tree.setFiles(files, null);
		output.log("[FMCE] Code Studio listo. Ctrl+S guarda, Ctrl+F busca, Ctrl+G va a una linea.", CodeTheme.MUTED);
		if (files.length > 0) openFile(0);
		else activate(null);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
	}

	// ------------------------------------------------------------------ construccion

	function buildToolbar(levelName:Null<String>):ToolBar
	{
		var t = new ToolBar(CodeTheme.MENU_H, FlxG.width);
		t.addButton("Guardar", CodeTheme.TEXT, save);
		t.addButton("Guardar todo", CodeTheme.TEXT, saveAll);
		t.addSeparator();
		t.addButton("+ Script", CodeTheme.TEXT, newScript);
		t.addSeparator();
		t.addButton("► Ejecutar", CodeTheme.OK, run);
		t.addButton("Sprites", CodeTheme.TEXT, previewSprites);
		t.addSeparator();
		t.addButton("Buscar", CodeTheme.TEXT, function() openFind(""));
		t.setTitle(levelName != null ? levelName : "");
		return t;
	}

	function buildMenus():Array<MenuDef>
	{
		return [
			{
				title: "Archivo",
				items: function():Array<MenuItem> return [
					{label: "Guardar", shortcut: "Ctrl+S", action: save, disabled: !canSave()},
					{label: "Guardar todo", shortcut: "Ctrl+Mayús+S", action: saveAll},
					{label: "", separator: true},
					{label: "Nuevo script", shortcut: "Ctrl+N", action: newScript},
					{label: "Cerrar pestaña", shortcut: "Ctrl+W", action: function() closeTab(currentOpen()), disabled: currentOpen() == null},
					{label: "", separator: true},
					{label: "Volver", shortcut: "ESC", action: function()
					{
						if (onExit != null) onExit();
					}}
				]
			},
			{
				title: "Editar",
				items: function():Array<MenuItem> return [
					{label: "Deshacer", shortcut: "Ctrl+Z", action: editor.undo, disabled: !canEdit()},
					{label: "Rehacer", shortcut: "Ctrl+Y", action: editor.redo, disabled: !canEdit()},
					{label: "", separator: true},
					{label: "Buscar…", shortcut: "Ctrl+F", action: function() openFind("")},
					{label: "Ir a la línea…", shortcut: "Ctrl+G", action: function() openFind(":")},
					{label: "", separator: true},
					{label: "Formatear JSON", shortcut: "Alt+Mayús+F", action: formatJson, disabled: !canFormat()}
				]
			},
			{
				title: "Ver",
				items: function():Array<MenuItem> return [
					{label: output.collapsed ? "Mostrar salida" : "Ocultar salida", shortcut: "Ctrl+J", action: toggleOutput},
					{label: "Limpiar salida", action: output.clearLog}
				]
			},
			{
				title: "Proyecto",
				items: function():Array<MenuItem> return [
					{label: "Ejecutar script", shortcut: "F5", action: run, disabled: !(currentOpen() != null && currentOpen().kind == "haxe")},
					{label: "Editor de sprites", shortcut: "F6", action: previewSprites}
				]
			},
			{
				title: "Ayuda",
				items: function():Array<MenuItem> return [
					{label: "Ctrl+Tab: siguiente pestaña"},
					{label: "Tab / Mayús+Tab: sangría"},
					{label: "Ctrl+/: comentar líneas"},
					{label: "Ctrl+D: duplicar línea"},
					{label: "Clic central: cerrar pestaña"}
				]
			}
		];
	}

	// ------------------------------------------------------------------ layout

	function relayout():Void
	{
		var bodyY = CodeTheme.MENU_H + CodeTheme.TOOL_H + CodeTheme.TAB_H;
		var findH = findBar.isOpen ? CodeTheme.FIND_H : 0;
		var outH = output.currentHeight();
		var top = bodyY + findH;
		editor.setRect(0, top, mainW, statusY - outH - top);
		// la barra de busqueda siempre esta justo debajo de las pestanas; se mueve con el editor
		welcome.y = top + Std.int((statusY - outH - top) / 2) - 30;
	}

	// ------------------------------------------------------------------ archivos

	function currentOpen():Null<CodeStudioFile>
		return currentFile >= 0 && currentFile < files.length ? files[currentFile] : null;

	function canSave():Bool
		return currentOpen() != null && currentOpen().editable;

	function canEdit():Bool
		return canSave();

	function canFormat():Bool
		return canSave() && currentOpen().kind == "json";

	public function openFile(index:Int):Void
	{
		if (index < 0 || index >= files.length) return;
		activate(files[index]);
	}

	function activate(f:Null<CodeStudioFile>):Void
	{
		if (f != null)
		{
			if (openTabs.indexOf(f) < 0) openTabs.push(f);
			currentFile = files.indexOf(f);
		}
		else
			currentFile = -1;

		editor.setFile(f);
		welcome.visible = f == null;
		tabs.refresh(openTabs, f);
		tree.setActive(f);
		refreshFileStatus();
		runJsonCheck();
		if (f != null) editor.focus();
	}

	function closeTab(f:Null<CodeStudioFile>):Void
	{
		if (f == null) return;
		if (f.dirty && !f.closeArmed)
		{
			f.closeArmed = true;
			warn("[FMCE] " + f.name + " tiene cambios sin guardar. Guarda con Ctrl+S o cierra otra vez para descartarlos.");
			return;
		}
		var wasActive = f == currentOpen();
		var pos = openTabs.indexOf(f);
		openTabs.remove(f);
		f.closeArmed = false;
		if (f.dirty)
		{
			// descartar: vuelve a lo que hay en disco
			if (f.saved == null)
			{
				var i = files.indexOf(f);
				if (i >= 0) files.splice(i, 1);
				tree.setFiles(files, null);
			}
			else
				f.content = f.saved;
		}
		editor.forget(f);
		if (wasActive)
		{
			var next:Null<CodeStudioFile> = null;
			if (openTabs.length > 0) next = openTabs[Std.int(Math.min(pos, openTabs.length - 1))];
			activate(next);
		}
		else
		{
			tabs.refresh(openTabs, currentOpen());
			tree.refreshMarks();
		}
	}

	function nextTab(step:Int):Void
	{
		if (openTabs.length < 2) return;
		var i = openTabs.indexOf(currentOpen());
		i = (i + step + openTabs.length) % openTabs.length;
		activate(openTabs[i]);
	}

	function newScript():Void
	{
		var f = onNewScript();
		if (f == null)
		{
			warn("[FMCE] No se pudo crear un script nuevo aqui.");
			return;
		}
		files.push(f);
		files.sort(function(a, b)
		{
			if (a.kind != b.kind) return a.kind == "haxe" ? -1 : 1;
			return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase());
		});
		tree.setFiles(files, f);
		activate(f);
		info("[FMCE] Nuevo script: " + f.name + " (guárdalo con Ctrl+S)");
	}

	public function hasUnsaved():Bool
	{
		for (f in files)
			if (f.dirty && f.editable) return true;
		return false;
	}

	// ------------------------------------------------------------------ guardar / ejecutar

	public function getCode():String
		return editor != null ? editor.getText() : "";

	function syncFile(f:CodeStudioFile):Void
	{
		if (f == currentOpen() && editor.file == f) f.setFromEditor(editor.getText());
	}

	public function save():Void
	{
		var f = currentOpen();
		if (f == null) return;
		syncFile(f);
		if (saveOne(f)) status.setMessage(f.name + "  •  Guardado");
		refreshFileStatus(false);
		tabs.refresh(openTabs, f);
		tree.refreshMarks();
	}

	public function saveAll():Void
	{
		var count = 0;
		var failed = 0;
		syncFile(currentOpen());
		for (f in files)
		{
			if (!f.dirty || !f.editable) continue;
			if (saveOne(f)) count++;
			else failed++;
		}
		if (count == 0 && failed == 0) info("[FMCE] No hay cambios que guardar.");
		else status.setMessage("Guardados " + count + " archivo(s)" + (failed > 0 ? ", " + failed + " con error" : ""), failed > 0);
		tabs.refresh(openTabs, currentOpen());
		tree.refreshMarks();
	}

	function saveOne(f:CodeStudioFile):Bool
	{
		if (!f.editable)
		{
			status.setMessage(f.name + "  •  SOLO LECTURA");
			warn("[FMCE] No se puede modificar " + f.name + ". " + f.readOnlyReason);
			return false;
		}
		if (onSave(f))
		{
			f.markSaved();
			ok("[FMCE] Guardado " + f.path);
			return true;
		}
		status.setMessage(f.name + "  •  error al guardar", true);
		return false;
	}

	public function run():Void
	{
		var f = currentOpen();
		if (f == null) return;
		if (f.kind != "haxe")
		{
			warn("[FMCE] Ejecutar solo prepara scripts Haxe. Abre un .hx.");
			return;
		}
		save();
		onRun(f);
	}

	public function previewSprites():Void
		onPreview();

	// ------------------------------------------------------------------ buscar / formatear / salida

	function openFind(prefill:String):Void
	{
		if (currentOpen() == null) return;
		findBar.open(prefill);
	}

	function toggleOutput():Void
		output.setCollapsed(!output.collapsed);

	function formatJson():Void
	{
		var f = currentOpen();
		if (f == null || f.kind != "json" || !f.editable) return;
		try
		{
			var pretty = Json.stringify(Json.parse(editor.getText()), null, "  ");
			editor.setTextAsEdit(pretty);
			info("[FMCE] JSON formateado.");
		}
		catch (e:Dynamic)
		{
			error("[FMCE] No se puede formatear: " + Std.string(e));
		}
	}

	/** Revisa el JSON abierto y marca la linea del error. */
	function runJsonCheck():Void
	{
		jsonTimer = -1;
		var f = currentOpen();
		if (f == null || f.kind != "json")
		{
			editor.setErrorLine(-1);
			status.setMessage(f == null ? "Listo" : f.name);
			return;
		}
		var text = editor.getText();
		if (text.length > 600000)
		{
			editor.setErrorLine(-1);
			status.setMessage(f.name + "  •  JSON grande: no se valida mientras escribes");
			return;
		}
		try
		{
			Json.parse(text);
			editor.setErrorLine(-1);
			status.setMessage(f.name + (f.editable ? "" : "  •  SOLO LECTURA"));
		}
		catch (e:Dynamic)
		{
			var msg = Std.string(e);
			var line = -1;
			var r = ~/position (\d+)/;
			if (r.match(msg))
			{
				var pos = Std.parseInt(r.matched(1));
				if (pos != null)
				{
					line = 0;
					for (i in 0...Std.int(Math.min(pos, text.length)))
						if (StringTools.fastCodeAt(text, i) == 10) line++;
				}
			}
			editor.setErrorLine(line);
			status.setMessage("JSON inválido" + (line >= 0 ? " (línea " + (line + 1) + ")" : "") + ": " + msg, true);
		}
	}

	function onEditorChange():Void
	{
		var f = currentOpen();
		if (f == null) return;
		syncFile(f);
		f.closeArmed = false;
		tabs.refresh(openTabs, f);
		tree.refreshMarks();
		if (f.kind == "json") jsonTimer = 0.5;
	}

	function refreshFileStatus(updateMessage:Bool = true):Void
	{
		var f = currentOpen();
		if (f == null)
		{
			status.setFileInfo("", "");
			if (updateMessage) status.setMessage("Listo");
			return;
		}
		var extra = (f.editable ? "" : "SOLO LECTURA  ") + (f.crlf ? "CRLF" : "LF");
		status.setFileInfo(f.kindLabel(), extra);
		if (!f.editable && updateMessage) warn("[FMCE] " + f.readOnlyReason);
	}

	// ------------------------------------------------------------------ log

	public function log(message:String):Void
	{
		var lower = message.toLowerCase();
		var color = CodeTheme.TEXT;
		if (lower.indexOf("error") >= 0 || lower.indexOf("invalid") >= 0 || lower.indexOf("bloquead") >= 0 || lower.indexOf("no se pudo") >= 0)
			color = CodeTheme.ERROR;
		else if (lower.indexOf("aun no") >= 0 || lower.indexOf("no se puede") >= 0 || lower.indexOf("sin guardar") >= 0)
			color = CodeTheme.WARN;
		else if (lower.indexOf("guardado") >= 0 || lower.indexOf("saved") >= 0)
			color = CodeTheme.OK;
		output.log(timeTag() + message, color);
	}

	function timeTag():String
		return "[" + Date.now().toString().substr(11, 8) + "] ";

	function info(message:String):Void
		output.log(timeTag() + message, CodeTheme.TEXT);

	function ok(message:String):Void
		output.log(timeTag() + message, CodeTheme.OK);

	function warn(message:String):Void
		output.log(timeTag() + message, CodeTheme.WARN);

	function error(message:String):Void
		output.log(timeTag() + message, CodeTheme.ERROR);

	// ------------------------------------------------------------------ teclado

	function onKeyDown(event:KeyboardEvent):Void
	{
		if (menu == null) return;
		var ctrl = event.ctrlKey || event.commandKey;

		if (event.keyCode == Keyboard.F5)
		{
			event.preventDefault();
			run();
			return;
		}
		if (event.keyCode == Keyboard.F6)
		{
			event.preventDefault();
			previewSprites();
			return;
		}
		if (event.altKey && event.shiftKey && event.keyCode == Keyboard.F)
		{
			event.preventDefault();
			formatJson();
			return;
		}
		if (ctrl)
		{
			switch (event.keyCode)
			{
				case Keyboard.S:
					event.preventDefault();
					if (event.shiftKey) saveAll();
					else save();
					return;
				case Keyboard.N:
					event.preventDefault();
					newScript();
					return;
				case Keyboard.W:
					event.preventDefault();
					closeTab(currentOpen());
					return;
				case Keyboard.F:
					event.preventDefault();
					openFind("");
					return;
				case Keyboard.G:
					event.preventDefault();
					openFind(":");
					return;
				case Keyboard.J:
					event.preventDefault();
					toggleOutput();
					return;
				case Keyboard.TAB:
					event.preventDefault();
					nextTab(event.shiftKey ? -1 : 1);
					return;
			}
		}
		if (!menu.isOpen) editor.onKey(event);
	}

	// ------------------------------------------------------------------ frame

	override public function update(elapsed:Float):Void
	{
		escapeHandled = false;
		overlay.sync();
		CodeDraw.blocked = menu.isOpen;

		if (FlxG.keys.justPressed.ESCAPE)
		{
			if (menu.isOpen)
			{
				menu.close();
				escapeHandled = true;
			}
			else if (findBar.isOpen)
			{
				findBar.close();
				escapeHandled = true;
			}
		}

		super.update(elapsed);

		if (jsonTimer >= 0)
		{
			jsonTimer -= elapsed;
			if (jsonTimer < 0) runJsonCheck();
		}
	}

	override public function destroy():Void
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		CodeDraw.blocked = false;
		FlxG.sound.muteKeys = oldMute;
		FlxG.sound.volumeUpKeys = oldUp;
		FlxG.sound.volumeDownKeys = oldDown;
		super.destroy();
		if (overlay != null) overlay.destroy();
		overlay = null;
	}
}
