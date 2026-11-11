package org.fmce;

import android.graphics.Bitmap;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.os.Build;

import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.Locale;

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

	private static volatile String lastProbeError = "";

	public static String probeError()
	{
		return lastProbeError;
	}

	private static MediaMetadataRetriever open(String path) throws Exception
	{
		File file = new File(path);
		if (!file.isFile()) throw new RuntimeException("no existe el archivo " + path);
		if (!file.canRead()) throw new RuntimeException("sin permiso de lectura: " + path);

		String byPath;
		MediaMetadataRetriever retriever = new MediaMetadataRetriever();
		try
		{
			retriever.setDataSource(path);
			return retriever;
		}
		catch (Throwable t)
		{
			byPath = String.valueOf(t);
			try { retriever.release(); } catch (Throwable ignored) {}
		}

		retriever = new MediaMetadataRetriever();
		FileInputStream stream = null;
		try
		{
			stream = new FileInputStream(file);
			retriever.setDataSource(stream.getFD());
			return retriever;
		}
		catch (Throwable t)
		{
			try { retriever.release(); } catch (Throwable ignored) {}
			throw new RuntimeException("por ruta: " + byPath + " | por descriptor: " + t);
		}
		finally
		{

			if (stream != null)
			{
				try { stream.close(); } catch (Throwable ignored) {}
			}
		}
	}

	private static Bitmap grab(MediaMetadataRetriever retriever, long timeUs, int index)
	{
		Bitmap frame = null;
		try { frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST); } catch (Throwable ignored) {}
		if (frame != null) return frame;
		try { frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC); } catch (Throwable ignored) {}
		if (frame != null) return frame;
		if (Build.VERSION.SDK_INT >= 28)
		{
			try { frame = retriever.getFrameAtIndex(index); } catch (Throwable ignored) {}
			if (frame != null) return frame;
		}
		try { frame = retriever.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_PREVIOUS_SYNC); } catch (Throwable ignored) {}
		return frame;
	}

	public static String probe(String path)
	{
		MediaMetadataRetriever retriever = null;
		lastProbeError = "";
		try
		{
			retriever = open(path);

			long durationMs = parseLong(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION));
			int width = 0;
			int height = 0;
			Bitmap first = null;
			try { first = retriever.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC); } catch (Throwable ignored) {}
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
			lastProbeError = String.valueOf(t);
			return "error: " + t;
		}
		finally
		{
			if (retriever != null)
			{
				try { retriever.release(); } catch (Throwable ignored) {}
			}
		}
	}

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

	public static int progress()
	{
		return written;
	}

	public static int state()
	{
		return state;
	}

	public static String error()
	{
		return errorText;
	}

	public static void cancel()
	{
		cancelRequested = true;
		Thread thread = worker;
		if (thread != null && thread.isAlive())
		{
			try { thread.join(3000); } catch (InterruptedException ignored) {}
		}
	}

	private static void extract(String path, String outDir, int fpsMilli, int width, int height, int count)
	{
		MediaMetadataRetriever retriever = null;
		Bitmap last = null;
		try
		{
			retriever = open(path);
			for (int i = 0; i < count; i++)
			{
				if (cancelRequested)
				{
					state = CANCELLED;
					return;
				}

				long timeUs = (long) (i * 1000000000.0 / fpsMilli);
				Bitmap frame = grab(retriever, timeUs, i);
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

					scaled = last;
					if (scaled == null) throw new RuntimeException("el decodificador del telefono no dio el frame " + i + " (probado por tiempo, keyframe e indice)");
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
			if (retriever != null)
			{
				try { retriever.release(); } catch (Throwable ignored) {}
			}
		}
	}

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
