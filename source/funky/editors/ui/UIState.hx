package funky.editors.ui;

import openfl.Lib;
import funky.editors.ui.notifications.UIBaseNotification;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import funky.backend.system.framerate.Framerate;
import funky.backend.utils.NativeAPI.CodeCursor;
import funky.editors.ui.UIContextMenu.UIContextMenuCallback;
import funky.editors.ui.UIContextMenu.UIContextMenuOption;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import flixel.system.scaleModes.StageSizeScaleMode;
import openfl.ui.Mouse;
import openfl.ui.MouseCursor;

class UIState extends MusicBeatState {
	public var curContextMenu:UIContextMenu = null;

	public static var state(get, never):UIState;

	public static var fallbackState:UIState = null;

	/**
	 * UIState "sin pantalla": cuando un editor vive como substate (el charter encima del PlayState), FlxG.state no es un UIState.
	 * El substate crea uno, lo deja aqui y lo actualiza el mismo (`tryUpdate`), asi los botones, el foco, el texto y los menus
	 * contextuales funcionan igual que cuando el editor es el state.
	 */
	public static var host:UIState = null;

	/**
	 * Donde se abren los avisos modales (SaveWarning): el substate del editor si hay `host`, si no FlxG.state.
	 */
	public static var hostRoot:flixel.FlxState = null;

	/**
	 * Camara de la interfaz del `host` (FlxG.camera es la del juego, que esta debajo y tiene otro desplazamiento).
	 */
	public static var hostCamera:flixel.FlxCamera = null;

	public static inline function mainCamera():flixel.FlxCamera
		return hostCamera != null ? hostCamera : FlxG.camera;

	/**
	 * Grupo donde se dibujan las notificaciones (por defecto el propio UIState; un `host` usa el de su substate).
	 */
	public var notificationTarget:flixel.group.FlxGroup = null;

	public static inline function root():flixel.FlxState
		return hostRoot != null ? hostRoot : FlxG.state;

	public static inline function isActive():Bool
		return host != null || FlxG.state is UIState;

	private inline static function get_state()
		return host != null ? host : (FlxG.state is UIState ? cast FlxG.state : getFallback());

	static function getFallback():UIState {
		if (fallbackState == null) {
			fallbackState = new UIState();
			fallbackState.__rect = new FlxRect();
			fallbackState.__mousePos = FlxPoint.get();
			FlxG.signals.postUpdate.add(fallbackState.__headlessTick);
			// Sin esto los campos de texto no reciben el teclado en pantallas que no son un UIState (create nunca se llama aqui).
			// Solo actuan si hay un campo enfocado en este UIState, asi que no chocan con un UIState real.
			FlxG.stage.window.onKeyDown.add(fallbackState.onKeyDown);
			FlxG.stage.window.onKeyUp.add(fallbackState.onKeyUp);
			FlxG.stage.window.onTextInput.add(fallbackState.onTextInput);
			FlxG.stage.window.onTextEdit.add(fallbackState.onTextEdit);
		}
		return fallbackState;
	}

	function __headlessTick():Void {

		if (FlxG.state is UIState || host != null) {
			buttonHandler = null;
			hoveredSprite = null;
			return;
		}

		FlxG.mouse.getScreenPosition(mainCamera(), __mousePos);

		if (buttonHandler != null) {
			buttonHandler();
			buttonHandler = null;
		}

		if (FlxG.mouse.justPressed)
			playEditorSound(Flags.DEFAULT_EDITOR_CLICK_SOUND);

		if (FlxG.mouse.justReleased)
			currentFocus = (hoveredSprite is IUIFocusable) ? (cast hoveredSprite) : null;

		// Igual que en tryUpdate: sin esto el teclado no manda texto a los UITextBox cuando la pantalla que los abre no es un UIState
		// (por ejemplo la ventana de nuevo nivel abierta desde el modo avanzado).
		var wantsText = currentFocus != null && (currentFocus is UITextBox);
		if (wantsText != __textInputOn) {
			__textInputOn = wantsText;
			FlxG.stage.window.textInputEnabled = wantsText;
		}

		if (hoveredSprite != null && hoveredSprite.cursor != null)
			NativeAPI.setCursorIcon(hoveredSprite.cursor);
		else
			NativeAPI.setCursorIcon(currentCursor);

		prevHoveredSprite = hoveredSprite;
		hoveredSprite = null;
	}

	public var buttonHandler:Void->Void = null;
	public var hoveredSprite:UISprite = null;

	public var prevHoveredSprite:UISprite = null;
	public var currentFocus:IUIFocusable = null;

	var __textInputOn:Bool = false;

	public var currentCursor:CodeCursor = ARROW;

	public var uiCameras:Array<FlxCamera> = [];

	private var __rect:FlxRect;
	private var __mousePos:FlxPoint;

	static var __point:FlxPoint = new FlxPoint();

	public override function create() {
		__rect = new FlxRect();
		__mousePos = FlxPoint.get();
		super.create();
		Framerate.offset.y = 30;
		FlxG.mouse.visible = true;

		FlxG.stage.window.onKeyDown.add(onKeyDown);
		FlxG.stage.window.onKeyUp.add(onKeyUp);
		FlxG.stage.window.onTextInput.add(onTextInput);
		FlxG.stage.window.onTextEdit.add(onTextEdit);
	}

	private function onKeyDown(e:KeyCode, modifier:KeyModifier) {
		if (currentFocus != null)
			currentFocus.onKeyDown(e, modifier);
	}

	private function onKeyUp(e:KeyCode, modifier:KeyModifier) {
		if (currentFocus != null)
			currentFocus.onKeyUp(e, modifier);
	}

	private function onTextInput(str:String) {
		if (currentFocus != null)
			currentFocus.onTextInput(str);
	}
	private function onTextEdit(str:String, start:Int, end:Int) {
		if (currentFocus != null)
			currentFocus.onTextEdit(str, start, end);
	}

	public function updateButtonHandler(spr:UISprite, buttonHandler:Void->Void) {
		spr.updateSpriteRect();
		updateRectButtonHandler(spr, spr.__rect, buttonHandler);
	}

	public function isOverlapping(spr:UISprite, rect:FlxRect) {
		for(camera in spr.__lastDrawCameras) {
			var pos = FlxG.mouse.getScreenPosition(camera, __point);
			__rect.copyFrom(rect);

			__rect.x = __rect.x - camera.scroll.x * spr.scrollFactor.x;
			__rect.y = __rect.y - camera.scroll.y * spr.scrollFactor.y;

			if (((pos.x > __rect.x) && (pos.x < __rect.x + __rect.width)) && ((pos.y > __rect.y) && (pos.y < __rect.y + __rect.height))) {
				return true;
			}
		}
		return false;
	}

	public function updateRectButtonHandler(spr:UISprite, rect:FlxRect, buttonHandler:Void->Void) {
		if(isOverlapping(spr, rect)) {
			spr.hoveredByChild = true;
			this.hoveredSprite = spr;
			this.buttonHandler = buttonHandler;
		}
	}

	public override function tryUpdate(elapsed:Float) {
		FlxG.mouse.getScreenPosition(mainCamera(), __mousePos);

		super.tryUpdate(elapsed);

		if (buttonHandler != null) {
			buttonHandler();
			buttonHandler = null;
		}

		if (FlxG.mouse.justPressed) {
			playEditorSound(Flags.DEFAULT_EDITOR_CLICK_SOUND);
		}

		if (FlxG.mouse.justReleased)
			currentFocus = (hoveredSprite is IUIFocusable) ? (cast hoveredSprite) : null;

		var keysAllowed = currentFocus != null ? !(currentFocus is UITextBox) : true;
		var wantsText = currentFocus != null && (currentFocus is UITextBox);
		if (wantsText != __textInputOn) {
			__textInputOn = wantsText;
			FlxG.stage.window.textInputEnabled = wantsText;
		}
		FlxG.sound.muteKeys = keysAllowed ? [flixel.input.keyboard.FlxKey.ZERO, flixel.input.keyboard.FlxKey.NUMPADZERO] : null;
		FlxG.sound.volumeUpKeys = keysAllowed ? [flixel.input.keyboard.FlxKey.PLUS, flixel.input.keyboard.FlxKey.NUMPADPLUS] : null;
		FlxG.sound.volumeDownKeys = keysAllowed ? [flixel.input.keyboard.FlxKey.MINUS, flixel.input.keyboard.FlxKey.NUMPADMINUS] : null;

		if (hoveredSprite != null && hoveredSprite.cursor != null) {
			NativeAPI.setCursorIcon(hoveredSprite.cursor);
		} else {
			NativeAPI.setCursorIcon(currentCursor);
		}
		prevHoveredSprite = hoveredSprite;
		hoveredSprite = null;
	}

	public override function destroy() {
		releaseResolutionAware();

		super.destroy();
		__mousePos.put();

		DrawUtil.destroyDrawers();
		WindowUtils.resetAffixes();
		SaveWarning.reset();

		FlxG.stage.window.onKeyDown.remove(onKeyDown);
		FlxG.stage.window.onKeyUp.remove(onKeyUp);
		FlxG.stage.window.onTextInput.remove(onTextInput);
		FlxG.stage.window.onTextEdit.remove(onTextEdit);
		if (__textInputOn) FlxG.stage.window.textInputEnabled = false;
		__textInputOn = false;
	}

	public function closeCurrentContextMenu() {
		playEditorSound(Flags.DEFAULT_EDITOR_WINDOWCLOSE_SOUND);
		if(curContextMenu != null) {
			curContextMenu.close();
			curContextMenu = null;
		}
	}

	public function openContextMenu(options:Array<UIContextMenuOption>, ?callback:UIContextMenuCallback, ?x:Float, ?y:Float, ?w:Int) {
		playEditorSound(Flags.DEFAULT_EDITOR_WINDOWAPPEAR_SOUND);
		var state = FlxG.state;
		while(state.subState != null && !(state._requestSubStateReset && state._requestedSubState == null))
			state = state.subState;

		state.persistentDraw = true;
		state.persistentUpdate = true;

		state.openSubState(curContextMenu = new UIContextMenu(options, callback, x.getDefault(__mousePos.x), y.getDefault(__mousePos.y), w));
		return curContextMenu;
	}

	public function displayNotification(notification:UIBaseNotification) {
		var target:flixel.group.FlxGroup = notificationTarget != null ? notificationTarget : this;
		notification.cameras = uiCameras;
		notification.onRemove = (notif) -> {
			notification.onRemove = null;
			target.remove(notif, true);
		};
		target.add(notification);
		notification.update(0);
		notification.appearAnimation();

	}

	public static var resolutionAware:Bool = false;
	public static var uiScaleMode:UIScaleMode = new UIScaleMode();

	public static function setResolutionAware() {
		if (!resolutionAware) funky.backend.system.Main.scaleMode = FlxG.scaleMode;
		resolutionAware = true;
		FlxG.scaleMode = uiScaleMode;
	}

	/**
	 * Devuelve al juego su resolucion normal (16:9 con barras a los lados) sin cerrar el editor. No hace nada si no estaba activa.
	 */
	public static function releaseResolutionAware():Void {
		if (!resolutionAware) return;
		resolutionAware = false;

		for (camera in FlxG.cameras.list) {
			camera.width = FlxG.initialWidth;
			camera.height = FlxG.initialHeight;
		}
		FlxG.scaleMode = funky.backend.system.Main.scaleMode;
	}

	public static function playEditorSound(path:String) {
		if (!Options.editorSFX) return;
		FlxG.sound.play(Paths.sound(path));
	}
}
