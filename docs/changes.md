# Input en ventanas de UI y Android sin Java propio
- `UIState`: el tick "headless" (pantallas que no son un UIState, como la ventana de NUEVO NIVEL del modo avanzado) ahora activa `textInputEnabled` al enfocar un `UITextBox`/`UINumericStepper`. Antes se podia hacer clic pero el teclado no escribia nada.
- `UISubstateWindow.destroy`: limpia el foco al cerrar para que un campo destruido no siga robando el teclado.
- `funky/core/Storage.hx`: usa `extension.androidtools` (`Permissions`, `Settings`, `os.Environment.isExternalStorageManager`) para pedir "Acceso a todos los archivos" en Android 11+ y los permisos normales en versiones viejas.
- Android ya no lleva Java propio en el repo: `extension-androidtools 2.2.2` (ver `building/libs.json`). Se borraron `building/discord-android.sh` y las referencias al Discord Social SDK de Android.
- `LevelCreator`/`LevelCreateScreen`: el chart importado se asocia a la carpeta del nivel nuevo y solo se aplica al abrir ese nivel en el charter.

# Videos de niveles, easter eggs y ventana de nuevo nivel
- `funky/backend/LevelVideoMigrator.hx` (nuevo): normaliza `sprites/<nombre>/config.json` (`type: "video"` y una entrada `data[]` por `.mp4`, con `anim` = nombre del archivo) y deja explicito el indice `video` de los objetos de `scene.json`. Es idempotente y valida cada `.mp4` con `Mp4Info`.
- `CheckerState`: nueva etapa `ScanLevelVideos` que migra/revisa los videos de `levels/` al arrancar. `AdvancedToolsState` tambien revisa el nivel al abrirlo (para niveles importados despues del arranque).
- Niveles del repo migrados: `abuela/sprites/pichazo` (su `anim` decia `tungazo` pero el archivo es `tungaso.mp4`) y los indices `video` de `abuela` y `static`.
- `funky/backend/LevelEasterEggs.hx` (nuevo): 5% de probabilidad de copiar una imagen random de `assets/included/` a `<nivel>/eastereggs/` al crear el nivel.
- Ventana NUEVO NIVEL ampliada: nombre, BPM, carriles, escenario y "copiar nivel de ejemplo". `LevelCreator.createWithOptions(...)` mantiene `create(nombre, sprites)` para los llamados viejos.
- Menu del modo avanzado: NUEVO NIVEL ahora es verde con el icono `editors/new` (como Codename).
- Charter en vivo: el escenario se inserta detras de la grilla (`charter.insert(1, stage)`) y el menu Ver agrega "Oscurecer escenario (0-80%)" para que nunca tape la zona de chartear.

# Cambios (optimizacion)
- PlayState: sin closures nuevas por frame; teclas por carril consultadas 1 vez por frame (antes 1 por nota).
- Note: los holds ya no recalculan escala/updateHitbox cada frame (solo si cambia).
- Stage: sin Map.keys() cuando nadie canta; sin objeto nuevo por objeto/frame en apply(); updateHitbox solo si cambia.
- SpritePages: acepta frames que reusan celdas de otra pagina (orden original de frames).
- Video -> spritesheet: VideoSheet.hx + modo sheet en VideoStripTask + menu Sprite > "Convertir video a spritesheet..." en el editor.
- Requiere FunkFMPEG 1.4.10 (git fijado al tag en `building/libs.json`).

# Charter en vivo (Seamless Charter nativo) + logs
- Nuevo funkin/editors/charter/CharterPreview.hx: escenario (scene.json), objetos y eventos en vivo detras de la grilla; las notas hacen cantar a su strumline. Sin PlayState, sin cambiar de pantalla.
- Pantalla de carga (LoadingOverlay) mientras se arma el escenario del charter.
- Menu Chart: ENTER / SHIFT+ENTER = vista previa interna. Jugar de verdad con PlayState: ALT+ENTER / ALT+SHIFT+ENTER (y los de oponente igual que antes).
- Menu Ver: "Mostrar escenario en vivo" y "Ocultar / mostrar interfaz" (TAB).
- LogOverlay: por defecto solo errores/avisos/notas (los [LOG] normales ya no salen en pantalla, siguen en latest.log), max 3 a la vez, logs repetidos se agrupan (xN), espaciados 0.35 s. F2: normal -> todo -> apagado.

# Nuevo nivel con id + nombre desde la meta
- funky/backend/LevelId.hx (nuevo): carpeta = `<nombre>_<id>`, id = base64 url-safe del timestamp de creacion (ms). Tambien lee el displayName de meta.json.
- funky/backend/LevelCreator.hx (nuevo): crea el nivel (meta.json + plantilla de assets/included + sprites de default.zip).
- advanced/LevelCreateScreen.hx (nuevo): ventana "Nuevo nivel" que pide el nombre. En el menu del modo avanzado: boton NUEVO NIVEL o tecla N.
- Importar .FMCE y convertir .FNMM tambien crean la carpeta con id y dejan displayName/id/created en meta.json (un .FMCE exportado desde un nivel con id conserva su id).
- Los menus (modo avanzado, herramientas, Freeplay, exportar) muestran el displayName; la carpeta es solo el identificador.
- Idiomas: assets/languages/{es,en}/AdvancedMenus.xml con los textos nuevos.
# Creador de niveles estilo Codename + charter sin bloqueo
- `advanced/LevelCreateScreen.hx`: el flujo de NUEVO NIVEL vuelve a ser un asistente de dos páginas, con nombre interno, BPM, compás, selección de instrumental/voces y opciones de menú (display name, icono, modos, dificultades y color); conserva también escenario, carriles y plantilla de FMCE.
- `funky/backend/LevelCreator.hx`: guarda el audio elegido en `music/` y registra BPM/compás/steps, icono y opciones del menú en `meta.json`. Los datos antiguos siguen siendo compatibles con `create(nombre, sprites)`.
- `LevelLoader`/`Chart`/`SongData`: ahora propagan el display name y el compás al HUD y al charter, en vez de mostrar siempre el nombre interno o forzar 4/4.
- Al crear desde plantilla se ejecuta `LevelVideoMigrator.scanLevel`; `CheckerState` sigue migrando y validando todos los niveles existentes con `Mp4Info` al arrancar.
- `CharterPreview`: la cámara del escenario se inserta realmente al fondo del display list (`FlxG.cameras.insert`) y se elimina al cerrar el charter. La capa ya no queda encima de la grilla ni se filtra a otros estados.
- El icono `+` de NUEVO NIVEL también recibe el mismo tinte verde que el texto.
