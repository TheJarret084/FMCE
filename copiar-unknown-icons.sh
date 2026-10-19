#!/bin/sh
# Copia Unknown.png con el nombre de cada evento que aun no tenga icono propio.
# Uso (desde la raiz del proyecto):  sh copiar-unknown-icons.sh        -> solo crea los que faltan
#                                    sh copiar-unknown-icons.sh -f     -> pisa tambien los que ya existen
DIR="assets/images/editors/charter/event-icons"
[ -f "$DIR/Unknown.png" ] || { echo "No existe $DIR/Unknown.png"; exit 1; }
for n in CameraSet CameraZoom CameraShake ObjectPositionSet ObjectVisibilitySet ObjectOpacitySet ObjectAnimationSet ObjectSpriteSet ObjectChartChange BarIconChange ScreenFlash RunActionPack PlayerHealth GUI; do
	if [ "$1" = "-f" ] || [ ! -f "$DIR/$n.png" ]; then
		cp "$DIR/Unknown.png" "$DIR/$n.png" && echo "$n.png"
	fi
done
