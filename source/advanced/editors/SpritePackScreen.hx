package advanced.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import funkin.editors.ui.*;
import funky.game.SpriteBuilder;
import haxe.Json;
import haxe.io.Path;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Administrador de sprites del nivel: una cuadricula con la miniatura de cada sprite de `<nivel>/sprites/`. */
class SpritePackScreen extends UISubstateWindow
{
	static inline var COLS:Int = 4;
	static inline var ROWS:Int = 4;
	static inline var CELL:Int = 96;
	static inline var GAP:Int = 8;
	static inline var PAD:Int = 20;
	static inline var HEAD:Int = 40;
	static inline var THUMB:Int = 80;

	/** Paleta del editor de escena: marco de las listas, seleccion azul y borrar en rojo claro. */
	static inline var CELL_COLOR:Int = 0xFF3A4152;
	static inline var SELECT_COLOR:Int = 0xFF8CC4FF;
	static inline var DANGER_COLOR:Int = 0xFFFF8080;

	var levelDir:String;
	var selected:String;
	var onPick:String->Void;
	var allowNone:Bool;
	var onImported:Null<String->Void>;

	var all:Array<String> = [];
	var shown:Array<String> = [];
	var kinds:Map<String, String> = new Map<String, String>();
	var filter:Int = 0;
	var scroll:Int = 0;

	var cellBg:Array<FlxSprite> = [];
	var cellThumb:Array<FlxSprite> = [];
	var cellName:Array<UIText> = [];
	var thumbs:Map<String, Null<FlxGraphic>> = new Map<String, Null<FlxGraphic>>();
	var filterButtons:Array<UIButton> = [];
	var nameText:UIText;
	var countText:UIText;
	var useButton:UIButton;

	var lastClick:String = "";
	var lastClickTime:Float = 0;
	var mouseP:FlxPoint = FlxPoint.get();

	/** @param current sprite que ya tiene el campo (se marca al abrir). @param startOnIcons abre en el filtro ICONOS. */
	public function new(levelDir:String, current:String, onPick:String->Void, allowNone:Bool = false, startOnIcons:Bool = false, ?onImported:String->Void)
	{
		super();
		this.levelDir = levelDir;
		this.selected = current == null ? "" : current;
		this.onPick = onPick;
		this.allowNone = allowNone;
		this.onImported = onImported;
		this.filter = startOnIcons ? 1 : 0;
	}

	public override function create():Void
	{
		winTitle = "Administrador de sprites";
		winWidth = PAD * 2 + COLS * CELL + (COLS - 1) * GAP;
		winHeight = HEAD + ROWS * CELL + (ROWS - 1) * GAP + 14 + 28 + 8 + 28 + 10 + 32 + PAD;
		super.create();

		var wx = windowSpr.x;
		var wy = windowSpr.y;
		for (i in 0...COLS * ROWS)
		{
			var x = wx + PAD + (i % COLS) * (CELL + GAP);
			var y = wy + HEAD + Std.int(i / COLS) * (CELL + GAP);
			var bg = new FlxSprite(x, y).makeGraphic(CELL, CELL, 0xFFFFFFFF);
			bg.color = CELL_COLOR;
			var thumb = new FlxSprite(x, y);
			var label = new UIText(x, y + CELL / 2 - 8, CELL, "", 12);
			label.alignment = CENTER;
			cellBg.push(bg);
			cellThumb.push(thumb);
			cellName.push(label);
			add(bg);
			add(thumb);
			add(label);
		}

		var rowY = wy + HEAD + ROWS * CELL + (ROWS - 1) * GAP + 14;
		var titles = ["Todos", "Iconos", "Otros"];
		var fx = wx + PAD;
		for (i in 0...3)
		{
			var index = i;
			var b = new UIButton(fx, rowY, titles[i], function() setFilter(index), 84, 28);
			add(b);
			filterButtons.push(b);
			fx += 88;
		}
		countText = new UIText(wx + winWidth - PAD - 120, rowY + 6, 120, "", 14);
		countText.alignment = RIGHT;
		add(countText);

		nameText = new UIText(wx + PAD, rowY + 28 + 8, winWidth - PAD * 2, "", 15);
		add(nameText);

		var buttonsY = rowY + 28 + 8 + 28 + 10;
		var x = wx + PAD;
		if (allowNone)
		{
			var none = new UIButton(x, buttonsY, "Quitar", function() pickNone(), 100, 32);
			none.color = DANGER_COLOR;
			add(none);
			x += 104;
		}
		add(new UIButton(x, buttonsY, "+ Nuevo", function() importSprite(), 100, 32));
		x += 104;
		useButton = new UIButton(x, buttonsY, "Usar", function() apply(), Std.int(wx + winWidth - PAD - x), 32);
		add(useButton);

		reloadNames();
		refresh();
		scrollToSelected();
	}

	// ── datos ──

	function reloadNames():Void
	{
		var names = SpriteBuilder.listSprites(levelDir);
		kinds = new Map<String, String>();
		for (n in names) kinds.set(n, kindOf(n));
		// los iconos primero, como en el resto del editor
		var icons = [for (n in names) if (kinds.get(n) == "icon") n];
		var others = [for (n in names) if (kinds.get(n) != "icon") n];
		all = icons.concat(others);
	}

	/** `type` del config.json del sprite ("icon", "character"...) o "". */
	function kindOf(name:String):String
	{
		#if sys
		try
		{
			var path = Path.join([SpriteBuilder.spriteDir(levelDir, name), "config.json"]);
			if (FileSystem.exists(path))
			{
				var type:Dynamic = Reflect.field(Json.parse(File.getContent(path)), "type");
				if (type != null) return Std.string(type);
			}
		}
		catch (e:Dynamic) {}
		#end
		return "";
	}

	function applyFilter():Void
	{
		shown = [for (n in all) if (filter == 0 || (filter == 1 && kinds.get(n) == "icon") || (filter == 2 && kinds.get(n) != "icon")) n];
		var maxScroll = Std.int(Math.max(0, Math.ceil(shown.length / COLS) - ROWS));
		if (scroll > maxScroll) scroll = maxScroll;
		if (scroll < 0) scroll = 0;
	}

	function setFilter(index:Int):Void
	{
		filter = index;
		scroll = 0;
		refresh();
	}

	function scrollToSelected():Void
	{
		var at = shown.indexOf(selected);
		if (at < 0) return;
		var row = Std.int(at / COLS);
		if (row < scroll) scroll = row;
		else if (row >= scroll + ROWS) scroll = row - ROWS + 1;
		refresh();
	}

	/** Foto del primer frame del sprite (null si no se pudo: video, atlas de Animate...). */
	function thumbFor(name:String):Null<FlxGraphic>
	{
		if (thumbs.exists(name)) return thumbs.get(name);
		var g:Null<FlxGraphic> = null;
		try
		{
			if (SpriteBuilder.videoCount(levelDir, name) == 0)
			{
				var spr = SpriteBuilder.build(levelDir, name);
				if (spr.loaded)
				{
					spr.update(0);
					var pixels = spr.updateFramePixels();
					if (pixels != null && pixels.width > 0 && pixels.height > 0) g = FlxGraphic.fromBitmapData(pixels.clone(), true);
				}
				spr.destroy();
			}
		}
		catch (e:Dynamic) {}
		thumbs.set(name, g);
		return g;
	}

	// ── dibujo ──

	function refresh():Void
	{
		applyFilter();
		for (i in 0...filterButtons.length) filterButtons[i].color = i == filter ? SELECT_COLOR : 0xFFFFFFFF;

		var first = scroll * COLS;
		for (i in 0...cellBg.length)
		{
			var index = first + i;
			var has = index < shown.length;
			var bg = cellBg[i];
			var thumb = cellThumb[i];
			var label = cellName[i];
			bg.visible = has;
			thumb.visible = false;
			label.visible = false;
			if (!has) continue;

			var name = shown[index];
			bg.color = name == selected ? SELECT_COLOR : CELL_COLOR;
			var g = thumbFor(name);
			if (g != null)
			{
				thumb.loadGraphic(g);
				var s = Math.min(Math.min(THUMB / g.width, THUMB / g.height), 3);
				thumb.scale.set(s, s);
				thumb.updateHitbox();
				thumb.antialiasing = s < 1;
				thumb.x = bg.x + (CELL - thumb.width) / 2;
				thumb.y = bg.y + (CELL - thumb.height) / 2;
				thumb.visible = true;
			}
			else
			{
				label.text = name.length > 12 ? name.substr(0, 11) + "…" : name;
				label.visible = true;
			}
		}

		nameText.text = selected == "" ? "(ninguno)" : "\"" + selected + "\"";
		countText.text = shown.length + (shown.length == 1 ? " sprite" : " sprites");
		useButton.selectable = selected != "" && all.indexOf(selected) >= 0;
	}

	// ── acciones ──

	function apply():Void
	{
		if (selected == "" || all.indexOf(selected) < 0) return;
		var name = selected;
		var cb = onPick;
		close();
		if (cb != null) cb(name);
	}

	function pickNone():Void
	{
		var cb = onPick;
		close();
		if (cb != null) cb("");
	}

	function importSprite():Void
	{
		openSubState(new SpriteImportScreen(levelDir, function(name:String)
		{
			reloadNames();
			thumbs.remove(name);
			selected = name;
			filter = 0;
			if (onImported != null) onImported(name);
			scrollToSelected();
			refresh();
		}));
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (subCam == null || windowSpr == null) return;
		if (FlxG.keys.justPressed.ESCAPE)
		{
			close();
			return;
		}
		if (FlxG.mouse.wheel != 0)
		{
			var maxScroll = Std.int(Math.max(0, Math.ceil(shown.length / COLS) - ROWS));
			var next = Std.int(Math.max(0, Math.min(maxScroll, scroll - FlxG.mouse.wheel)));
			if (next != scroll)
			{
				scroll = next;
				refresh();
			}
		}
		if (!FlxG.mouse.justPressed) return;

		var m = FlxG.mouse.getWorldPosition(subCam, mouseP);
		for (i in 0...cellBg.length)
		{
			var bg = cellBg[i];
			if (!bg.visible || m.x < bg.x || m.x >= bg.x + CELL || m.y < bg.y || m.y >= bg.y + CELL) continue;
			var name = shown[scroll * COLS + i];
			var now = haxe.Timer.stamp();
			var twice = name == lastClick && now - lastClickTime < 0.4;
			lastClick = name;
			lastClickTime = now;
			selected = name;
			refresh();
			if (twice) apply();
			return;
		}
	}

	override public function destroy():Void
	{
		super.destroy();
		for (g in thumbs) if (g != null) FlxG.bitmap.removeIfNoUse(g);
		thumbs.clear();
	}
}
