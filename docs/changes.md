# Cambios (optimizacion)
- PlayState: sin closures nuevas por frame; teclas por carril consultadas 1 vez por frame (antes 1 por nota).
- Note: los holds ya no recalculan escala/updateHitbox cada frame (solo si cambia).
- Stage: sin Map.keys() cuando nadie canta; sin objeto nuevo por objeto/frame en apply(); updateHitbox solo si cambia.
- SpritePages: acepta frames que reusan celdas de otra pagina (orden original de frames).
- Video -> spritesheet: VideoSheet.hx + modo sheet en VideoStripTask + menu Sprite > "Convertir video a spritesheet..." en el editor.
- Requiere FunkFMPEG 1.2.0 (haxelib dev funkfmpeg <carpeta>).

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