package funky.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.ui.FlxBar;
import flixel.ui.FlxBar.FlxBarFillDirection;
import funky.backend.MusicBeatState;
import funky.core.Log;
import funky.game.PlayState;
import funky.game.SongData;
import funky.game.SpriteBuilder;
import funky.game.SpriteCache;
import haxe.Timer;

/**
 * Pantalla previa a cada cancion: lee el chart y precarga los sprites que el nivel usa (`SpriteCache`) mientras
 * una `FlxBar` al fondo avanza. Al terminar entra a `PlayState`. Todo lo que abre un nivel pasa por aqui
 * (`PlayState.archivePath` ya fijado), incluidos los reintentos.
 */
class LoadingLevelState extends MusicBeatState
{
	static inline var BAR_WIDTH:Int = 640;
	static inline var BAR_HEIGHT:Int = 18;
	/** Segundos de trabajo por frame: lo justo para que la barra siga moviendose. */
	static inline var FRAME_BUDGET:Float = 0.012;

	/** El chart que leyo esta pantalla; `PlayState.create` lo toma para no leerlo dos veces. */
	static var song:Null<SongData> = null;

	public static function takeSong():Null<SongData>
	{
		var taken = song;
		song = null;
		return taken;
	}

	var bar:FlxBar;
	var shown:Float = 0;
	var progress:Float = 0;
	var names:Array<String> = [];
	var levelDir:Null<String> = null;
	var read:Bool = false;
	var next:Int = 0;
	var finished:Bool = false;
	var leaving:Bool = false;

	override public function create():Void
	{
		super.create();

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF151722));

		var barX = (FlxG.width - BAR_WIDTH) / 2;
		var barY = FlxG.height - 70;

		var label = new FlxText(0, barY - 44, FlxG.width, "Cargando Nivel...", 28);
		label.alignment = FlxTextAlign.CENTER;
		add(label);

		bar = new FlxBar(barX, barY, FlxBarFillDirection.LEFT_TO_RIGHT, BAR_WIDTH, BAR_HEIGHT, null, "", 0, 1, true);
		bar.createFilledBar(0xFF2A2D3E, 0xFF64DDAA, true, 0xFF000000);
		bar.numDivisions = BAR_WIDTH;
		bar.value = 0;
		add(bar);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!finished)
			work();

		// la barra alcanza el valor poco a poco, no a saltos
		shown += (progress - shown) * Math.min(1, elapsed * 12);
		bar.value = shown;

		// entra al juego (con cortina, la abre PlayState) cuando la barra ya se vio llena
		if (finished && shown > 0.98 && !leaving)
		{
			leaving = true;
			// el cambio de estado hace FlxG.bitmap.clearCache(): que no encuentre las imagenes precargadas
			SpriteCache.detach();
			transitionTo(new PlayState());
		}
	}

	function work():Void
	{
		var start = Timer.stamp();

		// Frame 1: el chart (de ahi sale la carpeta del nivel).
		if (!read)
		{
			read = true;
			try
			{
				song = SongData.fromPath(PlayState.archivePath);
				levelDir = song.levelDir;
			}
			catch (error:Dynamic)
			{
				// PlayState vuelve a leerlo y muestra el error.
				Log.warn('[LoadingLevelState] no se pudo leer el nivel: ' + Std.string(error));
				song = null;
			}

			if (levelDir == null)
			{
				finish();
				return;
			}

			SpriteCache.begin(levelDir);

			// Solo lo que el nivel nombra, y que exista en sprites/ (evita cargar GBs de sprites sin usar).
			var present = SpriteBuilder.listSprites(levelDir);
			names = [for (name in SpriteCache.referenced(song)) if (present.indexOf(name) >= 0) name];
			progress = 0.05;
			return;
		}

		// Un sprite tras otro hasta gastar el presupuesto del frame.
		while (next < names.length)
		{
			var name = names[next++];

			// los videos no se precargan (los abre Stage al usarlos)
			if (SpriteBuilder.videoCount(levelDir, name) == 0)
			{
				try
				{
					SpriteCache.preload(levelDir, name);
				}
				catch (error:Dynamic)
				{
					Log.warn('[LoadingLevelState] fallo precargando "' + name + '": ' + Std.string(error));
				}
			}

			progress = 0.05 + 0.95 * (next / names.length);

			if (Timer.stamp() - start >= FRAME_BUDGET) break;
		}

		if (next >= names.length)
			finish();
	}

	function finish():Void
	{
		Log.info('[LoadingLevelState] sprites precargados: ' + names.length + ' (' + names.join(', ') + ')');
		finished = true;
		progress = 1;
	}
}
