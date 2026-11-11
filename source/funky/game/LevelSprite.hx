package funky.game;

import funky.backend.FunkinSprite;
import funky.core.Conductor;
import funky.core.Log;
import funky.core.Paths;
import funky.game.SpriteBuilder;

class LevelSprite extends FunkinSprite
{
	public var spriteName(default, null):String = "";
	public var spriteType(default, null):String = "sprite";

	public var loaded(default, null):Bool = false;

	var anims:Map<String, SpriteAnim> = new Map<String, SpriteAnim>();
	var firstAnim:Null<String> = null;
	var baseAntialiasing:Bool = false;

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
				var target = cur.numFrames * Conductor.bpm / (60 * Math.max(0.01, data.spd));
				if (target > 0 && cur.frameRate != target) cur.frameRate = target;
			}
		}
		super.update(elapsed);
	}

	public function animNames():Array<String> return [for (key in anims.keys()) key];

	public function recycle():Void
	{
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
