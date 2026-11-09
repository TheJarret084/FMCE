package advanced.ui.code;

import StringTools;

/** Colorea codigo. */
class Highlighter
{
	static var haxeWords:Map<String, Int> = buildHaxeWords();

	static function buildHaxeWords():Map<String, Int>
	{
		var m = new Map<String, Int>();
		for (w in ["if", "else", "for", "while", "do", "switch", "case", "default", "return", "break", "continue", "try", "catch", "throw"])
			m.set(w, CodeTheme.SYN_CONTROL);
		for (w in [
			"abstract", "cast", "class", "dynamic", "enum", "extends", "extern", "final", "function", "implements", "import", "in", "inline", "interface",
			"macro", "new", "override", "package", "private", "public", "static", "typedef", "untyped", "using", "var", "null", "true", "false", "this",
			"super", "is"
		])
			m.set(w, CodeTheme.SYN_KEYWORD);
		return m;
	}

	public static function tokenize(text:String, kind:String):Array<Int>
	{
		if (text == null || text.length == 0) return [];
		return switch (kind)
		{
			case "haxe": tokenizeHaxe(text);
			case "json": tokenizeJson(text);
			default: [];
		};
	}

	static inline function at(t:String, i:Int):Int
		return StringTools.fastCodeAt(t, i);

	static inline function add(out:Array<Int>, s:Int, e:Int, color:Int):Void
	{
		out.push(s);
		out.push(e);
		out.push(color);
	}

	static inline function isIdentStart(c:Int):Bool
		return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;

	static inline function isDigit(c:Int):Bool
		return c >= 48 && c <= 57;

	static inline function isIdentPart(c:Int):Bool
		return isIdentStart(c) || isDigit(c);

	static function tokenizeHaxe(t:String):Array<Int>
	{
		var out:Array<Int> = [];
		var n = t.length;
		var i = 0;
		while (i < n)
		{
			var c = at(t, i);
			var next = i + 1 < n ? at(t, i + 1) : 0;
			if (c == 47 && next == 47) // //
			{
				var s = i;
				while (i < n && at(t, i) != 10) i++;
				add(out, s, i, CodeTheme.SYN_COMMENT);
			}
			else if (c == 47 && next == 42) // /* */
			{
				var s = i;
				i += 2;
				while (i < n && !(at(t, i) == 42 && i + 1 < n && at(t, i + 1) == 47)) i++;
				i = i + 2 > n ? n : i + 2;
				add(out, s, i, CodeTheme.SYN_COMMENT);
			}
			else if (c == 34 || c == 39) // " '
			{
				var s = i;
				var q = c;
				i++;
				while (i < n)
				{
					var d = at(t, i);
					if (d == 92)
					{
						i += 2;
						continue;
					}
					if (d == q)
					{
						i++;
						break;
					}
					if (d == 10 && q == 34) break;
					i++;
				}
				if (i > n) i = n;
				add(out, s, i, CodeTheme.SYN_STRING);
			}
			else if (c == 35 && next != 0 && isIdentStart(next)) // #if #else #end
			{
				var s = i;
				i++;
				while (i < n && isIdentPart(at(t, i))) i++;
				add(out, s, i, CodeTheme.SYN_PREPROC);
			}
			else if (c == 64) // @:meta
			{
				var s = i;
				i++;
				if (i < n && at(t, i) == 58) i++;
				while (i < n && isIdentPart(at(t, i))) i++;
				add(out, s, i, CodeTheme.SYN_META);
			}
			else if (isDigit(c))
			{
				var s = i;
				if (c == 48 && (next == 120 || next == 88))
				{
					i += 2;
					while (i < n && (isDigit(at(t, i)) || (at(t, i) >= 97 && at(t, i) <= 102) || (at(t, i) >= 65 && at(t, i) <= 70))) i++;
				}
				else
				{
					while (i < n && (isDigit(at(t, i)) || at(t, i) == 46 || at(t, i) == 101 || at(t, i) == 69)) i++;
				}
				add(out, s, i, CodeTheme.SYN_NUMBER);
			}
			else if (isIdentStart(c))
			{
				var s = i;
				while (i < n && isIdentPart(at(t, i))) i++;
				var word = t.substring(s, i);
				var color = haxeWords.get(word);
				if (color == null)
				{
					if (c >= 65 && c <= 90) color = CodeTheme.SYN_TYPE;
					else
					{
						var j = i;
						while (j < n && (at(t, j) == 32 || at(t, j) == 9)) j++;
						if (j < n && at(t, j) == 40) color = CodeTheme.SYN_FUNC;
					}
				}
				if (color != null) add(out, s, i, color);
			}
			else
				i++;
		}
		return out;
	}

	static function tokenizeJson(t:String):Array<Int>
	{
		var out:Array<Int> = [];
		var n = t.length;
		var i = 0;
		while (i < n)
		{
			var c = at(t, i);
			if (c == 34)
			{
				var s = i;
				i++;
				while (i < n)
				{
					var d = at(t, i);
					if (d == 92)
					{
						i += 2;
						continue;
					}
					i++;
					if (d == 34 || d == 10) break;
				}
				if (i > n) i = n;
				var j = i;
				while (j < n && (at(t, j) == 32 || at(t, j) == 9 || at(t, j) == 10 || at(t, j) == 13)) j++;
				add(out, s, i, j < n && at(t, j) == 58 ? CodeTheme.SYN_KEY : CodeTheme.SYN_STRING);
			}
			else if (isDigit(c) || (c == 45 && i + 1 < n && isDigit(at(t, i + 1))))
			{
				var s = i;
				i++;
				while (i < n && (isDigit(at(t, i)) || at(t, i) == 46 || at(t, i) == 101 || at(t, i) == 69 || at(t, i) == 43 || at(t, i) == 45)) i++;
				add(out, s, i, CodeTheme.SYN_NUMBER);
			}
			else if (isIdentStart(c))
			{
				var s = i;
				while (i < n && isIdentPart(at(t, i))) i++;
				var word = t.substring(s, i);
				if (word == "true" || word == "false" || word == "null") add(out, s, i, CodeTheme.SYN_KEYWORD);
			}
			else
				i++;
		}
		return out;
	}
}
