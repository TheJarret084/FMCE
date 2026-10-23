#!/usr/bin/env bash
# FMCE - build para Linux / macOS (y Android, via android-build.sh).
#
#   bash building/build.sh <hl|cpp|android> <debug|release> [args extra para lime]
#
# Hace todo: instala las libs de building/libs.txt, compila con lime y deja el resultado en
#   building/artifacts/FMCE-<OS>-x64-<target>-<type>.zip   (hl / cpp)
#   building/artifacts/FMCE-Android-<type>.apk             (android)
# El CI depende de esos nombres.
set -euo pipefail

KIND="${1:-cpp}"; MODE="${2:-release}"
shift $(( $# > 2 ? 2 : $# )) || true

case "$KIND" in hl|cpp|android) ;; *) echo "build.sh: target '$KIND' no valido (hl, cpp, android)" >&2; exit 2;; esac
case "$MODE" in debug|release) ;; *) echo "build.sh: modo '$MODE' no valido (debug, release)" >&2; exit 2;; esac

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR/.."
ART="building/artifacts"

[ -f building/alsoft.txt ] || { echo "build.sh: falta building/alsoft.txt (Project.xml lo copia al build)" >&2; exit 1; }
command -v haxe >/dev/null && command -v haxelib >/dev/null || { echo "build.sh: haxe/haxelib no estan en PATH (Haxe 4.3.7)" >&2; exit 127; }

# Haxe 4.3.7 es la version probada. FMCE_ALLOW_ANY_HAXE=1 para saltarlo.
FOUND="$(haxe --version 2>&1 | head -n1 | tr -d '[:space:]')"
if [ "${FMCE_ALLOW_ANY_HAXE:-0}" != "1" ] && [ "$FOUND" != "4.3.7" ]; then
	echo "build.sh: FMCE necesita Haxe 4.3.7 y hay $FOUND (o exporta FMCE_ALLOW_ANY_HAXE=1)" >&2; exit 1
fi

# ── Librerias ───────────────────────────────────────────────────
echo "==> Dependencias (building/libs.txt)"
while read -r name ver url ref; do
	case "$name" in ""|\#*) continue;; esac
	if [ "$ver" = "git" ]; then
		haxelib list "$name" 2>/dev/null </dev/null | grep -q "\\[git:$url" && continue
		echo "   instalando $name (git)"
		haxelib git "$name" "$url" ${ref:+"$ref"} --always >/dev/null </dev/null || { echo "build.sh: no se pudo instalar $name (git)" >&2; exit 1; }
	elif [ -n "$ver" ]; then
		haxelib list "$name" 2>/dev/null </dev/null | grep -q "\[$ver\]" && continue
		echo "   instalando $name $ver"
		haxelib install "$name" "$ver" --always >/dev/null 2>&1 </dev/null || haxelib install "$name" --always >/dev/null </dev/null || { echo "build.sh: no se pudo instalar $name $ver" >&2; exit 1; }
		haxelib set "$name" "$ver" >/dev/null 2>&1 </dev/null || true
	else
		haxelib path "$name" >/dev/null 2>&1 </dev/null && continue
		echo "   instalando $name"
		haxelib install "$name" --always >/dev/null </dev/null || { echo "build.sh: no se pudo instalar $name" >&2; exit 1; }
	fi
done < building/libs.txt

# ── Compilar ────────────────────────────────────────────────────
case "$KIND" in
	android) PLATFORM=android;;
	*) case "$(uname -s)" in Darwin) PLATFORM=mac;; *) PLATFORM=linux;; esac;;
esac

ARGS=(build "$PLATFORM")
[ "$KIND" = hl ] && ARGS+=(-hl)
EFFECTIVE="$MODE"
if [ "$KIND" = android ] && [ "$MODE" = release ] && [ ! -f building/android.keystore ]; then
	# Sin keystore lime no firma el release y un APK sin firmar no se instala: sale firmado en debug.
	echo "==> sin building/android.keystore: APK debug firmado (ver building/README.md)"
	ARGS+=(-debug); EFFECTIVE=debug
elif [ "$MODE" = debug ]; then
	ARGS+=(-debug)
fi

echo "==> FMCE $KIND $MODE ($PLATFORM)"
# Rich Presence (Discord Social SDK): las .so del .aar para el enlace de hxcpp
[ "$KIND" = android ] && bash building/discord-android.sh
haxelib run lime "${ARGS[@]}" "$@"

# ── Empaquetar ──────────────────────────────────────────────────
BUILD="export/$EFFECTIVE"
BIN="$BUILD/$([ "$KIND" = hl ] && echo hl || echo "$PLATFORM")/bin"
[ -d "$BIN" ] || BIN="$(ls -d "$BUILD"/*/bin 2>/dev/null | head -n1 || true)"
[ -n "$BIN" ] && [ -d "$BIN" ] || { echo "build.sh: lime termino bien pero no hay carpeta bin en $BUILD" >&2; exit 1; }

mkdir -p "$ART"
if [ "$KIND" = android ]; then
	# Gradle deja el APK bien adentro (bin/app/build/outputs/apk/<tipo>/): se busca en todo el arbol,
	# y si hay varios (debug y release de builds viejos) gana el mas reciente.
	APK="$(find "$BIN" -name '*.apk' -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2- || true)"
	if [ -z "$APK" ]; then
		echo "build.sh: no se genero ningun APK bajo $BIN. Contenido:" >&2
		find "$BIN" -maxdepth 4 | head -40 >&2
		exit 1
	fi
	OUT="$ART/FMCE-Android-$MODE.apk"
	cp "$APK" "$OUT"
else
	case "$(uname -s)" in Darwin) OS=MacOS;; *) OS=Linux;; esac
	OUT="$PWD/$ART/FMCE-$OS-x64-$KIND-$MODE.zip"
	rm -f "$OUT"
	( cd "$BIN" && zip -r -q "$OUT" . )
fi
echo "==> Listo: $OUT"
