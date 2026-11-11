package funky.core;

import haxe.io.Path;
import funky.core.Log;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import animate.FlxAnimateAssets;
import animate.FlxAnimateFrames;
import openfl.utils.Assets as OpenFlAssets;

class Paths
{
	public static final ASSETS = "assets/";
	public static var LEVELS(default, null):String = levelsRoot();

	public static final IMAGES = ASSETS + "images/";
	public static final SOUNDS = ASSETS + "sounds/";
	public static final MUSIC  = ASSETS + "music/";
	public static final DATA   = ASSETS + "data/";
	public static final FONTS  = ASSETS + "fonts/";

	public static final VIDEOS = Addons.ID_ROOT + "videos/";

	public static final GAME_UI = IMAGES + "game/";

	public static final SHADERS = ASSETS + "shaders/";

	public static inline function image(name:String):String return IMAGES + name + ".png";
	public static inline function fragShader(name:String):String return SHADERS + name + ".frag";
	public static inline function vertShader(name:String):String return SHADERS + name + ".vert";
	public static inline function imageXml(name:String):String return IMAGES + name + ".xml";
	public static inline function uiImage(name:String):String return GAME_UI + name + ".png";
	public static inline function uiXml(name:String):String   return GAME_UI + name + ".xml";
	public static inline function sound(name:String):String   return SOUNDS + name + ".ogg";
	public static inline function music(name:String):String   return MUSIC + name + ".ogg";
	public static inline function font(name:String):String return FONTS + name;

	public static function video(name:String):String
	{
		var real = Addons.file("videos/" + name + ".mp4");
		return real != null ? real : VIDEOS + name + ".mp4";
	}

	public static var tempFramesCache:Map<String, FlxFramesCollection> = [];

	public static function init():Void
	{
		FlxG.signals.preStateSwitch.add(function() {
			tempFramesCache.clear();
		});
		initAnimateAssets();
	}

	static function initAnimateAssets():Void
	{
		#if (sys && !desktop)
		var baseExists = FlxAnimateAssets.exists;
		var baseText = FlxAnimateAssets.getText;
		var baseBytes = FlxAnimateAssets.getBytes;
		var baseBitmap = FlxAnimateAssets.getBitmapData;
		var baseList = FlxAnimateAssets.list;

		FlxAnimateAssets.exists = function(path:String, type:AssetType):Bool
			return baseExists(path, type) || sys.FileSystem.exists(path);

		FlxAnimateAssets.getText = function(path:String):String
		{
			var text = baseText(path);
			if (text == null && sys.FileSystem.exists(path)) text = sys.io.File.getContent(path);
			return text;
		};

		FlxAnimateAssets.getBytes = function(path:String):haxe.io.Bytes
		{
			var bytes = baseBytes(path);
			if (bytes == null && sys.FileSystem.exists(path)) bytes = sys.io.File.getBytes(path);
			return bytes;
		};

		FlxAnimateAssets.getBitmapData = function(path:String):openfl.display.BitmapData
		{
			var bitmap = baseBitmap(path);
			if (bitmap == null && sys.FileSystem.exists(path)) bitmap = openfl.display.BitmapData.fromFile(path);
			return bitmap;
		};

		FlxAnimateAssets.list = function(path:String, ?type:AssetType, ?library:String, includeSubDirectories:Bool = false):Array<String>
		{
			if ((library == null || library.length == 0) && sys.FileSystem.exists(path) && sys.FileSystem.isDirectory(path))
			{
				var out:Array<String> = [];
				function walk(relative:String):Void
				{
					var full = relative == "" ? path : path + "/" + relative;
					for (entry in sys.FileSystem.readDirectory(full))
					{
						var rel = relative == "" ? entry : relative + "/" + entry;
						if (includeSubDirectories && sys.FileSystem.isDirectory(path + "/" + rel)) walk(rel);
						else out.push(rel);
					}
				}
				walk("");
				return out;
			}
			return baseList(path, type, library, includeSubDirectories);
		};
		#end
	}

	public static function getSparrowAtlas(name:String):FlxAtlasFrames
	{
		var png = image(name);
		var xml = imageXml(name);
		if (!OpenFlAssets.exists(png) || !OpenFlAssets.exists(xml))
		{
			Log.warn('[Paths] getSparrowAtlas: falta $png o $xml');
			return null;
		}
		var atlas = FlxAtlasFrames.fromSparrow(png, xml);

		if (atlas != null && atlas.parent != null)
			atlas.parent.persist = true;
		return atlas;
	}

	public static function getPackerAtlas(name:String):FlxAtlasFrames
	{
		var png = image(name);
		var txt = IMAGES + name + ".txt";
		if (!OpenFlAssets.exists(png) || !OpenFlAssets.exists(txt))
		{
			Log.warn('[Paths] getPackerAtlas: falta $png o $txt');
			return null;
		}
		return FlxAtlasFrames.fromSpriteSheetPacker(png, txt);
	}

	public static function getAsepriteAtlas(name:String):FlxAtlasFrames
	{
		var png = image(name);
		var json = IMAGES + name + ".json";
		if (!OpenFlAssets.exists(png) || !OpenFlAssets.exists(json))
		{
			Log.warn('[Paths] getAsepriteAtlas: falta $png o $json');
			return null;
		}
		return FlxAtlasFrames.fromAseprite(png, json);
	}

	public static function getFrames(name:String):FlxFramesCollection
	{

		if (animateExists(name))
			return getAnimateAtlas(name);

		if (tempFramesCache.exists(name))
		{
			var cached = tempFramesCache[name];
			if (cached != null && cached.parent != null && cached.parent.bitmap != null && cached.parent.bitmap.readable)
				return cached;
			tempFramesCache.remove(name);
		}

		var frames:FlxFramesCollection = null;
		if (OpenFlAssets.exists(imageXml(name)))
			frames = getSparrowAtlas(name);
		else if (OpenFlAssets.exists(IMAGES + name + ".txt"))
			frames = getPackerAtlas(name);
		else if (OpenFlAssets.exists(IMAGES + name + ".json"))
			frames = getAsepriteAtlas(name);
		else if (OpenFlAssets.exists(image(name)))
		{
			var graphic:FlxGraphic = FlxG.bitmap.add(image(name));
			if (graphic != null) frames = graphic.imageFrame;
		}

		if (frames != null) tempFramesCache[name] = frames;
		return frames;
	}

	public static inline function animateExists(name:String):Bool
		return OpenFlAssets.exists(IMAGES + name + "/Animation.json");

	public static function getAnimateAtlas(name:String):FlxFramesCollection
	{
		try
		{
			return FlxAnimateFrames.fromAnimate(IMAGES + name);
		}
		catch (e:Dynamic)
		{
			Log.error('[Paths] no se pudo cargar el atlas Animate "$name": $e');
			return null;
		}
	}

	public static function framesExists(name:String):Bool
	{
		return animateExists(name)
			|| OpenFlAssets.exists(imageXml(name))
			|| OpenFlAssets.exists(IMAGES + name + ".txt")
			|| OpenFlAssets.exists(IMAGES + name + ".json")
			|| OpenFlAssets.exists(image(name));
	}

	public static function getLevelSprite(levelDir:String, name:String):FlxAtlasFrames
	{
		#if sys

		if (!funky.game.SpriteCache.active) return loadLevelSprite(levelDir, name);

		var cacheKey = Path.join([levelDir, "sprites", name, "sprite.png"]);
		var hit = funky.game.SpriteCache.frames.get(cacheKey);
		if (hit != null && (hit.parent == null || hit.parent.bitmap != null)) return hit;

		var atlas = loadLevelSprite(levelDir, name);
		if (atlas != null) funky.game.SpriteCache.frames.set(cacheKey, atlas);
		return atlas;
		#else
		return null;
		#end
	}

	static function loadLevelSprite(levelDir:String, name:String):FlxAtlasFrames
	{
		#if sys
		var dir = Path.join([levelDir, "sprites", name]);
		var png = Path.join([dir, "sprite.png"]);
		var json = Path.join([dir, "sprite.json"]);
		var xml = Path.join([dir, "sprite.xml"]);
		try
		{
			if (!sys.FileSystem.exists(png)) { Log.warn('[Paths] falta $png'); return null; }
			if (!sys.FileSystem.exists(json) && sys.FileSystem.exists(xml))
				funky.backend.converter.SpriteFolderConverter.convertFile(xml);
			if (!sys.FileSystem.exists(json)) { Log.warn('[Paths] falta $json'); return null; }

			var paged = funky.backend.SpritePages.load(levelDir, name);
			if (paged != null) return paged;

			var key = "level:" + png;
			var graphic = FlxG.bitmap.get(key);
			if (graphic == null || graphic.bitmap == null)
				graphic = FlxG.bitmap.add(openfl.display.BitmapData.fromFile(png), false, key);
			if (graphic == null) return null;
			graphic.persist = true;
			var content = sys.io.File.getContent(json);
			var atlas = FlxAtlasFrames.fromAseprite(graphic, content);

			if (atlas != null && !Std.isOfType(haxe.Json.parse(content).frames, Array))
				atlas.frames.sort(function(a, b) return Reflect.compare(a.name, b.name));
			return atlas;
		}
		catch (e:Dynamic)
		{
			Log.error('[Paths] getLevelSprite($name) fallo: ' + Std.string(e));
			return null;
		}
		#else
		return null;
		#end
	}

	public static inline function levelsRoot():String
		return ensureTrailingSlash(userDataDir() + "/levels");

	public static inline function backupsRoot():String
		return ensureTrailingSlash(userDataDir() + "/backups");

	public static inline function exportsRoot():String
		return ensureTrailingSlash(userDataDir() + "/exports");

	public static inline function levelPath(songId:String, sub:String):String
		return levelsRoot() + songId + "/" + sub;

	public static function levelExists(songId:String, sub:String):Bool
		return sys.FileSystem.exists(levelPath(songId, sub));

	public static function levelText(songId:String, sub:String):Null<String>
	{
		var p = levelPath(songId, sub);
		return sys.FileSystem.exists(p) ? sys.io.File.getContent(p) : null;
	}

	public static var currentLevel:Null<String> = null;

	static final FILE_TYPES:Map<String, Array<String>> = [
		"sprite" => ["sprites", ""],
		"image"  => ["images", ".png"],
		"sound"  => ["sounds", ".ogg"],
		"music"  => ["music", ".ogg"],
		"video"  => ["videos", ".mp4"],
		"script" => ["data/scripts", ".hx"],
		"source" => ["source", ".hx"],
		"shader" => ["shaders", ".frag"],
		"json"   => ["data", ".json"],
		"xml"    => ["data", ".xml"],
		"txt"    => ["data", ".txt"],
		"data"   => ["data", ""],
		"font"   => ["fonts", ""]
	];

	public static function File(name:String, ?type:String, ?level:String):String
	{
		var root = level != null ? level : currentLevel;
		if (root == null || root == "")
		{
			Log.warn('[Paths] File("$name"): no hay nivel activo');
			return name;
		}

		root = normalizeDir(root);
		name = StringTools.replace(name == null ? "" : name, "\\", "/");
		while (StringTools.startsWith(name, "/")) name = name.substr(1);

		for (part in name.split("/"))
		{
			if (part == "..")
			{
				Log.warn('[Paths] File("$name"): no se permite salir del nivel');
				return root;
			}
		}

		var folder = "";
		var ext = "";
		var kind = type == null ? "" : StringTools.trim(type);

		if (kind != "")
		{
			var info = FILE_TYPES.get(kind.toLowerCase());
			if (info != null)
			{
				folder = info[0];
				ext = info[1];
			}
			else
			{
				folder = kind;
			}
		}

		var last = name.substr(name.lastIndexOf("/") + 1);
		if (last.indexOf(".") >= 0) ext = "";

		return root + "/" + (folder == "" ? "" : folder + "/") + name + ext;
	}

	public static function FileExists(name:String, ?type:String, ?level:String):Bool
	{
		#if sys
		return sys.FileSystem.exists(File(name, type, level));
		#else
		return false;
		#end
	}

	public static function FileList(type:String, ?sub:String, ?level:String):Array<String>
	{
		var out:Array<String> = [];
		#if sys
		var dir = File(sub == null ? "" : sub, type, level);
		if (StringTools.endsWith(dir, "/")) dir = dir.substr(0, dir.length - 1);

		if (sys.FileSystem.exists(dir) && sys.FileSystem.isDirectory(dir))
		{
			for (entry in sys.FileSystem.readDirectory(dir))
			{
				var isDir = sys.FileSystem.isDirectory(dir + "/" + entry);
				if (type.toLowerCase() == "sprite" && !isDir) continue;
				out.push(isDir ? entry : Path.withoutExtension(entry));
			}
		}
		out.sort(Reflect.compare);
		#end
		return out;
	}

	public static function levelSprites(?level:String):Array<String>
	{
		var icons:Array<String> = [];
		var others:Array<String> = [];

		for (name in FileList("sprite", null, level))
		{
			if (spriteKind(name, level) == "icon") icons.push(name);
			else others.push(name);
		}

		return icons.concat(others);
	}

	public static function spriteKind(name:String, ?level:String):String
	{
		#if sys
		var config = File(name + "/config.json", "sprite", level);
		try
		{
			if (sys.FileSystem.exists(config))
			{
				var kind:Dynamic = Reflect.field(haxe.Json.parse(sys.io.File.getContent(config)), "type");
				if (kind != null) return Std.string(kind);
			}
		}
		catch (_:Dynamic) {}
		#end
		return "";
	}

	public static function listLevels():Array<String>
	{
		var root = levelsRoot();
		var result = new Array<String>();
		if (!ensureLevelsRoot()) return result;
		var seen = new haxe.ds.StringMap<Bool>();
		scanLevelDirs(root, "", result, seen);
		result.sort(Reflect.compare);
		Log.info('[Paths] levels validos encontrados=' + result.length);
		return result;
	}

	static function scanLevelDirs(absDir:String, relDir:String, out:Array<String>, seen:haxe.ds.StringMap<Bool>):Void
	{
		if (!sys.FileSystem.exists(absDir) || !sys.FileSystem.isDirectory(absDir)) return;

		var hasMeta = sys.FileSystem.exists(Path.join([absDir, "meta.json"]))
			|| sys.FileSystem.exists(Path.join([absDir, "data", "meta.json"]))
			|| sys.FileSystem.exists(Path.join([absDir, "chart.json"]));
		if (hasMeta)
		{
			if (relDir != "" && !seen.exists(relDir))
			{
				seen.set(relDir, true);
				out.push(relDir);
			}
			return;
		}

		for (entry in sys.FileSystem.readDirectory(absDir))
		{
			var childAbs = Path.join([absDir, entry]);
			if (!sys.FileSystem.isDirectory(childAbs)) continue;
			var childRel = relDir == "" ? entry : relDir + "/" + entry;
			scanLevelDirs(childAbs, childRel, out, seen);
		}
	}

	public static function ensureLevelsRoot():Bool
	{
		#if sys
		var root = levelsRoot();
		try
		{
			if (!sys.FileSystem.exists(root)) sys.FileSystem.createDirectory(root);
			return sys.FileSystem.isDirectory(root);
		}
		catch (e:Dynamic)
		{
			Log.error('[Paths] no se pudo preparar $root: ' + Std.string(e));
			return false;
		}
		#else
		return false;
		#end
	}

	static function userDataDir():String
	{
		#if android
		return normalizeDir(Storage.dataDirectory());
		#else
		return resolveBaseDir();
		#end
	}

	static function resolveBaseDir():String
	{

		#if sys
		try
		{
			var prog = Sys.programPath();
			if (prog != null && prog != "")
			{
				var dir = Path.directory(prog);
				if (dir != null && dir != "") return normalizeDir(dir);
			}
		}
		catch (_:Dynamic) {}
		#end
		return normalizeDir(".");
	}

	static function normalizeDir(dir:String):String
	{
		if (dir == null || dir == "") return ".";
		var p = StringTools.replace(dir, "\\", "/");
		while (StringTools.endsWith(p, "/")) p = p.substr(0, p.length - 1);
		return p == "" ? "." : p;
	}

	static function ensureTrailingSlash(path:String):String
		return StringTools.endsWith(path, "/") ? path : path + "/";

	public static function fontPath(file:String):Null<String>
	{
		var path = font(file);
		if (OpenFlAssets.exists(path, openfl.utils.AssetType.FONT))
		{
			Log.info('[Paths] fuente ok: ' + path);
			return path;
		}
		Log.warn('[Paths] fuente no encontrada en los assets: ' + path + ' (se usa la fuente por defecto)');
		return null;
	}

	public static inline function Font(font:String, ?extension:String = ".ttf")
		return FONTS + font + extension;
}
