package funky.core;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

using StringTools;

/** Animaciones de una direccion (izq/abajo/arriba/der) dentro del atlas de un skin. */
typedef NoteSkinLane =
{
	var note:String;
	var hold:String;
	var holdEnd:String;
	var receptor:String;
	var press:String;
	var confirm:String;
	/** Splash al acertar un SICK. Si el atlas no tiene esa animacion, el splash usa la flecha de la nota (`note`). */
	var splash:String;
}

/** Colores de una direccion (igual para `rgb` que para `tint`). */
typedef NoteSkinColor =
{
	var idle:Null<Int>;
	var pressed:Null<Int>;
	var rest:Null<Int>;
}

/** Formas de colorear las notas de un skin (sparrow, rgb, tint). */
enum abstract NoteSkinType(String) to String
{
	var SPARROW = "sparrow";
	var RGB = "rgb";
	var TINT = "tint";

	public static function parse(value:Null<String>, fallback:NoteSkinType):NoteSkinType
	{
		if (value == null) return fallback;
		return switch (value.trim().toLowerCase())
		{
			case "sparrow" | "full" | "painted": SPARROW;
			case "rgb" | "mask": RGB;
			case "tint" | "color" | "colored" | "flxcolor": TINT;
			default: fallback;
		}
	}
}

/** Skin de notas configurable con un `noteSkin.xml` (con DOCTYPE, como los XML de Codename). */
class NoteSkin
{
	public static inline var DEFAULT_ID:String = "default";

	/** Carpeta de los skins dentro de addons/. */
	static inline var ROOT:String = "noteskins/";
	static var DIRS:Array<String> = ["left", "down", "up", "right"];

	/** Siempre aparecen en la lista, aunque el escaneo de assets falle. */
	static var BUILTINS:Array<String> = [DEFAULT_ID, "codename", "fmm"];

	static var cache:Map<String, NoteSkin> = new Map();
	static var hooked:Bool = false;

	/**
	 * El Flixel de Codename, en cada cambio de estado, marca TODA la cache de imagenes como destruible (tambien las `persist`)
	 * y solo salva las que se vuelven a pedir con `FlxG.bitmap.get(key)` durante el estado nuevo. Un skin que se queda con sus
	 * frames guardados nunca la vuelve a pedir: su atlas se destruye y las notas salen como cuadros negros o invisibles.
	 * Por eso al cambiar de estado se sueltan los frames: la proxima nota / receptor los vuelve a pedir (y los rescata).
	 */
	static function hook():Void
	{
		if (hooked) return;
		hooked = true;
		FlxG.signals.preStateSwitch.add(releaseFrames);
	}

	static function releaseFrames():Void
	{
		for (skin in cache)
		{
			skin.framesCache = null;
			skin.framesTried = false;
			skin.splashFramesCache = null;
			skin.splashTried = false;
		}
	}

	public var id(default, null):String;
	public var name:String;
	public var author:String;
	/** Nombre del atlas sin extension, dentro de addons/noteskins/<id>/images/. */
	public var atlas:String;
	public var type:NoteSkinType = RGB;

	/** true si el atlas es una mascara RGB (se pinta con NoteRGBShader). */
	public var rgb(get, never):Bool;

	inline function get_rgb():Bool
		return type == RGB;
	public var holdAlpha:Float = 0.65;
	public var anims:Array<NoteSkinLane>;
	public var colors:Array<Null<NoteSkinColor>>;
	/** Color de reposo de los receptores para todo el skin (`<colors rest="#828282">`), si ninguna lane trae el suyo. */
	public var restColor:Null<Int> = null;
	/** Paleta multikey (9 colores, mismo orden que noteColors de settings.xml). */
	public var palette:Array<Null<NoteSkinColor>>;

	/**
	 * Escala (multiplo de la base) que toma el receptor al apretarse / confirmar; al soltar vuelve a la base. 1 = no hace nada.
	 * `<pressedScale value="1.15"/>`. Si el skin es `tint` y no lo define, usa `DEFAULT_TINT_PRESSED_SCALE` (su confirm reusa la flecha, asi que
	 * sin esto no se notaria el golpe); con `value="1"` se apaga.
	 */
	public var pressedScale:Float = 1;
	public static inline var DEFAULT_TINT_PRESSED_SCALE:Float = 1.15;

	/**
	 * Ajustes del splash (`<splash scale="1" alpha="0.8" fps="24"/>`, todo opcional). El splash usa el MISMO sistema que las notas:
	 * el atlas del skin, la animacion `splash` de cada `<lane>` y el mismo coloreado (rgb / tint / sparrow).
	 */
	public var splashScale:Float = 1;
	/**
	 * Atlas aparte del splash (nombre sin extension, en images/ del skin): `<splash atlas="NOTE_splash"/>`. Sin declarar busca `splash.png/.xml`
	 * en el skin; si no hay ninguno, el splash usa el atlas principal del skin.
	 */
	public var splashAtlas:String = "splash";
	var splashAtlasDeclared:Bool = false;
	var splashFramesCache:Null<FlxAtlasFrames>;
	var splashTried:Bool = false;
	public var splashAlpha:Float = 0.8;
	public var splashFps:Int = 24;

	/** Script del skin (`data/noteSkin.hx`), o null si no trae. Ver `NoteSkinScript`. */
	public var script(default, null):Null<NoteSkinScript> = null;

	var framesCache:Null<FlxAtlasFrames>;
	/** Ya se intento cargar el atlas (con o sin exito): si fallo no se vuelve a buscar en cada nota. */
	var framesTried:Bool = false;

	function new(id:String)
	{
		this.id = id;
		name = id;
		author = "";
		atlas = "NOTE_assets";
		anims = defaultAnimations();
		colors = [];
		for (_ in 0...DIRS.length) colors.push(null);
		palette = [];
		for (_ in 0...9) palette.push(null);
	}

	// ───────────────────────────── API publica ─────────────────────────────

	/** Skin guardado en las preferencias (o el default si ya no existe). */
	public static function current():NoteSkin
		return get(ClientPrefs.getNoteSkin());

	/** Carga (con cache) un skin por id. Si no existe o le falta el atlas, cae al default. */
	public static function get(id:String):NoteSkin
	{
		if (id == null || id.length == 0) id = DEFAULT_ID;
		hook();

		var cached = cache.get(id);
		if (cached != null) return cached;

		var skin = load(id);
		if (skin == null || !skin.hasAtlas())
		{
			Log.warn('[NoteSkin] "$id" no esta completo (' + (skin == null ? "falta data/noteSkin.xml" : "falta su atlas " + skin.atlasRel() + ".png/.xml") + ')'
				+ (id != DEFAULT_ID ? ': se usa "default"' : ''));

			if (id != DEFAULT_ID)
			{
				// Se guarda tambien el resultado "cayo al default": si no, cada nota volveria a leer y parsear el XML.
				var replacement = get(DEFAULT_ID);
				cache.set(id, replacement);
				return replacement;
			}
			if (skin == null) skin = fallback();
		}

		cache.set(id, skin);
		return skin;
	}

	/** Ids de skins: los de fabrica + cualquier addon con `noteskins/<id>/data/noteSkin.xml` (externo o de los que trae el build). */
	public static function list():Array<String>
	{
		var out:Array<String> = [];
		for (id in BUILTINS) out.push(id);

		for (id in Addons.folders("noteskins"))
			if (!out.contains(id) && Addons.exists(ROOT + id + "/data/noteSkin.xml")) out.push(id);

		return out;
	}

	public static function displayName(id:String):String
		return get(id).name;

	/** true si el atlas del skin se puede cargar (en su carpeta images/ o, si no, en assets/images/). */
	public function hasAtlas():Bool
		return Addons.exists(atlasRel() + ".png") && Addons.exists(atlasRel() + ".xml") || Paths.framesExists(atlas);

	/** Atlas del skin (null si no existe; Note/Strum caen a un cuadro blanco). */
	public function frames():FlxAtlasFrames
	{
		if (framesCache != null)
		{
			// Si el atlas se destruyo por debajo (cambio de estado, limpieza de memoria), se vuelve a cargar.
			var graphic = framesCache.parent;
			if (graphic != null && !graphic.isDestroyed && graphic.bitmap != null) return framesCache;
			framesCache = null;
			framesTried = false;
		}
		if (framesTried) return null;
		framesTried = true;

		framesCache = Addons.getSparrowAtlas(atlasRel());
		if (framesCache == null && Paths.framesExists(atlas)) framesCache = Paths.getSparrowAtlas(atlas);
		if (framesCache == null)
			Log.error('[NoteSkin] no se pudo cargar el atlas de "$id": ' + atlasRel() + '.png/.xml (en addons/ externo o del build) ni assets/images/$atlas');
		return framesCache;
	}

	/** Atlas del splash (imagen aparte) o null si no hay: entonces el splash sale del atlas principal (`frames()`). */
	public function splashFrames():Null<FlxAtlasFrames>
	{
		if (splashFramesCache != null)
		{
			var graphic = splashFramesCache.parent;
			if (graphic != null && !graphic.isDestroyed && graphic.bitmap != null) return splashFramesCache;
			splashFramesCache = null;
			splashTried = false;
		}
		if (splashTried) return null;
		splashTried = true;

		var name = haxe.io.Path.withoutDirectory(splashAtlas);
		splashFramesCache = Addons.getSparrowAtlas(ROOT + id + "/images/" + name);
		if (splashFramesCache == null && splashAtlasDeclared && Paths.framesExists(splashAtlas)) splashFramesCache = Paths.getSparrowAtlas(splashAtlas);
		if (splashFramesCache == null && splashAtlasDeclared)
			Log.warn('[NoteSkin] no se pudo cargar el atlas de splash "$splashAtlas" de "$id": el splash usa el atlas principal');
		return splashFramesCache;
	}

	/** `noteskins/<id>/images/<atlas>` (ruta relativa a addons/, sin extension). */
	function atlasRel():String
		return ROOT + id + "/images/" + atlas;

	/** Codigo de un shader propio del skin (`noteskins/<id>/shaders/<nombre>.frag`), o null si no existe. */
	public function shaderSource(name:String):Null<String>
		return Addons.getText(ROOT + id + "/shaders/" + name + ".frag");

	/**
	 * Llama un callback del script del skin. `alias` es el nombre viejo/alternativo (ej. `onNote` para `onNoteCreate`);
	 * si el script define los dos se llaman los dos, como en los scripts de nivel.
	 */
	public function notify(primary:String, ?alias:String, ?args:Array<Dynamic>):Void
	{
		if (script == null) return;
		script.call(primary, args);
		if (alias != null && alias != primary) script.call(alias, args);
	}

	/** Nombre de animacion para `note` / `hold` / `holdEnd` / `receptor` / `press` / `confirm` / `splash`. */
	public function animFor(state:String, lane:Int):String
	{
		var a = anims[dirForLane(lane)];
		if (a == null) a = anims[0];

		return switch (state)
		{
			case "hold": a.hold;
			case "holdEnd": a.holdEnd;
			case "receptor": a.receptor;
			case "press": a.press;
			case "confirm": a.confirm;
			case "splash": a.splash;
			default: a.note;
		}
	}

	/** Entrada de color del skin para la lane (paleta multikey primero, luego por direccion), o null. */
	function entryFor(lane:Int, ?laneCount:Int):Null<NoteSkinColor>
	{
		var total = laneCount == null ? 4 : Std.int(Math.max(1, Math.min(9, laneCount)));
		var safeLane = lane < 0 ? 0 : (lane >= total ? total - 1 : lane);

		// Paleta multikey (mismo orden que noteColors de settings.xml).
		var entry = palette[ClientPrefs.colorIndexForLane(safeLane, total)];
		return entry != null ? entry : colors[dirForLane(lane)];
	}

	/** Color del skin para la lane, o null si el skin no define colores (se usan los de settings.xml). */
	public function colorFor(lane:Int, pressed:Bool = false, ?laneCount:Int):Null<Int>
	{
		var entry = entryFor(lane, laneCount);
		if (entry == null) return null;
		// `pressed` sin definir = el de `idle`; `idle` sin definir = null (cae a settings.xml).
		return pressed ? (entry.pressed != null ? entry.pressed : entry.idle) : entry.idle;
	}

	/** Color de reposo del receptor para `tint`: el de la lane, el del skin o `strumDefaultColor`. */
	public function restTintFor(lane:Int, ?laneCount:Int):Int
	{
		var entry = entryFor(lane, laneCount);
		if (entry != null && entry.rest != null) return 0xFF000000 | entry.rest;
		if (restColor != null) return 0xFF000000 | restColor;
		return ClientPrefs.strumIdleColor();
	}

	/**
	 * Los tres colores que NoteRGBShader mezcla por canal. null = no usar shader (atlas ya pintado).
	 */
	public function rgbFor(lane:Int, pressed:Bool = false, ?laneCount:Int):Null<Array<Int>>
	{
		if (type != RGB) return null;

		var color = colorFor(lane, pressed, laneCount);
		return color == null
			? ClientPrefs.noteRgbForLane(lane, pressed, laneCount)
			: ClientPrefs.rgbFromBase(color);
	}

	/** Color (FlxColor) para el tipo `tint`: el del skin o, si no define, el de settings.xml. null en los otros tipos. */
	public function tintFor(lane:Int, pressed:Bool = false, ?laneCount:Int):Null<Int>
	{
		if (type != TINT) return null;

		var color = colorFor(lane, pressed, laneCount);
		return color != null ? (0xFF000000 | color) : (0xFF000000 | ClientPrefs.noteColorForLane(lane, pressed, laneCount));
	}

	/** Pinta un sprite (nota o receptor) segun el tipo del skin: shader RGB, tinte, o nada (sparrow). */
	public function applyTo(sprite:FlxSprite, lane:Int, pressed:Bool = false, ?laneCount:Int):Void
	{
		switch (type)
		{
			case RGB:
				var colors = rgbFor(lane, pressed, laneCount);
				sprite.shader = colors == null ? null : NoteRGBShader.forColors(colors);
				sprite.color = 0xFFFFFFFF;
			case TINT:
				sprite.shader = null;
				var tint = tintFor(lane, pressed, laneCount);
				sprite.color = tint == null ? 0xFFFFFFFF : tint;
			case SPARROW:
				sprite.shader = null;
				sprite.color = 0xFFFFFFFF;
		}
	}

	/** Se llama al cambiar de nivel/skin para no quedarse con texturas viejas. */
	public static function clearCache():Void
	{
		cache.clear();
	}

	// ───────────────────────────── Carga del XML ─────────────────────────────

	static function load(id:String):Null<NoteSkin>
	{
		var raw = Addons.getText(ROOT + id + "/data/noteSkin.xml");
		if (raw == null) return null;

		try
		{
			var root = Xml.parse(raw).firstElement();
			if (root == null || root.nodeName != "noteSkin") return null;

			var skin = new NoteSkin(id);
			skin.name = attr(root, "name", id);
			skin.author = attr(root, "author", "");
			skin.atlas = attr(root, "atlas", skin.atlas);

			var atlasNode = firstElement(root, "atlas");
			if (atlasNode != null) skin.atlas = attr(atlasNode, "path", skin.atlas);
			// El atlas vive en images/ del propio skin: si el XML trae una ruta vieja (game/notes/...), se queda con el nombre.
			skin.atlas = haxe.io.Path.withoutDirectory(skin.atlas);

			// type="sparrow|rgb|tint". Sin type: <rgb enabled="..."/> (formato viejo); sin nada, rgb.
			var rgbNode = firstElement(root, "rgb");
			var legacy:NoteSkinType = rgbNode != null && !parseBool(attr(rgbNode, "enabled", "true"), true) ? SPARROW : RGB;
			skin.type = NoteSkinType.parse(attr(root, "type", null), legacy);

			skin.pressedScale = skin.type == TINT ? DEFAULT_TINT_PRESSED_SCALE : 1;
			var pressedNode = firstElement(root, "pressedScale");
			if (pressedNode != null)
				skin.pressedScale = Math.max(0.1, parseFloat(attr(pressedNode, "value", null), skin.pressedScale));

			var splashNode = firstElement(root, "splash");
			if (splashNode != null) parseSplash(skin, splashNode);

			var holdNode = firstElement(root, "holdAlpha");
			if (holdNode != null) skin.holdAlpha = parseFloat(attr(holdNode, "value", "0.65"), 0.65);

			var animsNode = firstElement(root, "animations");
			if (animsNode != null) parseAnimations(skin, animsNode);

			var colorsNode = firstElement(root, "colors");
			if (colorsNode != null) parseColors(skin, colorsNode);

			skin.loadScript();
			return skin;
		}
		catch (e:Dynamic)
		{
			Log.error('[NoteSkin] no se pudo leer $id/data/noteSkin.xml: ' + Std.string(e));
			return null;
		}
	}

	/**
	 * Carga el script del skin (`data/noteSkin.hx`), si trae. Un archivo vacio se ignora, asi que no hace falta
	 * borrarlo para que el skin funcione.
	 */
	function loadScript():Void
	{
		var source = Addons.getText(ROOT + id + "/data/noteSkin.hx");
		if (source == null) source = Addons.getText(ROOT + id + "/data/noteSkin.hscript");
		if (source == null || StringTools.trim(source).length == 0) return;

		try
		{
			script = new NoteSkinScript("noteSkin.hx", source, this);
			script.load();
		}
		catch (e:Dynamic)
		{
			// Un script roto no debe dejar sin skin al juego.
			script = null;
			Log.error('[NoteSkin] script de $id: ' + Std.string(e));
		}
	}

	static function parseAnimations(skin:NoteSkin, node:Xml):Void
	{
		for (lane in node.elementsNamed("lane"))
		{
			var idx = dirIndex(attr(lane, "dir", attr(lane, "index", null)));
			if (idx < 0) continue;

			var base = skin.anims[idx];
			skin.anims[idx] = {
				note: attr(lane, "note", base.note),
				hold: attr(lane, "hold", base.hold),
				holdEnd: attr(lane, "holdEnd", base.holdEnd),
				receptor: attr(lane, "receptor", base.receptor),
				press: attr(lane, "press", base.press),
				confirm: attr(lane, "confirm", base.confirm),
				splash: attr(lane, "splash", base.splash)
			};
		}
	}

	static function parseSplash(skin:NoteSkin, node:Xml):Void
	{
		var atlas = attr(node, "atlas", attr(node, "path", null));
		if (atlas != null)
		{
			skin.splashAtlas = atlas;
			skin.splashAtlasDeclared = true;
		}
		skin.splashScale = Math.max(0.05, parseFloat(attr(node, "scale", null), 1));
		skin.splashAlpha = Math.max(0, Math.min(1, parseFloat(attr(node, "alpha", null), 0.8)));
		skin.splashFps = Std.int(Math.max(1, parseFloat(attr(node, "fps", null), 24)));
	}

	static function parseColors(skin:NoteSkin, node:Xml):Void
	{
		var globalRest = attr(node, "rest", null);
		if (globalRest != null)
		{
			skin.restColor = parseColorOpt(globalRest);
		}

		for (lane in node.elementsNamed("lane"))
		{
			// Todo es opcional: idle (nota), pressed (apretado) y rest (receptor en reposo, solo `tint`).
			var idleAttr = attr(lane, "idle", attr(lane, "color", null));
			var pressedAttr = attr(lane, "pressed", null);
			var restAttr = attr(lane, "rest", attr(lane, "strum", null));
			if (idleAttr == null && pressedAttr == null && restAttr == null) continue;

			var entry:NoteSkinColor = {
				idle: idleAttr == null ? null : parseColorOpt(idleAttr),
				pressed: pressedAttr == null ? null : parseColorOpt(pressedAttr),
				rest: restAttr == null ? null : parseColorOpt(restAttr)
			};

			// <lane dir="left"> = color por direccion (4K / skins simples).
			var dir = attr(lane, "dir", null);
			if (dir != null)
			{
				var idx = dirIndex(dir);
				if (idx >= 0) skin.colors[idx] = entry;
				continue;
			}

			// <lane index="0"> = indice de la paleta multikey (0..8, como noteColors).
			var index = attr(lane, "index", null);
			if (index != null)
			{
				var idx = Std.parseInt(index);
				if (idx != null && idx >= 0 && idx < skin.palette.length)
					skin.palette[idx] = entry;
			}
		}
	}

	/**
	 * Como `parseColor`, pero devuelve null si el texto no es un color. No se puede usar `-1` de centinela: un color
	 * opaco (0xFFRRGGBB) ya es negativo como Int de 32 bits.
	 */
	static function parseColorOpt(value:String):Null<Int>
	{
		var s = StringTools.trim(value);
		if (s.startsWith("#")) s = s.substr(1);
		else if (s.startsWith("0x") || s.startsWith("0X")) s = s.substr(2);
		if (s.length == 0) return null;

		var n = Std.parseInt("0x" + s);
		return n == null ? null : (s.length <= 6 ? (0xFF000000 | n) : n);
	}

	// ───────────────────────────── helpers ─────────────────────────────

	static function defaultAnimations():Array<NoteSkinLane>
	{
		var out:Array<NoteSkinLane> = [];
		for (dir in DIRS)
			out.push({
				note: dir + " note",
				hold: dir + " hold piece",
				holdEnd: dir + " hold tail",
				receptor: dir + " receptor",
				press: dir + " press",
				confirm: dir + " confirm",
				splash: dir + " splash"
			});
		return out;
	}

	static function fallback():NoteSkin
	{
		var skin = new NoteSkin(DEFAULT_ID);
		skin.name = "Default";
		skin.atlas = "NOTE_assets";
		return skin;
	}

	static inline function dirForLane(lane:Int):Int
	{
		var i = lane % DIRS.length;
		return i < 0 ? 0 : i;
	}

	static function dirIndex(value:Null<String>):Int
	{
		if (value == null) return -1;

		var v = value.toLowerCase();
		for (i in 0...DIRS.length)
			if (DIRS[i] == v) return i;

		var n = Std.parseInt(v);
		if (n != null && n >= 0 && n < DIRS.length) return n;
		return -1;
	}

	static function firstElement(root:Xml, name:String):Null<Xml>
	{
		for (child in root.elements())
			if (child.nodeName == name) return child;
		return null;
	}

	static function attr(node:Xml, name:String, ?fallback:String):Null<String>
	{
		var value = node.get(name);
		if (value == null) return fallback;

		value = StringTools.trim(value);
		return value.length > 0 ? value : fallback;
	}

	static function parseColor(value:String, fallback:Int):Int
	{
		var s = StringTools.trim(value);
		if (s.startsWith("#")) s = s.substr(1);
		else if (s.startsWith("0x") || s.startsWith("0X")) s = s.substr(2);

		if (s.length == 0) return fallback;

		var n = Std.parseInt("0x" + s);
		if (n == null) return fallback;

		// Sin alfa (#RRGGBB) se asume opaco.
		return s.length <= 6 ? (0xFF000000 | n) : n;
	}

	static function parseBool(value:Null<String>, fallback:Bool):Bool
	{
		if (value == null) return fallback;

		var v = value.toLowerCase();
		return v == "true" || v == "1" || v == "yes" || v == "on";
	}

	static function parseFloat(value:Null<String>, fallback:Float):Float
	{
		if (value == null) return fallback;

		var n = Std.parseFloat(value);
		return Math.isNaN(n) ? fallback : n;
	}
}
