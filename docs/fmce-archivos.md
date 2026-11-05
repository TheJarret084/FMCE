# Niveles `.FMCE` (exportar / importar)


Un `.FMCE` es un **zip normal** con lo que hay dentro de la carpeta del nivel (`meta.json`, `chart.json`, `scene.json`,
`data/`, `sprites/`...). No se guardan las copias de seguridad `.bak` / `.bck`.

## Exportar

Modo avanzado > elige el nivel > icono **EXPORTAR .FMCE**. Crea `exports/<Nivel>.FMCE` (junto al juego; en Android, en la
carpeta de datos de la app) y muestra la ruta completa.

## Importar

Modo avanzado > pantalla de niveles > **IMPORTAR .FMCE** (o la tecla `I`).

- Si hay `.FMCE` sueltos en `levels/`, los importa todos y los mueve a `exports/`.
- Si no hay ninguno y estas en escritorio, abre el selector de archivos.
- En celular: copia el `.FMCE` a la carpeta `levels/` del juego y toca IMPORTAR.

El nivel queda en `levels/<nombre del archivo>/`. Si ese nivel ya existe **no se pisa** (avisa): borralo o renombralo y
vuelve a importar. Si el zip trae todo dentro de una sola carpeta, se le quita. Tiene que traer `meta.json` o `chart.json`.

Como es un zip, se puede abrir con cualquier compresor (renombrandolo a `.zip`) y crear a mano: solo comprime el
contenido de la carpeta del nivel, no la carpeta.

# Niveles `.FNMM` (exportar)

Un `.FNMM` es el formato de Funky Maker: Mobile: un zip con `data.json` (notas por strumline y lane, en segundos),
`events.json`, `scene.json`, `music.ogg` y `sprites/<nombre>/` con tiras `0.png`, `1.png`... y su `sprite.json`.

- Modo avanzado > elige el nivel > **EXPORTAR .FNMM**, o Opciones > Convertidor > modo **exportar**.
- Crea `exports/<Nivel>.FNMM`. Los atlas de FMCE se vuelven a partir en tiras (un frame por celda, con su recorte devuelto a su sitio).
- **`data/` no entra** (scripts y shaders no existen en FNMM): antes de exportar sale el aviso de Codename con la lista de archivos que se ignoran.
- Tampoco entran las voces (`Voices.ogg`), los sprites de video ni los `.bak` / `.bck`.
- Avisos al terminar: `meta.offset` (se suma a las notas), eventos que solo existen en FMCE (`ObjectSpriteSet`, `ObjectChartChange`), sprites sin tag en el atlas.
