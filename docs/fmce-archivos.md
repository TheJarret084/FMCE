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
