package funky.api;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;

/** Rutas absolutas del puente nativo y del Discord SDK para hxcpp. */
class DiscordBuild
{
	public static function xml():Array<Field>
	{
		var api = Path.normalize(FileSystem.fullPath(Path.directory(Context.resolvePath("funky/api/DiscordSdk.hx"))));
		var native = api + "/native";
		var root = Path.normalize(FileSystem.fullPath(api + "/../../.."));
		var discord = root + "/source/libs/discord";
		var stage = root + "/building/_discord/jni"; // lo deja building/discord-android.sh (los .so salen del .aar)

		var build = '
<files id="haxe">
	<compilerflag value="-I$native"/>
</files>
<files id="fmceDiscord" cxx_standard="17">
	<compilerflag value="-std=c++17"/>
	<compilerflag value="-I$discord/include"/>
	<compilerflag value="-I$native"/>
	<file name="$native/DiscordBridge.cpp"/>
</files>
<target id="haxe">
	<files id="fmceDiscord"/>
	<section if="android">
		<libpath name="$stage/arm64-v8a" if="HXCPP_ARM64"/>
		<libpath name="$stage/armeabi-v7a" if="HXCPP_ARMV7"/>
		<libpath name="$stage/x86_64" if="HXCPP_X86_64"/>
		<libpath name="$stage/x86" if="HXCPP_X86"/>
		<lib name="-ldiscord_partner_sdk"/>
	</section>
</target>
';

		Context.getLocalClass().get().meta.add(":buildXml", [macro $v{build}], Context.currentPos());
		return null;
	}
}
#end
