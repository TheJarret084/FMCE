package org.fmce;

import android.graphics.Bitmap;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.os.Build;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.util.Locale;

/**
 * Saca los frames de un video (.mp4) a PNG en Android: es lo que en escritorio hace ffmpeg
 * (ver funky.backend.converter.VideoStrip / AndroidFrames.hx). FunkFMPEG arma la tira despues.
 *
 * El trabajo corre en un hilo de Java propio y Haxe solo consulta `state()` / `progress()`, asi la pantalla sigue viva.
 * Solo hay una extraccion a la vez (el exportador procesa un video por vez).
 */
public class VideoFrames
{
	public static final int IDLE = 0;
	public static final int RUNNING = 1;
	public static final int DONE = 2;
	public static final int FAILED = 3;
	public static final int CANCELLED = 4;

	private static volatile Thread worker = null;
	private static volatile int state = IDLE;
	private static volatile int written = 0;
	private static volatile boolean cancelRequested = false;
	private static volatile String errorText = "";

	/**
	 * "ancho,alto,fps,segundos" del video tal como se va a ver (ya con la rotacion aplicada), o "error: ..." si no se pudo leer.
	 * El tamano sale del primer frame de verdad, asi no hay que adivinar como se aplica la rotacion en cada telefono.
	 */
	public static String probe(String path)
	{
		MediaMetadataRetriever retriever = new MediaMetadataRetriever();
		try
		{
			retriever.setDataSource(path);

			long durationMs = parseLong(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
			int width = 0;
			int height = 0;
			Bitmap first = retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
			if (first != null)
			{
				width = first.getWidth();
				height = first.getHeight();
				first.recycle();
			}
			if (width <= 0 || height <= 0)
			{
				width = (int) parseLong(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH));
				height = (int) parseLong(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT));
				int rotation = (int) parseLong(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION));
				if ((rotation / 90) % 2 == 1)
				{
					int swap = width;
					width = height;
					height = swap;
				}
			}
			if (width <= 0 || height <= 0) return "error: el video no trae tamano";

			double fps = 0;
			if (Build.VERSION.SDK_INT >= 28 && durationMs > 0)
			{
				long count = parseLong(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT));
				if (count > 0) fps = count * 1000.0 / durationMs;
			}
			if (fps <= 0) fps = trackFrameRate(path);
			if (fps <= 0) fps = 30;

			return width + "," + height + "," + String.format(Locale.US, "%.4f", fps) + "," + String.format(Locale.US, "%.4f", durationMs / 1000.0);
		}
		catch (Throwable t)
		{
			return "error: " + t;
		}
		finally
		{
			try { retriever.release(); } catch (Throwable ignored) {}
		}
	}

	/**
	 * Empieza a sacar `count` frames (el i-esimo en el segundo i / fps) como `f000001.png`, `f000002.png`... dentro de `outDir`,
	 * ya escalados a `width` x `height`. `fpsMilli` = fps x 1000 (23.976 fps -> 23976). Devuelve false si no pudo arrancar.
	 */
	public static boolean start(final String path, final String outDir, final int fpsMilli, final int width, final int height, final int count)
	{
		Thread previous = worker;
		if (previous != null && previous.isAlive())
		{
			cancelRequested = true;
			try { previous.join(5000); } catch (InterruptedException ignored) {}
			if (previous.isAlive())
			{
				errorText = "la extraccion anterior sigue corriendo";
				state = FAILED;
				return false;
			}
		}

		File dir = new File(outDir);
		if (!dir.isDirectory() && !dir.mkdirs())
		{
			errorText = "no se pudo crear " + outDir;
			state = FAILED;
			return false;
		}

		cancelRequested = false;
		errorText = "";
		written = 0;
		state = RUNNING;

		Thread thread = new Thread(new Runnable()
		{
			@Override
			public void run()
			{
				extract(path, outDir, fpsMilli, width, height, count);
			}
		}, "fmce-video-frames");
		worker = thread;
		thread.start();
		return true;
	}

	/** Frames ya escritos. */
	public static int progress()
	{
		return written;
	}

	/** IDLE, RUNNING, DONE, FAILED o CANCELLED. */
	public static int state()
	{
		return state;
	}

	public static String error()
	{
		return errorText;
	}

	/** Pide parar y espera (poco) a que termine el frame en curso. */
	public static void cancel()
	{
		cancelRequested = true;
		Thread thread = worker;
		if (thread != null && thread.isAlive())
		{
			try { thread.join(3000); } catch (InterruptedException ignored) {}
		}
	}

	// ------------------------------------------------------------------ hilo

	private static void extract(String path, String outDir, int fpsMilli, int width, int height, int count)
	{
		MediaMetadataRetriever retriever = new MediaMetadataRetriever();
		Bitmap last = null;
		try
		{
			retriever.setDataSource(path);
			for (int i = 0; i < count; i++)
			{
				if (cancelRequested)
				{
					state = CANCELLED;
					return;
				}

				long timeUs = (long) (i * 1000000000.0 / fpsMilli);
				Bitmap frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST);
				Bitmap scaled;
				if (frame != null)
				{
					scaled = fit(frame, width, height);
					if (scaled != frame) frame.recycle();
					if (last != null) last.recycle();
					last = scaled;
				}
				else
				{
					// el decodificador no dio frame (pasa cerca del final): se repite el ultimo para no romper la cuenta
					scaled = last;
					if (scaled == null) throw new RuntimeException("el video no dio el frame " + i);
				}

				writePng(scaled, new File(outDir, String.format(Locale.US, "f%06d.png", i + 1)));
				written = i + 1;
			}
			state = DONE;
		}
		catch (Throwable t)
		{
			errorText = String.valueOf(t);
			state = FAILED;
		}
		finally
		{
			if (last != null) last.recycle();
			try { retriever.release(); } catch (Throwable ignored) {}
		}
	}

	/** Reduce a la mitad mientras sobre mas del doble (el filtro bilineal solo no promedia todos los pixeles) y luego ajusta al tamano exacto. */
	private static Bitmap fit(Bitmap source, int width, int height)
	{
		if (source.getWidth() == width && source.getHeight() == height) return source;
		Bitmap current = source;
		while (current.getWidth() / 2 >= width && current.getHeight() / 2 >= height)
		{
			Bitmap next = Bitmap.createScaledBitmap(current, current.getWidth() / 2, current.getHeight() / 2, true);
			if (current != source && current != next) current.recycle();
			current = next;
		}
		Bitmap out = Bitmap.createScaledBitmap(current, width, height, true);
		if (current != source && current != out) current.recycle();
		return out;
	}

	private static void writePng(Bitmap bitmap, File file) throws java.io.IOException
	{
		BufferedOutputStream out = new BufferedOutputStream(new FileOutputStream(file), 1 << 16);
		try
		{
			if (!bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)) throw new java.io.IOException("no se pudo escribir " + file.getName());
		}
		finally
		{
			out.close();
		}
	}

	private static double trackFrameRate(String path)
	{
		MediaExtractor extractor = new MediaExtractor();
		try
		{
			extractor.setDataSource(path);
			for (int i = 0; i < extractor.getTrackCount(); i++)
			{
				MediaFormat format = extractor.getTrackFormat(i);
				String mime = format.getString(MediaFormat.KEY_MIME);
				if (mime != null && mime.startsWith("video/") && format.containsKey(MediaFormat.KEY_FRAME_RATE))
				{
					try { return format.getInteger(MediaFormat.KEY_FRAME_RATE); }
					catch (ClassCastException e) { return format.getFloat(MediaFormat.KEY_FRAME_RATE); }
				}
			}
		}
		catch (Throwable ignored) {}
		finally
		{
			try { extractor.release(); } catch (Throwable ignored) {}
		}
		return 0;
	}

	private static long parseLong(String value)
	{
		if (value == null) return 0;
		try { return Long.parseLong(value.trim()); }
		catch (NumberFormatException e) { return 0; }
	}
}
