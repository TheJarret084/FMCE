# Estructura: `assets.pack`, `addons/` y `source/`

## assets.pack
Todo `assets/` (menos `fonts/` y `*.mp3`) se compila en **un solo archivo**: `building/_pack/assets.pack`.

- Lo arma `python3 building/pack-assets.py` (lo corren `build.sh` / `build.bat` / `android-build.sh` antes de lime). `--verify` lo relee,
  `--list` lista el contenido, `--extract DIR` lo desempaqueta.
- Es reproducible (mismo contenido = mismo `assets.id`). Sin compresion: png/ogg ya vienen comprimidos y asi se lee con `seek`.
- Los IDs son los de siempre (`assets/images/...`): el codigo sigue usando `OpenFlAssets`. `funky.core.AssetPack.mount()` (primera linea de
  `Main`) registra `PackLibrary` como libreria "default"; detras queda la original (fuentes embebidas y `addons/`).
- Escritorio: lee `assets.pack` junto al ejecutable. Android: viaja en el APK y se copia una vez a la carpeta privada de la app
  (se vuelve a copiar si cambia `assets.id`).
- Las fuentes siguen embebidas en el ejecutable (`<assets path="assets/fonts" embed="true"/>`).
- Para iterar sin empaquetar: `-DFMCE_LOOSE_ASSETS` (mete `assets/` suelto, como antes).
- `assets/` sigue siendo la fuente en el repo; el `.pack` es generado (esta en `.gitignore`).

## addons/
Ver `addons/readme.txt`. Noteskins (`addons/noteskins/<id>/{data,images}`) y videos (`addons/videos/`). `funky.core.Addons` resuelve
cada archivo buscando primero en la carpeta externa y luego en lo que trae el build.
El `<atlas path="..."/>` de un `noteSkin.xml` es el nombre del atlas dentro de **su** carpeta `images/`.

## source/
`java/` y `libs/` ahora estan en `source/java/` y `source/libs/` (Project.xml, `DiscordBuild.hx` y `discord-android.sh` ya apuntan ahi).
Recuerda copiar `discord_partner_sdk.aar` a `source/libs/discord/android/`.

## Tipos de noteskin (`type` en `<noteSkin>`)
- `sparrow`: atlas completo y ya pintado (notas de colores, colas, receptores). Se dibuja tal cual. Ej: `codename`.
- `rgb`: atlas mascara (rojo = color, verde = brillo, azul = sombra) pintado con `NoteRGBShader`. Ej: `default` (FMCE).
- `tint`: atlas claro/gris teñido con un solo color (`FlxSprite.color`). Ej: `fmm` (Funky Maker: Mobile).
Los colores de `rgb` y `tint` salen de `<colors>` del skin o, si no hay, de settings.xml. Sin `type`, `<rgb enabled="false"/>` = sparrow.

## Scripts de noteskin

Un skin puede traer `addons/noteskins/<id>/data/noteSkin.hx` (o `.hscript`). Se ejecuta una vez al cargar el skin y
recibe callbacks cuando el motor crea las piezas. Sirve para shaders, tweens, escalas, animaciones... lo que se pueda
hacer con un `FlxSprite`.

| Callback | Cuando |
| --- | --- |
| `onLoad()` (o `create()` / `new()`) | Con el skin ya leido. La variable `skin` es el `NoteSkin`. |
| `onNoteCreate(nota, lane)` / `onNote(...)` | Cada nota (cabeza, piezas de sustain y final). |
| `onReceptorCreate(strum, lane)` / `onReceptor(...)` | Cada receptor. |
| `onReceptorColor(strum, lane, pressed)` | Al apretar/soltar (en `tint` el receptor limpia su shader; este callback lo vuelve a poner). |
| `onConfirmCreate(sprite, lane)` / `onConfirm(...)` | El sprite del confirm. |
| `onSplashCreate(splash, lane)` / `onSplash(...)` | El splash del SICK. |
| `onUpdate(elapsed)` | Cada frame, mientras se juega. |

Ademas de `FlxG`, `FlxSprite`, `FlxTween`, `FlxEase`, `FlxTimer`, `FlxColor`, `Math`, `Std`, `Log`, `Paths`... hay:

- `shader("nombre")` / `createShader("nombre")`: crea un shader. Busca primero `noteskins/<id>/shaders/<nombre>.frag` y
  despues `assets/shaders/<nombre>.frag`. Devuelve un `FlxRuntimeShader` con `hset(nombre, valor)` / `hget(nombre)`.
- `setShader(sprite, "nombre")` y `clearShader(sprite)`.
- `CustomShader` y `NoteSkinShader` para crearlos a mano. `new CustomShader("dropShadow", "noteskins/<id>/shaders")`
  carga un `.frag` del skin; sin carpeta usa `assets/shaders/`.
- Los uniforms se cambian con `hset("_alpha", 0.5)` (no con `shader._alpha = ...`).

Ejemplo (el del skin `fmm`, que le pone una sombra):

```haxe
var sombra;

function onLoad()
{
	sombra = shader("game/dropShadow");
	sombra.hset("_alpha", 0.5);
	sombra.hset("_disx", 4.0);
	sombra.hset("_disy", 4.0);
}

function onNote(note, lane)
{
	note.shader = sombra;
}

function onReceptor(strum, lane)
{
	strum.shader = sombra;
}

function onReceptorColor(strum, lane, pressed)
{
	strum.shader = sombra;
}

function onConfirm(sprite, lane)
{
	sprite.shader = sombra;
}

function onSplash(splash, lane)
{
	splash.shader = sombra;
}
```

Los errores del script salen una sola vez en el log con el prefijo `[NoteSkin <id>]`; el skin sigue funcionando sin el.
Un `noteSkin.hx` vacio se ignora.

## Scores
`scores.fmsc`: binario ofuscado y firmado (HMAC-SHA256). En Android vive en la carpeta privada de la app. Si se altera, se aparta como `.invalid` y se empieza vacio. El `scores.json` viejo se migra una sola vez.
