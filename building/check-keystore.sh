#!/usr/bin/env bash
# FMCE - comprueba que building/android.keystore sirve para firmar.
#
#   ANDROID_KEY_ALIAS=fmce ANDROID_STORE_PASSWORD=... bash building/check-keystore.sh [ruta]
#
# Sale 0 si el keystore existe, abre con esa contrasena, tiene el alias y se puede leer la llave
# privada (lo mismo que hace Gradle al firmar). Sale 1 si algo falla, con el motivo en stderr.
# Nunca imprime la contrasena. build.sh lo usa para decidir entre firmar con la llave o con debug.
set -u

KS="${1:-building/android.keystore}"

fail() { echo "check-keystore: $1" >&2; exit 1; }

[ -f "$KS" ] || fail "no existe $KS"
[ -s "$KS" ] || fail "el keystore esta vacio"
[ -n "${ANDROID_KEY_ALIAS:-}" ] || fail "falta ANDROID_KEY_ALIAS"
[ -n "${ANDROID_STORE_PASSWORD:-}" ] || fail "falta ANDROID_STORE_PASSWORD"
command -v keytool >/dev/null 2>&1 || fail "no hay keytool (JDK) para verificarlo"

TMP="$(mktemp -d)" || fail "no se pudo crear una carpeta temporal"
trap 'rm -rf "$TMP"' EXIT

# 1) Abre con esa contrasena y trae el alias.
if ! OUT="$(keytool -list -keystore "$KS" -alias "$ANDROID_KEY_ALIAS" \
		-storepass:env ANDROID_STORE_PASSWORD 2>&1)"; then
	case "$OUT" in
		*"password was incorrect"*) fail "ANDROID_STORE_PASSWORD no abre el keystore" ;;
		*"does not exist"*)         fail "el alias de ANDROID_KEY_ALIAS no existe en el keystore" ;;
		*)                          fail "no se pudo abrir (archivo danado o formato que este JDK no lee): $(printf '%s' "$OUT" | head -n1)" ;;
	esac
fi

# 2) La llave privada se puede leer: se copia a un keystore temporal (falla igual que Gradle si no).
if ! OUT="$(keytool -importkeystore -noprompt \
		-srckeystore "$KS" -srcalias "$ANDROID_KEY_ALIAS" -srcstorepass:env ANDROID_STORE_PASSWORD \
		-destkeystore "$TMP/check.p12" -deststoretype PKCS12 -deststorepass:env ANDROID_STORE_PASSWORD 2>&1)"; then
	fail "no se pudo leer la llave privada: $(printf '%s' "$OUT" | head -n1)"
fi

echo "check-keystore: keystore valido"
