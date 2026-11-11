package funky.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;

class CrashState extends FlxState
{
	var report:String;
	var savedPath:String;
	var message:String;

	var buttons:Array<{box:FlxSprite, label:FlxText, action:Void->Void}> = [];
	var copyLabel:FlxText;

	public function new(message:String, report:String, savedPath:String)
	{
		super();
		this.message = message;
		this.report = report;
		this.savedPath = savedPath;
	}

	override public function create():Void
	{
		super.create();
		FlxG.mouse.visible = true;
		bgColor = 0xFF14000A;

		var margin = 28;
		var w = FlxG.width - margin * 2;

		var title = new FlxText(margin, 18, w, "Funky Maker - ocurrio un error", 30);
		title.color = 0xFFFF5555;
		add(title);

		var head = new FlxText(margin, 66, w, clip(message, 300), 17);
		head.color = FlxColor.WHITE;
		add(head);

		var body = new FlxText(margin, 66 + head.height + 14, w, clip(stackOf(report), 1400), 13);
		body.color = 0xFFC8C8C8;
		add(body);

		var where = savedPath != null && savedPath != "" ? "Reporte completo guardado en:\n" + savedPath : "No se pudo guardar el reporte en disco (esta todo arriba).";
		var foot = new FlxText(margin, FlxG.height - 150, w, where, 13);
		foot.color = 0xFFFFD27F;
		add(foot);

		var bw = Std.int(Math.min(300, (w - 40) / 3));
		var y = FlxG.height - 78;
		addButton(margin, y, bw, "Volver al menu  [ENTER]", 0xFF2E7D32, goMenu);
		addButton(margin + bw + 20, y, bw, "Copiar reporte  [C]", 0xFF1565C0, copyReport);
		addButton(margin + (bw + 20) * 2, y, bw, "Salir  [ESC]", 0xFFB71C1C, quit);
	}

	function addButton(x:Float, y:Float, w:Int, text:String, color:FlxColor, action:Void->Void):Void
	{
		var box = new FlxSprite(x, y);
		box.makeGraphic(w, 56, color);
		add(box);

		var label = new FlxText(x, y + 17, w, text, 16);
		label.alignment = CENTER;
		label.color = FlxColor.WHITE;
		add(label);

		if (text.indexOf("Copiar") == 0) copyLabel = label;
		buttons.push({box: box, label: label, action: action});
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.ENTER) goMenu();
		else if (FlxG.keys.justPressed.C) copyReport();
		else if (FlxG.keys.justPressed.ESCAPE) quit();

		if (FlxG.mouse.justReleased)
			for (b in buttons)
				if (FlxG.mouse.overlaps(b.box))
				{
					b.action();
					break;
				}
	}

	function goMenu():Void
	{
		FlxG.switchState(new MainMenuState());
	}

	function copyReport():Void
	{
		try
		{
			lime.system.Clipboard.text = report;
			if (copyLabel != null) copyLabel.text = "Copiado";
		}
		catch (_:Dynamic)
		{
			if (copyLabel != null) copyLabel.text = "No se pudo copiar";
		}
	}

	function quit():Void
	{
		#if sys
		Sys.exit(1);
		#else
		openfl.system.System.exit(1);
		#end
	}

	static function stackOf(report:String):String
	{
		var i = report.indexOf("Stack Trace:");
		return i >= 0 ? report.substr(i) : report;
	}

	static function clip(text:String, max:Int):String
		return text.length <= max ? text : text.substr(0, max) + " ...";
}
