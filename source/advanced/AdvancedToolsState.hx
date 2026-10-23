package advanced;

import advanced.ui.EditorBackdrop;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import funky.backend.LevelArchive;
import funky.core.KeyBinds;
import funky.core.Paths;
import funky.core.TransitionHandler;

/** Una herramienta de la pantalla: su icono (`editors/icons/<icon>`), el texto y lo que hace. */
private typedef Tool =
{
	var label:String;
	var description:String;
	var icon:String;
	var action:Void->Void;
	var ?sprite:FlxSprite;
	var ?text:FlxText;
}

/**
 * Despues de elegir el nivel en el modo avanzado: elige que herramienta abrir (o exportar el nivel como .FMCE).
 * Cada herramienta es un icono de `editors/icons`; izquierda/derecha para moverse, o toca el icono directo.
 */
class AdvancedToolsState extends FlxState
{
	static inline var MUTED:Int = 0xFF858B97;
	static inline var ACTIVE:Int = 0xFFFFFFFF;

	/** Ancho de cada casilla y alto (centro) de la fila de iconos. */
	static inline var SLOT_W:Float = 214;
	static inline var ICON_Y:Float = 300;

	var levelName:String;
	var tools:Array<Tool> = [];
	var selected:Int = 0;
	var chosen:Bool = false;
	var info:FlxText;
	var back:FlxText;

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

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000));
		try
		{
			add(new EditorBackdrop());
		}
		catch (e:Dynamic) {}

		var title = new FlxText(0, 62, FlxG.width, "MODO AVANZADO", 36);
		title.alignment = FlxTextAlign.CENTER;
		add(title);

		var sub = new FlxText(0, 112, FlxG.width, levelName, 20);
		sub.color = MUTED;
		sub.alignment = FlxTextAlign.CENTER;
		add(sub);

		back = new FlxText(18, 14, 240, "< VOLVER", 20);
		back.color = MUTED;
		add(back);

		addTool("CODE STUDIO", "Scripts (.hx) y archivos .json del nivel", "debugOptions", function() go(new AdvancedEditorState(levelName)));
		// antiGay = true bloquea todo el modo avanzado (para el release); si no, los editores salen en todas las plataformas
		addTool("CHART EDITOR", "Notas, sustains, strumlines, eventos globales y waveform", "chart", function() go(funkin.editors.charter.CharterLauncher.open(levelName)));
		addTool("SPRITE EDITOR", "config.json de cada sprite: tipo, animaciones, indices, velocidad, loop, escala y pivote", "character",
			function() go(new advanced.editors.SpriteEditorState(levelName)));
		addTool("SCENE EDITOR", "scene.json: objetos, capas, parallax, fixed, strumlines y camaras", "stage", function() go(new advanced.editors.SceneEditorState(levelName)));
		addTool("EXPORTAR .FMCE", "Comprime el nivel en exports/" + levelName + ".FMCE (sin copias .bak / .bck)", "alphabet", exportLevel);

		// casillas centradas
		var startX = (FlxG.width - tools.length * SLOT_W) / 2 + SLOT_W / 2;
		for (i in 0...tools.length)
		{
			var tool = tools[i];
			var cx = startX + i * SLOT_W;

			var sprite = new FlxSprite();
			try
			{
				sprite.loadGraphic(Paths.image("editors/icons/" + tool.icon));
			}
			catch (e:Dynamic)
			{
				sprite.makeGraphic(128, 128, 0xFF2A2F3A);
			}
			sprite.antialiasing = true;
			sprite.setPosition(cx - sprite.width / 2, ICON_Y - sprite.height / 2);
			add(sprite);
			tool.sprite = sprite;

			var text = new FlxText(cx - SLOT_W / 2, ICON_Y + 86, SLOT_W, tool.label, 22);
			text.alignment = FlxTextAlign.CENTER;
			add(text);
			tool.text = text;
		}

		info = new FlxText(40, FlxG.height - 135, FlxG.width - 80, "", 17);
		info.color = MUTED;
		info.alignment = FlxTextAlign.CENTER;
		add(info);

		var hint = new FlxText(0, FlxG.height - 65, FlxG.width,
			KeyBinds.label(KeyBinds.LEFT) + "/" + KeyBinds.label(KeyBinds.RIGHT) + " mover  |  "
			+ KeyBinds.label(KeyBinds.ACCEPT) + " elegir  |  ESC volver", 15);
		hint.color = MUTED;
		hint.alignment = FlxTextAlign.CENTER;
		add(hint);

		refresh(true);
		TransitionHandler.playIn(this);
	}

	function addTool(label:String, description:String, icon:String, action:Void->Void):Void
		tools.push({label: label, description: description, icon: icon, action: action});

	function go(next:FlxState):Void
	{
		if (chosen) return;
		chosen = true;
		TransitionHandler.switchState(next);
	}

	/** Exporta el nivel a `.FMCE` y deja el resultado en la barra de info (no sale de la pantalla). */
	function exportLevel():Void
	{
		var result = LevelArchive.exportLevel(levelName);
		info.color = result.ok ? 0xFF8FE388 : 0xFFFF8A8A;
		info.text = result.ok ? "Exportado: " + result.path + " (" + result.files + " archivos)" : result.error;
	}

	function select(index:Int):Void
	{
		selected = (index + tools.length) % tools.length;
		refresh(false);
	}

	function refresh(instant:Bool):Void
	{
		for (i in 0...tools.length)
		{
			var active = i == selected;
			tools[i].text.color = active ? ACTIVE : MUTED;
			tools[i].text.alpha = active ? 1 : 0.65;
			tools[i].sprite.alpha = active ? 1 : 0.55;
			if (instant) tools[i].sprite.scale.set(active ? 1.15 : 0.9, active ? 1.15 : 0.9);
		}
		info.color = MUTED;
		info.text = tools[selected].description;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (chosen) return;

		// el seleccionado "crece" suave
		for (i in 0...tools.length)
		{
			var target = i == selected ? 1.15 : 0.9;
			var s = FlxMath.lerp(tools[i].sprite.scale.x, target, Math.min(1, elapsed * 14));
			tools[i].sprite.scale.set(s, s);
		}

		if (KeyBinds.justPressed(KeyBinds.BACK) || FlxG.keys.justPressed.ESCAPE)
		{
			go(new AdvancedModeState());
			return;
		}

		if (KeyBinds.justPressed(KeyBinds.LEFT) || KeyBinds.justPressed(KeyBinds.UP)) select(selected - 1);
		if (KeyBinds.justPressed(KeyBinds.RIGHT) || KeyBinds.justPressed(KeyBinds.DOWN)) select(selected + 1);
		if (KeyBinds.justPressed(KeyBinds.ACCEPT))
		{
			tools[selected].action();
			return;
		}

		// toque / click: sobre el icono (o su texto); sobre "< VOLVER" regresa a la lista de niveles
		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(back))
			{
				go(new AdvancedModeState());
				return;
			}

			for (i in 0...tools.length)
			{
				if (FlxG.mouse.overlaps(tools[i].sprite) || FlxG.mouse.overlaps(tools[i].text))
				{
					select(i);
					tools[i].action();
					return;
				}
			}
		}
	}
}
