package advanced;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import funky.core.KeyBinds;
import funky.core.TouchNav;
import funky.core.TransitionHandler;

/**
 * Despues de elegir el nivel en el modo avanzado: elige que herramienta abrir.
 * Funciona con teclado, mouse y toques (sin controles de celular).
 */
class AdvancedToolsState extends FlxState
{
	static inline var BG:Int = 0xFF101217;
	static inline var MUTED:Int = 0xFF858B97;
	static inline var ACTIVE:Int = 0xFFFFFFFF;

	var levelName:String;
	var labels:Array<FlxText> = [];
	var actions:Array<Void->Void> = [];
	var descriptions:Array<String> = [];
	var selected:Int = 0;
	var chosen:Bool = false;
	var info:FlxText;

	public function new(levelName:String)
	{
		super();
		this.levelName = levelName;
	}

	override public function create():Void
	{
		super.create();

		// Los editores usan breakfast en vez de la musica del menu (y la recuperan al volver del charter).
		funky.core.CoolUtil.playEditorSong();

		FlxG.mouse.visible = true;
		FlxG.mouse.enabled = true;

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, BG));

		var title = new FlxText(0, 62, FlxG.width, "MODO AVANZADO", 36);
		title.alignment = FlxTextAlign.CENTER;
		add(title);

		var sub = new FlxText(0, 112, FlxG.width, levelName, 20);
		sub.color = MUTED;
		sub.alignment = FlxTextAlign.CENTER;
		add(sub);

		addOption("CODE STUDIO", "Scripts (.hx) y archivos .json del nivel", function() go(new AdvancedEditorState(levelName)));
		// antiGay = true bloquea todo el modo avanzado (para el release); si no, los editores salen en todas las plataformas
		addOption("CHART EDITOR", "Notas, sustains, strumlines, eventos globales y waveform", function() go(funkin.editors.charter.CharterLauncher.open(levelName)));
		addOption("SPRITE EDITOR", "config.json de cada sprite: tipo, animaciones, indices, velocidad, loop, escala y pivote", function() go(new advanced.editors.SpriteEditorState(levelName)));
		addOption("SCENE EDITOR", "scene.json: objetos, capas, parallax, fixed, strumlines y camaras", function() go(new advanced.editors.SceneEditorState(levelName)));
		addOption("VOLVER", "Elegir otro nivel", function() go(new AdvancedModeState()));

		info = new FlxText(0, FlxG.height - 115, FlxG.width, "", 15);
		info.color = MUTED;
		info.alignment = FlxTextAlign.CENTER;
		add(info);

		var hint = new FlxText(0, FlxG.height - 65, FlxG.width,
			KeyBinds.label(KeyBinds.UP) + "/" + KeyBinds.label(KeyBinds.DOWN) + " mover  |  "
			+ KeyBinds.label(KeyBinds.ACCEPT) + " elegir  |  ESC volver", 15);
		hint.color = MUTED;
		hint.alignment = FlxTextAlign.CENTER;
		add(hint);

		refresh();
		TransitionHandler.playIn(this);
	}

	function addOption(label:String, description:String, action:Void->Void):Void
	{
		var item = new FlxText(180, 200 + labels.length * 58, FlxG.width - 360, label, 28);
		item.alignment = FlxTextAlign.CENTER;
		add(item);
		labels.push(item);
		descriptions.push(description);
		actions.push(action);
	}

	function go(next:FlxState):Void
	{
		if (chosen) return;
		chosen = true;
		TransitionHandler.switchState(next);
	}

	function refresh():Void
	{
		for (i in 0...labels.length)
		{
			labels[i].color = i == selected ? ACTIVE : MUTED;
			labels[i].alpha = i == selected ? 1 : 0.65;
		}
		info.text = descriptions[selected];
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (chosen) return;

		if (KeyBinds.justPressed(KeyBinds.BACK) || FlxG.keys.justPressed.ESCAPE)
		{
			go(new AdvancedModeState());
			return;
		}

		if (KeyBinds.justPressed(KeyBinds.UP))
		{
			selected = (selected - 1 + labels.length) % labels.length;
			refresh();
		}
		if (KeyBinds.justPressed(KeyBinds.DOWN))
		{
			selected = (selected + 1) % labels.length;
			refresh();
		}
		if (KeyBinds.justPressed(KeyBinds.ACCEPT))
		{
			actions[selected]();
			return;
		}

		// toque (TouchNav) o click (mouse)
		var tapped = TouchNav.rowTapped(labels);

		if (tapped < 0 && FlxG.mouse.justPressed)
		{
			for (i in 0...labels.length)
			{
				if (FlxG.mouse.overlaps(labels[i]))
				{
					tapped = i;
					break;
				}
			}
		}

		if (tapped >= 0)
		{
			selected = tapped;
			refresh();
			actions[selected]();
		}
	}
}
