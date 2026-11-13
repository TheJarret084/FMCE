package advanced.ui.code;

import advanced.ui.code.MenuBar.MenuDef;
import advanced.ui.code.MenuBar.MenuItem;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import haxe.Json;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;

class CodeStudio extends FlxSpriteGroup
{
	public var files:Array<CodeStudioFile> = [];
	public var currentFile(default, null):Int = -1;

	public var escapeHandled(default, null):Bool = false;

	public var covered(default, null):Bool = false;

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
	var inspector:JsonPanel;
	var inspectorBtn:CodeButton;
	var inspectorOn:Bool = true;
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
		editor.onCaret = function(line, col, sel)
		{
			status.setCaret(line, col, sel);
			if (inspector != null && inspector.exists) inspector.follow(editor.field.caretIndex);
		};

		welcome = CodeDraw.label(0, bodyY + Std.int(editorH / 2) - 30, CodeLang.t("ui.welcome", null, "Elige un archivo del explorador"), 18, CodeTheme.DIM, mainW);
		welcome.alignment = FlxTextAlign.CENTER;

		tabs = new TabBar(tabsY, mainW);
		tabs.onSelect = function(f) activate(f);
		tabs.onClose = closeTab;

		tree = new FileTree(mainW, tabsY, CodeTheme.EXPLORER_W, statusY - tabsY);
		tree.setTitle(levelName != null ? levelName : CodeLang.t("ui.levelDefault", null, "Nivel"));
		tree.onOpen = function(f) activate(f);
		tree.onNewScript = newScript;

		inspector = new JsonPanel(mainW, tabsY, CodeTheme.EXPLORER_W, statusY - tabsY);
		inspector.exists = false;
		inspector.onJump = function(offset, len)
		{
			editor.goToOffset(offset, len);
			editor.focus();
		};
		inspector.onClose = function()
		{
			inspectorOn = false;
			runJsonCheck();
		};

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

			if (covered) return;
			editor.thaw();
			findBar.thaw();
		};

		add(tabs);
		add(editor);
		add(welcome);
		add(findBar);
		add(output);
		add(tree);
		add(inspector);
		add(toolbar);
		add(status);
		add(menu);

		tree.setFiles(files, null);
		output.log("[FMCE] " + CodeLang.t("log.ready", null, "Code Studio listo. Ctrl+S guarda, Ctrl+F busca, Ctrl+G va a una línea."), CodeTheme.MUTED);
		if (files.length > 0) openFile(0);
		else activate(null);

		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
	}

	function buildToolbar(levelName:Null<String>):ToolBar
	{
		var t = new ToolBar(CodeTheme.MENU_H, FlxG.width);
		t.addButton(CodeLang.t("toolbar.save", null, "Guardar"), CodeTheme.TEXT, save);
		t.addButton(CodeLang.t("toolbar.saveAll", null, "Guardar todo"), CodeTheme.TEXT, saveAll);
		t.addSeparator();
		t.addButton(CodeLang.t("toolbar.newScript", null, "+ Script"), CodeTheme.TEXT, newScript);
		t.addSeparator();
		t.addButton(CodeLang.t("toolbar.run", null, "► Ejecutar"), CodeTheme.OK, run);
		t.addButton(CodeLang.t("toolbar.sprites", null, "Sprites"), CodeTheme.TEXT, previewSprites);
		t.addSeparator();
		t.addButton(CodeLang.t("toolbar.find", null, "Buscar"), CodeTheme.TEXT, function() openFind(""));
		t.addSeparator();
		inspectorBtn = t.addButton(CodeLang.t("toolbar.inspector", null, "{ } Inspector JSON"), CodeTheme.TEXT, toggleInspector);
		inspectorBtn.toggled = inspectorOn;
		t.setTitle(levelName != null ? levelName : "");
		return t;
	}

	function buildMenus():Array<MenuDef>
	{
		return [
			{
				title: CodeLang.t("menu.file", null, "Archivo"),
				items: function():Array<MenuItem> return [
					{label: CodeLang.t("file.save", null, "Guardar"), shortcut: "Ctrl+S", action: save, disabled: !canSave()},
					{label: CodeLang.t("file.saveAll", null, "Guardar todo"), shortcut: CodeLang.t("shortcut.saveAll", null, "Ctrl+Mayús+S"), action: saveAll},
					{label: "", separator: true},
					{label: CodeLang.t("file.newScript", null, "Nuevo script"), shortcut: "Ctrl+N", action: newScript},
					{label: CodeLang.t("file.closeTab", null, "Cerrar pestaña"), shortcut: "Ctrl+W", action: function() closeTab(currentOpen()), disabled: currentOpen() == null},
					{label: "", separator: true},
					{label: CodeLang.t("file.back", null, "Volver"), shortcut: "ESC", action: function()
					{
						if (onExit != null) onExit();
					}}
				]
			},
			{
				title: CodeLang.t("menu.edit", null, "Editar"),
				items: function():Array<MenuItem> return [
					{label: CodeLang.t("edit.undo", null, "Deshacer"), shortcut: "Ctrl+Z", action: editor.undo, disabled: !canEdit()},
					{label: CodeLang.t("edit.redo", null, "Rehacer"), shortcut: "Ctrl+Y", action: editor.redo, disabled: !canEdit()},
					{label: "", separator: true},
					{label: CodeLang.t("edit.find", null, "Buscar…"), shortcut: "Ctrl+F", action: function() openFind("")},
					{label: CodeLang.t("edit.goToLine", null, "Ir a la línea…"), shortcut: "Ctrl+G", action: function() openFind(":")},
					{label: "", separator: true},
					{label: CodeLang.t("edit.formatJson", null, "Formatear JSON"), shortcut: CodeLang.t("shortcut.formatJson", null, "Alt+Mayús+F"), action: formatJson, disabled: !canFormat()}
				]
			},
			{
				title: CodeLang.t("menu.view", null, "Ver"),
				items: function():Array<MenuItem> return [
					{label: output.collapsed ? CodeLang.t("view.showOutput", null, "Mostrar salida") : CodeLang.t("view.hideOutput", null, "Ocultar salida"), shortcut: "Ctrl+J", action: toggleOutput},
					{label: CodeLang.t("view.clearOutput", null, "Limpiar salida"), action: output.clearLog},
					{label: "", separator: true},
					{label: inspectorOn ? CodeLang.t("view.hideInspector", null, "Ocultar inspector JSON") : CodeLang.t("view.showInspector", null, "Mostrar inspector JSON"), shortcut: "F4", action: toggleInspector}
				]
			},
			{
				title: CodeLang.t("menu.project", null, "Proyecto"),
				items: function():Array<MenuItem> return [
					{label: CodeLang.t("project.runScript", null, "Ejecutar script"), shortcut: "F5", action: run, disabled: !(currentOpen() != null && currentOpen().kind == "haxe")},
					{label: CodeLang.t("project.spriteEditor", null, "Editor de sprites"), shortcut: "F6", action: previewSprites}
				]
			},
			{
				title: CodeLang.t("menu.help", null, "Ayuda"),
				items: function():Array<MenuItem> return [
					{label: CodeLang.t("help.nextTab", null, "Ctrl+Tab: siguiente pestaña")},
					{label: CodeLang.t("help.indent", null, "Tab / Mayús+Tab: sangría")},
					{label: CodeLang.t("help.comment", null, "Ctrl+/: comentar líneas")},
					{label: CodeLang.t("help.duplicate", null, "Ctrl+D: duplicar línea")},
					{label: CodeLang.t("help.middleClick", null, "Clic central: cerrar pestaña")},
					{label: CodeLang.t("help.inspector", null, "Inspector JSON: clic en una fila va a esa clave")}
				]
			}
		];
	}

	function relayout():Void
	{
		var bodyY = CodeTheme.MENU_H + CodeTheme.TOOL_H + CodeTheme.TAB_H;
		var findH = findBar.isOpen ? CodeTheme.FIND_H : 0;
		var outH = output.currentHeight();
		var top = bodyY + findH;
		editor.setRect(0, top, mainW, statusY - outH - top);

		welcome.y = top + Std.int((statusY - outH - top) / 2) - 30;
	}

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
			warn("[FMCE] " + CodeLang.t("log.unsavedClose", [f.name], "{0} tiene cambios sin guardar. Guarda con Ctrl+S o cierra otra vez para descartarlos."));
			return;
		}
		var wasActive = f == currentOpen();
		var pos = openTabs.indexOf(f);
		openTabs.remove(f);
		f.closeArmed = false;
		if (f.dirty)
		{

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
			warn("[FMCE] " + CodeLang.t("log.newScriptFail", null, "No se pudo crear un script nuevo aquí."));
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
		info("[FMCE] " + CodeLang.t("log.newScript", [f.name], "Nuevo script: {0} (guárdalo con Ctrl+S)"));
	}

	public function hasUnsaved():Bool
	{
		for (f in files)
			if (f.dirty && f.editable) return true;
		return false;
	}

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
		if (saveOne(f)) status.setMessage(CodeLang.t("status.saved", [f.name], "{0}  •  Guardado"));
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
		if (count == 0 && failed == 0) info("[FMCE] " + CodeLang.t("log.noChanges", null, "No hay cambios que guardar."));
		else status.setMessage(CodeLang.t("status.savedCount", [count], "Guardados {0} archivo(s)") + (failed > 0 ? CodeLang.t("status.savedFailed", [failed], ", {0} con error") : ""), failed > 0);
		tabs.refresh(openTabs, currentOpen());
		tree.refreshMarks();
	}

	function saveOne(f:CodeStudioFile):Bool
	{
		if (!f.editable)
		{
			status.setMessage(CodeLang.t("status.readOnly", [f.name], "{0}  •  SOLO LECTURA"));
			warn("[FMCE] " + CodeLang.t("log.readOnly", [f.name, f.readOnlyReason], "No se puede modificar {0}. {1}"));
			return false;
		}
		if (onSave(f))
		{
			f.markSaved();
			ok("[FMCE] " + CodeLang.t("log.saved", [f.path], "Guardado {0}"));
			return true;
		}
		status.setMessage(CodeLang.t("status.saveError", [f.name], "{0}  •  error al guardar"), true);
		return false;
	}

	public function run():Void
	{
		var f = currentOpen();
		if (f == null) return;
		if (f.kind != "haxe")
		{
			warn("[FMCE] " + CodeLang.t("log.runOnlyHaxe", null, "Ejecutar solo prepara scripts Haxe. Abre un .hx."));
			return;
		}
		save();
		onRun(f);
	}

	public function previewSprites():Void
		onPreview();

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
			info("[FMCE] " + CodeLang.t("log.jsonFormatted", null, "JSON formateado."));
		}
		catch (e:Dynamic)
		{
			error("[FMCE] " + CodeLang.t("log.formatFail", [Std.string(e)], "No se puede formatear: {0}"));
		}
	}

	function toggleInspector():Void
	{
		inspectorOn = !inspectorOn;
		var f = currentOpen();
		if (inspectorOn && (f == null || f.kind != "json")) info("[FMCE] " + CodeLang.t("log.inspectorHint", null, "El inspector aparece al abrir un archivo .json."));
		runJsonCheck();
	}

	function syncInspector(f:Null<CodeStudioFile>):Void
	{
		var show = inspectorOn && f != null && f.kind == "json";
		inspector.exists = show;
		tree.exists = !show;
		if (inspectorBtn != null) inspectorBtn.toggled = inspectorOn;
		if (!show) return;
		inspector.setSource(f, editor.getText());
		inspector.follow(editor.field.caretIndex);
	}

	public function setCovered(value:Bool):Void
	{
		if (covered == value) return;
		covered = value;
		if (value)
		{
			editor.flushHighlight();
			editor.freeze();
			findBar.freeze();
			if (FlxG.stage != null) FlxG.stage.focus = null;
		}
		else
		{
			editor.thaw();
			findBar.thaw();
			editor.focus();
		}
	}

	function runJsonCheck():Void
	{
		jsonTimer = -1;
		var f = currentOpen();
		syncInspector(f);
		if (f == null || f.kind != "json")
		{
			editor.setErrorLine(-1);
			status.setMessage(f == null ? CodeLang.t("status.ready", null, "Listo") : f.name);
			return;
		}
		var text = editor.getText();
		if (text.length > 600000)
		{
			editor.setErrorLine(-1);
			status.setMessage(CodeLang.t("status.jsonLarge", [f.name], "{0}  •  JSON grande: no se valida mientras escribes"));
			return;
		}
		try
		{
			Json.parse(text);
			editor.setErrorLine(-1);
			status.setMessage(f.editable ? f.name : CodeLang.t("status.readOnly", [f.name], "{0}  •  SOLO LECTURA"));
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
			status.setMessage(line >= 0 ? CodeLang.t("status.jsonInvalidLine", [line + 1, msg], "JSON inválido (línea {0}): {1}") : CodeLang.t("status.jsonInvalid", [msg], "JSON inválido: {0}"), true);
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
			if (updateMessage) status.setMessage(CodeLang.t("status.ready", null, "Listo"));
			return;
		}
		var extra = (f.editable ? "" : CodeLang.t("status.readOnlyShort", null, "SOLO LECTURA") + "  ") + (f.crlf ? "CRLF" : "LF");
		status.setFileInfo(f.kindLabel(), extra);
		if (!f.editable && updateMessage) warn("[FMCE] " + f.readOnlyReason);
	}

	/**
	 * level: "error" | "warn" | "ok" | "info". Si no se indica, se adivina por palabras clave
	 * (ES/EN) como antes; los mensajes traducidos deberian pasar siempre el nivel.
	 */
	public function log(message:String, ?level:String):Void
	{
		var color = CodeTheme.TEXT;
		if (level != null)
		{
			color = switch (level)
			{
				case "error": CodeTheme.ERROR;
				case "warn": CodeTheme.WARN;
				case "ok": CodeTheme.OK;
				default: CodeTheme.TEXT;
			};
		}
		else
		{
			var lower = message.toLowerCase();
			if (lower.indexOf("error") >= 0 || lower.indexOf("invalid") >= 0 || lower.indexOf("bloquead") >= 0 || lower.indexOf("no se pudo") >= 0
				|| lower.indexOf("blocked") >= 0 || lower.indexOf("could not") >= 0)
				color = CodeTheme.ERROR;
			else if (lower.indexOf("aun no") >= 0 || lower.indexOf("no se puede") >= 0 || lower.indexOf("sin guardar") >= 0
				|| lower.indexOf("not connected") >= 0 || lower.indexOf("cannot") >= 0 || lower.indexOf("unsaved") >= 0)
				color = CodeTheme.WARN;
			else if (lower.indexOf("guardado") >= 0 || lower.indexOf("saved") >= 0)
				color = CodeTheme.OK;
		}
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

	function onKeyDown(event:KeyboardEvent):Void
	{
		if (menu == null || covered) return;
		var ctrl = event.ctrlKey || event.commandKey;

		if (event.keyCode == Keyboard.F4)
		{
			event.preventDefault();
			toggleInspector();
			return;
		}
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
