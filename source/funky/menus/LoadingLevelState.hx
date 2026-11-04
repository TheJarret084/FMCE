package funky.menus;

import flixel.FlxG;
import flixel.FlxSprite;
import funky.backend.MusicBeatState;
import funky.core.Log;
import funky.core.Paths;
import funky.game.PlayState;
import funky.game.SongData;
import funky.game.SpriteBuilder;
import funky.game.SpriteCache;
import haxe.Timer;
import openfl.Assets as OpenFlAssets;

/**
 * Pantalla previa a cada cancion: lee el chart y precarga los sprites que el nivel usa (`SpriteCache`). Al terminar
 * entra a `PlayState`. Todo lo que abre un nivel pasa por aqui (`PlayState.archivePath` ya fijado), incluidos los
 * reintentos. Los saltos de la pausa (adelantar / retroceder) NO pasan por aqui: ver `PlayState.seekTo`.
 *
 * Look: fondo negro y, abajo a la derecha, la silueta blanca corriendo sobre una barra blanca hasta el microfono.
 * Los PNG van en `assets/images/menus/Loading/` (`runner.png` y `mic.png`); si faltan se dibuja algo simple.
 */
class LoadingLevelState extends MusicBeatState
{
	/** Barra (px del juego): ancho, alto, y lo que queda de margen a la derecha y abajo. */
	static inline var BAR_WIDTH:Int = 300;
	static inline var BAR_HEIGHT:Int = 9;
	static inline var MARGIN_RIGHT:Int = 75;
	static inline var MARGIN_BOTTOM:Int = 57;
	/** Cuanto se separa la silueta de la barra, y lo que salta al correr. */
	static inline var RUNNER_GAP:Int = 17;
	static inline var HOP_HEIGHT:Float = 9;
	static inline var HOP_SPEED:Float = 11;
	/** Segundos de trabajo por frame: lo justo para que la barra siga moviendose. */
	static inline var FRAME_BUDGET:Float = 0.012;

	/** El chart que leyo esta pantalla; `PlayState.create` lo toma para no leerlo dos veces. */
	static var song:Null<SongData> = null;

	/** Deja un chart ya leido para el siguiente PlayState (salto de la pausa: se entra sin loading ni lectura nueva). */
	public static function keep(value:Null<SongData>):Void
	{
		song = value;
	}

	public static function takeSong():Null<SongData>
	{
		var taken = song;
		song = null;
		return taken;
	}

	var track:FlxSprite;
	var fill:FlxSprite;
	var runner:FlxSprite;
	var mic:Null<FlxSprite>;
	var barX:Float = 0;
	var barY:Float = 0;
	var runnerY:Float = 0;
	var clock:Float = 0;
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

		add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF000000));

		var right = FlxG.width - MARGIN_RIGHT;
		barX = right - BAR_WIDTH;
		barY = FlxG.height - MARGIN_BOTTOM;

		// la barra: pista tenue + relleno blanco, con el tope a la izquierda
		track = new FlxSprite(barX, barY).makeGraphic(BAR_WIDTH, BAR_HEIGHT, 0xFFFFFFFF);
		track.alpha = 0.22;
		add(track);

		fill = new FlxSprite(barX, barY).makeGraphic(BAR_WIDTH, BAR_HEIGHT, 0xFFFFFFFF);
		fill.origin.set(0, 0);
		fill.scale.x = 0.001;
		add(fill);

		add(new FlxSprite(barX - 6, barY - 14).makeGraphic(6, 38, 0xFFFFFFFF));

		// el microfono, al final de la barra
		var micPath = Paths.image("menus/Loading/mic");
		if (OpenFlAssets.exists(micPath))
		{
			mic = new FlxSprite().loadGraphic(micPath);
			mic.antialiasing = true;
			mic.setPosition(right - 9, barY - 30);
			add(mic);
		}

		// la silueta, que corre de la izquierda al microfono segun avanza la carga
		var runnerPath = Paths.image("menus/Loading/runner");
		if (OpenFlAssets.exists(runnerPath))
		{
			runner = new FlxSprite().loadGraphic(runnerPath);
			runner.antialiasing = true;
		}
		else
			runner = new FlxSprite().makeGraphic(36, 90, 0xFFFFFFFF);

		runnerY = barY - RUNNER_GAP - runner.height;
		runner.setPosition(barX, runnerY);
		add(runner);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		clock += elapsed;

		if (!finished)
			work();

		// la barra alcanza el valor poco a poco, no a saltos
		shown += (progress - shown) * Math.min(1, elapsed * 12);
		fill.scale.x = Math.max(0.001, shown);

		// la silueta va pegada al avance y salta al correr
		var travel = BAR_WIDTH - runner.width - 6; // al llegar se queda justo antes del microfono
		runner.x = barX + travel * shown;
		runner.y = runnerY - Math.abs(Math.sin(clock * HOP_SPEED)) * HOP_HEIGHT;

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
