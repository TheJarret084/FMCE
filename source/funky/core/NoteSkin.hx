package funky.core;

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
}

/** Colores RGB de una direccion. `pressed` es el color del receptor/confirm apretado. */
typedef NoteSkinColor =
{
	var idle:Int;
	var pressed:Int;
}

/**
 * Como se colorean las notas de un skin (atributo `type` del `<noteSkin>`):
 * - `sparrow`: atlas completo y ya pintado (flechas de colores, colas, receptores...). Se dibuja tal cual. Ej: Codename.
 * - `rgb`: atlas tipo mascara (rojo = color, verde = brillo, azul = sombra) pintado con NoteRGBShader. Ej: FMCE.
 * - `tint`: atlas claro/gris que se tiñe con un solo color (FlxSprite.color). Ej: Funky Maker: Mobile.
 */
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

/**
 * Skin de notas configurable con un `noteSkin.xml` (con DOCTYPE, como los XML de Codename).
 *
 * Cada skin es un addon (ver `Addons`):
 *   addons/noteskins/<id>/data/noteSkin.xml      <- esta configuracion
 *   addons/noteskins/<id>/images/<atlas>.png/.xml <- el atlas (Sparrow)
 *
 * El `<atlas path="..."/>` es el nombre del atlas SIN extension, dentro de la carpeta images/ del propio skin
 * (un skin queda aislado: copiar su carpeta basta para instalarlo). Si ahi no esta, se busca en assets/images/.
 *
 * El XML dice que atlas usar, como se llaman las animaciones de cada direccion, de que tipo es
 * (`type="sparrow|rgb|tint"`, ver NoteSkinType) y, para rgb / tint, que colores usar (si no, los de settings.xml).
 * Compatibilidad: sin `type`, `<rgb enabled="true"/>` = rgb y `<rgb enabled="false"/>` = sparrow.
 */
class NoteSkin
{
	public static inline var DEFAULT_ID:String = "default";

	/** Carpeta de los skins dentro de addons/. */
	static inline var ROOT:String = "noteskins/";
	static var DIRS:Array<String> = ["left", "down", "up", "right"];

	/** Siempre aparecen en la lista, aunque el escaneo de assets falle. */
	static var BUILTINS:Array<String> = [DEFAULT_ID, "codename", "fmm"];

	static var cache:Map<String, NoteSkin> = new Map();

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
	/** Paleta multikey (9 colores, mismo orden que noteColors de settings.xml). */
	public var palette:Array<Null<NoteSkinColor>>;

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
		if (framesCache != null || framesTried) return framesCache;
		framesTried = true;

		framesCache = Addons.getSparrowAtlas(atlasRel());
		if (framesCache == null && Paths.framesExists(atlas)) framesCache = Paths.getSparrowAtlas(atlas);
		if (framesCache == null)
			Log.error('[NoteSkin] no se pudo cargar el atlas de "$id": ' + atlasRel() + '.png/.xml (en addons/ externo o del build) ni assets/images/$atlas');
		return framesCache;
	}

	/** `noteskins/<id>/images/<atlas>` (ruta relativa a addons/, sin extension). */
	function atlasRel():String
		return ROOT + id + "/images/" + atlas;

	/** Nombre de animacion para `note` / `hold` / `holdEnd` / `receptor` / `press` / `confirm`. */
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
			default: a.note;
		}
	}

	/** Color del skin para la lane, o null si el skin no define colores (se usan los de settings.xml). */
	public function colorFor(lane:Int, pressed:Bool = false, ?laneCount:Int):Null<Int>
	{
		var total = laneCount == null ? 4 : Std.int(Math.max(1, Math.min(9, laneCount)));
		var safeLane = lane < 0 ? 0 : (lane >= total ? total - 1 : lane);

		// Paleta multikey (mismo orden que noteColors de settings.xml).
		var entry = palette[ClientPrefs.colorIndexForLane(safeLane, total)];
		if (entry != null) return pressed ? entry.pressed : entry.idle;

		// Colores por direccion (4K / skins simples).
		var color = colors[dirForLane(lane)];
		if (color == null) return null;
		return pressed ? color.pressed : color.idle;
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

			var holdNode = firstElement(root, "holdAlpha");
			if (holdNode != null) skin.holdAlpha = parseFloat(attr(holdNode, "value", "0.65"), 0.65);

			var animsNode = firstElement(root, "animations");
			if (animsNode != null) parseAnimations(skin, animsNode);

			var colorsNode = firstElement(root, "colors");
			if (colorsNode != null) parseColors(skin, colorsNode);

			return skin;
		}
		catch (e:Dynamic)
		{
			Log.error('[NoteSkin] no se pudo leer $id/data/noteSkin.xml: ' + Std.string(e));
			return null;
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
				confirm: attr(lane, "confirm", base.confirm)
			};
		}
	}

	static function parseColors(skin:NoteSkin, node:Xml):Void
	{
		for (lane in node.elementsNamed("lane"))
		{
			var idleAttr = attr(lane, "idle", attr(lane, "color", null));
			if (idleAttr == null) continue;

			var idle = parseColor(idleAttr, -1);
			if (idle < 0) continue;

			var pressedAttr = attr(lane, "pressed", null);
			var pressed = pressedAttr == null ? idle : parseColor(pressedAttr, idle);
			var entry:NoteSkinColor = {idle: idle, pressed: pressed};

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
				confirm: dir + " confirm"
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
