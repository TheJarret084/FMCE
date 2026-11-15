#!/usr/bin/env bash
# FMCE - compila para Android y verifica el APK resultante.
#
#   bash test.sh                 # compila debug y verifica
#   bash test.sh release         # compila release (firma la keystore si esta)
#   bash test.sh release --no-build   # solo verifica el APK que ya existe
#
# Pensado para Termux (usa building/jarretTools) y para CI/Linux (building/android-build.sh).
# Sale con codigo != 0 si el APK falta, si trae libs armv7/x86 o si alguna .so no es AArch64.
# Ese ultimo chequeo es el que atrapa el bug de libvlc-v7.so enlazado en un binario aarch64.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

MODE=debug
NO_BUILD=0
for arg in "$@"; do
	case "$arg" in
		debug|release) MODE="$arg" ;;
		--no-build) NO_BUILD=1 ;;
		-h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "test.sh: argumento desconocido '$arg' (uso: bash test.sh [debug|release] [--no-build])" >&2; exit 2 ;;
	esac
done

APK="$DIR/building/artifacts/FMCE-Android-$MODE.apk"

fail() { echo "  [FALLA] $*" >&2; exit 1; }
ok()   { echo "  [ok]    $*"; }
step() { echo; echo "==> $*"; }

# Entorno de Termux (SDK/NDK/Haxe propios). En CI no existe y se usa lo del sistema.
if [ -f "$DIR/building/jarretTools/env.sh" ]; then
	# shellcheck disable=SC1091
	. "$DIR/building/jarretTools/env.sh"
fi

if [ "$NO_BUILD" = 0 ]; then
	step "Chequeos previos"
	if [ -f "$DIR/building/jarretTools/doctor.sh" ]; then
		bash "$DIR/building/jarretTools/doctor.sh" || fail "doctor.sh encontro algo que falta"
	fi
	command -v haxe >/dev/null 2>&1 || fail "no hay haxe en el PATH"
	command -v haxelib >/dev/null 2>&1 || fail "no hay haxelib en el PATH"

	step "Compilando Android ($MODE)"
	if [ -f "$DIR/building/jarretTools/build.sh" ]; then
		bash "$DIR/building/jarretTools/build.sh" "$MODE"
	else
		bash "$DIR/building/android-build.sh" "$MODE"
	fi
fi

step "Verificando $APK"
[ -f "$APK" ] || fail "no existe el APK (compilalo con: bash test.sh $MODE)"
ok "APK ($(du -h "$APK" | cut -f1))"

LIST="$(unzip -Z1 "$APK")" || fail "no se pudo leer el APK (unzip)"

# Solo arm64: nada de armeabi-v7a/x86 (el Project.xml excluye armv7 a proposito).
for bad in 'lib/armeabi-v7a/' 'lib/armeabi/' 'lib/x86/' 'lib/x86_64/'; do
	if grep -q "^$bad" <<< "$LIST"; then
		fail "el APK trae $bad; Project.xml debe compilar solo arm64"
	fi
done
ok "sin librerias de 32 bits / x86"

grep -qx 'lib/arm64-v8a/libApplicationMain.so' <<< "$LIST" \
	|| fail "falta lib/arm64-v8a/libApplicationMain.so"
ok "libApplicationMain.so arm64 presente"

if grep -qx 'lib/arm64-v8a/libvlc.so' <<< "$LIST"; then
	ok "libvlc.so arm64 presente (hxvlc)"
else
	echo "  [aviso] no hay libvlc.so (compilaste con -DFMCE_NO_VIDEO_ANDROID?)"
fi

# Cada .so de arm64-v8a tiene que ser AArch64 de verdad. Si hxcpp enlaza una lib armv7
# (libvlc-v7.so) el APK se arma igual pero revienta al cargar; aca lo cortamos antes.
READELF="$(command -v llvm-readelf || command -v readelf || true)"
if [ -z "$READELF" ] && [ -n "${ANDROID_NDK_ROOT:-}" ]; then
	for host in "${ANDROID_HOST:-}" linux-x86_64 linux-aarch64 darwin-x86_64; do
		[ -n "$host" ] || continue
		cand="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/$host/bin/llvm-readelf"
		if [ -x "$cand" ]; then READELF="$cand"; break; fi
	done
fi

if [ -n "$READELF" ]; then
	TMP="$(mktemp -d)"
	trap 'rm -rf "$TMP"' EXIT
	while IFS= read -r lib; do
		unzip -p "$APK" "$lib" > "$TMP/lib.so"
		ARCH="$("$READELF" -h "$TMP/lib.so" 2>/dev/null | awk '/Machine:/{print $2, $3}')"
		case "$ARCH" in
			*AArch64*) ;;
			*) fail "$lib no es AArch64 (Machine: ${ARCH:-desconocida})" ;;
		esac
	done < <(grep '^lib/arm64-v8a/.*\.so$' <<< "$LIST")
	ok "todas las .so de arm64-v8a son AArch64"
else
	echo "  [aviso] sin readelf/llvm-readelf: no pude revisar la arquitectura de las .so"
fi

# Datos del paquete, si hay aapt2 (Termux lo instala con `pkg install aapt2`).
AAPT="$(command -v aapt2 || true)"
if [ -z "$AAPT" ] && [ -n "${ANDROID_HOME:-}" ]; then
	AAPT="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -n1 || true)"
fi
if [ -n "$AAPT" ] && [ -x "$AAPT" ]; then
	"$AAPT" dump badging "$APK" 2>/dev/null | grep -m1 '^package:' | sed 's/^/  /' || true
fi

echo
echo "==> OK: $APK"
