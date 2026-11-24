package funky.menus.other;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.ui.FlxBar;
import flixel.ui.FlxBar.FlxBarFillDirection;
import flixel.util.FlxColor;
import funky.backend.LevelVideoMigrator;
import funky.backend.converter.VideoSheet;
import funky.backend.converter.VideoSheet.VideoSheetJob;
import funky.backend.FunkinVideoSprite;
import funky.backend.Mp4Info;
import funky.backend.MusicBeatState;
import funky.backend.system.framerate.Framerate;
import funky.backend.addons.Addons;
import funky.backend.addons.AssetPack;
import funky.backend.system.ClientPrefs;
import funky.backend.system.Log;
import funky.backend.assets.Paths;
import funky.backend.system.Storage;
import funky.backend.addons.AddonsDownloader;
import funky.menus.SplashState;
import funky.menus.TitleState;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/** Etapas del loader: una por frame (el .pack se revisa por tandas), asi la barra se mueve y no se congela nada. */
enum CheckStage
{
	WaitAccess;
	ScanPack;
	ReadSol;
	ReadFps;
	ScanLevelVideos;
	ScanAddons;
	Downloading;
	Finished;
}

/**
 * Loader rapido del engine. Antes de entrar al juego revisa, en orden:
 *  1. assets.pack: que cargue, que no este cortado y que sus entradas caigan dentro del archivo (y que png/ogg tengan firma valida).
 *  2. FMCE.sol: que se haya leido de la carpeta correcta (si no, se mueve y se recarga).
 *  3. Contador de FPS: que este como dice la config (display.fps del .sol).
 *  4. Addons: que esten todos los archivos (videos incluidos) y que no esten rotos; lo que falte o este roto se vuelve a bajar.
 */
class CheckerState extends MusicBeatState
{
	static inline var BASE_URL:String = "https://raw.githubusercontent.com/TheJarret084/FMCE/main/addons/";

	static inline var STALL_TIMEOUT:Float = 20;
	static inline var ACCESS_TIMEOUT:Float = 25;

	// Entradas del .pack que se revisan por frame.
	static inline var PACK_BATCH:Int = 600;

	static inline var COLOR_OK:Int = 0xFFFFFFFF;
	static inline var COLOR_WARN:Int = 0xFFFFD166;
	static inline var COLOR_BAD:Int = 0xFFFF6B6B;

	// Los HUD skins y los videos sueltos se entregan como zips (el unzip es recursivo); el video del error fatal queda fijo.
	static var addons:Array<AddonFile> = [
		{
			name: "hudskins.zip",
			url: BASE_URL + "hudskins.zip",
			check: [
				"hudskins/default/data/hudSkin.xml",
				"hudskins/default/fonts/PhantomMuff.ttf",
				"hudskins/default/images/go.png",
				"hudskins/default/images/ready.png",
				"hudskins/default/images/restart.png",
				"hudskins/default/images/set.png",
				"hudskins/default/images/notes/default.png",
				"hudskins/default/images/notes/default.xml",
				"hudskins/default/images/score/bad.png",
				"hudskins/default/images/score/epic.png",
				"hudskins/default/images/score/good.png",
				"hudskins/default/images/score/num0.png",
				"hudskins/default/images/score/num1.png",
				"hudskins/default/images/score/num2.png",
				"hudskins/default/images/score/num3.png",
				"hudskins/default/images/score/num4.png",
				"hudskins/default/images/score/num5.png",
				"hudskins/default/images/score/num6.png",
				"hudskins/default/images/score/num7.png",
				"hudskins/default/images/score/num8.png",
				"hudskins/default/images/score/num9.png",
				"hudskins/default/images/score/shit.png",
				"hudskins/default/images/score/sick.png",
				"hudskins/default/images/splashes/default.png",
				"hudskins/default/images/splashes/default.xml",
				"hudskins/default/sounds/gameOverEnd.ogg",
				"hudskins/default/sounds/gameOverSFX.ogg",
				"hudskins/default/sounds/intro1.ogg",
				"hudskins/default/sounds/intro2.ogg",
				"hudskins/default/sounds/intro3.ogg",
				"hudskins/default/sounds/introGo.ogg",
				"hudskins/default/sounds/missnote1.ogg",
				"hudskins/default/sounds/missnote2.ogg",
				"hudskins/default/sounds/missnote3.ogg",
				"hudskins/codename/data/hudSkin.xml",
				"hudskins/codename/fonts/vcr.ttf",
				"hudskins/codename/images/go.png",
				"hudskins/codename/images/ready.png",
				"hudskins/codename/images/restart.png",
				"hudskins/codename/images/set.png",
				"hudskins/codename/images/notes/default.png",
				"hudskins/codename/images/notes/default.xml",
				"hudskins/codename/images/score/bad.png",
				"hudskins/codename/images/score/combo.png",
				"hudskins/codename/images/score/good.png",
				"hudskins/codename/images/score/num0.png",
				"hudskins/codename/images/score/num1.png",
				"hudskins/codename/images/score/num2.png",
				"hudskins/codename/images/score/num3.png",
				"hudskins/codename/images/score/num4.png",
				"hudskins/codename/images/score/num5.png",
				"hudskins/codename/images/score/num6.png",
				"hudskins/codename/images/score/num7.png",
				"hudskins/codename/images/score/num8.png",
				"hudskins/codename/images/score/num9.png",
				"hudskins/codename/images/score/shit.png",
				"hudskins/codename/images/score/sick.png",
				"hudskins/codename/images/splashes/default.png",
				"hudskins/codename/images/splashes/default.xml",
				"hudskins/codename/sounds/gameOverEnd.ogg",
				"hudskins/codename/sounds/gameOverSFX.ogg",
				"hudskins/codename/sounds/intro1.ogg",
				"hudskins/codename/sounds/intro2.ogg",
				"hudskins/codename/sounds/intro3.ogg",
				"hudskins/codename/sounds/introGo.ogg",
				"hudskins/codename/sounds/missnote1.ogg",
				"hudskins/codename/sounds/missnote2.ogg",
				"hudskins/codename/sounds/missnote3.ogg",
				"hudskins/fmm/data/hudSkin.hx",
				"hudskins/fmm/data/hudSkin.xml",
				"hudskins/fmm/fonts/milky.ttf",
				"hudskins/fmm/images/go.png",
				"hudskins/fmm/images/ready.png",
				"hudskins/fmm/images/restart.png",
				"hudskins/fmm/images/set.png",
				"hudskins/fmm/images/notes/default.png",
				"hudskins/fmm/images/notes/default.xml",
				"hudskins/fmm/images/score/bad.png",
				"hudskins/fmm/images/score/good.png",
				"hudskins/fmm/images/score/sick.png",
				"hudskins/fmm/images/splashes/default.png",
				"hudskins/fmm/images/splashes/default.xml",
				"hudskins/fmm/shaders/dropShadow.frag",
				"hudskins/fmm/sounds/gameOverEnd.ogg",
				"hudskins/fmm/sounds/gameOverSFX.ogg",
				"hudskins/fmm/sounds/intro1.ogg",
				"hudskins/fmm/sounds/intro2.ogg",
				"hudskins/fmm/sounds/intro3.ogg",
				"hudskins/fmm/sounds/introGo.ogg",
				"hudskins/fmm/sounds/missnote1.ogg",
				"hudskins/fmm/sounds/missnote2.ogg",
				"hudskins/fmm/sounds/missnote3.ogg"
			],
			priority: true
		},
		{
			name: "videos.zip",
			url: BASE_URL + "videos.zip",
			check: ["videos/splash.mp4"],
			priority: true
		},
		{
			name: "fatalerrorisocurred.mp4",
			url: BASE_URL + "videos/fatalerrorisocurred.mp4",
			dest: "videos/fatalerrorisocurred.mp4",
			check: ["videos/fatalerrorisocurred.mp4"],
			priority: false
		}
	];

	var label:FlxText;
	var bar:FlxBar;

	var stage:CheckStage = WaitAccess;

	// Lo que se va encontrando: critical = el engine no va a andar bien, problems = se sigue pero con algo menos,
	// fixed = se arreglo solo.
	var critical:Array<String> = [];
	var problems:Array<String> = [];
	var fixed:Array<String> = [];

	var packIds:Array<String> = [];
	var packIdx:Int = 0;
	var packBad:Array<String> = [];
	var packStarted:Bool = false;

	var queue:Array<AddonFile> = [];
	var index:Int = 0;
	var current:Null<AddonsDownloader> = null;
	var failed:Array<String> = [];

	var subProgress:Float = 0;
	var shown:Float = 0;
	var stalled:Float = 0;

	var leaving:Bool = false;
	var leaveIn:Float = 0;

	var accessWait:Float = 0;
	var accessPoll:Float = 0;

	// Conversion de video -> spritesheet (paso a paso para no congelar el checker).
	var videoDirs:Array<String> = [];
	var videoIdx:Int = 0;
	var videoJob:Null<VideoSheetJob> = null;
	var videoConverted:Int = 0;
	var videoTotal:Int = 0;

	override public function create():Void
	{
		super.create();
		Storage.init();

		FlxG.cameras.bgColor = FlxColor.BLACK;

		label = new FlxText(20, FlxG.height - 72, FlxG.width - 40, "Revisando el engine...", 20);
		label.alignment = FlxTextAlign.CENTER;
		add(label);

		bar = new FlxBar(20, FlxG.height - 36, FlxBarFillDirection.LEFT_TO_RIGHT, FlxG.width - 40, 10, null, "", 0, 1, true);
		bar.createFilledBar(0xFF101016, 0xFF64DDAA, true, 0xFF000000);
		bar.percent = 0;
		add(bar);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (leaving) return;

		switch (stage)
		{
			case WaitAccess:
				if (waitForAccess(elapsed)) stage = ScanPack;
			case ScanPack:
				checkPack();
			case ReadSol:
				checkSol();
				stage = ReadFps;
			case ReadFps:
				checkFps();
				stage = ScanLevelVideos;
			case ScanLevelVideos:
				checkLevelVideos();
			case ScanAddons:
				checkAddons();
			case Downloading:
				watchDownload(elapsed);
			case Finished:
				leaveIn -= elapsed;
				if (leaveIn <= 0) leave();
		}

		shown += (overall() - shown) * Math.min(1, elapsed * 10);
		bar.percent = shown * 100;
	}

	function overall():Float
	{
		return switch (stage)
		{
			case WaitAccess: 0;
			case ScanPack: 0.05 + 0.35 * (packIds.length == 0 ? 0 : packIdx / packIds.length);
			case ReadSol: 0.42;
			case ReadFps: 0.48;
			case ScanLevelVideos: 0.52 + 0.03 * (videoTotal <= 0 ? 1 : (videoIdx + (videoJob != null ? videoJob.fraction : 0)) / videoTotal);
			case ScanAddons: 0.55;
			case Downloading: 0.55 + 0.45 * (queue.length == 0 ? 0 : (index + subProgress) / queue.length);
			case Finished: 1;
		}
	}

	// Pone el texto y lo sube lo que haga falta para que, si ocupa varias lineas, no se encime con la barra.
	function say(text:String, color:Int = COLOR_OK):Void
	{
		label.text = text;
		label.color = color;
		label.y = FlxG.height - 46 - label.height;
	}

	// En Android el permiso de archivos se pide de forma asincrona: si bajamos antes de que lo den, los addons
	// caerian en la carpeta de respaldo y despues el juego los buscaria en otra. Se espera un rato a que lo concedan.
	function waitForAccess(elapsed:Float):Bool
	{
		#if (android && sys)
		accessWait += elapsed;
		accessPoll += elapsed;
		if (accessPoll >= 0.5)
		{
			accessPoll = 0;
			if (Storage.hasAccess()) return true;
		}
		if (accessWait < ACCESS_TIMEOUT)
		{
			say("Revisando permisos, un momento...");
			return false;
		}
		Log.warn("[Checker] sin permiso de archivos, se sigue con la carpeta de respaldo");
		#end
		return true;
	}

	// ------------------------------------------------------------------ 1. assets.pack

	function checkPack():Void
	{
		#if (sys && !FMCE_LOOSE_ASSETS)
		var pack = AssetPack.pack;

		if (!packStarted)
		{
			packStarted = true;
			say("Revisando " + AssetPack.FILE + "...");

			if (!AssetPack.mounted || pack == null)
			{
				Log.error('[Checker] ${AssetPack.FILE} no esta montado');
				critical.push('${AssetPack.FILE} no cargo (falta o esta corrupto): el juego puede quedarse sin assets');
				stage = ReadSol;
				return;
			}
			if (pack.count <= 0)
			{
				Log.error('[Checker] ${AssetPack.FILE} no trae archivos');
				critical.push('${AssetPack.FILE} esta vacio');
				stage = ReadSol;
				return;
			}

			// Cabecera e indice ya pasaron al montarlo; las entradas se revisan por tandas desde el siguiente frame.
			packIds = pack.ids();
			return;
		}

		var end = Std.int(Math.min(packIds.length, packIdx + PACK_BATCH));
		while (packIdx < end)
		{
			var id = packIds[packIdx++];
			var why = pack.entryProblem(id);
			if (why != null) packBad.push('$id: $why');
		}
		say('Revisando ${AssetPack.FILE} ($packIdx/${packIds.length})');

		if (packIdx < packIds.length) return;

		if (packBad.length > 0)
		{
			for (line in packBad) Log.error('[Checker] ${AssetPack.FILE}: $line');
			var sample = [for (i in 0...Std.int(Math.min(2, packBad.length))) packBad[i].split(":")[0]].join(", ");
			critical.push('${AssetPack.FILE} danado (${packBad.length} archivos, ej: $sample): reinstala el juego');
		}
		else
			Log.info('[Checker] ${AssetPack.FILE}: ${packIds.length} archivos ok');

		stage = ReadSol;
		#else
		stage = ReadSol;
		#end
	}

	// ------------------------------------------------------------------ 2. FMCE.sol

	function checkSol():Void
	{
		say("Revisando FMCE.sol...");

		var expected = ClientPrefs.solPath();
		var loaded = ClientPrefs.loadedFrom;

		if (loaded != expected)
		{
			// Pasa en Android: la config se carga al abrir, antes de que den el permiso, y cae en la carpeta de respaldo.
			Log.warn('[Checker] FMCE.sol se leyo de $loaded pero le toca $expected: se mueve y se recarga');
			ClientPrefs.relocateSol(loaded);
			fixed.push("FMCE.sol (se leia de otra carpeta)");
		}
		else if (ClientPrefs.solRecovered)
		{
			Log.warn('[Checker] FMCE.sol estaba ilegible: se restauro con los valores por defecto');
			fixed.push("FMCE.sol (estaba danado)");
		}

		if (!FileSystem.exists(expected))
		{
			ClientPrefs.save();
			if (!FileSystem.exists(expected))
			{
				Log.warn('[Checker] no se pudo escribir FMCE.sol en $expected: la config no se va a guardar');
				problems.push("no se puede guardar FMCE.sol");
				return;
			}
		}

		Log.info('[Checker] FMCE.sol ok ($expected)');
	}

	// ------------------------------------------------------------------ 3. Contador de FPS

	function checkFps():Void
	{
		say("Revisando el contador de FPS...");

		// Lo que dice el .sol manda: si el contador esta distinto, se pone como la config dicta.
		var wanted = ClientPrefs.solFpsSetting();
		if (wanted != null && wanted != (Framerate.debugMode > 0))
		{
			Log.warn('[Checker] el contador de FPS no coincidia con la config (display.fps=$wanted): se corrige');
			Framerate.debugMode = wanted ? 1 : 0;
			fixed.push("contador de FPS");
		}

		var counter = Framerate.instance;
		if (counter == null || counter.fpsCounter == null)
		{
			Log.warn("[Checker] el contador de FPS no se creo");
			problems.push("no hay contador de FPS");
			return;
		}

		counter.visible = Framerate.debugMode > 0;
		counter.reload();

		if (FlxG.drawFramerate <= 0)
		{
			Log.warn('[Checker] drawFramerate invalido (${FlxG.drawFramerate}): el contador compara contra eso');
			problems.push("framerate invalido");
		}
		else
			Log.info('[Checker] FPS ok (contador ' + (Framerate.debugMode > 0 ? "visible" : "oculto") + ', objetivo ${FlxG.drawFramerate})');
	}

	// ------------------------------------------------------------------ 4. Videos de los niveles

	/**
	 * Convierte videos de niveles a spritesheets (sprite.json + paginas). Paso a paso para no congelar el checker.
	 * Si no se puede convertir, se normaliza el config de video como fallback.
	 */
	function checkLevelVideos():Void
	{
		if (!ClientPrefs.isAutoConvertVideos())
		{
			Log.info('[Checker] conversion de videos desactivada en opciones');
			stage = ScanAddons;
			return;
		}
		#if sys
		if (videoDirs.length == 0 && videoJob == null && videoIdx == 0 && videoTotal == 0)
		{
			say("Revisando videos de los niveles...");
			var levelsRoot = Paths.levelsRoot();
			levelsRoot = Path.removeTrailingSlashes(levelsRoot);
			if (FileSystem.exists(levelsRoot) && FileSystem.isDirectory(levelsRoot))
			{
				for (entry in FileSystem.readDirectory(levelsRoot))
				{
					if (entry == null || entry == "" || entry.charAt(0) == ".") continue;
					var levelDir = Path.join([levelsRoot, entry]);
					if (!FileSystem.exists(levelDir) || !FileSystem.isDirectory(levelDir)) continue;
					var spritesRoot = Path.join([levelDir, "sprites"]);
					if (!FileSystem.exists(spritesRoot) || !FileSystem.isDirectory(spritesRoot)) continue;
					for (spr in FileSystem.readDirectory(spritesRoot))
					{
						var dir = Path.join([spritesRoot, spr]);
						if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir)) continue;
						if (FunkinVideoSprite.videoFiles(dir).length > 0) videoDirs.push(dir);
					}
				}
			}
			videoTotal = videoDirs.length;
			if (videoTotal == 0)
			{
				Log.info('[Checker] videos de niveles: nada que convertir');
				stage = ScanAddons;
				return;
			}
		}

		if (videoJob == null)
		{
			if (videoIdx >= videoDirs.length)
			{
				Log.info('[Checker] videos de niveles: $videoTotal carpetas revisadas, $videoConverted convertidas a spritesheet');
				stage = ScanAddons;
				return;
			}

			var dir = videoDirs[videoIdx];
			var label = videoLabel(dir);
			if (VideoSheet.canConvert(dir))
			{
				say('Convirtiendo video a spritesheet (${videoIdx + 1}/$videoTotal): $label');
				videoJob = VideoSheet.start(dir);
			}
			else
			{
				// Tiene .mp4 pero no se puede convertir como sheet (ej. ya tiene sprite.png raro): normalizar fallback solo este dir.
				var files = FunkinVideoSprite.videoFiles(dir);
				var fallback = {dir: Path.directory(Path.directory(dir)), videos: files.length, fixed: [], problems: []};
				LevelVideoMigrator.normalizeVideoConfig(dir, files, label, fallback);
				for (line in fallback.fixed) fixed.push(line);
				for (line in fallback.problems) problems.push(line);
				videoIdx++;
				return;
			}
		}

		var job = videoJob;
		if (job == null) return;
		if (job.step())
		{
			say('Video a spritesheet (${videoIdx + 1}/$videoTotal): ${videoLabel(videoDirs[videoIdx])} ${Std.int(job.fraction * 100)}%');
			return;
		}

		var dir = videoDirs[videoIdx];
		var label = videoLabel(dir);
		videoJob = null;
		videoIdx++;

		if (job.ok)
		{
			videoConverted++;
			for (w in job.warnings)
			{
				Log.warn('[Checker] video: $label: $w');
				problems.push('$label: $w');
			}
			Log.info('[Checker] video -> spritesheet: $label (${job.summary})');
			fixed.push('$label (video -> spritesheet)');
		}
		else
		{
			var err = job.error == null ? "sin detalle" : job.error;
			Log.warn('[Checker] video no convertido $label: $err');
			// Fallback: dejarlo como video normalizado para que el nivel siga funcionando.
			var files = FunkinVideoSprite.videoFiles(dir);
			var fallback = {dir: Path.directory(Path.directory(dir)), videos: files.length, fixed: [], problems: []};
			LevelVideoMigrator.normalizeVideoConfig(dir, files, label, fallback);
			for (line in fallback.fixed) fixed.push(line);
			for (line in fallback.problems) problems.push(line);
			if (fallback.fixed.length == 0) problems.push('$label: no se pudo convertir a spritesheet ($err)');
		}
		#else
		stage = ScanAddons;
		#end
	}

	#if sys
	function videoLabel(dir:String):String
	{
		var spr = Path.withoutDirectory(dir);
		var levelDir = Path.directory(Path.directory(dir));
		return Path.withoutDirectory(levelDir) + "/sprites/" + spr;
	}
	#end

	// ------------------------------------------------------------------ 5. Addons

	function checkAddons():Void
	{
		say("Revisando addons...");

		for (item in addons)
			for (rel in item.check)
			{
				dropLeftover(rel);
				var why = addonProblem(rel);
				if (why == null) continue;

				Log.warn('[Checker] addons/$rel $why: se borra para volver a bajarlo');
				dropExternal(rel);
				fixed.push('$rel ($why)');
			}

		queue = AddonsDownloader.missing(addons);

		if (queue.length == 0)
		{
			finish();
			return;
		}

		Log.info('[Checker] faltan: ${[for (a in queue) a.name].join(", ")}');
		stage = Downloading;
		next();
	}

	/**
	 * Revisa un archivo de addons que ya esta en disco (los que vienen dentro del build no se tocan).
	 * Devuelve null si esta bien (o si no esta: eso lo cubre el downloader), o el motivo si esta roto.
	 */
	static function addonProblem(rel:String):Null<String>
	{
		var path = Addons.externalPath(rel);
		try
		{
			if (!FileSystem.exists(path)) return null;
			if (FileSystem.isDirectory(path)) return "es una carpeta";
			if (FileSystem.stat(path).size <= 0) return "esta vacio";

			switch (Path.extension(rel).toLowerCase())
			{
				case "mp4":
					// Mp4Info busca el 'moov': un video cortado a medias no lo tiene.
					Mp4Info.forget(path);
					if (Mp4Info.size(path) == null) return "el video esta corrupto o incompleto";
				case "png":
					var input = File.read(path, true);
					var head = input.read(4);
					input.close();
					if (head.get(0) != 0x89 || head.get(1) != 0x50 || head.get(2) != 0x4E || head.get(3) != 0x47)
						return "no es un PNG valido";
				case "xml":
					if (Xml.parse(File.getContent(path)).firstElement() == null) return "el XML esta vacio";
				default:
			}
		}
		catch (e:Dynamic)
		{
			return "no se pudo leer (" + Std.string(e) + ")";
		}
		return null;
	}

	// Un .part es una descarga que se corto: no sirve de nada y se borra.
	static function dropLeftover(rel:String):Void
	{
		var part = Addons.externalPath(rel) + ".part";
		try
		{
			if (FileSystem.exists(part) && !FileSystem.isDirectory(part)) FileSystem.deleteFile(part);
		}
		catch (_:Dynamic) {}
	}

	static function dropExternal(rel:String):Void
	{
		var path = Addons.externalPath(rel);
		try
		{
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) FileSystem.deleteFile(path);
		}
		catch (_:Dynamic) {}
		Mp4Info.forget(path);
	}

	function watchDownload(elapsed:Float):Void
	{
		if (current == null) return;

		stalled += elapsed;
		if (stalled > STALL_TIMEOUT)
		{
			Log.warn('[Checker] ${queue[index].name} no avanza en ${STALL_TIMEOUT}s, se salta');
			failed.push(queue[index].name);
			advance();
		}
	}

	function next():Void
	{
		if (index >= queue.length)
		{
			finish();
			return;
		}

		var item = queue[index];
		say('Descargando ${item.name} (${index + 1}/${queue.length})');
		subProgress = 0;
		stalled = 0;

		var job = new AddonsDownloader(item);
		current = job;

		job.onProgress = function(p:Float)
		{
			if (current != job) return;
			subProgress = p;
			stalled = 0;
		};
		job.onComplete = function()
		{
			if (current != job) return;
			Log.info('[Checker] ${item.name} listo');
			advance();
		};
		job.onError = function(error:String)
		{
			if (current != job) return;
			Log.warn('[Checker] no se pudo bajar ${item.name}: $error');
			failed.push(item.name);
			advance();
		};
		job.download();
	}

	function advance():Void
	{
		current = null;
		index++;
		subProgress = 0;
		next();
	}

	// ------------------------------------------------------------------ cierre

	function finish():Void
	{
		// Si se bajo algo, se vuelve a mirar todo: un video "bajado" pero cortado no cuenta como listo.
		var missing:Array<String> = [];
		for (item in addons)
			for (rel in item.check)
			{
				if (!Addons.exists(rel))
				{
					missing.push('$rel (falta)');
					continue;
				}
				if (queue.length == 0) continue;

				var why = addonProblem(rel);
				if (why != null)
				{
					dropExternal(rel);
					missing.push('$rel ($why)');
				}
			}

		var videos = [for (item in addons) for (rel in item.check) if (Path.extension(rel).toLowerCase() == "mp4") rel];
		var videosOk = [for (rel in videos) if (Addons.exists(rel)) rel];
		Log.info('[Checker] videos: ${videosOk.length}/${videos.length}');

		// Si la skin elegida ya no existe se vuelve a la default (si no, las notas salen sin textura).
		var skin = ClientPrefs.getHudSkin();
		if (skin != "default" && !Addons.exists('hudskins/$skin/data/hudSkin.xml') && !Addons.exists('noteskins/$skin/data/noteSkin.xml'))
		{
			Log.warn('[Checker] la noteskin "$skin" no existe: se usa "default"');
			ClientPrefs.setHudSkin("default");
			fixed.push('noteskin "$skin" -> default');
		}

		for (line in missing) problems.push(line);
		for (line in problems) Log.warn('[Checker] pendiente: $line');
		for (line in fixed) Log.info('[Checker] reparado: $line');

		stage = Finished;

		if (critical.length > 0)
		{
			var lines = critical.copy();
			if (problems.length > 0) lines.push("Tambien: " + problems.join(", "));
			say(lines.join("\n"), COLOR_BAD);
			leaveIn = 6;
		}
		else if (problems.length > 0)
		{
			say("Se sigue sin: " + problems.join(", "), COLOR_WARN);
			leaveIn = 2.5;
		}
		else if (fixed.length > 0)
		{
			say('Listo (se repararon ${fixed.length} cosas)');
			leaveIn = 0.8;
		}
		else
		{
			say("Listo");
			leaveIn = 0.25;
		}
	}

	function leave():Void
	{
		if (leaving) return;
		leaving = true;

		var nextState:FlxState = (ClientPrefs.isSkipIntro() || ClientPrefs.isSplashSeen()) ? new TitleState() : new SplashState();
		FlxG.switchState(nextState);
	}
}
