
import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

import funky.game.PlayState;
import funky.game.StrumLine;
import funky.core.ClientPrefs;
import funky.backend.system.framerate.Framerate;

var movedLine:Bool = false;
var previousMiddleScroll:Bool = false;

function onLoad() {
    previousMiddleScroll = ClientPrefs.isMiddleScroll();
    ClientPrefs.setMiddleScroll(false);
}

function onCreatePost() {
    hud.healthBar.visible = false;
    hud.iconPlayer.visible = false;
    hud.iconOpponent.visible = false;

    Framerate.setVisible(false);

    var px:Float = 20;
    var py:Float = 30;

    for (txt in [hud.accuracyTxt, hud.scoreTxt, hud.missesTxt]) {
        if (txt != null) {
            txt.fieldWidth = 0;
            txt.x = px;
            txt.y = py;
            txt.updateHitbox();

            py += 30;
        }
    }
}


function stepHit(curStep:Int) {
    if (curStep < 546 || movedLine) return;

    movedLine = true;
    
    var offsetX:Float = ((FlxG.width - (4 * StrumLine.BASE_SPACE)) / 3) - playerLine.members[0].x;

    for (strum in playerLine.members) {
        if (strum == null) continue;

        FlxTween.tween(strum, {
            x: strum.x + offsetX
        }, 0.8, {
            ease: FlxEase.quadInOut
        });
    }
}


function onDestroy() {
    ClientPrefs.setMiddleScroll(previousMiddleScroll);
    Framerate.setVisible(true);
}

