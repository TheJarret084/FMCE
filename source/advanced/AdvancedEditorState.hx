package advanced;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import haxe.Json;
import haxe.io.Path;
import funky.api.DiscordClient;
import funky.core.KeyBinds;
import funky.core.Log;
import funky.core.Paths;
import funky.core.TransitionHandler;
import funky.scripting.Scripts;
import advanced.ui.code.CodeLang;
import advanced.ui.code.CodeStudio;
import advanced.ui.code.CodeStudioFile;

import sys.FileSystem;
import sys.io.File;

class AdvancedEditorState extends FlxState
{
	var levelName:String;
	var levelDir:String;
	var studio:CodeStudio;
	var chosen:Bool = false;

	public function new(levelName:String)
	{
		super();
		this.levelName = levelName;
		this.levelDir = Path.join([Paths.levelsRoot(), levelName]);
	}

	override public function create():Void
	{
		super.create();
		funky.core.CoolUtil.playEditorSong();
		prepareLevel();

		studio = new CodeStudio(loadFiles(), saveFile, prepareRun, openSpritePreview, createScript, levelName);
		studio.onExit = leave;
		add(studio);

		studio.setCovered(true);

		DiscordClient.customPresence(CodeLang.t("advanced.presenceTitle", null, "Modo Avanzado"), CodeLang.t("advanced.presenceEditing", [levelName], "Editando {0}"), "fmce", "", false);
		TransitionHandler.playIn(this);
	}

	function prepareLevel():Void
	{
		#if sys
		try
		{
			if (!FileSystem.exists(levelDir)) FileSystem.createDirectory(levelDir);
			var data = Path.join([levelDir, "data"]);
			if (!FileSystem.exists(data)) FileSystem.createDirectory(data);
			var scripts = Path.join([levelDir, Scripts.DIR]);
			if (!FileSystem.exists(scripts)) FileSystem.createDirectory(scripts);
		}
		catch (e:Dynamic)
		{
			Log.error('[Advanced] no se pudo preparar ' + levelDir + ': ' + Std.string(e));
		}
		#end
	}

	function loadFiles():Array<CodeStudioFile>
	{
		var result:Array<CodeStudioFile> = [];
		var foundHx:Bool = false;
		#if sys
		collectFiles(levelDir, "", result);
		for (file in result)
			if (file.kind == "haxe") foundHx = true;

		if (!foundHx)
		{
			var path = Path.join([levelDir, Scripts.DIR, "script.hx"]);
			result.push(new CodeStudioFile(Scripts.DIR + "/script.hx", defaultScript(), path, true, "haxe", "", true));
		}
		#end
		result.sort(function(a, b)
		{
			if (a.kind != b.kind)
				return a.kind == "haxe" ? -1 : 1;
			return Reflect.compare(a.name.toLowerCase(), b.name.toLowerCase());
		});
		return result;
	}

	#if sys
	function collectFiles(absDir:String, relDir:String, out:Array<CodeStudioFile>):Void
	{
		if (!FileSystem.exists(absDir) || !FileSystem.isDirectory(absDir)) return;

		var entries = FileSystem.readDirectory(absDir);
		entries.sort(Reflect.compare);
		for (entry in entries)
		{
			if (entry == "." || entry == "..") continue;
			var abs = Path.join([absDir, entry]);
			var rel = relDir == "" ? entry : relDir + "/" + entry;
			if (FileSystem.isDirectory(abs))
			{
				collectFiles(abs, rel, out);
				continue;
			}

			var lower = entry.toLowerCase();
			if (StringTools.endsWith(lower, ".hx"))
			{
				if (isScriptPath(rel))
					out.push(new CodeStudioFile(rel, safeRead(abs), abs, true, "haxe"));
			}
			else if (StringTools.endsWith(lower, ".json"))
			{
				var readOnly = isSpriteJson(rel);
				out.push(new CodeStudioFile(rel, safeRead(abs), abs, !readOnly, "json",
					readOnly ? CodeLang.t("advanced.spriteJsonReadOnly", null, "sprite.json pertenece al atlas del sprite y se protege contra escritura.") : ""));
			}
		}
	}

	static function isScriptPath(rel:String):Bool
	{
		var lower = StringTools.replace(rel, "\\", "/").toLowerCase();

		return lower == Scripts.DIR || StringTools.startsWith(lower, Scripts.DIR + "/")
			|| lower == Scripts.LEGACY_DIR || StringTools.startsWith(lower, Scripts.LEGACY_DIR + "/");
	}

	static function isSpriteJson(rel:String):Bool
	{
		var normalized = StringTools.replace(rel, "\\", "/").toLowerCase();
		return StringTools.startsWith(normalized, "sprites/") && Path.withoutDirectory(normalized) == "sprite.json";
	}

	static function safeRead(path:String):String
	{
		try return File.getContent(path) catch (e:Dynamic) return "";
	}

	static function defaultScript():String
	{
		return CodeLang.t("advanced.defaultScript", null, "// FMCE Advanced\n// Este script se guarda en levels/<nivel>/data/scripts/.\n// Runtime de HScript pendiente: por ahora se edita y guarda.\n\nfunction onCreate()\n{\n    trace(\"FMCE: script cargado\");\n}\n");
	}
	#end

	function saveFile(file:CodeStudioFile):Bool
	{
		#if sys
		if (file == null || !file.editable) return false;
		if (!isInsideLevel(file.path))
		{
			studio.log("[FMCE] " + CodeLang.t("advanced.saveBlockedOutside", null, "Save bloqueado: ruta fuera del nivel."), "error");
			return false;
		}
		if (file.kind == "haxe" && !isScriptPath(relativeToLevel(file.path)))
		{
			studio.log("[FMCE] " + CodeLang.t("advanced.saveBlockedHx", null, "Save bloqueado: los .hx solo viven dentro de data/scripts/."), "error");
			return false;
		}
		if (file.kind == "json")
		{
			try
			{
				Json.parse(file.content);
			}
			catch (e:Dynamic)
			{
				studio.log("[FMCE] " + CodeLang.t("advanced.jsonInvalid", [Std.string(e)], "JSON inválido: {0}"), "error");
				return false;
			}
		}
		try
		{
			var dir = Path.directory(file.path);
			if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
			File.saveContent(file.path, file.content);
		}
		catch (e:Dynamic)
		{
			studio.log("[FMCE] " + CodeLang.t("advanced.saveError", [Std.string(e)], "Error al guardar: {0}"), "error");
			return false;
		}
		return true;
		#end
		return false;
	}

	function createScript():CodeStudioFile
	{
		#if sys
		var scripts = Path.join([levelDir, Scripts.DIR]);
		var index = 0;
		while (true)
		{
			var name = index == 0 ? "script.hx" : "script" + index + ".hx";
			var path = Path.join([scripts, name]);
			var alreadyUsed = FileSystem.exists(path);
			if (!alreadyUsed && studio != null)
				for (file in studio.files)
					if (file.path == path) alreadyUsed = true;
			if (!alreadyUsed)
				return new CodeStudioFile(Scripts.DIR + "/" + name, defaultScript(), path, true, "haxe", "", true);
			index++;
		}
		#end
		return null;
	}

	function prepareRun(file:CodeStudioFile):Void
	{
		if (file == null || file.kind != "haxe") return;
		studio.log("[FMCE] " + CodeLang.t("advanced.runtimeNotConnected", null, "El runtime de HScript aún no está conectado a PlayState."), "warn");
		studio.log("[FMCE] " + CodeLang.t("advanced.filePrepared", [file.path], "El archivo queda preparado en {0}"), "info");
	}

	function openSpritePreview():Void
	{
		chosen = true;
		if (studio != null) studio.setCovered(true);
		TransitionHandler.switchState(new advanced.editors.SpriteEditorState(levelName));
	}

	#if sys
	function isInsideLevel(path:String):Bool
	{
		var root = Path.normalize(levelDir + "/");
		var normalized = Path.normalize(path);
		return normalized == Path.normalize(levelDir) || StringTools.startsWith(normalized, root);
	}

	function relativeToLevel(path:String):String
	{
		var normalizedRoot = StringTools.replace(Path.normalize(levelDir), "\\", "/");
		var normalized = StringTools.replace(Path.normalize(path), "\\", "/");
		if (StringTools.startsWith(normalized, normalizedRoot + "/"))
			return normalized.substr(normalizedRoot.length + 1);
		return normalized;
	}
	#end

	var leaveWarned:Bool = false;

	function leave():Void
	{
		if (chosen) return;
		if (studio != null && studio.hasUnsaved() && !leaveWarned)
		{
			leaveWarned = true;
			studio.log("[FMCE] " + CodeLang.t("advanced.unsavedExit", null, "Hay cambios sin guardar. Vuelve a salir para descartarlos o guarda con Ctrl+S."), "warn");
			return;
		}
		chosen = true;
		if (studio != null) studio.setCovered(true);
		TransitionHandler.switchState(new AdvancedModeState());
	}

	override public function closeSubState():Void
	{
		super.closeSubState();
		if (studio != null && !chosen) studio.setCovered(false);
	}

	var coveredTicks:Int = 0;

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (studio != null && studio.covered && !chosen && TransitionHandler.active == null && ++coveredTicks > 3)
			studio.setCovered(false);
		if (chosen) return;
		if (studio != null && studio.escapeHandled) return;
		if (KeyBinds.justPressed(KeyBinds.BACK) || FlxG.keys.justPressed.ESCAPE) leave();
	}

	override public function destroy():Void
	{
		studio = null;
		super.destroy();
	}
}
