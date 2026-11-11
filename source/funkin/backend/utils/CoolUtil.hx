package funkin.backend.utils;

#if cpp
import cpp.Float64;
#end
#if sys
import sys.FileSystem;
#end
import flixel.animation.FlxAnimation;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;
import flixel.system.frontEnds.SoundFrontEnd;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.util.typeLimit.OneOfThree;
import flixel.util.typeLimit.OneOfTwo;
import funkin.backend.system.Conductor;
import funkin.backend.utils.XMLUtil.TextFormat;
import haxe.CallStack;
import haxe.Constraints.IMap;
import haxe.EnumTools.EnumValueTools;
import haxe.Json;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.xml.Access;
import lime.utils.Assets;
import openfl.display.BitmapData;
import openfl.geom.ColorTransform;
import animate.FlxAnimateJson;
import flixel.animation.FlxAnimationController;

using StringTools;

@:allow(funkin.game.PlayState)
final class CoolUtil
{

	public static function getLastExceptionStack():String {
		return CallStack.toString(CallStack.exceptionStack());
	}

	public static inline function isNotNull(v:Null<Dynamic>):Bool {
		return v != null && !isNaN(v);
	}

	public static inline function getDefault<T>(v:Null<T>, defaultValue:T):T {
		return (v == null || isNaN((v : Dynamic))) ? defaultValue : v;
	}

	public static inline function getDefaultFloat(v:Float, defaultValue:Float):Float {
		return (Math.isNaN(v)) ? defaultValue : v;
	}

	public static inline function positiveModulo(dividend:Float, divisor:Float) {
		return ((dividend % divisor) + divisor) % divisor;
	}

	public static inline function positiveModuloInt(dividend:Int, divisor:Int) {
		return ((dividend % divisor) + divisor) % divisor;
	}

	public static function parseJson(assetPath:String) {
		return Json.parse(Assets.getText(assetPath));
	}

	@:noUsing public static function deleteFolder(delete:String) {
		#if sys
		if (!FileSystem.exists(delete)) return;
		var files:Array<String> = FileSystem.readDirectory(delete);
		for(file in files) {
			if (FileSystem.isDirectory(delete + "/" + file)) {
				deleteFolder(delete + "/" + file);
				FileSystem.deleteDirectory(delete + "/" + file);
			} else {
				try FileSystem.deleteFile(delete + "/" + file)
				catch(e) Logs.trace("Could not delete " + delete + "/" + file);
			}
		}
		#end
	}

	@:noUsing public static function safeSaveFile(path:String, content:OneOfTwo<String, Bytes>, showErrorBox:Bool = true) {
		#if sys
		try {
			addMissingFolders(Path.directory(path));
			if(content is Bytes) sys.io.File.saveBytes(path, content);
			else sys.io.File.saveContent(path, content);
		} catch(e) {
			var errMsg:String = 'Error while trying to save the file: ${Std.string(e).replace('\n', ' ')}';
			Logs.trace(errMsg);
			if(showErrorBox) funkin.backend.utils.NativeAPI.showMessageBox("Codename Engine Warning", errMsg, MSG_WARNING);
		}
		#end
	}

	@:noUsing public static function addMissingFolders(path:String):String {
		#if sys
		var folders:Array<String> = path.split("/");
		var currentPath:String = "";

		for (folder in folders) {
			currentPath += folder + "/";
			if (!FileSystem.exists(currentPath))
				FileSystem.createDirectory(currentPath);
		}
		#end
		return path;
	}

	public inline static function parseJsonString(str:String)
		return Json.parse(str);

	public static inline function isNaN(v:Dynamic):Bool {
		return (v is Float) ? Math.isNaN(cast(v, Float)) : false;
	}

	public static inline function first<T>(array:Array<T>):T {
		return array[0];
	}

	public static inline function last<T>(array:Array<T>):T {
		return array[array.length - 1];
	}

	public static function setFieldDefault<T>(v:Dynamic, name:String, defaultValue:T):T {
		if (Reflect.hasField(v, name)) {
			var f:Null<Dynamic> = Reflect.field(v, name);
			if (f != null)
				return cast f;
		}
		Reflect.setField(v, name, defaultValue);
		return defaultValue;
	}

	public static inline function addZeros(str:String, num:Int) {
		while(str.length < num) str = '0${str}';
		return str;
	}

	public static inline function addEndZeros(str:String, num:Int) {
		while(str.length < num) str = '${str}0';
		return str;
	}

	private static var sizeLabels:Array<String> = ["B", "KB", "MB", "GB", "TB"];

	public static function getSizeString(size:Float):String {
		var rSize:Float = size;
		var label:Int = 0;
		var len = sizeLabels.length;
		while(rSize >= 1024 && label < len-1) {
			label++;
			rSize /= 1024;
		}
		return Std.int(rSize) + ((label <= 1) ? "" : "." + addZeros(Std.string(Std.int((rSize % 1) * 100)), 2)) + sizeLabels[label];
	}

	 public static function getSizeString64(size: #if cpp Float64 #else Float #end):String {
		var rSize: #if cpp Float64 #else Float #end = size;
		var label:Int = 0;
		var len = sizeLabels.length;
		while(rSize >= 1024 && label < len-1) {
			label++;
			rSize /= 1024;
		}
		return Std.int(rSize) + ((label <= 1) ? "" : "." + addZeros(Std.string(Std.int((rSize % 1) * 100)), 2)) + sizeLabels[label];
	}

	public static inline function removeIP(msg:String):String {
		return ~/\d+.\d+.\d+.\d+/.replace(msg, "[Your IP]");
	}

	@:noUsing public static inline function fpsLerp(v1:Float, v2:Float, ratio:Float):Float {
		return FlxMath.lerp(v1, v2, getFPSRatio(ratio));
	}

	@:noUsing public static inline function lerpColor(color1:FlxColor, color2:FlxColor, ratio:Float, fpsSensitive:Bool = false) {
		if (!fpsSensitive)
			ratio = getFPSRatio(ratio);
		return FlxColor.interpolate(color1, color2, ratio);
	}

	@:noUsing public static inline function getFPSRatio(ratio:Float, ?delta:Float):Float
		return 1.0 - Math.pow(1.0 - ratio, (delta == null ? FlxG.elapsed : delta) * 60);

	public static function getColorFromDynamic(c:Dynamic):Null<FlxColor> {

		if (c is Int) return c;

		if (c is Float) return Std.int(c);

		if (c is String) return FlxColor.fromString(c);

		if (c is Array) {
			var r:Int = 0;
			var g:Int = 0;
			var b:Int = 0;
			var a:Int = 255;
			var array:Array<Dynamic> = cast c;
			for(k=>e in array) {
				if (e is Int || e is Float) {
					switch(k) {
						case 0:	r = Std.int(e);
						case 1:	g = Std.int(e);
						case 2:	b = Std.int(e);
						case 3:	a = Std.int(e);
					}
				}
			}
			return FlxColor.fromRGB(r, g, b, a);
		}
		return null;
	}

	@:noUsing public static function playMenuSong(fadeIn:Bool = false) {
		if (FlxG.sound.music == null || !FlxG.sound.music.playing) {
			playMusic(Paths.music(Flags.DEFAULT_MENU_MUSIC), true, fadeIn ? 0 : 1, true, 102);
			if (fadeIn) FlxG.sound.music.fadeIn(4, 0, 1);
		}
	}

	@:noUsing public static function preloadCharacter(name:String, ?spriteName:String) {
		if (name == null) return;
		if (spriteName == null)
			spriteName = name;
		Assets.getText(Paths.xml('characters/$name'));
		Paths.getFrames('characters/$spriteName');
	}

	@:noUsing public static function playMusic(path:String, Persist:Bool = false, Volume:Float = 1, Looped:Bool = true, DefaultBPM:Float = 102, ?Group:FlxSoundGroup) {
		Conductor.reset();
		if (FlxG.sound.music == null || !FlxG.sound.music.exists) FlxG.sound.music = new FlxSound();
		else if (FlxG.sound.music.active) FlxG.sound.music.stop();
		FlxG.sound.music.loadEmbedded(path, Looped);
		FlxG.sound.music.volume = Volume;
		FlxG.sound.music.persist = Persist;
		FlxG.sound.defaultMusicGroup.add(FlxG.sound.music);

		var iniPath = '${Path.withoutExtension(path)}.ini';
		var musicData:Map<String, String> = null;
		if (musicData != null) {
			if (musicData["LoopTime"] != null) FlxG.sound.music.loopTime = Std.parseFloat(musicData["LoopTime"]) * 1000;
			if (musicData["EndTime"] != null) FlxG.sound.music.endTime = Std.parseFloat(musicData["EndTime"]) * 1000;

			var timeSignParsed:Array<Null<Float>> = musicData["TimeSignature"] == null ? [] : [for(s in musicData["TimeSignature"].split("/")) Std.parseFloat(s)];
			var beatsPerMeasure:Float = Flags.DEFAULT_BEATS_PER_MEASURE, stepsPerBeat:Float = Flags.DEFAULT_STEPS_PER_BEAT;
			if (timeSignParsed.length == 2) {
				beatsPerMeasure = Math.isNaN(timeSignParsed[0]) ? Flags.DEFAULT_BEATS_PER_MEASURE : timeSignParsed[0];
				stepsPerBeat = Math.isNaN(timeSignParsed[1]) ? Flags.DEFAULT_STEPS_PER_BEAT : (16 / timeSignParsed[1]);
			}

			var bpm:Float = Std.parseFloat(musicData["BPM"]).getDefault(DefaultBPM);
			Conductor.changeBPM(bpm, beatsPerMeasure, Math.floor(stepsPerBeat));
		}
		else
			Conductor.changeBPM(DefaultBPM);

		FlxG.sound.music.play();
	}

	@:noUsing public static inline function playMenuSFX(menuSFX:CoolSfx = SCROLL, volume:Float = 1):FlxSound {
		return FlxG.sound.play(Paths.sound(switch(menuSFX) {
			case CONFIRM:	Flags.DEFAULT_MENU_CONFIRM_SOUND;
			case CANCEL:	Flags.DEFAULT_MENU_CANCEL_SOUND;
			case SCROLL:	Flags.DEFAULT_MENU_SCROLL_SOUND;
			case CHECKED:	Flags.DEFAULT_EDITOR_CHECKBOXCHECKED_SOUND;
			case UNCHECKED:	Flags.DEFAULT_EDITOR_CHECKBOXUNCHECKED_SOUND;
			case WARNING:	Flags.DEFAULT_EDITOR_WARNING_SOUND;
			default: 		Flags.DEFAULT_MENU_SCROLL_SOUND;
		}), volume);
	}

	@:noUsing public static function coolTextFile(path:String):Array<String>
	{
		var trim:String;
		return [for(line in Assets.getText(path).split("\n")) if ((trim = line.trim()) != "" && !trim.startsWith("#")) trim];
	}

	@:noUsing public static inline function numberArray(max:Int, ?min:Int = 0):Array<Int>
	{

		var len:Int = CoolUtil.maxInt(max - min, 0);
		#if cpp
		var arr:Array<Int> = untyped __cpp__("::Array_obj< int >::__new({0})", len);
		#else
		var arr:Array<Int> = [];
		arr.resize(len);
		#end
		for(i in 0...len)
			arr[i] = i + min;
		return arr;
	}

	@:noUsing public static inline function numberArrayOld(max:Int, ?min:Int = 0):Array<Int>
	{
		return [for (i in min...max) i];
	}

	@:noUsing public static function switchAnimFrames(anim1:FlxAnimation, anim2:FlxAnimation) {
		if (anim1 == null || anim2 == null) return;
		var old = anim1.frames;
		anim1.frames = anim2.frames;
		anim2.frames = old;
	}

	public static function swapAnims(animation:FlxAnimationController, anim1:String, anim2:String) @:privateAccess {
		var flxAnim1 = animation.getByName(anim1);
		animation._animations.remove(anim1);

		var flxAnim2 = animation.getByName(anim2);
		animation._animations.remove(anim2);

		if (flxAnim1 != null) {
			flxAnim1.name = anim2;
			animation._animations.set(anim2, flxAnim1);
		}
		if (flxAnim2 != null) {
			flxAnim2.name = anim1;
			animation._animations.set(anim1, flxAnim2);
		}
	}

	public static inline function setUnstretchedGraphicSize(sprite:FlxSprite, width:Int, height:Int, fill:Bool = true, maxScale:Float = 0) {
		sprite.setGraphicSize(width, height);
		sprite.updateHitbox();
		var nScale = (fill ? Math.max : Math.min)(sprite.scale.x, sprite.scale.y);
		if (maxScale > 0 && nScale > maxScale) nScale = maxScale;
		sprite.scale.set(nScale, nScale);
	}

	public static function setGraphicSizeFloat(sprite:FlxSprite, Width:Float = 0, Height:Float = 0):Void
	{
		if (Width <= 0 && Height <= 0)
			return;

		var newScaleX:Float = Width / sprite.frameWidth;
		var newScaleY:Float = Height / sprite.frameHeight;
		sprite.scale.set(newScaleX, newScaleY);

		if (Width <= 0)
			sprite.scale.x = newScaleY;
		else if (Height <= 0)
			sprite.scale.y = newScaleX;
	}

	public static inline function keyToString(key:Null<FlxKey>):String {
		return switch(key) {
			case null | 0 | NONE:	"---";
			case LEFT: 				"←";
			case DOWN: 				"↓";
			case UP: 				"↑";
			case RIGHT:				"→";
			case ESCAPE:			"ESC";
			case BACKSPACE:			"[←]";
			case NUMPADZERO:		"#0";
			case NUMPADONE:			"#1";
			case NUMPADTWO:			"#2";
			case NUMPADTHREE:		"#3";
			case NUMPADFOUR:		"#4";
			case NUMPADFIVE:		"#5";
			case NUMPADSIX:			"#6";
			case NUMPADSEVEN:		"#7";
			case NUMPADEIGHT:		"#8";
			case NUMPADNINE:		"#9";
			case NUMPADPLUS:		"#+";
			case NUMPADMINUS:		"#-";
			case NUMPADPERIOD:		"#.";
			case ZERO:				"0";
			case ONE:				"1";
			case TWO:				"2";
			case THREE:				"3";
			case FOUR:				"4";
			case FIVE:				"5";
			case SIX:				"6";
			case SEVEN:				"7";
			case EIGHT:				"8";
			case NINE:				"9";
			case PERIOD:			".";
			default:				key.toString();
		}
	}

	public static inline function cameraCenter(obj:FlxObject, cam:FlxCamera, axes:FlxAxes = XY) {
		switch(axes) {
			case XY:
				obj.setPosition((cam.width - obj.width) / 2, (cam.height - obj.height) / 2);
			case X:
				obj.x = (cam.width - obj.width) / 2;
			case Y:
				obj.y = (cam.height - obj.height) / 2;
			case NONE:
		}
	}

	public static inline function setSpriteSize(sprite:FlxSprite, width:Float, height:Float) {
		sprite.scale.set(width / sprite.frameWidth, height / sprite.frameHeight);
		sprite.updateHitbox();
	}

	public static inline function getAtt(xml:Access, name:String) {

		var xml:Xml = xml.x;
		if (xml.nodeType != Element) {
			throw 'Bad node type, expected Element but found ${xml.nodeType}';
		}
		@:privateAccess
		return xml.attributeMap.exists(name) ? xml.attributeMap.get(name) : null;
	}

	public static function autoSetFormat(text:FlxText, formats:Array<TextFormat>) {
		var i = 0;
		@:privateAccess
		for(format in formats) {
			var fmtt = format.format;
			var start = i;
			var end = i + format.text.length;
			i = end;
			if(Reflect.fields(fmtt).length == 0) continue;
			var fmt = new FlxTextFormat();

			fmt.format.color = Reflect.hasField(fmtt, "color") ? FlxColor.fromString(fmtt.color) : text.color;
			fmt.format.font = Reflect.hasField(fmtt, "font") ? Paths.getFontName(Paths.font(fmtt.font)) : text.font;
			fmt.format.size = Reflect.hasField(fmtt, "size") ? Std.parseInt(fmtt.size) : text.size;
			fmt.format.italic = Reflect.hasField(fmtt, "italic") ? fmtt.italic == "true" : text.italic;
			fmt.format.bold = Reflect.hasField(fmtt, "bold") ? fmtt.bold == "true" : text.bold;
			fmt.borderColor = Reflect.hasField(fmtt, "borderColor") ? FlxColor.fromString(fmtt.borderColor) : text.borderColor;
			fmt.format.align = Reflect.hasField(fmtt, "align") ? TextFormatAlign.fromString(fmtt.align) : FlxTextAlign.toOpenFL(text.alignment);

			if(Reflect.hasField(fmtt, "leading")) fmt.format.leading = Std.parseInt(fmtt.leading);
			if(Reflect.hasField(fmtt, "kerning")) fmt.format.kerning = fmtt.kerning == "true";
			if(Reflect.hasField(fmtt, "blockIndent")) fmt.format.blockIndent = Std.parseInt(fmtt.blockIndent);
			if(Reflect.hasField(fmtt, "bullet")) fmt.format.bullet = fmtt.bullet == "true";
			if(Reflect.hasField(fmtt, "indent")) fmt.format.indent = Std.parseInt(fmtt.indent);
			if(Reflect.hasField(fmtt, "leftMargin")) fmt.format.leftMargin = Std.parseInt(fmtt.leftMargin);
			if(Reflect.hasField(fmtt, "letterSpacing")) fmt.format.letterSpacing = Std.parseFloat(fmtt.letterSpacing);
			if(Reflect.hasField(fmtt, "rightMargin")) fmt.format.rightMargin = Std.parseInt(fmtt.rightMargin);
			if(Reflect.hasField(fmtt, "tabStops")) fmt.format.tabStops = [for(x in cast(fmtt.tabStops, String).split(",")) Std.parseInt(x)];
			if(Reflect.hasField(fmtt, "underline")) fmt.format.underline = fmtt.underline == "true";
			text.addFormat(fmt, start, end);
		}
		return text;
	}

	public static function loadAnimatedGraphic(spr:FlxSprite, path:String, fps:Float = 24.0) {
		spr.frames = Paths.getFrames(path, true);

		if (spr.frames != null && spr.frames.frames != null) {
			spr.animation.add("idle", [for(i in 0...spr.frames.frames.length) i], fps, true);
			spr.animation.play("idle");
		}

		return spr;
	}

	public static inline function copyColorTransform(color1:ColorTransform, color2:ColorTransform) {
		color1.alphaMultiplier 	= color2.alphaMultiplier;
		color1.alphaOffset 		= color2.alphaOffset;
		color1.blueMultiplier 	= color2.blueMultiplier;
		color1.blueOffset 		= color2.blueOffset;
		color1.greenMultiplier 	= color2.greenMultiplier;
		color1.greenOffset 		= color2.greenOffset;
		color1.redMultiplier 	= color2.redMultiplier;
		color1.redOffset 		= color2.redOffset;
	}

	public static function resetSprite(spr:FlxSprite, x:Float, y:Float) {
		spr.reset(x, y);
		spr.alpha = 1;
		spr.visible = true;
		spr.active = true;
		spr.acceleration.set();
		spr.velocity.set();
		spr.drag.set();
		spr.antialiasing = FlxSprite.defaultAntialiasing;
		spr.offset.set();
		FlxTween.cancelTweensOf(spr);
	}

	@:noUsing public static inline function getMacroAbstractClass(className:String) {
		return Type.resolveClass(className + '_HSC');
	}

	public static inline function indexOfFromLast<T>(array:Array<T>, element:T):Int {

		return array.lastIndexOf(element);
	}

	public static inline function clear<T>(array:Array<T>):Array<T> {

		array.resize(0);
		return array;
	}

	public static inline function pushGroup<T>(array:Array<T>, ...args:T):Array<T> {
		for(a in args)
			array.push(a);
		return array;
	}

	@:noUsing public static inline function openURL(url:String) {
		#if linux

		var cmd = Sys.command("xdg-open", [url]);

		if (cmd != 0) cmd = Sys.command("/usr/bin/xdg-open", [url]);
		#else
		FlxG.openURL(url);
		#end
	}

	public static inline function browsePath(path:String) {
		var formattedPath:String = Path.normalize(path);

		#if windows
		formattedPath = formattedPath.replace("/", "\\");
		Sys.command("explorer", [formattedPath]);
		#elseif mac
		Sys.command("open", [formattedPath]);
		#elseif linux
		var cmd = Sys.command("xdg-open", [formattedPath]);
		if (cmd != 0) cmd = Sys.command("/usr/bin/xdg-open", [formattedPath]);
		#end
	}

	public static inline function timeToStr(time:Float)
		return '${Std.string(Std.int(time / 60000)).addZeros(2)}:${Std.string(Std.int(time / 1000) % 60).addZeros(2)}.${Std.string(Std.int(time % 1000)).addZeros(3)}';

	public static inline function replay(sound:FlxSound) sound.play(true, 0);

	@:noUsing public static inline function maxInt(p1:Int, p2:Int)
		return p1 < p2 ? p2 : p1;

	@:noUsing public static inline function minInt(p1:Int, p2:Int)
		return p1 > p2 ? p2 : p1;

	public static inline function floorInt(e:Float) {
		var r = Std.int(e);
		if (e < 0 && r != e)
			r--;
		return r;
	}

	@:noUsing public static inline function quantize(Value:Float, Quant:Float) {
		return Math.fround(Value * Quant) / Quant;
	}

	public static inline function setMusic(frontEnd:SoundFrontEnd, music:FlxSound) {
		if (frontEnd.music == music) return;

		if (frontEnd.music != null) frontEnd.music.destroy();
		frontEnd.list.remove(music);
		frontEnd.defaultMusicGroup.add(frontEnd.music = music);
	}

	@:noUsing public static inline function flxeaseFromString(mainEase:String, ?suffix:String)
		return Reflect.field(FlxEase, mainEase + (mainEase == "linear" || suffix == null ? "" : suffix));

	@:noUsing public static inline function getFilename(file:String) {
		var file = new haxe.io.Path(file);
		return file.file;
	}

	@:noUsing public static function getClosestAngle(angle:Float, targetAngle:Float):Float {
		var diff:Float = angle - targetAngle;
		if (diff < -180) diff += 360;
		else if (diff > 180) diff -= 360;
		return angle - diff;
	}

	public static function worldToScreenPosition(object:FlxObject, ?camera:FlxCamera, ?result:FlxPoint) {
		if (result == null)
			result = FlxPoint.get();
		if (camera == null)
			camera = FlxG.camera;

		result.set(object.x, object.y);
		result.x = (((result.x - camera.scroll.x * object.scrollFactor.x) * camera.zoom) - ((camera.width * 0.5) * (camera.zoom - camera.initialZoom)));
		result.y = (((result.y - camera.scroll.y * object.scrollFactor.y) * camera.zoom) - ((camera.height * 0.5) * (camera.zoom - camera.initialZoom)));
		return result;
	}

	 public static function pointToScreenPosition(object:FlxPoint, ?camera:FlxCamera, ?result:FlxPoint) {
		if (result == null)
			result = FlxPoint.get();
		if (camera == null)
			camera = FlxG.camera;

		result.set(object.x, object.y);
		result.x = (((result.x - camera.scroll.x) * camera.zoom) - ((camera.width * 0.5) * (camera.zoom - camera.initialZoom)));
		result.y = (((result.y - camera.scroll.y) * camera.zoom) - ((camera.height * 0.5) * (camera.zoom - camera.initialZoom)));

		object.putWeak();
		return result;
	}

	public static function mouseOverlaps(sprite:FlxObject, ?camera:FlxCamera) {
		var camToCheck:FlxCamera = camera ?? sprite.camera;
		var posthing:FlxPoint = FlxG.mouse.getWorldPosition(camToCheck);

		return posthing != null && FlxMath.inBounds(posthing.x, sprite.x, sprite.x + sprite.width) && FlxMath.inBounds(posthing.y, sprite.y, sprite.y + sprite.height);
	}

	public static function sortAlphabetically(array:Array<String>, ?lowercase:Bool=false) {
		array.sort(function(a1, a2):Int {
			if(lowercase) {
				a1 = a1.toLowerCase();
				a2 = a2.toLowerCase();
			}
			if (a1 < a2) return -1;
			if (a1 > a2) return 1;
			return 0;
		});
		return array;
	}

	public static inline function pushOnce<T>(array:Array<T>, element:T) {
		#if (haxe >= "4.0.0")
		if (!array.contains(element))
			array.push(element);
		#else
		if (array.indexOf(element) == -1)
			array.push(element);
		#end
	}

	#if !(haxe >= "4.0.0")

	public static inline function contains<T>(array:Array<T>, element:T) {
		return array.indexOf(element) != -1;
	}
	#end

	public static inline function repeat(str:String, times:Int) {
		var r = new StringBuf();
		for(i in 0...times)
			r.add(str);
		return r.toString();
	}

	public static inline function bound(Value:Float, Min:Float, Max:Float):Float {
		#if cpp
		var _hx_tmp1:Float = Value;
		var _hx_tmp2:Float = Min;
		var _hx_tmp3:Float = Max;
		return untyped __cpp__("((({0}) < ({1})) ? ({1}) : (({0}) > ({2})) ? ({2}) : ({0}))", _hx_tmp1, _hx_tmp2, _hx_tmp3);
		#else
		return (Value < Min) ? Min : (Value > Max) ? Max : Value;
		#end
	}

	public static inline function boundInt(Value:Int, Min:Int, Max:Int):Int {
		#if cpp
		var _hx_tmp1:Int = Value;
		var _hx_tmp2:Int = Min;
		var _hx_tmp3:Int = Max;
		return untyped __cpp__("((({0}) < ({1})) ? ({1}) : (({0}) > ({2})) ? ({2}) : ({0}))", _hx_tmp1, _hx_tmp2, _hx_tmp3);
		#else
		return (Value < Min) ? Min : (Value > Max) ? Max : Value;
		#end
	}

	public static inline function boolToInt(b:Bool):Int {
		#if cpp
		return untyped __cpp__("(({0}) ? 1 : 0)", b);
		#else
		return b ? 1 : 0;
		#end
	}

	public static function parseNumberRange(input:String):Array<Int> {
		var result:Array<Int> = [];
		var parts:Array<String> = input.split(",");

		for (part in parts) {
			part = part.trim();
			var idx = part.indexOf("..");
			if (idx != -1) {
				var start = Std.parseInt(part.substring(0, idx).trim());
				var end = Std.parseInt(part.substring(idx + 2).trim());

				if(start == null || end == null) {
					continue;
				}

				if (start < end) {
					for (j in start...end + 1) {
						result.push(j);
					}
				} else {
					for (j in end...start + 1) {
						result.push(start + end - j);
					}
				}
			} else {
				var num = Std.parseInt(part);
				if (num != null) {
					result.push(num);
				}
			}
		}
		return result;
	}

	public static function formatNumberRange(numbers:Array<Int>, separator:String = ","):String {
		if (numbers.length == 0) return "";

		var result:Array<String> = [];
		var i = 0;

		while (i < numbers.length) {
			var start = numbers[i];
			var end = start;
			var direction = 0;

			if (i + 1 < numbers.length) {
				if (numbers[i + 1] == end + 1) {
					direction = 1;
				} else if (numbers[i + 1] == end - 1) {
					direction = -1;
				}
			}

			if(direction != 0) {
				while (i + 1 < numbers.length && (numbers[i + 1] == end + direction)) {
					end = numbers[i + 1];
					i++;
				}
			}

			if (start == end) {
				result.push('${start}');
			} else if (start + direction == end) {
				result.push('${start},${end}');
			} else {
				result.push('${start}..${end}');
			}

			i++;
		}

		return result.join(separator);
	}

	public static function deepFlatten(arr:Array<Dynamic>, ?result:Array<Dynamic>):Array<Dynamic> {
		if(arr == null) return [];
		if(result == null) result = [];
		for (e in arr) {
			if (Std.isOfType(e, Array)) {
				deepFlatten(e, result);
			} else {
				result.push(e);
			}
		}
		return result;
	}

	public static function getLuminance(color:FlxColor):Float {
		return (0.2126*color.redFloat + 0.7152*color.greenFloat + 0.0722*color.blueFloat);
	}

	public static function imageHasFrameData(path:String):String {
		if (FileSystem.exists(Path.withExtension(path, "xml"))) return "xml";
		if (FileSystem.exists(Path.withExtension(path, "txt"))) return "txt";
		if (FileSystem.exists(Path.withExtension(path, "json"))) return "json";

		return null;
	}

	public static function loadFramesFromData(data:String, ext:String = null):FlxFramesCollection {
		var frames:FlxFramesCollection = null;
		var tempBitmap:BitmapData = new BitmapData(1, 1, false);

		var graphic:FlxGraphic = FlxG.bitmap.add(tempBitmap);
		@:privateAccess {

			graphic.width = 9999999;
			graphic.height = 9999999;
		}

		try {
			switch (ext) {
				case "xml": frames = FlxAtlasFrames.fromSparrow(graphic, Xml.parse(data));
				case "txt": frames = FlxAtlasFrames.fromSpriteSheetPacker(graphic, data);
				case "json": frames = FlxAtlasFrames.fromAseprite(graphic, data);
			}
		} catch (e) {trace(e);}

		return frames;
	}

	public static function removeBOM(str:String):String {
		return StringTools.replace(str, String.fromCharCode(0xFEFF), "");
	}

	public static function getAnimsListFromFrames(frames:FlxFramesCollection, ext:String = null):Array<String> {
		if (frames == null) return [];

		var animsList:Array<String> = [];
		for (frame in frames.frames) {
			var animName:String = ext == "txt" ? frame.name.split("_")[0] : frame.name.substr(0, frame.name.length-4);
			if (!animsList.contains(animName))
				animsList.push(animName);
		}

		return animsList;
	}

	public static function getAnimsListFromAtlas(atlas:AnimationJson):Array<String> {
		if (atlas == null) return [];

		var animsList:Array<String> = [];
		if (atlas.AN.SN != null) animsList.push(atlas.AN.SN);
		if (atlas.SD != null)
			for (symbol in atlas.SD)
				if (symbol.SN != null) animsList.push(symbol.SN);

		return animsList;
	}

	public static function getAnimsListFromSprite(spr:FunkinSprite):Array<String> {
		return getAnimsListFromFrames(spr.frames);
	}

	public static function deepEqual<T> (a:T, b:T) : Bool {
		if (a == b) { return true; }
		if (isNull(a) ||  isNull(b)) {
			return false;
		}

		switch (Type.typeof(a)) {
			case TNull, TInt, TBool, TUnknown:
				return a == b;
			case TFloat:
				return Math.isNaN(cast a) && Math.isNaN(cast b);
			case TFunction:
				return Reflect.compareMethods(a, b);
			case TEnum(_):
				if (EnumValueTools.getIndex(cast a) != EnumValueTools.getIndex(cast b)) {
					return false;
				}
				var a_args = EnumValueTools.getParameters(cast a);
				var b_args = EnumValueTools.getParameters(cast b);
				return deepEqual(a_args, b_args);
			case TClass(_):
				if ((a is String) && (b is String)) {
					return a == b;
				}
				if ((a is Array) && (b is Array)) {
					var a = cast(a, Array<Dynamic>);
					var b = cast(b, Array<Dynamic>);
					if (a.length != b.length) { return false; }
					for (i in 0...a.length) {
						if (!deepEqual(a[i], b[i])) {
							return false;
						}
					}
					return true;
				}

				if ((a is IMap) && (b is IMap)) {
					var a = cast(a, IMap<Dynamic, Dynamic>);
					var b = cast(b, IMap<Dynamic, Dynamic>);
					var a_keys = [ for (key in a.keys()) key ];
					var b_keys = [ for (key in b.keys()) key ];
					a_keys.sort(Reflect.compare);
					b_keys.sort(Reflect.compare);
					if (!deepEqual(a_keys, b_keys)) { return false; }
					for (key in a_keys) {
						if (!deepEqual(a.get(key), b.get(key))) {
							return false;
						}
					}
					return true;
				}

				if ((a is Date) && (b is Date)) {
					return cast(a, Date).getTime() == cast(b, Date).getTime();
				}

				if ((a is haxe.io.Bytes) && (b is haxe.io.Bytes)) {
					return deepEqual(cast(a, haxe.io.Bytes).getData(), cast(b, haxe.io.Bytes).getData());
				}

			case TObject:
		}

		for (field in Reflect.fields(a)) {
			var pa = Reflect.field(a, field);
			var pb = Reflect.field(b, field);
			if (isFunction(pa)) {

				if (isNull(pa) != isNull(pb)) {
					return false;
				}
				continue;
			}
			if (!deepEqual(pa, pb)) {
				return false;
			}
		}

		return true;
	}

	static inline function isNull(a:Dynamic):Bool {
		return Type.enumEq(Type.typeof(a), TNull);
	}

	static inline function isFunction(a:Dynamic):Bool {
		return Type.enumEq(Type.typeof(a), TFunction);
	}

	public static inline function isMapEmpty<K, V>(map: Map<K, V>): Bool {
		return !map.keys().hasNext();
	}

	public inline static function parsePropertyString(fieldPath:String):Array<OneOfTwo<String, Int>> {
		return cast fieldPath.split(".");
	}

	public static function stringifyFieldsPath(fields:Array<OneOfTwo<String, Int>>):String {
		var str = new StringBuf();
		var first = true;
		for (field in fields) {
			if (Type.typeof(field) == TInt) {
				str.add('[${field}]');
			} else {
				if (!first)
					str.add('.');
				str.add(field);
			}
			first = false;
		}
		return str.toString();
	}

	public static function parseProperty(target:Dynamic, fields:OneOfTwo<String, Array<OneOfTwo<String, Int>>>):Dynamic {
		var fields:Array<OneOfTwo<String, Int>> = {
			if((fields is String)) CoolUtil.parsePropertyString(fields);
			else fields;
		}

		var field = CoolUtil.last(fields);
		for (i in 0...fields.length - 1) {
			var component = fields[i];
			if (Type.typeof(component) == TInt) {
				if ((target is Array)) {
					var index:Int = cast component;
					var arr:Array<Dynamic> = cast target;
					target = arr[index];
				}
			} else {
				target = Reflect.getProperty(target, component);
			}
			if (!Reflect.isObject(target) && !(target is Array))
				throw 'The object does not have the property "$component" in "${stringifyFieldsPath(fields)}"';
		}
		return new PropertyInfo(target, field);
	}

	public static function cloneProperty(toTarget:Dynamic, fields:OneOfTwo<String, Array<OneOfTwo<String, Int>>>, fromTarget:Dynamic):Dynamic {
		var fields:Array<OneOfTwo<String, Int>> = {
			if((fields is String)) CoolUtil.parsePropertyString(fields);
			else fields;
		}

		var toProperty = CoolUtil.parseProperty(toTarget, fields);
		var fromProperty = CoolUtil.parseProperty(fromTarget, fields);

		return toProperty.setValue(fromProperty.getValue());
	}

}

class PropertyInfo {
	public var object:Dynamic;
	public var field:OneOfTwo<String, Int>;
	public var typeOfField:Type.ValueType;
	#if hscript_improved
	public var isCustom:Bool = false;
	public var custom:hscript.IHScriptCustomBehaviour;
	#end

	public function new(object:Dynamic, field:OneOfTwo<String, Int>) {
		this.object = object;
		this.field = field;
		#if hscript_improved
		if (object is hscript.IHScriptCustomBehaviour)
		{
			isCustom = true;
			custom = cast object;
		}
		#end

		typeOfField = Type.typeof(field);
	}

	public function getValue():Dynamic
	{
		if (typeOfField == TInt)
		{
			var index:Int = cast field;
			var arr:Array<Dynamic> = cast object;
			return arr[index];
		}
		else
		{
			#if hscript_improved
			if (isCustom)
				return custom.hget(field);
			else
			#end
			return Reflect.getProperty(object, field);
		}
	}

	public function setValue(value:Dynamic):Void
	{
		if (typeOfField == TInt)
		{
			var index:Int = cast field;
			var arr:Array<Dynamic> = cast object;
			arr[index] = value;
		}
		else
		{
			#if hscript_improved
			if (isCustom)
				custom.hset(field, value);
			else
			#end
			Reflect.setProperty(object, field, value);
		}
	}
}

enum abstract CoolSfx(Int) from Int {
	var SCROLL = 0;
	var CONFIRM = 1;
	var CANCEL = 2;
	var CHECKED = 3;
	var UNCHECKED = 4;
	var WARNING = 5;

	public static function format(str:String, args:Array<Dynamic>):String {
		for (i => a in args) str = StringTools.replace(str, '{$i}', Std.string(a));
		return str;
	}

	public static function makeSolid<T:flixel.FlxSprite>(sprite:T, width:Float, height:Float, color:flixel.util.FlxColor = 0xFFFFFFFF, unique:Bool = false, ?key:String):T {
		sprite.makeGraphic(1, 1, 0xFFFFFFFF, unique, key != null ? key : "__charter_solid");
		sprite.scale.set(width, height);
		sprite.updateHitbox();
		sprite.color = color;
		sprite.alpha = color.alphaFloat;
		return sprite;
	}

	public static function getViewRect(cam:flixel.FlxCamera, ?rect:flixel.math.FlxRect):flixel.math.FlxRect {
		if (rect == null) rect = flixel.math.FlxRect.get();
		return rect.set(cam.scroll.x + cam.viewMarginLeft, cam.scroll.y + cam.viewMarginTop, cam.viewWidth, cam.viewHeight);
	}

	public static function addShader(cam:flixel.FlxCamera, shader:flixel.system.FlxAssets.FlxShader):Void {
		var list:Array<openfl.filters.BitmapFilter> = cam.filters == null ? [] : cam.filters.copy();
		list.push(new openfl.filters.ShaderFilter(shader));
		cam.filters = list;
	}

	public static function removeShader(cam:flixel.FlxCamera, shader:flixel.system.FlxAssets.FlxShader):Void {
		if (cam.filters == null) return;
		cam.filters = [for (f in cam.filters) if (!(f is openfl.filters.ShaderFilter) || cast(f, openfl.filters.ShaderFilter).shader != shader) f];
	}

	public static inline function soundLoaded(sound:flixel.sound.FlxSound):Bool
		return sound != null && sound.length > 0;
}
