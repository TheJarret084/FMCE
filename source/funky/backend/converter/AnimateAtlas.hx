package funky.backend.converter;

import haxe.Json;

typedef AtlasSprite =
{
	var name:String;
	var x:Int;
	var y:Int;
	var w:Int;
	var h:Int;
	var rotated:Bool;
	var page:Int;
}

/** Efecto de color de una instancia: canal * multiplicador + desplazamiento (0..255). */
typedef ColorFx =
{
	var rm:Float;
	var gm:Float;
	var bm:Float;
	var am:Float;
	var ro:Float;
	var go:Float;
	var bo:Float;
	var ao:Float;
}

/** Un sprite del atlas ya colocado: `x' = a*x + c*y + tx`, `y' = b*x + d*y + ty`. */
typedef DrawOp =
{
	var sprite:String;
	var a:Float;
	var b:Float;
	var c:Float;
	var d:Float;
	var tx:Float;
	var ty:Float;
	var fx:Null<ColorFx>;
}

private typedef Element =
{
	/** true = sprite del atlas (ASI), false = instancia de simbolo (SI). */
	var atlas:Bool;
	var name:String;
	var m:Array<Float>;
	var type:String;
	var loop:String;
	var first:Int;
	var fx:Null<ColorFx>;
}

private typedef Keyframe =
{
	var index:Int;
	var dur:Int;
	var label:Null<String>;
	var elements:Array<Element>;
}

private typedef Layer =
{
	var name:String;
	var frames:Array<Keyframe>;
}

class AnimateTimeline
{
	public var layers:Array<Layer> = [];
	public var length:Int = 0;

	public function new() {}
}

/** Lee un spritemap de Adobe Animate y arma sus animaciones. */
class AnimateAtlas
{
	static inline var MAX_DEPTH:Int = 24;

	public var name(default, null):String = "";
	public var fps(default, null):Float = 24;
	public var stage(default, null):AnimateTimeline = new AnimateTimeline();
	public var symbols(default, null):Map<String, AnimateTimeline> = new Map<String, AnimateTimeline>();
	public var sprites(default, null):Map<String, AtlasSprite> = new Map<String, AtlasSprite>();
	public var pages(default, null):Array<String> = [];
	public var warnings(default, null):Array<String> = [];

	public function new() {}

	/** @param animation texto de Animation.json. @param spritemaps (nombre del json, texto) de cada spritemapN.json. */
	public static function parse(animation:String, spritemaps:Array<{file:String, text:String}>):AnimateAtlas
	{
		var atlas = new AnimateAtlas();
		var root:Dynamic = Json.parse(clean(animation));
		var an:Dynamic = pick(root, "AN", "ANIMATION");
		if (an == null) throw "Animation.json no tiene la animacion principal (AN / ANIMATION)";
		atlas.name = str(pick(an, "N", "name"), "");

		var md:Dynamic = pick(root, "MD", "metadata");
		atlas.fps = num(pick(md, "FRT", "framerate"), 24);
		if (atlas.fps <= 0) atlas.fps = 24;

		var dict:Dynamic = pick(root, "SD", "SYMBOL_DICTIONARY");
		var list:Dynamic = pick(dict, "S", "Symbols");
		if (Std.isOfType(list, Array))
			for (symbol in (list : Array<Dynamic>))
			{
				var n = str(pick(symbol, "SN", "SYMBOL_name"), "");
				if (n != "") atlas.symbols.set(n, atlas.timeline(pick(symbol, "TL", "TIMELINE")));
			}
		atlas.stage = atlas.timeline(pick(an, "TL", "TIMELINE"));

		for (map in spritemaps)
		{
			var data:Dynamic = Json.parse(clean(map.text));
			var meta:Dynamic = Reflect.field(data, "meta");
			var page = atlas.pages.length;
			atlas.pages.push(str(Reflect.field(meta, "image"), StringTools.replace(map.file, ".json", ".png")));
			var all:Dynamic = Reflect.field(Reflect.field(data, "ATLAS"), "SPRITES");
			if (Std.isOfType(all, Array))
				for (entry in (all : Array<Dynamic>))
				{
					var s:Dynamic = Reflect.field(entry, "SPRITE");
					if (s == null) continue;
					var key = str(Reflect.field(s, "name"), "");
					atlas.sprites.set(key, {
						name: key, x: Std.int(num(Reflect.field(s, "x"), 0)), y: Std.int(num(Reflect.field(s, "y"), 0)),
						w: Std.int(num(Reflect.field(s, "w"), 0)), h: Std.int(num(Reflect.field(s, "h"), 0)),
						rotated: Reflect.field(s, "rotated") == true, page: page
					});
				}
		}
		return atlas;
	}

	// ------------------------------------------------------------------ lectura

	/** Quita el BOM que deja Animate al principio de los json. */
	static function clean(text:String):String
		return text.length > 0 && text.charCodeAt(0) == 0xFEFF ? text.substr(1) : text;

	static function pick(o:Dynamic, shortKey:String, longKey:String):Dynamic
	{
		if (o == null) return null;
		var v = Reflect.field(o, shortKey);
		return v != null ? v : Reflect.field(o, longKey);
	}

	static function num(v:Dynamic, fallback:Float):Float
	{
		if (v == null) return fallback;
		var f = Std.parseFloat(Std.string(v));
		return Math.isNaN(f) ? fallback : f;
	}

	static function str(v:Dynamic, fallback:String):String
		return v == null ? fallback : Std.string(v);

	function timeline(tl:Dynamic):AnimateTimeline
	{
		var out = new AnimateTimeline();
		var layers:Dynamic = pick(tl, "L", "LAYERS");
		if (!Std.isOfType(layers, Array)) return out;
		for (raw in (layers : Array<Dynamic>))
		{
			if (pick(raw, "LT", "Layer_type") != null) warnings.push("capa '" + str(pick(raw, "LN", "Layer_name"), "?") + "' es una mascara o guia: se dibuja como capa normal");
			var layer:Layer = {name: str(pick(raw, "LN", "Layer_name"), ""), frames: []};
			var frames:Dynamic = pick(raw, "FR", "Frames");
			if (Std.isOfType(frames, Array))
				for (f in (frames : Array<Dynamic>))
				{
					var key:Keyframe = {
						index: Std.int(num(pick(f, "I", "index"), 0)), dur: Std.int(Math.max(1, num(pick(f, "DU", "duration"), 1))),
						label: pick(f, "N", "name") == null ? null : str(pick(f, "N", "name"), ""), elements: []
					};
					var elements:Dynamic = pick(f, "E", "elements");
					if (Std.isOfType(elements, Array))
						for (e in (elements : Array<Dynamic>))
						{
							var el = element(e);
							if (el != null) key.elements.push(el);
						}
					layer.frames.push(key);
					out.length = Std.int(Math.max(out.length, key.index + key.dur));
				}
			out.layers.push(layer);
		}
		return out;
	}

	function element(e:Dynamic):Null<Element>
	{
		var asi:Dynamic = pick(e, "ASI", "Atlas_Sprite_Instance");
		if (asi != null)
			return {atlas: true, name: str(pick(asi, "N", "name"), ""), m: matrix(asi), type: "G", loop: "LP", first: 0, fx: null};
		var si:Dynamic = pick(e, "SI", "Symbol_Instance");
		if (si == null) return null;
		return {
			atlas: false, name: str(pick(si, "SN", "SYMBOL_name"), ""), m: matrix(si), type: str(pick(si, "ST", "symbolType"), "G"),
			loop: str(pick(si, "LP", "loop"), "LP"), first: Std.int(num(pick(si, "FF", "firstFrame"), 0)), fx: colorOf(pick(si, "C", "color"))
		};
	}

	/** [a, b, c, d, tx, ty] desde `MX` (6 valores), `M3D` (16, por columnas) o `Matrix3D` {m00...}. */
	static function matrix(o:Dynamic):Array<Float>
	{
		var mx:Dynamic = Reflect.field(o, "MX");
		if (Std.isOfType(mx, Array) && (mx : Array<Dynamic>).length >= 6) return [for (v in (mx : Array<Dynamic>)) num(v, 0)];
		var m3:Dynamic = pick(o, "M3D", "Matrix3D");
		if (Std.isOfType(m3, Array) && (m3 : Array<Dynamic>).length >= 14)
		{
			var m:Array<Dynamic> = m3;
			return [num(m[0], 1), num(m[1], 0), num(m[4], 0), num(m[5], 1), num(m[12], 0), num(m[13], 0)];
		}
		if (m3 != null && Reflect.isObject(m3))
			return [num(Reflect.field(m3, "m00"), 1), num(Reflect.field(m3, "m01"), 0), num(Reflect.field(m3, "m10"), 0), num(Reflect.field(m3, "m11"), 1),
				num(Reflect.field(m3, "m30"), 0), num(Reflect.field(m3, "m31"), 0)];
		return [1, 0, 0, 1, 0, 0];
	}

	/** Efectos de color de Animate: alfa, avanzado, tinte y brillo. */
	static function colorOf(c:Dynamic):Null<ColorFx>
	{
		if (c == null) return null;
		var mode = str(pick(c, "M", "mode"), "");
		var fx:ColorFx = {rm: 1, gm: 1, bm: 1, am: 1, ro: 0, go: 0, bo: 0, ao: 0};
		switch (mode)
		{
			case "CA", "Alpha":
				fx.am = num(pick(c, "AM", "alphaMultiplier"), 1);
			case "AD", "Advanced":
				fx.rm = num(pick(c, "RM", "RedMultiplier"), 1);
				fx.gm = num(pick(c, "GM", "greenMultiplier"), 1);
				fx.bm = num(pick(c, "BM", "blueMultiplier"), 1);
				fx.am = num(pick(c, "AM", "AlphaMultiplier"), 1);
				fx.ro = num(pick(c, "RO", "redOffset"), 0);
				fx.go = num(pick(c, "GO", "greenOffset"), 0);
				fx.bo = num(pick(c, "BO", "blueOffset"), 0);
				fx.ao = num(pick(c, "AO", "AlphaOffset"), 0);
			case "T", "Tint":
				var tm = num(pick(c, "TM", "tintMultiplier"), 1);
				var color = Std.parseInt("0x" + StringTools.replace(str(pick(c, "TC", "tintColor"), "#FFFFFF"), "#", ""));
				if (color == null) color = 0xFFFFFF;
				fx.rm = fx.gm = fx.bm = 1 - tm;
				fx.ro = ((color >> 16) & 0xFF) * tm;
				fx.go = ((color >> 8) & 0xFF) * tm;
				fx.bo = (color & 0xFF) * tm;
			case "CBRT", "Brightness":
				var br = num(pick(c, "BRT", "brightness"), 0);
				fx.rm = fx.gm = fx.bm = 1 - Math.abs(br);
				var add = br > 0 ? 255 * br : 0;
				fx.ro = fx.go = fx.bo = add;
			default:
				return null;
		}
		return fx;
	}

	// ------------------------------------------------------------------ consulta

	/** Timeline de un simbolo del diccionario (null si no existe). */
	public function symbol(name:String):Null<AnimateTimeline>
		return symbols.get(name);

	/** Rango [desde, hasta) de frames del label `label` en la linea de tiempo principal (hasta el siguiente label). */
	public function labelRange(label:String):Null<{from:Int, to:Int}>
	{
		var starts:Array<{at:Int, name:String}> = [];
		for (layer in stage.layers)
			for (f in layer.frames)
				if (f.label != null && f.label != "") starts.push({at: f.index, name: f.label});
		starts.sort(function(a, b) return a.at - b.at);
		for (i in 0...starts.length)
			if (starts[i].name == label)
			{
				var to = stage.length;
				for (j in i + 1...starts.length)
					if (starts[j].at > starts[i].at)
					{
						to = starts[j].at;
						break;
					}
				return {from: starts[i].at, to: to};
			}
		return null;
	}

	/** Labels de la linea de tiempo principal, en orden. */
	public function labels():Array<String>
	{
		var starts:Array<{at:Int, name:String}> = [];
		for (layer in stage.layers)
			for (f in layer.frames)
				if (f.label != null && f.label != "") starts.push({at: f.index, name: f.label});
		starts.sort(function(a, b) return a.at - b.at);
		var out:Array<String> = [];
		for (s in starts)
			if (out.indexOf(s.name) < 0) out.push(s.name);
		return out;
	}

	/**
	 * Sprites del atlas que se ven en el frame `frame` de `tl`, de abajo hacia arriba. `root` = [a, b, c, d, tx, ty] de la
	 * linea de tiempo. Las capas de Animate vienen de arriba hacia abajo, por eso se recorren al reves.
	 */
	public function ops(tl:AnimateTimeline, frame:Int, root:Array<Float>):Array<DrawOp>
	{
		var out:Array<DrawOp> = [];
		expand(tl, frame, root, null, out, 0);
		return out;
	}

	function expand(tl:AnimateTimeline, frame:Int, parent:Array<Float>, parentFx:Null<ColorFx>, out:Array<DrawOp>, depth:Int):Void
	{
		if (depth > MAX_DEPTH) return;
		var i = tl.layers.length - 1;
		while (i >= 0)
		{
			var layer = tl.layers[i];
			i--;
			var key:Null<Keyframe> = null;
			for (f in layer.frames)
				if (frame >= f.index && frame < f.index + f.dur)
				{
					key = f;
					break;
				}
			if (key == null) continue;

			for (e in key.elements)
			{
				var m = compose(parent, e.m);
				var fx = mergeFx(parentFx, e.fx);
				if (e.atlas)
				{
					out.push({sprite: e.name, a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5], fx: fx});
					continue;
				}
				var child = symbols.get(e.name);
				if (child == null || child.length == 0) continue;
				var local = frame - key.index;
				var f:Int;
				switch (e.loop)
				{
					case "SF":
						f = e.first;
					case "PO":
						f = Std.int(Math.min(e.first + local, child.length - 1));
					default:
						f = (e.first + local) % child.length;
				}
				if (e.type != "G" && e.type != "" && e.loop == "LP" && e.first == 0) f = local % child.length;
				expand(child, f < 0 ? 0 : f, m, fx, out, depth + 1);
			}
		}
	}

	/** parent * child: se aplica primero `child`. */
	static function compose(p:Array<Float>, c:Array<Float>):Array<Float>
	{
		return [
			p[0] * c[0] + p[2] * c[1],
			p[1] * c[0] + p[3] * c[1],
			p[0] * c[2] + p[2] * c[3],
			p[1] * c[2] + p[3] * c[3],
			p[0] * c[4] + p[2] * c[5] + p[4],
			p[1] * c[4] + p[3] * c[5] + p[5]
		];
	}

	static function mergeFx(a:Null<ColorFx>, b:Null<ColorFx>):Null<ColorFx>
	{
		if (a == null) return b;
		if (b == null) return a;
		return {
			rm: a.rm * b.rm, gm: a.gm * b.gm, bm: a.bm * b.bm, am: a.am * b.am,
			ro: a.ro * b.rm + b.ro, go: a.go * b.gm + b.go, bo: a.bo * b.bm + b.bo, ao: a.ao * b.am + b.ao
		};
	}

	/**
	 * Escala (1 o menos) para que una tira de `frames` celdas de w x h entre en `maxSide` por lado y en `maxPixels` en total.
	 * Los atlas de Animate suelen tener frames enormes: la tira se reduce y el exportador compensa con `scale` y el pivote.
	 */
	public static function fitScale(w:Int, h:Int, frames:Int, maxSide:Int, maxPixels:Float):Float
	{
		var k = 1.0;
		k = Math.min(k, maxSide / (w * frames));
		k = Math.min(k, maxSide / h);
		k = Math.min(k, Math.sqrt(maxPixels / (w * h * frames)));
		if (k >= 1) return 1;
		return Math.max(0.05, Math.floor(k * 100) / 100);
	}

	/** Caja (x0, y0, x1, y1) que ocupan los sprites de `list`, o null si no hay ninguno con tamano. */
	public function bounds(list:Array<DrawOp>):Null<{x0:Float, y0:Float, x1:Float, y1:Float}>
	{
		var box:Null<{x0:Float, y0:Float, x1:Float, y1:Float}> = null;
		for (op in list)
		{
			var s = sprites.get(op.sprite);
			if (s == null || s.w <= 0 || s.h <= 0) continue;
			var w:Float = s.rotated ? s.h : s.w;
			var h:Float = s.rotated ? s.w : s.h;
			for (corner in [{x: 0.0, y: 0.0}, {x: w, y: 0.0}, {x: 0.0, y: h}, {x: w, y: h}])
			{
				var x = op.a * corner.x + op.c * corner.y + op.tx;
				var y = op.b * corner.x + op.d * corner.y + op.ty;
				if (box == null) box = {x0: x, y0: y, x1: x, y1: y};
				else
				{
					if (x < box.x0) box.x0 = x;
					if (y < box.y0) box.y0 = y;
					if (x > box.x1) box.x1 = x;
					if (y > box.y1) box.y1 = y;
				}
			}
		}
		return box;
	}
}
