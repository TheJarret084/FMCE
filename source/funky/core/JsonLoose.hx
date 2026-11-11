package funky.core;

import haxe.Json;

class JsonLoose
{
	public static function parse(raw:String):Dynamic
		return Json.parse(strip(raw));

	public static function strip(raw:String):String
	{
		if (raw.length > 0 && raw.charCodeAt(0) == 0xFEFF) raw = raw.substr(1);

		var out = new StringBuf();
		var inString = false;
		var i = 0;
		var n = raw.length;
		while (i < n)
		{
			var c = raw.charAt(i);
			if (inString)
			{
				out.add(c);
				if (c == "\\" && i + 1 < n)
				{
					out.add(raw.charAt(i + 1));
					i += 2;
					continue;
				}
				if (c == "\"") inString = false;
				i++;
				continue;
			}
			if (c == "\"")
			{
				inString = true;
				out.add(c);
				i++;
				continue;
			}
			if (c == ",")
			{
				var j = i + 1;
				while (j < n && StringTools.isSpace(raw, j)) j++;
				if (j < n && (raw.charAt(j) == "}" || raw.charAt(j) == "]"))
				{
					i++;
					continue;
				}
			}
			out.add(c);
			i++;
		}
		return out.toString();
	}
}
