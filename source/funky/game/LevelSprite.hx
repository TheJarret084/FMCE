package funky.game;

import funky.backend.FunkinSprite;
import funky.core.Conductor;
import funky.core.Log;
import funky.core.Paths;
import funky.game.SpriteBuilder;

/**
 * Un sprite de `levels/<nivel>/sprites/<nombre>/` ya cargado: atlas Aseprite, animaciones (los
 * frameTags de `sprite.json`) y el pivote de cada una.
 */
class LevelSprite extends FunkinSprite
{
	public var spriteName(default, null):String = "";
	public var spriteType(default, null):String = "sprite";
	/** false si faltaba el sprite o no se pudo leer; el objeto sigue siendo seguro de usar. */
	public var loaded(default, null):Bool = false;

	var anims:Map<String, SpriteAnim> = new Map<String, SpriteAnim>();
	var firstAnim:Null<String> = null;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
		animEnabled = true;
	}

    // resetea el sprite en caso de cambio
    function resetSprite():Void
    {
        frames = null;
        animation.destroyAnimations();
        anims.clear();
        firstAnim = null;
        loaded = false;
        spriteName = "";
        spriteType = "sprite";
    }

	/** Carga `sprites/<name>/` de `levelDir`. Devuelve false (y deja el sprite vacio) si falla. */
	public function load(levelDir:String, name:String):Bool
    {
        resetSprite();
        spriteName = name;

        // Spritemap de Animate: `sprites/<n>/sprite/Animation.json` + `sprites/<n>/config.json`.
        if (SpriteBuilder.isAtlas(levelDir, name)) return loadAtlas(levelDir, name);
    
        var atlas = Paths.getLevelSprite(levelDir, name);
        if (atlas == null)
        {
            Log.warn('[LevelSprite] sin atlas para ' + name + ' en ' + levelDir);
            return false;
        }

		var config = SpriteBuilder.readConfig(levelDir, name);
		frames = atlas;
		spriteType = config.type;
		antialiasing = config.bilinear;

		for (anim in config.anims)
		{
			var valid = [for (index in anim.frames) if (index >= 0 && index < atlas.numFrames) index];
			if (valid.length == 0) continue;
			if (anims.exists(anim.name)) Log.warn('[LevelSprite] ' + name + ': la animacion "' + anim.name + '" esta repetida en config.json (se queda la ultima)');
			animation.add(anim.name, valid, anim.fps, anim.loop);
			anims.set(anim.name, anim);
			if (firstAnim == null) firstAnim = anim.name;
		}
		if (firstAnim == null)
		{
			animation.add("anim0", [0], 1, false);
			firstAnim = "anim0";
		}
		animation.play(firstAnim);
		loaded = true;
		return true;
	}

	/**
	 * Sprite tipo atlas (Adobe Animate). El spritemap se lee tal cual, sin tocarlo; las animaciones salen del
	 * `name` de cada entrada de `config.json`, que debe ser un simbolo o label del atlas.
	 */
	function loadAtlas(levelDir:String, name:String):Bool
	{
		loadAnimate(SpriteBuilder.atlasDir(levelDir, name));
		if (frames == null)
		{
			Log.warn('[LevelSprite] spritemap ilegible en ' + SpriteBuilder.atlasDir(levelDir, name));
			return false;
		}

		var config = SpriteBuilder.readAtlasConfig(levelDir, name);
		spriteType = config.type;
		antialiasing = config.bilinear;

		for (entry in config.anims)
		{
			register(entry.name, entry.name, entry);

			// `singLEFT/DOWN/UP/RIGHT` tambien como `anim0..3` (ver SpriteBuilder.addLaneAliases).
			var lane = config.type == "icon" ? -1 : SpriteBuilder.laneOfSing(entry.name);
			if (lane >= 0 && !hasAnim("anim" + lane))
				register("anim" + lane, entry.name, entry);
		}

		if (firstAnim == null)
			Log.warn('[LevelSprite] ' + name + ': ninguna animacion de config.json existe en el atlas');
		else
			playAnim(firstAnim, true);

		loaded = true;
		return true;
	}

	/** Registra `gameName` apuntando al simbolo (o, si no es simbolo, al label) `atlasName`. */
	function register(gameName:String, atlasName:String, entry:SpriteAnim):Void
	{
		addAnim(gameName, atlasName, entry.fps, entry.loop);
		if (!hasAnim(gameName)) addAnim(gameName, atlasName, entry.fps, entry.loop, null, 0, 0, true);
		if (!hasAnim(gameName))
		{
			Log.warn('[LevelSprite] "' + atlasName + '" no existe en el atlas de ' + spriteName);
			return;
		}
		anims.set(gameName, {
			name: gameName, index: entry.index, frames: entry.frames, spd: entry.spd, spdFps: entry.spdFps, fps: entry.fps, loop: entry.loop,
			scale: entry.scale, offsetX: entry.offsetX, offsetY: entry.offsetY
		});
		if (firstAnim == null) firstAnim = gameName;
	}

	/** Animaciones con `spd_fps: false` duran `spd` beats (la animacion completa): se reajusta con el BPM actual. */
	override public function update(elapsed:Float):Void
	{
		var data = currentAnim();
		if (data != null && !data.spdFps)
		{
			var cur = animation.curAnim;
			if (cur != null && cur.numFrames > 0)
			{
				var target = cur.numFrames * Conductor.bpm / (60 * Math.max(0.01, data.spd));
				if (target > 0 && cur.frameRate != target) cur.frameRate = target;
			}
		}
		super.update(elapsed);
	}

	public function animNames():Array<String> return [for (key in anims.keys()) key];

	/** Toca la animacion cuyo `index` (posicion en el sprite original del .fnmm) es `index`. */
	public function playIndex(index:Int, force:Bool = true):Bool
	{
		for (anim in anims)
			if (anim.index == index)
			{
				playAnim(anim.name, force);
				return true;
			}
		return false;
	}

	/** Datos de la animacion que se esta tocando (pivote, escala), o null. */
	public inline function currentAnim():Null<SpriteAnim> return animation.name == null ? null : anims.get(animation.name);

	/** Toca `anim<lane>` (alias de `singLEFT/DOWN/UP/RIGHT`, ver `SpriteBuilder`). */
	public function playLane(lane:Int, force:Bool = true):Bool
	{
		if (!hasAnim("anim" + lane)) return false;
		playAnim("anim" + lane, force);
		return true;
	}

	/**
	 * Los sprites `character` traen UNA sola animacion de fallo (no una por lane), asi que no hay
	 * `anim#` para miss: se toca esta, sea cual sea la lane. Acepta `miss`, `singMISS` o `sing-miss`.
	 */
	public function playMiss(force:Bool = true):Bool
	{
		for (name in ["miss", "singMISS", "sing-miss"])
			if (hasAnim(name))
			{
				playAnim(name, force);
				return true;
			}
		return false;
	}

	/** Escala absoluta del sprite y recalcula la caja. La escala de cada animacion la aplica quien lo coloca (ver `SpriteAnim.scale`). */
	public function setSpriteScale(factor:Float):Void
	{
		scale.set(factor, factor);
		updateHitbox();
	}

	/**
	 * Coloca el sprite de modo que el pivote de la animacion actual caiga en (px, py).
	 * Sin pivote definido usa el centro. Es lo que necesitara el stage para respetar el
	 * `position` de cada objeto de `scene.json`.
	 */
	public function placePivot(px:Float, py:Float):Void
	{
		var anim = animation.name == null ? null : anims.get(animation.name);
		var pivotX = anim == null ? width / 2 : anim.offsetX * Math.abs(scale.x);
		var pivotY = anim == null ? height / 2 : anim.offsetY * Math.abs(scale.y);
		setPosition(px - pivotX, py - pivotY);
	}

	/** Centra la caja del sprite en (cx, cy), ignorando pivotes. */
	public inline function centerAt(cx:Float, cy:Float):Void
		setPosition(cx - width / 2, cy - height / 2);
}
