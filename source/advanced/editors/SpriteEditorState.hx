package advanced.editors;

import advanced.AdvancedToolsState;
import advanced.ui.EditorListButton;
import advanced.ui.FieldStepper;
import advanced.ui.JsonFile;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.math.FlxPoint;
import funkin.editors.SaveWarning;
import funkin.editors.ui.*;
import funkin.editors.ui.UIContextMenu.UIContextMenuOption;
import funkin.editors.ui.notifications.UIBaseNotification;
import funky.game.LevelSprite;
import funky.game.SpriteBuilder;
import haxe.io.Path;

/**
 * Editor de sprites (solo escritorio), con la interfaz de los editores de Codename.
 * Edita el `config.json` de cada carpeta de `sprites/`: tipo, escala y bilinear del sprite, y por animacion
 * el nombre, el tag del atlas, velocidad, escala, loop y pivote (`offset`). El atlas nunca se modifica y lo que
 * el editor no conoce de `config.json` (`index`, `num`...) se conserva tal cual.
 */
class SpriteEditorState extends UIState
{
	static inline var TOP:Int = 25;
	static inline var LEFT_W:Int = 230;
	static inline var RIGHT_W:Int = 300;
	static final TYPES:Array<String> = ["item", "character", "stage", "icon", "atlas"];

	var levelName:String;
	var levelDir:String;

	var uiCamera:FlxCamera;
	var topMenu:Array<UIContextMenuOption>;
	var topMenuSpr:UITopMenu;

	var sprites:Array<String> = [];
	var spriteIdx:Int = 0;
	var spriteList:UIButtonList<EditorListButton>;
	var animList:UIButtonList<EditorListButton>;

	var typeDrop:UIDropDown;
	var bilinearCheck:UICheckbox;
	var tagLabel:UIText;
	var nameBox:UITextBox;
	var tagBox:UITextBox;
	var speedStep:FieldStepper;
	var animScaleStep:FieldStepper;
	var pivotXStep:FieldStepper;
	var pivotYStep:FieldStepper;
	var loopCheck:UICheckbox;
	var spdFpsCheck:UICheckbox;
	var indicesBox:UITextBox;
	var animWidgets:Array<UISprite> = [];

	var cfgPath:String = "";
	var cfg:Dynamic = null;
	var entries:Array<Dynamic> = [];
	var animIdx:Int = 0;
	var atlas:Bool = false;

	var sprite:LevelSprite = null;
	var zoom:Float = 1;
	var dirty:Bool = false;
	var dragging:Bool = false;

	var infoText:UIText;
	var crossH:FlxSprite;
	var crossV:FlxSprite;
	var frameBars:Array<FlxSprite> = [];

	public function new(levelName:String)
	{
		super();
		this.levelName = levelName;
		this.levelDir = Path.join([funky.core.Paths.levelsRoot(), levelName]);
	}

	function ui<T:FlxBasic>(object:T):T
	{
		object.cameras = [uiCamera];
		add(object);
		return object;
	}

	function label(x:Float, y:Float, text:String):UIText
		return ui(new UIText(x, y, 0, text, 14));

	override public function create():Void
	{
		super.create();

		FlxG.camera.bgColor = 0xFF121212;
		uiCamera = new FlxCamera();
		uiCamera.bgColor = 0;
		FlxG.cameras.add(uiCamera, false);
		uiCameras = [uiCamera];
		for (camera in FlxG.cameras.list) camera.antialiasing = false;

		var canvasW = FlxG.width - LEFT_W - RIGHT_W;
		var grid = FlxGridOverlay.create(32, 32, canvasW, FlxG.height - TOP, true, 0xFF1C1C1C, 0xFF181818);
		grid.setPosition(LEFT_W, TOP);
		grid.scrollFactor.set();
		add(grid);
		add(new FlxSprite(LEFT_W + canvasW / 2, TOP).makeGraphic(1, FlxG.height - TOP, 0xFF2E3442));
		add(new FlxSprite(LEFT_W, centerY()).makeGraphic(canvasW, 1, 0xFF2E3442));
		for (i in 0...4)
		{
			var bar = new FlxSprite().makeGraphic(1, 1, 0x88FFFFFF);
			bar.visible = false;
			frameBars.push(bar);
			add(bar);
		}
		crossH = new FlxSprite().makeGraphic(26, 2, 0xFFFFD84A);
		crossV = new FlxSprite().makeGraphic(2, 26, 0xFFFFD84A);
		add(crossH);
		add(crossV);

		buildTopMenu();
		buildLeft();
		buildRight();

		infoText = ui(new UIText(LEFT_W + 12, FlxG.height - 44, canvasW - 24, "", 12));
		infoText.alpha = 0.8;

		sprites = SpriteBuilder.listSprites(levelDir);
		for (name in sprites) addSpriteButton(name);
		SaveWarning.saveFunc = save;
		if (sprites.length > 0) selectSprite(0);
		else notify("Este nivel no tiene sprites validos en sprites/.");
	}

	inline function centerX():Float
		return LEFT_W + (FlxG.width - LEFT_W - RIGHT_W) / 2;

	inline function centerY():Float
		return TOP + (FlxG.height - TOP) / 2 - 20;

	function notify(text:String):Void
		displayNotification(new UIBaseNotification(text, 3));

	// ───────────────────────── interfaz ─────────────────────────

	function buildTopMenu():Void
	{
		topMenu = [
			{
				label: "Archivo",
				childs: [
					{label: "Guardar", keybind: [CONTROL, S], onSelect: function(_) save()},
					{label: "Recargar desde el disco", keybind: [CONTROL, R], onSelect: function(_) reload()},
					null,
					{label: "Salir", keybind: [ESCAPE], onSelect: function(_) exit()}
				]
			},
			{
				label: "Editar",
				childs: [
					{label: "Nueva animacion", keybind: [INSERT], onSelect: function(_) newAnim()},
					{label: "Borrar animacion", keybind: [DELETE], onSelect: function(_) deleteAnim()},
					null,
					{label: "Reproducir de nuevo", keybind: [SPACE], onSelect: function(_) playCurrent()}
				]
			},
			{
				label: "Sprite",
				childs: [
					{label: "Anterior", keybind: [Q], onSelect: function(_) selectSprite(spriteIdx - 1)},
					{label: "Siguiente", keybind: [E], onSelect: function(_) selectSprite(spriteIdx + 1)}
				]
			},
			{
				label: "Animacion",
				childs: [
					{label: "Anterior", keybind: [A], onSelect: function(_) selectAnim(animIdx - 1)},
					{label: "Siguiente", keybind: [D], onSelect: function(_) selectAnim(animIdx + 1)}
				]
			},
			{
				label: "Ver",
				childs: [
					{label: "Acercar", onSelect: function(_) setZoom(zoom + 0.5)},
					{label: "Alejar", onSelect: function(_) setZoom(zoom - 0.5)},
					{label: "Zoom 100%", onSelect: function(_) setZoom(1)}
				]
			}
		];
		topMenuSpr = new UITopMenu(topMenu);
		topMenuSpr.cameras = [uiCamera];
		add(topMenuSpr);
	}

	function buildLeft():Void
	{
		var listH = Std.int((FlxG.height - TOP) * 0.5);
		spriteList = new UIButtonList<EditorListButton>(0, TOP, LEFT_W, listH, "Sprites", FlxPoint.get(LEFT_W - 30, 28), null, 4);
		spriteList.cameras = [uiCamera];
		spriteList.addButton.exists = false;
		spriteList.addIcon.exists = false;
		add(spriteList);

		animList = new UIButtonList<EditorListButton>(0, TOP + listH, LEFT_W, FlxG.height - TOP - listH, "Animaciones", FlxPoint.get(LEFT_W - 30, 28), null, 4);
		animList.cameras = [uiCamera];
		animList.addButton.callback = newAnim;
		add(animList);
	}

	function buildRight():Void
	{
		var x0 = FlxG.width - RIGHT_W;
		var y0 = TOP;
		ui(new UIWindow(x0, y0, RIGHT_W, 150, "Sprite"));
		label(x0 + 20, y0 + 38, "Tipo");
		typeDrop = ui(new UIDropDown(x0 + 20, y0 + 58, RIGHT_W - 40, 32, cast TYPES, 0));
		typeDrop.onChange = function(i:Int)
		{
			Reflect.setField(cfg, "type", TYPES[i]);
			touch();
		};
		bilinearCheck = ui(new UICheckbox(x0 + 20, y0 + 110, "Suavizado", false));
		bilinearCheck.onChecked = function(b:Bool)
		{
			Reflect.setField(cfg, "bilinear", b);
			touch();
		};

		var y1 = y0 + 160;
		ui(new UIWindow(x0, y1, RIGHT_W, 440, "Animacion"));
		label(x0 + 20, y1 + 38, "Nombre en el juego");
		nameBox = ui(new UITextBox(x0 + 20, y1 + 58, "", RIGHT_W - 40));
		nameBox.onChange = renameAnim;
		tagLabel = label(x0 + 20, y1 + 98, "Tag del sprite.json");
		tagBox = ui(new UITextBox(x0 + 20, y1 + 118, "", RIGHT_W - 40));
		tagBox.onChange = function(t:String)
		{
			setEntry("anim", StringTools.trim(t));
			notify("El tag nuevo se ve al guardar.");
		};
		label(x0 + 20, y1 + 164, "Velocidad");
		speedStep = ui(new FieldStepper(x0 + 20, y1 + 184, 24, 1, 2, 0.05, 240, 120));
		speedStep.onValue = function(v:Float) setEntry("spd", JsonFile.round(v));
		label(x0 + 156, y1 + 164, "Escala");
		animScaleStep = ui(new FieldStepper(x0 + 156, y1 + 184, 1, 0.05, 2, 0.05, 20, 120));
		animScaleStep.onValue = function(v:Float) setEntry("scale", JsonFile.round(v));
		label(x0 + 20, y1 + 230, "Pivote X");
		pivotXStep = ui(new FieldStepper(x0 + 20, y1 + 250, 0, 1, 1, null, null, 120));
		pivotXStep.onValue = function(v:Float) setPivot(v, null);
		label(x0 + 156, y1 + 230, "Pivote Y");
		pivotYStep = ui(new FieldStepper(x0 + 156, y1 + 250, 0, 1, 1, null, null, 120));
		pivotYStep.onValue = function(v:Float) setPivot(null, v);
		loopCheck = ui(new UICheckbox(x0 + 20, y1 + 300, "Loop", true));
		loopCheck.onChecked = function(b:Bool) setEntry("loop", b);
		var play = ui(new UIButton(x0 + 156, y1 + 296, "Reproducir", playCurrent, 120, 32));
		spdFpsCheck = ui(new UICheckbox(x0 + 20, y1 + 332, "Velocidad en FPS (apagado = frames por beat)", true));
		spdFpsCheck.onChecked = function(b:Bool)
		{
			setEntry("spd_fps", b);
			notify(b ? "spd = FPS crudos." : "spd = frames por beat (sigue al BPM). Se ve al guardar.");
		};
		label(x0 + 20, y1 + 372, "Indices del atlas (ej: 0,1,2,5-8; vacio = frameTag)");
		indicesBox = ui(new UITextBox(x0 + 20, y1 + 392, "", RIGHT_W - 40));
		indicesBox.onChange = function(t:String)
		{
			setEntry("indices", parseIndices(t));
			notify("Los indices se ven al guardar.");
		};

		animWidgets = [nameBox, tagBox, speedStep, animScaleStep, pivotXStep, pivotYStep, loopCheck, spdFpsCheck, indicesBox, play];
	}

	// ───────────────────────── listas ─────────────────────────

	function addSpriteButton(name:String):Void
	{
		var b:EditorListButton = null;
		b = new EditorListButton(0, 0, name, function() selectSprite(sprites.indexOf(b.item)), LEFT_W - 30, 28);
		b.item = name;
		spriteList.add(b);
	}

	function markSprites():Void
	{
		for (b in spriteList.buttons.members)
			if (b != null) b.mark(sprites[spriteIdx] == b.item);
	}

	function refreshAnimList():Void
	{
		for (b in animList.buttons.members.copy())
			if (b != null) animList.remove(b);
		for (e in entries)
		{
			var b:EditorListButton = null;
			b = new EditorListButton(0, 0, Std.string(Reflect.field(e, "name")), function() selectAnim(entries.indexOf(b.item)), LEFT_W - 30, 28);
			b.item = e;
			animList.add(b);
		}
		markAnims();
	}

	function markAnims():Void
	{
		for (b in animList.buttons.members)
			if (b != null) b.mark(entry() == b.item);
	}

	/** Si se arrastro un boton para cambiar el orden, el orden de los datos lo sigue. */
	function syncOrders():Void
	{
		var order = [for (b in spriteList.buttons.members) if (b != null) Std.string(b.item)];
		if (order.length == sprites.length)
		{
			var current = sprites[spriteIdx];
			for (i in 0...order.length) sprites[i] = order[i];
			spriteIdx = Std.int(Math.max(0, sprites.indexOf(current)));
		}

		var animOrder:Array<Dynamic> = [for (b in animList.buttons.members) if (b != null) b.item];
		if (animOrder.length != entries.length) return;
		var changed = false;
		for (i in 0...animOrder.length) if (animOrder[i] != entries[i]) changed = true;
		if (!changed) return;
		var selected = entry();
		for (i in 0...animOrder.length) entries[i] = animOrder[i];
		animIdx = Std.int(Math.max(0, entries.indexOf(selected)));
		touch();
	}

	// ───────────────────────── carga ─────────────────────────

	function selectSprite(index:Int):Void
	{
		if (sprites.length == 0) return;
		spriteIdx = (index + sprites.length) % sprites.length;
		markSprites();
		loadCurrent(0);
	}

	/** Lee `config.json` del sprite actual (o lo arma desde lo que ya resuelve el juego) y recarga la vista previa. */
	function loadCurrent(keepAnim:Int):Void
	{
		var name = sprites[spriteIdx];
		atlas = SpriteBuilder.isAtlas(levelDir, name);
		cfgPath = Path.join([SpriteBuilder.spriteDir(levelDir, name), "config.json"]);
		cfg = JsonFile.read(cfgPath);
		if (cfg == null || Std.isOfType(cfg, Array)) cfg = {};

		var data:Dynamic = Reflect.field(cfg, "data");
		if (Std.isOfType(data, Array) && (data : Array<Dynamic>).length > 0)
			entries = data;
		else
		{
			entries = [];
			var resolved = atlas ? SpriteBuilder.readAtlasConfig(levelDir, name) : SpriteBuilder.readConfig(levelDir, name);
			for (a in resolved.anims)
			{
				// los alias anim0..3 que el juego agrega a singLEFT.. no son entradas del config
				if (~/^anim[0-9]+$/.match(a.name) && Lambda.exists(resolved.anims, o -> SpriteBuilder.laneOfSing(o.name) == Std.parseInt(a.name.substr(4)))) continue;
				entries.push({index: a.index, anim: a.name, name: a.name, spd: JsonFile.round(a.spd), spd_fps: a.spdFps, indices: ([] : Array<Int>), loop: a.loop, offset: {x: a.offsetX, y: a.offsetY}, scale: a.scale});
			}
			if (Reflect.field(cfg, "type") == null) Reflect.setField(cfg, "type", resolved.type == "sprite" ? "item" : resolved.type);
			if (Reflect.field(cfg, "bilinear") == null) Reflect.setField(cfg, "bilinear", resolved.bilinear);
		}
		// Formatos viejos: `spd` multiplicador -> FPS + `spd_fps`; y sin escala global (cada animacion tiene la suya).
		for (e in entries) SpriteBuilder.migrateSpd(e);
		Reflect.deleteField(cfg, "scale");
		Reflect.setField(cfg, "data", entries);

		if (sprite != null)
		{
			remove(sprite, true);
			sprite.destroy();
			sprite = null;
		}
		sprite = SpriteBuilder.build(levelDir, name);
		sprite.scrollFactor.set();
		insert(members.indexOf(crossH), sprite);

		animIdx = Std.int(Math.max(0, Math.min(entries.length - 1, keepAnim)));
		syncSpriteWidgets();
		refreshAnimList();
		syncAnimWidgets();
		playCurrent();
	}

	function reload():Void
	{
		if (sprites.length == 0) return;
		dirty = false;
		SaveWarning.showWarning = false;
		loadCurrent(animIdx);
		notify("Recargado desde el disco.");
	}

	inline function entry():Dynamic
		return entries.length == 0 ? null : entries[animIdx];

	/** "0,1,2, 5-8" -> [0,1,2,5,6,7,8] (los rangos pueden ir al reves: "8-5"). Lo que no sea numero se ignora. */
	static function parseIndices(text:String):Array<Int>
	{
		var out:Array<Int> = [];
		for (token in ~/[,; ]+/g.split(text))
		{
			var t = StringTools.trim(token);
			if (t == "") continue;
			if (~/^[0-9]+-[0-9]+$/.match(t))
			{
				var parts = t.split("-");
				var a = Std.parseInt(parts[0]);
				var b = Std.parseInt(parts[1]);
				if (a <= b) for (i in a...b + 1) out.push(i);
				else { var i = a; while (i >= b) out.push(i--); }
			}
			else if (~/^[0-9]+$/.match(t))
				out.push(Std.parseInt(t));
		}
		return out;
	}

	// ───────────────────────── widgets <-> datos ─────────────────────────

	function syncSpriteWidgets():Void
	{
		var type = Std.string(Reflect.field(cfg, "type"));
		typeDrop.index = Std.int(Math.max(0, TYPES.indexOf(type)));
		typeDrop.label.text = TYPES[typeDrop.index];
		bilinearCheck.checked = Reflect.field(cfg, "bilinear") == true;
		tagLabel.text = atlas ? "Simbolo / label del atlas" : "Tag del sprite.json";
	}

	function syncAnimWidgets():Void
	{
		var e = entry();
		var has = e != null;
		for (w in animWidgets) w.selectable = has;
		if (!has)
		{
			nameBox.label.text = tagBox.label.text = "";
			return;
		}
		var name = Std.string(Reflect.field(e, "name"));
		nameBox.label.text = name;
		nameBox.position = name.length;
		var tag = Reflect.field(e, "anim") != null ? Std.string(Reflect.field(e, "anim")) : name;
		tagBox.label.text = tag;
		tagBox.position = tag.length;
		speedStep.value = JsonFile.num(Reflect.field(e, "spd"), 24);
		spdFpsCheck.checked = Reflect.field(e, "spd_fps") != false;
		var idx:Dynamic = Reflect.field(e, "indices");
		var idxText = Std.isOfType(idx, Array) ? (idx : Array<Dynamic>).join(",") : "";
		indicesBox.label.text = idxText;
		indicesBox.position = idxText.length;
		animScaleStep.value = JsonFile.num(Reflect.field(e, "scale"), 1);
		var offset = Reflect.field(e, "offset");
		pivotXStep.value = JsonFile.num(Reflect.field(offset, "x"), 0);
		pivotYStep.value = JsonFile.num(Reflect.field(offset, "y"), 0);
		loopCheck.checked = Reflect.field(e, "loop") != false;
	}

	function touch():Void
	{
		dirty = true;
		SaveWarning.showWarning = true;
		applyLive();
	}

	function setEntry(field:String, value:Dynamic):Void
	{
		var e = entry();
		if (e == null) return;
		Reflect.setField(e, field, value);
		touch();
	}

	function setPivot(x:Null<Float>, y:Null<Float>):Void
	{
		var e = entry();
		if (e == null) return;
		var offset = JsonFile.obj(e, "offset");
		if (x != null) Reflect.setField(offset, "x", JsonFile.round(x));
		if (y != null) Reflect.setField(offset, "y", JsonFile.round(y));
		touch();
	}

	// ───────────────────────── animaciones ─────────────────────────

	function newAnim():Void
	{
		var n = entries.length;
		var name = "anim" + n;
		while (Lambda.exists(entries, e -> Reflect.field(e, "name") == name)) name = "anim" + (++n);
		entries.push({index: entries.length, anim: name, name: name, spd: 24, spd_fps: true, indices: ([] : Array<Int>), loop: true, offset: {x: 0, y: 0}, scale: 1});
		Reflect.setField(cfg, "data", entries);
		animIdx = entries.length - 1;
		touch();
		refreshAnimList();
		syncAnimWidgets();
		playCurrent();
	}

	function renameAnim(text:String):Void
	{
		var e = entry();
		if (e == null) return;
		var name = StringTools.trim(text);
		var clash = Lambda.exists(entries, o -> o != e && Reflect.field(o, "name") == name);
		if (name == "" || clash)
		{
			notify(name == "" ? "El nombre no puede quedar vacio." : "Ya existe una animacion llamada " + name + ".");
			nameBox.label.text = Std.string(Reflect.field(e, "name"));
			return;
		}
		// `anim` es el tag del atlas: solo cambia `name` (el nombre que usa el juego)
		if (Reflect.field(e, "anim") == null) Reflect.setField(e, "anim", Reflect.field(e, "name"));
		Reflect.setField(e, "name", name);
		touch();
		refreshAnimList();
	}

	function deleteAnim():Void
	{
		if (entries.length == 0) return;
		entries.splice(animIdx, 1);
		animIdx = Std.int(Math.max(0, Math.min(entries.length - 1, animIdx)));
		touch();
		refreshAnimList();
		syncAnimWidgets();
		playCurrent();
	}

	function selectAnim(index:Int):Void
	{
		if (entries.length == 0) return;
		animIdx = (index + entries.length) % entries.length;
		markAnims();
		syncAnimWidgets();
		playCurrent();
	}

	function playCurrent():Void
	{
		var e = entry();
		if (sprite == null || !sprite.loaded || e == null) return;
		sprite.playAnim(Std.string(Reflect.field(e, "name")), true);
		applyLive();
	}

	/** Velocidad y loop se aplican en vivo (los atlas de Animate lo toman al volver a reproducir). */
	function applyLive():Void
	{
		var e = entry();
		if (sprite == null || !sprite.loaded || e == null) return;
		sprite.antialiasing = Reflect.field(cfg, "bilinear") == true;
		var cur = sprite.animation.curAnim;
		if (cur != null && !atlas)
		{
			var spd = Math.max(0.05, JsonFile.num(Reflect.field(e, "spd"), 24));
			cur.frameRate = Reflect.field(e, "spd_fps") == false ? spd * funky.core.Conductor.bpm / 60 : spd;
			cur.looped = Reflect.field(e, "loop") != false;
		}
		place();
	}

	function setZoom(value:Float):Void
	{
		zoom = Math.max(0.25, Math.min(16, value));
		place();
	}

	/** Centra el frame en el lienzo y mueve la cruz al pivote de la animacion. */
	function place():Void
	{
		var e = entry();
		if (sprite == null || !sprite.loaded || e == null)
		{
			crossH.visible = crossV.visible = false;
			for (b in frameBars) b.visible = false;
			return;
		}
		var s = zoom * Math.max(0.01, JsonFile.num(Reflect.field(e, "scale"), 1));
		sprite.scale.set(s, s);
		sprite.updateHitbox();
		sprite.setPosition(centerX() - sprite.width / 2, centerY() - sprite.height / 2);

		var rects = [[sprite.x, sprite.y, sprite.width, 1.0], [sprite.x, sprite.y + sprite.height - 1, sprite.width, 1.0], [sprite.x, sprite.y, 1.0, sprite.height], [sprite.x + sprite.width - 1, sprite.y, 1.0, sprite.height]];
		for (i in 0...4)
		{
			frameBars[i].visible = true;
			frameBars[i].scale.set(Math.max(1, rects[i][2]), Math.max(1, rects[i][3]));
			frameBars[i].updateHitbox();
			frameBars[i].setPosition(rects[i][0], rects[i][1]);
		}

		var offset = Reflect.field(e, "offset");
		var px = sprite.x + JsonFile.num(Reflect.field(offset, "x"), 0) * s;
		var py = sprite.y + JsonFile.num(Reflect.field(offset, "y"), 0) * s;
		crossH.visible = crossV.visible = true;
		crossH.setPosition(px - 13, py - 1);
		crossV.setPosition(px - 1, py - 13);
	}

	// ───────────────────────── guardar / salir ─────────────────────────

	function save():Void
	{
		if (sprites.length == 0) return;
		Reflect.setField(cfg, "data", entries);
		if (JsonFile.write(cfgPath, cfg))
		{
			dirty = false;
			SaveWarning.showWarning = false;
			UIState.playEditorSound(funkin.backend.system.Flags.DEFAULT_EDITOR_SAVE_SOUND);
			notify("Guardado: " + sprites[spriteIdx] + "/config.json");
			loadCurrent(animIdx);
		}
		else
			notify("No se pudo escribir " + cfgPath);
	}

	function exit():Void
	{
		if (!dirty)
		{
			FlxG.switchState(() -> new AdvancedToolsState(levelName));
			return;
		}
		openSubState(new UIWarningSubstate("Cambios sin guardar", "Hay cambios en el config.json de este sprite que todavia no guardaste.", [
			{label: "Cancelar", color: 0x969533, onClick: function(_) {}},
			{label: "Salir sin guardar", color: 0x969533, onClick: function(_) {
				SaveWarning.showWarning = false;
				FlxG.switchState(() -> new AdvancedToolsState(levelName));
			}},
			{label: "Guardar y salir", color: 0x969533, onClick: function(_) {
				save();
				FlxG.switchState(() -> new AdvancedToolsState(levelName));
			}}
		], false));
	}

	// ───────────────────────── frame ─────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		syncOrders();

		var typing = currentFocus != null;
		if (FlxG.keys.justPressed.ANY && !typing && curContextMenu == null && !topMenuSpr.anyMenuOpened) UIUtil.processShortcuts(topMenu);

		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		var inCanvas = mx >= LEFT_W && mx <= FlxG.width - RIGHT_W && my >= TOP && !topMenuSpr.anyMenuOpened && curContextMenu == null;

		if (inCanvas && FlxG.mouse.wheel != 0) setZoom(zoom + FlxG.mouse.wheel * 0.25 * Math.max(1, zoom * 0.5));
		if (FlxG.mouse.justPressed && inCanvas) dragging = true;
		if (!FlxG.mouse.pressed) dragging = false;
		if (dragging && entry() != null && sprite != null && sprite.loaded)
		{
			var s = Math.max(0.0001, Math.abs(sprite.scale.x));
			setPivot(Math.round((mx - sprite.x) / s * 10) / 10, Math.round((my - sprite.y) / s * 10) / 10);
			syncPivotSteppers();
		}

		if (!typing && !topMenuSpr.anyMenuOpened && entry() != null)
		{
			var step:Float = FlxG.keys.pressed.SHIFT ? 10 : 1;
			var dx = (FlxG.keys.justPressed.RIGHT ? 1 : 0) - (FlxG.keys.justPressed.LEFT ? 1 : 0);
			var dy = (FlxG.keys.justPressed.DOWN ? 1 : 0) - (FlxG.keys.justPressed.UP ? 1 : 0);
			if (dx != 0 || dy != 0)
			{
				var offset = JsonFile.obj(entry(), "offset");
				setPivot(JsonFile.num(Reflect.field(offset, "x"), 0) + dx * step, JsonFile.num(Reflect.field(offset, "y"), 0) + dy * step);
				syncPivotSteppers();
			}
		}

		if (sprite != null && sprite.loaded) place();
		refreshInfo();
	}

	function syncPivotSteppers():Void
	{
		var offset = Reflect.field(entry(), "offset");
		pivotXStep.value = JsonFile.num(Reflect.field(offset, "x"), 0);
		pivotYStep.value = JsonFile.num(Reflect.field(offset, "y"), 0);
	}

	function refreshInfo():Void
	{
		var frame = sprite != null && sprite.loaded ? Std.int(sprite.frameWidth) + " x " + Std.int(sprite.frameHeight) : "-";
		infoText.text = "Zoom " + Std.int(zoom * 100) + "%   Frame " + frame + (dirty ? "   * sin guardar" : "") + (sprite != null && !sprite.loaded ? "   (el sprite no cargo: revisa sprite.png y sprite.json)" : "")
			+ "\nArrastra en el lienzo o usa las flechas (SHIFT x10) para mover el pivote. Rueda: zoom. Q/E sprite, A/D animacion.";
	}

	override public function destroy():Void
	{
		SaveWarning.saveFunc = null;
		sprite = null;
		super.destroy();
	}
}
