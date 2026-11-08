package funky.game;

import haxe.Json;
import haxe.io.Path;
import funky.backend.FunkinVideoSprite;
import funky.core.Conductor;
import funky.core.Log;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/** Una animacion de un sprite de nivel, ya resuelta (frames, fps, loop, pivote). */
typedef SpriteAnim = {
	var name:String;
	/** Posicion de la animacion en el sprite original del .fnmm (0 = idle, 1.. = lanes o variantes). */
	var index:Int;
	/** Indices dentro del atlas (rango `from..to` del frameTag). */
	var frames:Array<Int>;
	/** Velocidad tal cual sale del config: FPS crudos si `spdFps`, o beats que dura la animacion si no. */
	var spd:Float;
	/** true = `spd` son FPS crudos; false = `spd` son los beats que dura la animacion completa (lo sigue LevelSprite.update con el BPM). */
	var spdFps:Bool;
	/** FPS resueltos al cargar (en modo beat, con el BPM de ese momento). */
	var fps:Float;
	var loop:Bool;
	var scale:Float;
	/** Pivote del frame en pixeles (el `offset` del editor). Para iconos es el centro. */
	var offsetX:Float;
	var offsetY:Float;
}

/** Contenido de `sprites/<nombre>/`: `config.json` + `sprite.json` (Aseprite) ya fusionados. */
typedef SpriteConfig = {
	var name:String;
	/** "icon", "character", "bg", "item"... lo que diga `config.json`; "sprite" si no dice nada. */
	var type:String;
	var bilinear:Bool;
	var anims:Array<SpriteAnim>;
}

/** Construye sprites a partir de las carpetas `levels/<nivel>/sprites/<nombre>/`. */
class SpriteBuilder
{
	public static inline var DEFAULT_FPS:Float = 24;

	public static function spriteDir(levelDir:String, name:String):String
		return Path.join([levelDir, "sprites", name]);

	/** Carpeta del spritemap de Adobe Animate: `sprites/<n>/sprite/` (Animation.json + spritemap1.*). Nunca se modifica. */
	public static function atlasDir(levelDir:String, name:String):String
		return Path.join([spriteDir(levelDir, name), "sprite"]);

	/** Sprite tipo atlas (`"type": "atlas"` en su config.json, aunque no lo diga): existe `sprites/<n>/sprite/Animation.json` (el `config.json` queda afuera, en `sprites/<n>/`). */
	public static function isAtlas(levelDir:Null<String>, name:Null<String>):Bool
	{
		#if sys
		if (levelDir == null || name == null || name == "") return false;
		return FileSystem.exists(Path.join([atlasDir(levelDir, name), "Animation.json"]));
		#else
		return false;
		#end
	}

	/**
	 * `config.json` de un sprite atlas. Cada entrada de `data` es una animacion y su `name` es a la vez el nombre
	 * que usa el juego y el simbolo / label del atlas (el atlas no se toca). `spd` + `spd_fps`: ver `resolveAnim`.
	 */
	public static function readAtlasConfig(levelDir:String, name:String):SpriteConfig
	{
		var config:SpriteConfig = {name: name, type: "sprite", bilinear: false, anims: []};
		#if sys
		var fromConfig = readJson(Path.join([spriteDir(levelDir, name), "config.json"]));
		config.type = text(field(fromConfig, "type"), "atlas");
		config.bilinear = bool(field(fromConfig, "bilinear"), false);

		for (entry in asArray(field(fromConfig, "data")))
		{
			var animName = text(field(entry, "name"), "");
			if (animName == "") continue;
			var resolved = resolveAnim(animName, config.anims.length, [], entry, null);
			// Convencion de todos los sprites: `anim0` = idle y `animN` = las demas. El indice sale del numero
			// (el Stage hace playIndex(0) para idle y playIndex(lane + 1) para cantar), sin importar el orden del config.
			if (!Reflect.hasField(entry, "index") && ~/^anim([0-9]+)$/.match(animName))
				resolved.index = Std.parseInt(~/^anim([0-9]+)$/.replace(animName, "$1"));
			config.anims.push(resolved);
		}
		#end
		return config;
	}

	/** Hay `sprite.png` y algo de lo que sacar el atlas (`sprite.json` o `sprite.xml`). */
	public static function exists(levelDir:Null<String>, name:Null<String>):Bool
	{
		#if sys
		if (levelDir == null || name == null || name == "") return false;
		if (isAtlas(levelDir, name)) return true;
		var dir = spriteDir(levelDir, name);
		// carpeta de video: un .mp4 + config.json con "type": "video" (o `meta.fmce.video` en sprite.json)
		if (FunkinVideoSprite.readInfo(dir) != null) return true;
		// Icono base de FNF (png de 300x150 / 150x150 sin json): se mapea solo para que cuente como sprite en los editores.
		funky.backend.converter.SpriteFolderConverter.mapFnfIcon(dir);
		return FileSystem.exists(Path.join([dir, "sprite.png"]))
			&& (FileSystem.exists(Path.join([dir, "sprite.json"])) || FileSystem.exists(Path.join([dir, "sprite.xml"])));
		#else
		return false;
		#end
	}

	/** Nombres de las carpetas de sprites del nivel. `type == null` = todas (lo que usara el stage). */
	public static function listSprites(levelDir:Null<String>, ?type:String):Array<String>
	{
		var out:Array<String> = [];
		#if sys
		if (levelDir == null) return out;
		var root = Path.join([levelDir, "sprites"]);
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return out;
		try
		{
			for (entry in FileSystem.readDirectory(root))
			{
				if (!FileSystem.isDirectory(Path.join([root, entry])) || !exists(levelDir, entry)) continue;
				if (type != null)
				{
					var kind = videoCount(levelDir, entry) > 0 ? "video" : (isAtlas(levelDir, entry) ? readAtlasConfig(levelDir, entry) : readConfig(levelDir, entry)).type;
					if (kind != type) continue;
				}
				out.push(entry);
			}
		}
		catch (e:Dynamic)
		{
			Log.warn('[SpriteBuilder] no se pudo listar ' + root + ': ' + Std.string(e));
		}
		out.sort(Reflect.compare);
		#end
		return out;
	}

	/** Sprite de cualquier tipo. Siempre devuelve un `LevelSprite`; `loaded` dice si salio bien. */
	public static function build(levelDir:Null<String>, name:Null<String>, x:Float = 0, y:Float = 0):LevelSprite
	{
		// Con el nivel precargado (SpriteCache) sale de ahi ya listo; si no hay uno de repuesto, se construye normal.
		if (name != null && name != "")
		{
			var spare = SpriteCache.take(levelDir, name);
			if (spare != null)
			{
				spare.setPosition(x, y);
				return spare;
			}
		}

		var sprite = new LevelSprite(x, y);
		if (levelDir != null && name != null && name != "") sprite.load(levelDir, name);
		return sprite;
	}

	/** Carpeta de video (`config.json` con "type": "video" y un .mp4, o `sprite.json` con `meta.fmce.video`): cuantos videos son, o 0 si no lo es. */
	public static function videoCount(levelDir:Null<String>, name:Null<String>):Int
	{
		if (levelDir == null || name == null || name == "") return 0;
		var info = FunkinVideoSprite.readInfo(spriteDir(levelDir, name));
		return info == null ? 0 : info.count;
	}

	/** Video `index` de la carpeta `sprites/<name>/` (sin audio). `loaded` no existe aca: mira el `Bool` de `loadSpriteVideo`. */
	public static function buildVideo(levelDir:Null<String>, name:Null<String>, index:Int = 0, x:Float = 0, y:Float = 0):FunkinVideoSprite
	{
		var video = new FunkinVideoSprite(x, y);
		if (levelDir != null && name != null && name != "") video.loadSpriteVideo(spriteDir(levelDir, name), index);
		return video;
	}

	/** Icono de la barra de vida. Si falta el sprite, `HealthIcon` dibuja un cuadrado de reemplazo. */
	public static function icon(levelDir:Null<String>, name:Null<String>, isPlayer:Bool):HealthIcon
		return new HealthIcon(levelDir, name, isPlayer);

	public static function readConfig(levelDir:String, name:String):SpriteConfig
	{
		var config:SpriteConfig = {name: name, type: "sprite", bilinear: false, anims: []};
		#if sys
		var dir = spriteDir(levelDir, name);
		var fromConfig = readJson(Path.join([dir, "config.json"]));
		var fromSprite = readJson(Path.join([dir, "sprite.json"]));
		var meta = field(fromSprite, "meta");
		var fmce = field(meta, "fmce");

		var type = text(field(fromConfig, "type"), text(field(fmce, "type"), ""));
		if (type != "") config.type = type;
		config.bilinear = bool(field(fromConfig, "bilinear"), bool(field(fmce, "bilinear"), false));

		// `config.json` es la fuente (lo escribe el editor); `sprite.json` puede estar viejo.
		var configAnims:Array<Dynamic> = asArray(field(fromConfig, "data"));
		var fmceAnims = field(fmce, "animations");

		// 1) Entradas con `indices`: usan esos frames del atlas tal cual (pueden repetirse, en cualquier orden) y no
		//    necesitan frameTag. Un frameTag al que apunta una de estas entradas (`anim`) se descarta, para que no
		//    quede una segunda animacion con el mismo `index`.
		var plain:Array<Dynamic> = [];
		var skipTags:Array<String> = [];
		for (entry in configAnims)
		{
			// Posicion en `data`: es el numero de la animacion (data[0] = anim0, data[1] = anim1...).
			var pos = configAnims.indexOf(entry);
			var list = intArray(field(entry, "indices"));
			if (list.length == 0)
			{
				plain.push(entry);
				continue;
			}
			// `name` e `index` solo existen en configs viejos; si estan, se respetan.
			var gameName = text(field(entry, "name"), "anim" + pos);
			skipTags.push(text(field(entry, "anim"), gameName));
			config.anims.push(resolveAnim(gameName, pos, list, entry, null));
		}
		var extra = configAnims.length;

		// 2) El resto sale de los frameTags del atlas (rango from..to), como siempre.
		var tags:Array<Dynamic> = asArray(field(meta, "frameTags"));
		for (tag in tags)
		{
			var animName = text(field(tag, "name"), "");
			if (animName == "" || skipTags.contains(animName)) continue;
			var first = Std.int(number(field(tag, "from"), 0));
			var last = Std.int(number(field(tag, "to"), first));
			if (last < first) last = first;
			var indices = [for (index in first...last + 1) index];
			if (text(field(tag, "direction"), "forward") == "reverse") indices.reverse();
			var entry = findByName(plain, animName);
			// `anim` = tag del atlas (animName). El nombre que aplica el juego es anim<posicion en data>
			// (un `name` viejo, si todavia esta, tiene prioridad). Un tag sin entrada se agrega al final con su propio nombre.
			var applied = animName;
			var pos = extra;
			if (entry != null)
			{
				pos = configAnims.indexOf(entry);
				if (field(entry, "anim") != null) applied = text(field(entry, "name"), "anim" + pos);
			}
			else
				extra++;
			config.anims.push(resolveAnim(applied, pos, indices, entry, field(fmceAnims, animName)));
		}

		// Orden por `index` (el de la tira original); a igual `index`, el de aparicion.
		var order = [for (anim in config.anims) anim];
		config.anims.sort(function(a, b) {
			var d = a.index - b.index;
			return d != 0 ? d : order.indexOf(a) - order.indexOf(b);
		});
		if (config.anims.length == 0) config.anims.push(resolveAnim("anim0", 0, [0], null, null));
		// Un icono no canta: su `singLEFT` es "perdiendo", no la lane 0, asi que no lleva alias anim#.
		if (config.type != "icon") addLaneAliases(config.anims);
		#end
		return config;
	}

	/**
	 * Cada `singLEFT/DOWN/UP/RIGHT` (o `sing0`, `sing1`...) tambien queda como `anim0..N`
	 * (LEFT=0, DOWN=1, UP=2, RIGHT=3), asi el stage solo hace `playAnim("anim" + lane)`.
	 * El nombre original se conserva (HealthIcon lo usa) y un `anim#` que ya exista no se pisa.
	 */
	static function addLaneAliases(list:Array<SpriteAnim>):Void
	{
		for (anim in list.copy())
		{
			var lane = laneOfSing(anim.name);
			if (lane < 0) continue;
			var alias = "anim" + lane;
			var taken = false;
			for (other in list) if (other.name == alias) { taken = true; break; }
			if (taken) continue;
			list.push({
				name: alias, index: anim.index, frames: anim.frames, spd: anim.spd, spdFps: anim.spdFps, fps: anim.fps, loop: anim.loop,
				scale: anim.scale, offsetX: anim.offsetX, offsetY: anim.offsetY
			});
		}
	}

	/** Lane de una animacion `sing...` (-1 si no es una). Solo coincide el nombre exacto, no `singLEFT-miss` ni `singMISS`. */
	public static function laneOfSing(name:String):Int
	{
		var lower = name.toLowerCase();
		if (!StringTools.startsWith(lower, "sing")) return -1;
		var rest = lower.substr(4);
		switch (rest)
		{
			case "left": return 0;
			case "down": return 1;
			case "up": return 2;
			case "right": return 3;
			default:
		}
		// Solo digitos: `singMISS` o `sing1x` no son lanes.
		if (!~/^[0-9]+$/.match(rest)) return -1;
		return Std.parseInt(rest);
	}

	/**
	 * Formato de `data` en config.json de un sprite (no atlas): cada entrada lleva solo `anim` (el tag del atlas); el nombre
	 * en el juego es `anim<posicion>` e `index` es esa misma posicion, asi que ya no se guardan `name` ni `index`.
	 *
	 * Para el editor: ordena un config viejo por su `index` (una sola vez), asegura `anim`, quita `index` y deja `name`
	 * = anim<posicion> SOLO en memoria. Antes de guardar hay que pasar la lista por `entriesForSave`.
	 */
	public static function normalizeEntries(list:Array<Dynamic>):Void
	{
		var legacy = false;
		for (e in list)
			if (Reflect.hasField(e, "index")) legacy = true;
		if (legacy)
		{
			var tagged = [for (i in 0...list.length) {e: list[i], pos: i}];
			tagged.sort(function(a, b)
			{
				var ia = Std.parseFloat(Std.string(Reflect.field(a.e, "index")));
				var ib = Std.parseFloat(Std.string(Reflect.field(b.e, "index")));
				if (Math.isNaN(ia)) ia = a.pos;
				if (Math.isNaN(ib)) ib = b.pos;
				return ia < ib ? -1 : (ia > ib ? 1 : a.pos - b.pos);
			});
			list.splice(0, list.length);
			for (t in tagged) list.push(t.e);
		}
		for (i in 0...list.length)
		{
			var e = list[i];
			if (Reflect.field(e, "anim") == null)
				Reflect.setField(e, "anim", Reflect.field(e, "name") != null ? Reflect.field(e, "name") : "anim" + i);
			Reflect.deleteField(e, "index");
			Reflect.setField(e, "name", "anim" + i);
		}
	}

	/** Copia de la lista sin `name` ni `index`, lista para escribir en config.json. */
	public static function entriesForSave(list:Array<Dynamic>):Array<Dynamic>
	{
		var out:Array<Dynamic> = [];
		for (e in list)
		{
			var copy:Dynamic = {};
			for (f in Reflect.fields(e))
				if (f != "name" && f != "index") Reflect.setField(copy, f, Reflect.field(e, f));
			out.push(copy);
		}
		return out;
	}

	#if sys
	static function resolveAnim(name:String, position:Int, frames:Array<Int>, fromConfig:Dynamic, fromFmce:Dynamic):SpriteAnim
	{
		// Velocidad (config.json): `spd_fps` true = `spd` son FPS crudos; false = `spd` son los beats que dura la
		// animacion completa (fps = frames * bpm / (60 * spd)). Sin `spd_fps` (config viejo) `spd` era un multiplicador de 24 fps.
		var hasFlag = fromConfig != null && Reflect.hasField(fromConfig, "spd_fps");
		var spdFps = hasFlag ? bool(field(fromConfig, "spd_fps"), true) : true;
		var spd:Float = spdFps ? DEFAULT_FPS : 1;
		if (fromConfig != null && Reflect.hasField(fromConfig, "spd"))
		{
			spd = number(field(fromConfig, "spd"), spd);
			if (!hasFlag) spd *= DEFAULT_FPS;
		}
		else if (fromFmce != null && Reflect.hasField(fromFmce, "fps"))
			spd = number(field(fromFmce, "fps"), spd);
		if (spd <= 0) spd = spdFps ? DEFAULT_FPS : 1;
		// spd_fps false: `spd` = beats que dura la animacion COMPLETA (1 = toda en un beat, 2 = repartida en dos beats).
		var fps = spdFps ? spd : Math.max(1, frames.length) * Conductor.bpm / (60 * spd);

		var offset = fromConfig != null && Reflect.hasField(fromConfig, "offset") ? field(fromConfig, "offset") : field(fromFmce, "offset");
		return {
			name: name,
			index: Std.int(number(field(fromConfig, "index"), position)),
			frames: frames,
			spd: spd,
			spdFps: spdFps,
			fps: fps,
			loop: bool(field(fromConfig, "loop"), bool(field(fromFmce, "loop"), true)),
			scale: Math.max(0.0001, number(field(fromConfig, "scale"), number(field(fromFmce, "scale"), 1))),
			offsetX: number(field(offset, "x"), 0),
			offsetY: number(field(offset, "y"), 0)
		};
	}

	static function findByName(list:Array<Dynamic>, name:String):Dynamic
	{
		// Se busca por `anim` (nombre en el atlas); sin `anim` (FNMM viejo) `name` es el nombre del atlas.
		for (item in list) if (text(field(item, "anim"), text(field(item, "name"), "")) == name) return item;
		return null;
	}

	static function readJson(path:String):Dynamic
	{
		if (!FileSystem.exists(path)) return null;
		try
		{
			return funky.core.JsonLoose.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			Log.warn('[SpriteBuilder] JSON ilegible: ' + path);
			return null;
		}
	}
	#end

	static function field(object:Dynamic, name:String):Dynamic
		return object == null ? null : Reflect.field(object, name);

	/** `[0, 1, 2]` del config -> Array<Int> (descarta lo que no sea un numero >= 0). */
	static function intArray(value:Dynamic):Array<Int>
	{
		var out:Array<Int> = [];
		for (item in asArray(value))
		{
			var n = number(item, -1);
			if (n >= 0) out.push(Std.int(n));
		}
		return out;
	}

	/** Pasa una entrada de config.json de `spd` multiplicador (viejo) a `spd` FPS + `spd_fps: true`. @return true si cambio. */
	public static function migrateSpd(entry:Dynamic):Bool
	{
		if (entry == null || Reflect.hasField(entry, "spd_fps")) return false;
		Reflect.setField(entry, "spd", Math.round(DEFAULT_FPS * number(field(entry, "spd"), 1) * 100) / 100);
		Reflect.setField(entry, "spd_fps", true);
		return true;
	}

	static function asArray(value:Dynamic):Array<Dynamic>
		return Std.isOfType(value, Array) ? cast value : [];

	static function text(value:Dynamic, fallback:String):String
	{
		if (value == null) return fallback;
		var parsed = Std.string(value);
		return parsed == "null" ? fallback : parsed;
	}

	static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function bool(value:Dynamic, fallback:Bool):Bool
		return value == null ? fallback : value == true;
}
