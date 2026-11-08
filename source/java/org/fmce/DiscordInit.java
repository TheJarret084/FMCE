package org.fmce;

import android.app.Activity;
import android.util.Log;

/**
 * Prepara el Discord Social SDK en Android: necesita la Activity antes de crear el Client.
 * Lo llama DiscordClient.hx por JNI.
 *
 * El SDK se llama por reflexion a proposito: asi este archivo compila aunque el .aar no este
 * (por ejemplo al compilar con -DFMCE_NO_DISCORD) y no hace falta una carpeta java aparte.
 */
public class DiscordInit
{
	public static boolean init()
	{
		try
		{
			Activity activity = (Activity) org.libsdl.app.SDLActivity.getContext();
			Class<?> sdk = Class.forName("com.discord.socialsdk.DiscordSocialSdkInit");
			sdk.getMethod("setEngineActivity", Activity.class).invoke(null, activity);
			return true;
		}
		catch (Throwable e)
		{
			Log.w("FMCE", "Discord SDK: no se pudo iniciar: " + e);
			return false;
		}
	}
}
