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

typedef SpriteAnim = {
	var name:String;

	var index:Int;

	var frames:Array<Int>;

	var spd:Float;

	var spdFps:Bool;

	var fps:Float;
	var loop:Bool;
	var scale:Float;

	var offsetX:Float;
	var offsetY:Float;
}

typedef SpriteConfig = {
	var name:String;

	var type:String;
	var bilinear:Bool;
	var anims:Array<SpriteAnim>;
}

class SpriteBuilder
{
	public static inline var DEFAULT_FPS:Float = 24;

	public static function spriteDir(levelDir:String, name:String):String
		return Path.join([levelDir, "sprites", name]);

	public static function atlasDir(levelDir:String, name:String):String
		return Path.join([spriteDir(levelDir, name), "sprite"]);

	public static function isAtlas(levelDir:Null<String>, name:Null<String>):Bool
	{
		#if sys
		if (levelDir == null || name == null || name == "") return false;
		return FileSystem.exists(Path.join([atlasDir(levelDir, name), "Animation.json"]));
		#else
		return false;
		#end
	}

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

			if (!Reflect.hasField(entry, "index") && ~/^anim([0-9]+)$/.match(animName))
				resolved.index = Std.parseInt(~/^anim([0-9]+)$/.replace(animName, "$1"));
			config.anims.push(resolved);
		}
		#end
		return config;
	}

	public static function exists(levelDir:Null<String>, name:Null<String>):Bool
	{
		#if sys
		if (levelDir == null || name == null || name == "") return false;
		if (isAtlas(levelDir, name)) return true;
		var dir = spriteDir(levelDir, name);

		if (FunkinVideoSprite.readInfo(dir) != null) return true;

		funky.backend.converter.SpriteFolderConverter.mapFnfIcon(dir);
		return FileSystem.exists(Path.join([dir, "sprite.png"]))
			&& (FileSystem.exists(Path.join([dir, "sprite.json"])) || FileSystem.exists(Path.join([dir, "sprite.xml"])));
		#else
		return false;
		#end
	}

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

	public static function build(levelDir:Null<String>, name:Null<String>, x:Float = 0, y:Float = 0):LevelSprite
	{

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

	public static function videoCount(levelDir:Null<String>, name:Null<String>):Int
	{
		if (levelDir == null || name == null || name == "") return 0;
		var info = FunkinVideoSprite.readInfo(spriteDir(levelDir, name));
		return info == null ? 0 : info.count;
	}

	public static function buildVideo(levelDir:Null<String>, name:Null<String>, index:Int = 0, x:Float = 0, y:Float = 0):FunkinVideoSprite
	{
		var video = new FunkinVideoSprite(x, y);
		if (levelDir != null && name != null && name != "") video.loadSpriteVideo(spriteDir(levelDir, name), index);
		return video;
	}

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

		var configAnims:Array<Dynamic> = asArray(field(fromConfig, "data"));
		var fmceAnims = field(fmce, "animations");

		var plain:Array<Dynamic> = [];
		var skipTags:Array<String> = [];
		for (entry in configAnims)
		{

			var pos = configAnims.indexOf(entry);
			var list = intArray(field(entry, "indices"));
			if (list.length == 0)
			{
				plain.push(entry);
				continue;
			}

			var gameName = text(field(entry, "name"), "anim" + pos);
			skipTags.push(text(field(entry, "anim"), gameName));
			config.anims.push(resolveAnim(gameName, pos, list, entry, null));
		}
		var extra = configAnims.length;

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

		var order = [for (anim in config.anims) anim];
		config.anims.sort(function(a, b) {
			var d = a.index - b.index;
			return d != 0 ? d : order.indexOf(a) - order.indexOf(b);
		});
		if (config.anims.length == 0) config.anims.push(resolveAnim("anim0", 0, [0], null, null));

		if (config.type != "icon") addLaneAliases(config.anims);
		#end
		return config;
	}

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

		if (!~/^[0-9]+$/.match(rest)) return -1;
		return Std.parseInt(rest);
	}

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
