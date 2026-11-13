package funky.core;

#if (!nme && !flash)
import funky.backend.shaders.CustomShader;
#end
import funky.scripting.Script;

/** Script de una noteskin (data/noteSkin.hx). Todo lo generico esta en `Script`; aca solo lo propio de las skins. */
class NoteSkinScript extends Script
{
	var skin:NoteSkin;

	public function new(name:String, source:String, skin:NoteSkin)
	{
		super(name, "NoteSkin " + skin.id, makeGlobals(skin), new Map<String, Dynamic>(), new Map<String, Dynamic>(), skin);
		this.skin = skin;

		interp.variables.set("shader", makeShader);
		interp.variables.set("createShader", makeShader);
		interp.variables.set("setShader", function(sprite:Dynamic, name:String):Dynamic
		{
			var s = makeShader(name);
			if (sprite != null) sprite.shader = s;
			return s;
		});
		interp.variables.set("clearShader", function(sprite:Dynamic):Void
		{
			if (sprite != null) sprite.shader = null;
		});

		parse(source);
	}

	override function onLoaded():Void
	{
		if (exists("onLoad")) call("onLoad");
		else if (exists("create")) call("create");
		else call("new");
	}

	public function makeShader(name:String):Dynamic
	{
		#if (!nme && !flash)
		var local = skin.shaderSource(name);
		if (local != null) return new NoteSkinShader(local, null, name);
		return new CustomShader(name);
		#else
		Log.warn('[NoteSkin ' + skin.id + '] los shaders no estan disponibles en este target: ' + name);
		return null;
		#end
	}

	override function importRoots():Array<String>
		return ["noteskins/" + skin.id + "/source", "noteskins/" + skin.id];

	override function readSource(file:String):Null<String>
		return Addons.getText(file);

	static function makeGlobals(skin:NoteSkin):Map<String, Dynamic>
	{
		var globals = Script.commonGlobals();

		globals.set("skin", skin);
		globals.set("NoteSkin", NoteSkin);
		globals.set("NoteSkinScript", NoteSkinScript);
		#if (!nme && !flash)
		globals.set("NoteSkinShader", NoteSkinShader);
		globals.set("CustomShader", CustomShader);
		globals.set("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
		#end
		globals.set("NoteRGBShader", NoteRGBShader);

		return globals;
	}
}
