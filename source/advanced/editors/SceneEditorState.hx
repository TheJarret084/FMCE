package advanced.editors;

import advanced.AdvancedToolsState;
import advanced.ui.ColorField;
import advanced.ui.EditorListButton;
import advanced.ui.FieldStepper;
import advanced.ui.JsonFile;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import funkin.editors.SaveWarning;
import funkin.editors.ui.*;
import funkin.editors.ui.UIContextMenu.UIContextMenuOption;
import funkin.editors.ui.notifications.UIBaseNotification;
import funky.game.LevelSprite;
import funky.game.SpriteBuilder;
import funky.game.Stage;
import haxe.Json;
import haxe.ds.ObjectMap;
import haxe.io.Path;

/**
 * Editor de escena (solo escritorio), con la interfaz de los editores de Codename.
 * Edita el `scene.json` del nivel sobre una vista que usa las mismas cuentas que el `Stage` del juego
 * (camara, parallax, objetos `fixed` pegados a la pantalla).
 *  - objetos: sprite, posicion, escala (negativa = espejo), parallax, opacidad, color, strumline, fixed, visible y orden de capas
 *    (arrastra los botones de la lista);
 *  - camaras: posicion y zoom de cada punto de camara.
 * Se edita la primera entrada de `transform` de cada objeto; las demas, `icons` y todo lo que el editor no conoce se conserva.
 */
class SceneEditorState extends UIState
{
	static inline var TOP:Int = 25;
	static inline var LEFT_W:Int = 230;
	static inline var RIGHT_W:Int = 300;

	var levelName:String;
	var levelDir:String;
	var scenePath:String;
	var scene:Dynamic;
	var objects:Array<Dynamic> = [];

	var uiCamera:FlxCamera;
	var camScene:FlxCamera;
	var viewX:Int;
	var viewY:Int;
	var viewW:Int;
	var viewH:Int;
	var layer:FlxGroup;
	var views:Array<FlxSprite> = [];
	var selBars:Array<FlxSprite> = [];

	var topMenu:Array<UIContextMenuOption>;
	var topMenuSpr:UITopMenu;
	var objectList:UIButtonList<EditorListButton>;
	var spriteNames:Array<String> = [];

	var spriteDrop:UIDropDown;
	var posX:FieldStepper;
	var posY:FieldStepper;
	var scaleX:FieldStepper;
	var scaleY:FieldStepper;
	var scrollX:FieldStepper;
	var scrollY:FieldStepper;
	var opacityStep:FieldStepper;
	var strumStep:FieldStepper;
	var fixedCheck:UICheckbox;
	var visibleCheck:UICheckbox;
	var colorWheel:ColorField;
	var objWidgets:Array<UISprite> = [];
	var lastWheelColor:Int = 0xFFFFFF;

	var camDrop:UIDropDown;
	var camX:FieldStepper;
	var camY:FieldStepper;
	var camZoom:FieldStepper;

	var infoText:UIText;
	var sel:Int = -1;
	var camIdx:Int = 0;
	var gameView:Bool = false;
	var dirty:Bool = false;
	var dragging:Bool = false;
	var lastMX:Float = 0;
	var lastMY:Float = 0;

	public function new(levelName:String)
	{
		super();
		this.levelName = levelName;
		this.levelDir = Path.join([funky.core.Paths.levelsRoot(), levelName]);
		this.scenePath = Path.join([levelDir, "scene.json"]);
	}

	function ui<T:FlxBasic>(object:T):T
	{
		object.cameras = [uiCamera];
		add(object);
		return object;
	}

	function label(x:Float, y:Float, text:String):UIText
		return ui(new UIText(x, y, 0, text, 14));

	function notify(text:String):Void
		displayNotification(new UIBaseNotification(text, 3));

	override public function create():Void
	{
		super.create();

		FlxG.camera.bgColor = 0xFF121212;
		viewW = FlxG.width - LEFT_W - RIGHT_W - 24;
		viewH = Std.int(viewW * FlxG.height / FlxG.width);
		viewX = LEFT_W + 12;
		viewY = TOP + Std.int((FlxG.height - TOP - viewH) / 2) - 18;

		camScene = new FlxCamera(viewX, viewY, viewW, viewH);
		camScene.bgColor = 0xFF000000;
		FlxG.cameras.add(camScene, false);
		uiCamera = new FlxCamera();
		uiCamera.bgColor = 0;
		FlxG.cameras.add(uiCamera, false);
		uiCameras = [uiCamera];
		for (camera in FlxG.cameras.list) camera.antialiasing = false;

		scene = JsonFile.read(scenePath);
		if (scene == null || Std.isOfType(scene, Array)) scene = {objects: [], landscape: true, cameras: [{position: {x: 0, y: 0}, scale: 1}], icons: []};
		if (!Std.isOfType(scene.objects, Array)) scene.objects = [];
		objects = scene.objects;

		layer = new FlxGroup();
		add(layer);
		for (i in 0...4)
		{
			var bar = new FlxSprite().makeGraphic(1, 1, 0xFFFFD84A);
			bar.cameras = [camScene];
			bar.scrollFactor.set();
			bar.visible = false;
			selBars.push(bar);
			add(bar);
		}
		// marco de la vista
		for (r in [[viewX - 1, viewY - 1, viewW + 2, 1], [viewX - 1, viewY + viewH, viewW + 2, 1], [viewX - 1, viewY - 1, 1, viewH + 2], [viewX + viewW, viewY - 1, 1, viewH + 2]])
			ui(new FlxSprite(r[0], r[1]).makeGraphic(Std.int(r[2]), Std.int(r[3]), 0xFF3A4152));

		buildTopMenu();
		buildLeft();
		buildRight();

		infoText = ui(new UIText(viewX, viewY + viewH + 10, viewW, "", 12));
		infoText.alpha = 0.8;

		spriteNames = SpriteBuilder.listSprites(levelDir);
		spriteDrop.items = [for (i => name in spriteNames) {label: name, value: i}];
		spriteDrop.options = spriteNames.copy();

		SaveWarning.saveFunc = save;
		rebuild();
		select(objects.length > 0 ? 0 : -1);
	}

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
				label: "Objeto",
				childs: [
					{label: "Agregar", keybind: [INSERT], onSelect: function(_) addObject()},
					{label: "Duplicar", keybind: [CONTROL, D], onSelect: function(_) if (sel >= 0) duplicate(sel)},
					{label: "Borrar", keybind: [DELETE], onSelect: function(_) if (sel >= 0) deleteObject(sel)},
					null,
					{label: "Subir capa", keybind: [CONTROL, PAGEUP], onSelect: function(_) if (sel >= 0) swap(sel, sel + 1)},
					{label: "Bajar capa", keybind: [CONTROL, PAGEDOWN], onSelect: function(_) if (sel >= 0) swap(sel, sel - 1)},
					null,
					{label: "Espejo horizontal", keybind: [M], onSelect: function(_) mirror("x")},
					{label: "Espejo vertical", keybind: [SHIFT, M], onSelect: function(_) mirror("y")},
					{label: "Cambiar fixed", keybind: [F], onSelect: function(_) if (sel >= 0) setFixed(sel, Reflect.field(objects[sel], "fixed") != true)},
					{label: "Cambiar visible", keybind: [V], onSelect: function(_) if (sel >= 0) setVisible(sel, Reflect.field(objects[sel], "visible") == false)}
				]
			},
			{
				label: "Seleccion",
				childs: [
					{label: "Objeto siguiente", keybind: [PAGEDOWN], onSelect: function(_) select(objects.length == 0 ? -1 : (sel + 1) % objects.length)},
					{label: "Objeto anterior", keybind: [PAGEUP], onSelect: function(_) select(objects.length == 0 ? -1 : (sel - 1 + objects.length) % objects.length)},
					{label: "Sprite siguiente", keybind: [E], onSelect: function(_) cycleSprite(1)},
					{label: "Sprite anterior", keybind: [Q], onSelect: function(_) cycleSprite(-1)}
				]
			},
			{
				label: "Ver",
				childs: [
					{label: "Camara siguiente", keybind: [C], onSelect: function(_) setCamera((camIdx + 1) % camCount())},
					{label: "Ver como en el juego", onSelect: function(_) gameView = !gameView}
				]
			}
		];
		topMenuSpr = new UITopMenu(topMenu);
		topMenuSpr.cameras = [uiCamera];
		add(topMenuSpr);
	}

	function buildLeft():Void
	{
		objectList = new UIButtonList<EditorListButton>(0, TOP, LEFT_W, FlxG.height - TOP, "Objetos (la lista es el orden de capas)", FlxPoint.get(LEFT_W - 30, 28), null, 4);
		objectList.cameras = [uiCamera];
		objectList.addButton.callback = addObject;
		add(objectList);
	}

	function buildRight():Void
	{
		var x0 = FlxG.width - RIGHT_W;
		var y0 = TOP;
		ui(new UIWindow(x0, y0, RIGHT_W, 440, "Objeto"));

		label(x0 + 20, y0 + 36, "Sprite");
		spriteDrop = ui(new UIDropDown(x0 + 20, y0 + 54, RIGHT_W - 40, 32, [""], 0));
		spriteDrop.onChange = function(i:Int) if (sel >= 0 && i >= 0 && i < spriteNames.length) setSprite(sel, spriteNames[i]);

		label(x0 + 20, y0 + 92, "Posicion X");
		posX = ui(new FieldStepper(x0 + 20, y0 + 110, 0, 1, 3, null, null, 120));
		posX.onValue = function(v:Float) setObjField("position", "x", v);
		label(x0 + 156, y0 + 92, "Posicion Y");
		posY = ui(new FieldStepper(x0 + 156, y0 + 110, 0, 1, 3, null, null, 120));
		posY.onValue = function(v:Float) setObjField("position", "y", v);

		label(x0 + 20, y0 + 148, "Escala X");
		scaleX = ui(new FieldStepper(x0 + 20, y0 + 166, 1, 0.05, 3, null, null, 120));
		scaleX.onValue = function(v:Float) setObjField("scale", "x", v);
		label(x0 + 156, y0 + 148, "Escala Y");
		scaleY = ui(new FieldStepper(x0 + 156, y0 + 166, 1, 0.05, 3, null, null, 120));
		scaleY.onValue = function(v:Float) setObjField("scale", "y", v);

		label(x0 + 20, y0 + 204, "Parallax X");
		scrollX = ui(new FieldStepper(x0 + 20, y0 + 222, 1, 0.05, 3, null, null, 120));
		scrollX.onValue = function(v:Float) setObjField("scrollFactor", "x", v);
		label(x0 + 156, y0 + 204, "Parallax Y");
		scrollY = ui(new FieldStepper(x0 + 156, y0 + 222, 1, 0.05, 3, null, null, 120));
		scrollY.onValue = function(v:Float) setObjField("scrollFactor", "y", v);

		label(x0 + 20, y0 + 260, "Opacidad");
		opacityStep = ui(new FieldStepper(x0 + 20, y0 + 278, 1, 0.1, 2, 0, 1, 120));
		opacityStep.onValue = function(v:Float) setTopField("opacity", JsonFile.round(v));
		label(x0 + 156, y0 + 260, "Strumline (-1 = ninguna)");
		strumStep = ui(new FieldStepper(x0 + 156, y0 + 278, -1, 1, 0, -1, 9, 120));
		strumStep.onValue = function(v:Float) setTopField("strumLine", Std.int(v));

		fixedCheck = ui(new UICheckbox(x0 + 20, y0 + 322, "Fixed (pegado a la pantalla)", false));
		fixedCheck.onChecked = function(b:Bool) if (sel >= 0) setFixed(sel, b);
		visibleCheck = ui(new UICheckbox(x0 + 20, y0 + 348, "Visible", true));
		visibleCheck.onChecked = function(b:Bool) if (sel >= 0) setVisible(sel, b);

		label(x0 + 20, y0 + 380, "Color");
		colorWheel = ui(new ColorField(x0 + 80, y0 + 372, 0xFFFFFFFF));
		var dup = ui(new UIButton(x0 + 20, y0 + 402, "Duplicar", function() if (sel >= 0) duplicate(sel), 120, 28));
		var del = ui(new UIButton(x0 + 156, y0 + 402, "Borrar", function() if (sel >= 0) deleteObject(sel), 120, 28));
		del.color = 0xFFFF8080;

		objWidgets = [spriteDrop, posX, posY, scaleX, scaleY, scrollX, scrollY, opacityStep, strumStep, fixedCheck, visibleCheck, colorWheel, dup, del];

		var y1 = y0 + 450;
		ui(new UIWindow(x0, y1, RIGHT_W, FlxG.height - y1 - 6, "Camara"));
		label(x0 + 20, y1 + 36, "Punto de camara (la vista usa el elegido)");
		camDrop = ui(new UIDropDown(x0 + 20, y1 + 54, RIGHT_W - 40, 32, [""], 0));
		camDrop.onChange = function(i:Int) setCamera(i);
		label(x0 + 20, y1 + 92, "X");
		camX = ui(new FieldStepper(x0 + 20, y1 + 110, 0, 10, 2, null, null, 120));
		camX.onValue = function(v:Float) setCameraField("x", v);
		label(x0 + 156, y1 + 92, "Y");
		camY = ui(new FieldStepper(x0 + 156, y1 + 110, 0, 10, 2, null, null, 120));
		camY.onValue = function(v:Float) setCameraField("y", v);
		label(x0 + 20, y1 + 148, "Zoom");
		camZoom = ui(new FieldStepper(x0 + 20, y1 + 166, 1, 0.05, 3, 0.05, 20, 120));
		camZoom.onValue = function(v:Float) setCameraField("scale", v);
		refreshCameraWidgets();
	}

	// ───────────────────────── datos ─────────────────────────

	/** Primera entrada de `transform` (se crea si falta, migrando el formato viejo de x/y sueltos). */
	function tr(o:Dynamic):Dynamic
	{
		var list:Dynamic = Reflect.field(o, "transform");
		if (Std.isOfType(list, Array) && (list : Array<Dynamic>).length > 0) return (list : Array<Dynamic>)[0];
		var legacyScale = JsonFile.num(Reflect.field(o, "scale"), 1);
		var t:Dynamic = {
			position: {x: JsonFile.num(Reflect.field(o, "x"), 0), y: JsonFile.num(Reflect.field(o, "y"), 0)},
			scrollFactor: {x: 1, y: 1},
			scale: {x: legacyScale, y: legacyScale}
		};
		Reflect.setField(o, "transform", [t]);
		for (f in ["x", "y", "scale"]) Reflect.deleteField(o, f);
		return t;
	}

	inline function pos(o:Dynamic):Dynamic return JsonFile.obj(tr(o), "position");
	inline function scl(o:Dynamic):Dynamic return JsonFile.obj(tr(o), "scale");
	inline function scroll(o:Dynamic):Dynamic return JsonFile.obj(tr(o), "scrollFactor");

	function camPoint(index:Int):{x:Float, y:Float, scale:Float}
	{
		var cams:Dynamic = scene.cameras;
		if (!Std.isOfType(cams, Array) || (cams : Array<Dynamic>).length == 0) return {x: 0, y: 0, scale: 1};
		var c = (cams : Array<Dynamic>)[Std.int(Math.min(index, (cams : Array<Dynamic>).length - 1))];
		var p = Reflect.field(c, "position");
		if (p == null) p = c;
		return {x: JsonFile.num(Reflect.field(p, "x"), 0), y: JsonFile.num(Reflect.field(p, "y"), 0), scale: JsonFile.num(Reflect.field(c, "scale"), 1)};
	}

	function camCount():Int
		return Std.isOfType(scene.cameras, Array) ? Std.int(Math.max(1, (scene.cameras : Array<Dynamic>).length)) : 1;

	/** La camara `camIdx` como objeto editable (se crea si la escena no tenia camaras). */
	function camObject():Dynamic
	{
		if (!Std.isOfType(scene.cameras, Array) || (scene.cameras : Array<Dynamic>).length == 0)
			scene.cameras = [{position: {x: 0, y: 0}, scale: 1}];
		var c = (scene.cameras : Array<Dynamic>)[Std.int(Math.min(camIdx, (scene.cameras : Array<Dynamic>).length - 1))];
		if (Reflect.field(c, "position") == null)
			Reflect.setField(c, "position", {x: JsonFile.num(Reflect.field(c, "x"), 0), y: JsonFile.num(Reflect.field(c, "y"), 0)});
		return c;
	}

	function touch():Void
	{
		dirty = true;
		SaveWarning.showWarning = true;
	}

	function setCamera(index:Int):Void
	{
		camIdx = Std.int(Math.max(0, Math.min(camCount() - 1, index)));
		refreshCameraWidgets();
	}

	function setCameraField(field:String, value:Float):Void
	{
		var c = camObject();
		if (field == "scale") Reflect.setField(c, "scale", JsonFile.round(Math.max(0.05, value)));
		else Reflect.setField(Reflect.field(c, "position"), field, JsonFile.round(value));
		touch();
	}

	function refreshCameraWidgets():Void
	{
		var names = [for (i in 0...camCount()) "Camara " + (i + 1) + (i == 0 ? " (origen del mundo)" : "")];
		camDrop.items = [for (i => n in names) {label: n, value: i}];
		camDrop.options = names;
		camDrop.index = camIdx;
		camDrop.label.text = names[camIdx];
		var c = camPoint(camIdx);
		camX.value = c.x;
		camY.value = c.y;
		camZoom.value = c.scale;
	}

	// ───────────────────────── vista ─────────────────────────

	function makeView(i:Int):FlxSprite
	{
		var name = Std.string(Reflect.field(objects[i], "spr"));
		var view:FlxSprite = null;
		if (name != "null" && name != "" && SpriteBuilder.videoCount(levelDir, name) == 0)
		{
			var s = SpriteBuilder.build(levelDir, name);
			if (s.loaded) view = s;
		}
		// sprite que falta (o video): una caja gris para poder moverlo igual
		if (view == null) view = new FlxSprite().makeGraphic(80, 80, 0xFF556070);
		view.cameras = [camScene];
		view.scrollFactor.set();
		return view;
	}

	function rebuild():Void
	{
		for (v in views)
		{
			layer.remove(v, true);
			v.destroy();
		}
		views = [];
		for (i in 0...objects.length)
		{
			var v = makeView(i);
			views.push(v);
			layer.add(v);
		}
		refreshList();
	}

	function replaceView(i:Int):Void
	{
		var index = layer.members.indexOf(views[i]);
		layer.remove(views[i], true);
		views[i].destroy();
		views[i] = makeView(i);
		layer.insert(index < 0 ? layer.length : index, views[i]);
	}

	function listLabel(i:Int):String
	{
		var o = objects[i];
		return i + "  " + Std.string(Reflect.field(o, "spr")) + (Reflect.field(o, "fixed") == true ? "  [F]" : "") + (Reflect.field(o, "visible") == false ? "  (oculto)" : "")
			+ (JsonFile.num(Reflect.field(o, "strumLine"), -1) >= 0 ? "  s" + Std.int(JsonFile.num(Reflect.field(o, "strumLine"), -1)) : "");
	}

	function refreshList():Void
	{
		for (b in objectList.buttons.members.copy())
			if (b != null) objectList.remove(b);
		for (i in 0...objects.length)
		{
			var b:EditorListButton = null;
			b = new EditorListButton(0, 0, listLabel(i), function() select(objects.indexOf(b.item)), LEFT_W - 30, 28);
			b.item = objects[i];
			objectList.add(b);
		}
		markList();
	}

	function markList():Void
	{
		for (b in objectList.buttons.members)
			if (b != null) b.mark(sel >= 0 && sel < objects.length && objects[sel] == b.item);
	}

	/** Si se arrastro un boton de la lista, el orden de capas (objetos y vistas) lo sigue. */
	function syncOrder():Void
	{
		var order:Array<Dynamic> = [for (b in objectList.buttons.members) if (b != null) b.item];
		if (order.length != objects.length) return;
		var changed = false;
		for (i in 0...order.length) if (order[i] != objects[i]) changed = true;
		if (!changed) return;

		var viewOf = new ObjectMap<Dynamic, FlxSprite>();
		for (i in 0...objects.length) viewOf.set(objects[i], views[i]);
		var current = sel >= 0 ? objects[sel] : null;
		for (i in 0...order.length) objects[i] = order[i];
		views = [for (o in objects) viewOf.get(o)];
		for (v in views) layer.remove(v, true);
		for (v in views) layer.add(v);
		sel = current == null ? -1 : objects.indexOf(current);
		touch();
	}

	/** Estado en pantalla de un objeto (lo mismo que calcula `Stage`, sobre esta vista). */
	function compute(i:Int):{px:Float, py:Float, tx:Float, ty:Float, anim:Float, ppu:Float}
	{
		var o = objects[i];
		var p = pos(o);
		var sc = scl(o);
		var sf = scroll(o);
		var x = JsonFile.num(Reflect.field(p, "x"), 0);
		var y = JsonFile.num(Reflect.field(p, "y"), 0);
		var sx = JsonFile.num(Reflect.field(sc, "x"), 1);
		var sy = JsonFile.num(Reflect.field(sc, "y"), sx);

		var animScale = 1.0;
		var view = views[i];
		if (Std.isOfType(view, LevelSprite))
		{
			var a = (cast view : LevelSprite).currentAnim();
			if (a != null) animScale = a.scale;
		}

		if (Reflect.field(o, "fixed") == true)
		{
			var unit = animScale * viewW / Stage.HUD_REF_WIDTH * Stage.defaultHudZoom;
			return {px: x * viewW, py: y * viewH, tx: sx * unit, ty: sy * unit, anim: animScale, ppu: viewW};
		}
		var cam = camPoint(camIdx);
		var cam0 = camPoint(0);
		var ppu = Stage.CAM_PRESET * viewW / (Stage.VIEW_WORLD_WIDTH * Math.max(0.001, cam.scale));
		var fx = JsonFile.num(Reflect.field(sf, "x"), 1);
		var fy = JsonFile.num(Reflect.field(sf, "y"), 1);
		return {
			px: (x - cam0.x - (cam.x - cam0.x) * fx) * ppu + viewW / 2,
			py: (y - cam0.y - (cam.y - cam0.y) * fy) * ppu + viewH / 2,
			tx: sx * animScale * ppu,
			ty: sy * animScale * ppu,
			anim: animScale,
			ppu: ppu
		};
	}

	function place(i:Int):Void
	{
		var o = objects[i];
		var v = views[i];
		var st = compute(i);
		v.scale.set(st.tx, st.ty);
		v.updateHitbox();
		if (Std.isOfType(v, LevelSprite)) (cast v : LevelSprite).placePivot(st.px, st.py);
		else v.setPosition(st.px - v.width / 2, st.py - v.height / 2);

		// en el editor lo oculto o transparente se ve tenue para poder encontrarlo (Ver > Ver como en el juego lo desactiva)
		var opacity = JsonFile.num(Reflect.field(o, "opacity"), 1);
		var shown = Reflect.field(o, "visible") != false;
		var floor = gameView ? 0 : 0.12;
		v.visible = shown || !gameView;
		v.alpha = Math.max(floor, shown ? Math.min(1, opacity) : 0);
		var color = Reflect.field(o, "color");
		if (color != null)
			v.color = FlxColor.fromRGB(Std.int(JsonFile.num(Reflect.field(color, "r"), 255)), Std.int(JsonFile.num(Reflect.field(color, "g"), 255)), Std.int(JsonFile.num(Reflect.field(color, "b"), 255)));
	}

	function drawSelection():Void
	{
		for (b in selBars) b.visible = sel >= 0 && sel < views.length;
		if (sel < 0 || sel >= views.length) return;
		var v = views[sel];
		var rects = [[v.x, v.y, v.width, 2.0], [v.x, v.y + v.height - 2, v.width, 2.0], [v.x, v.y, 2.0, v.height], [v.x + v.width - 2, v.y, 2.0, v.height]];
		for (i in 0...4)
		{
			selBars[i].scale.set(Math.max(1, rects[i][2]), Math.max(1, rects[i][3]));
			selBars[i].updateHitbox();
			selBars[i].setPosition(rects[i][0], rects[i][1]);
		}
	}

	// ───────────────────────── seleccion y widgets ─────────────────────────

	function select(index:Int):Void
	{
		sel = objects.length == 0 ? -1 : Std.int(Math.max(-1, Math.min(objects.length - 1, index)));
		markList();
		syncObjectWidgets();
	}

	function syncObjectWidgets():Void
	{
		var has = sel >= 0 && sel < objects.length;
		for (w in objWidgets) w.selectable = has;
		if (!has) return;
		var o = objects[sel];
		var spr = Std.string(Reflect.field(o, "spr"));
		var at = spriteNames.indexOf(spr);
		spriteDrop.index = Std.int(Math.max(0, at));
		spriteDrop.label.text = spr;
		var p = pos(o);
		var sc = scl(o);
		var sf = scroll(o);
		posX.value = JsonFile.num(Reflect.field(p, "x"), 0);
		posY.value = JsonFile.num(Reflect.field(p, "y"), 0);
		scaleX.value = JsonFile.num(Reflect.field(sc, "x"), 1);
		scaleY.value = JsonFile.num(Reflect.field(sc, "y"), 1);
		scrollX.value = JsonFile.num(Reflect.field(sf, "x"), 1);
		scrollY.value = JsonFile.num(Reflect.field(sf, "y"), 1);
		opacityStep.value = JsonFile.num(Reflect.field(o, "opacity"), 1);
		strumStep.value = JsonFile.num(Reflect.field(o, "strumLine"), -1);
		fixedCheck.checked = Reflect.field(o, "fixed") == true;
		visibleCheck.checked = Reflect.field(o, "visible") != false;
		var color = Reflect.field(o, "color");
		lastWheelColor = (Std.int(JsonFile.num(Reflect.field(color, "r"), 255)) << 16) | (Std.int(JsonFile.num(Reflect.field(color, "g"), 255)) << 8) | Std.int(JsonFile.num(Reflect.field(color, "b"), 255));
		colorWheel.setValue(FlxColor.fromInt(0xFF000000 | lastWheelColor));
	}

	function syncPositionWidgets():Void
	{
		if (sel < 0) return;
		var p = pos(objects[sel]);
		var sc = scl(objects[sel]);
		posX.value = JsonFile.num(Reflect.field(p, "x"), 0);
		posY.value = JsonFile.num(Reflect.field(p, "y"), 0);
		scaleX.value = JsonFile.num(Reflect.field(sc, "x"), 1);
		scaleY.value = JsonFile.num(Reflect.field(sc, "y"), 1);
	}

	function setObjField(group:String, axis:String, value:Float):Void
	{
		if (sel < 0) return;
		Reflect.setField(JsonFile.obj(tr(objects[sel]), group), axis, JsonFile.round(value));
		touch();
	}

	function setTopField(field:String, value:Dynamic):Void
	{
		if (sel < 0) return;
		Reflect.setField(objects[sel], field, value);
		touch();
		refreshList();
	}

	function setVisible(i:Int, value:Bool):Void
	{
		Reflect.setField(objects[i], "visible", value);
		visibleCheck.checked = value;
		touch();
		refreshList();
	}

	function mirror(axis:String):Void
	{
		if (sel < 0) return;
		var sc = scl(objects[sel]);
		Reflect.setField(sc, axis, -JsonFile.num(Reflect.field(sc, axis), 1));
		touch();
		syncPositionWidgets();
	}

	// ───────────────────────── edicion ─────────────────────────

	function pick(lx:Float, ly:Float):Int
	{
		var i = views.length - 1;
		while (i >= 0)
		{
			var v = views[i];
			if (lx >= v.x && lx <= v.x + v.width && ly >= v.y && ly <= v.y + v.height) return i;
			i--;
		}
		return -1;
	}

	function move(i:Int, dx:Float, dy:Float):Void
	{
		var p = pos(objects[i]);
		Reflect.setField(p, "x", JsonFile.round(JsonFile.num(Reflect.field(p, "x"), 0) + dx));
		Reflect.setField(p, "y", JsonFile.round(JsonFile.num(Reflect.field(p, "y"), 0) + dy));
		touch();
		syncPositionWidgets();
	}

	/** Cambia el tamano conservando el signo (espejo) de cada eje. */
	function rescale(i:Int, delta:Float):Void
	{
		var sc = scl(objects[i]);
		var sx = JsonFile.num(Reflect.field(sc, "x"), 1);
		var sy = JsonFile.num(Reflect.field(sc, "y"), sx);
		Reflect.setField(sc, "x", JsonFile.round((sx < 0 ? -1 : 1) * Math.max(0.01, Math.abs(sx) + delta)));
		Reflect.setField(sc, "y", JsonFile.round((sy < 0 ? -1 : 1) * Math.max(0.01, Math.abs(sy) + delta)));
		touch();
		syncPositionWidgets();
	}

	/** Pasa un objeto a (o de) `fixed` sin que se mueva ni cambie de tamano en pantalla. */
	function setFixed(i:Int, fixed:Bool):Void
	{
		var o = objects[i];
		var before = compute(i);
		Reflect.setField(o, "fixed", fixed);
		var p = pos(o);
		var sc = scl(o);
		var sf = scroll(o);
		if (fixed)
		{
			Reflect.setField(p, "x", JsonFile.round(before.px / viewW));
			Reflect.setField(p, "y", JsonFile.round(before.py / viewH));
		}
		else
		{
			var now = compute(i);
			var cam = camPoint(camIdx);
			var cam0 = camPoint(0);
			Reflect.setField(p, "x", JsonFile.round((before.px - viewW / 2) / now.ppu + cam0.x + (cam.x - cam0.x) * JsonFile.num(Reflect.field(sf, "x"), 1)));
			Reflect.setField(p, "y", JsonFile.round((before.py - viewH / 2) / now.ppu + cam0.y + (cam.y - cam0.y) * JsonFile.num(Reflect.field(sf, "y"), 1)));
		}
		var after = compute(i);
		var kx = after.tx == 0 ? 1 : before.tx / after.tx;
		var ky = after.ty == 0 ? 1 : before.ty / after.ty;
		Reflect.setField(sc, "x", JsonFile.round(JsonFile.num(Reflect.field(sc, "x"), 1) * kx));
		Reflect.setField(sc, "y", JsonFile.round(JsonFile.num(Reflect.field(sc, "y"), 1) * ky));
		touch();
		fixedCheck.checked = fixed;
		syncPositionWidgets();
		refreshList();
	}

	function setSprite(i:Int, name:String):Void
	{
		Reflect.setField(objects[i], "spr", name);
		replaceView(i);
		touch();
		refreshList();
		syncObjectWidgets();
	}

	function cycleSprite(dir:Int):Void
	{
		if (sel < 0 || spriteNames.length == 0) return;
		var at = spriteNames.indexOf(Std.string(Reflect.field(objects[sel], "spr")));
		setSprite(sel, spriteNames[(at + dir + spriteNames.length * 2) % spriteNames.length]);
	}

	function addObject():Void
	{
		var cam = camPoint(camIdx);
		var name = sel >= 0 ? Std.string(Reflect.field(objects[sel], "spr")) : (spriteNames.length > 0 ? spriteNames[0] : "");
		objects.push({
			visible: true, spr: name, strumLine: -1, fixed: false, opacity: 1,
			color: {r: 255, g: 255, b: 255},
			transform: [{position: {x: cam.x, y: cam.y}, scrollFactor: {x: 1, y: 1}, scale: {x: 1, y: 1}}]
		});
		rebuild();
		select(objects.length - 1);
		touch();
	}

	function duplicate(i:Int):Void
	{
		var copy:Dynamic = Json.parse(Json.stringify(objects[i]));
		var p = pos(copy);
		var gap = Reflect.field(copy, "fixed") == true ? 0.02 : 40;
		Reflect.setField(p, "x", JsonFile.num(Reflect.field(p, "x"), 0) + gap);
		Reflect.setField(p, "y", JsonFile.num(Reflect.field(p, "y"), 0) + gap);
		objects.insert(i + 1, copy);
		rebuild();
		select(i + 1);
		touch();
	}

	function deleteObject(i:Int):Void
	{
		objects.splice(i, 1);
		rebuild();
		select(Std.int(Math.min(i, objects.length - 1)));
		touch();
	}

	function swap(i:Int, j:Int):Void
	{
		if (j < 0 || j >= objects.length) return;
		var tmp = objects[i];
		objects[i] = objects[j];
		objects[j] = tmp;
		rebuild();
		select(j);
		touch();
	}

	// ───────────────────────── guardar / salir ─────────────────────────

	function save():Void
	{
		if (JsonFile.write(scenePath, scene))
		{
			dirty = false;
			SaveWarning.showWarning = false;
			UIState.playEditorSound(funkin.backend.system.Flags.DEFAULT_EDITOR_SAVE_SOUND);
			notify("Guardado: scene.json");
		}
		else
			notify("No se pudo escribir " + scenePath);
	}

	function reload():Void
	{
		var bak = scene;
		var fresh = JsonFile.read(scenePath);
		if (fresh == null || !Std.isOfType(fresh.objects, Array))
		{
			scene = bak;
			notify("No hay un scene.json valido en el disco.");
			return;
		}
		scene = fresh;
		objects = scene.objects;
		dirty = false;
		SaveWarning.showWarning = false;
		setCamera(0);
		rebuild();
		select(objects.length > 0 ? 0 : -1);
		notify("Recargado desde el disco.");
	}

	function exit():Void
	{
		if (!dirty)
		{
			FlxG.switchState(() -> new AdvancedToolsState(levelName));
			return;
		}
		openSubState(new UIWarningSubstate("Cambios sin guardar", "Hay cambios en scene.json que todavia no guardaste.", [
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
		syncOrder();

		var typing = currentFocus != null;
		if (FlxG.keys.justPressed.ANY && !typing && curContextMenu == null && !topMenuSpr.anyMenuOpened) UIUtil.processShortcuts(topMenu);

		var keys = FlxG.keys;
		var shift = keys.pressed.SHIFT;
		var ctrl = keys.pressed.CONTROL;
		var mx = FlxG.mouse.screenX;
		var my = FlxG.mouse.screenY;
		var lx = mx - viewX;
		var ly = my - viewY;
		var inView = lx >= 0 && lx <= viewW && ly >= 0 && ly <= viewH && !topMenuSpr.anyMenuOpened && curContextMenu == null;

		// la vista: elegir, arrastrar y escalar con la rueda
		if (FlxG.mouse.justPressed && inView)
		{
			var hit = pick(lx, ly);
			if (hit >= 0)
			{
				select(hit);
				dragging = true;
			}
		}
		if (!FlxG.mouse.pressed) dragging = false;
		if (dragging && sel >= 0)
		{
			var dx = mx - lastMX;
			var dy = my - lastMY;
			if (dx != 0 || dy != 0)
			{
				if (Reflect.field(objects[sel], "fixed") == true) move(sel, dx / viewW, dy / viewH);
				else
				{
					var ppu = compute(sel).ppu;
					move(sel, dx / ppu, dy / ppu);
				}
			}
		}
		lastMX = mx;
		lastMY = my;
		if (inView && FlxG.mouse.wheel != 0 && sel >= 0)
			rescale(sel, FlxG.mouse.wheel * (shift ? 0.25 : ctrl ? 0.01 : 0.05));

		// flechas: mover el objeto elegido (SHIFT x10, CTRL fino)
		if (!typing && !topMenuSpr.anyMenuOpened && sel >= 0 && sel < objects.length)
		{
			var ax = (keys.justPressed.RIGHT ? 1 : 0) - (keys.justPressed.LEFT ? 1 : 0);
			var ay = (keys.justPressed.DOWN ? 1 : 0) - (keys.justPressed.UP ? 1 : 0);
			if (ax != 0 || ay != 0)
			{
				var fixed = Reflect.field(objects[sel], "fixed") == true;
				var unit = fixed ? (shift ? 0.1 : ctrl ? 0.001 : 0.01) : (shift ? 100 : ctrl ? 1 : 10);
				move(sel, ax * unit, ay * unit);
			}
		}

		// el color se elige en el widget: se aplica cuando cambia
		if (sel >= 0 && sel < objects.length && colorWheel.curColor != null)
		{
			var c:Int = colorWheel.curColor & 0xFFFFFF;
			if (c != lastWheelColor)
			{
				lastWheelColor = c;
				var color = JsonFile.obj(objects[sel], "color");
				Reflect.setField(color, "r", (c >> 16) & 0xFF);
				Reflect.setField(color, "g", (c >> 8) & 0xFF);
				Reflect.setField(color, "b", c & 0xFF);
				touch();
			}
		}

		for (i in 0...objects.length) place(i);
		drawSelection();
		refreshInfo();
	}

	function refreshInfo():Void
	{
		var extra = 0;
		if (sel >= 0 && sel < objects.length) extra = (cast Reflect.field(objects[sel], "transform") : Array<Dynamic>).length - 1;
		infoText.text = "Vista de la camara " + (camIdx + 1) + "/" + camCount() + (dirty ? "   * sin guardar" : "") + (extra > 0 ? "   (+" + extra + " transform extra: no se editan)" : "")
			+ "\nClick y arrastra para mover. Rueda: escala. Flechas: mover (SHIFT x10, CTRL fino). Arrastra los botones de la lista para cambiar las capas.";
	}

	override public function destroy():Void
	{
		SaveWarning.saveFunc = null;
		views = [];
		super.destroy();
	}
}
