package advanced.ui;

import funkin.editors.ui.UINumericStepper;

/** `UINumericStepper` que avisa (`onValue`) al confirmar un valor escrito (ENTER o al salir del campo). */
class FieldStepper extends UINumericStepper
{
	public var onValue:Float->Void = null;

	public function new(x:Float, y:Float, value:Float = 0, step:Float = 1, precision:Int = 0, ?min:Float, ?max:Float, w:Int = 180)
	{
		super(x, y, value, step, precision, min, max, w);
		onChange = function(text:String)
		{
			__onChange(text);
			if (onValue != null && !Math.isNaN(Std.parseFloat(text))) onValue(this.value);
		};
	}

	/** Un campo numerico solo recibe digitos, signo y punto (la coma cuenta como punto); lo demas se descarta. */
	override public function onTextInput(text:String):Void
	{
		var clean = "";
		for (i in 0...text.length)
		{
			var c = text.charAt(i);
			if (c == ",") c = ".";
			if ("0123456789-.".indexOf(c) >= 0) clean += c;
		}
		if (clean != "") super.onTextInput(clean);
	}

	/** El texto en composicion (teclados predictivos / IME) no es un valor: se ignora, solo cuenta lo confirmado. */
	override public function onTextEdit(text:String, start:Int, end:Int):Void {}
}
