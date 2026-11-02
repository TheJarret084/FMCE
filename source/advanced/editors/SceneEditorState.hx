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
import flixel.addons.display.FlxGridOverlay;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import funkin.editors.SaveWarning;
import funkin.editors.ui.*;
import funkin.editors.ui.UIContextMenu.UIContextMenuOption;
import funkin.editors.ui.notifications.UIBaseNotification;
import funky.game.LevelSprite;
import funky.game.SpriteBuilder;
import funky.game.Stage;
import haxe.Json;
import haxe.ds.ObjectMap;
import funky.backend.chart.EventRemap;
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
	/** Los objetos tal como estan en el disco (por referencia): sirven para saber a donde se movio cada uno. */
	var baseline:Array<Dynamic> = [];
	var scene:Dynamic;
	var objects:Array<Dynamic> = [];

	var uiCamera:FlxCamera;
	var mouseP:FlxPoint = FlxPoint.get();
	var wasPressed:Bool = false;
	var debugText:UIText;
	var camScene:FlxCamera;
	var viewX:Int;
	var viewY:Int;
	var viewW:Int;
	var viewH:Int;
	var layer:FlxGroup;
	var views:Array<FlxSprite> = [];
	var selBars:Array<FlxSprite> = [];
	/** Pestana Camaras: el mundo queda fijo y la camara elegida es este marco (relleno, borde y el icono de camara al centro). */
	var camFrame:FlxSprite;
	/** Pestana Camaras: cuadricula de fondo y la caja negra del mundo. */
	var worldBackdrop:FlxSprite;
	var worldBox:FlxSprite;
	var camBars:Array<FlxSprite> = [];
	var camIcon:FlxSprite;

	var topMenu:Array<UIContextMenuOption>;
	var topMenuSpr:UITopMenu;
	var objectList:UIButtonList<EditorListButton>;
	var spriteNames:Array<String> = [];

	var spriteDrop:UIDropDown;
	var spriteBtn:UIButton;
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
	/** Lista de POSICIONES (`transform`) del objeto: anterior / siguiente / agregar / quitar. */
	var posPrev:UIButton;
	var posNext:UIButton;
	var posAdd:UIButton;
	var posDel:UIButton;
	var posIdxText:UIText;
	/** Pestanas del panel de objeto (Posicion / Apariencia / Logica) y los widgets de cada una. */
	var objTabs:Array<UIButton> = [];
	var objPages:Array<Array<FlxBasic>> = [[], [], []];
	var objTab:Int = 0;
	/** Cual de las `transform` del objeto elegido se esta editando (la lista de POSICIONES). */
	var tIdx:Int = 0;
	var colorWheel:ColorField;
	var objWidgets:Array<UISprite> = [];
	var lastWheelColor:Int = 0xFFFFFF;

	var camDel:UIButton;
	var camList:UIButtonList<EditorListButton>;
	var camListCount:Int = -1;
	var tabObjects:UIButton;
	var tabCams:UIButton;
	/** 0 = Objetos, 1 = Camaras. */
	var mode:Int = 0;
	var objPanel:Array<FlxBasic> = [];
	var camPanel:Array<FlxBasic> = [];
	var camX:FieldStepper;
	var camY:FieldStepper;
	var camZoom:FieldStepper;

	var infoText:UIText;
	var sel:Int = -1;
	/** Seleccion multiple: `sel` es el objeto principal (el de los widgets) y `extra` los demas elegidos (por referencia). */
	var extra:Array<Dynamic> = [];
	var multiMode:Bool = false;
	var marqueeBox:FlxSprite;
	var marqueeOn:Bool = false;
	var marqueeX:Float = 0;
	var marqueeY:Float = 0;
	/** Objeto al que se alterna / al que se colapsa la seleccion si el toque no llega a arrastrar. */
	var tapCandidate:Int = -1;
	var collapseTo:Int = -1;
	var pressTravel:Float = 0;
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
		baseline = objects.copy();

		// fondo de la pestana Camaras (como FNMM: cuadricula y, encima, el mundo con su esquina (0, 0) arriba a la izquierda)
		worldBackdrop = FlxGridOverlay.create(32, 32, viewW, viewH, true, 0xFF1C2630, 0xFF18202A);
		worldBackdrop.cameras = [camScene];
		worldBackdrop.scrollFactor.set();
		worldBackdrop.visible = false;
		add(worldBackdrop);
		worldBox = new FlxSprite().makeGraphic(1, 1, 0xFF000000);
		worldBox.cameras = [camScene];
		worldBox.scrollFactor.set();
		worldBox.scale.set(WORLD_W * worldPpu(), WORLD_H * worldPpu());
		worldBox.updateHitbox();
		worldBox.setPosition(worldOffX(), worldOffY());
		worldBox.visible = false;
		add(worldBox);

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
		// marco de la camara (solo se ve en la pestana Camaras)
		camFrame = new FlxSprite().makeGraphic(1, 1, 0x55E03030);
		camFrame.cameras = [camScene];
		camFrame.scrollFactor.set();
		camFrame.visible = false;
		add(camFrame);
		for (i in 0...4)
		{
			var bar = new FlxSprite().makeGraphic(1, 1, 0xFFE03030);
			bar.cameras = [camScene];
			bar.scrollFactor.set();
			bar.visible = false;
			camBars.push(bar);
			add(bar);
		}
		camIcon = new FlxSprite().makeGraphic(30, 16, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRect(camIcon, 1, 2, 19, 13, 0xFFE03030, {thickness: 2, color: FlxColor.BLACK});
		FlxSpriteUtil.drawPolygon(camIcon, [FlxPoint.get(21, 8), FlxPoint.get(29, 2), FlxPoint.get(29, 14)], 0xFFE03030, {thickness: 2, color: FlxColor.BLACK});
		camIcon.cameras = [camScene];
		camIcon.scrollFactor.set();
		camIcon.visible = false;
		add(camIcon);
		marqueeBox = new FlxSprite().makeGraphic(1, 1, 0x558CC4FF);
		marqueeBox.cameras = [camScene];
		marqueeBox.scrollFactor.set();
		marqueeBox.visible = false;
		add(marqueeBox);

		// marco de la vista
		for (r in [[viewX - 1, viewY - 1, viewW + 2, 1], [viewX - 1, viewY + viewH, viewW + 2, 1], [viewX - 1, viewY - 1, 1, viewH + 2], [viewX + viewW, viewY - 1, 1, viewH + 2]])
			ui(new FlxSprite(r[0], r[1]).makeGraphic(Std.int(r[2]), Std.int(r[3]), 0xFF3A4152));

		buildTopMenu();
		buildLeft();
		buildRight();

		infoText = ui(new UIText(viewX, viewY + viewH + 10, viewW, "", 12));
		debugText = ui(new UIText(viewX + 6, viewY + 4, viewW, "", 12));
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
					{label: "Duplicar", keybind: [CONTROL, D], onSelect: function(_) duplicateSelected()},
					{label: "Borrar", keybind: [DELETE], onSelect: function(_) deleteSelected()},
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
					{label: "Sprite anterior", keybind: [Q], onSelect: function(_) cycleSprite(-1)},
					null,
					{label: "Seleccion multiple (alternar)", keybind: [F2], onSelect: function(_) setMulti(!multiMode)},
					{label: "Seleccionar todo", keybind: [CONTROL, A], onSelect: function(_) selectAll()},
					{label: "Quitar la seleccion extra", keybind: [CONTROL, SHIFT, A], onSelect: function(_) if (sel >= 0) select(sel)}
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
		tabObjects = ui(new UIButton(6, TOP + 4, "Objetos", function() setMode(0), 108, 26));
		tabCams = ui(new UIButton(118, TOP + 4, "Camaras", function() setMode(1), 106, 26));

		var listY = TOP + 36;
		objectList = new UIButtonList<EditorListButton>(0, listY, LEFT_W, FlxG.height - listY, "Objetos (la lista es el orden de capas)", FlxPoint.get(LEFT_W - 30, 28), null, 4);
		objectList.cameras = [uiCamera];
		objectList.addButton.callback = addObject;
		add(objectList);

		camList = new UIButtonList<EditorListButton>(0, listY, LEFT_W, FlxG.height - listY, "Camaras (la 1 es el origen del mundo)", FlxPoint.get(LEFT_W - 30, 28), null, 4);
		camList.cameras = [uiCamera];
		camList.addButton.callback = addCamera;
		add(camList);
	}

	function buildRight():Void
	{
		var x0 = FlxG.width - RIGHT_W;
		var y0 = TOP;
		var objStart = members.length;
		ui(new UIWindow(x0, y0, RIGHT_W, 440, "Objeto"));

		// pestanas: Posicion / Apariencia / Logica (el mismo estilo de las pestanas Objetos / Camaras)
		var tabNames = ["Posicion", "Apariencia", "Logica"];
		var tw = Std.int((RIGHT_W - 40 - 4) / 3);
		for (i in 0...3)
		{
			var index = i;
			objTabs.push(ui(new UIButton(x0 + 20 + i * (tw + 2), y0 + 34, tabNames[i], function() setObjTab(index), tw, 24)));
		}
		var top = y0 + 68;
		var half = x0 + 156;

		// ── Posicion ──
		fixedCheck = ui(new UICheckbox(x0 + 20, top + 2, "Fixed (pegado a la pantalla)", false));
		fixedCheck.onChecked = function(b:Bool) if (sel >= 0) setFixed(sel, b);

		var l1 = label(x0 + 20, top + 36, "Posiciones (transform)");
		posPrev = ui(new UIButton(x0 + 20, top + 56, "<", function() stepTransform(-1), 30, 28));
		posNext = ui(new UIButton(x0 + 54, top + 56, ">", function() stepTransform(1), 30, 28));
		posIdxText = label(x0 + 94, top + 62, "0 de 1");
		posAdd = ui(new UIButton(x0 + RIGHT_W - 20 - 30, top + 56, "+", addTransform, 30, 28));
		posDel = ui(new UIButton(x0 + RIGHT_W - 20 - 64, top + 56, "-", removeTransform, 30, 28));

		var l2 = label(x0 + 20, top + 96, "Posicion X");
		posX = ui(new FieldStepper(x0 + 20, top + 114, 0, 1, 3, null, null, 120));
		posX.onValue = function(v:Float) setObjField("position", "x", v);
		var l3 = label(half, top + 96, "Posicion Y");
		posY = ui(new FieldStepper(half, top + 114, 0, 1, 3, null, null, 120));
		posY.onValue = function(v:Float) setObjField("position", "y", v);

		var l4 = label(x0 + 20, top + 152, "Escala X");
		scaleX = ui(new FieldStepper(x0 + 20, top + 170, 1, 0.05, 3, null, null, 120));
		scaleX.onValue = function(v:Float) setObjField("scale", "x", v);
		var l5 = label(half, top + 152, "Escala Y");
		scaleY = ui(new FieldStepper(half, top + 170, 1, 0.05, 3, null, null, 120));
		scaleY.onValue = function(v:Float) setObjField("scale", "y", v);
		var mirrorBtn = ui(new UIButton(x0 + 20, top + 208, "Espejo X", function() mirror("x"), 120, 28));

		var l6 = label(x0 + 20, top + 248, "Parallax X");
		scrollX = ui(new FieldStepper(x0 + 20, top + 266, 1, 0.05, 3, null, null, 120));
		scrollX.onValue = function(v:Float) setObjField("scrollFactor", "x", v);
		var l7 = label(half, top + 248, "Parallax Y");
		scrollY = ui(new FieldStepper(half, top + 266, 1, 0.05, 3, null, null, 120));
		scrollY.onValue = function(v:Float) setObjField("scrollFactor", "y", v);

		objPages[0] = [fixedCheck, l1, posPrev, posNext, posIdxText, posAdd, posDel, l2, posX, l3, posY, l4, scaleX, l5, scaleY, mirrorBtn, l6, scrollX, l7, scrollY];

		// ── Apariencia ──
		var a1 = label(x0 + 20, top + 2, "Sprite");
		spriteDrop = ui(new UIDropDown(x0 + 20, top + 20, RIGHT_W - 40 - 40, 32, [""], 0));
		spriteDrop.onChange = function(i:Int) if (sel >= 0 && i >= 0 && i < spriteNames.length) setSprite(sel, spriteNames[i]);
		spriteBtn = ui(new UIButton(x0 + RIGHT_W - 20 - 34, top + 20, "...", openSpritePack, 34, 32));

		var a2 = label(x0 + 20, top + 70, "Opacidad");
		opacityStep = ui(new FieldStepper(x0 + 20, top + 88, 1, 0.1, 2, 0, 1, 120));
		opacityStep.onValue = function(v:Float) setTopField("opacity", JsonFile.round(v));
		visibleCheck = ui(new UICheckbox(x0 + 20, top + 136, "Visible", true));
		visibleCheck.onChecked = function(b:Bool) if (sel >= 0) setVisible(sel, b);
		var a3 = label(x0 + 20, top + 176, "Color");
		colorWheel = ui(new ColorField(x0 + 80, top + 168, 0xFFFFFFFF));

		objPages[1] = [a1, spriteDrop, spriteBtn, a2, opacityStep, visibleCheck, a3, colorWheel];

		// ── Logica ──
		var g1 = label(x0 + 20, top + 2, "Strumline (-1 = ninguna)");
		strumStep = ui(new FieldStepper(x0 + 20, top + 20, -1, 1, 0, -1, 9, 120));
		strumStep.onValue = function(v:Float) setTopField("strumLine", Std.int(v));
		objPages[2] = [g1, strumStep];

		// ── siempre a la vista ──
		var dup = ui(new UIButton(x0 + 20, y0 + 402, "Duplicar", function() duplicateSelected(), 120, 28));
		var del = ui(new UIButton(x0 + 156, y0 + 402, "Borrar", function() deleteSelected(), 120, 28));
		del.color = 0xFFFF8080;

		objWidgets = [spriteDrop, spriteBtn, posX, posY, scaleX, scaleY, scrollX, scrollY, opacityStep, strumStep, fixedCheck, visibleCheck, colorWheel, posPrev, posNext, posAdd, posDel, mirrorBtn, dup, del];

		objPanel = members.slice(objStart);

		// ── pestaña Camaras ──
		var camStart = members.length;
		ui(new UIWindow(x0, y0, RIGHT_W, 250, "Camara"));
		label(x0 + 20, y0 + 38, "Posicion X");
		camX = ui(new FieldStepper(x0 + 20, y0 + 58, 0, 10, 2, null, null, 120));
		camX.onValue = function(v:Float) setCameraField("x", v);
		label(x0 + 156, y0 + 38, "Posicion Y");
		camY = ui(new FieldStepper(x0 + 156, y0 + 58, 0, 10, 2, null, null, 120));
		camY.onValue = function(v:Float) setCameraField("y", v);
		label(x0 + 20, y0 + 100, "Zoom");
		camZoom = ui(new FieldStepper(x0 + 20, y0 + 120, 1, 0.05, 3, 0.05, 20, 120));
		camZoom.onValue = function(v:Float) setCameraField("scale", v);
		camDel = ui(new UIButton(x0 + 156, y0 + 118, "Borrar camara", deleteCamera, 120, 28));
		camDel.color = 0xFFFF8080;
		var camHelp = label(x0 + 20, y0 + 170, "En la vista: arrastra para mover la camara,\nrueda para el zoom. Flechas: mover (SHIFT x10,\nCTRL fino). Solo se borra la ultima camara.");
		camHelp.alpha = 0.8;
		camPanel = members.slice(camStart);

		refreshCameraWidgets(true);
		setMode(0);
	}

	// ───────────────────────── datos ─────────────────────────

	/** Entrada de `transform` en uso (se crea si falta, migrando el formato viejo de x/y sueltos). */
	function tr(o:Dynamic):Dynamic
	{
		var list:Dynamic = Reflect.field(o, "transform");
		if (Std.isOfType(list, Array) && (list : Array<Dynamic>).length > 0)
		{
			// el objeto elegido usa la posicion que se esta editando; los demas, la primera
			var all:Array<Dynamic> = list;
			var at = (sel >= 0 && sel < objects.length && objects[sel] == o) ? tIdx : 0;
			return all[Std.int(Math.max(0, Math.min(all.length - 1, at)))];
		}
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
			scene.cameras = [{position: {x: WORLD_W / 2, y: WORLD_H / 2}, scale: 1}]; // una camara nueva nace en el centro del mundo
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

	/**
	 * Mundo de las camaras, igual que FNMM: el (0, 0) es la ESQUINA de arriba a la izquierda y el mundo mide solo
	 * `WORLD_W` x `WORLD_H`. Los sprites pueden salirse de ahi, las camaras NO: el marco entero se queda dentro.
	 */
	static inline var WORLD_W:Float = 2160;
	static inline var WORLD_H:Float = 1920;
	/** Margen (fraccion del mundo, a cada lado) que se deja ver alrededor del mundo para los sprites que se salen. */
	static inline var WORLD_PAD:Float = 0.1;

	/** Px de la vista por unidad del mundo en la pestana Camaras (el mundo y su margen caben en la vista). */
	function worldPpu():Float
		return Math.min(viewW / (WORLD_W * (1 + 2 * WORLD_PAD)), viewH / (WORLD_H * (1 + 2 * WORLD_PAD)));

	/** Donde cae la esquina (0, 0) del mundo dentro de la vista. */
	function worldOffX():Float
		return (viewW - WORLD_W * worldPpu()) / 2;

	function worldOffY():Float
		return (viewH - WORLD_H * worldPpu()) / 2;

	/**
	 * Mantiene la camara dentro del mundo (solo en el editor; en juego la camara va tal cual): el marco entero queda entre
	 * (0, 0) y (WORLD_W, WORLD_H), asi que el scale tambien tiene un maximo (el marco no puede ser mas grande que el mundo).
	 * La posicion es el centro del marco. true si la movio.
	 */
	function limitCameraPoint(c:Dynamic):Bool
	{
		var p = Reflect.field(c, "position");
		var x = JsonFile.num(Reflect.field(p, "x"), 0);
		var y = JsonFile.num(Reflect.field(p, "y"), 0);
		var scale = JsonFile.num(Reflect.field(c, "scale"), 1);

		var baseW = Stage.VIEW_WORLD_WIDTH / Stage.CAM_PRESET; // ancho del marco con scale 1
		var baseH = baseW * viewH / viewW;
		var limited = Math.max(0.05, Math.min(Math.min(WORLD_W / baseW, WORLD_H / baseH), scale));
		var halfW = baseW * limited / 2;
		var halfH = baseH * limited / 2;
		var nx = Math.max(halfW, Math.min(WORLD_W - halfW, x));
		var ny = Math.max(halfH, Math.min(WORLD_H - halfH, y));
		if (nx == x && ny == y && limited == scale) return false;

		Reflect.setField(p, "x", JsonFile.round(nx));
		Reflect.setField(p, "y", JsonFile.round(ny));
		Reflect.setField(c, "scale", JsonFile.round(limited));
		return true;
	}

	/** Centra el marco de la camara elegida en (x, y) del mundo. */
	function setCameraCenter(x:Float, y:Float):Void
	{
		var c = camObject();
		var p = Reflect.field(c, "position");
		Reflect.setField(p, "x", JsonFile.round(x));
		Reflect.setField(p, "y", JsonFile.round(y));
		limitCameraPoint(c);
		touch();
		refreshCameraWidgets();
	}

	/** El marco de la camara elegida sobre el mundo fijo, en px de la vista. */
	function camFrameRect():{x:Float, y:Float, w:Float, h:Float}
	{
		var cam = camPoint(camIdx);
		var ppu = worldPpu();
		var w = Stage.VIEW_WORLD_WIDTH * Math.max(0.001, cam.scale) / Stage.CAM_PRESET * ppu;
		var h = w * viewH / viewW;
		return {x: worldOffX() + cam.x * ppu - w / 2, y: worldOffY() + cam.y * ppu - h / 2, w: w, h: h};
	}

	function drawCameraFrame():Void
	{
		var on = mode == 1;
		camFrame.visible = camIcon.visible = worldBackdrop.visible = worldBox.visible = on;
		for (b in camBars) b.visible = on;
		if (!on) return;

		var f = camFrameRect();
		camFrame.scale.set(f.w, f.h);
		camFrame.updateHitbox();
		camFrame.setPosition(f.x, f.y);

		var rects = [[f.x, f.y, f.w, 2.0], [f.x, f.y + f.h - 2, f.w, 2.0], [f.x, f.y, 2.0, f.h], [f.x + f.w - 2, f.y, 2.0, f.h]];
		for (i in 0...4)
		{
			camBars[i].scale.set(Math.max(1, rects[i][2]), Math.max(1, rects[i][3]));
			camBars[i].updateHitbox();
			camBars[i].setPosition(rects[i][0], rects[i][1]);
		}
		camIcon.setPosition(f.x + f.w / 2 - camIcon.width / 2, f.y + f.h / 2 - camIcon.height / 2);
	}

	function setCameraField(field:String, value:Float):Void
	{
		var c = camObject();
		if (field == "scale") Reflect.setField(c, "scale", JsonFile.round(Math.max(0.05, value)));
		else Reflect.setField(Reflect.field(c, "position"), field, JsonFile.round(value));
		var moved = limitCameraPoint(c);
		touch();
		if (moved) refreshCameraWidgets();
	}

	function panCamera(dx:Float, dy:Float):Void
	{
		var c = camObject();
		var p = Reflect.field(c, "position");
		Reflect.setField(p, "x", JsonFile.round(JsonFile.num(Reflect.field(p, "x"), 0) + dx));
		Reflect.setField(p, "y", JsonFile.round(JsonFile.num(Reflect.field(p, "y"), 0) + dy));
		limitCameraPoint(c);
		touch();
		refreshCameraWidgets();
	}

	function zoomCamera(delta:Float):Void
	{
		var c = camObject();
		Reflect.setField(c, "scale", JsonFile.round(Math.max(0.05, JsonFile.num(Reflect.field(c, "scale"), 1) + delta)));
		limitCameraPoint(c);
		touch();
		refreshCameraWidgets();
	}

	function addCamera():Void
	{
		camObject();
		var c = camPoint(camIdx);
		(scene.cameras : Array<Dynamic>).push({position: {x: c.x, y: c.y}, scale: c.scale});
		camIdx = camCount() - 1;
		touch();
		refreshCameraWidgets(true);
	}

	function deleteCamera():Void
	{
		var n = camCount();
		if (camIdx != n - 1 || camIdx == 0)
		{
			notify("Solo se puede borrar la ultima camara (la 1 es el origen del mundo): los eventos las usan por numero.");
			return;
		}
		(scene.cameras : Array<Dynamic>).pop();
		camIdx = n - 2;
		touch();
		refreshCameraWidgets(true);
	}

	/** Los widgets siguen a la camara elegida; la lista se rearma solo si cambio la cantidad (o se pide). */
	function refreshCameraWidgets(rebuildList:Bool = false):Void
	{
		var c = camPoint(camIdx);
		camX.value = c.x;
		camY.value = c.y;
		camZoom.value = c.scale;
		if (rebuildList || camListCount != camCount())
		{
			for (b in camList.buttons.members.copy())
				if (b != null) camList.remove(b);
			for (i in 0...camCount())
			{
				var index = i;
				var b = new EditorListButton(0, 0, "Camara " + (i + 1) + (i == 0 ? " (origen)" : ""), function() setCamera(index), LEFT_W - 30, 28);
				b.item = i;
				camList.add(b);
			}
			camListCount = camCount();
		}
		for (b in camList.buttons.members)
			if (b != null) b.mark(b.item == camIdx);
	}

	/** Pestaña de arriba a la izquierda: Objetos o Camaras (lista, panel y herramientas del lienzo cambian juntos). */
	function setMode(m:Int):Void
	{
		mode = m;
		var objs = m == 0;
		currentFocus = null;
		dragging = false;
		objectList.exists = objectList.visible = objs;
		camList.exists = camList.visible = !objs;
		for (o in objPanel) o.exists = objs;
		for (o in camPanel) o.exists = !objs;
		setObjTab(objTab);
		tabObjects.color = objs ? 0xFF8CC4FF : 0xFFFFFFFF;
		tabCams.color = objs ? 0xFFFFFFFF : 0xFF8CC4FF;
		if (!objs)
		{
			for (b in selBars) b.visible = false;
			marqueeOn = false;
			marqueeBox.visible = false;
		}
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
			b = new EditorListButton(0, 0, listLabel(i), function() clickObject(objects.indexOf(b.item)), LEFT_W - 30, 28);
			b.item = objects[i];
			objectList.add(b);
		}
		markList();
	}

	function markList():Void
	{
		for (b in objectList.buttons.members)
			if (b != null) b.mark(isSel(b.item), multiMode);
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
		var c = computeView(i);
		if (mode != 1) return c;

		// Pestana Camaras: los sprites son EXACTAMENTE los de la pestana Objetos (parallax incluido, visto desde la camara elegida),
		// pero encogidos dentro del marco de esa camara sobre el mundo fijo.
		var f = camFrameRect();
		var k = f.w / viewW;
		return {px: f.x + c.px * k, py: f.y + c.py * k, tx: c.tx * k, ty: c.ty * k, anim: c.anim, ppu: c.ppu * k};
	}

	/** Lo que se ve de un objeto desde la camara elegida, a todo el tamano de la vista (pestana Objetos). */
	function computeView(i:Int):{px:Float, py:Float, tx:Float, ty:Float, anim:Float, ppu:Float}
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
		var ppu = Stage.CAM_PRESET * viewW / (Stage.VIEW_WORLD_WIDTH * Math.max(0.001, cam.scale));
		var fx = JsonFile.num(Reflect.field(sf, "x"), 1);
		var fy = JsonFile.num(Reflect.field(sf, "y"), 1);
		// MISMA formula que `Stage.placementFor`: el scrollFactor multiplica la ESQUINA de la camara (centro - mitad de la vista).
		var halfX = viewW / 2 / ppu;
		var halfY = viewH / 2 / ppu;
		return {
			px: (x - (cam.x - halfX) * fx) * ppu,
			py: (y - (cam.y - halfY) * fy) * ppu,
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
		var primary = sel >= 0 && sel < views.length;
		for (bar in selBars) bar.visible = primary;
		if (primary) outline(selBars, 0, views[sel]);
	}

	/** Dibuja el borde de `v` con 4 barras de `bars` a partir de `first`. */
	function outline(bars:Array<FlxSprite>, first:Int, v:FlxSprite):Void
	{
		var rects = [[v.x, v.y, v.width, 2.0], [v.x, v.y + v.height - 2, v.width, 2.0], [v.x, v.y, 2.0, v.height], [v.x + v.width - 2, v.y, 2.0, v.height]];
		for (i in 0...4)
		{
			bars[first + i].scale.set(Math.max(1, rects[i][2]), Math.max(1, rects[i][3]));
			bars[first + i].updateHitbox();
			bars[first + i].setPosition(rects[i][0], rects[i][1]);
		}
	}

	// ───────────────────────── seleccion y widgets ─────────────────────────

	function select(index:Int):Void
	{
		var before = sel;
		extra = [];
		sel = objects.length == 0 ? -1 : Std.int(Math.max(-1, Math.min(objects.length - 1, index)));
		if (sel != before) tIdx = 0;
		markList();
		syncObjectWidgets();
	}

	// ───────────────────────── seleccion multiple ─────────────────────────

	function setMulti(on:Bool):Void
	{
		multiMode = on;
		markList(); // en multi los bloques de la lista se ven azules y los elegidos en morado
	}

	function isSel(o:Dynamic):Bool
		return (sel >= 0 && sel < objects.length && objects[sel] == o) || extra.indexOf(o) >= 0;

	/** Indices de todo lo elegido (el principal primero). */
	function selectedList():Array<Int>
	{
		var list:Array<Int> = [];
		if (sel >= 0 && sel < objects.length) list.push(sel);
		for (o in extra)
		{
			var i = objects.indexOf(o);
			if (i >= 0 && list.indexOf(i) < 0) list.push(i);
		}
		return list;
	}

	/** Clic en la lista: con multi (F2) alterna, si no elige solo ese. */
	function clickObject(index:Int):Void
	{
		if (multiMode) toggleSelect(index);
		else select(index);
	}

	function addToSelection(i:Int):Void
	{
		if (i < 0 || i >= objects.length) return;
		var o = objects[i];
		if (sel == i || extra.indexOf(o) >= 0) return;
		if (sel < 0)
		{
			sel = i;
			tIdx = 0;
		}
		else extra.push(o);
	}

	function toggleSelect(index:Int):Void
	{
		if (index < 0 || index >= objects.length) return;
		var o = objects[index];
		if (sel == index)
		{
			// se saca el principal: el siguiente elegido pasa a serlo
			if (extra.length > 0)
			{
				sel = objects.indexOf(extra.shift());
				tIdx = 0;
			}
			else sel = -1;
		}
		else if (extra.indexOf(o) >= 0) extra.remove(o);
		else addToSelection(index);
		markList();
		syncObjectWidgets();
	}

	function selectAll():Void
	{
		if (objects.length == 0) return;
		select(sel >= 0 ? sel : 0);
		for (i in 0...objects.length) addToSelection(i);
		markList();
		syncObjectWidgets();
	}

	/** Suma a la seleccion lo que toque el rectangulo (coordenadas de la vista). */
	function selectInRect(x1:Float, y1:Float, x2:Float, y2:Float):Void
	{
		var l = Math.min(x1, x2);
		var r = Math.max(x1, x2);
		var t = Math.min(y1, y2);
		var b = Math.max(y1, y2);
		for (i in 0...views.length)
		{
			var v = views[i];
			if (v.x <= r && v.x + v.width >= l && v.y <= b && v.y + v.height >= t) addToSelection(i);
		}
		markList();
		syncObjectWidgets();
	}

	function syncObjectWidgets():Void
	{
		var has = sel >= 0 && sel < objects.length;
		for (w in objWidgets) w.selectable = has;
		if (!has)
		{
			posIdxText.text = "-";
			return;
		}
		var o = objects[sel];
		var spr = Std.string(Reflect.field(o, "spr"));
		var at = spriteNames.indexOf(spr);
		spriteDrop.index = Std.int(Math.max(0, at));
		spriteDrop.label.text = spr;
		syncPositionWidgets();
		var sf = scroll(o);
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

	/** Lo que depende de la posicion (`transform`) en uso: indice, x / y y escala. */
	function syncPositionWidgets():Void
	{
		if (sel < 0 || sel >= objects.length) return;
		var p = pos(objects[sel]);
		var sc = scl(objects[sel]);
		posX.value = JsonFile.num(Reflect.field(p, "x"), 0);
		posY.value = JsonFile.num(Reflect.field(p, "y"), 0);
		scaleX.value = JsonFile.num(Reflect.field(sc, "x"), 1);
		scaleY.value = JsonFile.num(Reflect.field(sc, "y"), 1);
		posIdxText.text = tIdx + " de " + tCount();
		posPrev.selectable = tIdx > 0;
		posNext.selectable = tIdx < tCount() - 1;
		posDel.selectable = tCount() > 1;
	}

	/** Cambia de pestana del panel de objeto: solo se ven los widgets de esa pestana. */
	function setObjTab(index:Int):Void
	{
		objTab = index;
		for (p in 0...objPages.length)
		{
			for (w in objPages[p]) w.exists = mode == 0 && p == index;
			objTabs[p].color = p == index ? 0xFF8CC4FF : 0xFFFFFFFF;
		}
	}

	/** Cuantas posiciones (`transform`) tiene el objeto elegido. */
	function tCount():Int
	{
		if (sel < 0 || sel >= objects.length) return 0;
		var list:Dynamic = Reflect.field(objects[sel], "transform");
		return Std.isOfType(list, Array) ? Std.int(Math.max(1, (list : Array<Dynamic>).length)) : 1;
	}

	function stepTransform(dir:Int):Void
	{
		if (sel < 0) return;
		tr(objects[sel]);
		tIdx = Std.int(Math.max(0, Math.min(tCount() - 1, tIdx + dir)));
		syncPositionWidgets();
	}

	/** Agrega una posicion nueva (copia de la que se esta editando) y se pasa a ella. */
	function addTransform():Void
	{
		if (sel < 0) return;
		var current = tr(objects[sel]);
		var copy:Dynamic = Json.parse(Json.stringify(current));
		(cast Reflect.field(objects[sel], "transform") : Array<Dynamic>).push(copy);
		tIdx = tCount() - 1;
		touch();
		syncPositionWidgets();
		notify("Posicion " + tIdx + " agregada (copia de la anterior). Los eventos ObjectPositionSet usan estos numeros.");
	}

	function removeTransform():Void
	{
		if (sel < 0 || tCount() <= 1) return;
		tr(objects[sel]);
		(cast Reflect.field(objects[sel], "transform") : Array<Dynamic>).splice(tIdx, 1);
		tIdx = Std.int(Math.max(0, Math.min(tCount() - 1, tIdx)));
		touch();
		syncPositionWidgets();
	}

	/** Abre el administrador de sprites para cambiar el sprite del objeto elegido. */
	function openSpritePack():Void
	{
		if (sel < 0 || sel >= objects.length) return;
		var index = sel;
		openSubState(new SpritePackScreen(levelDir, Std.string(Reflect.field(objects[index], "spr")), function(name:String)
		{
			if (index < objects.length && name != "") setSprite(index, name);
		}, false, false, function(_:String)
		{
			// se importo un sprite desde el administrador: la lista del dropdown tambien lo tiene
			spriteNames = SpriteBuilder.listSprites(levelDir);
			spriteDrop.items = [for (i => name in spriteNames) {label: name, value: i}];
			spriteDrop.options = spriteNames.copy();
		}));
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
			var halfX = viewW / 2 / now.ppu;
			var halfY = viewH / 2 / now.ppu;
			Reflect.setField(p, "x", JsonFile.round(before.px / now.ppu + (cam.x - halfX) * JsonFile.num(Reflect.field(sf, "x"), 1)));
			Reflect.setField(p, "y", JsonFile.round(before.py / now.ppu + (cam.y - halfY) * JsonFile.num(Reflect.field(sf, "y"), 1)));
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

	/** Copia del objeto `i`, un poco corrida. */
	function cloneObject(i:Int):Dynamic
	{
		var copy:Dynamic = Json.parse(Json.stringify(objects[i]));
		var p = pos(copy);
		var gap = Reflect.field(copy, "fixed") == true ? 0.02 : 40;
		Reflect.setField(p, "x", JsonFile.num(Reflect.field(p, "x"), 0) + gap);
		Reflect.setField(p, "y", JsonFile.num(Reflect.field(p, "y"), 0) + gap);
		return copy;
	}

	function duplicate(i:Int):Void
	{
		objects.insert(i + 1, cloneObject(i));
		rebuild();
		select(i + 1);
		touch();
	}

	/** Duplica todo lo elegido; las copias quedan elegidas. */
	function duplicateSelected():Void
	{
		var list = selectedList();
		if (list.length == 0) return;
		if (list.length == 1)
		{
			duplicate(list[0]);
			return;
		}
		list.sort((a, b) -> b - a); // de atras para adelante: los indices que faltan por tratar no se mueven
		var copies:Array<Dynamic> = [];
		for (i in list)
		{
			var c = cloneObject(i);
			objects.insert(i + 1, c);
			copies.push(c);
		}
		rebuild();
		var at = [for (c in copies) objects.indexOf(c)];
		at.sort((a, b) -> a - b);
		select(at[0]);
		for (k in 1...at.length) addToSelection(at[k]);
		markList();
		touch();
	}

	function deleteSelected():Void
	{
		var list = selectedList();
		if (list.length == 0) return;
		list.sort((a, b) -> b - a);
		var first = list[list.length - 1];
		for (i in list) objects.splice(i, 1);
		rebuild();
		select(Std.int(Math.min(first, objects.length - 1)));
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
		// donde quedo cada objeto que ya estaba guardado (-1 = se borro): los eventos apuntan a ellos por su numero
		var moved = [for (o in baseline) objects.indexOf(o)];
		if (JsonFile.write(scenePath, scene))
		{
			dirty = false;
			SaveWarning.showWarning = false;
			UIState.playEditorSound(funkin.backend.system.Flags.DEFAULT_EDITOR_SAVE_SOUND);
			var message = "Guardado: scene.json";
			try
			{
				var fixed = EventRemap.applyToFile(Path.join([levelDir, "events.json"]), moved);
				if (fixed != null && fixed.changed > 0) message += " (" + fixed.changed + " eventos siguen a su objeto)";
				if (fixed != null && fixed.orphaned > 0) message += " - " + fixed.orphaned + " eventos apuntan a un objeto borrado";
			}
			catch (e:Dynamic)
			{
				message += " - no se pudo actualizar events.json: " + Std.string(e);
			}
			baseline = objects.copy();
			notify(message);
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
		baseline = objects.copy();
		camIdx = 0;
		refreshCameraWidgets(true);
		rebuild();
		select(objects.length > 0 ? 0 : -1);
		notify("Recargado desde el disco.");
	}

	function exit():Void
	{
		if (!dirty)
		{
			FlxG.switchState(new AdvancedToolsState(levelName));
			return;
		}
		openSubState(new UIWarningSubstate("Cambios sin guardar", "Hay cambios en scene.json que todavia no guardaste.", [
			{label: "Cancelar", color: 0x969533, onClick: function(_) {}},
			{label: "Salir sin guardar", color: 0x969533, onClick: function(_) {
				SaveWarning.showWarning = false;
				FlxG.switchState(new AdvancedToolsState(levelName));
			}},
			{label: "Guardar y salir", color: 0x969533, onClick: function(_) {
				save();
				FlxG.switchState(new AdvancedToolsState(levelName));
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
		// Mismo origen de coordenadas que usa el hover de todos los botones (camara de la UI).
		FlxG.mouse.getScreenPosition(uiCamera, mouseP);
		var mx = mouseP.x;
		var my = mouseP.y;
		// Un toque rapido puede traer press y release en el mismo frame: se detecta el borde a mano.
		var pressedNow = FlxG.mouse.pressed;
		var pressEdge = FlxG.mouse.justPressed || (pressedNow && !wasPressed);
		var tapEdge = FlxG.mouse.justReleased && !wasPressed && !pressEdge;
		var releaseEdge = FlxG.mouse.justReleased || (wasPressed && !pressedNow);
		wasPressed = pressedNow;
		var lx = mx - viewX;
		var ly = my - viewY;
		var inView = lx >= 0 && lx <= viewW && ly >= 0 && ly <= viewH && !topMenuSpr.anyMenuOpened && curContextMenu == null;

		// la vista: elegir, arrastrar y escalar con la rueda.
		// Con multi (solo se activa con F2) el clic suma o quita; arrastrar un objeto elegido mueve todo el grupo; arrastrar en
		// vacio dibuja un rectangulo que suma lo que toca.
		var additive = multiMode;
		if (mode == 0 && (pressEdge || tapEdge) && inView)
		{
			var hit = pick(lx, ly);
			pressTravel = 0;
			tapCandidate = -1;
			collapseTo = -1;
			if (hit >= 0)
			{
				var was = isSel(objects[hit]);
				if (additive)
				{
					if (!was)
					{
						addToSelection(hit);
						markList();
						syncObjectWidgets();
					}
					else if (tapEdge) toggleSelect(hit);
					else tapCandidate = hit; // si suelta sin arrastrar, se quita
				}
				else if (was && selectedList().length > 1)
				{
					// sobre uno de varios elegidos: se arrastra el grupo; si no llega a moverse, queda solo ese
					if (tapEdge) select(hit);
					else collapseTo = hit;
				}
				else select(hit);
				dragging = pressEdge;
			}
			else if (additive && pressEdge)
			{
				marqueeOn = true;
				marqueeX = lx;
				marqueeY = ly;
			}
		}
		if (!FlxG.mouse.pressed) dragging = false;
		if (mode == 0 && dragging && sel >= 0)
		{
			var dx = mx - lastMX;
			var dy = my - lastMY;
			if (dx != 0 || dy != 0)
			{
				pressTravel += Math.abs(dx) + Math.abs(dy);
				for (i in selectedList())
				{
					if (Reflect.field(objects[i], "fixed") == true) move(i, dx / viewW, dy / viewH);
					else
					{
						var ppu = compute(i).ppu;
						move(i, dx / ppu, dy / ppu);
					}
				}
			}
		}
		if (mode == 0 && marqueeOn)
		{
			var qx = Math.max(0, Math.min(viewW, lx));
			var qy = Math.max(0, Math.min(viewH, ly));
			if (pressedNow)
			{
				marqueeBox.visible = true;
				marqueeBox.scale.set(Math.max(1, Math.abs(qx - marqueeX)), Math.max(1, Math.abs(qy - marqueeY)));
				marqueeBox.updateHitbox();
				marqueeBox.setPosition(Math.min(qx, marqueeX), Math.min(qy, marqueeY));
			}
			else
			{
				marqueeOn = false;
				marqueeBox.visible = false;
				selectInRect(marqueeX, marqueeY, qx, qy);
			}
		}
		if (releaseEdge)
		{
			// un toque que no llego a mover nada: quita ese del grupo / deja solo ese
			if (pressTravel < 4)
			{
				if (tapCandidate >= 0) toggleSelect(tapCandidate);
				else if (collapseTo >= 0) select(collapseTo);
			}
			tapCandidate = -1;
			collapseTo = -1;
		}
		// pestaña Camaras: el mundo esta fijo; arrastra el marco (o toca el mundo para llevarlo ahi), rueda: zoom, flechas: mover
		if (mode == 1)
		{
			var wp = worldPpu();
			if (pressEdge && inView)
			{
				dragging = true;
				var f = camFrameRect();
				if (lx < f.x || lx > f.x + f.w || ly < f.y || ly > f.y + f.h)
					setCameraCenter((lx - worldOffX()) / wp, (ly - worldOffY()) / wp);
			}
			if (!FlxG.mouse.pressed) dragging = false;
			if (dragging && !pressEdge && (mx != lastMX || my != lastMY)) panCamera((mx - lastMX) / wp, (my - lastMY) / wp);
			if (inView && FlxG.mouse.wheel != 0) zoomCamera(FlxG.mouse.wheel * (shift ? 0.25 : ctrl ? 0.01 : 0.05));
			if (!typing && !topMenuSpr.anyMenuOpened)
			{
				var cx = (keys.justPressed.RIGHT ? 1 : 0) - (keys.justPressed.LEFT ? 1 : 0);
				var cy = (keys.justPressed.DOWN ? 1 : 0) - (keys.justPressed.UP ? 1 : 0);
				if (cx != 0 || cy != 0) panCamera(cx * (shift ? 100 : ctrl ? 1 : 10), cy * (shift ? 100 : ctrl ? 1 : 10));
			}
		}
		debugText.text = 'DEBUG mouse screen=${FlxG.mouse.screenX},${FlxG.mouse.screenY} ui=${Std.int(mx)},${Std.int(my)} juego=${FlxG.width}x${FlxG.height} camUI=${uiCamera.width}x${uiCamera.height}\n'
			+ 'vista=$viewX,$viewY,$viewW,$viewH dentro=$inView presionado=$pressedNow borde=$pressEdge toque=$tapEdge menu=${topMenuSpr.anyMenuOpened} ctx=${curContextMenu != null} sel=$sel';
		lastMX = mx;
		lastMY = my;
		if (mode == 0 && inView && FlxG.mouse.wheel != 0 && sel >= 0)
			for (i in selectedList()) rescale(i, FlxG.mouse.wheel * (shift ? 0.25 : ctrl ? 0.01 : 0.05));

		// flechas: mover el objeto elegido (SHIFT x10, CTRL fino)
		if (mode == 0 && !typing && !topMenuSpr.anyMenuOpened && sel >= 0 && sel < objects.length)
		{
			var ax = (keys.justPressed.RIGHT ? 1 : 0) - (keys.justPressed.LEFT ? 1 : 0);
			var ay = (keys.justPressed.DOWN ? 1 : 0) - (keys.justPressed.UP ? 1 : 0);
			if (ax != 0 || ay != 0)
			{
				for (i in selectedList())
				{
					var fixed = Reflect.field(objects[i], "fixed") == true;
					var unit = fixed ? (shift ? 0.1 : ctrl ? 0.001 : 0.01) : (shift ? 100 : ctrl ? 1 : 10);
					move(i, ax * unit, ay * unit);
				}
			}
		}

		// el color se elige en el widget: se aplica cuando cambia
		if (mode == 0 && sel >= 0 && sel < objects.length && colorWheel.curColor != null)
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
		if (mode == 0) drawSelection();
		drawCameraFrame();
		refreshInfo();
	}

	function refreshInfo():Void
	{
		infoText.text = (mode == 1 ? "Mundo fijo - camara " : "Vista de la camara ") + (camIdx + 1) + "/" + camCount() + (dirty ? "   * sin guardar" : "") + (mode == 0 && (multiMode || selectedList().length > 1) ? "   [" + selectedList().length + " elegidos" + (multiMode ? ", MULTI" : "") + "]" : "") + (mode == 0 && sel >= 0 && tCount() > 1 ? "   (posicion " + tIdx + " de " + tCount() + ")" : "")
			+ (mode == 0 ? "\nClick y arrastra para mover. Rueda: escala. Flechas: mover (SHIFT x10, CTRL fino). Arrastra los botones de la lista para cambiar las capas."
				: "\nPestaña Camaras (mundo fijo): arrastra el marco rojo o toca el mundo para mover la camara, rueda: zoom, flechas: mover (SHIFT x10, CTRL fino).");
	}

	override public function destroy():Void
	{
		SaveWarning.saveFunc = null;
		views = [];
		super.destroy();
	}
}
