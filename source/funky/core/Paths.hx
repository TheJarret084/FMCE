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

/**
 * Paths
 * Resuelve rutas de assets del motor y de niveles FNMM.
 */
class Paths
{
	public static final ASSETS = "assets/";
	public static var LEVELS(default, null):String = levelsRoot();

	public static final IMAGES = ASSETS + "images/";
	public static final SOUNDS = ASSETS + "sounds/";
	public static final MUSIC  = ASSETS + "music/";
	public static final DATA   = ASSETS + "data/";
	public static final FONTS  = ASSETS + "fonts/";
	/** Los videos NO van en el assets.pack (hxvlc necesita un archivo real): viven en addons/videos/ (ver Addons). */
	public static final VIDEOS = Addons.ID_ROOT + "videos/";

	public static final GAME_UI = IMAGES + "game/";

	public static final SHADERS = ASSETS + "shaders/";

	// motor
	public static inline function image(name:String):String return IMAGES + name + ".png";
	public static inline function fragShader(name:String):String return SHADERS + name + ".frag";
	public static inline function vertShader(name:String):String return SHADERS + name + ".vert";
	public static inline function imageXml(name:String):String return IMAGES + name + ".xml";
	public static inline function uiImage(name:String):String return GAME_UI + name + ".png";
	public static inline function uiXml(name:String):String   return GAME_UI + name + ".xml";
	public static inline function sound(name:String):String   return SOUNDS + name + ".ogg";
	public static inline function music(name:String):String   return MUSIC + name + ".ogg";
	public static inline function font(name:String):String return FONTS + name;
	/** Ruta REAL en disco de `addons/videos/<name>.mp4` (la carpeta externa gana sobre la que trae el build). Si no existe, el id sin resolver. */
	public static function video(name:String):String
	{
		var real = Addons.file("videos/" + name + ".mp4");
		return real != null ? real : VIDEOS + name + ".mp4";
	}

	// Soporta atlas de Adobe Animate (carpeta con Animation.json + spritemap) via flixel-animate,
	// ademas de Sparrow / Packer / Aseprite / imagen suelta.
	public static var tempFramesCache:Map<String, FlxFramesCollection> = [];

	/** Enganchar en Main una sola vez: limpia la caché de frames sueltos en cada cambio de state. */
	public static function init():Void
	{
		FlxG.signals.preStateSwitch.add(function() {
			tempFramesCache.clear();
		});
		initAnimateAssets();
	}

	/**
	 * flixel-animate solo lee del disco en desktop (`#if sys && desktop`). En Android los spritemaps sueltos
	 * (carpeta de un nivel, `.JarretLabs-FMCE/...`) viven en el almacenamiento, asi que se le agrega ese
	 * respaldo: primero lo de siempre (assets empaquetados) y, si no esta, el disco.
	 */
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

	/** Atlas Sparrow (`$name.png` + `$name.xml` en assets/images/). `name` sin extensión. */
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
		// Marcamos el FlxGraphic como persistente: si nadie más lo usa como
		// frame de un FlxSprite en el state actual (ej. CursorManager, que lo
		// usa manualmente vía Bitmap), el cache de Flixel puede tirarlo en un
		// cambio de state o una limpieza de memoria, dejando el BitmapData
		// interno inválido y reventando el próximo .paint().
		if (atlas != null && atlas.parent != null)
			atlas.parent.persist = true;
		return atlas;
	}

	/** Atlas estilo TexturePacker/SpriteSheetPacker (`$name.png` + `$name.txt`). */
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

	/** Atlas Aseprite (`$name.png` + `$name.json`). */
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

	/**
	 * Devuelve frames para `name`, detectando automáticamente si es un atlas
	 * (Sparrow > Packer > Aseprite, en ese orden) o una imagen suelta.
	 * Cachea el resultado hasta el próximo cambio de state (ver `init()`).
	 */
	public static function getFrames(name:String):FlxFramesCollection
	{
		// Atlas de Adobe Animate: flixel-animate ya tiene su propia cache, asi que no pasa por la nuestra.
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

	/** True si `images/<name>/Animation.json` existe: es un spritemap de Adobe Animate. */
	public static inline function animateExists(name:String):Bool
		return OpenFlAssets.exists(IMAGES + name + "/Animation.json");

	/** Frames de un atlas de Adobe Animate (`images/<name>/`), o null si no se puede leer. */
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

	/** True si existe cualquier variante cargable (Animate/Sparrow/Packer/Aseprite/imagen suelta) para `name`. */
	public static function framesExists(name:String):Bool
	{
		return animateExists(name)
			|| OpenFlAssets.exists(imageXml(name))
			|| OpenFlAssets.exists(IMAGES + name + ".txt")
			|| OpenFlAssets.exists(IMAGES + name + ".json")
			|| OpenFlAssets.exists(image(name));
	}

	/**
	 * Frames de un sprite de nivel: `<levelDir>/sprites/<name>/sprite.png` + `sprite.json`
	 * (Aseprite). Se lee del disco, no de OpenFL Assets, porque los niveles son archivos
	 * sueltos. Si falta el JSON pero hay `sprite.xml`, se convierte en el momento.
	 */
	public static function getLevelSprite(levelDir:String, name:String):FlxAtlasFrames
	{
		#if sys
		// Con el nivel precargado (SpriteCache) el atlas se arma una sola vez: sin releer ni reparsear el JSON.
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

			// Atlas con paginas (o tan grande que hay que partirlo): lo arma SpritePages.
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
			// JSON Hash: el orden de los campos de un objeto no esta garantizado en todos los
			// targets, asi que se ordena por nombre (anim00000, anim00001, ..., idle0000). Los
			// frameTags de `make_strips.py` apuntan a ese orden. El JSON en lista no se toca.
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

	// levels
	public static inline function levelsRoot():String
		return ensureTrailingSlash(userDataDir() + "/levels");

	/** Backups de levels/editor: mismo root físico que levels/. */
	public static inline function backupsRoot():String
		return ensureTrailingSlash(userDataDir() + "/backups");

	/** Exports manuales del usuario (botón "Exportar" en EditorMenuState). */
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

	// ───────────────────────── archivos de un nivel (para scripts y editores) ─────────────────────────

	/** Nivel activo: lo fija PlayState al cargar y el charter al abrir un nivel. `File` lo usa si no le pasas otro. */
	public static var currentLevel:Null<String> = null;

	/** tipo -> [carpeta dentro del nivel, extension por defecto]. Un tipo que no esta aqui se usa como nombre de carpeta. */
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

	/**
	 * Ruta de un archivo DENTRO de un nivel.
	 *
	 * @param name  Que es: el nombre, con subcarpetas si hace falta (`"boss"`, `"boss/sprite"`, `"efectos/golpe"`).
	 * @param type  De que tipo es: `sprite`, `image`, `sound`, `music`, `video`, `script`, `source`, `shader`, `json`,
	 *              `xml`, `txt`, `data` o `font`. Con otra palabra se usa como carpeta (`File("a", "mapas")` = `<nivel>/mapas/a`).
	 *              Vacio = `name` tal cual desde la raiz del nivel.
	 * @param level Carpeta del nivel. Por defecto el nivel activo (`currentLevel`).
	 *
	 * Si `name` ya trae extension no se le agrega otra. Un `name` con `..` se rechaza (devuelve la raiz del nivel).
	 *
	 *     Paths.File("boss", "sprite")        // <nivel>/sprites/boss
	 *     Paths.File("golpe", "sound")        // <nivel>/sounds/golpe.ogg
	 *     Paths.File("intro/corte", "video")  // <nivel>/videos/intro/corte.mp4
	 *     Paths.File("blur", "shader")        // <nivel>/shaders/blur.frag
	 *     Paths.File("config", "json")        // <nivel>/data/config.json
	 */
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

	/** true si `File(name, type, level)` existe en disco (archivo o carpeta). */
	public static function FileExists(name:String, ?type:String, ?level:String):Bool
	{
		#if sys
		return sys.FileSystem.exists(File(name, type, level));
		#else
		return false;
		#end
	}

	/**
	 * Nombres de lo que hay en la carpeta de un tipo del nivel, sin extension y ordenados (no entra a subcarpetas;
	 * para `sprite` salen las carpetas). `sub` = subcarpeta dentro del tipo.
	 */
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

	/**
	 * Sprites de un nivel (`<nivel>/sprites/<n>/`), con los de `config.json` > `type: "icon"` primero.
	 * Es lo que muestran los dropdowns de iconos del charter.
	 */
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

	/** `type` del `config.json` de un sprite del nivel ("icon", "character"...), o "" si no lo dice. */
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

	// Lista carpetas de levels (cada una = un nivel)
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

		// FMCE actual: meta.json lives at the level root. The data/ check is kept
		// for compatibility with older level layouts.
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

	/**
	 * Creates `levels/` if it is missing. Returns false instead of throwing when the
	 * folder cannot be created or is not readable, so menus can show an empty list
	 * rather than crash (the folder does not exist on a fresh install).
	 */
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

	/** Writable user-data root: app-scoped storage on Android, beside the executable elsewhere. */
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

	/**
	 * Ruta de una fuente de `assets/fonts` si OpenFL la tiene registrada, o null (y avisa en el log) si no.
	 * Asi, si una fuente no carga, el motivo sale en el log (F2) en vez de caer en silencio a la fuente por defecto.
	 */
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

	/** `assets/fonts/$font$extension` (por defecto `.ttf`). */
	public static inline function Font(font:String, ?extension:String = ".ttf")
		return FONTS + font + extension;
}
