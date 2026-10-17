package funky.menus.options;

import advanced.AdvancedModeState;
import flixel.FlxG;
import funky.backend.system.LogOverlay;
import funky.backend.system.framerate.Framerate;
import funky.core.ClientPrefs;
import funky.core.CoolUtil;
import funky.core.TouchNav;
import funky.core.TransitionHandler;
import flixel.util.FlxColor;

import funky.core.Log;

/**
 * Un nodo del arbol de creditos (como los nodos <credit> y <menu> del credits.xml de Codename).
 * Si trae `menu` es una SECCION (abre otra pantalla con esas entradas); si no, es una persona/enlace.
 */
typedef CreditEntry =
{
	var name:String;
	/** Texto que sale arriba al seleccionarla. */
	@:optional var desc:String;
	/** Se abre en el navegador al aceptar. */
	@:optional var url:String;
	/** URL del avatar a descargar; si falla se usa assets/images/credits/<name>.png y luego el icono de FMCE. */
	@:optional var avatar:String;
	/** Color del nombre (0xAARRGGBB). */
	@:optional var color:Int;
	/** Entradas de la seccion (si existe, esta entrada es una seccion). */
	@:optional var menu:Array<CreditEntry>;
    /** BG DEL MENU, TOTALMENTE CAMBIABLE*/
    @:optional var background:String;
}

/** Contenido de cada pantalla de opciones y de creditos. Aqui se decide QUE hay; ConfigMenu decide COMO se ve. */
class ConfigScreens
{
	/** Raiz de Opciones. `inGame` = abierto desde la pausa: sin entradas que saquen de la cancion. */
	public static function root(menu:ConfigMenu, inGame:Bool):ConfigScreen
	{
		var items:Array<ConfigItem> = [];
		if (!TouchNav.MOBILE)
			items.push(ConfigItem.submenu("CONTROLES", "Cambia la tecla de cada carril", () -> menu.push(controls(menu))));
		items.push(ConfigItem.submenu("GAMEPLAY", "Scroll, ghost tapping, botplay y mas", () -> menu.push(gameplay())));
		items.push(ConfigItem.submenu("AUDIO", "Volumen general, musica y efectos", () -> menu.push(audio())));
		items.push(ConfigItem.submenu("APARIENCIA", "Intro, contador de FPS y logs en pantalla", () -> menu.push(appearance())));
		if (!inGame)
			items.push(ConfigItem.submenu("MISCELANEA", "Convertidor y herramientas", () -> menu.push(misc())));
		return new ConfigScreen("OPCIONES", "Ajusta FMCE a tu gusto", items);
	}

	static function gameplay():ConfigScreen
	{
		return new ConfigScreen("GAMEPLAY", "Como se juega", [
			ConfigItem.check("DOWNSCROLL", "Las notas bajan en vez de subir (se aplica al reiniciar)", ClientPrefs.isDownScroll, ClientPrefs.setDownScroll),
			ConfigItem.check("MIDDLESCROLL", "Tus carriles al centro y el rival oculto (se aplica al reiniciar)", ClientPrefs.isMiddleScroll, ClientPrefs.setMiddleScroll),
			ConfigItem.check("GHOST TAPPING", "Tocar sin nota delante no cuenta como fallo", ClientPrefs.isGhostTapping, ClientPrefs.setGhostTapping),
			ConfigItem.check("BOTPLAY", "El juego toca por ti", ClientPrefs.isBotplay, ClientPrefs.setBotplay),
			ConfigItem.check("SONIDO DE FALLO", "Suena un efecto al fallar una nota", ClientPrefs.isMissSound, ClientPrefs.setMissSound),
			ConfigItem.check("NOTE SPLASHES", "Salpicadura al acertar con SICK", ClientPrefs.isNoteSplashes, ClientPrefs.setNoteSplashes),
			ConfigItem.separator(),
			ConfigItem.number("VELOCIDAD DE NOTAS", "Velocidad base de scroll (se aplica al reiniciar)", 0.5, 10, 0.1, 1, ClientPrefs.getScrollSpeed,
				ClientPrefs.setScrollSpeed)
		]);
	}

	static function audio():ConfigScreen
	{
		return new ConfigScreen("AUDIO", "Volumenes", [
			ConfigItem.slider("VOLUMEN GENERAL", "Volumen maestro de todo el juego", 0.1, ClientPrefs.getMasterVolume, v ->
			{
				ClientPrefs.setMasterVolume(v);
				ClientPrefs.applyAudio();
			}),
			ConfigItem.slider("MUSICA", "Volumen de la musica y la cancion", 0.1, ClientPrefs.getMusicVolume, v ->
			{
				ClientPrefs.setMusicVolume(v);
				ClientPrefs.applyAudio();
			}),
			ConfigItem.slider("EFECTOS", "Volumen de sonidos de menu y de fallo", 0.1, ClientPrefs.getSfxVolume, v ->
			{
				ClientPrefs.setSfxVolume(v);
			})
		]);
	}

	static function appearance():ConfigScreen
	{
		return new ConfigScreen("APARIENCIA", "Lo que se ve en pantalla", [
			ConfigItem.check("SALTAR INTRO", "Al abrir el juego va directo al titulo, sin el splash", ClientPrefs.isSkipIntro, ClientPrefs.setSkipIntro),
			ConfigItem.check("LOGS EN PANTALLA", "Tarjetas con los mensajes del log (tambien con F2)", () -> LogOverlay.enabled, v ->
			{
				LogOverlay.enabled = v;
			}),
			ConfigItem.check("CONTADOR DE FPS", "FPS y memoria arriba a la izquierda (no se guarda)", () -> Framerate.debugMode > 0, v ->
			{
				Framerate.debugMode = v ? 1 : 0;
			})
		]);
	}

	static function misc():ConfigScreen
	{
		var items:Array<ConfigItem> = [
			ConfigItem.action("CONVERTIDOR .FNMM", "Convierte niveles .fnmm al formato de FMCE", () ->
			{
				ClientPrefs.save();
				TransitionHandler.switchState(new ConverterMenuState());
			})
		];
		if (!AdvancedModeState.antiGay)
		{
			items.push(ConfigItem.action("MODO AVANZADO", "Editores y Code Studio (atajo: tecla 7 en el menu principal)", () ->
			{
				ClientPrefs.save();
				TransitionHandler.switchState(new AdvancedModeState());
			}));
		}
		return new ConfigScreen("MISCELANEA", "Herramientas", items);
	}

	static function controls(menu:ConfigMenu):ConfigScreen
	{
		var items:Array<ConfigItem> = [];
		var capturing = -1;

		for (lane in 0...ClientPrefs.getLaneCount())
		{
			var item = ConfigItem.action("", "ENTER para cambiar la tecla  |  ESC cancela", null);
			item.dynamicLabel = () -> "CARRIL " + (lane + 1) + ":  " + (capturing == lane ? "PRESIONA UNA TECLA..." : keysText(lane));
			item.onSelect = () ->
			{
				capturing = lane;
				menu.captureKey(key ->
				{
					rebind(lane, key);
					capturing = -1;
				}, () ->
					{
						capturing = -1;
					});
			};
			items.push(item);
		}
		return new ConfigScreen("CONTROLES", "Teclas de los carriles", items);
	}

	static function keysText(lane:Int):String
	{
		var keys = ClientPrefs.getLaneKeys(lane);
		return keys.length == 0 ? "-" : keys.join(" / ");
	}

	/** Cambia la tecla principal del carril. Si otro carril ya la usaba, intercambian para no duplicar. */
	static function rebind(lane:Int, key:String):Void
	{
		var mine = ClientPrefs.getLaneKeys(lane).copy();
		var old:Null<String> = mine.length > 0 ? mine[0] : null;

		for (other in 0...ClientPrefs.getLaneCount())
		{
			if (other == lane) continue;
			var keys = ClientPrefs.getLaneKeys(other).copy();
			var idx = keys.indexOf(key);
			if (idx < 0) continue;

			if (old != null && keys.indexOf(old) < 0) keys[idx] = old;
			else keys.splice(idx, 1);
			// Un carril nunca se queda sin teclas.
			if (keys.length > 0) ClientPrefs.setLaneKeys(other, keys);
		}

		var at = mine.indexOf(key);
		if (at > 0)
		{
			mine[at] = mine[0];
			mine[0] = key;
		}
		else if (mine.length == 0)
			mine.push(key);
		else
			mine[0] = key;
		ClientPrefs.setLaneKeys(lane, mine);
	}

	/**
	 * Arbol de creditos. Cada entrada con `menu` es una seccion aparte (se entra con ENTER y se vuelve con ESC),
	 * igual que los <menu> del credits.xml de Codename; las demas son personas o enlaces.
	 * Para agregar gente basta con meter otra linea en la seccion que toque.
	 */
	static final CREDITS:Array<CreditEntry> = [
		{
			name: "ENGINE",
			desc: "Equipo de desarrollo, y sus artistas",
            background: "credits_1",
			menu: [
				{
					name: "TheJarret084",
					desc: "Creador y programador principal de FMCE... y artista novato",
					url: "https://github.com/TheJarret084",
					avatar: "https://cdn.discordapp.com/avatars/1361447743444226088/a5ce44e72dec1919333a5c036d4f190c.png?size=2048",
                    color: FlxColor.RED
				},
                {
					name: "Cubicko",
					desc: "Artista Principal",
					url: "https://www.youtube.com/@TheCubicko2014",
					avatar: "https://cdn.discordapp.com/avatars/944071738982031401/3b2c81d4c34c28bcc2a59c208a18c8a5.png?size=2048",
                    color: FlxColor.fromRGB(0, 255, 170)
				},
                {
					name: "UnwiFoxy",
					desc: "No se que hiso este wei",
					url: "https://youtube.com/@unwifoxy11",
					avatar: "https://cdn.discordapp.com/avatars/897985259805749269/8ef9afd4a95ecf7818b97b09d0434a47.png?size=2048",
                    color: FlxColor.fromRGB(139, 0, 93)
				},
                {
					name: "Papas",
					desc: "BGS entre menus y mas assets",
					url: "https://youtube.com/@unwifoxy11",
					avatar: "https://cdn.discordapp.com/avatars/1410318769347363071/07fe3880e7573b7342009782d73d911e.png?size=2048",
                    color: FlxColor.fromRGB(139, 0, 93)
                }
			]
		},
		{
			name: "Basado en",
            background: "othersEngines",
			desc: "Proyectos en los que se apoya este Engine",
			menu: [
                {
					name: "Funky Maker!: Mobile (de KingGC)",
					desc: "Literalmente usamos su nombre, base principal de todo (nota de creador: espero algun dia ser revisor, es mi unico sueño en ese juego)",
					url: "https://play.google.com/store/apps/details?id=com.kingamescreator.fnmm",
					color: FlxColor.fromRGB(242,255,119)  // DORADO rgb(242,255,119)
                    // no ponemos avatar porque en fallback es el icon de el GGs
				},
				{
					name: "Codename Engine",
					desc: "Referencia de editores, charts y menus",
					url: "https://github.com/CodenameCrew/CodenameEngine",
                    avatar: "https://github.com/CodenameCrew/CodenameEngine/blob/main/assets%2Fimages%2Ficon.png",
					color: 0xFFFFC107
				},
				{
					name: "Friday Night Funkin'",
					desc: "El juego original",
					url: "https://ninja-muffin24.itch.io/funkin",
                    avatar: "https://github.com/FunkinCrew/funkin.art/blob/main/icons%2Fbf-iOS-Default-1024x1024.png",
                    color: FlxColor.YELLOW
				},
                {
					name: "KADE ENGINE: Mobile",
					desc: "Engine modificado, mas modificado, pero de aqui saque la Hitbox para mobile, y mas utilidades",
					url: "https://github.com/TheLeerName/Kade-Engine-android",
                    avatar: "https://github.com/TheLeerName/Kade-Engine-android/blob/master/art/icon16.png",
                    color: FlxColor.GRAY
                    
				},
				{
					name: "HaxeFlixel",
					desc: "El framework sobre el que corre todo",
					url: "https://haxeflixel.com",
                    avatar: "https://github.com/HaxeFlixel/flixel/blob/dev/assets/images/logo/logo.png",
                    color: FlxColor.ORANGE
				}
			]
		}
	];

	public static function credits(menu:ConfigMenu):ConfigScreen
		return creditScreen(menu, "CREDITOS", "Gracias a todos los que hicieron esto posible", CREDITS);

	/** Construye una pantalla de creditos; las secciones se llaman a si mismas para abrir su propia pantalla. */
	static function creditScreen(menu:ConfigMenu, title:String, desc:String, entries:Array<CreditEntry>):ConfigScreen
	{
		var items:Array<ConfigItem> = [];
		for (entry in entries)
		{
			var text = entry.desc != null ? entry.desc : "";
			var item:ConfigItem;
			if (entry.menu != null)
			{
				var children = entry.menu;
				var name = entry.name;
				var background = entry.background;
				item = ConfigItem.submenu(name, text, () ->
				{
					var screen = creditScreen(menu, name.toUpperCase(), text, children);
					screen.background = background; // ConfigMenu avisa a onBackgroundChange al entrar y al volver
					menu.push(screen);
				});
			}
			else
			{
				var url = entry.url;
				item = ConfigItem.action(entry.name, text, url != null && url != "" ? () -> CoolUtil.openURL(url) : null);
				item.hasIcon = true;
				item.iconUrl = entry.avatar != null && entry.avatar != "" ? entry.avatar : null;
				item.iconAsset = entry.name;
			}
			if (entry.color != null) item.color = entry.color;
			items.push(item);
		}
		return new ConfigScreen(title, desc, items);
	}
}
