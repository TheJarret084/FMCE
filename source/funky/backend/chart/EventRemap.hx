package funky.backend.chart;

import haxe.Json;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Cuando cambia el orden de `scene.json > objects` (subir/bajar capa, duplicar, borrar), los eventos de `events.json`
 * que apuntan a un objeto por su numero tienen que seguir al mismo objeto. Aqui se reescriben esos numeros.
 */
class EventRemap
{
	/** `map[viejo]` = numero nuevo del objeto, o -1 si se borro. */
	public static function isIdentity(map:Array<Int>):Bool
	{
		for (i in 0...map.length)
			if (map[i] != i) return false;
		return true;
	}

	/**
	 * Reescribe `props.object` de las acciones `Object*` de `events` y `action_packs`. Devuelve cuantas cambio y cuantas
	 * apuntan a un objeto borrado (esas se dejan como estan para no perder el resto del evento).
	 */
	public static function apply(root:Dynamic, map:Array<Int>):{changed:Int, orphaned:Int}
	{
		var result = {changed: 0, orphaned: 0};
		if (root == null || Std.isOfType(root, Array)) return result;

		function fix(actions:Dynamic):Void
		{
			if (!Std.isOfType(actions, Array)) return;
			for (action in (actions : Array<Dynamic>))
			{
				var type = Std.string(Reflect.field(action, "type"));
				if (!StringTools.startsWith(type, "Object")) continue;
				var props:Dynamic = Reflect.field(action, "props");
				if (props == null) continue;
				var raw:Dynamic = Reflect.field(props, "object");
				if (raw == null) continue;
				var old = Std.parseInt(Std.string(raw));
				if (old == null || old < 0 || old >= map.length) continue;
				var now = map[old];
				if (now < 0)
				{
					result.orphaned++;
					continue;
				}
				if (now != old)
				{
					Reflect.setField(props, "object", now);
					result.changed++;
				}
			}
		}

		var events:Dynamic = Reflect.field(root, "events");
		if (Std.isOfType(events, Array))
			for (e in (events : Array<Dynamic>)) fix(Reflect.field(e, "actions"));
		var packs:Dynamic = Reflect.field(root, "action_packs");
		if (Std.isOfType(packs, Array))
			for (p in (packs : Array<Dynamic>)) fix(Reflect.field(p, "actions"));
		return result;
	}

	#if sys
	/** Lee `events.json`, aplica `map` y lo vuelve a escribir. null = no habia nada que cambiar o no existe. */
	public static function applyToFile(path:String, map:Array<Int>):Null<{changed:Int, orphaned:Int}>
	{
		if (isIdentity(map) || !FileSystem.exists(path)) return null;
		var text = File.getContent(path);
		if (text.length > 0 && text.charCodeAt(0) == 0xFEFF) text = text.substr(1);
		var root:Dynamic = Json.parse(text);
		var result = apply(root, map);
		if (result.changed > 0) File.saveContent(path, Json.stringify(root, null, "\t"));
		return result;
	}
	#end
}
