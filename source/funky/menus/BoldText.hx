package funky.menus;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.text.FlxText;
import funky.core.Paths;

/** Texto con la fuente bold del menu (`menus/alphabet-bold`), como el Alphabet de Codename. */
class BoldText extends FlxSpriteGroup
{
	static var atlas:FlxAtlasFrames;

	static final NAMES:Map<String, String> = [
		"." => "period", "," => "comma", "-" => "hyphen", "_" => "underscore", ":" => "colon", ";" => "semicolon",
		"!" => "exclamationmark", "?" => "questionmark", "'" => "singlequote", "\"" => "doublequote", "&" => "ampersand",
		"(" => "roundbracket-left", ")" => "roundbracket-right", "/" => "slash", "+" => "plus", "=" => "equal",
		"0" => "zero", "1" => "one", "2" => "two", "3" => "three", "4" => "four", "5" => "five", "6" => "six",
		"7" => "seven", "8" => "eight", "9" => "nine", "<" => "anglebracket-left", ">" => "anglebracket-right",
		"%" => "percent", "$" => "dollar", "#" => "pound", "@" => "at", "*" => "asterisk", "~" => "tilde"
	];

	/** Distancia entre letras y alto de linea, en px. */
	static inline var SPACE:Float = 30;
	static inline var KERN:Float = 3;

	public var text(default, null):String;

	public function new(x:Float, y:Float, text:String, scale:Float = 1)
	{
		super(x, y);
		this.text = text;

		if (atlas == null) atlas = Paths.getSparrowAtlas("menus/alphabet-bold");

		if (atlas == null)
		{
			var fallback = new FlxText(0, 0, 0, text.toUpperCase(), Std.int(56 * scale));
			add(fallback);
			return;
		}

		var cursor:Float = 0;
		for (i in 0...text.length)
		{
			var ch = text.charAt(i);
			if (ch == " ")
			{
				cursor += SPACE * scale;
				continue;
			}

			var key = NAMES.exists(ch) ? NAMES.get(ch) : ch.toLowerCase();
			var frameName = "character-" + key + "0000";
			if (atlas.getByName(frameName) == null) continue;

			var letter = new FlxSprite(cursor, 0);
			letter.frames = atlas;
			letter.animation.frameName = frameName;
			letter.scale.set(scale, scale);
			letter.updateHitbox();
			letter.antialiasing = true;
			add(letter);
			cursor += letter.width + KERN * scale;
		}
	}
}
