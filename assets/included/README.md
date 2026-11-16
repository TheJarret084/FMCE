# Plantilla de niveles

Estos archivos se copian al crear un level nuevo (pantalla NUEVO NIVEL). Todo esta en el formato FMCE real:

- `chart.json`, `events.json`, `scene.json`: nivel vacio.
- `default.zip`: nivel de ejemplo (scene, events y sprites: bg, player, enemy, icon1, icon2).
- `default_sprite_packs/*.zip`: sprites sueltos para el administrador de sprites (bg, character, icon, item).

Cada sprite es `sprite.png` (+ `sprite_pN.png` si hay mas de una pagina) + `sprite.json` (fmce-sprite compacto) + `config.json`
(`type`, `bilinear` y una entrada por animacion con `anim`, `spd` en fps, `loop`, `scale`, `offset`).
