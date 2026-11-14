package funky.menus.other;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.ui.FlxBar;
import flixel.ui.FlxBar.FlxBarFillDirection;
import flixel.util.FlxColor;
import funky.backend.MusicBeatState;
import funky.core.ClientPrefs;
import funky.core.Log;
import funky.core.Storage;
import funky.core.other.AddonsDownloader;
import funky.menus.SplashState;
import funky.menus.TitleState;

class CheckerState extends MusicBeatState
{
	static inline var BASE_URL:String = "https://raw.githubusercontent.com/TheJarret084/FMCE/main/addons/";

	static inline var STALL_TIMEOUT:Float = 20;
	static inline var ACCESS_TIMEOUT:Float = 25;

	// Ahora el repo tiene addons/ como carpetas sueltas: un archivo = una descarga (solo se bajan los que falten).
	// Cuando pases a zips: una entrada SIN dest, con la URL del .zip y en check los archivos que trae
	// (el zip se extrae dentro de addons/, asi que debe incluir sus carpetas, ej. noteskins/default/...).
	static var files:Array<String> = [
		"videos/splash.mp4",
		"noteskins/default/data/noteSkin.xml",
		"noteskins/default/images/NOTE_assets.png",
		"noteskins/default/images/NOTE_assets.xml",
		"noteskins/default/images/NOTE_splashes.png",
		"noteskins/default/images/NOTE_splashes.xml",
		"noteskins/codename/data/noteSkin.xml",
		"noteskins/codename/images/NOTE_assets.png",
		"noteskins/codename/images/NOTE_assets.xml",
		"noteskins/codename/images/NOTE_splashes.png",
		"noteskins/codename/images/NOTE_splashes.xml",
		"noteskins/fmm/data/noteSkin.hx",
		"noteskins/fmm/data/noteSkin.xml",
		"noteskins/fmm/images/NOTE_assets.png",
		"noteskins/fmm/images/NOTE_assets.xml",
		"noteskins/fmm/images/NOTE_splashes.png",
		"noteskins/fmm/images/NOTE_splashes.xml",
		"noteskins/fmm/shaders/dropShadow.frag",
		"videos/fatalerrorisocurred.mp4"
	];

	static var addons:Array<AddonFile> = [
		for (rel in files)
			{
				name: rel,
				url: BASE_URL + rel,
				dest: rel,
				check: [rel],
				priority: rel != "videos/fatalerrorisocurred.mp4"
			}
	];

	var label:FlxText;
	var bar:FlxBar;

	var queue:Array<AddonFile> = [];
	var index:Int = 0;
	var current:Null<AddonsDownloader> = null;
	var failed:Array<String> = [];

	var subProgress:Float = 0;
	var shown:Float = 0;
	var stalled:Float = 0;

	var started:Bool = false;
	var done:Bool = false;
	var leaving:Bool = false;
	var leaveIn:Float = 0;

	var accessWait:Float = 0;
	var accessPoll:Float = 0;

	override public function create():Void
	{
		super.create();
		Storage.init();

		FlxG.cameras.bgColor = FlxColor.BLACK;

		label = new FlxText(20, FlxG.height - 72, FlxG.width - 40, "Checando cosas faltantes...", 20);
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

		if (!started)
		{
			if (!waitForAccess(elapsed)) return;
			begin();
			return;
		}

		if (done)
		{
			leaveIn -= elapsed;
			if (leaveIn <= 0) leave();
		}
		else if (current != null)
		{
			stalled += elapsed;
			if (stalled > STALL_TIMEOUT)
			{
				Log.warn('[Checker] ${queue[index].name} no avanza en ${STALL_TIMEOUT}s, se salta');
				failed.push(queue[index].name);
				advance();
			}
		}

		var target = done ? 1 : (queue.length == 0 ? 0 : (index + subProgress) / queue.length);
		shown += (target - shown) * Math.min(1, elapsed * 10);
		bar.percent = shown * 100;
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
			label.text = "Concede el permiso de archivos para continuar...";
			return false;
		}
		Log.warn("[Checker] sin permiso de archivos, se sigue con la carpeta de respaldo");
		#end
		return true;
	}

	function begin():Void
	{
		started = true;
		queue = AddonsDownloader.missing(addons);

		if (queue.length == 0)
		{
			leave();
			return;
		}

		Log.info('[Checker] faltan: ${[for (a in queue) a.name].join(", ")}');
		next();
	}

	function next():Void
	{
		if (index >= queue.length)
		{
			finish();
			return;
		}

		var item = queue[index];
		label.text = 'Descargando ${item.name} (${index + 1}/${queue.length})';
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

	function finish():Void
	{
		done = true;
		if (failed.length > 0)
		{
			label.text = 'No se pudo bajar: ${failed.join(", ")}. Se sigue sin eso.';
			leaveIn = 2.5;
		}
		else
		{
			label.text = "Listo";
			leaveIn = 0.4;
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
