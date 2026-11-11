package funky.backend.converter;

import haxe.io.Bytes;
import haxe.io.Path;
import funky.backend.LevelArchive;
import funky.backend.chart.LevelLoader;
import funky.core.JsonLoose;
import funky.core.Paths;

#if sys
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import sys.FileSystem;
import sys.io.File;
#end

typedef FNMMExportResult =
{
	var ok:Bool;
	var level:String;
	var path:String;
	var notes:Int;
	var sprites:Int;
	var files:Int;

	var ignored:Array<String>;
	var warnings:Array<String>;
	var error:Null<String>;
}

typedef FNMMExportPlan =
{
	var music:Null<String>;
	var voices:Null<String>;
	