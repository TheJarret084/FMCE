package funky.backend.converter;

import haxe.Json;

typedef AsepriteConversion = {

	var json:String;
	var frames:Int;
	var tags:Int;
	var warnings:Array<String>;
}

private typedef RawFrame = {
	var name:String;
	var prefix:String;
	var index:Int;
	var order:Int;

	var x:Int;
	var y:Int;
	var w:Int;
	var h:Int;

	var trimmed:Bool;
	var fx:Int;
	var fy:Int;
	var fw:Int;
	var fh:Int;
	var rotated:Bool;
}

class SparrowToAseprite
{

	public static inline var DEFAULT_FPS:Float = 24;

	static final TRAILING_INDEX:EReg = ~/^(.*?)(\d+)$/;

	public static function convert(xmlText:String, imageName:String, ?config:Dynamic, imageWidth:Int = 0, imageHeight:Int = 0):AsepriteConversion
	{
		var warnings:Array<String> = [];
		var root = findAtlasRoot(xmlText);
		if (root == null) throw "no es un TextureAtlas Sparrow (falta el elemento raiz)";

		var raw:Array<RawFrame> = [];
		var order = 0;
		for (el in root.elementsNamed("SubTexture"))
		{
			var name = el.get("name");
			if (name == null || name == "")
			{
				warnings.push("SubTexture sin nombre, se ignora");
				continue;
			}
			if (el.get("width") == null && el.get("w") != null)
				throw "Sparrow v1 no esta soportado (usa width/height, no w/h)";

			var trimmed = el.get("frameX") != null;
			var w = intAttr(el, "width", 0, name, warnings);
			var h = intAttr(el, "height", 0, name, warnings);
			var fx = trimmed ? intAttr(el, "frameX", 0, name, warnings) : 0;
			var fy = trimmed ? intAttr(el, "frameY", 0, name, warnings) : 0;
			var fw = trimmed ? intAttr(el, "frameWidth", w, name, warnings) : w;
			var fh = trimmed ? intAttr(el, "frameHeight", h, name, warnings) : h;
			var rotated = el.get("rotated") == "true";

			if (el.get("flipX") == "true" || el.get("flipY") == "true")
				warnings.push('$name: flipX/flipY no existe en Aseprite, se pierde');

			if (w <= 0 || h <= 0)
			{

				warnings.push('$name: frame de tamano 0, se guarda como 1x1');
				w = 1;
				h = 1;
				if (!trimmed) { fw = 1; fh = 1; }
			}

			var prefix = name;
			var index = 0;
			if (TRAILING_INDEX.match(name))
			{
				prefix = TRAILING_INDEX.matched(1);
				var parsedIndex:Null<Int> = Std.parseInt(TRAILING_INDEX.matched(2));
				index = parsedIndex != null ? parsedIndex : 0;
			}
			if (prefix == "") prefix = "frame";

			raw.push({
				name: name, prefix: prefix, index: index, order: order++,
				x: intAttr(el, "x", 0, name, warnings), y: intAttr(el, "y", 0, name, warnings), w: w, h: h,
				trimmed: trimmed, fx: fx, fy: fy, fw: fw, fh: fh, rotated: rotated
			});
		}

		if (raw.length == 0) throw "el atlas no tiene ningun SubTexture";

		var groupOrder:Array<String> = [];
		var groups = new Map<String, Array<RawFrame>>();
		for (frame in raw)
		{
			if (!groups.exists(frame.prefix))
			{
				groups.set(frame.prefix, []);
				groupOrder.push(frame.prefix);
			}
			groups.get(frame.prefix).push(frame);
		}
		for (prefix in groupOrder)
			groups.get(prefix).sort(function(a, b) return a.index != b.index ? a.index - b.index : a.order - b.order);

		var animConfig = new Map<String, Dynamic>();
		if (config != null && Std.isOfType(Reflect.field(config, "data"), Array))
		{
			for (entry in (cast Reflect.field(config, "data"):Array<Dynamic>))
			{

				var entryName = Reflect.hasField(entry, "anim") ? Reflect.field(entry, "anim") : Reflect.field(entry, "name");
				if (entryName != null) animConfig.set(Std.string(entryName), entry);
			}
		}

		var frames:Array<Dynamic> = [];
		var tags:Array<Dynamic> = [];
		var fmceAnimations:Dynamic = {};
		var maxRight = 0;
		var maxBottom = 0;

		for (prefix in groupOrder)
		{
			var group = groups.get(prefix);
			var cfg = animConfig.get(prefix);

			var spd = cfg != null ? number(Reflect.field(cfg, "spd"), 1) : 1;
			if (spd <= 0) spd = 1;
			var fps = DEFAULT_FPS * spd;
			var duration = Math.round(1000 / fps);
			var loop = cfg != null && Reflect.hasField(cfg, "loop") ? Reflect.field(cfg, "loop") == true : true;

			if (cfg != null)
			{
				var declared = Std.int(number(Reflect.field(cfg, "num"), group.length));
				if (declared != group.length)
					warnings.push('$prefix: config.json dice ${declared} frames pero el XML tiene ${group.length}');
			}

			var from = frames.length;
			for (frame in group)
			{

				var jw = frame.rotated ? frame.h : frame.w;
				var jh = frame.rotated ? frame.w : frame.h;

				var sourceW = frame.trimmed ? frame.fw : jw;
				var sourceH = frame.trimmed ? frame.fh : jh;
				var offsetX = frame.trimmed ? -frame.fx : 0;
				var offsetY = frame.trimmed ? -frame.fy : 0;

				frames.push({
					filename: frame.name,
					frame: {x: frame.x, y: frame.y, w: jw, h: jh},
					rotated: frame.rotated,
					trimmed: frame.trimmed && (offsetX != 0 || offsetY != 0 || sourceW != jw || sourceH != jh),
					spriteSourceSize: {x: offsetX, y: offsetY, w: jw, h: jh},
					sourceSize: {w: sourceW, h: sourceH},
					duration: duration
				});

				var right = frame.x + frame.w;
				var bottom = frame.y + frame.h;
				if (right > maxRight) maxRight = right;
				if (bottom > maxBottom) maxBottom = bottom;
			}

			var tag:Dynamic = {name: prefix, from: from, to: frames.length - 1, direction: "forward"};

			if (!loop) Reflect.setField(tag, "repeat", "1");
			tags.push(tag);

			var meta:Dynamic = {fps: fps, loop: loop};
			if (cfg != null)
			{
				var offset = Reflect.field(cfg, "offset");
				if (offset != null) Reflect.setField(meta, "offset", {x: number(Reflect.field(offset, "x"), 0), y: number(Reflect.field(offset, "y"), 0)});
				if (Reflect.hasField(cfg, "scale")) Reflect.setField(meta, "scale", number(Reflect.field(cfg, "scale"), 1));
				if (Reflect.hasField(cfg, "bilinear")) Reflect.setField(meta, "bilinear", Reflect.field(cfg, "bilinear") == true);
			}
			Reflect.setField(fmceAnimations, prefix, meta);
		}

		var atlasW = imageWidth > 0 ? imageWidth : attrInt(root, "width", maxRight);
		var atlasH = imageHeight > 0 ? imageHeight : attrInt(root, "height", maxBottom);
		if (imageWidth <= 0 && maxRight > atlasW) atlasW = maxRight;
		if (imageHeight <= 0 && maxBottom > atlasH) atlasH = maxBottom;

		var fmce:Dynamic = {source: "sparrow", animations: fmceAnimations};
		if (config != null)
		{
			if (Reflect.hasField(config, "type")) Reflect.setField(fmce, "type", Reflect.field(config, "type"));
			if (Reflect.hasField(config, "scale")) Reflect.setField(fmce, "scale", number(Reflect.field(config, "scale"), 1));
			if (Reflect.hasField(config, "bilinear")) Reflect.setField(fmce, "bilinear", Reflect.field(config, "bilinear") == true);
		}

		var out = {
			frames: frames,
			meta: {
				app: "FMCE SparrowToAseprite",
				version: "1.0",
				image: imageName,
				format: "RGBA8888",
				size: {w: atlasW, h: atlasH},
				scale: "1",
				frameTags: tags,
				fmce: fmce
			}
		};

		return {json: Json.stringify(out, null, "\t"), frames: frames.length, tags: tags.length, warnings: warnings};
	}

	public static function prefixes(xmlText:String):Array<String>
	{
		var out:Array<String> = [];
		var root = findAtlasRoot(xmlText);
		if (root == null) return out;
		for (el in root.elementsNamed("SubTexture"))
		{
			var name = el.get("name");
			if (name == null || name == "") continue;
			var prefix = TRAILING_INDEX.match(name) ? TRAILING_INDEX.matched(1) : name;
			if (prefix == "") prefix = "frame";
			if (!out.contains(prefix)) out.push(prefix);
		}
		return out;
	}

	public static function declaredImage(xmlText:String):Null<String>
	{
		var root = findAtlasRoot(xmlText);
		return root == null ? null : root.get("imagePath");
	}

	public static function isSparrow(xmlText:String):Bool
	{
		try return findAtlasRoot(xmlText) != null catch (_:Dynamic) return false;
	}

	static function findAtlasRoot(xmlText:String):Null<Xml>
	{
		var doc = Xml.parse(xmlText);
		for (el in doc.elements()) if (el.nodeName == "TextureAtlas") return el;
		return null;
	}

	static function intAttr(el:Xml, key:String, fallback:Int, frameName:String, warnings:Array<String>):Int
	{
		var value = el.get(key);
		if (value == null) return fallback;
		var parsed = Std.parseFloat(value);
		if (Math.isNaN(parsed)) return fallback;
		if (parsed != Math.ffloor(parsed))
			warnings.push('$frameName: $key=$value no es entero, se redondea');
		return Math.round(parsed);
	}

	static function attrInt(el:Xml, key:String, fallback:Int):Int
	{
		var value = el.get(key);
		if (value == null) return fallback;
		var parsed = Std.parseInt(value);
		return parsed == null ? fallback : parsed;
	}

	static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}
