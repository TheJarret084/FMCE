# Eventos (`events.json`)

Todo lo de la cancion (eventos, `action_packs`, bpm) sale de `SongData`. `time` esta en segundos tal cual
viene en el archivo y se compara con el tiempo de la musica. Las duraciones (`transitionTime`, `duration`,
`delay`) traen su unidad (`seconds`, `beats` o `steps`). Cada transicion arranca en el tiempo DEL EVENTO,
no del frame en que se detecto. `object` = indice en `scene.json > objects`. Los numeros llegan como Float.

| Tipo | Props | Que hace |
| --- | --- | --- |
| `CameraSet` | `mode`, `target`, `transitionTime`, `transitionTimeUnit`, `easingType` | Mueve la camara al punto `target` de `scene.json > cameras` (`mode` "auto" y "focus" hacen lo mismo). |
| `CameraZoom` | `value`, `transitionTime`, `transitionTimeUnit`, `easingType` | Cambia `stage.zoomMul`. |
| `CameraShake` | `shakes`, `delay`, `timeUnit`, `strength` | `shakes` sacudidas, una cada `delay`; `strength` en pixeles. |
| `ObjectPositionSet` | `object`, `transform`, `transitionTime`, `transitionTimeUnit`, `easingType` | Lleva el objeto a `transform[i]` (x, y, escala y scrollFactor). |
| `ObjectVisibilitySet` | `object`, `value` | Muestra u oculta. |
| `ObjectOpacitySet` | `object`, `value`, `transitionTime`, `transitionTimeUnit`, `easingType` | Cambia la opacidad. |
| `ObjectAnimationSet` | `object`, `anim` | `anim` = posicion de la animacion en el sprite original (0 = idle). En un video, el numero de video. |
| `ObjectSpriteSet` | `object`, `sprite` | Cambia el sprite del objeto por otro de `sprites/` del nivel. |
| `ObjectChartChange` | `object`, `chart` | Cambia la strumline a la que responde el objeto (-1 ninguna, 0 jugador, 1 oponente). |
| `BarIconChange` | `target`, `sprite` | Cambia el icono de la barra de vida (0 = oponente, 1 = jugador). |
| `ScreenFlash` | `color_r`, `color_g`, `color_b`, `alpha`, `duration`, `timeUnit` | Flash de pantalla que se desvanece. |
| `RunActionPack` | `actionPack` | Corre un pack de `action_packs` (puede anidar hasta 8 niveles). |

`ObjectSpriteSet` y `ObjectChartChange` leen tambien nombres alternativos (`spr`, `name`, `value` para el
sprite; `strumLine`, `target`, `value` para el chart). Si falta una prop, el log dice cuales llegaron.

Curvas (`easingType`): `linear`, `quad`, `cube`/`cubic`, `circ`, `sine`, `expo`, `back`, `bounce`, `elastic`.
Sin sufijo usan InOut (bounce y elastic, Out); con sufijo `In`, `Out` o `InOut` (`quadOut`) ese tipo.
`default`, `Classic` o vacio usan la curva base (`cubeOut`).
