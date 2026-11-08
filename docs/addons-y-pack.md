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
