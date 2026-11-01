
var activeEnemyIndex:Int = 0;

var originalEnemyIcon:String = "";
var iconBaseScaleX:Float = 1;
var iconBaseScaleY:Float = 1;

var iconTransitionTween:FlxTween;
var healthColorTween:FlxTween;

var iconIsTransitioning:Bool = false;

var healthBarEnemyColor:FlxColor;
var healthBarPlayerColor:FlxColor;

var iconCenterX:Float = 0;
var iconCenterY:Float = 0;

var enemyIcons:Array<String> = [
    "",
    ""
];

function postCreate() {
    originalEnemyIcon = iconP2.curCharacter;

    iconBaseScaleX = iconP2.scale.x;
    iconBaseScaleY = iconP2.scale.y;

    healthBarEnemyColor = dad.iconColor;
    healthBarPlayerColor = boyfriend.iconColor;
}

function getEnemyCharacterColor(memberIndex:Int):FlxColor {
    if (strumLines.members[memberIndex] != null) {
        var line = strumLines.members[memberIndex];

        if (line.characters != null && line.characters.length > 0) {
            var character = line.characters[0];

            if (character != null) {
                return character.iconColor;
            }
        }
    }

    return healthBarEnemyColor;
}

function getEnemyIcon(memberIndex:Int):String {
    if (memberIndex >= 0 && memberIndex < strumLines.members.length) {
        var line = strumLines.members[memberIndex];

        if (line != null && line.characters != null && line.characters.length > 0) {
            var character = line.characters[0];

            if (character != null) {
                return character.getIcon();
            }
        }
    }

    return originalEnemyIcon;
}


function switchEnemy(memberIndex:Int) {
    if (activeEnemyIndex == memberIndex) return;

    if (memberIndex < 0 || memberIndex >= strumLines.members.length) {
        trace("Índice de oponente inválido: " + memberIndex);
        return;
    }

    activeEnemyIndex = memberIndex;
    iconIsTransitioning = true;

    if (iconTransitionTween != null) {
        iconTransitionTween.cancel();
    }

    iconCenterX = iconP2.x + iconP2.width / 2;
    iconCenterY = iconP2.y + iconP2.height / 2;

    iconTransitionTween = FlxTween.tween(
        iconP2.scale,
        {x: 0, y: 0},
        0.2,
        {
            ease: FlxEase.sineInOut,
            onUpdate: function(tween:FlxTween) {
                iconP2.updateHitbox();
                iconP2.x = iconCenterX - iconP2.width / 2;
                iconP2.y = iconCenterY - iconP2.height / 2;
            },
            onComplete: function(tween:FlxTween) {
                iconP2.setIcon(getEnemyIcon(memberIndex), false);

                iconP2.scale.set(0, 0);
                iconP2.updateHitbox();

                iconP2.x = iconCenterX - iconP2.width / 2;
                iconP2.y = iconCenterY - iconP2.height / 2;

                iconTransitionTween = FlxTween.tween(
                    iconP2.scale,
                    {
                        x: iconBaseScaleX,
                        y: iconBaseScaleY
                    },
                    0.2,
                    {
                        ease: FlxEase.sineInOut,
                        onUpdate: function(tween:FlxTween) {
                            iconP2.updateHitbox();
                            iconP2.x = iconCenterX - iconP2.width / 2;
                            iconP2.y = iconCenterY - iconP2.height / 2;
                        },
                        onComplete: function(tween:FlxTween) {
                            iconP2.scale.set(
                                iconBaseScaleX,
                                iconBaseScaleY
                            );

                            iconP2.updateHitbox();
                            iconP2.x = iconCenterX - iconP2.width / 2;
                            iconP2.y = iconCenterY - iconP2.height / 2;

                            iconIsTransitioning = false;
                        }
                    }
                );
            }
        }
    );

    var targetColor = getEnemyCharacterColor(memberIndex);
    var startColor = healthBarEnemyColor;

    if (healthColorTween != null) {
        healthColorTween.cancel();
    }

    healthColorTween = FlxTween.num(
        0,
        1,
        0.4,
        {ease: FlxEase.sineInOut},
        function(t:Float) {
            var color = FlxColor.interpolate(startColor, targetColor, t);

            healthBarEnemyColor = color;

            healthBar.createFilledBar(
                healthBarEnemyColor,
                healthBarPlayerColor
            );

            healthBar.updateBar();
        }
    );
}

function stepHit(curStep:Int) {
    switch (curStep) {
        case 443, 890, 1585, 2401, 2913, 3201:
            switchEnemy(2);

        case 737, 1057, 1841, 2529, 3041, 3297:
            switchEnemy(0);
    }
}