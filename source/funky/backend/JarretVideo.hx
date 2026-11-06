
package funky.backend;

import flixel.FlxG;
import flixel.FlxSubState;
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import hxvlc.flixel.FlxVideo;

import funky.core.Paths;
import funkin.editors.ui.UIWarningSubstate;

typedef ConfigWarning =
{
    var titleError:String;
    var messageBoxError:String;
    var labelError:String;
    var colorError:FlxColor;
    var onClickError:UIWarningSubstate->Void;
}

class JarretVideo extends FlxSubState
{
    public var fnc:Void->Void;
    public var instance:JarretVideo;

    public var warning:ConfigWarning;

    public var showError:Void->Void;

    var video:FlxVideo;
    var finished:Bool = false;

    public function new()
    {
        super();
        instance = this;
    }

    public function create(
        sprite:FlxSprite,
        path:String,
        ?onError:Void->Void,
        ?func:Void->Void
    ):Void
    {
        fnc = func;
        showError = onError;

        finished = false;
        video = new FlxVideo();

        video.onEndReached.add(function()
        {
            finishVideo();
        });

        video.onEncounteredError.add(function(error:String)
        {
            finishVideo(true);
        });

        FlxG.addChildBelowMouse(video);

        if (video.load(Paths.video(path)))
        {
            new FlxTimer().start(0.001, function(_)
            {
                if (!finished && video != null)
                    video.play();
            });
        }
        else
        {
            finishVideo(true);
        }
    }

    function finishVideo(error:Bool = false):Void
    {
        if (finished) return;
        finished = true;

        if (video != null)
        {
            video.stop();
            video.dispose();
            FlxG.removeChild(video);
            video = null;
        }

        close();

        if (error)
        {
            if (showError != null)
                showError();
        }
        else if (fnc != null)
        {
            fnc();
        }
    }

    override function destroy():Void
    {
        if (video != null)
        {
            video.stop();
            video.dispose();
            FlxG.removeChild(video);
            video = null;
        }

        super.destroy();
    }
}
