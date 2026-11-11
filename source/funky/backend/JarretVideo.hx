package funky.backend;

import flixel.FlxG;
import flixel.FlxSubState;
import flixel.util.FlxTimer;
#if FMCE_VIDEO
import hxvlc.flixel.FlxVideo;
#end
import funky.core.Log;
import funky.core.Paths;

class JarretVideo extends FlxSubState
{
	#if FMCE_VIDEO
	var video:FlxVideo;
	#end
	var finished:Bool = false;
	var onDone:Null<Void->Void>;

	public function new()
	{
		super();
	}

	public function play(name:String, ?onDone:Void->Void):Void
	{
		this.onDone = onDone;
		finished = false;

		#if FMCE_VIDEO
		try
		{
			video = new FlxVideo();
			video.onEndReached.add(function() finish());
			video.onEncounteredError.add(function(error:String)
			{
				Log.warn('[JarretVideo] error de video: $error');
				finish();
			});

			FlxG.addChildBelowMouse(video);

			if (video.load(Paths.video(name)))
			{

				new FlxTimer().start(0.05, function(_)
				{
					if (!finished && video != null) video.play();
				});
			}
			else
			{
				Log.warn('[JarretVideo] no se pudo cargar ${Paths.video(name)}');
				finish();
			}
		}
		catch (e:Dynamic)
		{
			Log.warn('[JarretVideo] $e');
			finish();
		}
		#else

		finish();
		#end
	}

	function releaseVideo():Void
	{
		#if FMCE_VIDEO
		if (video == null) return;
		try
		{
			video.stop();
			video.dispose();
			FlxG.removeChild(video);
		}
		catch (e:Dynamic) {}
		video = null;
		#end
	}

	function finish():Void
	{
		if (finished) return;
		finished = true;

		releaseVideo();
		var done = onDone;
		onDone = null;

		close();
		if (done != null) done();
	}

	override function destroy():Void
	{
		releaseVideo();
		super.destroy();
	}
}
