package org.fmce;

import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

/** Notificacion nativa de Android para el CrashHandler (funky/core/CrashHandler.hx). */
public class CrashNotifier
{
	static final String CHANNEL = "fmce_crash";

	/** Android 13+: sin este permiso las notificaciones no salen. Se pide al iniciar, no al crashear. */
	public static void requestPermission()
	{
		try
		{
			if (Build.VERSION.SDK_INT < 33) return;
			final Activity activity = (Activity) org.libsdl.app.SDLActivity.getContext();
			if (activity.checkSelfPermission("android.permission.POST_NOTIFICATIONS") == PackageManager.PERMISSION_GRANTED) return;
			activity.runOnUiThread(new Runnable()
			{
				public void run()
				{
					activity.requestPermissions(new String[] { "android.permission.POST_NOTIFICATIONS" }, 7002);
				}
			});
		}
		catch (Exception e)
		{
			android.util.Log.w("FMCE", "no se pudo pedir el permiso de notificaciones: " + e);
		}
	}

	/** Devuelve false si no se pudo mostrar (sin permiso, sin contexto...). Nunca lanza. */
	public static boolean show(String title, String text, String details)
	{
		try
		{
			Context context = org.libsdl.app.SDLActivity.getContext();
			NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
			if (manager == null) return false;

			Notification.Builder builder;
			if (Build.VERSION.SDK_INT >= 26)
			{
				NotificationChannel channel = new NotificationChannel(CHANNEL, "Errores del juego", NotificationManager.IMPORTANCE_HIGH);
				manager.createNotificationChannel(channel);
				builder = new Notification.Builder(context, CHANNEL);
			}
			else
			{
				builder = new Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH);
			}

			builder.setSmallIcon(android.R.drawable.stat_notify_error)
				.setContentTitle(title)
				.setContentText(text)
				.setStyle(new Notification.BigTextStyle().bigText(details))
				.setAutoCancel(true);

			// tocarla vuelve al juego (abrir el .txt desde aca exigiria un FileProvider)
			Intent launch = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
			if (launch != null)
			{
				launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
				int flags = PendingIntent.FLAG_UPDATE_CURRENT | (Build.VERSION.SDK_INT >= 23 ? PendingIntent.FLAG_IMMUTABLE : 0);
				builder.setContentIntent(PendingIntent.getActivity(context, 0, launch, flags));
			}

			manager.notify((int) (System.currentTimeMillis() & 0x7fffffff), builder.build());
			return true;
		}
		catch (Throwable e)
		{
			android.util.Log.w("FMCE", "no se pudo mostrar la notificacion de crash: " + e);
			return false;
		}
	}
}
