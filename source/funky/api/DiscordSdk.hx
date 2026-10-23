package funky.api;

#if DISCORD_SDK
import cpp.ConstCharStar;

/**
 * Discord Social SDK (puente en `native/DiscordBridge.cpp`). Solo Android (el escritorio usa hxdiscord_rpc, ver DiscordClient).
 * Para el codigo del juego usa `DiscordClient`, no esto.
 */
@:build(funky.api.DiscordBuild.xml())
@:include("DiscordBridge.h")
@:native("fmce::discord")
extern class DiscordSdk
{
	static function init(applicationId:ConstCharStar, name:ConstCharStar):Bool;

	static function update(details:ConstCharStar, state:ConstCharStar, largeImage:ConstCharStar, largeText:ConstCharStar,
		smallImage:ConstCharStar, smallText:ConstCharStar, startSeconds:Int, endSeconds:Int):Void;

	static function clear():Void;
	static function tick():Void;
	static function shutdown():Void;
	static function lastError():ConstCharStar;
}
#end
