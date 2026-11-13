package advanced;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import advanced.AdvLang;
import advanced.ui.EditorBackdrop;
import funky.api.DiscordClient;
import funky.backend.LevelArchive;
import funky.backend.chart.LevelLoader;
import funky.core.CoolUtil;
import funky.core.KeyBinds;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import funky.game.HealthIcon;
import funky.menus.BoldText;
import funky.menus.MainMenuState;

class AdvancedModeState extends FlxState
{

	public static var antiGay:Bool = false;

	static inline var BG:Int = 0xFF101217;
	static inline var MUTED:Int = 0xFF858B97;
	static inline var ACTIVE:Int = 0xFFFFFFFF;

	static inline var ROW_H:Float = 112;
	static inline var ANCHOR_Y:Float = 290;
	static inline var ROW_X:Float = 190;
	static inline var SELECTED_SHIFT:Float = 36;

	var levels:Array<String> = [];
	var rows:Array<BoldText> = [];
	var icons:Array<Null<HealthIcon>> = [];
	var iconTried:Array<Bool> = [];
	var arrow:Null<BoldText>;
	var importButton:Null<FlxText>;
	var pendingImport:Null<String>;
	var selected:Int = 0;
	var scrollPos:Float = 0;
	var chosen:Bool = false;
	var info:FlxText;

	var startLevel:Null<String>;

	public function new(?startLevel:String)
	{
		super();
		this.startLevel = startLevel;
	}

	override public function create():Void
	{
		super.create();

		if (antiGay)
			createGay();
		else
			createMenu();
	}

	function createMenu():Void
	{

		CoolUtil.playEditorSong();

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		add(bg);

		try
		{
			add(new EditorBackdrop());
		}
		catch (e:Dynamic) {}

		add(new BoldText(16, 6, AdvLang.t("modeMenu.title", null, "MODO AVANZADO >"), 0.55));
		var desc = new FlxText(18, 50, FlxG.width - 40, AdvLang.t("modeMenu.desc", [KeyBinds.label(KeyBinds.ACCEPT)], "Selecciona el nivel que quieres editar.\n{0} para elegir  |  ESC volver"), 15);
		desc.color = MUTED;
		add(desc);

		levels = Paths.listLevels();
		if (startLevel != null)
		{
			var idx = levels.indexOf(startLevel);
			if (idx >= 0) selected = idx;
		}
		if (levels.length > 0)
		{
			for (i in 0...levels.length)
			{
				var row = new BoldText(ROW_X, ANCHOR_Y + i * ROW_H, levels[i], 0.95);
				add(row);
				rows.push(row);
				icons.push(null);
				iconTried.push(false);
			}

			arrow = new BoldText(0, 0, ">", 0.95);
			add(arrow);
		}
		else
		{
			var empty = new FlxText(0, 255, FlxG.width, AdvLang.t("modeMenu.noLevels", [Paths.levelsRoot()], "No hay niveles en {0}"), 18);
			empty.color = MUTED;
			empty.alignment = FlxTextAlign.CENTER;
			add(empty);
		}

		info = new FlxText(0, FlxG.height - 34, FlxG.width, "", 15);
		info.color = MUTED;
		info.alignment = FlxTextAlign.CENTER;
		add(info);

		importButton = new FlxText(FlxG.width - 330, 14, 310, AdvLang.t("modeMenu.importButton", null, "IMPORTAR .FMCE  [I]"), 20);
		importButton.color = ACTIVE;
		importButton.alignment = FlxTextAlign.RIGHT;
		add(importButton);

		DiscordClient.customPresence(AdvLang.t("modeMenu.presenceTitle", null, "Modo Avanzado"), AdvLang.t("modeMenu.presenceSelecting", null, "Seleccionando nivel"), "fmce", "", false);
		scrollPos = selected;
		layoutRows(1);
		TransitionHandler.playIn(this);
	}

	function layoutRows(lerp:Float):Void
	{
		scrollPos += (selected - scrollPos) * lerp;

		for (i in 0...rows.length)
		{
			var row = rows[i];
			var active = i == selected;
			var y = ANCHOR_Y + (i - scrollPos) * ROW_H;
			var x = ROW_X + (active ? SELECTED_SHIFT : 0);

			row.visible = y > -ROW_H && y < FlxG.height;
			row.setPosition(x, y);
			row.alpha = active ? 1 : 0.55;

			var icon = iconFor(i);
			if (icon != null)
			{
				icon.visible = row.visible;
				icon.alpha = row.alpha;
				icon.centerAt(x - 14 - HealthIcon.FIT / 2, y + row.height / 2);
			}
		}

		if (arrow != null && selected >= 0 && selected < rows.length)
		{
			var sel = rows[selected];
			arrow.visible = sel.visible;
			arrow.setPosition(sel.x + sel.width + 24, sel.y);
		}

	}

	function iconFor(index:Int):Null<HealthIcon>
	{
		if (icons[index] != null) return icons[index];
		if (iconTried[index] || Math.abs(index - selected) > 3) return null;
		iconTried[index] = true;

		#if sys
		var path = Paths.levelsRoot() + levels[index];
		if (LevelLoader.isArchive(path)) return null;
		var name = LevelLoader.opponentIcon(path);
		if (name == null) return null;

		var icon = new HealthIcon(path, name, false);
		if (!icon.loaded)
		{
			icon.destroy();
			return null;
		}
		add(icon);
		icons[index] = icon;
		return icon;
		#else
		return null;
		#end
	}

	function refresh():Void
	{
		if (info == null) return;
		info.color = MUTED;
		info.text = levels.length == 0 ? AdvLang.t("modeMenu.createLevel", null, "Crea un nivel en la carpeta levels/ para usar el modo avanzado.") : (selected + 1) + " / " + levels.length;
	}

	function importLevels():Void
	{
		#if sys
		var found = LevelArchive.listArchives();
		if (found.length == 0)
		{
			#if desktop
			var dialog = new lime.ui.FileDialog();
			dialog.onSelect.add(function(path:String) pendingImport = path);
			dialog.browse(lime.ui.FileDialogType.OPEN, "fmce", null, AdvLang.t("modeMenu.importDialog", null, "Importar nivel .FMCE"));
			return;
			#else
			setInfo(AdvLang.t("modeMenu.noArchives", [funky.core.Paths.levelsRoot()], "No hay .FMCE en {0} (copialo ahi y vuelve a tocar IMPORTAR)"), false);
			return;
			#end
		}

		var messages:Array<String> = [];
		var okCount = 0;
		for (path in found)
		{
			var result = LevelArchive.importArchive(path);
			if (result.ok)
			{
				okCount++;
				LevelArchive.archiveDone(path);
				messages.push(AdvLang.t("modeMenu.importedItem", [result.level, result.files], "{0} ({1} archivos)"));
			}
			else
				messages.push(result.error);
		}

		reloadLevels();
		var joined = messages.join(" | ");
		setInfo(okCount > 0 ? AdvLang.t("modeMenu.imported", [joined], "Importado: {0}") : joined, okCount > 0);
		#end
	}

	function importPicked(path:String):Void
	{
		var result = LevelArchive.importArchive(path);
		if (result.ok) reloadLevels();
		setInfo(result.ok ? AdvLang.t("modeMenu.imported", [AdvLang.t("modeMenu.importedItem", [result.level, result.files], "{0} ({1} archivos)")], "Importado: {0}") : result.error, result.ok);
	}

	function setInfo(text:String, good:Bool):Void
	{
		if (info == null) return;
		info.text = text;
		info.color = good ? 0xFF8FE388 : 0xFFFF8A8A;
	}

	function reloadLevels():Void
	{
		for (row in rows) remove(row, true).destroy();
		for (icon in icons) if (icon != null) remove(icon, true).destroy();
		if (arrow != null) remove(arrow, true).destroy();
		rows = [];
		icons = [];
		iconTried = [];
		arrow = null;

		levels = Paths.listLevels();
		for (i in 0...levels.length)
		{
			var row = new BoldText(ROW_X, ANCHOR_Y + i * ROW_H, levels[i], 0.95);
			add(row);
			rows.push(row);
			icons.push(null);
			iconTried.push(false);
		}
		if (levels.length > 0)
		{
			arrow = new BoldText(0, 0, ">", 0.95);
			add(arrow);
		}
		selected = Std.int(Math.min(selected, Math.max(0, levels.length - 1)));
		scrollPos = selected;
		layoutRows(1);
	}

	function openSelected():Void
	{
		if (levels.length == 0 || selected < 0 || selected >= levels.length) return;
		chosen = true;
		TransitionHandler.switchState(new AdvancedToolsState(levels[selected]));
	}

	function createGay():Void
	{
		var text = new FlxText(0, 0, FlxG.width, AdvLang.t("modeMenu.gay", null, "¡GAY!"), 64);
		text.alignment = FlxTextAlign.CENTER;
		text.screenCenter();
		add(text);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (chosen) return;

		if (KeyBinds.justPressed(KeyBinds.BACK))
		{
			chosen = true;
			TransitionHandler.switchState(new MainMenuState());
			return;
		}
		if (pendingImport != null)
		{
			var path = pendingImport;
			pendingImport = null;
			importPicked(path);
		}

		if (FlxG.keys.justPressed.I || (FlxG.mouse.justPressed && importButton != null && FlxG.mouse.overlaps(importButton)))
		{
			importLevels();
			return;
		}

		if (levels.length == 0) return;

		if (KeyBinds.justPressed(KeyBinds.UP))
		{
			selected = (selected - 1 + levels.length) % levels.length;
			refresh();
		}
		if (KeyBinds.justPressed(KeyBinds.DOWN))
		{
			selected = (selected + 1) % levels.length;
			refresh();
		}
		if (KeyBinds.justPressed(KeyBinds.ACCEPT)) openSelected();

		if (FlxG.mouse.justPressed)
		{
			for (i in 0...rows.length)
			{
				if (!rows[i].visible || !FlxG.mouse.overlaps(rows[i])) continue;
				if (i == selected)
					openSelected();
				else
				{
					selected = i;
					refresh();
				}
				break;
			}
		}

		layoutRows(Math.min(1, elapsed * 12));
	}
}
