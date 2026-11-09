package org.fmce;

import android.app.Activity;
import android.util.Log;

/** Prepara el Discord Social SDK en Android (por reflexion, para compilar sin el .aar). */
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
