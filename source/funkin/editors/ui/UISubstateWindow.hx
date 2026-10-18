package funkin.editors.ui;

import openfl.display.ShaderParameter;
import openfl.display.ShaderInput;
import openfl.filters.ShaderFilter;
import flixel.tweens.FlxTween;
import funkin.backend.shaders.CustomShader;
import openfl.filters.ShaderFilter;

// TODO: make UIWarningSubstate extend this
class UISubstateWindow extends MusicBeatSubstate {
	var camShaders:Array<FlxCamera> = [];
	/** Desenfoque del fondo. null si no se pudo crear (Android o error): entonces se usa un fondo oscuro. */
	var blurShader:Null<CustomShader> = makeBlurShader();
	/** Fondo oscuro de reemplazo cuando no hay blur. */
	var dimCam:Null<FlxCamera>;

	static function makeBlurShader():Null<CustomShader> {
		#if android
		return null;
		#else
		try {
			var _ = new CustomShader(Options.intensiveBlur ? "engine/editorBlur" : "engine/editorBlurFast");
			if(!Options.intensiveBlur) {
				var noiseTexture:ShaderInput<openfl.display.BitmapData> = _.data.noiseTexture;
				noiseTexture.input = Assets.getBitmapData("assets/shaders/noise256.png");
				noiseTexture.wrap = REPEAT;
				var noiseTextureSize:ShaderParameter<Float> = _.data.noiseTextureSize;
				noiseTextureSize.value = [noiseTexture.input.width, noiseTexture.input.height];
			}
			return _;
		} catch (e:Dynamic) {
			funky.core.Log.warn('[UISubstateWindow] no se pudo crear el blur, se usa un fondo oscuro: ' + Std.string(e));
			return null;
		}
		#end
	}

	var titleSpr:UIText;
	var messageSpr:UIText;

	var subCam:FlxCamera;

	var windowSpr:UISliceSprite;

	public override function onSubstateOpen() {
		super.onSubstateOpen();
		parent.persistentUpdate = false;
		parent.persistentDraw = true;
	}

	var winWidth:Int = 560;
	var winHeight:Int = 570;
	var winTitle:String = "";
	var winSkin:String = "editors/ui/normal-popup";

	public override function create() {
		super.create();

		if(blurShader != null) {
			try {
				for(c in FlxG.cameras.list) {
					// Prevent adding a shader if it already has one
					if(c.filters != null) {
						var shouldSkip = false;
						for(filter in c.filters) {
							if(filter is ShaderFilter) {
								var filter:ShaderFilter = cast filter;
								if(filter.shader is CustomShader) {
									var shader:CustomShader = cast filter.shader;

									if(shader.path == blurShader.path) {
										shouldSkip = true;
										break;
									}
								}
							}
						}
						if(shouldSkip)
							continue;
					}
					camShaders.push(c);
					c.addShader(blurShader);
				}
			} catch (e:Dynamic) {
				funky.core.Log.warn('[UISubstateWindow] el blur fallo, se usa un fondo oscuro: ' + Std.string(e));
				removeBlur();
				blurShader = null;
			}
		}

		if(blurShader == null) {
			dimCam = new FlxCamera();
			dimCam.bgColor = 0x99000000;
			dimCam.alpha = 0;
			FlxG.cameras.add(dimCam, false);
			FlxTween.tween(dimCam, {alpha: 1}, 0.25, {ease: FlxEase.cubeOut});
		}

		camera = subCam = new FlxCamera();
		subCam.bgColor = 0;
		subCam.alpha = 0;
		subCam.zoom = 0.1;
		FlxG.cameras.add(subCam, false);

		windowSpr = new UISliceSprite(0, 0, winWidth, winHeight, winSkin);
		add(windowSpr);

		if(winTitle != null) {
			add(titleSpr = new UIText(windowSpr.x + 25, windowSpr.y, windowSpr.bWidth - 50, winTitle, 15, -1));
			titleSpr.y = windowSpr.y + ((30 - titleSpr.height) / 2);
		}

		FlxTween.tween(camera, {alpha: 1}, 0.25, {ease: FlxEase.cubeOut});
		FlxTween.tween(camera, {zoom: 1}, 0.66, {ease: FlxEase.elasticOut});
	}

	function removeBlur():Void {
		if(blurShader != null)
			for(e in camShaders)
				try e.removeShader(blurShader) catch(_:Dynamic) {}
		camShaders = [];
	}

	public override function destroy() {
		try UIState.playEditorSound(Flags.DEFAULT_EDITOR_WINDOWCLOSE_SOUND) catch(_:Dynamic) {}
		super.destroy();
		removeBlur();
		blurShader = null;

		if(dimCam != null) {
			FlxTween.cancelTweensOf(dimCam);
			FlxG.cameras.remove(dimCam);
			dimCam = null;
		}
		if(subCam != null) {
			FlxTween.cancelTweensOf(subCam);
			FlxG.cameras.remove(subCam);
			subCam = null;
		}
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		// Si create() fallo a medio armar, no hay ventana ni camara todavia: no se toca nada (antes era un null reference cada frame).
		if(subCam == null || windowSpr == null) return;
		subCam.scroll.set(Std.int(-(FlxG.width - windowSpr.bWidth) / 2), Std.int(-(FlxG.height - windowSpr.bHeight) / 2));
	}
}
