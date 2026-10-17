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
}
