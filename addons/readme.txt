CARPETA DE ADDONS - FMCE

Aqui vive lo que NO va dentro de assets.pack: extensiones que el juego carga siempre
(a diferencia de un mod, que se activa o desactiva) y recursos que necesitan ser archivos reales.

  addons/
    noteskins/<id>/data/noteSkin.xml      configuracion del skin
    noteskins/<id>/images/NOTE_assets.*   atlas Sparrow (.png + .xml)
    videos/<nombre>.mp4                   videos (hxvlc no puede leer de un .pack)

Donde se buscan (el externo gana, asi puedes reemplazar uno que trae el juego):
  1. Carpeta externa: addons/ junto al ejecutable (escritorio) o .JarretLabs-FMCE/addons/ (Android)
  2. Lo que trae el build (Project.xml mete esta carpeta)

Una noteskin nueva = copiar su carpeta a addons/noteskins/
.Detalles: DOCS/addons-y-pack.md
