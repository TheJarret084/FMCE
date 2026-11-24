package funky.editors.charter;

import funky.backend.utils.CoolUtil;
import funky.backend.assets.Paths;
import funky.editors.ui.UIContextMenu.UIContextMenuOption;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;
import flixel.sound.FlxSound;
import funky.backend.chart.ChartData.ChartStrumLine;
import funky.backend.shaders.CustomShader;
import funky.editors.ui.UITopMenu.UITopMenuButton;
import funky.game.Character;
import funky.game.HealthIcon;

class CharterStrumline extends UISprite {
	/**
	 * Icono de las strumlines extra (la 2, 3...). "" = bloque de color.
	 * Pon aqui el nombre de un sprite del nivel para que todas las extra lo usen.
	 * La strumline 0 usa meta.iconPlayer y la 1 meta.iconOpponent.
	 */
	public static var extraIcon:String = "";
	/** Color del bloque que se muestra cuando una strumline no tiene icono. */
	public static var blockColor:FlxColor = 0xFF8C8C8C;
	/** Lado (en px) con el que se ajusta el icono de cada strumline. */
	public static var iconSize:Float = 82;

	/**
	 * Sprite que puso el ultimo evento BarIconChange antes de la posicion actual del chart.
	 * null = el icono del meta. Lo actualiza Charter.updateBarIcons.
	 */
	public var barIcon:Null<String> = null;
	var __iconKey:Null<String> = null;

	public var strumLine:ChartStrumLine;

	public var draggingSprite:UISprite;
	public var healthIcons:FlxSpriteGroup;
	public var button:CharterStrumlineOptions;
	public var highlightColor:FlxColor;

	public var draggable:Bool = false;
	public var dragging:Bool = false;

	public var curMenu:UIContextMenu = null;

	public var vocals:FlxSound;
	public var hasVocals:Bool = false;
	public var vocalsVolume:Float = 1;
	public var hitsoundVolume:Float = 1;

	public var keyCount:Int = 4;
	public var startingID(get, null):Int;
	private var __startingID:Int = -1;
	public function get_startingID():Int {
		if (__startingID != -1) return __startingID;

		var index = Charter.instance.strumLines.members.indexOf(this);
		if (index < 1) return __startingID = 0;

		var v:Int = 0;
		for (i in 0...index) v += Charter.instance.strumLines.members[i].keyCount;
		return __startingID = v;
	}

	public var selectedWaveform(default, set):Int = -1;
	public function set_selectedWaveform(value:Int):Int {
		if (value < 0 || Charter.waveformHandler == null || value >= Charter.waveformHandler.waveformList.length) {
			waveformShader = null;
			return selectedWaveform = -1;
		}
		else {
			var shaderName:String = Charter.waveformHandler.waveformList[value];
			waveformShader = Charter.waveformHandler.waveShaders.get(shaderName);
		}
		return selectedWaveform = value;
	}
	public var waveformShader:CustomShader;

	public function new(strumLine:ChartStrumLine) {
		super();
		this.strumLine = strumLine;

		scrollFactor.set(1, 0);
		alpha = 0;

		if(strumLine.visible == null) strumLine.visible = true;

		keyCount = strumLine.keyCount != null ? strumLine.keyCount : 4;

		healthIcons = new FlxSpriteGroup(x, y);
		// Los iconos se arman en syncIcons(): necesita saber en que posicion quedo la strumline dentro del Charter.

		members.push(healthIcons);

		draggingSprite = new UISprite();
		draggingSprite.loadGraphic(Paths.image("editors/charter/strumline-drag"));
		draggingSprite.alpha = 0.4;
		draggingSprite.y = 9;
		draggingSprite.antialiasing = true;
		draggingSprite.cursor = CLICK;
		members.push(draggingSprite);

		button = new CharterStrumlineOptions(this);
		members.push(button);

		updateInfo();

		selectedWaveform = -1;
	}

	private var __healthYOffset:Float = 0;
	private var __draggingYOffset:Float = 0;

	public override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.K) draggable = !draggable;

		syncIcons();

		healthIcons.follow(this, ((40 * keyCount) - healthIcons.width) / 2, 7 + (__healthYOffset = FlxMath.lerp(__healthYOffset, draggable ? 8 : 0, 1/20)));

		draggingSprite.selectable = draggable;
		draggingSprite.updateSpriteRect();

		var dragScale:Float = FlxMath.lerp(draggingSprite.scale.x, draggable ? 1 : 0.8, 1/16);
		draggingSprite.scale.set(dragScale, dragScale);
		draggingSprite.updateHitbox();

		draggingSprite.follow(this, ((keyCount*40)/2) - (draggingSprite.width/2), 6 + (__draggingYOffset = FlxMath.lerp(__draggingYOffset, draggable ? 3 : 0, 1/12)));
		var fullAlpha:Float = UIState.state.isOverlapping(draggingSprite, @:privateAccess draggingSprite.__rect) || dragging ? 0.9 : 0.35;
		draggingSprite.alpha = FlxMath.lerp(draggingSprite.alpha, draggable ? fullAlpha : 0, 1/12);
		button.follow(this, 0, 95);

		super.update(elapsed);
	}

	/** Posicion de esta strumline en el Charter (0 = jugador, 1 = oponente, 2+ = extra). -1 si todavia no esta en el grupo. */
	public function iconSlot():Int {
		var charter = Charter.instance;
		if (charter == null || charter.strumLines == null) return -1;
		return charter.strumLines.members.indexOf(this);
	}

	/** Sprite del nivel que le toca a la strumline en esa posicion. "" = bloque. */
	function iconSprite(slot:Int):String {
		var meta = PlayState.SONG != null ? PlayState.SONG.meta : null;
		var name:Null<String> = switch (slot) {
			case 0: barIcon != null ? barIcon : (meta != null ? meta.iconPlayer : null);
			case 1: barIcon != null ? barIcon : (meta != null ? meta.iconOpponent : null);
			default: extraIcon;
		};
		return name == null ? "" : name;
	}

	/**
	 * Arma el icono de la strumline: sprite del nivel (strumline 0 = jugador, 1 = oponente) o bloque (el resto).
	 * Solo reconstruye cuando algo cambio, asi que es barato llamarlo cada frame.
	 */
	public function syncIcons():Void {
		var slot = iconSlot();
		if (slot < 0) return;

		var sprite = iconSprite(slot);
		var key = slot + ":" + sprite + ":" + (strumLine.visible ? 1 : 0) + ":" + (blockColor : Int) + ":" + iconSize;
		if (key == __iconKey) return;
		__iconKey = key;

		healthIcons.clear();

		var icon = new CharterIcon();
		var levelDir = funky.backend.chart.Chart.levelDir;
		var shown = sprite != "" && levelDir != null && icon.setLevelIcon(levelDir, sprite, iconSize);
		if (!shown) icon.setBlock(Std.int(iconSize), blockColor);

		icon.x = 0;
		icon.y = draggable ? 14 : 7;
		icon.alpha = strumLine.visible ? 1 : 0.4;
		healthIcons.add(icon);
	}

	public function updateInfo() {
		var icons = strumLine.characters != null ? strumLine.characters : [];

		keyCount = strumLine.keyCount != null ? strumLine.keyCount : 4;

		__iconKey = null;
		syncIcons();

		if (strumLine.vocalsSuffix == null) strumLine.vocalsSuffix = "";

		var vocalsPath = strumLine.vocalsSuffix.length > 0 ? funky.backend.chart.LevelLoader.findVoices(funky.backend.chart.Chart.levelDir, strumLine.vocalsSuffix) : null;
		var asset = vocalsPath != null ? funky.backend.chart.LevelLoader.loadSound(vocalsPath) : null;

		if (vocals == null) FlxG.sound.list.add(vocals = new FlxSound());
		if (asset != null) {
			vocals.stop();
			vocals.loadEmbedded(asset);
			hasVocals = true;
		}
		else {

			vocals.stop();
			hasVocals = false;
		}
		vocals.group = FlxG.sound.defaultMusicGroup;

		highlightColor = 0xFFFFFFFF;
		if (icons[0] != null) {

			highlightColor.brightness = Math.max(highlightColor.brightness, 0.65);
		}
	}
}

class CharterStrumlineOptions extends UITopMenuButton {
	var strLine:CharterStrumline;
	public function new(parent:CharterStrumline) {

		super(0, 95, null, TU.translate("charter.strumLine.button-name"), []);
		strLine = parent;
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		alpha = FlxMath.lerp(1/20, 1, alpha);
		bWidth = 40 * strLine.keyCount;
		this.label.fieldWidth = bWidth;
	}

	public override function openContextMenu() {
		contextMenu = [
			{
				label: TU.translate("charter.strumLine.hitsounds"),
				slider: {
					min: 0,
					max: 1,
					value: strLine.hitsoundVolume,
					onChange: function(t) {
						strLine.hitsoundVolume = t.slider.value;
						t.icon = t.slider.value > 0.5 ? 7 : (t.slider.value > 0 ? 8 : 9);
					}
				},
				onIconClick: Charter.instance._slider_mutetoggle,
				icon: 7
			},
			null,
			{
				label: TU.translate("charter.strumLine.edit"),
				onSelect: function (_) {
					Charter.instance.editStrumline(strLine.strumLine);
				},
				color: 0xFF959829,
				icon: 4
			},
			{
				label: TU.translate("charter.strumLine.delete"),
				onSelect: function (_) {
					Charter.instance.deleteStrumlineFromData(strLine.strumLine);
				},
				color: 0xFF982929,
				icon: 3
			}
		];

		if (strLine.hasVocals) {
			contextMenu.insert(1, {
				label: TU.translate("charter.strumLine.vocals"),
				slider: {
					min: 0,
					max: 1,
					value: strLine.vocalsVolume,
					onChange: function(t) {
						strLine.vocalsVolume = t.slider.value;
						strLine.vocals.volume = Charter.instance.vocals.volume * strLine.vocalsVolume;
						t.icon = t.slider.value > 0.5 ? 7 : (t.slider.value > 0 ? 8 : 9);
					}
				},
				onIconClick: Charter.instance._slider_mutetoggle,
				icon: 7
			});
		}

		var waveformOptions:Array<UIContextMenuOption> = [
			{
				label: TU.translate("charter.strumLine.noWaveform"),
				onSelect: function(_) {strLine.selectedWaveform = -1;},
				icon: strLine.selectedWaveform == -1 ? 1 : 0
			}
		];

		for (i => name in Charter.waveformHandler.waveformList)
			waveformOptions.push({
				label: name,
				onSelect: function(_) {strLine.selectedWaveform = i;},
				icon: strLine.selectedWaveform == i ? 6 : 5
			});

		contextMenu.insert(0, {
			label: TU.translate("charter.strumLine.waveforms"),
			childs: waveformOptions
		});
		contextMenu.insert(1, null);

		var cam = Charter.instance.charterCamera;
		var point = CoolUtil.worldToScreenPosition(this, cam);
		curMenu = UIState.state.openContextMenu(contextMenu, null, point.x, point.y + (bHeight*cam.zoom), Std.int(bWidth * cam.zoom));
		point.put();
	}
}

/** Icono de una strumline dentro del Charter: un sprite del nivel (el mismo que usa el HUD) o, si no hay, un bloque de color. */
class CharterIcon extends funky.game.LevelSprite {
	public var isBlock(default, null):Bool = true;

	public function new() {
		super();
	}

	/** Carga el sprite del nivel y lo ajusta a `size` px. false si no existe o no se pudo leer. */
	public function setLevelIcon(levelDir:String, name:String, size:Float):Bool {
		if (levelDir == null || name == null || name == "") return false;
		if (!load(levelDir, name)) return false;

		var normal:Null<String> = hasAnim("anim0") ? "anim0" : firstAnim;
		if (normal != null) playAnim(normal, true);

		setSpriteScale(size / Math.max(1, Math.max(frameWidth, frameHeight)));
		antialiasing = true;
		isBlock = false;
		return true;
	}

	/** Cuadrado liso de `size` x `size`. */
	public function setBlock(size:Int, color:FlxColor):Void {
		makeGraphic(size, size, color);
		scale.set(1, 1);
		updateHitbox();
		isBlock = true;
	}
}
