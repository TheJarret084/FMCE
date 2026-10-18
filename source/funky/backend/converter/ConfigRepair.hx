package funky.backend.converter;

import haxe.Json;
import haxe.io.Path;
import funky.core.Log;
import funky.game.SpriteBuilder;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

typedef RepairResult =
{
	var dirs:Int;
	var fixed:Int;
	var orphans:Array<String>;
}

/** Repara los `config.json` de niveles ya convertidos al formato `anim` / `name`: */
class ConfigRepair
{
	public static function repairLevel(levelDir:String):RepairResult
	{
		var result:RepairResult = {dirs: 0, fixed: 0, orphans: []};
		#if sys
		var root = Path.join([levelDir, "sprites"]);
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root)) return result;

		for (entry in FileSystem.readDirectory(root))
		{
			var dir = Path.join([root, entry]);
			if (!FileSystem.isDirectory(dir)) continue;
			try
			{
				var done = repairSprite(dir, result.orphans);
				if (done >= 0) result.dirs++;
				if (done > 0) result.fixed += done;
			}
			catch (e:Dynamic)
			{
				Log.warn('[ConfigRepair] ${entry}: $e');
			}
		}
		if (result.fixed > 0 || result.orphans.length > 0)
			Log.info('[ConfigRepair] ${levelDir}: ${result.fixed} entradas reparadas, ${result.orphans.length} huerfanas');
		#end
		return result;
	}

	/** @return -1 si la carpeta no tiene config + atlas; si no, cuantas entradas se corrigieron. */
	static function repairSprite(dir:String, orphans:Array<String>):Int
	{
		#if sys
		var configPath = Path.join([dir, "config.json"]);
		var spritePath = Path.join([dir, "sprite.json"]);
		if (!FileSystem.exists(configPath) || !FileSystem.exists(spritePath)) return -1;

		var config:Dynamic = funky.core.JsonLoose.parse(File.getContent(configPath));
		var atlas:Dynamic = funky.core.JsonLoose.parse(File.getContent(spritePath));
		if (!Std.isOfType(config.data, Array) || atlas.meta == null || !Std.isOfType(atlas.meta.frameTags, Array)) return -1;

		// Tags por orden de aparicion en el atlas: el N-esimo es la animacion `index` N de la tira original.
		var tags:Array<Dynamic> = atlas.meta.frameTags;
		tags.sort((a, b) -> Std.int(a.from) - Std.int(b.from));
		var tagNames = [for (tag in tags) Std.string(tag.name)];

		var fixed = 0;
		var sprite = Path.withoutDirectory(dir);

		// La escala global (`scale` afuera de `data`) ya no existe: se suma a la `scale` de cada animacion.
		if (Reflect.hasField(config, "scale"))
		{
			var global = Std.parseFloat(Std.string(config.scale));
			if (!Math.isNaN(global) && global > 0 && global != 1)
				for (item in (config.data : Array<Dynamic>))
				{
					var own = item.scale != null ? Std.parseFloat(Std.string(item.scale)) : 1;
					item.scale = Math.round((Math.isNaN(own) ? 1 : own) * global * 10000) / 10000;
				}
			Reflect.deleteField(config, "scale");
			fixed++;
		}

		for (item in (config.data : Array<Dynamic>))
		{
			// `spd` multiplicador (viejo) -> `spd` FPS + `spd_fps: true`.
			if (SpriteBuilder.migrateSpd(item)) fixed++;

			// Con `indices` la entrada no necesita tag.
			if (Std.isOfType(item.indices, Array) && (item.indices : Array<Dynamic>).length > 0) continue;

			// 1) `anim` ya apunta a un tag real: nada que hacer.
			if (item.anim != null && tagNames.contains(Std.string(item.anim))) continue;

			// 2) `index` (posicion original en la tira) manda: el tag N-esimo del atlas es la animacion N.
			//    Asi un `name` que coincide por casualidad con OTRO tag no engaña (name "anim0" con index 1).
			var index = item.index != null ? Std.parseInt(Std.string(item.index)) : null;
			if (index != null && index >= 0 && index < tagNames.length)
			{
				item.anim = tagNames[index];
				fixed++;
				continue;
			}

			// 3) Sin `index`: el nombre que traia es el del atlas (formato FNMM viejo).
			var key:Null<String> = item.name != null ? Std.string(item.name) : null;
			if (key != null && tagNames.contains(key))
			{
				item.anim = key;
				fixed++;
			}
			else
				orphans.push('$sprite: "${key}" no esta en el atlas');
		}

		if (fixed > 0)
		{
			if (!FileSystem.exists(configPath + ".orig")) File.copy(configPath, configPath + ".orig");
			File.saveContent(configPath, Json.stringify(config, null, "  "));
		}
		return fixed;
		#else
		return -1;
		#end
	}
}
