package funky.backend;

import animate.FlxAnimate;
import animate.FlxAnimateFrames;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxGraphicAsset;
import funky.core.Log;
import funky.core.Paths;
import haxe.Json;
import openfl.utils.Assets as OpenFlAssets;

/** Para que `beatHit` no pise una animacion que alguien bloqueo (cantar, fallar, etc.). */
enum abstract PlayAnimContext(Int)
{
	var NONE = 0;
	var DANCE = 1;
	var SING = 2;
	var MISS = 3;
	var LOCK = 4;
}

/** Como se anima un sprite por si solo: nada, en cada beat, o en bucle. */
enum abstract XMLAnimType(Int)
{
	var NONE = 0;
	var BEAT = 1;
	var LOOP = 2;

	public static function fromString(str:String, def:XMLAnimType = XMLAnimType.NONE):XMLAnimType
	{
		return switch (StringTools.trim(str).toLowerCase())
		{
			case "none": NONE;
			case "beat" | "onbeat": BEAT;
			case "loop": LOOP;
			default: def;
		}
	}
}

typedef BeatAnim =
{
	var name:String;
	var forced:Bool;
}

/** FunkinSprite, portado de Codename Engine (`funkin.backend.FunkinSprite`). */
class FunkinSprite extends FlxAnimate
{
	public var extra:Map<String, Dynamic> = [];
	public var name:String;

	public var spriteAnimType:XMLAnimType = NONE;
	public var beatAnims:Array<BeatAnim> = [];

	/** Si es false, `beatHit` y la animacion no avanzan solas. */
	public var animEnabled:Bool = true;

	/** `config.json` cargado (formato FNMM) o null. Ver `loadConfig`. */
	public var config:Null<Dynamic>;

	/** Par -> alineado a los beats, impar -> desalineado (como en Codename). */
	public var beatInterval(default, set):Int = 2;

	public var beatOffset:Int = 0;
	public var lastAnimContext:PlayAnimContext = DANCE;

	/** Offsets por animacion, en pixeles (se aplican a `offset` en `playAnim`; `updateHitbox()` lo reinicia). */
	public var animOffsets:Map<String, FlxPoint> = new Map();

	var countedBeat:Int = 0;

	public function new(?X:Float = 0, ?Y:Float = 0, ?SimpleGraphic:FlxGraphicAsset)
	{
		super(X, Y);

		if (SimpleGraphic != null)
		{
			if (SimpleGraphic is String)
				loadFromPathOrName(cast SimpleGraphic);
			else
				loadGraphic(SimpleGraphic);
		}

		moves = false;
	}

	/**
	 * Acepta un nombre de imagen (`menus/menuDesat`) o la ruta que devuelve `Paths.image(...)`
	 * (`assets/images/menus/menuDesat.png`, como en Codename). Con ruta: usa el atlas si existe y, si no,
	 * carga la imagen sola en vez de dejar el sprite sin frames.
	 */
	function loadFromPathOrName(path:String):Void
	{
		var name = path;
		var isFile = false;
		if (StringTools.startsWith(name, "assets/images/")) {name = name.substr("assets/images/".length); isFile = true;}
		for (ext in [".png", ".jpg", ".jpeg"])
			if (StringTools.endsWith(name.toLowerCase(), ext)) {name = name.substr(0, name.length - ext.length); isFile = true;}
		if (!isFile) {loadSprite(path); return;}

		var loaded = Paths.getFrames(name);
		if (loaded != null) {loadSprite(name); return;}
		if (openfl.utils.Assets.exists(path)) loadGraphic(path);
		else Log.warn('[FunkinSprite] no existe la imagen "$path"');
	}

	/**
	 * Carga frames desde `assets/images/<path>`: detecta Animate / Sparrow / Packer / Aseprite / imagen sola.
	 * @return este sprite (null en `frames` si no encontro nada; queda un aviso en el log).
	 */
	public function loadSprite(path:String):FunkinSprite
	{
		var loaded = Paths.getFrames(path);
		if (loaded == null)
			Log.warn('[FunkinSprite] no hay frames para "$path"');
		else
			frames = loaded;

		// Si hay config.json junto al atlas, las animaciones salen de ahi.
		if (loaded != null && loadConfig(path))
			addAnimsFromConfig();
		return this;
	}

	/**
	 * Carga un spritemap de Adobe Animate desde CUALQUIER carpeta (la del nivel, el almacenamiento...), no solo
	 * desde `assets/images/`. La carpeta lleva `Animation.json` + `spritemap1.json` + `spritemap1.png`.
	 * Despues registra animaciones con `addAnim(nombre, simboloOLabel, fps, loop)` y toca con `playAnim`.
	 */
	public function loadAnimate(folder:String):FunkinSprite
	{
		var loaded:FlxFramesCollection = null;
		try
		{
			loaded = FlxAnimateFrames.fromAnimate(folder);
		}
		catch (e:Dynamic)
		{
			Log.error('[FunkinSprite] no se pudo leer el spritemap "$folder": $e');
		}

		if (loaded == null)
			Log.warn('[FunkinSprite] no hay spritemap en "$folder" (falta Animation.json o spritemap1.*)');
		else
			frames = loaded;
		return this;
	}

	/** Lee `config.json` (formato FNMM) de `images/<path>/` (atlas Animate) o de la carpeta del atlas: */
	public function loadConfig(path:String):Bool
	{
		var candidates = [Paths.IMAGES + path + "/config.json"];
		var slash = path.lastIndexOf("/");
		if (slash > 0) candidates.push(Paths.IMAGES + path.substr(0, slash) + "/config.json");

		for (file in candidates)
		{
			if (!OpenFlAssets.exists(file)) continue;
			try
			{
				config = Json.parse(OpenFlAssets.getText(file));
				if (config.bilinear != null) antialiasing = config.bilinear == true;
				return true;
			}
			catch (e:Dynamic)
			{
				Log.error('[FunkinSprite] config.json invalido ($file): $e');
			}
		}
		return false;
	}

	/** Crea las animaciones de `config.data`. @return cuantas quedaron registradas. */
	public function addAnimsFromConfig():Int
	{
		if (config == null || !(config.data is Array)) return 0;
		var added = 0;

		for (entry in (config.data : Array<Dynamic>))
		{
			var inAtlas:String = entry.anim != null ? entry.anim : entry.name;
			if (inAtlas == null) continue;
			var gameName:String = entry.name != null ? entry.name : inAtlas;
			// `spd_fps` true = `spd` FPS crudos; false = frames por beat (BPM actual); sin `spd_fps` (viejo) = multiplicador de 24.
			var spdValue:Float = entry.spd != null && entry.spd > 0 ? entry.spd : 1;
			var fps:Float = entry.spd_fps == null ? 24 * spdValue : (entry.spd_fps == true ? spdValue : 1 / Math.max(0.01, spdValue) * funky.core.Conductor.bpm / 60);
			var loop:Bool = entry.loop == null ? true : entry.loop == true;

			addAnim(gameName, inAtlas, fps, loop);

			// Atlas Animate: `name` puede ser simbolo o label; si como simbolo no existe, prueba label.
			if (isAnimate && !hasAnim(gameName)) addAnim(gameName, inAtlas, fps, loop, null, 0, 0, true);

			if (!hasAnim(gameName))
			{
				Log.warn('[FunkinSprite] config.json: "$inAtlas" no existe en el atlas (anim "$gameName")');
				continue;
			}

			var off = entry.offset;
			if (off != null) addOffset(gameName, off.x != null ? off.x : 0, off.y != null ? off.y : 0);
			added++;
		}
		Log.info('[FunkinSprite] config.json: $added animaciones');
		return added;
	}

	/** Copia grafico y propiedades basicas de otro sprite (FlxSprite o FunkinSprite). */
	public static function copyFrom(source:FlxSprite):FunkinSprite
	{
		var spr = new FunkinSprite();
		spr.setPosition(source.x, source.y);
		spr.frames = source.frames;
		spr.animation.copyFrom(source.animation);
		spr.visible = source.visible;
		spr.alpha = source.alpha;
		spr.antialiasing = source.antialiasing;
		spr.scale.set(source.scale.x, source.scale.y);
		spr.scrollFactor.set(source.scrollFactor.x, source.scrollFactor.y);

		if (source is FunkinSprite)
		{
			var other:FunkinSprite = cast source;
			spr.skew.set(other.skew.x, other.skew.y);
			for (key => point in other.animOffsets)
				spr.animOffsets[key] = FlxPoint.get(point.x, point.y);
		}
		return spr;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// "anim" termina -> si existe "anim-loop", sigue con esa (patron de Codename).
		if (isAnimFinished())
		{
			var loopName = getAnimName() + "-loop";
			if (hasAnim(loopName))
				playAnim(loopName, null, lastAnimContext);
		}
	}

	public function beatHit(curBeat:Int):Void
	{
		if (!animEnabled || lastAnimContext == LOCK || beatAnims.length == 0) return;
		if ((curBeat + beatOffset) % beatInterval != 0) return;

		var anim = beatAnims[FlxMath.wrap(countedBeat++, 0, beatAnims.length - 1)];
		if (anim.name != null && anim.name != "null" && anim.name != "none")
			playAnim(anim.name, anim.forced);
	}

	public function stepHit(curStep:Int):Void {}

	public function measureHit(curMeasure:Int):Void {}

	public function addOffset(name:String, x:Float = 0, y:Float = 0):Void
	{
		var old = animOffsets.get(name);
		if (old != null) old.put();
		animOffsets[name] = FlxPoint.get(x, y);
	}

	public function switchOffset(anim1:String, anim2:String):Void
	{
		var old = animOffsets[anim1];
		animOffsets[anim1] = animOffsets[anim2];
		animOffsets[anim2] = old;
	}

	public inline function getAnimOffset(name:String):FlxPoint
		return animOffsets.exists(name) ? animOffsets[name] : FlxPoint.weak(0, 0);

	/**
	 * Agrega una animacion. `prefix` es el prefijo Sparrow, o el simbolo / label si es un atlas Animate.
	 * @param animateAtlasLabel en atlas Animate: true = `prefix` es un label del timeline, false = un simbolo.
	 */
	public function addAnim(name:String, prefix:String, frameRate:Float = 24, ?looped:Bool, ?indices:Array<Int>, x:Float = 0, y:Float = 0,
			animateAtlasLabel:Bool = false):Void
	{
		if (looped == null) looped = false;
		var hasIndices = indices != null && indices.length > 0;

		if (isAnimate)
		{
			if (animateAtlasLabel)
			{
				if (hasIndices) anim.addByFrameLabelIndices(name, prefix, indices, frameRate, looped);
				else anim.addByFrameLabel(name, prefix, frameRate, looped);
			}
			else
			{
				if (hasIndices) anim.addBySymbolIndices(name, prefix, indices, frameRate, looped);
				else anim.addBySymbol(name, prefix, frameRate, looped);
			}
		}
		else
		{
			if (hasIndices) animation.addByIndices(name, prefix, indices, "", frameRate, looped);
			else animation.addByPrefix(name, prefix, frameRate, looped);
		}

		if (x != 0 || y != 0) addOffset(name, x, y);
	}

	public function playAnim(AnimName:String, ?Force:Null<Bool>, Context:PlayAnimContext = NONE, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if (AnimName == null || !hasAnim(AnimName)) return;

		animation.play(AnimName, Force == true, Reversed, Frame);

		// Convencion FNF: `offset` positivo mueve el sprite hacia arriba/izquierda.
		// Solo si la animacion registro uno: si no, se respeta el `offset` que dejo `updateHitbox()` al escalar.
		if (animOffsets.exists(AnimName))
		{
			var animOffset = animOffsets[AnimName];
			offset.set(animOffset.x, animOffset.y);
		}

		lastAnimContext = Context;
	}

	public inline function removeAnim(name:String):Void
		animation.remove(name);

	public inline function hasAnim(AnimName:String):Bool
		return animation.exists(AnimName);

	public inline function getAnimName():String
		return animation.name;

	public inline function getNameList():Array<String>
		return animation.getNameList();

	public inline function stopAnim():Void
		animation.stop();

	public inline function isAnimFinished():Bool
		return animation.curAnim == null || animation.curAnim.finished;

	public inline function isAnimAtEnd():Bool
		return animation.curAnim != null && animation.curAnim.curFrame >= animation.curAnim.numFrames - 1;

	override function updateAnimation(elapsed:Float):Void
	{
		if (animEnabled)
			super.updateAnimation(elapsed);
	}

	override public function destroy():Void
	{
		if (animOffsets != null)
		{
			for (point in animOffsets)
				if (point != null) point.put();
			animOffsets = null;
		}
		extra = null;
		config = null;
		beatAnims = null;
		super.destroy();
	}

	@:noCompletion function set_beatInterval(v:Int):Int
		return beatInterval = v < 1 ? 1 : v;
}
