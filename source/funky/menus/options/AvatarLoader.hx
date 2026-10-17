package funky.menus.options;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import funky.core.Log;
import funky.core.Paths;
import openfl.Assets as OpenFlAssets;
import openfl.display.BitmapData;
import openfl.geom.Matrix;

class AvatarLoader extends FlxSpriteGroup
{
	static var cache:Map<String, BitmapData> = [];
	static var failed:Map<String, Bool> = [];

	public var avatar:FlxSprite;
	public var border:FlxSprite;

	public var avatarSize:Int = 64;
	public var borderWidth:Int = 3;
	public var borderColor:Int = FlxColor.WHITE;

	var disposed:Bool = false;

	public function new(
		url:Null<String> = null,
		fallbackAsset:Null<String> = null,
		size:Int = 64,
		borderColor:Int = FlxColor.WHITE,
		borderWidth:Int = 3,
		x:Float = 0,
		y:Float = 0
	)
	{
		super(x, y);

		avatarSize = size;
		this.borderColor = borderColor;
		this.borderWidth = Std.int(Math.max(1, Math.min(borderWidth, size / 2)));

		border = new FlxSprite();
		avatar = new FlxSprite();

		add(border);
		add(avatar);

		updateBorder();
		apply(url, fallbackAsset, size, function() return disposed);
	}

	public function apply(
		url:Null<String>,
		fallbackAsset:Null<String>,
		size:Int,
		isDead:Void->Bool
	):Void
	{
		showFallback(fallbackAsset, size);

		if (url == null || failed.exists(url))
			return;

		if (cache.exists(url))
		{
			show(cache.get(url), size);
			return;
		}

		BitmapData.loadFromFile(url).onComplete(bitmap ->
		{
			if (bitmap == null)
				return;

			cache.set(url, bitmap);

			if (!isDead())
				show(bitmap, size);
		}).onError(error ->
		{
			failed.set(url, true);
			Log.warn("[AvatarLoader] no se pudo bajar el avatar, se usa el fallback: " + error);
		});
	}

	function showFallback(asset:Null<String>, size:Int):Void
	{
		var path:Null<String> = null;

		if (asset != null)
		{
			var plain = ~/[^a-z0-9]/g.replace(asset.toLowerCase(), "");

			for (candidate in [asset, plain])
			{
				var option = Paths.image("credits/" + candidate);

				if (OpenFlAssets.exists(option))
				{
					path = option;
					break;
				}
			}
		}

		if (path == null)
			path = Paths.image("icon");

		if (OpenFlAssets.exists(path))
			avatar.loadGraphic(makeCircle(OpenFlAssets.getBitmapData(path), getInnerSize()));
		else
			avatar.loadGraphic(makeCircle(
				new BitmapData(size, size, true, 0xFF55555F),
				getInnerSize()
			));

		fit(avatar, getInnerSize());
	}

	function show(bitmap:BitmapData, size:Int):Void
	{
		if (disposed || bitmap == null)
			return;

		avatar.loadGraphic(makeCircle(bitmap.clone(), getInnerSize()));
		fit(avatar, getInnerSize());
	}

	function fit(sprite:FlxSprite, size:Int):Void
	{
		sprite.setGraphicSize(size, size);
		sprite.updateHitbox();
	}

	function getInnerSize():Int
	{
		return Std.int(Math.max(1, avatarSize - borderWidth * 2));
	}

	function updateBorder():Void
	{
		border.loadGraphic(makeBorder(avatarSize, borderWidth, borderColor));
		border.setGraphicSize(avatarSize, avatarSize);
		border.updateHitbox();

		avatar.setPosition(borderWidth, borderWidth);
	}

	static function makeCircle(source:BitmapData, size:Int):BitmapData
	{
		var result = new BitmapData(size, size, true, 0x00000000);

		if (source.width > 0 && source.height > 0)
		{
			var scale = Math.max(size / source.width, size / source.height);
			var matrix = new Matrix();

			matrix.scale(scale, scale);
			matrix.translate(
				(size - source.width * scale) / 2,
				(size - source.height * scale) / 2
			);

			result.draw(source, matrix, null, null, null, true);
		}

		var center = size / 2;
		var radius = center * center;

		for (py in 0...size)
		{
			for (px in 0...size)
			{
				var dx = px + 0.5 - center;
				var dy = py + 0.5 - center;

				if (dx * dx + dy * dy > radius)
					result.setPixel32(px, py, 0x00000000);
			}
		}

		return result;
	}

	static function makeBorder(size:Int, width:Int, color:Int):BitmapData
	{
		var result = new BitmapData(size, size, true, 0x00000000);
		var center = size / 2;
		var outer = center * center;
		var inner = Math.max(0, center - width);
		var innerRadius = inner * inner;

		for (py in 0...size)
		{
			for (px in 0...size)
			{
				var dx = px + 0.5 - center;
				var dy = py + 0.5 - center;
				var distance = dx * dx + dy * dy;

				if (distance <= outer && distance >= innerRadius)
					result.setPixel32(px, py, color);
			}
		}

		return result;
	}

	public function setBorderColor(color:Int):Void
	{
		borderColor = color;
		updateBorder();
	}

	override public function destroy():Void
	{
		disposed = true;
		super.destroy();
	}
}
