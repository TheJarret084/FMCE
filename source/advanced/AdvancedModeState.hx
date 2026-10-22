package advanced;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import funky.api.DiscordClient;
import funky.backend.chart.LevelLoader;
import funky.core.CoolUtil;
import funky.core.KeyBinds;
import funky.core.Paths;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import funky.game.HealthIcon;
import funky.menus.BoldText;
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

	/** Separacion vertical entre filas y posicion (en Y) del nivel seleccionado, como el arbol de editores de Codename. */
	static inline var ROW_H:Float = 112;
	static inline var ANCHOR_Y:Float = 290;
	static inline var ROW_X:Float = 190;
	static inline var SELECTED_SHIFT:Float = 36;

	var levels:Array<String> = [];
	var rows:Array<BoldText> = [];
	var icons:Array<Null<HealthIcon>> = [];
	var iconTried:Array<Bool> = [];
	var arrow:Null<BoldText>;
	var pattern:Null<FlxSprite>;
	var selected:Int = 0;
	var scrollPos:Float = 0;
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
		// Los editores usan breakfast (la de Codename) en vez de la musica del menu.
		CoolUtil.playEditorSong();

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000);
		add(bg);

		// Fondo de flechas de los editores (`editors/bgs/default`), tenue sobre negro.
		var tile = Paths.image("editors/bgs/default");
		if (tile != null)
		{
			try
			{
				pattern = new FlxSprite().loadGraphic(tile);
				pattern.setGraphicSize(FlxG.width, FlxG.height);
				pattern.updateHitbox();
				pattern.alpha = 0.55;
				add(pattern);
			}
			catch (e:Dynamic)
			{
				pattern = null;
			}
		}

		// Titulo arriba a la izquierda + descripcion, igual que "Chart Editor >" de Codename.
		add(new BoldText(16, 6, "MODO AVANZADO >", 0.55));
		var desc = new FlxText(18, 50, FlxG.width - 40, "Selecciona el nivel que quieres editar.\n" + KeyBinds.label(KeyBinds.ACCEPT) + " para elegir  |  ESC volver", 15);
		desc.color = MUTED;
		add(desc);

		levels = Paths.listLevels();
		if (levels.length > 0)
		{
			for (i in 0...levels.length)
			{
				var row = new BoldText(ROW_X, ANCHOR_Y + i * ROW_H, levels[i], 0.95);
				add(row);
				rows.push(row);
				icons.push(null);
				iconTried.push(false);
			}

			arrow = new BoldText(0, 0, ">", 0.95);
			add(arrow);
		}
		else
		{
			var empty = new FlxText(0, 255, FlxG.width, "No hay niveles en " + Paths.levelsRoot(), 18);
			empty.color = MUTED;
			empty.alignment = FlxTextAlign.CENTER;
			add(empty);
		}

		info = new FlxText(0, FlxG.height - 34, FlxG.width, "", 15);
		info.color = MUTED;
		info.alignment = FlxTextAlign.CENTER;
		add(info);

		DiscordClient.customPresence("Modo Avanzado", "Seleccionando nivel", "fmce", "", false);
		scrollPos = selected;
		layoutRows(1);
		TransitionHandler.playIn(this);
	}

	/** Coloca las filas alrededor del seleccionado: el seleccionado queda fijo en ANCHOR_Y y el resto se desliza (scroll suave). */
	function layoutRows(lerp:Float):Void
	{
		scrollPos += (selected - scrollPos) * lerp;

		for (i in 0...rows.length)
		{
			var row = rows[i];
			var active = i == selected;
			var y = ANCHOR_Y + (i - scrollPos) * ROW_H;
			var x = ROW_X + (active ? SELECTED_SHIFT : 0);

			row.visible = y > -ROW_H && y < FlxG.height;
			row.setPosition(x, y);
			row.alpha = active ? 1 : 0.55;

			var icon = iconFor(i);
			if (icon != null)
			{
				icon.visible = row.visible;
				icon.alpha = row.alpha;
				icon.centerAt(x - 14 - HealthIcon.FIT / 2, y + row.height / 2);
			}
		}

		if (arrow != null && selected >= 0 && selected < rows.length)
		{
			var sel = rows[selected];
			arrow.visible = sel.visible;
			arrow.setPosition(sel.x + sel.width + 24, sel.y);
		}

		if (pattern != null)
			pattern.y = -((scrollPos * 12) % 40);
	}

	/** Icono del oponente del nivel, como en Freeplay; se carga al acercarse a la fila para no cargar todos de golpe. */
	function iconFor(index:Int):Null<HealthIcon>
	{
		if (icons[index] != null) return icons[index];
		if (iconTried[index] || Math.abs(index - selected) > 3) return null;
		iconTried[index] = true;

		#if sys
		var path = Paths.levelsRoot() + levels[index];
		if (LevelLoader.isArchive(path)) return null;
		var name = LevelLoader.opponentIcon(path);
		if (name == null) return null;

		var icon = new HealthIcon(path, name, false);
		if (!icon.loaded)
		{
			icon.destroy();
			return null;
		}
		add(icon);
		icons[index] = icon;
		return icon;
		#else
		return null;
		#end
	}

	function refresh():Void
	{
		if (info == null) return;
		info.text = levels.length == 0 ? "Crea un nivel en la carpeta levels/ para usar el modo avanzado." : (selected + 1) + " / " + levels.length;
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

		// Toque / clic: sobre la fila seleccionada abre el nivel; sobre otra, la selecciona.
		if (FlxG.mouse.justPressed)
		{
			for (i in 0...rows.length)
			{
				if (!rows[i].visible || !FlxG.mouse.overlaps(rows[i])) continue;
				if (i == selected)
					openSelected();
				else
				{
					selected = i;
					refresh();
				}
				break;
			}
		}

		layoutRows(Math.min(1, elapsed * 12));
	}
}
