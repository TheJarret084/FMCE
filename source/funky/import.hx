#if !macro
package funky;

import funky.backend.system.Main;
import funky.backend.assets.Paths;
import funky.backend.MusicBeatState;
import funky.backend.MusicBeatSubstate;
import funky.backend.MusicBeatGroup;
import funky.backend.FunkinSprite;
import funky.backend.utils.*;
import funky.backend.utils.TranslationUtil as TU;
import funky.backend.system.Logs;
import funky.options.Options;
import funky.game.PlayState;
import funky.backend.scripting.EventManager;

import openfl.utils.Assets;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxObject;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.util.FlxDestroyUtil;

import funky.backend.system.Flags;
import funky.Types;

import funky.menus.ui.Alphabet;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

using StringTools;
using funky.backend.utils.CoolUtil;
#end
