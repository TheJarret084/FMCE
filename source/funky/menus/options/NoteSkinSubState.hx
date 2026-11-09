package funky.menus.options;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.util.FlxColor;
import funky.core.ClientPrefs;
import funky.core.CoolUtil;
import funky.core.KeyBinds;
import funky.core.NoteRGBShader;
import funky.core.NoteSkin;
import funky.core.Paths;
import funky.core.TouchNav;
import funkin.backend.utils.TranslationUtil as TU;

using StringTools;

/** Mini substate de skins de notas: lista a la izquierda, preview animada de los 4 carriles a la derecha. */
class NoteSkinSubState extends FlxSubState
{
	static var font:Null<String> = null;
	static var fontLoaded:Bool = false;

	static inline var ROW_H:Float = 54;
	static inline var PREVIEW_SIZE:Float = 96;

	var skins:Array<String> = [];
	var selected:Int = 0;
	var labels:Array<FlxText> = [];

	var notes:Array<FlxSprite> = [];
	var receptors:Array<FlxSprite> = [];
	var previewId:String = "";
	var previewX:Float = 0;
	var previewY:Float = 0;
	var previewSpacing:Float = 0;
	var previewT:Float = 0;

	var title:FlxText;
	var hint:FlxText;
	var author:FlxText;
	var backButton:FlxObject;
	var closed:Bool = false;

	override public function create():Void
	{
		super.create();

		if (!fontLoaded)
		{
			fontLoaded = true;
			font = Paths.fontPath("PhantomMuff.ttf");
		}

		var dim = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xE6000000);
		dim.scrollFactor.set();
		add(dim);

		title = new FlxText(BackButton.WIDTH, 8, FlxG.width - BackButton.WIDTH - 14, "", 32);
		title.setFormat(font, 32, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 1.5;
		title.text = TU.translate("options.noteSkin.title", null, "NOTE SKINS");
		add(title);

		hint = new FlxText(BackButton.WIDTH, 0, FlxG.width - BackButton.WIDTH - 14, "", 18);
		hint.setFormat(font, 18, 0xFFD8D8E0, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.borderSize = 1.5;
		hint.text = TU.translate("options.noteSkin.hint", null, "ENTER elige  |  ESC vuelve");
		hint.y = title.y + title.height + 2;
		add(hint);

		previewX = FlxG.width * 0.58;
		previewY = FlxG.height * 0.46;
		previewSpacing = Math.min(120, Math.max(64, (FlxG.width - previewX - 30) / 4));

		author = new FlxText(previewX - 30, previewY + 150, previewSpacing * 4 + 60, "", 20);
		author.setFormat(font, 20, 0xFF9AA4B0, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		author.borderSize = 1.5;
		add(author);

		skins = NoteSkin.list();
		var current = ClientPrefs.getNoteSkin();
		selected = skins.indexOf(current);
		if (selected < 0) selected = 0;

		for (i in 0...skins.length)
		{
			var label = new FlxText(0, 0, 0, "", 36);
			label.setFormat(font, 36, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			label.borderSize = 2;
			labels.push(label);
			add(label);
		}

		backButton = BackButton.place();
		add(backButton);

		refresh();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		previewT += elapsed;
		var span = 220.0;
		for (i in 0...notes.length)
		{
			var note = notes[i];
			if (note == null) continue;
			note.y = previewY - span + ((previewT * 160 + i * 55) % span);
		}

		if (closed) return;

		if (KeyBinds.justPressed(KeyBinds.BACK))
		{
			closePicker();
			return;
		}

		if (skins.length > 1)
		{
			if (KeyBinds.justPressed(KeyBinds.UP)) move(-1);
			if (KeyBinds.justPressed(KeyBinds.DOWN)) move(1);
		}

		if (KeyBinds.justPressed(KeyBinds.ACCEPT)) choose();

		var tapped = TouchNav.rowTapped(labels);
		if (tapped >= 0)
		{
			if (tapped == selected) choose();
			else
			{
				selected = tapped;
				CoolUtil.playMenuSound("scroll", 0.6);
				refresh();
			}
		}
		else if (BackButton.clicked(backButton)) closePicker();
	}

	function move(dir:Int):Void
	{
		if (skins.length == 0) return;
		selected = (selected + dir + skins.length) % skins.length;
		CoolUtil.playMenuSound("scroll", 0.6);
		refresh();
	}

	function choose():Void
	{
		if (skins.length == 0) return;
		ClientPrefs.setNoteSkin(skins[selected]);
		ClientPrefs.save();
		CoolUtil.playMenuSound("confirm", 0.7);
		closePicker();
	}

	function closePicker():Void
	{
		if (closed) return;
		closed = true;
		close();
	}

	function refresh():Void
	{
		if (skins.length == 0) return;

		var cy = FlxG.height * 0.5;
		for (i in 0...labels.length)
		{
			var off = i - selected;
			var label = labels[i];
			label.text = (i == selected ? "> " : "  ") + NoteSkin.displayName(skins[i]);
			label.x = 80 - Math.pow(Math.abs(off), 1.4) * 10;
			label.y = cy + off * ROW_H - 18;
			label.alpha = off == 0 ? 1 : 0.55;
			label.visible = Math.abs(off) <= 6;
		}

		var id = skins[selected];
		if (previewId != id)
		{
			previewId = id;
			buildPreview(NoteSkin.get(id));
		}
	}

	function buildPreview(skin:NoteSkin):Void
	{
		for (sprite in notes)
		{
			remove(sprite, true);
			sprite.destroy();
		}
		for (sprite in receptors)
		{
			remove(sprite, true);
			sprite.destroy();
		}
		notes = [];
		receptors = [];

		author.text = skin.author;

		var frames = skin.frames();

		for (dir in 0...4)
		{
			var laneX = previewX + dir * previewSpacing + (previewSpacing - PREVIEW_SIZE) * 0.5;

			var receptor = new FlxSprite();
			if (frames != null)
			{
				receptor.frames = frames;
				receptor.animation.addByPrefix("idle", skin.animFor("receptor", dir), 24, false);
				receptor.animation.play("idle");
			}
			else receptor.makeGraphic(Std.int(PREVIEW_SIZE), Std.int(PREVIEW_SIZE), 0xFF888888);
			receptor.setGraphicSize(Std.int(PREVIEW_SIZE));
			receptor.updateHitbox();
			skin.applyTo(receptor, dir, true, 4);
			receptor.setPosition(laneX, previewY);
			add(receptor);
			receptors.push(receptor);

			var note = new FlxSprite();
			if (frames != null)
			{
				note.frames = frames;
				note.animation.addByPrefix("note", skin.animFor("note", dir), 24, false);
				note.animation.play("note");
			}
			else note.makeGraphic(Std.int(PREVIEW_SIZE), Std.int(PREVIEW_SIZE), 0xFFFFFFFF);
			note.setGraphicSize(Std.int(PREVIEW_SIZE));
			note.updateHitbox();
			skin.applyTo(note, dir, false, 4);
			note.setPosition(laneX, previewY - 220);
			add(note);
			notes.push(note);
		}
	}
}
