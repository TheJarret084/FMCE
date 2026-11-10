package funky.backend.converter;

import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import funky.backend.converter.AnimateAtlas.AnimateTimeline;
import funky.backend.converter.AnimateAtlas.DrawOp;
import funky.backend.FunkinVideoSprite;
import funky.backend.converter.VideoStrip.VideoClip;
#if (sys && !android)
import funky.backend.converter.VideoStrip.VideoStripTask;
#end
import funky.core.JsonLoose;

#if sys
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;
#end

/** Un sprite de `sprites/<nombre>/` -> tiras `<i>.png` + `sprite.json` nativo de FNMM. */
class FNMMSpriteExport
{
	public var name(default, null):String;
	public var label(default, null):String = "";
	public var done(default, null):Bool = false;
	public var ok(default, null):Bool = false;
	public var error(default, null):Null<String> = null;
	public var warnings(default, null):Array<String> = [];
	public var fraction(get, never):Float;
	/** Archivos listos para el zip; el job los escribe y vacia la lista. */
	public var pending:Array<{path:String, bytes:Bytes}> = [];

	#if sys
	var dir:String;
	var base:String;
	var phase:Int = 0;
	var index:Int = 0;
	var nativeFiles:Array<String> = [];
	var frames:Array<Dynamic> = [];
	var pageFiles:Array<String> = [];
	var pages:Map<Int, BitmapData> = new Map<Int, BitmapData>();
	var anims:Array<{frames:Array<Dynamic>, cfg:Dynamic}> = [];
	var outData:Array<Dynamic> = [];
	/** Pagina del atlas -> ultima tira que la usa (despues de esa se libera su bitmap). */
	var lastUse:Map<Int, Int> = new Map<Int, Int>();
	/** Atlas de Adobe Animate (`sprites/<n>/sprite/Animation.json`): se desarma en frames y se arman las tiras. */
	var animate:Null<AnimateAtlas>;
	var animateDir:String;
	var jobs:Array<{name:String, cfg:Dynamic, tl:AnimateTimeline, frames:Array<Int>}> = [];
	var cutouts:Map<String, Null<BitmapData>> = new Map<String, Null<BitmapData>>();
	/** Sprite de video (`config.json` type video): cada video sale como una tira. */
	var videoClips:Array<VideoClip> = [];
	var ffmpeg:Null<String> = null;
	#if !android
	var videoTask:Null<VideoStripTask> = null;
	#end
	#end

	public function new(levelDir:String, name:String)
	{
		this.name = name;
		#if sys
		this.dir = Path.join([levelDir, "sprites", name]);
		this.base = "sprites/" + name + "/";
		#else
		error = "necesita sys";
		done = true;
		#end
	}

	function get_fraction():Float
	{
		#if sys
		if (phase == 4 && jobs.length > 0) return index / jobs.length;
		#if !android
		if (phase == 5 && videoClips.length > 0) return (index + (videoTask != null ? videoTask.fraction : 0)) / videoClips.length;
		#end
		return phase == 1 && anims.length > 0 ? index / anims.length : 0;
		#else
		return 0;
		#end
	}

	public function step():Bool
	{
		#if sys
		if (done) return false;
		try
		{
			switch (phase)
			{
				case 0: open();
				case 1: stepAnim();
				case 2: finishAtlas();
				case 4: stepAnimate();
				case 5: stepVideo();
				default: stepNative();
			}
		}
		catch (e:Dynamic)
		{
			error = Std.string(e);
			dispose();
			done = true;
		}
		#end
		return !done;
	}

	public function dispose():Void
	{
		#if sys
		for (bitmap in pages) bitmap.dispose();
		pages = new Map<Int, BitmapData>();
		for (bitmap in cutouts) if (bitmap != null) bitmap.dispose();
		cutouts = new Map<String, Null<BitmapData>>();
		#if !android
		if (videoTask != null)
		{
			videoTask.dispose();
			videoTask = null;
		}
		#end
		#end
	}

	#if sys
	function open():Void
	{
		label = "abriendo";
		// El .FNMM no tiene video: cada video del sprite sale como una tira (ffmpeg + FunkFMPEG). Es video si el motor lo
		// consideraria video (config.json type "video", o carpeta con .mp4 y sin sprite.png).
		if (FunkinVideoSprite.readInfo(dir) != null)
		{
			openVideo();
			return;
		}
		for (entry in FileSystem.readDirectory(dir))
		{
			var lower = entry.toLowerCase();
			if (StringTools.endsWith(lower, ".mp4") || StringTools.endsWith(lower, ".webm"))
				warnings.push("el video " + entry + " no se usa en el juego (el sprite no es de tipo video) y no entra al .FNMM");
		}

		// ya viene en formato FNMM (tiras + sprite.json con `data`): se copia tal cual
		if (FNMMSpriteImporter.isNative(dir))
		{
			var native:Dynamic = JsonLoose.parse(File.getContent(Path.join([dir, "sprite.json"])));
			nativeFiles = ["sprite.json"];
			for (i in 0...(cast Reflect.field(native, "data"):Array<Dynamic>).length) nativeFiles.push(i + ".png");
			phase = 3;
			return;
		}

		animateDir = Path.join([dir, "sprite"]);
		if (FileSystem.exists(Path.join([animateDir, "Animation.json"])))
		{
			openAnimate();
			return;
		}

		var jsonPath = Path.join([dir, "sprite.json"]);
		if (!FileSystem.exists(jsonPath)) throw "no tiene sprite.json";
		var atlas:Dynamic = JsonLoose.parse(File.getContent(jsonPath));
		frames = framesOf(atlas);
		if (frames.length == 0) throw "el atlas no tiene frames";

		var meta = Reflect.field(atlas, "meta");
		var pageInfo = FMCEToFNMMExporter.field(meta, "pages");
		if (Std.isOfType(pageInfo, Array) && (cast pageInfo:Array<Dynamic>).length > 0)
			for (page in (cast pageInfo:Array<Dynamic>)) pageFiles.push(FMCEToFNMMExporter.text(Reflect.field(page, "image"), "sprite.png"));
		else
			pageFiles.push("sprite.png");

		var tags:Array<Dynamic> = [];
		var rawTags = FMCEToFNMMExporter.field(meta, "frameTags");
		if (Std.isOfType(rawTags, Array)) tags = cast rawTags;

		var config:Dynamic = null;
		var configPath = Path.join([dir, "config.json"]);
		if (FileSystem.exists(configPath))
		{
			try config = JsonLoose.parse(File.getContent(configPath)) catch (_:Dynamic) warnings.push("config.json ilegible: se usan los tags del atlas");
		}
		var list = FMCEToFNMMExporter.field(config, "data");
		if (Std.isOfType(list, Array) && (cast list:Array<Dynamic>).length > 0) fromConfig(cast list, tags);
		else fromTags(tags);

		if (anims.length == 0) throw "no quedo ninguna animacion";
		for (i in 0...anims.length)
			for (frame in anims[i].frames) lastUse.set(pageKey(frame), i);
		phase = 1;
	}

	// ------------------------------------------------------------------ atlas de Animate

	/** Lee Animation.json + spritemaps y arma la lista de animaciones a exportar (solo las del config.json: lo demas no se toca). */
	function openAnimate():Void
	{
		label = "atlas de Animate";
		var maps:Array<{file:String, text:String}> = [];
		var names = [for (e in FileSystem.readDirectory(animateDir)) if (~/^spritemap\d*\.json$/i.match(e)) e];
		names.sort(function(a, b) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
		for (n in names) maps.push({file: n, text: File.getContent(Path.join([animateDir, n]))});
		if (maps.length == 0) throw "el atlas de Animate no tiene spritemap*.json";

		var atlas = AnimateAtlas.parse(File.getContent(Path.join([animateDir, "Animation.json"])), maps);
		animate = atlas;
		pageFiles = atlas.pages;
		for (w in atlas.warnings) if (warnings.indexOf(w) < 0) warnings.push(w);

		var config:Dynamic = null;
		var configPath = Path.join([dir, "config.json"]);
		if (FileSystem.exists(configPath))
		{
			try config = JsonLoose.parse(File.getContent(configPath)) catch (_:Dynamic) warnings.push("config.json ilegible: se exportan los labels del atlas");
		}
		var list = FMCEToFNMMExporter.field(config, "data");
		var entries:Array<Dynamic> = [];
		if (Std.isOfType(list, Array) && (cast list:Array<Dynamic>).length > 0)
		{
			var raw:Array<Dynamic> = cast list;
			var order = [for (i in 0...raw.length) {entry: raw[i], at: i}];
			order.sort(function(a, b)
			{
				var ia = FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(a.entry, "index"), a.at);
				var ib = FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(b.entry, "index"), b.at);
				return ia < ib ? -1 : (ia > ib ? 1 : a.at - b.at);
			});
			entries = [for (o in order) o.entry];
		}
		else
		{
			// sin config.json: un label del escenario = una animacion; sin labels, el escenario entero
			var labels = atlas.labels();
			if (labels.length > 0) entries = [for (l in labels) {name: l}];
			else entries = [{name: ""}];
			warnings.push("no hay config.json con animaciones: se exporta " + (labels.length > 0 ? "cada label del atlas" : "el escenario completo"));
		}

		for (entry in entries)
		{
			var wanted = FMCEToFNMMExporter.text(FMCEToFNMMExporter.field(entry, "name"), FMCEToFNMMExporter.text(FMCEToFNMMExporter.field(entry, "anim"), ""));
			var tl:Null<AnimateTimeline> = null;
			var from = 0;
			var to = 0;
			if (wanted == "")
			{
				tl = atlas.stage;
				to = atlas.stage.length;
			}
			else if (atlas.symbol(wanted) != null)
			{
				tl = atlas.symbol(wanted);
				to = tl.length;
			}
			else
			{
				var range = atlas.labelRange(wanted);
				if (range != null)
				{
					tl = atlas.stage;
					from = range.from;
					to = range.to;
				}
			}
			if (tl == null || to <= from)
			{
				// se deja vacia (no se borra) para que las animaciones de abajo conserven su numero
				warnings.push("'" + wanted + "' no es un simbolo ni un label del atlas: sale una animacion vacia");
				tl = new AnimateTimeline();
				from = 0;
				to = 1;
			}

			// `indices` (si hay) elige y ordena frames de la animacion; sin ellos van todos
			var frames:Array<Int> = [];
			var indices = FMCEToFNMMExporter.field(entry, "indices");
			if (Std.isOfType(indices, Array) && (cast indices:Array<Dynamic>).length > 0)
				for (v in (cast indices:Array<Dynamic>))
				{
					var at = Std.int(FMCEToFNMMExporter.num(v, -1));
					if (at >= 0 && from + at < to) frames.push(from + at);
				}
			if (frames.length == 0) for (f in from...to) frames.push(f);

			// sin velocidad en el config.json se usa la del atlas
			var cfg:Dynamic = {};
			for (k in Reflect.fields(entry)) Reflect.setField(cfg, k, Reflect.field(entry, k));
			if (FMCEToFNMMExporter.field(cfg, "spd") == null)
			{
				Reflect.setField(cfg, "spd", atlas.fps);
				Reflect.setField(cfg, "spd_fps", true);
			}
			jobs.push({name: wanted == "" ? "escenario" : wanted, cfg: cfg, tl: tl, frames: frames});
		}
		if (jobs.length == 0) throw "no quedo ninguna animacion del atlas";
		phase = 4;
	}

	/** Recorte del atlas de un sprite (se corta una vez y se reutiliza). */
	function cutout(sprite:String):Null<BitmapData>
	{
		if (cutouts.exists(sprite)) return cutouts.get(sprite);
		var info = animate.sprites.get(sprite);
		var result:Null<BitmapData> = null;
		if (info != null && info.w > 0 && info.h > 0)
		{
			var page = pageBitmap(info.page);
			var w = info.rotated ? info.h : info.w;
			var h = info.rotated ? info.w : info.h;
			result = new BitmapData(w, h, true, 0x00000000);
			result.copyPixels(page, new Rectangle(info.x, info.y, w, h), new Point(0, 0));
			if (info.rotated) warnings.push("el sprite '" + sprite + "' esta rotado en el atlas: puede verse mal");
		}
		else
			warnings.push("el atlas no tiene el sprite '" + sprite + "'");
		cutouts.set(sprite, result);
		return result;
	}

	/** Una animacion del atlas de Animate -> una tira (solo se dibujan los simbolos de esa animacion, y se recorta lo vacio). */
	function stepAnimate():Void
	{
		if (index >= jobs.length)
		{
			phase = 2;
			return;
		}
		var i = index++;
		var job = jobs[i];
		label = job.name;
		var atlas = animate;
		var identity = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0];

		var frameOps = [for (f in job.frames) atlas.ops(job.tl, f, identity)];
		var x0 = 1.0e9;
		var y0 = 1.0e9;
		var x1 = -1.0e9;
		var y1 = -1.0e9;
		for (ops in frameOps)
		{
			var b = atlas.bounds(ops);
			if (b == null) continue;
			if (b.x0 < x0) x0 = b.x0;
			if (b.y0 < y0) y0 = b.y0;
			if (b.x1 > x1) x1 = b.x1;
			if (b.y1 > y1) y1 = b.y1;
		}
		if (x1 < x0)
		{
			// no dibuja nada: sale una tira transparente de 1 px para no correr los numeros de las demas animaciones
			warnings.push("la animacion '" + job.name + "' no dibuja nada");
			x0 = y0 = 0;
			x1 = y1 = 1;
		}
		var bx = Std.int(Math.floor(x0));
		var by = Std.int(Math.floor(y0));
		var bw = Std.int(Math.max(1, Math.ceil(x1) - bx));
		var bh = Std.int(Math.max(1, Math.ceil(y1) - by));

		// un frame de Animate puede medir cientos de px: si la tira no cabe (o pesa demasiado) se dibuja mas chica y el
		// `scale` y el pivote del config se corrigen, asi el sprite se ve igual de grande en el juego
		var shrink = shrinkFor(bw, bh, job.frames.length);
		if (shrink < 1) warnings.push("'" + job.name + "' se exporta al " + Math.round(shrink * 100) + "% de su tamano para que entre en la tira");
		var cw = Std.int(Math.max(1, Math.ceil(bw * shrink)));
		var ch = Std.int(Math.max(1, Math.ceil(bh * shrink)));
		var originX = bx * shrink;
		var originY = by * shrink;

		// 1) cada frame en un lienzo; los frames iguales se dibujan una sola vez
		var unique = new Map<String, BitmapData>();
		var canvases:Array<BitmapData> = [];
		for (ops in frameOps)
		{
			var key = signature(ops);
			var canvas = unique.get(key);
			if (canvas == null)
			{
				canvas = new BitmapData(cw, ch, true, 0x00000000);
				for (op in ops)
				{
					var piece = cutout(op.sprite);
					if (piece == null) continue;
					var color:Null<ColorTransform> = op.fx == null ? null : new ColorTransform(op.fx.rm, op.fx.gm, op.fx.bm, op.fx.am, op.fx.ro, op.fx.go, op.fx.bo, op.fx.ao);
					canvas.draw(piece, new Matrix(op.a * shrink, op.b * shrink, op.c * shrink, op.d * shrink, op.tx * shrink - originX, op.ty * shrink - originY), color, null, null, true);
				}
				unique.set(key, canvas);
			}
			canvases.push(canvas);
		}

		// 2) recorte: la union de lo que de verdad se pinto en todos los frames
		var area:Null<Rectangle> = null;
		for (canvas in unique)
		{
			var painted = canvas.getColorBoundsRect(0xFF000000, 0x00000000, false);
			if (painted.width < 1 || painted.height < 1) continue;
			area = area == null ? painted : area.union(painted);
		}
		if (area == null) area = new Rectangle(0, 0, 1, 1);
		var cellW = Std.int(area.width);
		var cellH = Std.int(area.height);

		// 3) la tira
		var strip = new BitmapData(cellW * canvases.length, cellH, true, 0x00000000);
		for (k in 0...canvases.length) strip.copyPixels(canvases[k], area, new Point(k * cellW, 0));
		var bytes:Bytes = FMCEToFNMMExporter.encodePng(strip);
		strip.dispose();
		for (canvas in unique) canvas.dispose();

		// la tira lleva el numero de su lugar en `data` (asi no se descuadran si falta alguna)
		pending.push({path: base + outData.length + ".png", bytes: bytes});
		// el pivote se mide desde el origen del simbolo; la esquina de la celda esta en (origen + area) y todo va a la escala `shrink`
		outData.push(animEntry(scaledCfg(job.cfg, shrink), canvases.length, originX + area.x, originY + area.y));
	}

	/** Cuanto se reduce una tira para que entre en FNMM_MAX_SIDE / MAX_PIXELS (nunca agranda: 1 = a su tamano real). */
	function shrinkFor(cellW:Int, cellH:Int, frames:Int):Float
		return AnimateAtlas.fitScale(cellW, cellH, frames, FMCEToFNMMExporter.FNMM_MAX_SIDE, FMCEToFNMMExporter.MAX_PIXELS);

	/** El config de la animacion para una tira dibujada a `shrink`: pivote mas chico y `scale` mas grande, asi se ve igual. */
	function scaledCfg(cfg:Dynamic, shrink:Float):Dynamic
	{
		if (shrink >= 1) return cfg;
		var copy:Dynamic = {};
		if (cfg != null) for (k in Reflect.fields(cfg)) Reflect.setField(copy, k, Reflect.field(cfg, k));
		var pivot = FMCEToFNMMExporter.field(copy, "offset");
		Reflect.setField(copy, "offset", {x: FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(pivot, "x"), 0) * shrink, y: FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(pivot, "y"), 0) * shrink});
		Reflect.setField(copy, "scale", FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(copy, "scale"), 1) / shrink);
		return copy;
	}

	/** Identifica un frame por lo que dibuja (para no dibujar dos veces frames iguales). */
	static function signature(ops:Array<DrawOp>):String
	{
		var b = new StringBuf();
		for (op in ops)
		{
			b.add(op.sprite);
			for (v in [op.a, op.b, op.c, op.d, op.tx, op.ty]) b.add("," + Math.round(v * 1000));
			if (op.fx != null) for (v in [op.fx.rm, op.fx.gm, op.fx.bm, op.fx.am, op.fx.ro, op.fx.go, op.fx.bo, op.fx.ao]) b.add("," + Math.round(v * 1000));
			b.add(";");
		}
		return b.toString();
	}

	/** Cada entrada del config.json es una tira; van en el orden de `index`, que es la posicion que usan los eventos. */
	function fromConfig(list:Array<Dynamic>, tags:Array<Dynamic>):Void
	{
		var order = [for (i in 0...list.length) i];
		order.sort(function(a:Int, b:Int):Int
		{
			var ia = FMCEToFNMMExporter.num(Reflect.field(list[a], "index"), a);
			var ib = FMCEToFNMMExporter.num(Reflect.field(list[b], "index"), b);
			return ia < ib ? -1 : (ia > ib ? 1 : a - b);
		});

		for (i in order)
		{
			var cfg = list[i];
			var tagName = FMCEToFNMMExporter.text(Reflect.field(cfg, "anim"), FMCEToFNMMExporter.text(Reflect.field(cfg, "name"), ""));
			var slice:Array<Dynamic> = [];
			var indices = Reflect.field(cfg, "indices");
			if (Std.isOfType(indices, Array) && (cast indices:Array<Dynamic>).length > 0)
			{
				// `indices` = frames del atlas tal cual (igual que en el juego): no necesita tag y pueden repetirse.
				for (value in (cast indices:Array<Dynamic>))
				{
					var at = Std.int(FMCEToFNMMExporter.num(value, -1));
					if (at >= 0 && at < frames.length) slice.push(frames[at]);
				}
				if (slice.length == 0)
				{
					warnings.push("la animacion '" + tagName + "' tiene indices que no existen en el atlas y se salta");
					continue;
				}
			}
			else
			{
				var range = rangeOf(tags, tagName);
				if (range == null && tags.length == 0 && list.length == 1) range = {from: 0, to: frames.length - 1};
				if (range == null)
				{
					warnings.push("la animacion '" + tagName + "' no tiene tag en el atlas y se salta");
					continue;
				}
				slice = frames.slice(range.from, range.to + 1);
			}
			if (slice.length > 0) anims.push({frames: slice, cfg: cfg});
		}
	}

	function fromTags(tags:Array<Dynamic>):Void
	{
		for (tag in tags)
		{
			var range = rangeOf([tag], FMCEToFNMMExporter.text(Reflect.field(tag, "name"), ""));
			if (range != null) anims.push({frames: frames.slice(range.from, range.to + 1), cfg: null});
		}
		if (anims.length == 0) anims.push({frames: frames, cfg: null});
		warnings.push("no tiene config.json: se exporta con offset 0 y velocidad 1");
	}

	function rangeOf(tags:Array<Dynamic>, tagName:String):Null<{from:Int, to:Int}>
	{
		for (tag in tags)
		{
			if (FMCEToFNMMExporter.text(Reflect.field(tag, "name"), "") != tagName) continue;
			var from = Std.int(FMCEToFNMMExporter.num(Reflect.field(tag, "from"), 0));
			var to = Std.int(FMCEToFNMMExporter.num(Reflect.field(tag, "to"), from));
			from = Std.int(Math.max(0, from));
			to = Std.int(Math.min(frames.length - 1, to));
			if (to >= from) return {from: from, to: to};
		}
		return null;
	}

	/** Aseprite puede traer `frames` como lista o como objeto {nombre: frame}. */
	static function framesOf(atlas:Dynamic):Array<Dynamic>
	{
		var raw:Dynamic = Reflect.field(atlas, "frames");
		if (Std.isOfType(raw, Array)) return cast raw;
		var out:Array<Dynamic> = [];
		if (raw != null && Reflect.isObject(raw))
			for (key in Reflect.fields(raw)) out.push(Reflect.field(raw, key));
		return out;
	}

	/** Una tira por llamada: los frames recortados del atlas vuelven a su lugar dentro de su celda original. */
	function stepAnim():Void
	{
		if (index >= anims.length)
		{
			phase = 2;
			return;
		}
		var i = index;
		index++;
		label = "tira " + index + "/" + anims.length;

		var list = anims[i].frames;

		// Zona visible de cada frame dentro de su celda original (`spriteSourceSize`). La celda de la tira es la union de todas.
		var minX = 1 << 30;
		var minY = 1 << 30;
		var maxX = 0;
		var maxY = 0;
		var fullW = 1;
		var fullH = 1;
		for (frame in list)
		{
			var size = Reflect.field(frame, "sourceSize");
			var box = Reflect.field(frame, "frame");
			var inner = Reflect.field(frame, "spriteSourceSize");
			var w = Std.int(FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(box, "w"), 0));
			var h = Std.int(FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(box, "h"), 0));
			fullW = Std.int(Math.max(fullW, FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(size, "w"), w)));
			fullH = Std.int(Math.max(fullH, FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(size, "h"), h)));
			if (w < 1 || h < 1) continue;
			var ix = Std.int(FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(inner, "x"), 0));
			var iy = Std.int(FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(inner, "y"), 0));
			minX = Std.int(Math.min(minX, ix));
			minY = Std.int(Math.min(minY, iy));
			maxX = Std.int(Math.max(maxX, ix + w));
			maxY = Std.int(Math.max(maxY, iy + h));
		}
		if (maxX <= minX || maxY <= minY)
		{
			// todos los frames vacios: una celda de 1x1
			minX = 0;
			minY = 0;
			maxX = 1;
			maxY = 1;
		}

		var cropX = 0;
		var cropY = 0;
		var cellW = Std.int(Math.max(fullW, maxX));
		var cellH = Std.int(Math.max(fullH, maxY));
		if (FMCEToFNMMExporter.CROP_CELLS)
		{
			cropX = minX;
			cropY = minY;
			cellW = maxX - minX;
			cellH = maxY - minY;
		}
		// resolucion de la tira: la que pide su uso en la escena, y siempre una que entre en un celular
		var shrink = shrinkFor(cellW, cellH, list.length);
		var sw = Std.int(Math.max(1, Math.ceil(cellW * shrink)));
		var sh = Std.int(Math.max(1, Math.ceil(cellH * shrink)));
		if (sw * list.length > FMCEToFNMMExporter.MAX_BITMAP || sh > FMCEToFNMMExporter.MAX_BITMAP)
			throw "la tira " + i + " mide " + (sw * list.length) + "x" + sh + " (maximo " + FMCEToFNMMExporter.MAX_BITMAP + ")";

		var strip = new BitmapData(sw * list.length, sh, true, 0x00000000);
		for (k in 0...list.length)
		{
			var frame = list[k];
			if (Reflect.field(frame, "rotated") == true) warnings.push("tira " + i + ": hay frames rotados, no se soportan");
			var box = Reflect.field(frame, "frame");
			var inner = Reflect.field(frame, "spriteSourceSize");
			var w = Std.int(FMCEToFNMMExporter.num(Reflect.field(box, "w"), 0));
			var h = Std.int(FMCEToFNMMExporter.num(Reflect.field(box, "h"), 0));
			if (w < 1 || h < 1) continue;
			var page = pageBitmap(pageKey(frame));
			var source = new Rectangle(FMCEToFNMMExporter.num(Reflect.field(box, "x"), 0), FMCEToFNMMExporter.num(Reflect.field(box, "y"), 0), w, h);
			var dx = FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(inner, "x"), 0) - cropX;
			var dy = FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(inner, "y"), 0) - cropY;
			if (shrink >= 1)
				strip.copyPixels(page, source, new Point(k * sw + dx, dy));
			else
			{
				// el recorte del frame se dibuja mas chico dentro de la tira
				var piece = new BitmapData(w, h, true, 0x00000000);
				piece.copyPixels(page, source, new Point(0, 0));
				strip.draw(piece, new Matrix(shrink, 0, 0, shrink, k * sw + dx * shrink, dy * shrink), null, null, null, true);
				piece.dispose();
			}
		}
		var bytes:Bytes = FMCEToFNMMExporter.encodePng(strip);
		strip.dispose();
		pending.push({path: base + i + ".png", bytes: bytes});
		outData.push(animEntry(scaledCfg(anims[i].cfg, shrink), list.length, cropX * shrink, cropY * shrink));

		// una pagina del atlas que ya no usa ninguna tira de las que faltan se libera (ahorra memoria en celulares)
		for (page in lastUse.keys())
			if (lastUse.get(page) == i && pages.exists(page))
			{
				pages.get(page).dispose();
				pages.remove(page);
			}
	}

	/** Pagina del atlas de un frame (si apunta a una que no existe, la 0, igual que `pageBitmap`). */
	function pageKey(frame:Dynamic):Int
	{
		var page = Std.int(FMCEToFNMMExporter.num(Reflect.field(frame, "page"), 0));
		return page >= 0 && page < pageFiles.length ? page : 0;
	}

	function pageBitmap(page:Int):BitmapData
	{
		if (pages.exists(page)) return pages.get(page);
		var file = page >= 0 && page < pageFiles.length ? pageFiles[page] : pageFiles[0];
		var path = Path.join([animate != null ? animateDir : dir, file]);
		if (!FileSystem.exists(path)) throw "falta la imagen " + file;
		var bitmap = BitmapData.fromFile(path);
		if (bitmap == null) throw "no se pudo leer " + file;
		pages.set(page, bitmap);
		return bitmap;
	}

	/** `spd` en FNMM es un multiplicador de 24 fps; en FMCE puede venir en fps crudos (`spd_fps`). */
	function animEntry(cfg:Dynamic, count:Int, cropX:Float, cropY:Float):Dynamic
	{
		var offset = FMCEToFNMMExporter.field(cfg, "offset");
		var spd = FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(cfg, "spd"), 1);
		if (FMCEToFNMMExporter.field(cfg, "spd_fps") == true) spd = spd / 24;
		return {
			// el pivote se mide desde la esquina de la celda: si la celda se recorto, se corre lo mismo
			offset: {x: FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(offset, "x"), 0) - cropX, y: FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(offset, "y"), 0) - cropY},
			num: count,
			spd: spd,
			spd_fps: false,
			scale: FMCEToFNMMExporter.num(FMCEToFNMMExporter.field(cfg, "scale"), 1),
			bilinear: FMCEToFNMMExporter.field(cfg, "bilinear") == true,
			loop: FMCEToFNMMExporter.field(cfg, "loop") != false
		};
	}

	// ------------------------------------------------------------------ video

	function openVideo():Void
	{
		#if android
		throw "exportar videos solo funciona en escritorio (hace falta ffmpeg)";
		#else
		label = "video";
		ffmpeg = VideoStrip.findFfmpeg();
		if (ffmpeg == null) throw "los videos necesitan ffmpeg: ponlo junto al .exe o en el PATH";
		videoClips = VideoStrip.clips(dir, warnings);
		if (videoClips.length == 0) throw "el sprite de video no tiene videos";
		index = 0;
		phase = 5;
		#end
	}

	/** Un video por vez: ffmpeg saca los frames, FunkFMPEG arma la tira (en otro hilo) y aqui solo se espera. Un video que falla no tira a los demas. */
	function stepVideo():Void
	{
		#if !android
		if (videoTask == null)
		{
			if (index >= videoClips.length)
			{
				phase = 2;
				return;
			}
			var clip = videoClips[index];
			if (clip.path == null)
			{
				placeholder("el video " + index + " esta en config.json pero no existe el .mp4");
				return;
			}
			videoTask = new VideoStripTask(ffmpeg, clip.path, VideoStrip.workDir(dir, index));
			label = Path.withoutDirectory(clip.path);
			return;
		}

		var file = Path.withoutDirectory(videoClips[index].path);
		if (videoTask.step())
		{
			label = file + ": " + videoTask.label;
			return;
		}
		var task = videoTask;
		videoTask = null;
		for (w in task.warnings) warnings.push(w);
		if (!task.ok)
		{
			placeholder("el video " + file + " no se pudo exportar: " + task.error);
			return;
		}

		var cfg:Dynamic = {};
		var original = videoClips[index].cfg;
		if (original != null) for (k in Reflect.fields(original)) Reflect.setField(cfg, k, Reflect.field(original, k));
		// la tira puede ser mas chica que el video: pivote y `scale` se corrigen para que se vea del mismo tamano
		var shrink = Math.min(1, task.frameWidth / task.sourceWidth);
		Reflect.setField(cfg, "spd", task.fps);
		Reflect.setField(cfg, "spd_fps", true);
		if (Reflect.field(cfg, "bilinear") != false) Reflect.setField(cfg, "bilinear", true);
		pending.push({path: base + outData.length + ".png", bytes: task.bytes});
		outData.push(animEntry(scaledCfg(cfg, shrink), task.frames, 0, 0));
		warnings.push("video " + file + ": " + task.frames + " frames de " + task.frameWidth + "x" + task.frameHeight + " a " + Math.round(task.fps * 100) / 100 + " fps"
			+ (task.resampled ? " (el original tiene otro fps)" : "") + (shrink < 1 ? ", al " + Math.round(shrink * 100) + "% del tamano original" : ", a tamano completo"));
		index++;
		#end
	}

	/** La animacion queda como un pixel transparente para que las de abajo conserven su numero (en vez de dejar el hueco sin avisar). */
	function placeholder(reason:String):Void
	{
		warnings.push(reason + " (queda vacia la animacion " + index + ")");
		pending.push({path: base + outData.length + ".png", bytes: PngHandler.encodeArgb(Bytes.alloc(4), 1, 1, 0)});
		outData.push(animEntry(videoClips[index].cfg, 1, 0, 0));
		index++;
	}

	function finishAtlas():Void
	{
		label = "sprite.json";
		dispose();
		pending.push({path: base + "sprite.json", bytes: Bytes.ofString(Json.stringify({type: 0, data: outData}))});
		ok = true;
		done = true;
	}

	function stepNative():Void
	{
		if (index >= nativeFiles.length)
		{
			ok = true;
			done = true;
			return;
		}
		var file = nativeFiles[index];
		index++;
		label = file;
		var path = Path.join([dir, file]);
		if (FileSystem.exists(path)) pending.push({path: base + file, bytes: File.getBytes(path)});
		else warnings.push("falta " + file);
	}
	#end
}
