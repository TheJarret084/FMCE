package funky.game;

import funky.backend.FunkinSprite;
import funky.backend.system.Conductor;
import funky.backend.system.Log;
import funky.backend.assets.Paths;
import funky.game.SpriteBuilder;
import flixel.util.FlxColor;

class LevelSprite extends FunkinSprite
{
	public var spriteName(default, null):String = "";
	public var spriteType(default, null):String = "sprite";

	public var loaded(default, null):Bool = false;

	var anims:Map<String, SpriteAnim> = new Map<String, SpriteAnim>();
	var firstAnim:Null<String> = null;
	var baseAntialiasing:Bool = false;

	/** Tinte base (ObjectBlendColor / color de scene.json). */
	public var tintColor(default, null):FlxColor = 0xFFFFFFFF;


	// Hold loop (como SpriteAnimator.Update de FMP): mientras se mantiene la nota se repiten los primeros frames.
	public static inline var HOLD_LOOP_FRAMES:Int = 2;
	public static inline var HOLD_SHORT_ANIM:Int = 3;
	public static inline var HOLD_LOOP_LAST:Bool = false;
	public static inline var HOLD_SHORT_FREEZE:Bool = true;

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
		animEnabled = true;
	}

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

	public function load(levelDir:String, name:String):Bool
	{
		resetSprite();
		spriteName = name;

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
		baseAntialiasing = antialiasing;

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
		baseAntialiasing = antialiasing;

		for (entry in config.anims)
		{
			register(entry.name, entry.name, entry);

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

	override public function update(elapsed:Float):Void
	{
		var data = currentAnim();
		if (data != null && !data.spdFps)
		{
			var cur = animation.curAnim;
			if (cur != null && cur.numFrames > 0)
			{
				var target = SpriteBuilder.animFps(data.spd, false, cur.numFrames, Conductor.bpm);
				if (cur.frameRate != target) cur.frameRate = target;
			}
		}
		super.update(elapsed);
	}

	public function animNames():Array<String> return [for (key in anims.keys()) key];

	/** Cambia el tinte base (ObjectBlendColor). */
	public function setTint(value:FlxColor):Void
	{
		tintColor = value;
		color = value;
	}

	/** true si la animacion actual tiene loop false: se queda en su ultimo frame y NO vuelve a idle. */
	public inline function holdsPose():Bool
	{
		var data = currentAnim();
		return data != null && !data.loop;
	}

	/**
	 * Logica de hold (FMP `HOLD_LOOP_FRAMES`): mientras dura la nota repite los primeros frames de la animacion actual.
	 * `repeatNoLoop` = false -> una animacion con loop false se reproduce una vez y se queda en el ultimo frame.
	 */
	public function holdLoop(repeatNoLoop:Bool = false):Void
	{
		var cur = animation.curAnim;
		if (cur == null) return;
		if (!repeatNoLoop && holdsPose()) return;

		var total = cur.numFrames;
		if (total <= 1) return;

		var isShort = total <= HOLD_SHORT_ANIM;
		var count = isShort ? (HOLD_SHORT_FREEZE ? 1 : total) : Std.int(Math.min(total, HOLD_LOOP_FRAMES));
		var start = HOLD_LOOP_LAST ? total - count : 0;

		if (cur.finished)
		{
			playAnim(cur.name, true, lastAnimContext, false, start);
			return;
		}

		if (cur.curFrame >= start + count || cur.curFrame < start)
			cur.curFrame = start;
	}

	public function recycle():Void
	{
		tintColor = 0xFFFFFFFF;
		color = 0xFFFFFFFF;
		alpha = 1;
		visible = true;
		angle = 0;
		flipX = false;
		flipY = false;
		blend = null;
		shader = null;
		clipRect = null;
		cameras = null;
		skew.set(0, 0);
		scrollFactor.set(1, 1);
		scale.set(1, 1);
		updateHitbox();
		antialiasing = baseAntialiasing;
		if (firstAnim != null) playAnim(firstAnim, true);
	}

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

	public inline function currentAnim():Null<SpriteAnim> return animation.name == null ? null : anims.get(animation.name);

	public function playLane(lane:Int, force:Bool = true):Bool
	{
		if (!hasAnim("anim" + lane)) return false;
		playAnim("anim" + lane, force);
		return true;
	}

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

	public function setSpriteScale(factor:Float):Void
	{
		scale.set(factor, factor);
		updateHitbox();
	}

	public function placePivot(px:Float, py:Float):Void
	{
		var anim = animation.name == null ? null : anims.get(animation.name);
		var pivotX = anim == null ? width / 2 : anim.offsetX * Math.abs(scale.x);
		var pivotY = anim == null ? height / 2 : anim.offsetY * Math.abs(scale.y);
		setPosition(px - pivotX, py - pivotY);
	}

	public inline function centerAt(cx:Float, cy:Float):Void
		setPosition(cx - width / 2, cy - height / 2);
}
