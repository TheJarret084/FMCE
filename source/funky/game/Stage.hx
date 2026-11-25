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

	/** Pose puesta por un evento (ObjectAnimationSet != idle): las notas no la pisan hasta que expire (como IsSetByEvent del Player). */
	public var setByEvent:Bool = false;

	/** ms que faltan para volver a idle (_singTimer del Player). Solo cuenta con la nota suelta. */
	public var singTimer:Float = 0;

	/** Animacion que se puso con loop true pero es pose de nota: toca una vez y espera al timer. */
	public var loopFlag:Bool = true;

	public var wasHolding:Bool = false;
	public var completingHold:Bool = false;

	/** Carril que canta (-1 = nada / miss) y hasta cuando cuenta como "cantando" (ms de cancion). */
	public var lane:Int = -1;
	public var laneUntil:Float = 0;

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

	public static var usePivot:Bool = true;

	/**
	 * scrollFactor. false = la formula que ya tenia FMCE (y que usa el SceneEditor), NO se toco.
	 * true = la del Player: pantalla = (pos - cam * sf) * ppu + vw / 2. Con sf = 1 las dos dan lo mismo;
	 * con sf != 1 la de FMCE queda corrida (vw / 2) * (1 - sf). Si lo activas, cambia tambien SceneEditorState.computeView.
	 */
	static inline var PLAYER_PARALLAX:Bool = false;

	/** Frames que se repiten mientras se mantiene la nota (HOLD_LOOP_FRAMES del Player). */
	static inline var HOLD_LOOP_FRAMES:Int = 2;

	/** Cuanto "dura" cada llamada a hold() (PlayState la llama cada frame con la tecla abajo). */
	static inline var HOLD_GRACE_MS:Float = 120;

	/** Minimo que aguanta una pose antes de volver a idle (SingHold del Player: max(0.5 s, 1 beat)). */
	static inline var MIN_SING_MS:Float = 500;

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

	var holdMs:Float = 500;
	var singHoldMs:Float = MIN_SING_MS;

	public var camHUD:Null<FlxCamera>;

	// Valores de camara/vista que se calculan UNA vez por frame (antes se recalculaban por cada objeto).
	var fVw:Float = 1;
	var fVh:Float = 1;
	var fPpu:Float = 1;
	var fFixedUnit:Float = 1;
	var fCamX:Float = 0;
	var fCamY:Float = 0;

	public function new(song:SongData, ?camHUD:FlxCamera)
	{
		super();

		this.camHUD = camHUD;
		current = this;

		levelDir = song.levelDir == null ? "" : song.levelDir;
		bpm = song.bpm <= 0 ? 120 : song.bpm;
		stepsPerBeat = song.stepsPerBeat;
		holdMs = song.beatMs;
		singHoldMs = Math.max(MIN_SING_MS, holdMs);

		#if sys
		if (song.levelDir != null
			&& FileSystem.exists(Path.join([levelDir, "scene.json"])))
		{
			build();
		}
		#end
	}

	// ------------------------------------------------------------------ creador (CreateAnimators del Player)

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

		prepareFrame();

		var missing = new Map<String, Bool>();

		for (item in asArray(field(scene, "objects")))
		{
			var name = CoolUtil.text(field(item, "spr"), "");
			var itemFixed = field(item, "fixed") == true;
			var transforms = readTransforms(item, itemFixed);

			if (name == "" || transforms.length == 0)
			{
				addPlaceholder(name);
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
				if (!missing.exists(name))
					Log.warn('[Stage] falta el sprite "' + name + '" de scene.json');

				missing.set(name, true);
				addPlaceholder(name);
				continue;
			}

			sprite.scrollFactor.set();
			tint(sprite, field(item, "color"));

			var object = makeObject(item, name, sprite, transforms);

			objects.push(object);
			add(sprite);
			assignCamera(object);

			// Pose inicial: la que pide el objeto (obj.Anim del Player) o idle si es personaje.
			var startAnim = field(item, "anim");
			if (startAnim != null)
				playObject(object, Std.int(CoolUtil.number(startAnim, 0)), false);
			else if (object.strumLine >= 0)
				playObject(object, object.baseAnim, false);

			apply(object);
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

	static function readTransforms(item:Dynamic, itemFixed:Bool):Array<StageTransform>
	{
		var transforms:Array<StageTransform> = [];

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

		// Formato viejo: x / y / scale sueltos en el objeto.
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

		return transforms;
	}

	static function tint(target:FlxSprite, color:Dynamic):Void
	{
		if (color == null) return;

		target.color = FlxColor.fromRGB(
			Std.int(CoolUtil.number(field(color, "r"), 255)),
			Std.int(CoolUtil.number(field(color, "g"), 255)),
			Std.int(CoolUtil.number(field(color, "b"), 255))
		);
	}

	function makeObject(item:Dynamic, name:String, holder:LevelSprite, transforms:Array<StageTransform>):StageObject
	{
		var object = new StageObject(
			holder,
			Std.int(CoolUtil.number(field(item, "strumLine"), -1)),
			field(item, "fixed") == true,
			transforms,
			field(item, "visible") != false,
			CoolUtil.number(field(item, "opacity"), 1)
		);

		object.id = objects.length;
		object.name = name;
		return object;
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

			addPlaceholder(name);
			return;
		}

		video.scrollFactor.set();
		tint(video, field(item, "color"));

		var hole = new LevelSprite();
		hole.visible = false;

		var object = makeObject(item, name, hole, transforms);
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

	/** Hueco para que los indices de scene.json (y los eventos) sigan alineados. */
	function addPlaceholder(name:String = ""):Void
	{
		var empty = new LevelSprite();
		empty.visible = false;

		var object = new StageObject(
			empty,
			-1,
			true,
			[{x: 0, y: 0, scale: 1, scaleY: 1, scrollX: 1, scrollY: 1}],
			false,
			0
		);
		object.id = objects.length;
		object.name = name;
		objects.push(object);
	}
	#end

	function assignCamera(object:StageObject):Void
	{
		if (!object.fixed || camHUD == null) return;

		object.sprite.cameras = [camHUD];

		if (object.video != null)
			object.video.cameras = [camHUD];
	}

	// ------------------------------------------------------------------ poses (SpriteAnimator del Player)

	/** Duracion (ms) de una pasada completa de la animacion actual (frames / fps). */
	inline function animMs(sprite:LevelSprite):Float
	{
		var cur = sprite.animation.curAnim;
		return cur != null && cur.frameRate > 0 ? cur.numFrames / cur.frameRate * 1000 : 0;
	}

	/**
	 * SetAnimation del Player. Reglas:
	 * - Personaje en pose de nota (no idle, no evento): toca UNA vez aunque loop sea true y espera al timer para volver a idle.
	 * - Evento / idle / props: respetan el loop del config.
	 * - loop false: se queda en el ultimo frame y NUNCA vuelve solo a idle.
	 */
	function playObject(object:StageObject, index:Int, byEvent:Bool):Bool
	{
		var sprite = object.sprite;
		if (!sprite.playIndex(index, true)) return false;

		var cur = sprite.animation.curAnim;
		var data = sprite.currentAnim();
		var loop = data == null || data.loop;
		var character = object.strumLine >= 0;
		var idle = index == object.baseAnim;
		var poseOnce = character && !byEvent && !idle && loop;

		object.loopFlag = loop && !poseOnce;
		if (cur != null) cur.looped = object.loopFlag;

		object.setByEvent = byEvent;
		object.completingHold = false;
		object.singTimer = 0;

		if (character && !idle && (loop || byEvent))
		{
			var duration = animMs(sprite);
			object.singTimer = loop ? Math.max(singHoldMs, duration) : duration;
		}

		return true;
	}

	/** Vuelve a idle sin tocar el resto del estado. */
	function toIdle(object:StageObject):Void
	{
		object.singAnim = -1;
		object.holdUntil = 0;
		object.lane = -1;

		if (!playObject(object, object.baseAnim, false))
			playObject(object, 0, false);
	}

	inline function clampInt(value:Int, low:Int, high:Int):Int
		return value < low ? low : (value > high ? high : value);

	public function sing(strumLine:Int, lane:Int, holdEnd:Float = -1):Void
	{
		if (strumLine < 0) return;

		for (object in objects)
		{
			if (object.strumLine != strumLine || object.video != null) continue;

			// Los eventos mandan sobre las notas (IsSetByEvent).
			if (object.setByEvent) continue;

			// lane + 1 = animacion de canto; si el sprite tiene menos, usa la ultima (nunca idle).
			var index = clampInt(lane + 1, 1, Std.int(Math.max(1, object.sprite.animCount() - 1)));

			object.singAnim = playObject(object, index, false) ? index : -1;
			object.holdUntil = holdEnd > songTime ? holdEnd : 0;
			object.lane = object.singAnim > 0 ? lane : -1;
			object.laneUntil = songTime + holdMs;
		}
	}

	/**
	 * Lane que esta cantando la strumLine ahora mismo (0 izq, 1 abajo, 2 arriba, 3 der...), o -1 si no canta (o esta en miss).
	 */
	public function singLane(strumLine:Int):Int
	{
		for (object in objects)
			if (object.strumLine == strumLine && object.lane >= 0 && songTime < object.laneUntil)
				return object.lane;

		return -1;
	}

	/** La nota se mantiene: alarga la pose HOLD_GRACE_MS mas (PlayState lo llama cada frame mientras la tecla sigue abajo). */
	public function hold(strumLine:Int):Void
	{
		if (strumLine < 0) return;

		for (object in objects)
		{
			if (object.strumLine != strumLine || object.singAnim <= 0 || object.setByEvent) continue;

			object.holdUntil = songTime + HOLD_GRACE_MS;
			object.laneUntil = songTime + holdMs;
		}
	}

	public function miss(strumLine:Int):Void
	{
		if (strumLine < 0) return;

		for (object in objects)
		{
			if (object.strumLine != strumLine || object.video != null || object.setByEvent) continue;

			var count = object.sprite.animCount();
			var index = count > 5 ? 5 : count - 1;
			if (index < 1) continue;

			object.holdUntil = 0;
			object.singAnim = playObject(object, index, false) ? index : -1;
			object.lane = -1;
			object.laneUntil = 0;
		}
	}

	/**
	 * Un personaje (strumLine >= 0) por frame: temporizador de pose, vuelta a idle y loop de los 2 primeros frames mientras
	 * dura la nota (Update del SpriteAnimator). Los props no pasan por aqui: los anima Flixel solo.
	 */
	function tickPose(object:StageObject, elapsed:Float):Void
	{
		var sprite = object.sprite;
		var cur = sprite.animation.curAnim;
		if (cur == null) return;

		var data = sprite.currentAnim();
		var loop = data == null || data.loop;
		var idle = data != null && data.index == object.baseAnim;

		var holdActive = object.holdUntil > 0 && songTime < object.holdUntil;
		if (object.holdUntil > 0 && songTime >= object.holdUntil) object.holdUntil = 0;

		var released = object.wasHolding && !holdActive;
		object.wasHolding = holdActive;

		if (!holdActive)
		{
			if (object.singTimer > 0) object.singTimer -= elapsed * 1000;

			if (object.singTimer <= 0 && !idle)
			{
				// Termino la pose por evento: las notas vuelven a mandar.
				if (object.setByEvent && (loop || cur.finished)) object.setByEvent = false;

				// Solo vuelve a idle si loop es true (loop false se queda en la pose). Espera a que la pose termine.
				if (loop && (cur.finished || cur.numFrames <= 1 || cur.curFrame >= cur.numFrames - 1))
				{
					toIdle(object);
					return;
				}
			}
		}
		else
		{
			object.singTimer = loop ? singHoldMs : 0;
		}

		var total = cur.numFrames;

		if (holdActive && total > HOLD_LOOP_FRAMES)
		{
			// Con la nota abajo se repiten los frames 0..1.
			if (cur.finished)
			{
				sprite.playAnim(cur.name, true, sprite.lastAnimContext, false, 0);
				cur = sprite.animation.curAnim;
				if (cur != null) cur.looped = object.loopFlag;
			}
			else if (cur.curFrame >= HOLD_LOOP_FRAMES)
				cur.curFrame = cur.curFrame % HOLD_LOOP_FRAMES;

			object.completingHold = false;
		}
		else if (released && total > HOLD_LOOP_FRAMES)
		{
			// Soltaste la nota: salta a la cola de la animacion y la termina sin repetir.
			if (cur.curFrame < HOLD_LOOP_FRAMES && !object.completingHold)
				cur.curFrame = HOLD_LOOP_FRAMES;

			object.completingHold = true;
		}
		else if (!holdActive && object.completingHold && cur.curFrame < HOLD_LOOP_FRAMES)
		{
			cur.curFrame = HOLD_LOOP_FRAMES;
		}

		if (cur != null && cur.finished)
			object.completingHold = false;
	}

	// ------------------------------------------------------------------ loop

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!loaded) return;

		prepareFrame();

		for (object in objects)
		{
			if (object.strumLine >= 0 && object.video == null && object.sprite.loaded)
				tickPose(object, elapsed);

			apply(object);
		}
	}

	/** Camara y vista del frame (una sola vez, no por objeto). */
	function prepareFrame():Void
	{
		fVw = vw();
		fVh = vh();
		fPpu = CAM_PRESET * fVw / (VIEW_WORLD_WIDTH * Math.max(0.001, camScale * zoomMul));
		fFixedUnit = fVw / HUD_REF_WIDTH * defaultHudZoom;
		fCamX = camX + camOffsetX;
		fCamY = camY + camOffsetY;
	}

	var placeX:Float = 0;
	var placeY:Float = 0;
	var placeScaleX:Float = 1;
	var placeScaleY:Float = 1;

	/** Escribe placeX/Y y placeScaleX/Y (campos reutilizados: sin objetos nuevos por frame). */
	function placementFor(object:StageObject, animScale:Float):Void
	{
		if (object.fixed)
		{
			placeX = object.x * fVw;
			placeY = object.y * fVh;

			var unit = animScale * fFixedUnit;
			placeScaleX = object.scale * unit;
			placeScaleY = object.scaleY * unit;
			return;
		}

		if (PLAYER_PARALLAX)
		{
			var sfx = Math.max(0.01, Math.min(4, object.scrollX));
			var sfy = Math.max(0.01, Math.min(4, object.scrollY));
			placeX = (object.x - fCamX * sfx) * fPpu + fVw / 2;
			placeY = (object.y - fCamY * sfy) * fPpu + fVh / 2;
		}
		else
		{
			var halfViewX = fVw / 2 / fPpu;
			var halfViewY = fVh / 2 / fPpu;
			placeX = (object.x - (fCamX - halfViewX) * object.scrollX) * fPpu;
			placeY = (object.y - (fCamY - halfViewY) * object.scrollY) * fPpu;
		}

		placeScaleX = object.scale * animScale * fPpu;
		placeScaleY = object.scaleY * animScale * fPpu;
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

	// ------------------------------------------------------------------ eventos de objeto

	/** ObjectSpriteSet: cambia el sprite y le pasa la pose, el hold y el control por evento al nuevo (los "alts" del Player). */
	public function setSprite(object:StageObject, name:String):Bool
	{
		#if sys
		if (object.video != null || name == "") return false;

		var old = object.sprite;
		if (old.loaded && old.spriteName == name) return true;

		var sprite = SpriteBuilder.build(levelDir, name);
		if (!sprite.loaded) return false;

		var oldData = old.currentAnim();
		var oldIndex = oldData == null ? object.baseAnim : oldData.index;
		var wasByEvent = object.setByEvent;

		sprite.scrollFactor.set();
		sprite.color = old.color;
		sprite.flipX = old.flipX;
		sprite.flipY = old.flipY;
		sprite.blend = old.blend;

		var index = members.indexOf(old);
		if (index >= 0)
			insert(index, sprite);
		else
			add(sprite);

		remove(old, true);
		SpriteCache.give(levelDir, old);

		object.sprite = sprite;

		var safe = clampInt(oldIndex, 0, Std.int(Math.max(0, sprite.animCount() - 1)));
		if (!playObject(object, safe, wasByEvent))
			playObject(object, 0, wasByEvent);

		assignCamera(object);
		prepareFrame();
		apply(object);
		return true;
		#else
		return false;
		#end
	}

	/** ObjectChartChange: al cambiar de strumLine, los de la linea vieja y la nueva vuelven a idle (salvo los que manda un evento). */
	public function setChart(object:StageObject, line:Int):Bool
	{
		if (line < -1) return false;
		if (object.strumLine == line) return true;

		releaseLine(object.strumLine, object);
		releaseLine(line, object);

		object.strumLine = line;
		object.setByEvent = false;
		toIdle(object);
		return true;
	}

	function releaseLine(line:Int, except:StageObject):Void
	{
		if (line < 0) return;

		for (other in objects)
		{
			if (other == except || other.strumLine != line || other.setByEvent || other.video != null) continue;
			toIdle(other);
		}
	}

	/** ObjectAnimationSet: una animacion distinta de idle bloquea las notas hasta que termine (IsSetByEvent). */
	public function setAnim(object:StageObject, index:Int):Bool
	{
		if (object.video != null)
			return setVideo(object, index);

		if (!playObject(object, index, index != object.baseAnim))
			return false;

		object.singAnim = -1;
		object.lane = -1;
		return true;
	}

	/** ObjectBlendColor: tinte base del objeto (sprite o video). */
	public function setTint(object:StageObject, color:FlxColor):Void
	{
		if (object == null) return;
		if (object.video != null) object.video.color = color;
		else object.sprite.color = color;
	}

	/** Tras un seek: todos los personajes a idle (menos los que manda un evento), como al saltar en el Player. */
	public function resetPoses():Void
	{
		for (object in objects)
		{
			if (object.strumLine < 0 || object.video != null || object.setByEvent || !object.sprite.loaded) continue;

			object.wasHolding = false;
			toIdle(object);
		}
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

		placementFor(object, 1);

		video.scale.set(placeScaleX, placeScaleY);
		video.updateHitbox();
		video.antialiasing = true;

		video.setPosition(
			placeX - video.width / 2,
			placeY - video.height / 2
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

		placementFor(object, animScale);

		// updateHitbox solo si cambio la escala o el frame (no en cada objeto, cada frame).
		var sx = placeScaleX;
		var sy = placeScaleY;
		if (sprite.scale.x != sx || sprite.scale.y != sy || sprite.width != sprite.frameWidth * Math.abs(sx) || sprite.height != sprite.frameHeight * Math.abs(sy))
		{
			sprite.scale.set(sx, sy);
			sprite.updateHitbox();
		}

		sprite.antialiasing = Math.min(Math.abs(sx), Math.abs(sy)) < 1
			|| sprite.antialiasing;

		if (usePivot)
			sprite.placePivot(placeX, placeY);
		else
			sprite.centerAt(placeX, placeY);
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
