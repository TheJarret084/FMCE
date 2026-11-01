package funky.game;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import funky.core.Log;

/**
 * Precarga de los sprites de un nivel, para que `Stage.setSprite` (ObjectSpriteSet) no tenga que leer disco,
 * parsear JSON ni subir texturas en pleno juego.
 *
 * Mientras `active` es true:
 *  - `Paths.getLevelSprite` reutiliza los `FlxAtlasFrames` ya armados (`frames`).
 *  - `SpriteBuilder.build` entrega primero un sprite de repuesto de este `pool` (`take`).
 *  - `Stage.setSprite` devuelve el sprite que reemplaza al pool (`give`) en vez de destruirlo, asi volver a un
 *    sprite anterior tambien es gratis.
 *
 * Fuera de un nivel (`active` = false) no hace nada: los editores siguen leyendo siempre de disco.
 * Lo llena `LoadingLevelState` antes de cada cancion y se vacia solo al entrar a cualquier otra pantalla.
 */
class SpriteCache
{
	/** true entre `begin` y `clear`. */
	public static var active(default, null):Bool = false;

	/** Atlas ya armados, por ruta de `sprite.png`. Lo usa `Paths.getLevelSprite`. */
	public static var frames(default, null):Map<String, FlxAtlasFrames> = new Map();

	static var hooked:Bool = false;
	static var levelDir:Null<String> = null;
	static var pool:Map<String, Array<LevelSprite>> = new Map();
	static var graphics:Array<FlxGraphic> = [];

	/** Deja el cache listo para `dir`. Si venia de otro nivel lo vacia primero. */
	public static function begin(dir:String):Void
	{
		// Una sola vez: el cache solo vive mientras el estado es el loading o el juego. Cualquier otra pantalla
		// (menus, editores) lo vacia sola, salga el jugador por donde salga (Pause, GameOver, fin de cancion...).
		if (!hooked)
		{
			hooked = true;
			FlxG.signals.preStateCreate.add(function(state:flixel.FlxState):Void
			{
				if (!Std.isOfType(state, funky.menus.LoadingLevelState) && !Std.isOfType(state, PlayState)) clear();
			});
		}

		if (active && levelDir == dir) return;
		clear();
		levelDir = dir;
		active = true;
	}

	/** Suelta todo: sprites de repuesto, atlas y texturas (las que sigan en uso se liberan solas al destruirse). */
	public static function clear():Void
	{
		for (list in pool)
			for (sprite in list)
				sprite.destroy();

		for (graphic in graphics)
		{
			graphic.persist = false;
			graphic.destroyOnNoUse = true;
			FlxG.bitmap.removeIfNoUse(graphic);
		}

		pool = new Map();
		frames = new Map();
		graphics = [];
		levelDir = null;
		active = false;
	}

	/** Deja un sprite de `name` de repuesto (si no hay ya uno) y sube su textura a la GPU. */
	public static function preload(dir:String, name:String):Void
	{
		if (!active || dir != levelDir) return;

		var list = pool.get(name);
		if (list != null && list.length > 0) return;

		// `new` + `load` directo: `SpriteBuilder.build` se llevaria el repuesto que estamos armando.
		var sprite = new LevelSprite();
		sprite.load(dir, name);

		if (!sprite.loaded)
		{
			Log.warn('[SpriteCache] no se pudo precargar "' + name + '"');
			sprite.destroy();
			return;
		}

		for (graphic in graphicsOf(sprite))
		{
			if (graphics.indexOf(graphic) >= 0) continue;
			graphics.push(graphic);

			// Clave: al pasar del loading al juego, Flixel hace `FlxG.bitmap.clearCache()` y DESTRUYE toda imagen que
			// no sea `persist` (da igual que un sprite la use). Sin esto los sprites precargados quedan sin textura.
			graphic.persist = true;
			upload(graphic);
		}

		if (list == null)
		{
			list = [];
			pool.set(name, list);
		}
		list.push(sprite);
	}

	/** Un sprite de repuesto de `name`, o null si no hay (se construye normal). */
	public static function take(dir:Null<String>, name:String):Null<LevelSprite>
	{
		if (!active || dir != levelDir) return null;
		var list = pool.get(name);
		if (list == null || list.length == 0) return null;
		Log.info('[SpriteCache] repuesto de "' + name + '"');
		return list.pop();
	}

	/** Devuelve un sprite que ya no se usa para reutilizarlo; si no se puede, lo destruye. */
	public static function give(dir:Null<String>, sprite:LevelSprite):Void
	{
		if (!active || dir != levelDir || !sprite.loaded)
		{
			sprite.destroy();
			return;
		}

		sprite.recycle();

		var list = pool.get(sprite.spriteName);
		if (list == null)
		{
			list = [];
			pool.set(sprite.spriteName, list);
		}
		list.push(sprite);
	}

	/** Todas las imagenes (paginas / spritemaps) que usa el sprite. */
	static function graphicsOf(sprite:LevelSprite):Array<FlxGraphic>
	{
		var out:Array<FlxGraphic> = [];

		inline function add(graphic:FlxGraphic):Void
			if (graphic != null && out.indexOf(graphic) < 0) out.push(graphic);

		add(sprite.graphic);

		if (sprite.frames != null)
		{
			add(sprite.frames.parent);
			for (frame in sprite.frames.frames)
				if (frame != null) add(frame.parent);
		}
		return out;
	}

	/** Sube la textura ahora: si no, OpenFL la sube en el primer frame que la dibuja (ahi es el tiron del lag). */
	static function upload(graphic:FlxGraphic):Void
	{
		#if (openfl && !flash)
		try
		{
			var context = FlxG.stage.context3D;
			if (context != null && graphic.bitmap != null)
				graphic.bitmap.getTexture(context);
		}
		catch (e:Dynamic)
		{
			Log.warn('[SpriteCache] no se pudo subir la textura: ' + Std.string(e));
		}
		#end
	}

	/**
	 * Nombres de los sprites que el nivel usa de verdad: los de `scene.json`, los iconos, y los que ponen los
	 * eventos ObjectSpriteSet / BarIconChange (tambien dentro de los action packs). Un sprite de `sprites/` que
	 * nadie nombra no se precarga (si un script lo pide, se carga al momento como siempre).
	 */
	public static function referenced(song:SongData):Array<String>
	{
		var out:Array<String> = [];

		inline function add(name:Dynamic):Void
		{
			if (name == null) return;
			var text = Std.string(name);
			if (text != "" && text != "null" && out.indexOf(text) < 0) out.push(text);
		}

		function scan(action:Dynamic):Void
		{
			var props = Reflect.field(action, "props");
			switch (Std.string(Reflect.field(action, "type")))
			{
				case "ObjectSpriteSet":
					for (key in ["sprite", "spr", "name", "value"])
						if (Reflect.field(props, key) != null) { add(Reflect.field(props, key)); break; }
				case "BarIconChange", "BarIconChance":
					add(Reflect.field(props, "sprite"));
				default:
			}
		}

		add(song.iconPlayer);
		add(song.iconOpponent);

		#if sys
		try
		{
			var file = haxe.io.Path.join([song.levelDir, "scene.json"]);
			if (sys.FileSystem.exists(file))
			{
				var scene:Dynamic = haxe.Json.parse(sys.io.File.getContent(file));
				if (Std.isOfType(scene.objects, Array))
					for (item in (scene.objects : Array<Dynamic>)) add(Reflect.field(item, "spr"));
			}
		}
		catch (e:Dynamic)
		{
			Log.warn('[SpriteCache] no se pudo leer scene.json: ' + Std.string(e));
		}
		#end

		for (event in song.events)
			if (Std.isOfType(Reflect.field(event, "actions"), Array))
				for (action in (Reflect.field(event, "actions") : Array<Dynamic>)) scan(action);

		for (pack in song.actionPacks)
			for (action in pack) scan(action);

		return out;
	}
}
