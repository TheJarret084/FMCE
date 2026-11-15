package funky.backend;

import haxe.Json;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Codec del `sprite.json`.
 *
 * En disco el sprite.json es compacto (formato FMCE v3). En memoria sigue siendo el layout Aseprite de siempre
 * (`{frames:[...], meta:{frameTags, fmce, pages...}}`), asi que todo el codigo que ya lee sprite.json sigue igual:
 * solo se cambia `Json.parse(texto)` por `SpriteSheet.parse(texto)` y `Json.stringify(data, null, "\t")` por `SpriteSheet.stringify(data)`.
 * Los archivos viejos (Aseprite) se siguen leyendo igual; `migrateFile` / `migrateTree` los pasan al formato nuevo comprobando
 * antes que no se pierda nada.
 *
 * Por que el Aseprite pesaba tanto: repite en CADA frame filename, frame, rotated, trimmed, spriteSourceSize, sourceSize, duration y page,
 * aunque muchos frames sean el mismo rectangulo del atlas (una animacion que se queda quieta N frames guardaba N copias).
 *
 * Formato v3:
 *
 *     {
 *         "format": "fmce-sprite", "version": 3,
 *         "image": "sprite.png",
 *         "size": [3641, 3807],                       // tamano del PNG
 *         "rects": [                                  // rectangulos UNICOS del atlas
 *             {"x":1860,"y":1,"w":460,"h":658,"ox":4,"sw":464}
 *         ],                                          //   ox/oy = recorte (trim), sw/sh = tamano original, solo si difieren
 *         "frames": "0, 1-3, 4*20, 5",                // slot -> rect. "a-b" = rango, "v*n" = v repetido n veces
 *         "duration": 42,                             // ms por frame ("durations" si no son todas iguales)
 *         "anims": [                                  // tags: slots desde..hasta (el indice del slot NO cambia)
 *             {"name":"anim0","from":0,"to":29}       //   opcionales: direction, repeat, fps, loop, offset, scale, bilinear
 *         ],
 *         "type": "icon", "bilinear": false           // opcionales
 *     }
 *
 * Los indices de slot son los mismos que los frames del Aseprite viejo, asi que los `indices` del config.json no se tocan.
 */
class SpriteSheet
{
	public static inline var FORMAT:String = "fmce-sprite";
	public static inline var VERSION:Int = 3;

	static inline var DEFAULT_DURATION:Int = 42;

	public static function isCompact(data:Dynamic):Bool
		return data != null && Reflect.field(data, "format") == FORMAT && Std.isOfType(Reflect.field(data, "rects"), Array);

	public static function parse(text:String):Dynamic
	{
		if (text.length > 0 && text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
		return expand(Json.parse(text));
	}

	public static function expandText(text:String):String
	{
		if (text.length > 0 && text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
		var data:Dynamic = Json.parse(text);
		return isCompact(data) ? Json.stringify(expand(data)) : text;
	}

	public static function expand(data:Dynamic):Dynamic
	{
		if (!isCompact(data)) return data;

		var rects:Array<Dynamic> = Reflect.field(data, "rects");
		var anims:Array<Dynamic> = arr(Reflect.field(data, "anims"));
		var slots = decodeSlots(Reflect.field(data, "frames"), rects.length);
		var names = namesOf(data, slots.length, anims);

		var durations:Null<Array<Int>> = Reflect.hasField(data, "durations") ? decodeValues(Reflect.field(data, "durations"), slots.length) : null;
		var duration = int(Reflect.field(data, "duration"), DEFAULT_DURATION);

		var frames:Array<Dynamic> = [];
		for (i in 0...slots.length)
		{
			var r = rects[slots[i]];
			var w = int(Reflect.field(r, "w"), 0);
			var h = int(Reflect.field(r, "h"), 0);
			var ox = int(Reflect.field(r, "ox"), 0);
			var oy = int(Reflect.field(r, "oy"), 0);
			var sw = int(Reflect.field(r, "sw"), w);
			var sh = int(Reflect.field(r, "sh"), h);
			var tw = int(Reflect.field(r, "tw"), w);
			var th = int(Reflect.field(r, "th"), h);
			var derived = ox != 0 || oy != 0 || sw != w || sh != h;

			frames.push({
				filename: names[i],
				frame: {x: int(Reflect.field(r, "x"), 0), y: int(Reflect.field(r, "y"), 0), w: w, h: h},
				rotated: Reflect.field(r, "rot") == true,
				trimmed: Reflect.hasField(r, "trim") ? Reflect.field(r, "trim") == true : derived,
				spriteSourceSize: {x: ox, y: oy, w: tw, h: th},
				sourceSize: {w: sw, h: sh},
				duration: durations == null ? duration : durations[i],
				page: int(Reflect.field(r, "page"), 0)
			});
		}

		var tags:Array<Dynamic> = [];
		var fmceAnims:Dynamic = {};
		var anyAnimMeta = false;
		for (a in anims)
		{
			var name = str(Reflect.field(a, "name"), "");
			var from = int(Reflect.field(a, "from"), 0);
			var tag:Dynamic = {name: name, from: from, to: int(Reflect.field(a, "to"), from), direction: str(Reflect.field(a, "direction"), "forward")};
			if (Reflect.hasField(a, "repeat")) Reflect.setField(tag, "repeat", Std.string(Reflect.field(a, "repeat")));
			tags.push(tag);

			var own:Dynamic = {};
			var has = false;
			for (key in ["fps", "loop", "scale", "bilinear"])
				if (Reflect.hasField(a, key))
				{
					Reflect.setField(own, key, Reflect.field(a, key));
					has = true;
				}
			var offset:Dynamic = Reflect.field(a, "offset");
			if (Std.isOfType(offset, Array) && (offset : Array<Dynamic>).length >= 2)
			{
				var list:Array<Dynamic> = offset;
				Reflect.setField(own, "offset", {x: list[0], y: list[1]});
				has = true;
			}
			if (has)
			{
				Reflect.setField(fmceAnims, name, own);
				anyAnimMeta = true;
			}
		}

		var size:Array<Dynamic> = arr(Reflect.field(data, "size"));
		var meta:Dynamic = {
			app: "FMCE",
			version: "2.0",
			image: str(Reflect.field(data, "image"), "sprite.png"),
			format: "RGBA8888",
			size: {w: size.length > 0 ? int(size[0], 0) : 0, h: size.length > 1 ? int(size[1], 0) : 0},
			scale: "1",
			frameTags: tags
		};

		var extraMeta:Dynamic = Reflect.field(data, "meta");
		if (extraMeta != null)
			for (key in Reflect.fields(extraMeta))
				Reflect.setField(meta, key, Reflect.field(extraMeta, key));

		var fmce:Dynamic = {};
		var anyFmce = false;
		for (key in ["source", "type", "bilinear"])
			if (Reflect.hasField(data, key))
			{
				Reflect.setField(fmce, key, Reflect.field(data, key));
				anyFmce = true;
			}
		var fmceExtra:Dynamic = Reflect.field(data, "fmceExtra");
		if (fmceExtra != null)
			for (key in Reflect.fields(fmceExtra))
			{
				Reflect.setField(fmce, key, Reflect.field(fmceExtra, key));
				anyFmce = true;
			}
		if (anyAnimMeta)
		{
			Reflect.setField(fmce, "animations", fmceAnims);
			anyFmce = true;
		}
		if (anyFmce) Reflect.setField(meta, "fmce", fmce);

		return {frames: frames, meta: meta};
	}

	/** Devuelve el texto del sprite.json en formato compacto. Acepta datos Aseprite o ya compactos. Si el Aseprite es el de tipo hash (frames por nombre) lo deja como estaba. */
	public static function stringify(data:Dynamic):String
	{
		var legacy = expand(data);
		var frames:Dynamic = Reflect.field(legacy, "frames");
		if (!Std.isOfType(frames, Array)) return Json.stringify(data, null, "\t");
		return write(legacy, cast frames);
	}

	static function write(legacy:Dynamic, frames:Array<Dynamic>):String
	{
		var meta:Dynamic = Reflect.field(legacy, "meta");
		var tags:Array<Dynamic> = arr(Reflect.field(meta, "frameTags"));
		var fmce:Dynamic = Reflect.field(meta, "fmce");
		var fmceAnims:Dynamic = Reflect.field(fmce, "animations");

		var rects:Array<String> = [];
		var rectIndex = new Map<String, Int>();
		var slots:Array<Int> = [];
		var durations:Array<Int> = [];

		for (f in frames)
		{
			var fr:Dynamic = Reflect.field(f, "frame");
			var w = int(Reflect.field(fr, "w"), 0);
			var h = int(Reflect.field(fr, "h"), 0);
			var ss:Dynamic = Reflect.field(f, "spriteSourceSize");
			var sz:Dynamic = Reflect.field(f, "sourceSize");
			var ox = int(Reflect.field(ss, "x"), 0);
			var oy = int(Reflect.field(ss, "y"), 0);
			var tw = ss == null ? w : int(Reflect.field(ss, "w"), w);
			var th = ss == null ? h : int(Reflect.field(ss, "h"), h);
			var sw = sz == null ? w : int(Reflect.field(sz, "w"), w);
			var sh = sz == null ? h : int(Reflect.field(sz, "h"), h);
			var page = int(Reflect.field(f, "page"), 0);
			var rot = Reflect.field(f, "rotated") == true;
			var derived = ox != 0 || oy != 0 || sw != w || sh != h;
			var trimmed = Reflect.hasField(f, "trimmed") ? Reflect.field(f, "trimmed") == true : derived;

			var parts = ['"x":' + int(Reflect.field(fr, "x"), 0), '"y":' + int(Reflect.field(fr, "y"), 0), '"w":' + w, '"h":' + h];
			if (ox != 0) parts.push('"ox":' + ox);
			if (oy != 0) parts.push('"oy":' + oy);
			if (sw != w) parts.push('"sw":' + sw);
			if (sh != h) parts.push('"sh":' + sh);
			if (tw != w) parts.push('"tw":' + tw);
			if (th != h) parts.push('"th":' + th);
			if (rot) parts.push('"rot":true');
			if (page != 0) parts.push('"page":' + page);
			if (trimmed != derived) parts.push('"trim":' + trimmed);
			var line = "{" + parts.join(",") + "}";

			var index = rectIndex.get(line);
			if (index == null)
			{
				index = rects.length;
				rects.push(line);
				rectIndex.set(line, index);
			}
			slots.push(index);
			durations.push(int(Reflect.field(f, "duration"), DEFAULT_DURATION));
		}

		var out:Array<String> = [];
		out.push('\t"format": ' + Json.stringify(FORMAT) + ',');
		out.push('\t"version": ' + VERSION + ',');
		out.push('\t"image": ' + Json.stringify(str(Reflect.field(meta, "image"), "sprite.png")) + ',');
		var size:Dynamic = Reflect.field(meta, "size");
		out.push('\t"size": [' + int(Reflect.field(size, "w"), 0) + ', ' + int(Reflect.field(size, "h"), 0) + '],');

		var uniform = true;
		for (d in durations) if (d != durations[0]) uniform = false;
		if (durations.length == 0 || uniform) out.push('\t"duration": ' + (durations.length == 0 ? DEFAULT_DURATION : durations[0]) + ',');
		else out.push('\t"durations": ' + Json.stringify(encodeValues(durations)) + ',');

		for (key in ["type", "bilinear", "source"])
			if (fmce != null && Reflect.hasField(fmce, key)) out.push('\t"' + key + '": ' + Json.stringify(Reflect.field(fmce, key)) + ',');

		var names = [for (f in frames) str(Reflect.field(f, "filename"), "")];
		if (!namesMatch(names, tags)) out.push('\t"names": ' + Json.stringify(names) + ',');

		var extraMeta:Dynamic = {};
		var anyExtraMeta = false;
		for (key in Reflect.fields(meta))
		{
			if (key == "image" || key == "size" || key == "frameTags" || key == "fmce" || key == "app" || key == "version" || key == "format") continue;
			if (key == "scale" && Std.string(Reflect.field(meta, key)) == "1") continue;
			Reflect.setField(extraMeta, key, Reflect.field(meta, key));
			anyExtraMeta = true;
		}

		var extraFmce:Dynamic = {};
		var anyExtraFmce = false;
		if (fmce != null)
			for (key in Reflect.fields(fmce))
			{
				if (key == "source" || key == "type" || key == "bilinear" || key == "animations") continue;
				Reflect.setField(extraFmce, key, Reflect.field(fmce, key));
				anyExtraFmce = true;
			}

		out.push('\t"rects": [\n\t\t' + rects.join(",\n\t\t") + '\n\t],');
		out.push('\t"frames": ' + Json.stringify(encodeSlots(slots)) + ',');

		var animLines:Array<String> = [];
		for (tag in tags)
		{
			var name = str(Reflect.field(tag, "name"), "");
			var parts = ['"name":' + Json.stringify(name), '"from":' + int(Reflect.field(tag, "from"), 0), '"to":' + int(Reflect.field(tag, "to"), 0)];
			var direction = str(Reflect.field(tag, "direction"), "forward");
			if (direction != "forward") parts.push('"direction":' + Json.stringify(direction));
			if (Reflect.hasField(tag, "repeat")) parts.push('"repeat":' + Json.stringify(Std.string(Reflect.field(tag, "repeat"))));

			var own:Dynamic = fmceAnims == null ? null : Reflect.field(fmceAnims, name);
			if (own != null)
			{
				for (key in ["fps", "loop", "scale", "bilinear"])
					if (Reflect.hasField(own, key)) parts.push('"' + key + '":' + Json.stringify(Reflect.field(own, key)));
				var offset:Dynamic = Reflect.field(own, "offset");
				if (offset != null) parts.push('"offset":[' + Json.stringify(Reflect.field(offset, "x")) + ',' + Json.stringify(Reflect.field(offset, "y")) + ']');
			}
			animLines.push("{" + parts.join(",") + "}");
		}
		var tail:Array<String> = [];
		tail.push('\t"anims": [' + (animLines.length == 0 ? "" : '\n\t\t' + animLines.join(",\n\t\t") + '\n\t') + ']');
		if (anyExtraMeta) tail.push('\t"meta": ' + Json.stringify(extraMeta));
		if (anyExtraFmce) tail.push('\t"fmceExtra": ' + Json.stringify(extraFmce));

		return "{\n" + out.join("\n") + "\n" + tail.join(",\n") + "\n}\n";
	}

	/** Compara lo que de verdad usa el juego de dos sprite.json (ya expandidos): frames, tags y datos fmce. */
	public static function sameContent(a:Dynamic, b:Dynamic):Bool
		return signature(a) == signature(b);

	static function signature(data:Dynamic):String
	{
		var legacy = expand(data);
		var frames:Array<Dynamic> = arr(Reflect.field(legacy, "frames"));
		var sb = new StringBuf();
		for (f in frames)
		{
			var fr:Dynamic = Reflect.field(f, "frame");
			var ss:Dynamic = Reflect.field(f, "spriteSourceSize");
			var sz:Dynamic = Reflect.field(f, "sourceSize");
			sb.add(([
				str(Reflect.field(f, "filename"), ""),
				int(Reflect.field(fr, "x"), 0), int(Reflect.field(fr, "y"), 0), int(Reflect.field(fr, "w"), 0), int(Reflect.field(fr, "h"), 0),
				Reflect.field(f, "rotated") == true,
				int(Reflect.field(ss, "x"), 0), int(Reflect.field(ss, "y"), 0), int(Reflect.field(ss, "w"), 0), int(Reflect.field(ss, "h"), 0),
				int(Reflect.field(sz, "w"), 0), int(Reflect.field(sz, "h"), 0),
				int(Reflect.field(f, "duration"), DEFAULT_DURATION), int(Reflect.field(f, "page"), 0)
			] : Array<Dynamic>).join(",") + "|");
		}
		var meta:Dynamic = Reflect.field(legacy, "meta");
		sb.add("#" + Json.stringify(sortedCopy(Reflect.field(meta, "frameTags"))));
		sb.add("#" + Json.stringify(sortedCopy(Reflect.field(meta, "fmce"))));
		sb.add("#" + str(Reflect.field(meta, "image"), ""));
		var size:Dynamic = Reflect.field(meta, "size");
		sb.add("#" + int(Reflect.field(size, "w"), 0) + "x" + int(Reflect.field(size, "h"), 0));
		sb.add("#" + Json.stringify(sortedCopy(Reflect.field(meta, "pages"))));
		return sb.toString();
	}

	static function sortedCopy(value:Dynamic):Dynamic
	{
		if (value == null) return null;
		if (Std.isOfType(value, Array)) return [for (item in (value : Array<Dynamic>)) sortedCopy(item)];
		if (Std.isOfType(value, String) || Std.isOfType(value, Float) || Std.isOfType(value, Bool)) return value;
		var out:Array<Dynamic> = [];
		var keys = Reflect.fields(value);
		keys.sort(Reflect.compare);
		for (key in keys) out.push([key, sortedCopy(Reflect.field(value, key))]);
		return out;
	}

	static function expectedName(index:Int, tags:Array<Dynamic>):String
	{
		for (tag in tags)
		{
			var from = int(Reflect.field(tag, "from"), 0);
			var to = int(Reflect.field(tag, "to"), from);
			if (index >= from && index <= to) return str(Reflect.field(tag, "name"), "") + StringTools.lpad(Std.string(index - from), "0", 4);
		}
		return "frame" + StringTools.lpad(Std.string(index), "0", 4);
	}

	static function namesMatch(names:Array<String>, tags:Array<Dynamic>):Bool
	{
		for (i in 0...names.length)
			if (names[i] != expectedName(i, tags)) return false;
		return true;
	}

	static function namesOf(data:Dynamic, count:Int, anims:Array<Dynamic>):Array<String>
	{
		var explicit:Dynamic = Reflect.field(data, "names");
		if (Std.isOfType(explicit, Array) && (explicit : Array<Dynamic>).length == count) return [for (n in (explicit : Array<Dynamic>)) Std.string(n)];
		return [for (i in 0...count) expectedName(i, anims)];
	}

	public static function encodeSlots(slots:Array<Int>):String
	{
		var out:Array<String> = [];
		var i = 0;
		while (i < slots.length)
		{
			var v = slots[i];
			var j = i;
			while (j + 1 < slots.length && slots[j + 1] == v) j++;
			if (j - i + 1 >= 3)
			{
				out.push(v + "*" + (j - i + 1));
				i = j + 1;
				continue;
			}
			j = i;
			while (j + 1 < slots.length && slots[j + 1] == slots[j] + 1) j++;
			if (j - i + 1 >= 3)
			{
				out.push(v + "-" + slots[j]);
				i = j + 1;
				continue;
			}
			out.push(Std.string(v));
			i++;
		}
		return out.join(", ");
	}

	public static function decodeSlots(value:Dynamic, rectCount:Int):Array<Int>
	{
		var tokens:Array<String> = tokensOf(value);
		var out:Array<Int> = [];
		for (token in tokens)
		{
			var star = token.indexOf("*");
			var dash = token.indexOf("-", 1);
			if (star > 0)
			{
				var v = parseInt(token.substr(0, star), token);
				var n = parseInt(token.substr(star + 1), token);
				for (_ in 0...n) out.push(v);
			}
			else if (dash > 0)
			{
				var a = parseInt(token.substr(0, dash), token);
				var b = parseInt(token.substr(dash + 1), token);
				if (a <= b) for (v in a...b + 1) out.push(v);
				else
				{
					var v = a;
					while (v >= b) out.push(v--);
				}
			}
			else
				out.push(parseInt(token, token));
		}
		for (v in out)
			if (v < 0 || v >= rectCount) throw 'sprite.json: el frame apunta al rect $v pero solo hay $rectCount';
		return out;
	}

	static function encodeValues(values:Array<Int>):String
	{
		var out:Array<String> = [];
		var i = 0;
		while (i < values.length)
		{
			var j = i;
			while (j + 1 < values.length && values[j + 1] == values[i]) j++;
			out.push(j > i ? values[i] + "*" + (j - i + 1) : Std.string(values[i]));
			i = j + 1;
		}
		return out.join(", ");
	}

	static function decodeValues(value:Dynamic, count:Int):Array<Int>
	{
		var out:Array<Int> = [];
		for (token in tokensOf(value))
		{
			var star = token.indexOf("*");
			if (star > 0)
			{
				var v = parseInt(token.substr(0, star), token);
				for (_ in 0...parseInt(token.substr(star + 1), token)) out.push(v);
			}
			else
				out.push(parseInt(token, token));
		}
		if (out.length != count) throw 'sprite.json: "durations" tiene ${out.length} valores y hay $count frames';
		return out;
	}

	static function tokensOf(value:Dynamic):Array<String>
	{
		var out:Array<String> = [];
		if (Std.isOfType(value, String))
		{
			for (part in (value : String).split(","))
			{
				var t = StringTools.trim(part);
				if (t != "") out.push(t);
			}
		}
		else if (Std.isOfType(value, Array))
		{
			for (item in (value : Array<Dynamic>))
				for (part in Std.string(item).split(","))
				{
					var t = StringTools.trim(part);
					if (t != "") out.push(t);
				}
		}
		return out;
	}

	static function parseInt(text:String, token:String):Int
	{
		var v = Std.parseInt(StringTools.trim(text));
		if (v == null) throw 'sprite.json: "$token" no es un numero valido';
		return v;
	}

	#if sys

	public static function readFile(path:String):Dynamic
		return parse(File.getContent(path));

	/**
	 * Pasa un sprite.json Aseprite al formato compacto. Antes de escribir comprueba que al volver a leerlo queda IGUAL
	 * (frames, tags y datos fmce); si no, no toca el archivo.
	 * Devuelve los bytes que se ahorraron, o -1 si no hacia falta o no se pudo.
	 */
	public static function migrateFile(path:String):Int
	{
		try
		{
			if (!FileSystem.exists(path)) return -1;
			var text = File.getContent(path);
			var plain = text.length > 0 && text.charCodeAt(0) == 0xFEFF ? text.substr(1) : text;
			var data:Dynamic = Json.parse(plain);
			if (isCompact(data) || !Std.isOfType(Reflect.field(data, "frames"), Array) || (Reflect.field(data, "frames") : Array<Dynamic>).length == 0) return -1;

			var compact = stringify(data);
			if (!sameContent(data, parse(compact))) return -1;

			File.saveContent(path + ".tmp", compact);
			FileSystem.rename(path + ".tmp", path);
			return text.length - compact.length;
		}
		catch (e:Dynamic)
		{
			return -1;
		}
	}

	/** Compacta todos los sprite.json Aseprite que haya bajo `root`. Devuelve cuantos archivos cambio. */
	public static function migrateTree(root:String, depth:Int = 0):Int
	{
		if (depth > 12 || !FileSystem.exists(root) || !FileSystem.isDirectory(root)) return 0;
		var count = 0;
		for (entry in FileSystem.readDirectory(root))
		{
			var path = Path.join([root, entry]);
			if (FileSystem.isDirectory(path)) count += migrateTree(path, depth + 1);
			else if (entry == "sprite.json" && migrateFile(path) >= 0) count++;
		}
		return count;
	}
	#end

	static function arr(value:Dynamic):Array<Dynamic>
		return Std.isOfType(value, Array) ? cast value : [];

	static function int(value:Dynamic, fallback:Int):Int
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : Math.round(parsed);
	}

	static function str(value:Dynamic, fallback:String):String
		return value == null ? fallback : Std.string(value);
}
