package funky.api;

import funky.api.RPCState;
import lime.app.Application;
import StringTools;

#if (DISCORD_SDK || DISCORD_RPC)
import cpp.ConstCharStar;
#end
#if DISCORD_RPC
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
#end

/**
 * Discord Rich Presence. Un solo `DiscordClient` para todo el juego, con el backend que toque segun la plataforma:
 *
 * - **Android** (`DISCORD_SDK`): Discord Social SDK, desde el `.aar` (ver `DiscordSdk` y `libs/discord/README.md`).
 * - **Escritorio, target cpp** (`DISCORD_RPC`): el haxelib `hxdiscord_rpc` (Windows, Linux y Mac; no pide DLL ni login).
 * - Otros (HashLink, HTML5): no hace nada, y el resto del juego lo llama igual.
 *
 * El nombre que se ve ("Funky Maker: CNE") es el de la aplicacion en https://discord.com/developers: Discord lo toma
 * de ahi, no se puede cambiar por codigo.
 */
class DiscordClient
{
	#if (DISCORD_SDK || DISCORD_RPC)

	public static var started:Bool = false;
	public static var clientID:String = "1509746395962409071";

	/** Nombre fijo de la aplicacion / actividad. */
	public static inline var APP_NAME:String = "Funky Maker: CNE";

	/** Lo ultimo que se mando, para no repetir la misma presencia (Discord limita las actualizaciones). */
	static var lastKey:String = "";

	/**
	 * Claves de imagen que SI existen en Developer Portal > Rich Presence > Art Assets.
	 * Discord no pinta una clave que no este ahi (la tarjeta sale con un circulo vacio), asi que lo que no
	 * este en esta lista cae en ASSET_FALLBACK. Cuando subas mas assets, agregalos aqui.
	 */
	static var availableAssets:Array<String> = ["fmm"];

	static inline var ASSET_FALLBACK:String = "fmm";

	static var startTimestamp:Int = 0;
	static inline var DEFAULT_ICON:String = "fmce";

	static var largeImageTexts:Map<String, String> = [
		"fmce"     => "Funky Maker - Codename Engine",
		"freeplay" => "Escogiendo canción",
		"story"    => "Modo Historia",
		"pause"    => "Juego pausado",
		"dead"     => "Game Over",
		"settings" => "Configuración",
		"credits"  => "Créditos"
	];

	static var smallImageTexts:Map<String, String> = [
		"sfc"   => "SFC",
		"gfc"   => "GFC",
		"fc"    => "Full Combo",
		"clear" => "Clear",
		"miss"  => "Con fallos"
	];

	#end

	static function getGameVersion():String
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		try
		{
			if (Application.current != null && Application.current.meta != null)
			{
				var version = Application.current.meta.get("version");
				if (version != null && StringTools.trim(version) != "")
					return version;
			}
		}
		catch (e:Dynamic) {}
		#end

		return "Dev Build";
	}

	public static function initialize():Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		if (started)
			return;

		#if DISCORD_SDK
		#if android
		// El SDK necesita la Activity antes de crear el cliente (org/fmce/DiscordInit.java)
		try
		{
			var init = lime.system.JNI.createStaticMethod("org/fmce/DiscordInit", "init", "()Z");
			if (!init())
			{
				trace("Discord SDK: no se pudo pasar la Activity");
				return;
			}
		}
		catch (e:Dynamic)
		{
			trace("Discord SDK: JNI fallo: " + e);
			return;
		}
		#end

		if (!DiscordSdk.init(ConstCharStar.fromString(clientID), ConstCharStar.fromString(APP_NAME)))
		{
			trace("Discord SDK: no inicio: " + DiscordSdk.lastError().toString());
			return;
		}

		started = true;
		startTimestamp = Std.int(Date.now().getTime() / 1000);

		// El SDK entrega sus respuestas cuando se le "da turno": cada frame, en el hilo principal.
		Application.current.onUpdate.add(function(_:Int) if (started) DiscordSdk.tick());
		Application.current.onExit.add(function(_:Int) shutdown());

		trace("Discord SDK listo.");
		menuPresence();
		#else
		var handlers:DiscordEventHandlers = new DiscordEventHandlers();
		handlers.ready = cpp.Function.fromStaticFunction(onRpcReady);
		handlers.disconnected = cpp.Function.fromStaticFunction(onRpcDisconnected);
		handlers.errored = cpp.Function.fromStaticFunction(onRpcError);
		Discord.Initialize(ConstCharStar.fromString(clientID), cpp.RawPointer.addressOf(handlers), false, null);

		started = true;
		startTimestamp = Std.int(Date.now().getTime() / 1000);

		// Discord responde cuando se le "da turno": cada frame, en el hilo principal.
		Application.current.onUpdate.add(function(_:Int) if (started) Discord.RunCallbacks());
		Application.current.onExit.add(function(_:Int) shutdown());

		menuPresence();
		#end
		#end
	}

	#if DISCORD_RPC
	static function onRpcReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		trace("Discord RPC listo: " + request[0].username);
	}

	static function onRpcDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace("Discord RPC desconectado: " + errorCode + " / " + message.toString());
	}

	static function onRpcError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		trace("Discord RPC error: " + errorCode + " / " + message.toString());
	}
	#end

	public static function shutdown():Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		if (!started)
			return;

		started = false;
		#if DISCORD_SDK
		DiscordSdk.shutdown();
		#else
		Discord.Shutdown();
		#end
		#end
	}

	static inline function normalizeText(value:String, fallback:String):String
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		if (value == null)
			return fallback;

		var trimmed = StringTools.trim(value);
		return trimmed == "" ? fallback : trimmed;
		#else
		return fallback;
		#end
	}

	static function buildPresence(
		details:String,
		state:String,
		?image:String,
		?smallImage:String,
		?withTime:Bool = false,
		?endTimestamp:Float = 0
	):Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		if (!started)
			return;

		var imageKey = normalizeText(image, DEFAULT_ICON);
		var smallKey = normalizeText(smallImage, "");

		var largeText:String = largeImageTexts.exists(imageKey)
			? largeImageTexts.get(imageKey)
			: imageKey;

		var smallText:String = smallImageTexts.exists(smallKey)
			? smallImageTexts.get(smallKey)
			: smallKey;

		// solo se manda una imagen que exista en el portal; la pequena es opcional (vacia = no se muestra)
		image = availableAssets.contains(imageKey) ? imageKey : ASSET_FALLBACK;
		smallImage = availableAssets.contains(smallKey) ? smallKey : "";

		var end = endTimestamp > 0 ? Std.int(endTimestamp / 1000) : 0;
		var start = withTime ? startTimestamp : 0;

		// no repetir lo mismo: Discord limita las actualizaciones
		var key = [details, state, image, smallImage, Std.string(start), Std.string(end)].join("|");
		if (key == lastKey)
			return;
		lastKey = key;

		#if DISCORD_SDK
		DiscordSdk.update(ConstCharStar.fromString(details), ConstCharStar.fromString(state), ConstCharStar.fromString(image),
			ConstCharStar.fromString(largeText), ConstCharStar.fromString(smallImage), ConstCharStar.fromString(smallText), start, end);
		#else
		var presence:DiscordRichPresence = new DiscordRichPresence();
		presence.type = DiscordActivityType_Playing;
		presence.details = ConstCharStar.fromString(details);
		presence.state = ConstCharStar.fromString(state);
		presence.largeImageKey = ConstCharStar.fromString(image);
		presence.largeImageText = ConstCharStar.fromString(largeText);
		presence.smallImageKey = ConstCharStar.fromString(smallImage);
		presence.smallImageText = ConstCharStar.fromString(smallText);
		presence.startTimestamp = start;
		presence.endTimestamp = end;
		Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence));
		#end
		#end
	}

	public static function setPresence(presence:RPCState):Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		switch (presence)
		{
			case Menu:
				buildPresence(
					"En los menus",
					getGameVersion(),
					"fmce",
					"",
					false
				);

			case Freeplay:
				buildPresence(
					"Escogiendo canción",
					"",
					"freeplay",
					"",
					false
				);

			case Story:
				buildPresence(
					"Modo Historia",
					"",
					"story",
					"",
					false
				);

			case Settings:
				buildPresence(
					"Configuración",
					"",
					"settings",
					"",
					false
				);

			case Credits:
				buildPresence(
					"Créditos",
					"",
					"credits",
					"",
					false
				);

			case Pause(song):
				buildPresence(
					"Pausado",
					song,
					"pause",
					"",
					false
				);

			case Playing(song, difficulty, icon, smallIcon, withTime):
				buildPresence(
					"Jugando: " + song,
					"Dificultad: " + difficulty,
					normalizeText(icon, DEFAULT_ICON),
					normalizeText(smallIcon, ""),
					withTime
				);

			case GameOverFade(song, misses):
				buildPresence(
					"Game Over",
					'Fade de salida | ' + song + ' | Misses: ' + misses,
					"dead",
					"miss",
					false
				);

			case GameOver(song, misses, willRestart):
				buildPresence(
					"Perdió en " + song,
					'Misses: ' + misses + " | Reiniciar: " + (willRestart ? "Sí" : "No"),
					"dead",
					"miss",
					false
				);

			case Custom(details, state, icon, smallIcon, withTime, endTimestamp):
				buildPresence(
					details,
					state,
					icon,
					smallIcon,
					withTime,
					endTimestamp
				);
		}
		#end
	}

	public static function menuPresence():Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(Menu);
		#end
	}

	public static function freeplayPresence():Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(Freeplay);
		#end
	}

	public static function storyPresence():Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(Story);
		#end
	}

	public static function settingsPresence():Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(Settings);
		#end
	}

	public static function creditsPresence():Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(Credits);
		#end
	}

	public static function pausePresence(song:String):Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(Pause(song));
		#end
	}

	public static function playingPresence(
		song:String,
		difficulty:String,
		?iconRPC:String,
		?smallIcon:String,
		?withTime:Bool = true
	):Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(Playing(song, difficulty, iconRPC == null ? "fmce" : iconRPC, smallIcon == null ? "" : smallIcon, withTime));
		#end
	}

	public static function gameOverFadePresence(song:String, misses:Int):Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(GameOverFade(song, misses));
		#end
	}

	public static function gameOverPresence(song:String, misses:Int, willRestart:Bool):Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(GameOver(song, misses, willRestart));
		#end
	}

	public static function customPresence(
		details:String,
		state:String,
		?icon:String,
		?smallIcon:String,
		?withTime:Bool = false,
		?endTimestamp:Float = 0
	):Void
	{
		#if (DISCORD_SDK || DISCORD_RPC)
		setPresence(Custom(details, state, icon == null ? "fmce" : icon, smallIcon == null ? "" : smallIcon, withTime, endTimestamp));
		#end
	}
}
