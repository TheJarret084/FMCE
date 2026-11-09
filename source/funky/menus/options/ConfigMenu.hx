package funky.menus.options;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import funky.core.ClientPrefs;
import funky.core.CoolUtil;
import funky.core.KeyBinds;
import funky.core.Paths;
import funky.core.NavPad;
import funky.core.TouchNav;
import funky.menus.options.ConfigItem;

import funky.core.Log;
import funkin.backend.utils.TranslationUtil as TU;

/** Una fila visible: texto + (checkbox | numero | slider). Se posiciona desde ConfigMenu. */
private class Row extends FlxGroup
{
	public static inline var HEIGHT:Float = 74;
	public static inline var BAR_W:Int = 260;
	public static inline var ICON:Int = 64;

	public var item:ConfigItem;
	public var label:FlxText;
	public var value:FlxText;
	public var box:FlxSprite;
	public var barBack:FlxSprite;
	public var barFill:FlxSprite;
	public var icon:AvatarLoader;
	public var x:Float = 0;
	public var y:Float = 0;
	public var baseX:Float = 0;
	public var right:Float = 0;
	public var valueMid:Float = 0;

	var boxAtlas:Bool = false;
	var lastChecked:Null<Bool> = null;
	var dead:Bool = false;

	public function new(item:ConfigItem, font:Null<String>)
	{
		super();
		this.item = item;
		if (item.kind == SEPARATOR) return;

		label = new FlxText(0, 0, 0, item.label + item.suffix, 40);
		label.setFormat(font, 40, item.color, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 2;
		add(label);

		if (item.hasIcon)
		{
			icon = new AvatarLoader(item.iconUrl, item.iconAsset, ICON);
			add(icon);
		}

		switch (item.kind)
		{
			case CHECK:
				box = new FlxSprite();
				var frames = Paths.getFrames("menus/options/checkboxThingie");
				if (frames != null)
				{
					box.frames = frames;
					box.animation.addByPrefix("off", "Check Box unselected0", 24, false);
					box.animation.addByPrefix("on", "Check Box Selected Static0", 24, false);
					boxAtlas = box.animation.getByName("off") != null && box.animation.getByName("on") != null;
				}
				if (boxAtlas)
				{
					box.scale.set(0.5, 0.5);
					box.updateHitbox();
				}
				else
					box.makeGraphic(40, 40, FlxColor.WHITE);
				add(box);
			case NUMBER:
				value = makeValue(font);
			case SLIDER:
				barBack = new FlxSprite().makeGraphic(BAR_W, 10, 0xFF3A3A44);
				barFill = new FlxSprite().makeGraphic(BAR_W, 10, 0xFF4DC3FF);
				barFill.origin.set(0, 5);
				add(barBack);
				add(barFill);
				value = makeValue(font);
			default:
		}
		refresh();
	}

	function makeValue(font:Null<String>):FlxText
	{
		var text = new FlxText(0, 0, 0, "", 40);
		text.setFormat(font, 40, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.borderSize = 2;
		add(text);
		return text;
	}

	override public function destroy():Void
	{
		dead = true;
		super.destroy();
	}

	public function rowHeight():Float
		return item.kind == SEPARATOR ? 36 : HEIGHT;

	public function refresh():Void
	{
		if (item.kind == SEPARATOR) return;
		if (item.dynamicLabel != null) label.text = item.dynamicLabel() + item.suffix;

		switch (item.kind)
		{
			case CHECK:
				var on = item.getBool();
				if (lastChecked != on)
				{
					lastChecked = on;
					if (boxAtlas) box.animation.play(on ? "on" : "off", true);
					else box.color = on ? 0xFF35B162 : 0xFF55555F;
				}
			case NUMBER:
				value.text = item.valueText();
			case SLIDER:
				value.text = item.valueText();
				var span = item.max - item.min;
				var ratio = span <= 0 ? 0 : (item.getNum() - item.min) / span;
				barFill.scale.x = Math.max(0.001, Math.min(1, ratio));
			default:
		}
	}

	public function place(px:Float, py:Float):Void
	{
		x = px;
		y = py;
		if (item.kind == SEPARATOR) return;

		var lx = item.hasIcon ? px + ICON + 16 : px;
		label.setPosition(lx, py);
		if (icon != null) icon.setPosition(px, py + (label.height - ICON) / 2);
		var rx = lx + label.width + 28;
		right = lx + label.width;

		switch (item.kind)
		{
			case CHECK:
				box.setPosition(rx, py + (label.height - box.height) / 2);
				right = rx + box.width;
			case NUMBER:
				value.setPosition(rx, py);
				right = rx + value.width;
				valueMid = rx + value.width / 2;
			case SLIDER:
				barBack.setPosition(rx, py + label.height / 2 - 5);
				barFill.setPosition(rx, py + label.height / 2 - 5);
				value.setPosition(rx + BAR_W + 16, py);
				right = value.x + value.width;
				valueMid = rx + BAR_W / 2;
			default:
		}
	}

	public function setAlpha(a:Float):Void
	{
		var sprites:Array<FlxSprite> = [label, value, box, barBack, barFill, icon];
		for (sprite in sprites)
			if (sprite != null) sprite.alpha = a;
	}
}

/** Menu de opciones estilo Codename (TreeMenu) con fila centrada. */
class ConfigMenu extends FlxGroup
{
	static var font:Null<String> = null;
	static var fontLoaded:Bool = false;

	public var onExit:Void->Void;
	/** Avisa del fondo de la pantalla visible (null = el de por defecto); solo lo usan los creditos. */
	public var onBackgroundChange:String->Void;
	/** Abre un substate encima del host correcto (ConfigState o el ConfigSubState de la pausa). */
	public var openSubState:FlxSubState->Void;
	/** Reconstruye la raiz (se usa al cambiar de idioma). */
	public var rootFactory:Void->ConfigScreen;
	public var stack:Array<ConfigScreen> = [];

	var rows:Array<Row> = [];
	var rowLayer:FlxGroup;
	var headBG:FlxSprite;
	var titleText:FlxText;
	var descText:FlxText;
	var backButton:FlxObject;
	var navPad:Null<NavPad>;

	var enterT:Float = 1;
	var enterDir:Float = 0;
	var holdTime:Float = 0;
	var repeatTime:Float = 0;
	var exiting:Bool = false;
	var capture:Null<String->Void>;
	var captureCancel:Null<Void->Void>;

	public function new()
	{
		super();
		if (!fontLoaded)
		{
			fontLoaded = true;
			font = Paths.fontPath("PhantomMuff.ttf");
		}

		rowLayer = new FlxGroup();
		add(rowLayer);

		headBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		headBG.alpha = 0.45;
		add(headBG);

		titleText = new FlxText(14, 8, FlxG.width - 28, "", 32);
		titleText.setFormat(font, 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 1.5;
		add(titleText);

		descText = new FlxText(14, 0, FlxG.width - 28, "", 18);
		descText.setFormat(font, 18, 0xFFD8D8E0, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(descText);

		// Boton ATRAS en su lugar de siempre (arriba a la izquierda, igual que en los demas menus), con mouse o dedo.
		backButton = BackButton.place();
		add(backButton);

		// El titulo y la descripcion arrancan despues del boton, no pasan por debajo.
		titleText.x = descText.x = BackButton.WIDTH;
		titleText.fieldWidth = descText.fieldWidth = FlxG.width - BackButton.WIDTH - 14;

		if (TouchNav.MOBILE)
		{
			navPad = NavPad.make(() -> navigate(-1), () -> navigate(1));
			if (navPad != null) add(navPad);
		}
	}

	/** Botones arriba/abajo del movil: solo cuando el menu acepta input (no al salir, ni capturando una tecla). */
	function navigate(dir:Int):Void
	{
		if (exiting || capture != null || enterT < 0.35) return;
		var screen = top();
		if (screen == null || screen.items.length == 0) return;
		move(dir);
	}

	public function setRoot(screen:ConfigScreen):Void
	{
		stack = [screen];
		build(screen, 0);
	}

	/** Guarda como se construye la raiz y la muestra. */
	public function setRootFactory(factory:Void->ConfigScreen):Void
	{
		rootFactory = factory;
		setRoot(factory());
	}

	/** Vuelve a la raiz para refrescar titulos, descripciones y filas (cambio de idioma). */
	public function reloadRoot():Void
	{
		if (rootFactory == null) return;
		stack = [rootFactory()];
		build(stack[0], 0);
		applyBackground();
	}

	public function push(screen:ConfigScreen):Void
	{
		stack.push(screen);
		build(screen, 1);
		applyBackground();
	}

	function applyBackground():Void
	{
		if (onBackgroundChange == null) return;
		var screen = top();
		onBackgroundChange(screen != null ? screen.background : null);
	}

	public function isCapturing():Bool
		return capture != null;

	/** Espera la proxima tecla (ESC cancela) y la entrega como texto de FlxKey ("A", "LEFT"...). */
	public function captureKey(onKey:String->Void, ?onCancel:Void->Void):Void
	{
		capture = onKey;
		captureCancel = onCancel;
	}

	function top():Null<ConfigScreen>
		return stack.length > 0 ? stack[stack.length - 1] : null;

	function build(screen:ConfigScreen, dir:Int):Void
	{
		for (row in rows)
		{
			rowLayer.remove(row, true);
			row.destroy();
		}
		rows = [];
		for (item in screen.items)
		{
			var row = new Row(item, font);
			rows.push(row);
			rowLayer.add(row);
		}

		if (screen.selected < 0 || screen.selected >= screen.items.length) screen.selected = 0;
		var guard = 0;
		while (screen.items.length > 0 && screen.items[screen.selected].kind == SEPARATOR && guard++ < screen.items.length)
			screen.selected = (screen.selected + 1) % screen.items.length;

		enterDir = dir;
		enterT = dir == 0 ? 1 : 0;
		layout(true, 0);
		updateHeader();
	}

	function updateHeader():Void
	{
		var screen = top();
		if (screen == null) return;

		titleText.text = [for (s in stack) s.title].join(" > ");
		var text = screen.desc;
		var item = screen.items.length > 0 ? screen.items[screen.selected] : null;
		if (item != null && item.desc != null && item.desc != "") text += "\n" + item.desc;
		descText.text = text;
		descText.y = titleText.y + titleText.height + 2;

		// La barra de arriba cubre tambien el boton ATRAS (esquina izquierda), para que las filas no pasen por debajo de el.
		headBG.scale.set(FlxG.width, Math.max(descText.y + descText.height + 8, BackButton.Y + BackButton.SIZE + 4));
		headBG.updateHitbox();
	}

	function layout(snap:Bool, elapsed:Float):Void
	{
		var screen = top();
		if (screen == null || rows.length == 0) return;

		var n = rows.length;
		var s = screen.selected;
		var ys:Array<Float> = [for (_ in 0...n) 0.0];
		var cy = FlxG.height * 0.58;
		var hs = rows[s].rowHeight();

		ys[s] = cy - hs / 2;
		var y = cy + hs / 2;
		for (i in (s + 1)...n)
		{
			ys[i] = y;
			y += rows[i].rowHeight();
		}
		y = cy - hs / 2;
		var j = s;
		while (j-- > 0)
		{
			y -= rows[j].rowHeight();
			ys[j] = y;
		}

		var ease = FlxEase.cubeOut(enterT);
		var offX = (1 - ease) * enterDir * 260;
		var r = snap ? 1.0 : 1 - Math.exp(-elapsed * 16);

		for (i in 0...n)
		{
			var row = rows[i];
			var targetX = 90 - Math.pow(Math.abs(i - s), 1.6) * 12;
			row.baseX = FlxMath.lerp(snap ? targetX : row.baseX, targetX, r);
			var ny = FlxMath.lerp(snap ? ys[i] : row.y, ys[i], r);
			row.place(row.baseX + offX, ny);
			row.visible = ny > -Row.HEIGHT && ny < FlxG.height;
			row.setAlpha(Math.max(0, (i == s ? 1.0 : 0.6) * ease));
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (enterT < 1) enterT = Math.min(1, enterT + elapsed / 0.28);
		for (row in rows) row.refresh();
		layout(false, elapsed);

		if (exiting) return;
		if (capture != null)
		{
			updateCapture();
			return;
		}
		if (enterT < 0.35) return;
		input(elapsed);
	}

	function updateCapture():Void
	{
		if (FlxG.keys.justPressed.ESCAPE)
		{
			var cancel = captureCancel;
			capture = null;
			captureCancel = null;
			if (cancel != null) cancel();
			return;
		}
		var key:FlxKey = FlxG.keys.firstJustPressed();
		if (key != FlxKey.NONE)
		{
			var done = capture;
			capture = null;
			captureCancel = null;
			CoolUtil.playMenuSound("confirm", 0.7);
			done(key.toString());
		}
	}

	function input(elapsed:Float):Void
	{
		var screen = top();
		if (screen == null) return;

		// ATRAS: la tecla o el boton de arriba a la izquierda (mouse o dedo).
		if (KeyBinds.justPressed(KeyBinds.BACK) || BackButton.clicked(backButton))
		{
			back();
			return;
		}
		if (screen.items.length == 0) return;

		if (KeyBinds.justPressed(KeyBinds.UP)) move(-1);
		if (KeyBinds.justPressed(KeyBinds.DOWN)) move(1);

		var item = screen.items[screen.selected];
		var numeric = item.kind == NUMBER || item.kind == SLIDER;
		var held = (KeyBinds.pressed(KeyBinds.LEFT) ? -1 : 0) + (KeyBinds.pressed(KeyBinds.RIGHT) ? 1 : 0);
		var pressed = (KeyBinds.justPressed(KeyBinds.LEFT) ? -1 : 0) + (KeyBinds.justPressed(KeyBinds.RIGHT) ? 1 : 0);
		if (pressed != 0)
		{
			holdTime = 0;
			repeatTime = 0;
			adjust(item, pressed);
		}
		else if (held != 0 && numeric)
		{
			holdTime += elapsed;
			if (holdTime > 0.4)
			{
				repeatTime += elapsed;
				if (repeatTime >= 0.06)
				{
					repeatTime = 0;
					adjust(item, held);
				}
			}
		}
		else
		{
			holdTime = 0;
			repeatTime = 0;
		}

		if (KeyBinds.justPressed(KeyBinds.ACCEPT)) activate(item);

		var tap = TouchNav.pressPoint();
		if (tap != null && navPad != null && navPad.covers(tap.x, tap.y))
			tap.put();
		else if (tap != null)
		{
			handleTap(tap, screen);
			tap.put();
		}
	}

	function handleTap(p:FlxPoint, screen:ConfigScreen):Void
	{
		for (i in 0...rows.length)
		{
			var row = rows[i];
			if (row.item.kind == SEPARATOR || !row.visible) continue;
			if (!inside(p, row.x, row.label.y, row.right - row.x, row.label.height, 16)) continue;

			if (i != screen.selected)
				select(i);
			else if ((row.item.kind == NUMBER || row.item.kind == SLIDER))
			{
				// Tocar la mitad izquierda del valor baja, la derecha sube. Tocar el nombre no hace nada.
				if (p.x >= row.label.x + row.label.width) adjust(row.item, p.x < row.valueMid ? -1 : 1);
			}
			else
				activate(row.item);
			return;
		}
	}

	static inline function inside(p:FlxPoint, x:Float, y:Float, w:Float, h:Float, pad:Float):Bool
		return p.x >= x - pad && p.x <= x + w + pad && p.y >= y - pad && p.y <= y + h + pad;

	function move(dir:Int):Void
	{
		var screen = top();
		var n = screen.items.length;
		var i = screen.selected;
		var guard = 0;
		do
		{
			i = (i + dir + n) % n;
			guard++;
		}
		while (screen.items[i].kind == SEPARATOR && guard <= n);
		select(i);
	}

	function select(i:Int):Void
	{
		var screen = top();
		if (screen.selected == i) return;
		screen.selected = i;
		CoolUtil.playMenuSound("scroll", 0.6);
		updateHeader();
	}

	function adjust(item:ConfigItem, dir:Int):Void
	{
		if (item == null || dir == 0 || item.getNum == null) return;
		if (item.kind != NUMBER && item.kind != SLIDER) return;

		var before = item.getNum();
		var v = Math.round((before + dir * item.step) * 1000) / 1000;
		v = Math.max(item.min, Math.min(item.max, v));
		if (v == before) return;

		item.setNum(v);
		CoolUtil.playMenuSound("scroll", 0.4);
	}

	function activate(item:ConfigItem):Void
	{
		if (item == null) return;
		switch (item.kind)
		{
			case ACTION:
				CoolUtil.playMenuSound("confirm", 0.7);
				if (item.onSelect != null) item.onSelect();
			case CHECK:
				item.setBool(!item.getBool());
				CoolUtil.playMenuSound("scroll", 0.7);
			default:
		}
	}

	function back():Void
	{
		CoolUtil.playMenuSound("cancel", 0.7);
		if (stack.length > 1)
		{
			stack.pop();
			build(top(), -1);
			applyBackground();
		}
		else
			exitMenu();
	}

	/** Guarda las preferencias y avisa al host (state o substate) para que cierre. */
	public function exitMenu():Void
	{
		if (exiting) return;
		exiting = true;
		ClientPrefs.save();
		if (onExit != null) onExit();
	}
}
