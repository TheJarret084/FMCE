package advanced.ui;


import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import haxe.Json;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.ui.Keyboard;

/** Inspector visual de JSON. Los objetos/arrays se navegan y los valores se editan en un dialogo. */
class JsonInspector extends FlxSpriteGroup
{
	static inline var HEADER_H:Int = 48;
	static inline var ROW_H:Int = 58;
	static inline var PAD:Int = 22;
	static inline var BG:Int = 0xFF0A0D12;
	static inline var PANEL:Int = 0xFF12171D;
	static inline var CARD:Int = 0xFF192026;
	static inline var CARD_HOVER:Int = 0xFF202A31;
	static inline var BORDER:Int = 0xFF2B343C;
	static inline var TEXT:Int = 0xFFE7EAED;
	static inline var MUTED:Int = 0xFF89939C;
	static inline var ACCENT:Int = 0xFF54D6C5;
	static inline var NUMBER:Int = 0xFF77B8FF;
	static inline var STRING:Int = 0xFFFFD27D;
	static inline var BOOL:Int = 0xFFB991FF;
	static inline var NULLC:Int = 0xFF9AA3AA;

	public var changed:Void->Void;
	public var content(default, null):String = "";

	var root:Dynamic;
	var current:Dynamic;
	var parentStack:Array<Dynamic> = [];
	var keyStack:Array<String> = [];
	var rows:Array<FlxSprite> = [];
	var rowLabels:Array<FlxText> = [];
	var rowTypes:Array<FlxText> = [];
	var emptyText:FlxText;
	var breadcrumb:FlxText;
	var title:FlxText;
	var dialog:FlxSpriteGroup;
	var dialogValue:TextField;
	var dialogKey:TextField;
	var dialogType:FlxText;
	var dialogPathKey:String = "";
	var dialogParent:Dynamic;
	var dialogOldValue:Dynamic;
	var dialogNewEntry:Bool = false;
	var dialogTypeIndex:Int = 0;
	var dialogOpen:Bool = false;

	public function new(json:String, ?onChanged:Void->Void)
	{
		super();
		changed = onChanged != null ? onChanged : function() {};
		buildChrome();
		load(json);
	}

	public function load(json:String):Void
	{
		content = json == null ? "" : json;
		try
		{
			root = Json.parse(content);
			current = root;
			parentStack = [];
			keyStack = [];
			refresh();
		}
		catch (e:Dynamic)
		{
			root = null;
			current = null;
			clearRows();
			showInvalid(Std.string(e));
		}
	}

	public function getJson():String
		return root == null ? content : Json.stringify(root, null, "  ");

	public function isValid():Bool
		return root != null;

	function refresh():Void
	{
		clearRows();
		if (breadcrumb != null) breadcrumb.text = breadcrumbText();
		if (current == null)
		{
			showInvalid("JSON invalido");
			return;
		}

		var entries:Array<{key:String, value:Dynamic}> = [];
		if (Std.isOfType(current, Array))
		{
			var array:Array<Dynamic> = cast current;
			for (i in 0...array.length) entries.push({key: "[" + i + "]", value: array[i]});
		}
		else
		{
			for (key in Reflect.fields(current)) entries.push({key: key, value: Reflect.field(current, key)});
		}

		if (entries.length == 0)
		{
			emptyText = text(0, HEADER_H + 70, FlxG.width, "Este objeto esta vacio", 18, MUTED);
			emptyText.alignment = FlxTextAlign.CENTER;
			add(emptyText);
		}

		for (i in 0...entries.length) addRow(i, entries[i].key, entries[i].value);
	}

	function buildChrome():Void
	{
		add(rect(0, 0, FlxG.width, FlxG.height, BG));
		add(rect(0, 0, FlxG.width, HEADER_H, PANEL));
		add(rect(0, HEADER_H - 1, FlxG.width, 1, BORDER));

		title = text(20, 13, 190, "JSON Inspector", 18, TEXT);
		add(title);
		breadcrumb = text(225, 16, FlxG.width - 320, breadcrumbText(), 13, MUTED);
		add(breadcrumb);
		var addButton = text(FlxG.width - 72, 8, 45, "+", 30, ACCENT);
		addButton.alignment = FlxTextAlign.CENTER;
		add(addButton);
	}

	function addRow(index:Int, key:String, value:Dynamic):Void
	{
		var y = HEADER_H + index * ROW_H + 8;
		var card = rect(PAD, y, FlxG.width - PAD * 2, ROW_H - 8, CARD);
		add(card);
		rows.push(card);

		var keyText = text(PAD + 18, y + 9, FlxG.width * 0.52, key, 16, TEXT);
		add(keyText);
		rowLabels.push(keyText);

		var valuePreview = preview(value);
		var previewText = text(PAD + 18, y + 31, FlxG.width * 0.56, valuePreview, 12, MUTED);
		add(previewText);

		var typeText = text(FlxG.width - 190, y + 17, 120, typeName(value), 11, typeColor(value));
		typeText.alignment = FlxTextAlign.CENTER;
		add(typeText);
		rowTypes.push(typeText);

		var arrow = text(FlxG.width - 55, y + 13, 28, isContainer(value) ? "›" : "⋮", 26, MUTED);
		arrow.alignment = FlxTextAlign.CENTER;
		add(arrow);
	}

	function clearRows():Void
	{
		for (item in rows) remove(item, true);
		for (item in rowLabels) remove(item, true);
		for (item in rowTypes) remove(item, true);
		if (emptyText != null) remove(emptyText, true);
		rows = [];
		rowLabels = [];
		rowTypes = [];
		emptyText = null;
	}

	function showInvalid(reason:String):Void
	{
		add(rect(PAD, HEADER_H + 12, FlxG.width - PAD * 2, 90, CARD));
		var t = text(PAD + 18, HEADER_H + 29, FlxG.width - PAD * 4, "JSON invalido", 18, 0xFFFF7B7B);
		add(t);
		var r = text(PAD + 18, HEADER_H + 58, FlxG.width - PAD * 4, reason, 12, MUTED);
		add(r);
	}

	function breadcrumbText():String
	{
		if (keyStack.length == 0) return "root";
		return "root  ›  " + keyStack.join("  ›  ");
	}

	function isContainer(value:Dynamic):Bool
		return Std.isOfType(value, Array) || (value != null && Reflect.isObject(value) && !Std.isOfType(value, String));

	function typeName(value:Dynamic):String
	{
		if (value == null) return "NULO";
		if (Std.isOfType(value, Bool)) return "BOOLEANO";
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return "NÚMERO";
		if (Std.isOfType(value, String)) return "TEXTO";
		if (Std.isOfType(value, Array)) return "ARRAY";
		return "OBJETO";
	}

	function typeColor(value:Dynamic):Int
	{
		return switch (typeName(value))
		{
			case "NÚMERO": NUMBER;
			case "TEXTO": STRING;
			case "BOOLEANO": BOOL;
			case "NULO": NULLC;
			default: ACCENT;
		}
	}

	function preview(value:Dynamic):String
	{
		if (value == null) return "null";
		if (Std.isOfType(value, String)) return '"' + Std.string(value) + '"';
		if (Std.isOfType(value, Bool)) return value ? "true" : "false";
		if (Std.isOfType(value, Array)) return (cast value:Array<Dynamic>).length + " elementos";
		if (Reflect.isObject(value)) return Reflect.fields(value).length + " objetos";
		return Std.string(value);
	}

	function valueAt(key:String):Dynamic
	{
		if (Std.isOfType(current, Array))
			return (cast current:Array<Dynamic>)[Std.parseInt(key.substr(1, key.length - 2))];
		return Reflect.field(current, key);
	}

	function setValue(key:String, value:Dynamic):Void
	{
		if (Std.isOfType(current, Array))
			(cast current:Array<Dynamic>)[Std.parseInt(key.substr(1, key.length - 2))] = value;
		else
			Reflect.setField(current, key, value);
	}

	function deleteValue(key:String):Void
	{
		if (Std.isOfType(current, Array))
		{
			var array:Array<Dynamic> = cast current;
			array.splice(Std.parseInt(key.substr(1, key.length - 2)), 1);
		}
		else Reflect.deleteField(current, key);
	}

	function openValue(key:String):Void
	{
		var value = valueAt(key);
		if (isContainer(value))
		{
			parentStack.push(current);
			keyStack.push(key);
			current = value;
			refresh();
		}
		else openDialog(key, value);
	}

	function openDialog(key:String, value:Dynamic):Void
	{
		closeDialog();
		dialogOpen = true;
		dialogNewEntry = false;
		dialogPathKey = key;
		dialogParent = current;
		dialogOldValue = value;
		dialogTypeIndex = typeIndex(value);

		dialog = new FlxSpriteGroup();
		add(dialog);
		dialog.add(rect(25, 105, FlxG.width - 50, 390, 0xFF202A28));
		dialog.add(text(55, 140, FlxG.width - 110, 'Editar "$key"', 28, TEXT));
		dialog.add(text(55, 198, FlxG.width - 110, "Clave", 12, MUTED));

		dialogKey = input(key, 55, 216, FlxG.width - 110, 52);
		FlxG.stage.addChild(dialogKey);
		dialog.add(text(55, 285, 90, "Tipo", 12, MUTED));
		dialogType = text(55, 307, 190, typeName(value), 16, typeColor(value));
		dialog.add(dialogType);
	var change = text(175, 306, 100, "Cambiar", 16, ACCENT);
	dialog.add(change);

		dialogValue = input(valueToText(value), 55, 350, FlxG.width - 110, 58);
		FlxG.stage.addChild(dialogValue);

		dialog.add(text(390, 438, 95, "Cancelar", 15, MUTED));
		dialog.add(text(505, 438, 90, "Guardar", 15, ACCENT));
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onDialogKey);
	}

	function openNewEntry():Void
	{
		if (Std.isOfType(current, Array)) return;
		closeDialog();
		dialogOpen = true;
		dialogNewEntry = true;
		dialogPathKey = "";
		dialogParent = current;
		dialogOldValue = "";
		dialogTypeIndex = 0;

		dialog = new FlxSpriteGroup();
		add(dialog);
		dialog.add(rect(25, 105, FlxG.width - 50, 390, 0xFF202A28));
		dialog.add(text(55, 140, FlxG.width - 110, "Nuevo valor", 28, TEXT));
		dialog.add(text(55, 198, FlxG.width - 110, "Clave", 12, MUTED));
		dialogKey = input("newKey", 55, 216, FlxG.width - 110, 52);
		FlxG.stage.addChild(dialogKey);
		dialog.add(text(55, 285, 90, "Tipo", 12, MUTED));
		dialogType = text(55, 307, 190, "TEXTO", 16, STRING);
		dialog.add(dialogType);
		dialog.add(text(175, 306, 100, "Cambiar", 16, ACCENT));
		dialogValue = input("", 55, 350, FlxG.width - 110, 58);
		FlxG.stage.addChild(dialogValue);
		dialog.add(text(390, 438, 95, "Cancelar", 15, MUTED));
		dialog.add(text(505, 438, 90, "Guardar", 15, ACCENT));
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onDialogKey);
	}

	function typeIndex(value:Dynamic):Int
	{
		if (value == null) return 3;
		if (Std.isOfType(value, Bool)) return 2;
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float)) return 1;
		return 0;
	}

	function valueToText(value:Dynamic):String
	{
		if (value == null) return "null";
		if (Std.isOfType(value, Bool)) return value ? "true" : "false";
		return Std.string(value);
	}

	function applyDialog():Void
	{
		var newKey = StringTools.trim(dialogKey.text);
		if (newKey == "") newKey = dialogPathKey;
		var value:Dynamic = null;
		switch (dialogTypeIndex)
		{
			case 0: value = dialogValue.text;
			case 1:
				var parsed = Std.parseFloat(StringTools.trim(dialogValue.text));
				if (Math.isNaN(parsed)) return;
				value = parsed;
			case 2:
				value = StringTools.trim(dialogValue.text).toLowerCase() == "true";
			case 3: value = null;
		}

		if (newKey == "" || newKey == "newKey" && dialogNewEntry) return;
		if (dialogNewEntry)
			Reflect.setField(dialogParent, newKey, value);
		else if (newKey != dialogPathKey && !Std.isOfType(dialogParent, Array))
		{
			Reflect.deleteField(dialogParent, dialogPathKey);
			Reflect.setField(dialogParent, newKey, value);
		}
		else setValue(dialogPathKey, value);

		content = getJson();
		changed();
		closeDialog();
		refresh();
	}

	function cycleType():Void
	{
		dialogTypeIndex = (dialogTypeIndex + 1) % 4;
		var fake:Dynamic = switch (dialogTypeIndex)
		{
			case 0: "";
			case 1: 1;
			case 2: true;
			default: null;
		};
		dialogType.text = typeName(fake);
		dialogType.color = typeColor(fake);
		dialogValue.text = valueToText(fake);
	}

	function closeDialog():Void
	{
		if (!dialogOpen) return;
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onDialogKey);
		if (dialog != null) remove(dialog, true);
		if (dialogValue != null && dialogValue.parent != null) dialogValue.parent.removeChild(dialogValue);
		if (dialogKey != null && dialogKey.parent != null) dialogKey.parent.removeChild(dialogKey);
		dialog = null;
		dialogValue = null;
		dialogKey = null;
		dialogOpen = false;
	}

	function onDialogKey(event:KeyboardEvent):Void
	{
		if (!dialogOpen) return;
		if (event.keyCode == Keyboard.ESCAPE)
		{
			event.preventDefault();
			closeDialog();
			return;
		}
		if (event.keyCode == Keyboard.ENTER && event.ctrlKey)
		{
			event.preventDefault();
			applyDialog();
		}
	}

	function rect(x:Float, y:Float, w:Float, h:Float, color:Int):FlxSprite
		return new FlxSprite(x, y).makeGraphic(Std.int(w), Std.int(h), color);

	function text(x:Float, y:Float, w:Float, value:String, size:Int, color:Int):FlxText
	{
		var t = new FlxText(x, y, w, value, size);
		t.color = color;
		return t;
	}

	function input(value:String, x:Float, y:Float, w:Float, h:Float):TextField
	{
		var field = new TextField();
		field.type = TextFieldType.INPUT;
		field.multiline = false;
		field.background = true;
		field.backgroundColor = 0xFF18201F;
		field.border = true;
		field.borderColor = BORDER;
		field.textColor = TEXT;
		field.defaultTextFormat = new TextFormat("Arial", 17, TEXT);
		field.text = value;
		field.x = x;
		field.y = y;
		field.width = w;
		field.height = h;
		return field;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (dialogOpen)
		{
			if (FlxG.mouse.justPressed)
			{
				if (FlxG.mouse.y >= 300 && FlxG.mouse.y <= 335 && FlxG.mouse.x >= 170 && FlxG.mouse.x <= 290)
					cycleType();
				else if (FlxG.mouse.y >= 425 && FlxG.mouse.y <= 475 && FlxG.mouse.x >= 370 && FlxG.mouse.x <= 495)
					closeDialog();
				else if (FlxG.mouse.y >= 425 && FlxG.mouse.y <= 475 && FlxG.mouse.x >= 495 && FlxG.mouse.x <= 620)
					applyDialog();
			}
			return;
		}

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.y < HEADER_H && FlxG.mouse.x >= FlxG.width - 90)
			{
				openNewEntry();
				return;
			}
			if (FlxG.mouse.y >= HEADER_H && FlxG.mouse.y < HEADER_H + rows.length * ROW_H + 8)
			{
				var index = Std.int((FlxG.mouse.y - HEADER_H - 8) / ROW_H);
				if (index >= 0 && index < rows.length) openValue(rowKey(index));
			}
			else if (FlxG.mouse.y < HEADER_H && FlxG.mouse.x < 205 && keyStack.length > 0)
			{
				goBack();
			}
		}
	}

	function rowKey(index:Int):String
	{
		if (Std.isOfType(current, Array)) return "[" + index + "]";
		return Reflect.fields(current)[index];
	}

	function goBack():Void
	{
		if (parentStack.length == 0) return;
		current = parentStack.pop();
		keyStack.pop();
		refresh();
	}

	override public function destroy():Void
	{
		closeDialog();
		super.destroy();
	}
}
