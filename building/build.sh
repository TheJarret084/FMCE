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

# Un haxelib git puede estar en un commit viejo aunque la URL coincida. Si libs.json
# pide un ref (tag o rama), exigimos que el checkout este realmente ahi.
git_ref_matches() {
	local dir="$1" ref="$2" head
	[ -z "$ref" ] && return 0
	[ -d "$dir" ] || return 1
	head="$(git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null || true)"
	[ "$head" = "$ref" ] && return 0
	head="$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
	[ "$head" = "$ref" ] && return 0
	return 1
}

while IFS=$'\t' read -r type name ver url ref; do
	# '-' marca campos vacios (el tab es whitespace en IFS y read los colapsaria, corriendo version/url/ref)
	[ "$ver" = "-" ] && ver=""; [ "$url" = "-" ] && url=""; [ "$ref" = "-" ] && ref=""
	case "$name" in ""|-|\#*) continue;; esac
	if [ "$type" = "git" ]; then
		if haxelib list "$name" 2>/dev/null </dev/null | grep -q '\[git\]' \
			&& git -C "$HAXELIB_REPO/$name/git" remote get-url origin 2>/dev/null | grep -qxF "$url" \
			&& git_ref_matches "$HAXELIB_REPO/$name/git" "$ref"; then
			continue
		fi
		echo "   instalando $name (git)"
		if ! haxelib git "$name" "$url" ${ref:+"$ref"} --always --quiet </dev/null; then
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
			haxelib install "$name" "$ver" --always --quiet </dev/null || haxelib install "$name" --always --quiet </dev/null || { echo "build.sh: no se pudo instalar $name $ver" >&2; exit 1; }
			haxelib set "$name" "$ver" >/dev/null 2>&1 </dev/null || true
		else
			haxelib path "$name" >/dev/null 2>&1 </dev/null && continue
			echo "   instalando $name"
			haxelib install "$name" --always --quiet </dev/null || { echo "build.sh: no se pudo instalar $name" >&2; exit 1; }
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

# FunkFMPEG se instala por git (solo codigo). Los ndll precompilados se bajan del release
# del mismo tag (building/fetch-funkfmpeg.sh) al checkout de haxelib: no se compila FFmpeg aqui.
# FUNKFMPEG_LOCAL=1 usa ndll/ local en vez de bajarlo.
FF_NDLL="$HAXELIB_REPO/funkfmpeg/git/ndll"
ff_get() { # $1=plataforma del release, $2=carpeta dentro de ndll/
	if [ "${FUNKFMPEG_LOCAL:-0}" = "1" ]; then
		mkdir -p "$FF_NDLL/$2"; cp -rf "ndll/$2/." "$FF_NDLL/$2/"
	else
		bash building/fetch-funkfmpeg.sh "$1" "$FF_NDLL"
	fi
}
case "$PLATFORM" in
	linux)
		ff_get linux-x64 Linux64
		;;
	android)
		ff_get android-arm64 Android
		# Guardia: el .a no puede traer outline atomics (__aarch64_ldadd8_acq_rel...): el NDK 21 no los tiene y
		# la app muere al abrir con "dlopen failed: cannot locate symbol". Hace falta FunkFMPEG >= 1.4.11.
		NDK_="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-}}"
		NM_="$(ls "$NDK_"/toolchains/llvm/prebuilt/*/bin/llvm-nm 2>/dev/null | head -n1 || true)"
		if [ -n "$NM_" ] && "$NM_" -A "$FF_NDLL/Android/libfunkfmpeg-64.a" 2>/dev/null | grep -qE '__aarch64_(ldadd|ldset|ldclr|ldeor|swp|cas)'; then
			echo "build.sh: libfunkfmpeg-64.a usa outline atomics (FunkFMPEG viejo). Sube funkfmpeg a >= 1.4.11 en building/libs.json." >&2
			exit 1
		fi
		# Lime/Java siempre carga libfunkfmpeg-64.so antes que libApplicationMain.so. Un .so
		# enlazado desde el .a tendria simbolos hxcpp sin resolver (alloc_int, ...) porque
		# el runtime vive en ApplicationMain y Android no lo exporta. Por eso el codigo real
		# se mete en ApplicationMain con --whole-archive y aqui solo queda un modulo vacio.
		NDK="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-}}"
		[ -n "$NDK" ] || { echo "build.sh: falta ANDROID_NDK_ROOT para enlazar funkfmpeg" >&2; exit 1; }
		CXX="$(ls "$NDK"/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android*-clang++ 2>/dev/null | head -n1 || true)"
		[ -n "$CXX" ] || { echo "build.sh: no hay clang++ arm64 en $NDK" >&2; exit 1; }
		STUB="$FF_NDLL/Android/funkfmpeg_stub.cpp"
		printf 'extern "C" int funkfmpeg_android_static_stub() { return 1; }\n' > "$STUB"
		"$CXX" -shared -fPIC -static-libstdc++ \
			-Wl,-soname,libfunkfmpeg-64.so \
			-o "$FF_NDLL/Android/libfunkfmpeg-64.so" "$STUB"
		# Hxcpp permite añadir flags al enlazador desde HXCPP_CONFIG. Metemos el .a en el
		# binario principal para que funkfmpeg_register_prims() (llamado desde Main.hx) y
		# todas las funciones CFFI vivan en el mismo modulo que el runtime de hxcpp.
		FF_LIB_ABS="$FF_NDLL/Android/libfunkfmpeg-64.a"
		FF_INIT_CPP="$PWD/building/.funkfmpeg_android_init.cpp"
		# Registro estatico: se ejecuta cuando Android carga libApplicationMain.so, antes de que
		# el juego pida cualquier funcion CFFI de FunkFMPEG. Asi evitamos declaraciones @:native
		# que hxcpp no genera para el modulo principal en Android.
		cat > "$FF_INIT_CPP" <<EOF
extern "C" int funkfmpeg_register_prims();
namespace {
struct FunkFmpegStaticPrims {
	FunkFmpegStaticPrims() { funkfmpeg_register_prims(); }
} funkFmpegStaticPrims;
}
EOF
		HXCPP_CONF="$PWD/building/.hxcpp-android-funkfmpeg.xml"
		cat > "$HXCPP_CONF" <<EOF
<xml>
  <section id="exes">
    <files id="main">
      <file name="$FF_INIT_CPP" />
    </files>
    <linker id="dll" if="android">
      <flag value="-Wl,--whole-archive" />
      <flag value="$FF_LIB_ABS" />
      <flag value="-Wl,--no-whole-archive" />
      <flag value="-Wl,--exclude-libs,ALL" />
      <flag value="-llog" />
      <flag value="-lz" />
      <flag value="-ldl" />
      <flag value="-lm" />
    </linker>
    <linker id="exe" if="android">
      <flag value="-Wl,--whole-archive" />
      <flag value="$FF_LIB_ABS" />
      <flag value="-Wl,--no-whole-archive" />
      <flag value="-Wl,--exclude-libs,ALL" />
      <flag value="-llog" />
      <flag value="-lz" />
      <flag value="-ldl" />
      <flag value="-lm" />
    </linker>
  </section>
</xml>
EOF
		export HXCPP_CONFIG="$HXCPP_CONF"
		echo "==> Android: FunkFMPEG enlazado dentro de ApplicationMain"
		;;
	html5) ;;
	*)
		echo "build.sh: no hay ndll de FunkFMPEG para $PLATFORM" >&2
		exit 1
		;;
esac

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
