package funky.backend.chart;

import haxe.io.Path;
import funky.backend.converter.FNMMToFMCEConverter;
import funky.core.Paths;
import funky.core.Storage;

#if sys
import sys.FileSystem;
#end

/** Lee archivos `.fnmm` para jugarlos directo desde Freeplay. */
class FNMMLoader
{
	public static function listArchives(?root:String):Array<String>
	{
		#if sys
		if (root == null) root = Storage.levelsDirectory();
		if (!FileSystem.exists(root)) FileSystem.createDirectory(root);
		var files = [for (file in FileSystem.readDirectory(root))
			if (StringTools.endsWith(file.toLowerCase(), ".fnmm")) Path.join([root, file])];
		files.sort(Reflect.compare);
		return files;
		#else
		return [];
		#end
	}

	public static function load(archivePath:String):FNMMChart
	{
		#if sys
		var result = FNMMToFMCEConverter.convert(archivePath, Paths.levelsRoot());
		if (!result.ok) throw 'No se pudo leer ' + archivePath + ': ' + result.error;
		return LevelLoader.loadFolder(result.target);
		#else
		throw "FNMM archives require a sys target";
		#end
	}
}
