package advanced;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import funky.api.DiscordClient;
import funky.core.KeyBinds;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import funky.menus.MainMenuState;

/**
 * Entrada al modo avanzado: elige el nivel y despues la herramienta (Code Studio o Chart Editor).
 */
class AdvancedModeState extends FlxState
{
	/**
	 * Seguro del modo avanzado. true = no se puede entrar (ni con la tecla 7 en el menu principal,
	 * ni desde Opciones). Funciona igual en escritorio y celular.
	 */
	public static var antiGay:Bool = false;

	static inline var BG:Int = 0xFF101217;
	static inline var MUTED:Int = 0xFF858B97;
	static inline var ACTIVE:Int = 0xFFFFFFFF;

	var levels:Array<String> = [];
	var labels:Array<FlxText> = [];
	var selected:Int = 0;
	var chosen:Bool = false;
	var info:FlxText;

	override public function create():Void
	{
		super.create();

		if (antiGay)
			createGay();
		else
			createMenu();
	}

	function createMenu():Void
	{
		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, BG);
		add(bg);

		var title = new FlxText(0, 62, FlxG.width, "MODO AVANZADO", 36);
		title.alignment = FlxTextAlign.CENTER;
		add(title);

		var sub = new FlxText(0, 112, FlxG.width, "Selecciona el nivel que quieres editar", 17);
		sub.color = MUTED;
		sub.alignment = FlxTextAlign.CENTER;
		add(sub);

		levels = Paths.listLevels();
		if (levels.length > 0)
		{
			for (i in 0...levels.length)
			{
				var label = new FlxText(180, 185 + i * 42, FlxG.width - 360, levels[i], 23);
				label.alignment = FlxTextAlign.CENTER;
				add(label);
				labels.push(label);
			}
		}
		else
		{
			var empty = new FlxText(0, 255, FlxG.width, "No hay niveles en " + Paths.levelsRoot(), 18);
			empty.color = MUTED;
			empty.alignment = FlxTextAlign.CENTER;
			add(empty);
		}

		info = new FlxText(0, FlxG.height - 115, FlxG.width, "", 15);
		info.color = MUTED;
		info.alignment = FlxTextAlign.CENTER;
		add(info);

		var hint = new FlxText(0, FlxG.height - 65, FlxG.width,
			KeyBinds.label(KeyBinds.UP) + "/" + KeyBinds.label(KeyBinds.DOWN) + " mover  |  "
			+ KeyBinds.label(KeyBinds.ACCEPT) + " elegir nivel  |  ESC volver", 15);
		hint.color = MUTED;
		hint.alignment = FlxTextAlign.CENTER;
		add(hint);

		DiscordClient.customPresence("Modo Avanzado", "Seleccionando nivel", "fmce", "", false);
		refresh();
		TransitionHandler.playIn(this);
	}

	function refresh():Void
	{
		for (i in 0...labels.length)
		{
			labels[i].color = i == selected ? ACTIVE : MUTED;
			labels[i].alpha = i == selected ? 1 : 0.65;
		}
		if (info == null) return;
		info.text = levels.length == 0 ? "Crea un nivel en la carpeta levels/ para usar el modo avanzado." : levels[selected];
	}

	function openSelected():Void
	{
		if (levels.length == 0 || selected < 0 || selected >= levels.length) return;
		chosen = true;
		TransitionHandler.switchState(new AdvancedToolsState(levels[selected]));
	}

	function createGay():Void
	{
		var text = new FlxText(0, 0, FlxG.width, "¡GAY!", 64);
		text.alignment = FlxTextAlign.CENTER;
		text.screenCenter();
		add(text);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (chosen) return;

		if (KeyBinds.justPressed(KeyBinds.BACK))
		{
			chosen = true;
			TransitionHandler.switchState(new MainMenuState());
			return;
		}
		if (levels.length == 0) return;

		if (KeyBinds.justPressed(KeyBinds.UP))
		{
			selected = (selected - 1 + levels.length) % levels.length;
			refresh();
		}
		if (KeyBinds.justPressed(KeyBinds.DOWN))
		{
			selected = (selected + 1) % levels.length;
			refresh();
		}
		if (KeyBinds.justPressed(KeyBinds.ACCEPT)) openSelected();

		var tapped = TouchNav.rowTapped(labels);
		if (tapped >= 0)
		{
			selected = tapped;
			refresh();
			openSelected();
		}
	}
}
