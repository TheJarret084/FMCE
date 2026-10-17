# lista de cosas a terminar

---
(24 sep):

[X] hacer la hitbox más pequeña verticalmente
[X] arreglar la hitbox de las notas
[X] arreglar el input de las notas para que detecte correctamente todas las teclas/lane y no se quede agarrando solamente la key morada
[X] arreglar la conversión del nivel
[X] hacer más decente y usable el formato de meta
[X] revisar y arreglar los sprites del nivel
[X] mejorar el titleScreen sin aplastar/deformar los textos
[X] rehacer el conversor como un State completo, no solo el .py
[X] dejar el nivel completamente jugable después de la conversión
[X] modificar scrollSpeed según dificultad:

  [V] Fácil

  [V] Normal

  [V] Difícil

  [V] Fast

[X] corregir colores de notas idle a un gris decente
[X] en el splash del principio poner los sprites ligeramente mas pequeño
[X] agregar dos tipos nuevos de sprites FlxVideoSprite (sin audio), y FlxAnimatedAtlas (spritemap de adove), con esto importar funkinSprite de codename
[X] arreglar la pausa ya que no trae configuracion, y demas hacer una, ademas de no hacer que no se salga de una vez
[X] arreglar el pitero countdown que creo que lo rompi pero non tengo forma de confirmarlo

---

(6 oct):
- [X] Conversion de niveles: `Null object reference` a medio camino en la 1a pasada (y bien al reanudar).  Ahora los iconos se leen en `open`, la copia sale del archivo ya escrito. Probado con un .fnmm 

- [X] Probar en telefono: permisos de `.JarretLabs-FMCE`

- [ ] limpiar scene y events, a esto refiero abrirlo y no dejarlo aplastado que no se puede leer bien

- [X] Logger tipo legacy.

- [X] Iconos: nunca se voltean (`flipX = false` en `HealthIcon`). Ademas el mapeo de estados estaba corrido (anim0 normal salia como "perdiendo"): ahora anim0 normal, anim1 perdiendo, anim2 ganando.

- [X ] Sprites `fixed` (Stage), error de escalado y de Camara

---

(9 oct):
- [X] Pausa estilo Impostor Legacy.
- [X] Opciones estilo Codename (`funky/menus/options/`): CONTROLES (rebind de carriles), GAMEPLAY, AUDIO, APARIENCIA, MISCELANEA.
- [X] Creditos 
- [X] Menu principal: OPCIONES + CREDITOS; el modo avanzado queda detras de la tecla 7 (tambien desde Opciones).
- [X] Compilar y probar en movil
- [X] GameOverSubState
- [X] poner lo que pidio papas, (el among us bailando en la pausa)

---

(10 oct):

- [X] arreglar sobrecarga de sprites al usar solo un spritesheet demaciado grande
- [ ] pulir en convertidor

---

(13 oct):
- [X] CI Android: faltaba `flixel-addons` (FlxBackdrop / FlxRuntimeShader) en `building/libs.txt` y `Project.xml`.
- [X] Preferencia `SALTAR INTRO` (Opciones > Apariencia): va directo al TITLE; si no, el splash se salta tocando la pantalla / click / tecla.
- [X] Menu principal y Freeplay con la vista de Codename (`BoldText` = fuente bold del atlas).
- [X] Botones arriba/abajo del movil (`NavPad`) rehechos con sprites propios + `TouchNav.hit` (antes `FlxVirtualPad` no respondia). Tocar una fila: la primera vez la selecciona, la segunda entra; el espacio vacio no hace nada.
- [ ] Probar todo esto en CI/telefono (no se compilo al escribirlo).
- [X] Splash: el video ya se escala al llegar `onFormatSetup`, termina al acabar el video (o error / 6 s sin arrancar) y no se salta solo en el primer frame. Video activo en Android (`-DFMCE_NO_VIDEO_ANDROID` lo apaga).
- [X] Freeplay: icono del oponente (meta.json icons.P2 o scene.json icons[0]) a la derecha de cada nivel.
- [X] Android: `latest.log`/`previous.log` van en `<carpeta del juego>/logs` y los crashes en `<carpeta del juego>/crashes` (`.JarretLabs-FMCE`, o `Android/media/<package>` sin permiso), no en la carpeta privada de la app.
