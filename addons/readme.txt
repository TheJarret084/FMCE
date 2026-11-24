CARPETA DE ADDONS - FMCE

Aqui vive lo que NO va dentro de assets.pack: extensiones que el juego carga siempre
(a diferencia de un mod, que se activa o desactiva) y recursos que necesitan ser archivos reales.

  addons/
    hudskins/<id>/data/hudSkin.xml       configuracion completa del HUD
    hudskins/<id>/data/hudSkin.hx        script opcional del skin (shaders, tweens...)
    hudskins/<id>/images/NOTE_assets.*   atlas Sparrow de notas (.png + .xml)
    hudskins/<id>/images/NOTE_splashes.* atlas Sparrow de salpicaduras
    hudskins/<id>/images/game/score/*    imagenes de rating y numeros del combo
    hudskins/<id>/fonts/*                fuentes del HUD
    hudskins/<id>/shaders/*.frag         shaders propios del skin (opcional)
    videos/*.mp4                         videos (hxvlc no puede leer de un .pack)

hudSkin.xml controla fuentes, colores, tamanos, alineacion y rutas de assets del HUD.
El TEXTO NO se cambia ahi: lo decide la traduccion (assets/languages/<idioma>/).
La barra de vida y los icons NO se tocan desde el HUD skin.

Donde se buscan (el externo gana, asi puedes reemplazar uno que trae el juego):
  1. Carpeta externa: addons/ junto al ejecutable (escritorio) o .JarretLabs-FMCE/addons/ (Android)
  2. Lo que trae el build (Project.xml mete esta carpeta)

Un hud skin nuevo = copiar su carpeta a addons/hudskins/
Detalles: docs/addons-y-pack.md
