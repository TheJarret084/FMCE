package funkin.editors.ui;

import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import funkin.backend.shaders.CustomShader;

using flixel.util.FlxSpriteUtil;

class UIColorwheel extends UISliceSprite {
	var colorPicker:FlxSprite;
	/** null en Android o si el shader no compila: entonces el cuadro de color se dibuja por CPU (ver redrawPicker). */
	var colorPickerShader:Null<CustomShader>;
	var pickerMask:Array<Bool>;
	var __pickerHue:Float = -1;
	var colorPickerSelector:UIColorWheelSelector;

	var colorSlider:FlxSprite;
	var colorSliderSelector:UIColorWheelSelector;

	var colorHexTextBox:UITextBox;
	var rgbNumSteppers:Array<UINumericStepper> = []; // r,g,b

	public var curColor:Null<FlxColor>;
	public var curColorString:String = "#FFFFFF";

	public var saturation:Float;
	public var brightness:Float;
	public var hue:Float;

	public function new (x:Float, y:Float, ?color:Int) {
		super(x, y, 299, 125, 'editors/ui/inputbox');

		curColor = cast color;
		hue = curColor.hue; saturation = curColor.saturation; brightness = curColor.brightness;

		colorPickerShader = makePickerShader();

		colorPicker = new FlxSprite(x + 12.5, (y + 125/2) - (100/2)).makeGraphic(100, 100, FlxColor.TRANSPARENT);
		colorPicker.drawRoundRect(0, 0, 100, 100, 10, 10, FlxColor.WHITE);
		if (colorPickerShader != null) colorPicker.shader = colorPickerShader;
		else initPickerMask();

		colorPickerSelector = new UIColorWheelSelector(colorPicker.x + 100 - 16, colorPicker.y);

		colorSlider = new FlxSprite(colorPicker.x + 100 + 12.5, colorPicker.y).makeGraphic(16, 100, FlxColor.TRANSPARENT);
		colorSlider.drawRoundRect(0, 0, 16, 100, 10, 10, FlxColor.WHITE);

		// Im too lazy to use a shader for this if its not even gonna change
		colorSlider.pixels.lock();
		for (pixelY in 0...Std.int(colorSlider.height)) {
			var color:Int = FlxColor.fromHSB(pixelY / (colorSlider.height-1) * 360, 1, 1);
			for (pixelX in 0...Std.int(colorSlider.width))
				if (colorSlider.pixels.getPixel32(pixelX, pixelY) != FlxColor.TRANSPARENT) colorSlider.pixels.setPixel32(pixelX, pixelY, color);
		}
		colorSlider.pixels.unlock();

		colorSliderSelector = new UIColorWheelSelector(colorSlider.x, colorSlider.y);

		colorHexTextBox = new UITextBox(colorSlider.x + 16 + 12.5, colorSlider.y + 16, "", 100, 28);
		colorHexTextBox.onChange = (colorString:String) -> {
			curColor = FlxColor.fromString(colorString);
			if (curColor == null) curColor = FlxColor.WHITE;

			hue = curColor.hue; saturation = curColor.saturation; brightness = curColor.brightness;
			updateWheel();
		}

		var hexLabel:UIText = new UIText(colorHexTextBox.x - 2, colorHexTextBox.y - 18, 0, "Hex (#FFFFFF)", 13);

		for (i in 0...3) {
			var numStepper:UINumericStepper = new UINumericStepper(colorSlider.x + 18 + 12.5 + (i * 44), colorHexTextBox.y + 28 + 6 + 13 + 6 + .5, 0, 1, 0, 0, 255, 40 + 28, 28);
			numStepper.antialiasing = true; numStepper.ID = i;
			numStepper.onChange = (text:String) -> {
				@:privateAccess numStepper.__onChange(text);
				var val = Std.int(numStepper.value);
				switch (numStepper.ID) {
					default: curColor.red = val;
					case 1: curColor.green = val;
					case 2: curColor.blue = val;
				}
				hue = curColor.hue; saturation = curColor.saturation; brightness = curColor.brightness;
				updateWheel();
			};
			members.push(numStepper); rgbNumSteppers.push(numStepper);
		}

		var rgbLabel:UIText = new UIText(rgbNumSteppers[0].x - 2, rgbNumSteppers[0].y - 18, 0, "RGB (255,255,255)", 13);

		colorPicker.antialiasing = colorSlider.antialiasing = colorHexTextBox.antialiasing = true;

		for (item in [colorPicker, colorPickerSelector, colorSlider, colorSliderSelector, colorHexTextBox, hexLabel, rgbLabel])
			members.push(item);

		updateWheel(false);
	}

	static function makePickerShader():Null<CustomShader> {
		#if android
		return null; // los shaders del selector no se usan en Android (igual que el blur de UISubstateWindow)
		#else
		try {
			return new CustomShader("engine/colorPicker");
		} catch (e:Dynamic) {
			funky.core.Log.warn('[UIColorwheel] no se pudo crear el shader, se dibuja por CPU: ' + Std.string(e));
			return null;
		}
		#end
	}

	/** Guarda que pixeles del cuadro (redondeado) estan dibujados, para recolorearlos sin shader. */
	function initPickerMask() {
		pickerMask = [];
		var bmp = colorPicker.pixels;
		for (py in 0...100)
			for (px in 0...100)
				pickerMask.push(((bmp.getPixel32(px, py) >> 24) & 0xFF) > 0);
	}

	/** Sin shader: pinta el cuadro (saturacion en X, brillo en Y) para el tono actual. Solo repinta si el tono cambio. */
	function redrawPicker() {
		if (pickerMask == null || (__pickerHue >= 0 && Math.abs(hue - __pickerHue) < 0.5)) return;
		__pickerHue = hue;
		var bmp = colorPicker.pixels;
		bmp.lock();
		for (py in 0...100)
			for (px in 0...100)
				if (pickerMask[py * 100 + px])
					bmp.setPixel32(px, py, FlxColor.fromHSB(hue, px / 99, 1 - py / 99));
		bmp.unlock();
		colorPicker.dirty = true;
	}

	public function setColor(color:FlxColor) {
		hue = curColor.hue; saturation = curColor.saturation; brightness = curColor.brightness;
		updateWheel(false);
	}

	inline function updateColorPickerSelector()
		colorPickerSelector.selector.setPosition(colorPicker.x + (colorPicker.width *saturation) - 8, colorPicker.y + (colorPicker.height + (colorPicker.height * -brightness))- 8);

	inline function updateColorPickerMouse(mousePos:FlxPoint) {
		saturation = mousePos.x/colorPicker.width; brightness = 1 + -(mousePos.y/colorPicker.height);
	}

	inline function updateColorSliderPickerSelector()
		colorSliderSelector.selector.setPosition(colorSlider.x, colorSlider.y + (hue / 360 * (colorSlider.height-1)) - 8);

	inline function updateColorSliderMouse(mousePos:FlxPoint)
		hue = (mousePos.y / colorSlider.height) * 360;

	public function updateWheel(checkChanged:Bool = true) {
		if(checkChanged) colorChanged = true;
		if (colorPickerShader != null) colorPickerShader.hset("hue", hue / 360);
		else redrawPicker();
		colorPickerSelector.curColor = color = curColor = FlxColor.fromHSB(hue, saturation, brightness); colorSliderSelector.curColor = FlxColor.fromHSB(hue, 1, 1);

		updateColorPickerSelector(); updateColorSliderPickerSelector();
		colorHexTextBox.label.text = curColorString = curColor.toWebString();
		for (numStepper in rgbNumSteppers) {
			numStepper.label.text = Std.string(switch (numStepper.ID) {
				default: curColor.red;
				case 1: curColor.green;
				case 2: curColor.blue;
			});
		}
	}

	// For Character Editor
	public var colorChanged:Bool = false;

	// Make the colorwheel feel better
	static inline var hitBoxExtension:Float = 8;

	// Skibidi
	var selectedSprite = null;
	public override function update(elapsed:Float) {
		var mousePos = FlxG.mouse.getScreenPosition(__lastDrawCameras[0], FlxPoint.get());
		if (hovered && FlxG.mouse.justPressed) {
			for (sprite in [colorPicker, colorSlider]) {
				var spritePos:FlxPoint = sprite.getScreenPosition(FlxPoint.get(), __lastDrawCameras[0]);
				if (FlxMath.inBounds(mousePos.x, spritePos.x - (hitBoxExtension/2), spritePos.x - (hitBoxExtension/2) + (sprite.width + hitBoxExtension)) && FlxMath.inBounds(mousePos.y, spritePos.y - (hitBoxExtension/2), spritePos.y - (hitBoxExtension/2) + (sprite.height + hitBoxExtension))) {
					selectedSprite = sprite;
					break;
				}
			}
		}

		if (selectedSprite != null) {
			var spritePos:FlxPoint = selectedSprite.getScreenPosition(FlxPoint.get(), __lastDrawCameras[0]);
			mousePos -= FlxPoint.weak(spritePos.x, spritePos.y);
			mousePos.set(CoolUtil.bound(mousePos.x, 0, selectedSprite.width), CoolUtil.bound(mousePos.y, 0, selectedSprite.height));

			if (selectedSprite == colorSlider) updateColorSliderMouse(mousePos);
			if (selectedSprite == colorPicker) updateColorPickerMouse(mousePos);
			updateWheel();
			spritePos.put();

			if (FlxG.mouse.justReleased) selectedSprite = null;
		}
		mousePos.put();
		super.update(elapsed);
	}
}

class UIColorWheelSelector extends FlxTypedGroup<FlxSprite> {
	public var curColor:FlxColor = FlxColor.WHITE;

	public var selector:FlxSprite;
	public var colorCircle:FlxSprite;

	public function new(x:Float, y:Float, ?color:Null<Int>) {
		super();
		if (color != null) curColor = cast color;

		add(selector = new FlxSprite(x, y).loadGraphic(Paths.image("editors/ui/slider")));
		add(colorCircle = new FlxSprite(x + 2, y + 2).makeGraphic(12,12, FlxColor.TRANSPARENT).drawCircle());

		selector.antialiasing = colorCircle.antialiasing = true;
		colorCircle.colorTransform.color = curColor;
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);

		colorCircle.setPosition(selector.x + 2, selector.y + 2);
		colorCircle.colorTransform.color = curColor;
	}
}
