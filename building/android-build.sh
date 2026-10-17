#!/usr/bin/env bash
# FMCE — Android build driver.
#
# CI calls this as:  bash building/android-build.sh <debug|release>
# .github/workflows/android-release.yml depends on the APK landing at
# building/artifacts/FMCE-Android-release.apk with `if-no-files-found: error`,
# so that exact path is part of the CI contract.
#
# Unlike the desktop scripts this one does not take a haxe target: Android is
# always the C++ backend.

set -euo pipefail

BUILD_TYPE="${1:-release}"

case "$BUILD_TYPE" in
	debug|release) ;;
	*)
		echo "android-build.sh: unknown build type '$BUILD_TYPE' (expected: debug or release)" >&2
		exit 2
		;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACT_DIR="$SCRIPT_DIR/artifacts"

cd "$PROJECT_DIR"

# ── Haxe version guard ──────────────────────────────────────────────────────
# FMCE is only tested on Haxe 4.3.7 (CI pins it). Set FMCE_ALLOW_ANY_HAXE=1 to skip.
REQUIRED_HAXE="4.3.7"
if [ "${FMCE_ALLOW_ANY_HAXE:-0}" != "1" ] && command -v haxe >/dev/null 2>&1; then
	FOUND_HAXE="$(haxe --version 2>&1 | head -n1 | tr -d '[:space:]')"
	if [ "$FOUND_HAXE" != "$REQUIRED_HAXE" ]; then
		echo "FMCE needs Haxe $REQUIRED_HAXE but found $FOUND_HAXE." >&2
		echo "Install $REQUIRED_HAXE (or export FMCE_ALLOW_ANY_HAXE=1 to ignore this)." >&2
		exit 1
	fi
fi

# ── Preflight ───────────────────────────────────────────────────────────────
if ! command -v haxe >/dev/null 2>&1; then
	echo "android-build.sh: 'haxe' is not on PATH. Install Haxe 4.3.7 or add it to PATH." >&2
	exit 127
fi

if ! command -v haxelib >/dev/null 2>&1; then
	echo "android-build.sh: 'haxelib' is not on PATH. It ships with Haxe; reinstall Haxe." >&2
	exit 127
fi

# `android-actions/setup-android` exports these, but a local build may not.
if [ -z "${ANDROID_HOME:-}" ] && [ -z "${ANDROID_SDK_ROOT:-}" ]; then
	echo "android-build.sh: neither ANDROID_HOME nor ANDROID_SDK_ROOT is set." >&2
	echo "  Install the Android SDK, or source your shell profile before building." >&2
	exit 1
fi

# Without a licence accepted, lime blocks waiting for interactive input and
# the CI job hangs until it times out rather than failing fast.
if [ -z "${ANDROID_NDK_ROOT:-}" ]; then
	echo "android-build.sh: warning: ANDROID_NDK_ROOT is unset; lime will pick its default NDK." >&2
fi

# `lime setup android` es interactivo (pregunta rutas por stdin), asi que en CI no sirve.
# Lime lee ANDROID_SETUP / ANDROID_SDK / ANDROID_NDK_ROOT / JAVA_HOME del entorno
# (se mezcla con ~/.lime/config.xml), y setup-android solo exporta ANDROID_HOME y
# ANDROID_SDK_ROOT, no los nombres que lime espera.
export ANDROID_SETUP=true
export ANDROID_SDK="${ANDROID_SDK:-${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}}"

if [ -z "${ANDROID_NDK_ROOT:-}" ] || [ ! -d "$ANDROID_NDK_ROOT" ]; then
	# Ultimo NDK instalado bajo el SDK, si el workflow no fijo uno valido.
	NDK_FOUND="$(ls -d "$ANDROID_SDK"/ndk/*/ 2>/dev/null | sort -V | tail -n 1 || true)"
	if [ -z "$NDK_FOUND" ]; then
		echo "android-build.sh: no NDK found (ANDROID_NDK_ROOT='${ANDROID_NDK_ROOT:-}', $ANDROID_SDK/ndk/ empty)." >&2
		exit 1
	fi
	export ANDROID_NDK_ROOT="${NDK_FOUND%/}"
fi
# hxcpp 4.3.2 deduce ANDROID_HOST mirando toolchains/arm-linux-androideabi-*, que solo
# existe en NDK <= r22. Si no lo encuentra cae a "linux-x86" y usa el clang del sistema
# sin sysroot. Se fija a mano desde el NDK real (hxcpp lee las variables de entorno).
if [ -z "${ANDROID_HOST:-}" ]; then
	HOST_FOUND="$(ls -d "$ANDROID_NDK_ROOT"/toolchains/llvm/prebuilt/*/ 2>/dev/null | head -n 1 || true)"
	if [ -n "$HOST_FOUND" ]; then
		HOST_FOUND="${HOST_FOUND%/}"
		export ANDROID_HOST="${HOST_FOUND##*/}"
	fi
fi
echo "==> Android SDK: $ANDROID_SDK"
echo "==> Android host: ${ANDROID_HOST:-(sin detectar)}"
echo "==> Android NDK: $ANDROID_NDK_ROOT"

# Libs, lime build y copia del APK los hace build.sh (comun con escritorio).
exec bash "$SCRIPT_DIR/build.sh" android "$BUILD_TYPE"
