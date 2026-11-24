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
Ver `addons/readme.txt`. HUD skins (`addons/hudskins/<id>/{data,images,fonts,shaders}`) y videos (`addons/videos/`). `funky.backend.addons.Addons` resuelve
cada archivo buscando primero en la carpeta externa y luego en lo que trae el build.
El `<atlas path="..."/>` de un `hudSkin.xml` es el nombre del atlas dentro de **su** carpeta `images/`.

`hudSkin.xml` es la configuracion visual completa: `<assets font="..." scoreDir="..."/>` (fuentes e imagenes del HUD),
`<timeBar .../>` (tamano, colores y estilo en modo Legacy) y `<texts><text id="..." size="..." color="..." .../></texts>`
(fuente, color, borde, tamano y alineacion de cada texto). El contenido de los textos SIEMPRE lo pone
`assets/languages/<idioma>/`; cambiar `id` no cambia las palabras. La barra de vida y los icons no se configuran aqui.


`hudSkin.xml` es la configuracion visual completa: `<assets font="..." scoreDir="..."/>` (fuentes e imagenes del HUD),
`<timeBar .../>` (tamano, colores y estilo en modo Legacy) y `<texts><text id="..." size="..." color="..." .../></texts>`
(fuente, color, borde, tamano y alineacion de cada texto). El contenido de los textos SIEMPRE lo pone
`assets/languages/<idioma>/`; cambiar `id` no cambia las palabras. La barra de vida y los icons no se configuran aqui.


## source/
No hay codigo Java propio: lo nativo de Android (permisos, ajustes, dialogos) lo da el haxelib
`extension-androidtools` (ver `building/libs.json`). No hace falta copiar `.aar`, `.jar` ni nada al repo.

## Tipos de HUD skin (`type` en `<hudSkin>`)
- `sparrow`: atlas completo y ya pintado (notas de colores, colas, receptores). Se dibuja tal cual. Ej: `codename`.
- `rgb`: atlas mascara (rojo = color, verde = brillo, azul = sombra) pintado con `HudRGBShader`. Ej: `default` (FMCE).
- `tint`: atlas claro/gris teñido con un solo color (`FlxSprite.color`). Ej: `fmm` (Funky Maker: Mobile).
Los colores de `rgb` y `tint` salen de `<colors>` del skin o, si no hay, de settings.xml. Sin `type`, `<rgb enabled="false"/>` = sparrow.

## Scripts de HUD skin

Un skin puede traer `addons/hudskins/<id>/data/hudSkin.hx` (o `.hscript`). Se ejecuta una vez al cargar el skin y
recibe callbacks cuando el motor crea las piezas. Sirve para shaders, tweens, escalas, animaciones... lo que se pueda
hacer con un `FlxSprite`.

| Callback | Cuando |
| --- | --- |
| `onLoad()` (o `create()` / `new()`) | Con el skin ya leido. La variable `skin` es el `HudSkin`. |
| `onNoteCreate(nota, lane)` / `onNote(...)` | Cada nota (cabeza, piezas de sustain y final). |
| `onReceptorCreate(strum, lane)` / `onReceptor(...)` | Cada receptor. |
| `onReceptorColor(strum, lane, pressed)` | Al apretar/soltar (en `tint` el receptor limpia su shader; este callback lo vuelve a poner). |
| `onConfirmCreate(sprite, lane)` / `onConfirm(...)` | El sprite del confirm. |
| `onSplashCreate(splash, lane)` / `onSplash(...)` | El splash del SICK. |
| `onUpdate(elapsed)` | Cada frame, mientras se juega. |

Ademas de `FlxG`, `FlxSprite`, `FlxTween`, `FlxEase`, `FlxTimer`, `FlxColor`, `Math`, `Std`, `Log`, `Paths`... hay:

- `shader("nombre")` / `createShader("nombre")`: crea un shader. Busca primero `hudskins/<id>/shaders/<nombre>.frag` y
  despues `assets/shaders/<nombre>.frag`. Devuelve un `FlxRuntimeShader` con `hset(nombre, valor)` / `hget(nombre)`.
- `setShader(sprite, "nombre")` y `clearShader(sprite)`.
- `CustomShader` y `HudSkinShader` para crearlos a mano. `new CustomShader("dropShadow", "hudskins/<id>/shaders")`
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

Los errores del script salen una sola vez en el log con el prefijo `[HudSkin <id>]`; el skin sigue funcionando sin el.
Un `hudSkin.hx` vacio se ignora.

## Scores
`scores.fmsc`: binario ofuscado y firmado (HMAC-SHA256). En Android vive en la carpeta privada de la app. Si se altera, se aparta como `.invalid` y se empieza vacio. El `scores.json` viejo se migra una sola vez.
