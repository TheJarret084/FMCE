package funky.backend.skins;

#if (!nme && !flash)
import funky.backend.shaders.CustomShader;
#end
import funky.scripting.Script;

/** Script de una noteskin (data/hudSkin.hx). Todo lo generico esta en `Script`; aca solo lo propio de las skins. */
class HudSkinScript extends Script
{
	var skin:HudSkin;

	public function new(name:String, source:String, skin:HudSkin)
	{
		super(name, "HudSkin " + skin.id, makeGlobals(skin), new Map<String, Dynamic>(), new Map<String, Dynamic>(), skin);
		this.skin = skin;

		interp.variables.set("shader", makeShader);
		interp.variables.set("createShader", makeShader);
		interp.variables.set("setShader", function(sprite:Dynamic, nameOrShader:Dynamic, ?folder:String):Dynamic
		{
			var s:Dynamic = nameOrShader;
			if (Std.isOfType(nameOrShader, String)) s = makeShader(nameOrShader, folder);
			#if (!nme && !flash)
			HudShaderUtil.set(cast sprite, s);
			#else
			if (sprite != null) sprite.shader = s;
			#end
			return s;
		});
		interp.variables.set("clearShader", function(sprite:Dynamic):Void
		{
			#if (!nme && !flash)
			HudShaderUtil.clear(cast sprite);
			#else
			if (sprite != null) sprite.shader = null;
			#end
		});

		parse(source);
	}

	override function onLoaded():Void
	{
		if (exists("onLoad")) call("onLoad");
		else if (exists("create")) call("create");
		else call("new");
	}

	public function makeShader(name:String, ?folder:String):Dynamic
	{
		#if (!nme && !flash)
		if (folder != null && folder.length > 0) return new CustomShader(name, folder);
		var local = skin.shaderSource(name);
		if (local != null) return new HudSkinShader(local, null, name);
		return new CustomShader(name);
		#else
		Log.warn('[HudSkin ' + skin.id + '] los shaders no estan disponibles en este target: ' + name);
		return null;
		#end
	}

	override function importRoots():Array<String>
		return ["hudskins/" + skin.id + "/source", "hudskins/" + skin.id, "noteskins/" + skin.id + "/source", "noteskins/" + skin.id];

	override function readSource(file:String):Null<String>
		return Addons.getText(file);

	static function makeGlobals(skin:HudSkin):Map<String, Dynamic>
	{
		var globals = Script.commonGlobals();

		globals.set("skin", skin);
		globals.set("HudSkin", HudSkin);
		globals.set("NoteSkin", HudSkin);
		globals.set("HudSkinScript", HudSkinScript);
		#if (!nme && !flash)
		globals.set("HudSkinShader", HudSkinShader);
		globals.set("NoteSkinShader", HudSkinShader);
		globals.set("CustomShader", CustomShader);
		globals.set("FlxRuntimeShader", flixel.addons.display.FlxRuntimeShader);
		#end
		globals.set("HudRGBShader", HudRGBShader);
		globals.set("NoteRGBShader", HudRGBShader);
		#if (!nme && !flash)
		globals.set("HudShaderUtil", HudShaderUtil);
		#end

		return globals;
	}
}
