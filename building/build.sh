#!/usr/bin/env bash
# FMCE - build para Linux / macOS (y Android, via android-build.sh).
#
#   bash building/build.sh <hl|cpp|android|web> <debug|release> [args extra para lime]
#
# Hace todo: instala las libs de building/libs.json, compila con lime y deja el resultado en
#   building/artifacts/FMCE-<OS>-x64-<target>-<type>.zip   (hl / cpp)
#   building/artifacts/FMCE-Web-html5-<type>.zip            (web)
#   building/artifacts/FMCE-Android-<type>.apk              (android)
# El CI depende de esos nombres.
set -euo pipefail

KIND="${1:-cpp}"; MODE="${2:-release}"
shift $(( $# > 2 ? 2 : $# )) || true

case "$KIND" in hl|cpp|android|web) ;; *) echo "build.sh: target '$KIND' no valido (hl, cpp, android, web)" >&2; exit 2;; esac
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
echo "==> Dependencias (building/libs.json)"
PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || { echo "build.sh: falta python3 (necesario para leer building/libs.json)" >&2; exit 127; }
HAXELIB_REPO="$(haxelib config 2>/dev/null | head -n1)"
HAXELIB_REPO="${HAXELIB_REPO:-$HOME/haxelib}"
while IFS=$'\t' read -r type name ver url ref; do
	# '-' marca campos vacios (el tab es whitespace en IFS y read los colapsaria, corriendo version/url/ref)
	[ "$ver" = "-" ] && ver=""; [ "$url" = "-" ] && url=""; [ "$ref" = "-" ] && ref=""
	case "$name" in ""|-|\#*) continue;; esac
	if [ "$type" = "git" ]; then
		if haxelib list "$name" 2>/dev/null </dev/null | grep -q '\[git\]' \
			&& git -C "$HAXELIB_REPO/$name/git" remote get-url origin 2>/dev/null | grep -qxF "$url"; then
			continue
		fi
		echo "   instalando $name (git)"
		if ! haxelib git "$name" "$url" ${ref:+"$ref"} --always </dev/null; then
			echo "   haxelib git falló, intentando clone manual..."
			rm -rf "$HAXELIB_REPO/$name/git"
			mkdir -p "$HAXELIB_REPO/$name"
			if [ -n "$ref" ]; then
				GIT_TERMINAL_PROMPT=0 git clone --recursive --depth 1 --branch "$ref" "$url" "$HAXELIB_REPO/$name/git" </dev/null || { echo "build.sh: no se pudo instalar $name (git)" >&2; exit 1; }
			else
				GIT_TERMINAL_PROMPT=0 git clone --recursive --depth 1 "$url" "$HAXELIB_REPO/$name/git" </dev/null || { echo "build.sh: no se pudo instalar $name (git)" >&2; exit 1; }
			fi
			echo "git" > "$HAXELIB_REPO/$name/.current"
		fi
	elif [ "$type" = "haxelib" ]; then
		if [ -n "$ver" ]; then
			haxelib list "$name" 2>/dev/null </dev/null | grep -q "\[$ver\]" && continue
			echo "   instalando $name $ver"
			haxelib install "$name" "$ver" --always </dev/null || haxelib install "$name" --always </dev/null || { echo "build.sh: no se pudo instalar $name $ver" >&2; exit 1; }
			haxelib set "$name" "$ver" >/dev/null 2>&1 </dev/null || true
		else
			haxelib path "$name" >/dev/null 2>&1 </dev/null && continue
			echo "   instalando $name"
			haxelib install "$name" --always </dev/null || { echo "build.sh: no se pudo instalar $name" >&2; exit 1; }
		fi
	fi
done < <("$PY" -c "import json,sys; d=json.load(open('building/libs.json')); [print('\t'.join([x.get('type','') or '-',x.get('name','') or '-',x.get('version','') or '-',x.get('url','') or '-',x.get('ref','') or '-'])) for x in d.get('dependencies',[])]")

# ── Assets -> assets.pack ───────────────────────────────────────
# assets/ se compila en building/_pack/assets.pack (Project.xml lo mete en el build). -DFMCE_LOOSE_ASSETS lo salta.
if [[ " $* " == *" -DFMCE_LOOSE_ASSETS "* ]]; then
	echo "==> Assets sueltos (-DFMCE_LOOSE_ASSETS): no se arma assets.pack"
else
	PY="$(command -v python3 || command -v python || true)"
	[ -n "$PY" ] || { echo "build.sh: falta python3 (building/pack-assets.py arma assets.pack)" >&2; exit 127; }
	echo "==> Empaquetando assets/ en assets.pack"
	"$PY" building/pack-assets.py --verify
fi

# ── Compilar ────────────────────────────────────────────────────
case "$KIND" in
	android) PLATFORM=android;;
	web) PLATFORM=html5;;
	*) case "$(uname -s)" in Darwin) PLATFORM=mac;; *) PLATFORM=linux;; esac;;
esac

ARGS=(build "$PLATFORM")
[ "$KIND" = hl ] && ARGS+=(-hl)
EFFECTIVE="$MODE"

if [ "$KIND" = android ] && [ "$MODE" = release ]; then
    # Solo se firma con la llave si existe y se puede leer de verdad (building/check-keystore.sh).
    # Si falta, esta danada o los secrets no coinciden, no se aborta: se compila firmado en debug.
    if bash building/check-keystore.sh building/android.keystore; then

        echo "==> Android: usando keystore FMCE (verificado)"

        ARGS+=(
            --certificate-path="$PWD/building/android.keystore"
            --certificate-alias="$ANDROID_KEY_ALIAS"
            --certificate-password="$ANDROID_STORE_PASSWORD"
        )
    else
        echo "==> Sin keystore valido: APK debug firmado (instalable, pero la firma cambia en cada build)"
        ARGS+=(-debug)
        EFFECTIVE=debug
    fi
elif [ "$MODE" = debug ]; then
    ARGS+=(-debug)
fi

echo "==> FMCE $KIND $MODE ($PLATFORM)"

# funkfmpeg: ndll nativo para cpp desktop (no viene precompilado en el repo git).
if [ "$KIND" = "cpp" ]; then
	echo "==> Recompilando ndll funkfmpeg ($PLATFORM)"
	haxelib run lime rebuild funkfmpeg "$PLATFORM" -64 || { echo "build.sh: fallo al recompilar funkfmpeg ndll" >&2; exit 1; }
fi

# Android: hxcpp reutiliza export/<modo>/android/obj entre arquitecturas. Si un build viejo dejo
# Options.txt/HxcppConfig-v7.h de armv7, el siguiente intento arm64 arrastra HXCPP_ARMV7 y acaba
# enlazando libvlc-v7.so contra un binario aarch64 (ld.lld: "incompatible with aarch64linux").
# Se borra solo la configuracion generada: haxe/hxcpp la rehacen con la arquitectura correcta.
if [ "$KIND" = android ]; then
	OBJ="export/$EFFECTIVE/android/obj"
	if [ -d "$OBJ" ]; then
		rm -f "$OBJ/Options.txt" "$OBJ"/HxcppConfig*.h
	fi
fi

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
elif [ "$KIND" = web ]; then
	OUT="$PWD/$ART/FMCE-Web-html5-$MODE.zip"
	rm -f "$OUT"
	( cd "$BIN" && zip -r -q "$OUT" . )
else
	case "$(uname -s)" in Darwin) OS=MacOS;; *) OS=Linux;; esac
	OUT="$PWD/$ART/FMCE-$OS-x64-$KIND-$MODE.zip"
	rm -f "$OUT"
	( cd "$BIN" && zip -r -q "$OUT" . )
fi
echo "==> Listo: $OUT"
