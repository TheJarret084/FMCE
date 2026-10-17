╔═══════════════════════════════════════╗
║ CARPETA DE ADDONS — FMCE                    ║
╚═══════════════════════════════════════╝

Este directorio existe por compatibilidad de estructura con Codename Engine.
Todavía NO hay un cargador de addons implementado en FMCE: poner carpetas acá
no hace que el juego las lea.

Un addon esta pensado como una extension que se carga siempre y extiende el
engine, a diferencia de un mod que se puede activar o desactivar.

Estado actual del sistema de addons:

  · No existe IModsAssetLibrary ni ZipFolderLibrary
  · No hay registro de addons al arrancar
  · No hay carga de .zip

Cuando se implemente, el contrato esperado sera:

  📁 addons/
      📁 mi_addon/
          📁 data/
          📁 assets/
