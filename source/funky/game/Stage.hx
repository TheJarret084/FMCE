package funky.game;

import funky.backend.utils.CoolUtil;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import haxe.io.Path;
import funky.backend.FunkinVideoSprite;
import funky.backend.system.Log;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

private typedef StageTransform =
{
	var x:Float;
	var y:Float;

	var scale:Float;

	var scaleY:Float;
	var scrollX:Float;
	var scrollY:Float;
}

private typedef StagePlacement =
{
	var x:Float;
	var y:Float;
	var scaleX:Float;
	var scaleY:Float;
}

class StageObject
{
	public var sprite:LevelSprite;

	public var name:String = "";

	public var id:Int = -1;

	public var video:Null<FunkinVideoSprite>;

	public var videoName:String = "";
	public var videoIndex:Int = 0;
	public var videoCount:Int = 0;
	public var videoPlaying:Bool = false;

	public var strumLine:Int;

	public var baseAnim:Int = 0;

	public var singAnim:Int = -1;

	public var holdUntil:Float = 0;

	public var revertAt:Float = 0;

	public var fixed:Bool;
	public var transforms:Array<StageTransform>;
	public var shown:Bool;

	public var x:Float;
	public var y:Float;

	public var scale:Float;

	public var scaleY:Float;
	public var opacity:Float;

	public var scrollX:Float;
	public var scrollY:Float;

	public function new(
		sprite:LevelSprite,
		strumLine:Int,
		fixed:Bool,
		transforms:Array<StageTransform>,
		shown:Bool,
		opacity:Float
	)
	{
		this.sprite = sprite;
		this.strumLine = strumLine;
		this.fixed = fixed;
		this.transforms = transforms;
		this.shown = shown;
		this.opacity = opacity;

		x = transforms[0].x;
		y = transforms[0].y;
		scale = transforms[0].scale;
		scaleY = transforms[0].scaleY;
		scrollX = transforms[0].scrollX;
		scrollY = transforms[0].scrollY;
	}
}

class Stage extends FlxGroup
{
	public static inline var VIEW_WORLD_WIDTH:Float = 2400;
	public static var CAM_PRESET:Float = 1.25;

	public static var current(default, null):Null<Stage>;

	public static function get(key:Dynamic):Null<StageObject>
	{
		var stage = current;
		if (stage == null || key == null) return null;
		if (Std.isOfType(key, Int) || Std.isOfType(key, Float))
		{
			var i = Std.int(key);
			return i >= 0 && i < stage.objects.length ? stage.objects[i] : null;
		}
		var text = Std.string(key);
		for (object in stage.objects)
			if (object.name == text) return object;

		var n = Std.parseInt(text);
		return n != null && Std.string(n) == StringTools.trim(text) ? get(n) : null;
	}

	public static function getAll(name:String):Array<StageObject>
		return current == null ? [] : [for (object in current.objects) if (object.name == name) object];

	public static function sprite(key:Dynamic):Null<LevelSprite>
	{
		var object = get(key);
		return object == null ? null : object.sprite;
	}

	public static inline var HUD_REF_WIDTH:Float = 1920;

	public static var defaultHudZoom:Float = 1;

	static inline var MAX_PACK_DEPTH:Int = 8;

	public static var usePivot:Bool = true;

	public var loaded(default, null):Bool = false;
	public var songTime:Float = 0;

	var levelDir:String;
	public var bpm:Float;
	public var stepsPerBeat:Float = 4;

	public var objects:Array<StageObject> = [];
	public var camPoints:Array<{x:Float, y:Float, scale:Float}> = [];
	public var flash:FlxSprite;

	/**
	 * Tamano (px) del area donde se dibuja el escenario. -1 = toda la pantalla (FlxG.width / FlxG.height).
	 * El Charter lo usa para encuadrar el escenario igual que en el juego (setView).
	 */
	public var viewW:Float = -1;
	public var viewH:Float = -1;

	inline function vw():Float return viewW > 0 ? viewW : FlxG.width;

	inline function vh():Float return viewH > 0 ? viewH : FlxG.height;

	/** Cambia el area de dibujo (ancho y alto en px). Con valores <= 0 vuelve a toda la pantalla. */
	public function setView(w:Float, h:Float):Void
	{
		viewW = w;
		viewH = h;
		if (flash != null)
		{
			flash.setGraphicSize(Std.int(vw()), Std.int(vh()));
			flash.updateHitbox();
		}
	}

	public var camX:Float = 0;
	public var camY:Float = 0;
	public var camScale:Float = 1;
	public var zoomMul:Float = 1;

	/**
	 * Desplazamiento extra de la camara en unidades del mundo, encima de camX/camY. Los eventos de camara (CameraSet) escriben
	 * camX/camY y no lo tocan, asi que un script puede moverlo cada frame sin pelearse con ellos.
	 */
	public var camOffsetX:Float = 0;
	public var camOffsetY:Float = 0;

	var singUntil:Map<Int, Float> = new Map<Int, Float>();
	var singing:Map<Int, Bool> = new Map<Int, Bool>();

	/** Falso = nadie esta cantando, el update se salta el recorrido del Map. */
	var singingAny:Bool = false;
	var singLaneOf:Map<Int, Int> = new Map<Int, Int>();
	var holdMs:Float = 500;

	public var camHUD:Null<FlxCamera>;

	public function new(song:SongData, ?camHUD:FlxCamera)
	{
		super();

		this.camHUD = camHUD;
		current = this;

		levelDir = song.levelDir == null ? "" : song.levelDir;
		bpm = song.bpm <= 0 ? 120 : song.bpm;
		stepsPerBeat = song.stepsPerBeat;
		holdMs = song.beatMs;

		#if sys
		if (song.levelDir != null
			&& FileSystem.exists(Path.join([levelDir, "scene.json"])))
		{
			build();
		}
		#end
	}

	#if sys
	function build():Void
	{
		var scene:Dynamic = readJson(Path.join([levelDir, "scene.json"]));
		if (scene == null) return;

		for (cam in asArray(field(scene, "cameras")))
		{
			var position = field(cam, "position");

			if (position == null)
				position = cam;

			camPoints.push({
				x: CoolUtil.number(field(position, "x"), 0),
				y: CoolUtil.number(field(position, "y"), 0),
				scale: CoolUtil.number(field(cam, "scale"), 1)
			});
		}

		if (camPoints.length == 0)
			camPoints.push({x: 0, y: 0, scale: 1});

		camX = camPoints[0].x;
		camY = camPoints[0].y;
		camScale = camPoints[0].scale;

		var cache = new Map<String, Bool>();

		for (item in asArray(field(scene, "objects")))
		{
			var name = CoolUtil.text(field(item, "spr"), "");
			var transforms:Array<StageTransform> = [];
			var itemFixed = field(item, "fixed") == true;

			for (t in asArray(field(item, "transform")))
			{
				var position = field(t, "position");
				var scale = field(t, "scale");
				var scroll = field(t, "scrollFactor");

				var scaleX = CoolUtil.number(field(scale, "x"), 1);

				transforms.push({
					x: CoolUtil.number(field(position, "x"), 0),
					y: CoolUtil.number(field(position, "y"), 0),
					scale: scaleX,
					scaleY: CoolUtil.number(field(scale, "y"), scaleX),
					scrollX: itemFixed ? 1 : CoolUtil.number(field(scroll, "x"), 1),
					scrollY: itemFixed ? 1 : CoolUtil.number(field(scroll, "y"), 1)
				});
			}

			if (transforms.length == 0 && field(item, "x") != null)
			{
				var legacyScale = field(item, "scale");
				var legacyX = CoolUtil.number(legacyScale, CoolUtil.number(field(legacyScale, "x"), 1));

				transforms.push({
					x: CoolUtil.number(field(item, "x"), 0),
					y: CoolUtil.number(field(item, "y"), 0),
					scale: legacyX,
					scaleY: CoolUtil.number(legacyScale, CoolUtil.number(field(legacyScale, "y"), legacyX)),
					scrollX: 1,
					scrollY: 1
				});
			}

			if (name == "" || transforms.length == 0)
			{
				addPlaceholder();
				continue;
			}

			var count = SpriteBuilder.videoCount(levelDir, name);

			if (count > 0)
			{
				addVideoObject(item, name, count, transforms);
				continue;
			}

			var sprite = SpriteBuilder.build(levelDir, name);

			if (!sprite.loaded)
			{
				if (!cache.exists(name))
					Log.warn('[Stage] falta el sprite "' + name + '" de scene.json');

				cache.set(name, true);
				addPlaceholder();
				continue;
			}

			sprite.scrollFactor.set();

			var color = field(item, "color");

			if (color != null)
			{
				sprite.color = FlxColor.fromRGB(
					Std.int(CoolUtil.number(field(color, "r"), 255)),
					Std.int(CoolUtil.number(field(color, "g"), 255)),
					Std.int(CoolUtil.number(field(color, "b"), 255))
				);
			}

			var object = new StageObject(
				sprite,
				Std.int(CoolUtil.number(field(item, "strumLine"), -1)),
				field(item, "fixed") == true,
				transforms,
				field(item, "visible") != false,
				CoolUtil.number(field(item, "opacity"), 1)
			);

			objects.push(object);
			add(sprite);
			assignCamera(object);
			apply(object);
		}

		var items = asArray(field(scene, "objects"));
		for (i in 0...objects.length)
		{
			objects[i].id = i;
			if (i < items.length) objects[i].name = Std.string(field(items[i], "spr"));
		}

		flash = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		flash.setGraphicSize(Std.int(vw()), Std.int(vh()));
		flash.updateHitbox();
		flash.scrollFactor.set();
		flash.alpha = 0;

		add(flash);

		loaded = objects.length > 0;
		Log.info('[Stage] ' + objects.length + ' objetos');
	}

	function addVideoObject(
		item:Dynamic,
		name:String,
		count:Int,
		transforms:Array<StageTransform>
	):Void
	{
		var index = Std.int(Math.max(
			0,
			Math.min(count - 1, CoolUtil.number(field(item, "video"), 0))
		));

		var video:FunkinVideoSprite = null;
		try
		{
			video = SpriteBuilder.buildVideo(levelDir, name, index);
		}
		catch (e:Dynamic)
		{
			Log.error('[Stage] el video "' + name + '" fallo al cargar: ' + Std.string(e));
		}

		if (video == null || video.videoPath == null)
		{
			Log.warn(
				'[Stage] el video "' + name + '" no se pudo cargar ('
				+ (FunkinVideoSprite.SUPPORTED
					? "falta el archivo"
					: "este build no trae hxvlc")
				+ ')'
			);

			addPlaceholder();
			return;
		}

		video.scrollFactor.set();

		var color = field(item, "color");

		if (color != null)
		{
			video.color = FlxColor.fromRGB(
				Std.int(CoolUtil.number(field(color, "r"), 255)),
				Std.int(CoolUtil.number(field(color, "g"), 255)),
				Std.int(CoolUtil.number(field(color, "b"), 255))
			);
		}

		var hole = new LevelSprite();
		hole.visible = false;

		var object = new StageObject(
			hole,
			Std.int(CoolUtil.number(field(item, "strumLine"), -1)),
			field(item, "fixed") == true,
			transforms,
			field(item, "visible") != false,
			CoolUtil.number(field(item, "opacity"), 1)
		);

		object.video = video;
		object.videoName = name;
		object.videoIndex = index;
		object.videoCount = count;

		objects.push(object);
		add(video);
		assignCamera(object);

		video.visible = false;

		if (video.looping)
			playVideo(object);

		apply(object);
	}

	function addPlaceholder():Void
	{
		var empty = new LevelSprite();
		empty.visible = false;

		objects.push(new StageObject(
			empty,
			-1,
			true,
			[{x: 0, y: 0, scale: 1, scaleY: 1, scrollX: 1, scrollY: 1}],
			false,
			0
		));
	}
	#end

	function assignCamera(object:StageObject):Void
	{
		if (!object.fixed || camHUD == null) return;

		object.sprite.cameras = [camHUD];

		if (object.video != null)
			object.video.cameras = [camHUD];
	}

	public function sing(strumLine:Int, lane:Int):Void
	{
		if (strumLine < 0) return;

		for (object in objects)
		{
			if (object.strumLine != strumLine) continue;

			object.holdUntil = 0;
			object.revertAt = 0;

			object.singAnim = object.sprite.playIndex(lane + 1, true) ? lane + 1 : -1;
		}

		singing.set(strumLine, true);
		singingAny = true;
		singLaneOf.set(strumLine, lane);
		singUntil.set(strumLine, songTime + holdMs);
	}

	/**
	 * Lane que esta cantando la strumLine ahora mismo (0 izq, 1 abajo, 2 arriba, 3 der...), o -1 si no canta (o esta en miss).
	 */
	public function singLane(strumLine:Int):Int
	{
		if (singing.get(strumLine) != true) return -1;
		var lane = singLaneOf.get(strumLine);
		return lane == null ? -1 : lane;
	}

	static inline var HOLD_LOOP_FRAMES:Int = 2;

	static inline var HOLD_SHORT_ANIM:Int = 3;

	static inline var HOLD_LOOP_LAST:Bool = false;

	static inline var HOLD_SHORT_FREEZE:Bool = true;

	static inline var HOLD_GRACE_MS:Float = 120;

	public function hold(strumLine:Int):Void
	{
		if (strumLine < 0) return;

		for (object in objects)
		{

			if (object.strumLine == strumLine && object.singAnim > 0)
			{
				object.holdUntil = songTime + HOLD_GRACE_MS;
				wrapHold(object.sprite);
			}
		}

		singing.set(strumLine, true);
		singingAny = true;
		singUntil.set(strumLine, songTime + holdMs);
	}

	function wrapHold(sprite:LevelSprite):Void
	{
		var cur = sprite.animation.curAnim;
		if (cur == null) return;

		var total = cur.numFrames;
		if (total <= 1) return;

		var isShort = total <= HOLD_SHORT_ANIM;
		var count = isShort ? (HOLD_SHORT_FREEZE ? 1 : total) : Std.int(Math.min(total, HOLD_LOOP_FRAMES));
		var start = HOLD_LOOP_LAST ? total - count : 0;

		if (cur.finished)
		{

			sprite.playAnim(cur.name, true, sprite.lastAnimContext, false, start);
			return;
		}

		if (cur.curFrame >= start + count || cur.curFrame < start)
			cur.curFrame = start;
	}

	override public function update(elapsed:Float):Void
	{
		if (loaded && singingAny)
		{
			var stillSinging = false;
			for (line in singing.keys())
			{
				if (!singing.get(line)) continue;
				if (songTime < singUntil.get(line))
				{
					stillSinging = true;
					continue;
				}

				singing.set(line, false);
				singLaneOf.set(line, -1);

				for (object in objects)
				{
					if (object.strumLine != line) continue;

					object.singAnim = -1;
					object.holdUntil = 0;

					if (!object.sprite.playIndex(object.baseAnim, true))
						object.sprite.playIndex(0, true);
				}
			}
			singingAny = stillSinging;
		}

		if (loaded)
		{
			for (object in objects)
			{
				if (object.revertAt <= 0 || songTime < object.revertAt) continue;

				object.revertAt = 0;
				if (object.singAnim <= 0)
					object.sprite.playIndex(0, true);
			}
		}

		super.update(elapsed);

		if (loaded)
		{
			for (object in objects)
			{
				if (object.singAnim > 0 && songTime <= object.holdUntil)
					wrapHold(object.sprite);

				apply(object);
			}
		}
	}

	inline function fixedPixelsPerUnit():Float
	{
		return vw() / HUD_REF_WIDTH * defaultHudZoom;
	}

	inline function pixelsPerUnit():Float
	{
		return CAM_PRESET * vw()
			/ (VIEW_WORLD_WIDTH * Math.max(0.001, camScale * zoomMul));
	}

	var placementScratch:StagePlacement = {x: 0, y: 0, scaleX: 1, scaleY: 1};

	function placementFor(
		object:StageObject,
		animScale:Float
	):StagePlacement
	{
		var px:Float = 0;
		var py:Float = 0;
		var totalX:Float = 1;
		var totalY:Float = 1;

		switch (object.fixed)
		{
			case true:

				px = object.x * vw();
				py = object.y * vh();

				var unit = animScale * fixedPixelsPerUnit();
				totalX = object.scale * unit;
				totalY = object.scaleY * unit;

			case false:

				var ppu = pixelsPerUnit();
				var halfViewX = vw() / 2 / ppu;
				var halfViewY = vh() / 2 / ppu;

				px = (object.x - (camX + camOffsetX - halfViewX) * object.scrollX) * ppu;
				py = (object.y - (camY + camOffsetY - halfViewY) * object.scrollY) * ppu;

				totalX = object.scale * animScale * ppu;
				totalY = object.scaleY * animScale * ppu;
		}

		// Se reusa el mismo objeto: antes se creaba uno nuevo por objeto y por frame (basura para el GC).
		placementScratch.x = px;
		placementScratch.y = py;
		placementScratch.scaleX = totalX;
		placementScratch.scaleY = totalY;
		return placementScratch;
	}

	function playVideo(object:StageObject):Void
	{
		if (object.video == null) return;

		try
		{

			object.videoPlaying = object.video.playWhenReady();
		}
		catch (e:Dynamic)
		{
			object.videoPlaying = false;
			Log.error('[Stage] el video "' + object.videoName + '" fallo al reproducir: ' + Std.string(e));
		}
	}

	public function startVideos():Void
	{
		for (object in objects)
		{
			if (object.video != null && !object.videoPlaying)
				playVideo(object);
		}
	}

	public function pauseVideos():Void
	{
		for (object in objects)
		{
			if (object.video != null && object.videoPlaying)
				object.video.pause();
		}
	}

	public function resumeVideos():Void
	{
		for (object in objects)
		{
			if (object.video != null && object.videoPlaying)
				object.video.resume();
		}
	}

	public function setVideo(object:StageObject, index:Int):Bool
	{
		if (object.video == null
			|| index < 0
			|| index >= object.videoCount)
			return false;

		object.videoPlaying = false;

		if (!object.video.playSpriteVideo(
			SpriteBuilder.spriteDir(levelDir, object.videoName),
			index
		))
			return false;

		object.videoIndex = index;
		object.videoPlaying = true;

		return true;
	}

	public function setSprite(object:StageObject, name:String):Bool
	{
		#if sys
		if (object.video != null || name == "") return false;

		var old = object.sprite;
		if (old.loaded && old.spriteName == name) return true;

		var sprite = SpriteBuilder.build(levelDir, name);
		if (!sprite.loaded) return false;

		sprite.scrollFactor.set();
		sprite.color = old.color;
		sprite.flipX = old.flipX;
		sprite.flipY = old.flipY;
		sprite.blend = old.blend;

		sprite.playIndex(object.singAnim > 0 ? object.singAnim : object.baseAnim, true);

		var index = members.indexOf(old);
		if (index >= 0)
			insert(index, sprite);
		else
			add(sprite);

		remove(old, true);
		SpriteCache.give(levelDir, old);

		object.sprite = sprite;
		assignCamera(object);
		apply(object);
		return true;
		#else
		return false;
		#end
	}

	public function setChart(object:StageObject, line:Int):Bool
	{
		if (line < -1) return false;
		if (object.strumLine == line) return true;

		object.strumLine = line;
		object.singAnim = -1;
		object.holdUntil = 0;
		if (!object.sprite.playIndex(object.baseAnim, true))
			object.sprite.playIndex(0, true);
		return true;
	}

	public function setAnim(object:StageObject, index:Int):Bool
	{
		if (object.video != null)
			return setVideo(object, index);

		if (!object.sprite.playIndex(index, true))
			return false;

		if (object.strumLine >= 0)
		{
			object.singAnim = -1;
			object.holdUntil = 0;

			var cur = object.sprite.animation.curAnim;
			var ms = cur != null && cur.frameRate > 0 ? cur.numFrames / cur.frameRate * 1000 : 0;
			object.revertAt = index > 0 && ms > 0 ? songTime + ms : 0;
		}

		return true;
		}

		static inline var MISS_ANIM:Int = 5;

		public function miss(strumLine:Int):Void
		{
			if (strumLine < 0) return;

			for (object in objects)
			{
				if (object.strumLine != strumLine) continue;

				object.holdUntil = 0;
				object.revertAt = 0;

				object.singAnim = object.sprite.playIndex(MISS_ANIM, true) ? MISS_ANIM : -1;
			}

			singing.set(strumLine, true);
		singingAny = true;
			singLaneOf.set(strumLine, -1);
			singUntil.set(strumLine, songTime + holdMs);
		}

	function applyVideo(object:StageObject):Void
	{
		var video = object.video;
		if (video == null) return;

		var alpha = Math.max(0, Math.min(1, object.opacity));

		video.alpha = alpha;
		video.visible = object.shown
			&& alpha > 0.001
			&& video.frameWidth > 0;

		if (!video.visible) return;

		var placement = placementFor(object, 1);

		video.scale.set(placement.scaleX, placement.scaleY);
		video.updateHitbox();
		video.antialiasing = true;

		video.setPosition(
			placement.x - video.width / 2,
			placement.y - video.height / 2
		);
	}

	function apply(object:StageObject):Void
	{
		if (object.video != null)
		{
			applyVideo(object);
			return;
		}

		var sprite = object.sprite;
		if (!sprite.loaded) return;

		var alpha = Math.max(0, Math.min(1, object.opacity));

		sprite.alpha = alpha;
		sprite.visible = object.shown && alpha > 0.001;

		if (!sprite.visible) return;

		var anim = sprite.currentAnim();
		var animScale = anim == null ? 1 : anim.scale;

		var placement = placementFor(object, animScale);

		// updateHitbox solo si cambio la escala o el frame (antes en cada objeto, cada frame).
		var sx = placement.scaleX;
		var sy = placement.scaleY;
		if (sprite.scale.x != sx || sprite.scale.y != sy || sprite.width != sprite.frameWidth * Math.abs(sx) || sprite.height != sprite.frameHeight * Math.abs(sy))
		{
			sprite.scale.set(sx, sy);
			sprite.updateHitbox();
		}

		sprite.antialiasing = Math.min(Math.abs(placement.scaleX), Math.abs(placement.scaleY)) < 1
			|| sprite.antialiasing;

		if (usePivot)
			sprite.placePivot(placement.x, placement.y);
		else
			sprite.centerAt(placement.x, placement.y);
	}

	public function objectAt(value:Dynamic):Null<StageObject>
	{
		var index = Std.int(CoolUtil.number(value, -1));

		return index >= 0 && index < objects.length
			? objects[index]
			: null;
	}

	#if sys
	static function readJson(path:String):Dynamic
	{
		if (!FileSystem.exists(path))
			return null;

		try
		{
			return funky.backend.utils.JsonLoose.parse(File.getContent(path));
		}
		catch (e:Dynamic)
		{
			Log.warn('[Stage] JSON ilegible: ' + path);
			return null;
		}
	}
	#end

	static function field(object:Dynamic, name:String):Dynamic
	{
		return object == null ? null : Reflect.field(object, name);
	}

	static function asArray(value:Dynamic):Array<Dynamic>
	{
		return Std.isOfType(value, Array) ? cast value : [];
	}



	public static function getList(?mods:Bool = false):Array<String>
	{
		var list:Array<String> = [];
		var seen:Map<String, Bool> = new Map();
		function addDir(dir:String) {
			#if sys
			if (!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir)) return;
			for (f in sys.FileSystem.readDirectory(dir)) {
				var name = f;
				if (name.endsWith('.json')) name = name.substr(0, name.length - 5);
				else if (name.endsWith('.xml')) name = name.substr(0, name.length - 4);
				else continue;
				if (!seen.exists(name)) { seen.set(name, true); list.push(name); }
			}
			#end
		}
		addDir('assets/data/stages');
		addDir('assets/stages');
		addDir('assets/images/stages');
		return list;
	}

	override public function destroy():Void
	{
		if (current == this) current = null;
		objects = [];
		super.destroy();
	}
}
