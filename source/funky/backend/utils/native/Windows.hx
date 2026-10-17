package funky.backend.utils.native;

#if windows
import funky.backend.utils.NativeAPI.MessageBoxIcon;

@:buildXml('
<target id="haxe">
	<lib name="user32.lib" if="windows" />
</target>
')

// Adaptado de Codename Engine (funkin.backend.utils.native.Windows), recortado
// a lo estrictamente necesario para el CrashHandler (solo el message box nativo).
@:cppFileCode('
#include <windows.h>
')
@:dox(hide)
final class Windows
{
	@:functionCode('
		MessageBoxA(GetActiveWindow(), message.c_str(), caption.c_str(), icon | MB_SETFOREGROUND);
	')
	public static function showMessageBox(caption:String, message:String, icon:MessageBoxIcon = MSG_WARNING):Void
	{
	}
}
#end
