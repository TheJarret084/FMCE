package funky.backend.skins;
import funky.backend.system.ClientPrefs;

import funky.backend.system.Log;
import funky.backend.addons.Addons;
import funky.backend.assets.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;

using StringTools;

typedef HudSkinLane =
{
	var note:String;
	var hold:String;
	var holdEnd:String;
	var receptor:String;
	var press:String;
	var confirm:String;

	var splash:String;
}

typedef HudSkinColor =
{
	var idle:Null<Int>;
	var pressed:Null<Int>;
	var rest:Null<Int>;
}

/** Estilo de un texto del HUD, declarado en <texts> del hudSkin.xml. */
typedef HudTextStyle =
{
	var size:Int;
	var color:Int;
	var border:Int;
	var borderSize:Float;
	var align:String;
	var alpha:Float;
}

enum abstract HudSkinType(String) to String
{
	var SPARROW = "sparrow";
	var RGB = "rgb";
	var TINT = "tint";

	public static function parse(value:Null<String>, fallback:HudSkinType):HudSkinType
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

class HudSkin
{
	public static inline var DEFAULT_ID:String = "default";

	static inline var ROOT:String = "hudskins/";
	// Solo para skins viejos del usuario: el engine ya no usa noteskins/ para los builtins.
	static inline var LEGACY_ROOT:String = "noteskins/";
	static var DIRS:Array<String> = ["left", "down", "up", "right"];

	static var BUILTINS:Array<String> = [DEFAULT_ID, "codename", "fmm"];

	static var cache:Map<String, HudSkin> = new Map();
	static var hooked:Bool = false;

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
		#if (!nme && !flash)
		HudShaderUtil.clearAll();
		#end
	}

	public var id(default, null):String;
	public var name:String;
	public var author:String;

	// Configuracion visual completa del HUD, definida en hudSkin.xml.
	public var font:String = "PhantomMuff.ttf";
	public var scoreDir:String = "score";

	public var countdownDir:String = "";
	public var countdownReady:String = "";
	public var countdownSet:String = "";
	public var countdownGo:String = "";
	public var countdownScale:Float = 1;
	public var countdownAlpha:Float = 1;

	public var timeBarMode:String = "legacy";
	public var timeBarStyle:String = "pinklime";
	public var timeBarWidth:Int = 400;
	public var timeBarHeight:Int = 18;
	public var timeBarBgPad:Int = 4;
	public var timeBarEmpty:Int = 0xFF101016;
	public var timeBarFill:Int = 0xFFFF8AFF;
	public var timeBarBorder:Int = 0xFF000000;
	public var timeBarTextColor:Int = 0xFFFFFFFF;

	public var texts:Map<String, HudTextStyle> = new Map();

	public var atlas:String;
	public var type:HudSkinType = RGB;

	public var rgb(get, never):Bool;

	inline function get_rgb():Bool
		return type == RGB;
	public var holdAlpha:Float = 0.65;

	/** Sombra de notas y receptores (<shadow> en hudSkin.xml). x e y son fracciones del ancho del sprite. */
	public var shadowEnabled:Bool = false;
	public var shadowX:Float = 0.025;
	public var shadowY:Float = 0.07;
	public var shadowAlpha:Float = 0.55;
	public var shadowColor:Int = 0xFF000000;
	public var anims:Array<HudSkinLane>;
	public var colors:Array<Null<HudSkinColor>>;

	public var restColor:Null<Int> = null;

	public var palette:Array<Null<HudSkinColor>>;

	public var pressedScale:Float = 1;
	public static inline var DEFAULT_TINT_PRESSED_SCALE:Float = 1.15;

	public var splashScale:Float = 1;

	public var splashAtlas:String = "splash";
	var splashAtlasDeclared:Bool = false;
	var splashFramesCache:Null<FlxAtlasFrames>;
	var splashTried:Bool = false;
	public var splashAlpha:Float = 0.8;
	public var splashFps:Int = 24;

	public var script(default, null):Null<HudSkinScript> = null;

	var framesCache:Null<FlxAtlasFrames>;

	var framesTried:Bool = false;

	function new(id:String)
	{
		this.id = id;
		name = id;
		author = "";
		atlas = "NOTE_assets";
		font = "PhantomMuff.ttf";
		scoreDir = "score";
		countdownDir = "";
		countdownReady = "";
		countdownSet = "";
		countdownGo = "";
		countdownScale = 1;
		countdownAlpha = 1;
		anims = defaultAnimations();
		colors = [];
		for (_ in 0...DIRS.length) colors.push(null);
		palette = [];
		for (_ in 0...9) palette.push(null);
	}

	public static function current():HudSkin
		return get(ClientPrefs.getHudSkin());

	public static function get(id:String):HudSkin
	{
		if (id == null || id.length == 0) id = DEFAULT_ID;
		hook();

		var cached = cache.get(id);
		if (cached != null) return cached;

		var skin = load(id);
		if (skin == null || !skin.hasAtlas())
		{
			Log.warn('[HudSkin] "$id" no esta completo (' + (skin == null ? "falta data/hudSkin.xml" : "falta su atlas " + skin.atlasRel() + ".png/.xml") + ')'
				+ (id != DEFAULT_ID ? ': se usa "default"' : ''));

			if (id != DEFAULT_ID)
			{

				var replacement = get(DEFAULT_ID);
				cache.set(id, replacement);
				return replacement;
			}
			if (skin == null) skin = fallback();
		}

		cache.set(id, skin);
		return skin;
	}

	public static function list():Array<String>
	{
		var out:Array<String> = [];
		for (id in BUILTINS) out.push(id);

		for (id in Addons.folders("hudskins"))
			if (!out.contains(id) && Addons.exists(ROOT + id + "/data/hudSkin.xml")) out.push(id);
		for (id in Addons.folders("noteskins"))
			if (!out.contains(id) && Addons.exists(LEGACY_ROOT + id + "/data/noteSkin.xml")) out.push(id);

		return out;
	}

	public static function displayName(id:String):String
		return get(id).name;

	public function hasAtlas():Bool
		return (Addons.exists(atlasRel() + ".png") && Addons.exists(atlasRel() + ".xml"))
			|| (Addons.exists(legacyAtlasRel() + ".png") && Addons.exists(legacyAtlasRel() + ".xml"))
			|| Paths.framesExists(atlas);

	public function frames():FlxAtlasFrames
	{
		if (framesCache != null)
		{

			var graphic = framesCache.parent;
			if (graphic != null && !graphic.isDestroyed && graphic.bitmap != null) return framesCache;
			framesCache = null;
			framesTried = false;
		}
		if (framesTried) return null;
		framesTried = true;

		framesCache = cast Addons.getSparrowAtlas(atlasRel());
		if (framesCache == null) framesCache = cast Addons.getSparrowAtlas(legacyAtlasRel());
		if (framesCache == null && Paths.framesExists(atlas)) framesCache = cast Paths.getSparrowAtlas(atlas);
		if (framesCache == null)
			Log.error('[HudSkin] no se pudo cargar el atlas de "$id": ' + atlasRel() + '.png/.xml (en addons/ externo o del build) ni assets/images/$atlas');
		return framesCache;
	}

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

		var name = splashAtlas.replace("\\", "/");
		splashFramesCache = cast Addons.getSparrowAtlas(ROOT + id + "/images/" + name);
		if (splashFramesCache == null) splashFramesCache = cast Addons.getSparrowAtlas(LEGACY_ROOT + id + "/images/" + name);
		if (splashFramesCache == null && splashAtlasDeclared && Paths.framesExists(splashAtlas)) splashFramesCache = cast Paths.getSparrowAtlas(splashAtlas);
		if (splashFramesCache == null && splashAtlasDeclared)
			Log.warn('[HudSkin] no se pudo cargar el atlas de splash "$splashAtlas" de "$id": el splash usa el atlas principal');
		return splashFramesCache;
	}

	function atlasRel():String
	{
		var p = ROOT + id + "/images/" + atlas;
		if (Addons.exists(p + ".png") || Addons.exists(p + ".xml")) return p;
		var old = LEGACY_ROOT + id + "/images/" + atlas;
		if (Addons.exists(old + ".png") || Addons.exists(old + ".xml")) return old;
		return p;
	}

	function legacyAtlasRel():String
		return LEGACY_ROOT + id + "/images/" + atlas;

	public function shaderSource(name:String):Null<String>
	{
		var src = Addons.getText(ROOT + id + "/shaders/" + name + ".frag");
		if (src == null) src = Addons.getText(LEGACY_ROOT + id + "/shaders/" + name + ".frag");
		return src;
	}

	public function image(rel:String):Null<openfl.display.BitmapData>
	{
		var p = rel.replace("\\", "/");
		var bmp = Addons.getBitmap(ROOT + id + "/images/" + p + ".png");
		if (bmp == null) bmp = Addons.getBitmap(LEGACY_ROOT + id + "/images/" + p + ".png");
		if (bmp == null && id != DEFAULT_ID)
		{
			bmp = Addons.getBitmap(ROOT + DEFAULT_ID + "/images/" + p + ".png");
			var canonical = p.startsWith("score/") ? "game/" + p : p;
			if (bmp == null && canonical != p) bmp = Addons.getBitmap(ROOT + DEFAULT_ID + "/images/" + canonical + ".png");
		}
		return bmp;
	}

	/** Sonido del skin (sounds/<nombre>.ogg), o null para usar el del engine. */
	public function sound(name:String):Null<String>
	{
		var key = haxe.io.Path.withoutDirectory(name.replace("\\", "/"));
		var p = Addons.file(ROOT + id + "/sounds/" + key + ".ogg");
		if (p == null) p = Addons.file(LEGACY_ROOT + id + "/sounds/" + key + ".ogg");
		if (p == null && id != DEFAULT_ID) p = Addons.file(ROOT + DEFAULT_ID + "/sounds/" + key + ".ogg");
		return p;
	}

	public function fontPath():Null<String>
	{
		if (font == null || font == "") return null;
		var file = haxe.io.Path.withoutDirectory(font.replace("\\", "/"));
		var p = Addons.file(ROOT + id + "/fonts/" + file);
		if (p == null) p = Addons.file(LEGACY_ROOT + id + "/fonts/" + file);
		if (p == null && id != DEFAULT_ID) p = Addons.file(ROOT + DEFAULT_ID + "/fonts/" + file);
		if (p != null) return p;
		return Paths.fontPath(file);
	}

	/** Imagen del countdown del skin (ready / set / go), o null para usar la del engine. */
	public function countdownImage(path:String):Null<openfl.display.BitmapData>
	{
		var key = haxe.io.Path.withoutDirectory(path.replace("\\", "/")).toLowerCase();
		var rel = switch (key)
		{
			case "ready" | "intro2" | "2": countdownReady;
			case "set" | "intro1" | "1": countdownSet;
			case "go" | "intro0" | "0": countdownGo;
			default: "";
		};
		if (rel == "") return null;
		return image((countdownDir == "" ? "" : countdownDir + "/") + rel);
	}

	public function text(idText:String):HudTextStyle
	{
		var s = texts.get(idText);
		if (s != null) return s;
		return {size: 20, color: 0xFFFFFFFF, border: 0xFF000000, borderSize: 1.25, align: "center", alpha: 1};
	}

	public function notify(primary:String, ?alias:String, ?args:Array<Dynamic>):Void
	{
		if (script == null) return;
		script.call(primary, args);
		if (alias != null && alias != primary) script.call(alias, args);
	}

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

	function entryFor(lane:Int, ?laneCount:Int):Null<HudSkinColor>
	{
		var total = laneCount == null ? 4 : Std.int(Math.max(1, Math.min(9, laneCount)));
		var safeLane = lane < 0 ? 0 : (lane >= total ? total - 1 : lane);

		var entry = palette[ClientPrefs.colorIndexForLane(safeLane, total)];
		return entry != null ? entry : colors[dirForLane(lane)];
	}

	public function colorFor(lane:Int, pressed:Bool = false, ?laneCount:Int):Null<Int>
	{
		var entry = entryFor(lane, laneCount);
		if (entry == null) return null;

		return pressed ? (entry.pressed != null ? entry.pressed : entry.idle) : entry.idle;
	}

	public function restTintFor(lane:Int, ?laneCount:Int):Int
	{
		var entry = entryFor(lane, laneCount);
		if (entry != null && entry.rest != null) return 0xFF000000 | entry.rest;
		if (restColor != null) return 0xFF000000 | restColor;
		return ClientPrefs.strumIdleColor();
	}

	public function rgbFor(lane:Int, pressed:Bool = false, ?laneCount:Int):Null<Array<Int>>
	{
		if (type != RGB) return null;

		var color = colorFor(lane, pressed, laneCount);
		return color == null
			? ClientPrefs.noteRgbForLane(lane, pressed, laneCount)
			: ClientPrefs.rgbFromBase(color);
	}

	public function tintFor(lane:Int, pressed:Bool = false, ?laneCount:Int):Null<Int>
	{
		if (type != TINT) return null;

		var color = colorFor(lane, pressed, laneCount);
		return color != null ? (0xFF000000 | color) : (0xFF000000 | ClientPrefs.noteColorForLane(lane, pressed, laneCount));
	}

	public function applyTo(sprite:FlxSprite, lane:Int, pressed:Bool = false, ?laneCount:Int):Void
	{
		switch (type)
		{
			case RGB:
				var colors = rgbFor(lane, pressed, laneCount);
				sprite.shader = colors == null ? null : HudRGBShader.forColors(colors);
				sprite.color = 0xFFFFFFFF;
			case TINT:
				sprite.shader = null;
				var tint = tintFor(lane, pressed, laneCount);
				sprite.color = tint == null ? 0xFFFFFFFF : tint;
			case SPARROW:
				sprite.shader = null;
				sprite.color = 0xFFFFFFFF;
		}

		#if (!nme && !flash)
		HudShaderUtil.restore(sprite);
		#end
	}

	public static function clearCache():Void
	{
		cache.clear();
	}

	static function load(id:String):Null<HudSkin>
	{
		var raw = Addons.getText(ROOT + id + "/data/hudSkin.xml");
		if (raw == null) raw = Addons.getText(LEGACY_ROOT + id + "/data/noteSkin.xml");
		if (raw == null) return null;

		try
		{
			var root = Xml.parse(raw).firstElement();
			if (root == null || (root.nodeName != "hudSkin" && root.nodeName != "noteSkin")) return null;

			var skin = new HudSkin(id);
			skin.name = attr(root, "name", id);
			skin.author = attr(root, "author", "");
			skin.atlas = attr(root, "atlas", skin.atlas);

			var atlasNode = firstElement(root, "atlas");
			if (atlasNode != null) skin.atlas = attr(atlasNode, "path", skin.atlas);

			// El path del atlas es relativo a images/ y puede tener subdirectorio
			// (notes/default), asi que no se recorta con withoutDirectory().
			skin.atlas = skin.atlas.replace("\\", "/");
			while (skin.atlas.endsWith("/")) skin.atlas = skin.atlas.substr(0, skin.atlas.length - 1);

			var assetsNode = firstElement(root, "assets");
			if (assetsNode != null)
			{
				skin.font = attr(assetsNode, "font", skin.font);
				skin.scoreDir = attr(assetsNode, "scoreDir", skin.scoreDir).replace("\\", "/");
				while (skin.scoreDir.endsWith("/")) skin.scoreDir = skin.scoreDir.substr(0, skin.scoreDir.length - 1);
				skin.countdownDir = attr(assetsNode, "countdownDir", skin.countdownDir).replace("\\", "/");
				while (skin.countdownDir.endsWith("/")) skin.countdownDir = skin.countdownDir.substr(0, skin.countdownDir.length - 1);
			}

			var countdownNode = firstElement(root, "countdown");
			if (countdownNode != null)
			{
				skin.countdownReady = attr(countdownNode, "ready", skin.countdownReady);
				skin.countdownSet = attr(countdownNode, "set", skin.countdownSet);
				skin.countdownGo = attr(countdownNode, "go", skin.countdownGo);
				skin.countdownScale = Math.max(0.1, parseFloat(attr(countdownNode, "scale", null), skin.countdownScale));
				skin.countdownAlpha = Math.max(0, Math.min(1, parseFloat(attr(countdownNode, "alpha", null), skin.countdownAlpha)));
			}

			var timeNode = firstElement(root, "timeBar");
			if (timeNode != null)
			{
				skin.timeBarMode = attr(timeNode, "mode", skin.timeBarMode).toLowerCase();
				skin.timeBarStyle = attr(timeNode, "style", skin.timeBarStyle).toLowerCase();
				skin.timeBarWidth = Std.int(Math.max(80, parseFloat(attr(timeNode, "width", null), skin.timeBarWidth)));
				skin.timeBarHeight = Std.int(Math.max(4, parseFloat(attr(timeNode, "height", null), skin.timeBarHeight)));
				skin.timeBarBgPad = Std.int(Math.max(0, parseFloat(attr(timeNode, "bgPad", null), skin.timeBarBgPad)));
				skin.timeBarEmpty = parseColor(attr(timeNode, "empty", null), skin.timeBarEmpty);
				skin.timeBarFill = parseColor(attr(timeNode, "fill", null), skin.timeBarFill);
				skin.timeBarBorder = parseColor(attr(timeNode, "border", null), skin.timeBarBorder);
				skin.timeBarTextColor = parseColor(attr(timeNode, "textColor", null), skin.timeBarTextColor);
			}

			var textsNode = firstElement(root, "texts");
			if (textsNode != null)
				for (node in textsNode.elementsNamed("text"))
				{
					var key = attr(node, "id", null);
					if (key == null) continue;
					skin.texts.set(key, {
						size: Std.int(Math.max(6, parseFloat(attr(node, "size", null), 20))),
						color: parseColor(attr(node, "color", null), 0xFFFFFFFF),
						border: parseColor(attr(node, "border", null), 0xFF000000),
						borderSize: Math.max(0, parseFloat(attr(node, "borderSize", null), 1.25)),
						align: attr(node, "align", "center"),
						alpha: Math.max(0, Math.min(1, parseFloat(attr(node, "alpha", null), 1)))
					});
				}

			var rgbNode = firstElement(root, "rgb");
			var legacy:HudSkinType = rgbNode != null && !parseBool(attr(rgbNode, "enabled", "true"), true) ? SPARROW : RGB;
			skin.type = HudSkinType.parse(attr(root, "type", null), legacy);

			skin.pressedScale = skin.type == TINT ? DEFAULT_TINT_PRESSED_SCALE : 1;
			var pressedNode = firstElement(root, "pressedScale");
			if (pressedNode != null)
				skin.pressedScale = Math.max(0.1, parseFloat(attr(pressedNode, "value", null), skin.pressedScale));

			var splashNode = firstElement(root, "splash");
			if (splashNode != null) parseSplash(skin, splashNode);

			var holdNode = firstElement(root, "holdAlpha");
			if (holdNode != null) skin.holdAlpha = parseFloat(attr(holdNode, "value", "0.65"), 0.65);

			var shadowNode = firstElement(root, "shadow");
			if (shadowNode != null)
			{
				skin.shadowEnabled = parseBool(attr(shadowNode, "enabled", "true"), true);
				skin.shadowX = parseFloat(attr(shadowNode, "x", null), skin.shadowX);
				skin.shadowY = parseFloat(attr(shadowNode, "y", null), skin.shadowY);
				skin.shadowAlpha = Math.max(0, Math.min(1, parseFloat(attr(shadowNode, "alpha", null), skin.shadowAlpha)));
				skin.shadowColor = parseColor(attr(shadowNode, "color", null), skin.shadowColor);
			}

			var animsNode = firstElement(root, "animations");
			if (animsNode != null) parseAnimations(skin, animsNode);

			var colorsNode = firstElement(root, "colors");
			if (colorsNode != null) parseColors(skin, colorsNode);

			skin.loadScript();
			return skin;
		}
		catch (e:Dynamic)
		{
			Log.error('[HudSkin] no se pudo leer $id/data/hudSkin.xml: ' + Std.string(e));
			return null;
		}
	}

	function loadScript():Void
	{
		var source = Addons.getText(ROOT + id + "/data/hudSkin.hx");
		if (source == null) source = Addons.getText(ROOT + id + "/data/hudSkin.hscript");
		if (source == null) source = Addons.getText(LEGACY_ROOT + id + "/data/noteSkin.hx");
		if (source == null) source = Addons.getText(LEGACY_ROOT + id + "/data/noteSkin.hscript");
		if (source == null || StringTools.trim(source).length == 0) return;

		try
		{
			script = new HudSkinScript("hudSkin.hx", source, this);
			script.load();
		}
		catch (e:Dynamic)
		{

			script = null;
			Log.error('[HudSkin] script de $id: ' + Std.string(e));
		}
	}

	static function parseAnimations(skin:HudSkin, node:Xml):Void
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

	static function parseSplash(skin:HudSkin, node:Xml):Void
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

	static function parseColors(skin:HudSkin, node:Xml):Void
	{
		var globalRest = attr(node, "rest", null);
		if (globalRest != null)
		{
			skin.restColor = parseColorOpt(globalRest);
		}

		for (lane in node.elementsNamed("lane"))
		{

			var idleAttr = attr(lane, "idle", attr(lane, "color", null));
			var pressedAttr = attr(lane, "pressed", null);
			var restAttr = attr(lane, "rest", attr(lane, "strum", null));
			if (idleAttr == null && pressedAttr == null && restAttr == null) continue;

			var entry:HudSkinColor = {
				idle: idleAttr == null ? null : parseColorOpt(idleAttr),
				pressed: pressedAttr == null ? null : parseColorOpt(pressedAttr),
				rest: restAttr == null ? null : parseColorOpt(restAttr)
			};

			var dir = attr(lane, "dir", null);
			if (dir != null)
			{
				var idx = dirIndex(dir);
				if (idx >= 0) skin.colors[idx] = entry;
				continue;
			}

			var index = attr(lane, "index", null);
			if (index != null)
			{
				var idx = Std.parseInt(index);
				if (idx != null && idx >= 0 && idx < skin.palette.length)
					skin.palette[idx] = entry;
			}
		}
	}

	static function parseColorOpt(value:String):Null<Int>
	{
		var s = StringTools.trim(value);
		if (s.startsWith("#")) s = s.substr(1);
		else if (s.startsWith("0x") || s.startsWith("0X")) s = s.substr(2);
		if (s.length == 0) return null;

		var n = Std.parseInt("0x" + s);
		return n == null ? null : (s.length <= 6 ? (0xFF000000 | n) : n);
	}

	static function defaultAnimations():Array<HudSkinLane>
	{
		var out:Array<HudSkinLane> = [];
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

	static function fallback():HudSkin
	{
		var skin = new HudSkin(DEFAULT_ID);
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
