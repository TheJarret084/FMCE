#!/usr/bin/env bash
# Baja los ndll precompilados de FunkFMPEG desde su release de GitHub (no se compila nada).
#   bash building/fetch-funkfmpeg.sh <linux-x64|windows-x64|android-arm64> <carpeta-ndll-destino>
# El tag sale de building/libs.json (ref de funkfmpeg). Si ya esta bajado ese tag, no hace nada.
set -euo pipefail

NAME="${1:?uso: $0 <linux-x64|windows-x64|android-arm64> <destino>}"
DEST="${2:?uso: $0 <plataforma> <carpeta-ndll-destino>}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || { echo "fetch-funkfmpeg: falta python3" >&2; exit 127; }

TAG="${FUNKFMPEG_TAG:-$("$PY" -c "import json;print(next(x['ref'] for x in json.load(open('$DIR/libs.json'))['dependencies'] if x['name']=='funkfmpeg'))")}"
REPO="${FUNKFMPEG_REPO:-TheJarret084/FunkFMPEG}"
URL="https://github.com/$REPO/releases/download/$TAG/funkfmpeg-ndll-$NAME.zip"
MARK="$DEST/.release-$NAME"

if [ -f "$MARK" ] && [ "$(cat "$MARK")" = "$TAG" ]; then
	echo "==> FunkFMPEG $TAG ($NAME) ya esta en $DEST"; exit 0
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo "==> FunkFMPEG $TAG ($NAME): $URL"
ok=0
for i in 1 2 3 4; do
	if curl -fL --retry 2 -o "$TMP/ndll.zip" "$URL"; then ok=1; break; fi
	echo "   intento $i fallo; reintento en 10s"; sleep 10
done
[ "$ok" = 1 ] || { echo "fetch-funkfmpeg: no se pudo bajar $URL (existe el release $TAG con ese asset?)" >&2; exit 1; }

mkdir -p "$DEST"
if command -v unzip >/dev/null; then unzip -q -o "$TMP/ndll.zip" -d "$DEST"
else "$PY" -c "import zipfile,sys;zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP/ndll.zip" "$DEST"; fi
printf '%s' "$TAG" > "$MARK"
echo "==> FunkFMPEG $TAG listo en $DEST"
