package org.fmce;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;

public class StorageAccess
{

	public static boolean hasAccess()
	{
		if (Build.VERSION.SDK_INT >= 30) return Environment.isExternalStorageManager();
		if (Build.VERSION.SDK_INT >= 23)
		{
			Context context = org.libsdl.app.SDLActivity.getContext();
			return context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED;
		}
		return true;
	}

	public static void requestAccess()
	{
		try
		{
			Activity activity = (Activity) org.libsdl.app.SDLActivity.getContext();
			if (Build.VERSION.SDK_INT >= 30)
			{
				try
				{
					Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:" + activity.getPackageName()));
					activity.startActivity(intent);
				}
				catch (Exception e)
				{
					activity.startActivity(new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION));
				}
			}
			else if (Build.VERSION.SDK_INT >= 23)
			{
				activity.requestPermissions(new String[] {
					android.Manifest.permission.READ_EXTERNAL_STORAGE,
					android.Manifest.permission.WRITE_EXTERNAL_STORAGE
				}, 7001);
			}
		}
		catch (Exception e)
		{
			android.util.Log.w("FMCE", "no se pudo pedir acceso al almacenamiento: " + e);
		}
	}
}
