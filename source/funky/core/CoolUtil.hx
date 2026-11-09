package funky.core;
import funky.core.ClientPrefs;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.animation.FlxAnimation;
import flixel.animation.FlxAnimationController;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;
import flixel.system.frontEnds.SoundFrontEnd;
import flixel.tweens.FlxTween;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.util.typeLimit.OneOfTwo;
import haxe.CallStack;
import haxe.Constraints.IMap;
import haxe.EnumTools.EnumValueTools;
import haxe.Json;
import haxe.io.Path;
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
import sys.FileSystem;
import sys.io.File;

#if sys
#end

using StringTools;

final class CoolUtil
{
	public static function getLastExceptionStack():String
		return CallStack.toString(CallStack.exceptionStack());

	public static inline function isNotNull(v:Null<Dynamic>):Bool
		return v != null && !isNaN(v);

	public static inline function getDefault<T>(v:Null<T>, defaultValue:T):T
		return (v == null || isNaN(v)) ? defaultValue : v;

	public static inline function getDefaultFloat(v:Float, defaultValue:Float):Float
		return (Math.isNaN(v)) ? defaultValue : v;

	public static inline function isNaN(v:Dynamic):Bool
		return (v is Float) ? Math.isNaN(cast(v, Float)) : false;

	public static inline function positiveModulo(dividend:Float, divisor:Float):Float
		return ((dividend % divisor) + divisor) % divisor;

	public static inline function positiveModuloInt(dividend:Int, divisor:Int):Int
		return ((dividend % divisor) + divisor) % divisor;

	public static inline function maxInt(p1:Int, p2:Int):Int
		return p1 < p2 ? p2 : p1;

	public static inline function minInt(p1:Int, p2:Int):Int
		return p1 > p2 ? p2 : p1;

	public static inline function floorInt(e:Float):Int
	{
		var r = Std.int(e);
		if (e < 0 && r != e) r--;
		return r;
	}

	public static inline function quantize(value:Float, quant:Float):Float
		return Math.fround(value * quant) / quant;

	/**
	 * Interpolación exponencial independiente del framerate: `a` "persigue" a `b`. `ratio` es la
	 * velocidad de acercamiento (ej.
	 */
	public static inline function fpsLerp(a:Float, b:Float, ratio:Float):Float
		return b + (a - b) * Math.exp(-ratio);

	public static inline function bound(value:Float, min:Float, max:Float):Float
		return (value < min) ? min : (value > max) ? max : value;

	public static inline function boundInt(value:Int, min:Int, max:Int):Int
		return (value < min) ? min : (value > max) ? max : value;

	public static inline function boolToInt(b:Bool):Int
		return b ? 1 : 0;

	public static function getClosestAngle(angle:Float, targetAngle:Float):Float
	{
		var diff:Float = angle - targetAngle;
		if (diff < -180) diff += 360;
		else if (diff > 180) diff -= 360;
		return angle - diff;
	}

	public static function getLuminance(color:FlxColor):Float
		return (0.2126 * color.redFloat + 0.7152 * color.greenFloat + 0.0722 * color.blueFloat);

	public static inline function parseJsonString(str:String):Dynamic
		return Json.parse(str);

	#if sys
	public static function parseJson(path:String):Dynamic
		return Json.parse(File.getContent(path));
	#end

	public static inline function first<T>(array:Array<T>):T
		return array[0];

	public static inline function last<T>(array:Array<T>):T
		return array[array.length - 1];

	public static inline function clear<T>(array:Array<T>):Array<T>
	{
		array.resize(0);
		return array;
	}

	public static inline function pushGroup<T>(array:Array<T>, ...args:T):Array<T>
	{
		for (a in args) array.push(a);
		return array;
	}

	public static inline function pushOnce<T>(array:Array<T>, element:T):Void
		if (!array.contains(element)) array.push(element);

	public static inline function indexOfFromLast<T>(array:Array<T>, element:T):Int
		return array.lastIndexOf(element);

	public static function sortAlphabetically(array:Array<String>, lowercase:Bool = false):Array<String>
	{
		array.sort((a1, a2) ->
		{
			if (lowercase) { a1 = a1.toLowerCase(); a2 = a2.toLowerCase(); }
			if (a1 < a2) return -1;
			if (a1 > a2) return 1;
			return 0;
		});
		return array;
	}

	public static function deepFlatten(arr:Array<Dynamic>, ?result:Array<Dynamic>):Array<Dynamic>
	{
		if (arr == null) return [];
		if (result == null) result = [];
		for (e in arr)
		{
			if (Std.isOfType(e, Array)) deepFlatten(e, result);
			else result.push(e);
		}
		return result;
	}

	/** Convierte "1..3,5,7..9" en [1,2,3,5,7,8,9]. Útil para eventos/steps de charts. */
	public static function parseNumberRange(input:String):Array<Int>
	{
		var result:Array<Int> = [];
		for (part in input.split(","))
		{
			part = part.trim();
			var idx = part.indexOf("..");
			if (idx != -1)
			{
				var start = Std.parseInt(part.substring(0, idx).trim());
				var end = Std.parseInt(part.substring(idx + 2).trim());
				if (start == null || end == null) continue;
				if (start < end) { for (j in start...end + 1) result.push(j); }
				else { for (j in end...start + 1) result.push(start + end - j); }
			}
			else
			{
				var num = Std.parseInt(part);
				if (num != null) result.push(num);
			}
		}
		return result;
	}

	public static function formatNumberRange(numbers:Array<Int>, separator:String = ","):String
	{
		if (numbers.length == 0) return "";
		var result:Array<String> = [];
		var i = 0;
		while (i < numbers.length)
		{
			var start = numbers[i];
			var end = start;
			var direction = 0;
			if (i + 1 < numbers.length)
			{
				if (numbers[i + 1] == end + 1) direction = 1;
				else if (numbers[i + 1] == end - 1) direction = -1;
			}
			if (direction != 0)
				while (i + 1 < numbers.length && (numbers[i + 1] == end + direction)) { end = numbers[i + 1]; i++; }

			if (start == end) result.push('${start}');
			else if (start + direction == end) result.push('${start},${end}');
			else result.push('${start}..${end}');
			i++;
		}
		return result.join(separator);
	}

	public static inline function addZeros(str:String, num:Int):String
	{
		while (str.length < num) str = '0${str}';
		return str;
	}

	public static inline function addEndZeros(str:String, num:Int):String
	{
		while (str.length < num) str = '${str}0';
		return str;
	}

	public static inline function repeat(str:String, times:Int):String
	{
		var r = new StringBuf();
		for (i in 0...times) r.add(str);
		return r.toString();
	}

	public static inline function removeIP(msg:String):String
		return ~/\d+.\d+.\d+.\d+/.replace(msg, "[Your IP]");

	public static function removeBOM(str:String):String
		return StringTools.replace(str, String.fromCharCode(0xFEFF), "");

	/** "01:22.500" a partir de ms (mm:ss.ms) */
	public static inline function timeToStr(time:Float):String
		return '${addZeros(Std.string(Std.int(time / 60000)), 2)}:${addZeros(Std.string(Std.int(time / 1000) % 60), 2)}.${addZeros(Std.string(Std.int(time % 1000)), 3)}';

	public static inline function getFilename(file:String):String
		return new Path(file).file;

	private static var sizeLabels:Array<String> = ["B", "KB", "MB", "GB", "TB"];

	public static function getSizeString(size:Float):String
	{
		var rSize = size;
		var label = 0;
		while (rSize >= 1024 && label < sizeLabels.length - 1) { label++; rSize /= 1024; }
		return Std.int(rSize) + ((label <= 1) ? "" : "." + addZeros(Std.string(Std.int((rSize % 1) * 100)), 2)) + sizeLabels[label];
	}

	public static function setFieldDefault<T>(v:Dynamic, name:String, defaultValue:T):T
	{
		if (Reflect.hasField(v, name))
		{
			var f:Null<Dynamic> = Reflect.field(v, name);
			if (f != null) return cast f;
		}
		Reflect.setField(v, name, defaultValue);
		return defaultValue;
	}

	public static function getColorFromDynamic(c:Dynamic):Null<FlxColor>
	{
		if (c is Int) return c;
		if (c is Float) return Std.int(c);
		if (c is String) return FlxColor.fromString(c);
		if (c is Array)
		{
			var r = 0, g = 0, b = 0, a = 255;
			var array:Array<Dynamic> = cast c;
			for (k => e in array)
			{
				if (e is Int || e is Float)
				{
					switch (k)
					{
						case 0: r = Std.int(e);
						case 1: g = Std.int(e);
						case 2: b = Std.int(e);
						case 3: a = Std.int(e);
					}
				}
			}
			return FlxColor.fromRGB(r, g, b, a);
		}
		return null;
	}

	public static inline function isMapEmpty<K, V>(map:Map<K, V>):Bool
		return !map.keys().hasNext();

	/** Comparación profunda (arrays, mapas, objetos anidados). Útil para tests / diffs de eventos. */
	public static function deepEqual<T>(a:T, b:T):Bool
	{
		if (a == b) return true;
		if (isNull(a) || isNull(b)) return false;

		switch (Type.typeof(a))
		{
			case TNull, TInt, TBool, TUnknown:
				return a == b;
			case TFloat:
				return Math.isNaN(cast a) && Math.isNaN(cast b);
			case TFunction:
				return Reflect.compareMethods(a, b);
			case TEnum(_):
				if (EnumValueTools.getIndex(cast a) != EnumValueTools.getIndex(cast b)) return false;
				return deepEqual(EnumValueTools.getParameters(cast a), EnumValueTools.getParameters(cast b));
			case TClass(_):
				if ((a is String) && (b is String)) return a == b;
				if ((a is Array) && (b is Array))
				{
					var aa = cast(a, Array<Dynamic>);
					var bb = cast(b, Array<Dynamic>);
					if (aa.length != bb.length) return false;
					for (i in 0...aa.length) if (!deepEqual(aa[i], bb[i])) return false;
					return true;
				}
				if ((a is IMap) && (b is IMap))
				{
					var aa = cast(a, IMap<Dynamic, Dynamic>);
					var bb = cast(b, IMap<Dynamic, Dynamic>);
					var ak = [for (key in aa.keys()) key];
					var bk = [for (key in bb.keys()) key];
					ak.sort(Reflect.compare);
					bk.sort(Reflect.compare);
					if (!deepEqual(ak, bk)) return false;
					for (key in ak) if (!deepEqual(aa.get(key), bb.get(key))) return false;
					return true;
				}
				if ((a is Date) && (b is Date)) return cast(a, Date).getTime() == cast(b, Date).getTime();
				if ((a is haxe.io.Bytes) && (b is haxe.io.Bytes))
					return deepEqual(cast(a, haxe.io.Bytes).getData(), cast(b, haxe.io.Bytes).getData());
			case TObject:
		}

		for (field in Reflect.fields(a))
		{
			var pa = Reflect.field(a, field);
			var pb = Reflect.field(b, field);
			if (isFunction(pa))
			{
				if (isNull(pa) != isNull(pb)) return false;
				continue;
			}
			if (!deepEqual(pa, pb)) return false;
		}
		return true;
	}

	static inline function isNull(a:Dynamic):Bool return Type.enumEq(Type.typeof(a), TNull);
	static inline function isFunction(a:Dynamic):Bool return Type.enumEq(Type.typeof(a), TFunction);

	// FlxTween.parseFieldString existe en Flixel pero es PRIVADO (uso interno
	// de VarTween), no se puede llamar desde afuera. Lo reimplementamos acá,
	// mismo formato de salida (Array<String o Int>).
	static var PROPERTY_TOKEN = ~/([^.\[\]]+)|\[(\d+)\]/g;

	public static function parsePropertyString(fieldPath:String):Array<OneOfTwo<String, Int>>
	{
		var result:Array<OneOfTwo<String, Int>> = [];
		var pos = 0;
		while (pos <= fieldPath.length && PROPERTY_TOKEN.matchSub(fieldPath, pos))
		{
			var idx = PROPERTY_TOKEN.matched(2);
			if (idx != null && idx.length > 0)
				result.push(Std.parseInt(idx));
			else
				result.push(PROPERTY_TOKEN.matched(1));

			var mpos = PROPERTY_TOKEN.matchedPos();
			pos = mpos.pos + mpos.len;
			if (mpos.len == 0) pos++; // no quedarse trabado en match vacío
		}
		return result;
	}

	public static function stringifyFieldsPath(fields:Array<OneOfTwo<String, Int>>):String
	{
		var str = new StringBuf();
		var isFirst = true;
		for (field in fields)
		{
			if (Type.typeof(field) == TInt) str.add('[${field}]');
			else { if (!isFirst) str.add('.'); str.add(field); }
			isFirst = false;
		}
		return str.toString();
	}

	public static function parseProperty(target:Dynamic, fields:OneOfTwo<String, Array<OneOfTwo<String, Int>>>):PropertyInfo
	{
		var fieldsArr:Array<OneOfTwo<String, Int>> = (fields is String) ? parsePropertyString(cast fields) : cast fields;
		var field = last(fieldsArr);
		for (i in 0...fieldsArr.length - 1)
		{
			var component = fieldsArr[i];
			if (Type.typeof(component) == TInt)
			{
				if (target is Array)
				{
					var index:Int = cast component;
					target = (cast target : Array<Dynamic>)[index];
				}
			}
			else target = Reflect.getProperty(target, component);

			if (!Reflect.isObject(target) && !(target is Array))
				throw 'The object does not have the property "$component" in "${stringifyFieldsPath(fieldsArr)}"';
		}
		return new PropertyInfo(target, field);
	}

	public static function cloneProperty(toTarget:Dynamic, fields:OneOfTwo<String, Array<OneOfTwo<String, Int>>>, fromTarget:Dynamic):Void
	{
		var toProperty = parseProperty(toTarget, fields);
		var fromProperty = parseProperty(fromTarget, fields);
		toProperty.setValue(fromProperty.getValue());
	}

	public static inline function setUnstretchedGraphicSize(sprite:FlxSprite, width:Int, height:Int, fill:Bool = true, maxScale:Float = 0):Void
	{
		sprite.setGraphicSize(width, height);
		sprite.updateHitbox();
		var nScale = (fill ? Math.max : Math.min)(sprite.scale.x, sprite.scale.y);
		if (maxScale > 0 && nScale > maxScale) nScale = maxScale;
		sprite.scale.set(nScale, nScale);
	}

	public static function setGraphicSizeFloat(sprite:FlxSprite, width:Float = 0, height:Float = 0):Void
	{
		if (width <= 0 && height <= 0) return;
		var newScaleX = width / sprite.frameWidth;
		var newScaleY = height / sprite.frameHeight;
		sprite.scale.set(newScaleX, newScaleY);
		if (width <= 0) sprite.scale.x = newScaleY;
		else if (height <= 0) sprite.scale.y = newScaleX;
	}

	public static inline function setSpriteSize(sprite:FlxSprite, width:Float, height:Float):Void
	{
		sprite.scale.set(width / sprite.frameWidth, height / sprite.frameHeight);
		sprite.updateHitbox();
	}

	public static inline function cameraCenter(obj:FlxObject, cam:FlxCamera, axes:FlxAxes = XY):Void
	{
		switch (axes)
		{
			case XY: obj.setPosition((cam.width - obj.width) / 2, (cam.height - obj.height) / 2);
			case X: obj.x = (cam.width - obj.width) / 2;
			case Y: obj.y = (cam.height - obj.height) / 2;
			case NONE:
		}
	}

	public static function worldToScreenPosition(object:FlxObject, ?camera:FlxCamera, ?result:FlxPoint):FlxPoint
	{
		if (result == null) result = FlxPoint.get();
		if (camera == null) camera = FlxG.camera;
		result.set(object.x, object.y);
		result.x = (((result.x - camera.scroll.x * object.scrollFactor.x) * camera.zoom) - ((camera.width * 0.5) * (camera.zoom - camera.initialZoom)));
		result.y = (((result.y - camera.scroll.y * object.scrollFactor.y) * camera.zoom) - ((camera.height * 0.5) * (camera.zoom - camera.initialZoom)));
		return result;
	}

	public static function mouseOverlaps(sprite:FlxObject, ?camera:FlxCamera):Bool
	{
		var cam = camera ?? sprite.camera;
		var mouseWorld = FlxG.mouse.getWorldPosition(cam);
		return mouseWorld != null && FlxMath.inBounds(mouseWorld.x, sprite.x, sprite.x + sprite.width) && FlxMath.inBounds(mouseWorld.y, sprite.y, sprite.y + sprite.height);
	}

	public static inline function copyColorTransform(color1:ColorTransform, color2:ColorTransform):Void
	{
		color1.alphaMultiplier = color2.alphaMultiplier;
		color1.alphaOffset = color2.alphaOffset;
		color1.blueMultiplier = color2.blueMultiplier;
		color1.blueOffset = color2.blueOffset;
		color1.greenMultiplier = color2.greenMultiplier;
		color1.greenOffset = color2.greenOffset;
		color1.redMultiplier = color2.redMultiplier;
		color1.redOffset = color2.redOffset;
	}

	public static function resetSprite(spr:FlxSprite, x:Float, y:Float):Void
	{
		spr.setPosition(x, y);
		spr.alpha = 1;
		spr.angle = 0;
		spr.visible = true;
		spr.scale.set(1, 1);
	}

	/** Intercambia los frames de dos animaciones (in-place). */
	public static function switchAnimFrames(anim1:FlxAnimation, anim2:FlxAnimation):Void
	{
		if (anim1 == null || anim2 == null) return;
		var old = anim1.frames;
		anim1.frames = anim2.frames;
		anim2.frames = old;
	}

	/** Intercambia los nombres/entradas de dos animaciones en un controller (ej: swap idle/confirm). */
	public static function swapAnims(animation:FlxAnimationController, anim1:String, anim2:String):Void
	{
		@:privateAccess
		{
			var flxAnim1 = animation.getByName(anim1);
			animation._animations.remove(anim1);
			var flxAnim2 = animation.getByName(anim2);
			animation._animations.remove(anim2);
			if (flxAnim1 != null) { flxAnim1.name = anim2; animation._animations.set(anim2, flxAnim1); }
			if (flxAnim2 != null) { flxAnim2.name = anim1; animation._animations.set(anim1, flxAnim2); }
		}
	}

	public static inline function keyToString(key:Null<FlxKey>):String
	{
		return switch (key)
		{
			case null | 0 | NONE: "---";
			case LEFT: "←";
			case DOWN: "↓";
			case UP: "↑";
			case RIGHT: "→";
			case ESCAPE: "ESC";
			case BACKSPACE: "[←]";
			default: key.toString();
		}
	}

	#if sys
	/** Devuelve "xml"/"txt"/"json" según qué archivo de datos de frames exista junto a la imagen, o null. */
	public static function imageHasFrameData(path:String):String
	{
		if (FileSystem.exists(Path.withExtension(path, "xml"))) return "xml";
		if (FileSystem.exists(Path.withExtension(path, "txt"))) return "txt";
		if (FileSystem.exists(Path.withExtension(path, "json"))) return "json";
		return null;
	}
	#end

	/** Carga frames desde texto (Sparrow XML / SpriteSheetPacker TXT), sin imagen real (para parseo). */
	public static function loadFramesFromData(data:String, ext:String = null):FlxFramesCollection
	{
		var frames:FlxFramesCollection = null;
		var tempBitmap = new BitmapData(1, 1, false);
		var graphic:FlxGraphic = FlxG.bitmap.add(tempBitmap);
		@:privateAccess { graphic.width = 9999999; graphic.height = 9999999; }

		try
		{
			switch (ext)
			{
				case "xml": frames = FlxAtlasFrames.fromSparrow(graphic, Xml.parse(data));
				case "txt": frames = FlxAtlasFrames.fromSpriteSheetPacker(graphic, data);
			}
		}
		catch (e) { funky.core.Log.error('[CoolUtil] loadFramesFromData: $e'); }

		return frames;
	}

	public static function getAnimsListFromFrames(frames:FlxFramesCollection, ext:String = null):Array<String>
	{
		if (frames == null) return [];
		var animsList:Array<String> = [];
		for (frame in frames.frames)
		{
			var animName = ext == "txt" ? frame.name.split("_")[0] : frame.name.substr(0, frame.name.length - 4);
			if (!animsList.contains(animName)) animsList.push(animName);
		}
		return animsList;
	}

	/**
	 * Reproduce música desde `Paths.music(name)`, opcionalmente persistente entre estados.
	 * Reemplaza a la música actual si había una sonando.
	 */
	public static function playMusic(name:String, persist:Bool = false, volume:Float = 1, looped:Bool = true, group:FlxSoundGroup = null):Void
	{
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		FlxG.sound.playMusic(Paths.music(name), volume, looped, group);
		if (FlxG.sound.music != null) FlxG.sound.music.persist = persist;
	}

	/** Nombre del archivo de música de menú (`assets/music/$MENU_SONG.ogg`). */
	public static var MENU_SONG:String = "freakyMenu";

	/** Musica de los editores (`assets/music/breakfast.ogg`), la de Codename Engine. */
	public static var EDITOR_SONG:String = "breakfast";

	/** Ultima musica de menu / editores que se puso con playMenuSong / playEditorSong. */
	static var currentMusic:String = null;

	/** El FlxSound de esa musica: si el charter / un nivel lo reemplaza, `breakfast` se vuelve a poner al volver a un editor. */
	static var currentSound:flixel.sound.FlxSound = null;

	/** Musica de los editores (modo avanzado y sus pantallas): breakfast en vez de la del menu. No reinicia si ya suena. */
	public static function playEditorSong():Void
	{
		if (FlxG.sound.music != null && FlxG.sound.music == currentSound && FlxG.sound.music.playing && currentMusic == EDITOR_SONG) return;

		try
		{
			currentMusic = EDITOR_SONG;
			playMusic(EDITOR_SONG, true, 1, true);
			currentSound = FlxG.sound.music;
		}
		catch (e:Dynamic)
		{
			funky.core.Log.warn('[CoolUtil] No se pudo cargar la musica de editores ($EDITOR_SONG): $e');
		}
	}

	/**
	 * Música de menú (igual que `CoolUtil.playMenuSong` en Codename Engine): si ya está sonando
	 * (porque venís de otro menú y la dejaste `persist`), NO la reinicia — sigue tal cual, sin el
	 * corte feo de reiniciar el tema cada vez que cambiás de menú.
	 */
	public static function playMenuSong(fadeIn:Bool = false):Void
	{
		// Si suena la de los editores (breakfast) se cambia a la de menu; cualquier otra musica se respeta como antes.
		if (FlxG.sound.music != null && FlxG.sound.music.playing && currentMusic != EDITOR_SONG) return;

		try
		{
			currentMusic = MENU_SONG;
			playMusic(MENU_SONG, true, fadeIn ? 0 : 1, true);
			currentSound = FlxG.sound.music;
			if (fadeIn && FlxG.sound.music != null)
				FlxG.sound.music.fadeIn(4, 0, 1);
		}
		catch (e:Dynamic)
		{
			// No tirar el menú abajo si falta el .ogg (assets sueltos, build sin música, etc).
			funky.core.Log.warn('[CoolUtil] No se pudo cargar la música de menú ($MENU_SONG): $e');
		}
	}

	/** Reproduce un sonido puntual desde `Paths.sound(name)` (ej: menú, confirmar, cancelar). */
	public static inline function playSound(name:String, volume:Float = 1):FlxSound
		return FlxG.sound.play(Paths.sound(name), volume * ClientPrefs.getSfxVolume() * ClientPrefs.getMasterVolume());

	/** Reproduce un sonido de `assets/sounds/menu/` (scroll, confirm, cancel...). */
	public static inline function playMenuSound(name:String, volume:Float = 1):FlxSound
		return FlxG.sound.play(Paths.SOUNDS + "menu/" + name + ".ogg", volume * ClientPrefs.getSfxVolume() * ClientPrefs.getMasterVolume());

	public static inline function replay(sound:FlxSound):Void
		sound.play(true, 0);

	public static inline function setMusic(frontEnd:SoundFrontEnd, music:FlxSound):Void
	{
		if (frontEnd.music == music) return;

		// SoundFrontEnd.destroySound() no existe como API pública/privada
		// accesible en esta versión de Flixel — se logra lo mismo a mano:
		// frenar y destruir el FlxSound que estaba de música antes de
		// reemplazarlo.
		if (frontEnd.music != null)
		{
			frontEnd.music.stop();
			frontEnd.music.destroy();
		}

		frontEnd.list.remove(music);
		frontEnd.defaultMusicGroup.add(frontEnd.music = music);
	}

	public static inline function openURL(url:String):Void
	{
		#if linux
		var cmd = Sys.command("xdg-open", [url]);
		if (cmd != 0) Sys.command("/usr/bin/xdg-open", [url]);
		#else
		FlxG.openURL(url);
		#end
	}

	#if sys
	public static inline function browsePath(path:String):Void
	{
		var formattedPath = Path.normalize(path);
		#if windows
		Sys.command("explorer", [formattedPath.replace("/", "\\")]);
		#elseif mac
		Sys.command("open", [formattedPath]);
		#elseif linux
		var cmd = Sys.command("xdg-open", [formattedPath]);
		if (cmd != 0) Sys.command("/usr/bin/xdg-open", [formattedPath]);
		#end
	}
	#end
}

/** Referencia a una propiedad anidada (`obj.a.b[2].c`), usado por `CoolUtil.parseProperty`. */
class PropertyInfo
{
	public var object:Dynamic;
	public var field:OneOfTwo<String, Int>;
	public var typeOfField:Type.ValueType;

	public function new(object:Dynamic, field:OneOfTwo<String, Int>)
	{
		this.object = object;
		this.field = field;
		typeOfField = Type.typeof(field);
	}

	public function getValue():Dynamic
	{
		if (typeOfField == TInt)
		{
			var index:Int = cast field;
			return (cast object : Array<Dynamic>)[index];
		}
		return Reflect.getProperty(object, field);
	}

	public function setValue(value:Dynamic):Void
	{
		if (typeOfField == TInt)
		{
			var index:Int = cast field;
			(cast object : Array<Dynamic>)[index] = value;
		}
		else Reflect.setProperty(object, field, value);
	}
}
