package funky.game;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.io.Path;
import funky.backend.FunkinVideoSprite;
import funky.core.Log;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

private typedef StageTransform =
{
	var x:Float;
	var y:Float;
	/** Escala X (puede ser negativa = espejo horizontal). */
	var scale:Float;
	/** Escala Y (puede ser negativa = espejo vertical). Si el json no la trae, igual a X. */
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

	public var video:Null<FunkinVideoSprite>;

	public var videoName:String = "";
	public var videoIndex:Int = 0;
	public var videoCount:Int = 0;
	public var videoPlaying:Bool = false;

	public var strumLine:Int;
	public var fixed:Bool;
	public var transforms:Array<StageTransform>;
	public var shown:Bool;

	public var x:Float;
	public var y:Float;
	/** Escala X; negativa = espejo horizontal. */
	public var scale:Float;
	/** Escala Y; negativa = espejo vertical. */
	public var scaleY:Float;
	public var opacity:Float;

	/** scrollFactor del scene.json (parallax). Los fixed lo ignoran y van 1:1. */
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

	/**
	 * Resolucion de referencia del editor para los fixed: 1920 de ancho.
	 * Un fixed mide (px del sprite * scale) / 1920 del ancho de pantalla,
	 * sin importar la camara (ej: hud 800x450 con scale 2.4 = pantalla completa).
	 */
	public static inline var HUD_REF_WIDTH:Float = 1920;

	/** Ajuste global extra de los fixed (1 = tal cual el editor). Constante, no sigue a la camara. */
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

	public var camX:Float = 0;
	public var camY:Float = 0;
	public var camScale:Float = 1;
	public var zoomMul:Float = 1;

	// por indice de strumline (0 jugador, 1 oponente, 2+ extras)
	var singUntil:Map<Int, Float> = new Map<Int, Float>();
	var singing:Map<Int, Bool> = new Map<Int, Bool>();
	var holdMs:Float = 500;

	/** Camara del HUD: los objetos `fixed` se dibujan aqui y no siguen a la camara del mundo (camGame). */
	public var camHUD:Null<FlxCamera>;

	public function new(song:SongData, ?camHUD:FlxCamera)
	{
		super();

		this.camHUD = camHUD;

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
				position = cam; // formato viejo: x, y planos

			camPoints.push({
				x: number(field(position, "x"), 0),
				y: number(field(position, "y"), 0),
				scale: number(field(cam, "scale"), 1)
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
			var name = text(field(item, "spr"), "");
			var transforms:Array<StageTransform> = [];
			var itemFixed = field(item, "fixed") == true;

			for (t in asArray(field(item, "transform")))
			{
				var position = field(t, "position");
				var scale = field(t, "scale");
				var scroll = field(t, "scrollFactor");

				var scaleX = number(field(scale, "x"), 1);

				// los fixed ignoran el scrollFactor del json: van en camHUD
				transforms.push({
					x: number(field(position, "x"), 0),
					y: number(field(position, "y"), 0),
					scale: scaleX,
					scaleY: number(field(scale, "y"), scaleX),
					scrollX: itemFixed ? 1 : number(field(scroll, "x"), 1),
					scrollY: itemFixed ? 1 : number(field(scroll, "y"), 1)
				});
			}

			// formato viejo: sin lista "transform", x / y / scale van sueltos en el objeto
			if (transforms.length == 0 && field(item, "x") != null)
			{
				var legacyScale = field(item, "scale");
				var legacyX = number(legacyScale, number(field(legacyScale, "x"), 1));

				transforms.push({
					x: number(field(item, "x"), 0),
					y: number(field(item, "y"), 0),
					scale: legacyX,
					scaleY: number(legacyScale, number(field(legacyScale, "y"), legacyX)),
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
					Std.int(number(field(color, "r"), 255)),
					Std.int(number(field(color, "g"), 255)),
					Std.int(number(field(color, "b"), 255))
				);
			}

			var object = new StageObject(
				sprite,
				Std.int(number(field(item, "strumLine"), -1)),
				field(item, "fixed") == true,
				transforms,
				field(item, "visible") != false,
				number(field(item, "opacity"), 1)
			);

			objects.push(object);
			add(sprite);
			assignCamera(object);
			apply(object);
		}

		flash = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		flash.setGraphicSize(FlxG.width, FlxG.height);
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
			Math.min(count - 1, number(field(item, "video"), 0))
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
				Std.int(number(field(color, "r"), 255)),
				Std.int(number(field(color, "g"), 255)),
				Std.int(number(field(color, "b"), 255))
			);
		}

		var hole = new LevelSprite();
		hole.visible = false;

		var object = new StageObject(
			hole,
			Std.int(number(field(item, "strumLine"), -1)),
			field(item, "fixed") == true,
			transforms,
			field(item, "visible") != false,
			number(field(item, "opacity"), 1)
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

	/** Los `fixed` van a camHUD (pegados a la pantalla); el resto se queda en camGame (la default). */
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
			if (object.strumLine == strumLine)
				object.sprite.playIndex(lane + 1, true);
		}

		singing.set(strumLine, true);
		singUntil.set(strumLine, songTime + holdMs);
	}

	/** Frames que se repiten mientras dura un hold (provisional). */
	static inline var HOLD_LOOP_FRAMES:Int = 2;

	/** Una anim de canto con este numero de frames o menos se queda en el primero mientras dura el hold. */
	static inline var HOLD_SHORT_ANIM:Int = 3;

	/** true = repite los ultimos frames de la anim; false = los primeros. */
	static inline var HOLD_LOOP_LAST:Bool = false;

	public function hold(strumLine:Int):Void
	{
		if (strumLine < 0) return;

		for (object in objects)
		{
			if (object.strumLine == strumLine)
				loopHold(object.sprite);
		}

		singing.set(strumLine, true);
		singUntil.set(strumLine, songTime + holdMs);
	}

	/** Mantiene la anim de canto en loop sobre HOLD_LOOP_FRAMES frames mientras se sostiene el hold. */
	function loopHold(sprite:LevelSprite):Void
	{
		var cur = sprite.animation.curAnim;
		var data = sprite.currentAnim();
		if (cur == null || data == null || data.index <= 0) return; // idle no cuenta

		var total = cur.numFrames;
		// pocos frames (2 o 3): repetir 2 se ve a saltos, asi que se mantiene la pose del primero
		var count = total <= HOLD_SHORT_ANIM ? 1 : (total < HOLD_LOOP_FRAMES ? total : HOLD_LOOP_FRAMES);
		var start = HOLD_LOOP_LAST ? total - count : 0;

		if (cur.finished || cur.curFrame >= start + count)
			sprite.playAnim(cur.name, true, sprite.lastAnimContext, false, start);
	}

	override public function update(elapsed:Float):Void
	{
		if (loaded)
		{
			for (line in singing.keys())
			{
				if (!singing.get(line) || songTime < singUntil.get(line))
					continue;

				singing.set(line, false);

				for (object in objects)
				{
					if (object.strumLine == line)
						object.sprite.playIndex(0, true);
				}
			}
		}

		super.update(elapsed);

		if (loaded)
		{
			for (object in objects)
				apply(object);
		}
	}

	/** Pixeles de pantalla por pixel de sprite para un fixed con scale 1: ancho / 1920, sin camara. */
	inline function fixedPixelsPerUnit():Float
	{
		return FlxG.width / HUD_REF_WIDTH * defaultHudZoom;
	}

	inline function pixelsPerUnit():Float
	{
		return CAM_PRESET * FlxG.width
			/ (VIEW_WORLD_WIDTH * Math.max(0.001, camScale * zoomMul));
	}

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
				// FIXED: vive en camHUD, no sigue la camara del mundo. Su posicion
				// es normalizada de pantalla (0.5, 0.5 = centro) y la escala es
				// scale * animScale * (ancho / 1920), independiente de la camara.
				px = object.x * FlxG.width;
				py = object.y * FlxG.height;

				var unit = animScale * fixedPixelsPerUnit();
				totalX = object.scale * unit;
				totalY = object.scaleY * unit;

			case false:
				// NORMAL: transformar con la camara del mundo, aplicando su
				// scrollFactor (parallax). Con 1 es identico a (x - camX);
				// con 0 se queda donde lo ve la camara inicial.

				var ppu = pixelsPerUnit();

				px = (object.x - camPoints[0].x
					- (camX - camPoints[0].x) * object.scrollX) * ppu
					+ FlxG.width / 2;
				py = (object.y - camPoints[0].y
					- (camY - camPoints[0].y) * object.scrollY) * ppu
					+ FlxG.height / 2;

				totalX = object.scale * animScale * ppu;
				totalY = object.scaleY * animScale * ppu;
		}

		return {
			x: px,
			y: py,
			scaleX: totalX,
			scaleY: totalY
		};
	}

	function playVideo(object:StageObject):Void
	{
		if (object.video == null) return;

		try
		{
			object.videoPlaying = object.video.play();
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

		if (index == object.videoIndex)
			return true;

		object.video.stop();
		object.videoPlaying = false;

		if (!object.video.loadSpriteVideo(
			SpriteBuilder.spriteDir(levelDir, object.videoName),
			index
		))
			return false;

		object.videoIndex = index;
		playVideo(object);

		return true;
	}

	/** Cambia el sprite de un objeto por otro de `sprites/` del nivel (ObjectSpriteSet). */
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

		var index = members.indexOf(old);
		if (index >= 0)
			insert(index, sprite);
		else
			add(sprite);

		remove(old, true);
		old.destroy();

		object.sprite = sprite;
		assignCamera(object);
		apply(object);
		return true;
		#else
		return false;
		#end
	}

	/** Cambia la strumline a la que responde un objeto (ObjectChartChange): -1 ninguna, 0 jugador, 1 oponente, 2+ extras. */
	public function setChart(object:StageObject, line:Int):Bool
	{
		if (line < -1) return false;
		if (object.strumLine == line) return true;

		object.strumLine = line;
		object.sprite.playIndex(0, true);
		return true;
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

		sprite.scale.set(placement.scaleX, placement.scaleY);
		sprite.updateHitbox();

		sprite.antialiasing = Math.min(Math.abs(placement.scaleX), Math.abs(placement.scaleY)) < 1
			|| sprite.antialiasing;

		if (usePivot)
			sprite.placePivot(placement.x, placement.y);
		else
			sprite.centerAt(placement.x, placement.y);
	}

	public function objectAt(value:Dynamic):Null<StageObject>
	{
		var index = Std.int(number(value, -1));

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
			return funky.core.JsonLoose.parse(File.getContent(path));
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

	static function text(value:Dynamic, fallback:String):String
	{
		if (value == null)
			return fallback;

		var parsed = Std.string(value);
		return parsed == "null" ? fallback : parsed;
	}

	static function number(value:Dynamic, fallback:Float):Float
	{
		if (value == null)
			return fallback;

		var parsed = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	override public function destroy():Void
	{
		objects = [];
		super.destroy();
	}
}

