package funky.api;

import funky.api.RPCState;
import lime.app.Application;
import sys.thread.Thread;
import StringTools;

#if DISCORD_RPC
import discord_rpc.DiscordRpc;
#end

class DiscordClient
{
	#if DISCORD_RPC

	public static var started:Bool = false;
	public static var clientID:String = "1509746395962409071";

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
		#if DISCORD_RPC
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
		#if DISCORD_RPC
		if (started)
			return;

		DiscordRpc.start({
			clientID: clientID,
			onReady: function()
			{
				trace("Discord RPC listo.");
			},
			onDisconnected: function(code:Int, message:String)
			{
				trace('Discord RPC desconectado: ' + code + " / " + message);
			},
			onError: function(code:Int, message:String)
			{
				trace('Discord RPC error: ' + code + " / " + message);
			}
		});

		started = true;
		startTimestamp = Std.int(Date.now().getTime() / 1000);

		menuPresence();

		Thread.create(() ->
		{
			while (started)
			{
				DiscordRpc.process();
				Sys.sleep(2);
			}
		});
		#end
	}

	public static function shutdown():Void
	{
		#if DISCORD_RPC
		if (!started)
			return;

		started = false;
		DiscordRpc.shutdown();
		#end
	}

	static inline function normalizeText(value:String, fallback:String):String
	{
		#if DISCORD_RPC
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
		#if DISCORD_RPC
		if (!started)
			return;

		image      = normalizeText(image, DEFAULT_ICON);
		smallImage = normalizeText(smallImage, DEFAULT_ICON);

		var largeText:String = largeImageTexts.exists(image)
			? largeImageTexts.get(image)
			: image;

		var smallText:String = smallImageTexts.exists(smallImage)
			? smallImageTexts.get(smallImage)
			: smallImage;

		var presence:DiscordPresenceOptions = {
			details:        details,
			state:          state,
			largeImageKey:  image,
			largeImageText: largeText,
			smallImageKey:  smallImage,
			smallImageText: smallText,
			startTimestamp: withTime ? startTimestamp : 0,
			endTimestamp:   endTimestamp > 0 ? Std.int(endTimestamp / 1000) : 0
		};

		DiscordRpc.presence(presence);
		#end
	}

	public static function setPresence(presence:RPCState):Void
	{
		#if DISCORD_RPC
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
		#if DISCORD_RPC
		setPresence(Menu);
		#end
	}

	public static function freeplayPresence():Void
	{
		#if DISCORD_RPC
		setPresence(Freeplay);
		#end
	}

	public static function storyPresence():Void
	{
		#if DISCORD_RPC
		setPresence(Story);
		#end
	}

	public static function settingsPresence():Void
	{
		#if DISCORD_RPC
		setPresence(Settings);
		#end
	}

	public static function creditsPresence():Void
	{
		#if DISCORD_RPC
		setPresence(Credits);
		#end
	}

	public static function pausePresence(song:String):Void
	{
		#if DISCORD_RPC
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
		#if DISCORD_RPC
		setPresence(Playing(song, difficulty, iconRPC == null ? "fmce" : iconRPC, smallIcon == null ? "" : smallIcon, withTime));
		#end
	}

	public static function gameOverFadePresence(song:String, misses:Int):Void
	{
		#if DISCORD_RPC
		setPresence(GameOverFade(song, misses));
		#end
	}

	public static function gameOverPresence(song:String, misses:Int, willRestart:Bool):Void
	{
		#if DISCORD_RPC
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
		#if DISCORD_RPC
		setPresence(Custom(details, state, icon == null ? "fmce" : icon, smallIcon == null ? "" : smallIcon, withTime, endTimestamp));
		#end
	}
}
