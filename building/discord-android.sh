#!/usr/bin/env bash
# FMCE - saca las .so del Discord Social SDK (source/libs/discord/android/discord_partner_sdk.aar) a building/_discord/jni/<abi>/.
# hxcpp las necesita en tiempo de ENLACE (-ldiscord_partner_sdk); en el APK las mete Gradle desde el mismo .aar.
# Lo llama building/build.sh al compilar android. Si no hay .aar, no hace nada (el juego compila sin Rich Presence).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

AAR="source/libs/discord/android/discord_partner_sdk.aar"
OUT="building/_discord"

if [ ! -f "$AAR" ]; then
	echo "==> Discord: no hay $AAR -> compila sin Rich Presence (ver source/libs/discord/README.md)"
	exit 0
fi

if [ ! -f "$OUT/jni/arm64-v8a/libdiscord_partner_sdk.so" ] || [ "$AAR" -nt "$OUT/jni/arm64-v8a/libdiscord_partner_sdk.so" ]; then
	echo "==> Discord: extrayendo .so de $AAR"
	rm -rf "$OUT"
	mkdir -p "$OUT"
	if command -v unzip >/dev/null 2>&1; then
		unzip -q -o "$AAR" 'jni/*' -d "$OUT"
	else
		python3 -c "import sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); [z.extract(n, sys.argv[2]) for n in z.namelist() if n.startswith('jni/')]" "$AAR" "$OUT"
	fi
fi
