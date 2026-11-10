# Scripts de nivel

Los scripts son `.hx` (hscript) y se cargan de `<nivel>/data/scripts/*.hx`, en orden alfabetico (la carpeta vieja `<nivel>/scripts/` se sigue leyendo despues, para no romper niveles viejos). Cada script
define funciones con el nombre del callback y el engine las llama. Si un script falla, el error sale en el
log una sola vez y el juego sigue.

## Instalar la dependencia

FMCE usa **hscript-improved** (el fork de Codename, con clases, `import` y `using`), no el `hscript` normal.
Ya viene puesto en:

- `building/libs.txt`: `hscript-improved git https://github.com/CodenameCrew/hscript-improved.git codename-dev`
  (`build.sh` y `build.bat` saben instalar lineas `git`).
- `Project.xml`: `<haxelib name="hscript-improved" />`, `<define name="CUSTOM_CLASSES" />` y `<haxedef name="hscriptPos" />`.
- `source/hscript/Config.hx`: que clases del juego se pueden extender desde un script.

Si tenias el `hscript` normal instalado, desinstalalo (`haxelib remove hscript`): comparten paquete y chocan.

## Variables globales

`game` (PlayState), `song`, `levelDir`, `stage`, `eventos`, `hud`, `playerLine`, `opponentLine`
(las ultimas existen a partir de `onCreatePost`; antes valen null), `countdownTick` (dentro de
`onCountdownTick`), y las clases `FlxG`, `FlxSprite`, `FlxText`, `FlxTween`, `FlxEase`, `FlxTimer`,
`FlxColor` (constantes y `fromRGB`/`fromString`), `Math`, `Std`, `StringTools`, `Reflect`, `Json`,
`Paths`, `Conductor`, `ClientPrefs`, `Log`, `Stage`.

### Objetos del stage: `Stage.get`

- `Stage.get("bg")` busca el objeto por su `spr` (la carpeta del sprite en `sprites/`; el primero con ese nombre).
- `Stage.get(2)` lo busca por su numero en `scene.json > objects` (el mismo numero que usan los eventos y el editor de escena).
- `Stage.getAll("bg")` devuelve todos los objetos con ese `spr`; `Stage.sprite("bg")` devuelve directo el sprite (`LevelSprite`).
- Devuelve un `StageObject` (o `null` si no existe): `x`, `y`, `scale`, `scaleY`, `opacity`, `shown`, `fixed`, `scrollX/scrollY`, `transforms`, `name`, `id` y `sprite`. El stage los aplica cada frame, asi que
  `Stage.get("bg").x += 10;` o `Stage.get(0).opacity = 0.5;` basta. Existe desde `onCreatePost`; antes `Stage.get` devuelve `null`.

Funciones: `debugPrint(...)` / `trace(...)` (van al log), `setVar(nombre, valor)` / `getVar(nombre)`
(compartir datos entre scripts), y las constantes `Function_Continue` / `Function_Stop`.

Desde `game` se puede usar lo publico de PlayState: `game.add(sprite)`, `game.score`, `game.combo`,
`game.misses`, `game.songTime`, `game.startCountdown(true)`, `game.endSong(true)`.

## Callbacks

Los que se pueden cancelar devolviendo `Function_Stop` estan marcados con (stop).

| Callback | Cuando |
| --- | --- |
| `onLoad()` | Con todos los scripts ya cargados, antes de crear nada. |
| `onCreatePost()` | Al final de `create`: todo existe. |
| `onAddSpriteGroups()` | Despues de agregar stage y strumlines, antes del HUD. |
| `onStartCountdown()` (stop) | Antes de la cuenta regresiva. Si cancelas, empiezala tu con `game.startCountdown(true)`. |
| `onCountdownStarted()` | Cuando la cuenta queda programada. |
| `onCountdownTick()` | En cada cuenta (3, 2, 1, GO); el numero esta en `countdownTick` (0..3). |
| `onSongStart()` | Cuando arranca la musica. |
| `preReceptorGeneration(strumLine, lane)` / `postReceptorGeneration()` | Antes de crear cada receptor y al terminar la strumline. |
| `onEventPush(evento)` | Una vez por evento de `events.json` al cargar. |
| `onEvent(tipo, props, tiempoMs)` (stop) | Antes de ejecutar cada accion de evento; si cancelas, el engine no la ejecuta. |
| `onMoveCamera(destino)` | Cuando `CameraSet` mueve la camara; `destino` = indice del punto de camara. |
| `onSubstateOpen()` / `onSubstateClose()` | Al abrir / cerrar un substate (pausa, game over). |
| `onPause()` (stop) / `onResume()` | Al pausar y al reanudar. |
| `onUpdate(elapsed)` / `onUpdatePost(elapsed)` | Cada frame, antes y despues de actualizar el state. |
| `onSpawnNote(nota)` / `onSpawnNotePost(nota)` | Al aparecer la cabeza de una nota (las piezas de sustain no). |
| `onKeyPress(lane)` / `onKeyRelease(lane)` | Al presionar / soltar una lane del jugador. |
| `onGhostTap(lane)` | Presionar una lane sin nota al alcance (no resta nada). |
| `goodNoteHitPre(nota)` / `goodNoteHit(nota)` | Antes / despues de que el jugador acierte una nota. |
| `opponentNoteHitPre(nota)` / `opponentNoteHit(nota)` | Igual para el oponente (cabezas de nota). |
| `onPopUpScore(nota, rating)` / `onPopUpScorePost(nota, rating)` | Antes / despues de mostrar el rating (`sick`, `good`, `bad`, `shit`). |
| `noteMiss(nota)` | Nota fallada o sustain soltado. |
| `onUpdateScore(missed)` / `onRecalculateRating()` | Cuando cambia el marcador. |
| `onGameOver()` (stop) | Vida en 0; si cancelas no hay game over (tu subes la vida). |
| `onEndSong()` (stop) | Termina la cancion. Si cancelas, termina despues con `game.endSong(true)`. |
| `onStepHit()` / `onBeatHit()` / `onSectionHit()` | Cada step y cada beat; una seccion = 4 beats. Usa `Conductor.currentStep` / `currentBeat`. |
| `onDestroy()` | Al salir del nivel. |

## Sin equivalente en este engine

`preModifierRegister`, `postModifierRegister` (no hay modcharts), `eventEarlyTrigger`,
`noteMissPress` (pulsar de mas no penaliza), `extraNoteHitPre` / `extraNoteHit` (solo hay dos
strumlines), `onGhostAnim` y `onSpawnNoteSplash` (aun no hay splashes). Si las defines no pasa nada,
simplemente no se llaman.

## Ejemplo

```haxe
function onCreatePost()
{
	debugPrint('nivel ' + song.name + ' listo');
}

function onBeatHit()
{
	if (Conductor.currentBeat % 4 == 0)
		FlxG.camera.zoom += 0.03;
}

function onGameOver()
{
	if (game.misses < 3) { hud.health = 1; return Function_Stop; }
}
```

## Clases propias (como en Codename)

Las clases van en `<nivel>/source/` (**no** en `data/scripts/`: todo lo de `data/scripts/` se ejecuta solo). Se traen con `import`:

`levels/MiNivel/source/jefe/Boss.hx`
```haxe
package jefe;

class Boss extends FunkinSprite
{
	public var vida:Int = 100;

	public function new(x:Float, y:Float)
	{
		super(x, y);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		y += Math.sin(Conductor.songPosition / 500) * 0.5;
	}

	public function golpe(dano:Int)
	{
		vida -= dano;
		playAnim("hit", true);
	}
}
```

`levels/MiNivel/data/scripts/main.hx`
```haxe
import jefe.Boss;

var boss;

function onCreatePost()
{
	boss = new Boss(400, 200);
	game.add(boss);
}
```

- Se pueden extender `FlxSprite` y todo `flixel.*`, `FunkinSprite` y `LevelSprite`. Para permitir mas clases agregalas a
  `ALLOWED_CUSTOM_CLASSES` en `source/hscript/Config.hx`.
- `import flixel.FlxCamera;` y similares: las clases comunes ya estan como globales. Para importar *cualquier* clase de
  Flixel/OpenFL compila con `-DFMCE_FULL_IMPORTS` (desactiva el DCE; tarda bastante mas).
- Los `static` de las clases se comparten entre todos los scripts del nivel. `public var` de un script tambien (son
  los mismos de `setVar` / `getVar`).
- `#if android ... #end`, `#if desktop`, `#if mobile`, `#if debug` funcionan dentro de los scripts.

## Archivos del nivel: `Paths.File(que, tipo)`

`Paths.File` devuelve la ruta de cualquier archivo **dentro del nivel**. El primer valor dice *que es* (el nombre, con
subcarpetas si hace falta) y el segundo *de que tipo es*; con eso se arma la carpeta y la extension. El nivel es el que
se esta jugando (no hay que pasar `levelDir`).

```haxe
Paths.File("boss", "sprite");          // <nivel>/sprites/boss
Paths.File("boss/sprite", "sprite");   // <nivel>/sprites/boss/sprite   (el spritemap de un atlas)
Paths.File("golpe", "sound");          // <nivel>/sounds/golpe.ogg
Paths.File("intro/corte", "video");    // <nivel>/videos/intro/corte.mp4   (subcarpetas: lo de adentro)
Paths.File("blur", "shader");          // <nivel>/shaders/blur.frag
Paths.File("config", "json");          // <nivel>/data/config.json
Paths.File("main", "script");          // <nivel>/data/scripts/main.hx
Paths.File("mapa", "niveles");         // <nivel>/niveles/mapa   (tipo desconocido = esa carpeta)
Paths.File("data/algo.txt");           // <nivel>/data/algo.txt  (sin tipo: desde la raiz del nivel)
```

| Tipo | Carpeta | Extension |
| --- | --- | --- |
| `sprite` | `sprites/` | (carpeta) |
| `image` | `images/` | `.png` |
| `sound` / `music` | `sounds/` / `music/` | `.ogg` |
| `video` | `videos/` | `.mp4` |
| `script` / `source` | `data/scripts/` / `source/` | `.hx` |
| `shader` | `shaders/` | `.frag` |
| `json` / `xml` / `txt` / `data` | `data/` | `.json` / `.xml` / `.txt` / (la que traiga) |
| `font` | `fonts/` | (la que traiga) |

Si el nombre ya trae extension no se le agrega otra, y un nombre con `..` se rechaza (no se puede salir del nivel).

Extras:

- `Paths.FileExists(que, tipo)`: `true` si existe en disco.
- `Paths.FileList(tipo, ?subcarpeta)`: nombres (sin extension) de lo que hay en esa carpeta; para `sprite`, las carpetas.
- `Paths.levelSprites()`: los sprites del nivel, los de `config.json` > `"type": "icon"` primero (lo que usa el charter).
- Un tercer parametro opcional (`Paths.File("boss", "sprite", otroNivel)`) apunta a otro nivel.

## Iconos del jugador y del enemigo

Estan en `meta.json` > `icons.P1` (jugador) y `icons.P2` (enemigo); cada uno es el nombre de un sprite del nivel. En el
charter se cambian en **Meta** con un dropdown de los sprites del nivel (`(none)` los quita). En un script, el evento
`BarIconChange` o `hud.iconPlayer.changeIcon("nombre")` / `hud.iconOpponent.changeIcon("nombre")`.

## Spritemaps de Adobe Animate (sprites tipo atlas)

Un sprite de nivel es **atlas** cuando existe `sprites/<nombre>/sprite/Animation.json`. El spritemap se deja tal cual lo
exporto Animate (nunca se modifica) y el `config.json` va afuera de la carpeta `sprite/`:

```
levels/MiNivel/sprites/boss/
├── config.json              <- "type": "atlas", scale, bilinear y data (animaciones)
└── sprite/
    ├── Animation.json
    ├── spritemap1.json
    └── spritemap1.png
```

El `type` `atlas` es uno mas de los tipos (item, character, stage, icon...) y no cambia nada por si mismo: solo
marca el sprite para el futuro SpriteEditor. Convencion de todos los sprites: `anim0` es el idle y `anim1`, `anim2`... las demas (el Stage toca `anim0` en idle y
`anim<lane + 1>` al cantar, por indice). Las animaciones salen del `name` de cada entrada de `data` en `config.json`: ese `name` es el nombre que usa el juego y
tambien el **simbolo o label** del atlas (se prueba primero como simbolo y luego como label). `spd` multiplica 24 fps,
`loop` y `offset` (pivote) funcionan igual que en los sprites normales, y `singLEFT/DOWN/UP/RIGHT` tambien quedan como `anim0..3`.

```json
{ "type": "atlas", "scale": 1, "bilinear": true,
  "data": [ { "name": "idle", "spd": 1, "loop": true, "offset": {"x": 130, "y": 110} },
            { "name": "singLEFT", "spd": 1, "loop": false } ] }
```

Eso cubre escenas y `SpriteBuilder`. Desde un script tambien puedes cargar un spritemap suelto de cualquier carpeta:

```haxe
var boss = new FunkinSprite(300, 200);
boss.loadAnimate(levelDir + "/sprites/boss/sprite");
boss.addAnim("idle", "idle", 24, true);   // 4o param = loop; ultimo param true si es un LABEL del timeline
boss.playAnim("idle");
game.add(boss);
```

Para tener spritemaps empaquetados en el juego (sin nivel), `assets/images/<carpeta>/` + `FunkinSprite.loadSprite("<carpeta>")`.

En Android esto funciona porque `Paths.init()` le agrega a flixel-animate el respaldo de leer del disco
(la libreria solo lo hace en desktop).

## Scripts de noteskin

Aparte de los scripts de nivel, cada skin de notas puede traer su propio `addons/noteskins/<id>/data/noteSkin.hx`.
No se cargan desde `<nivel>/data/scripts/`: son parte del skin y reciben callbacks cuando se crean las notas,
receptores, confirms y splashes. Sirven, por ejemplo, para ponerle un shader de sombra al skin `fmm`.
La lista de callbacks y las ayudas (`shader("...")`, `setShader`, `clearShader`...) estan en
[`addons-y-pack.md`](addons-y-pack.md#scripts-de-noteskin).
