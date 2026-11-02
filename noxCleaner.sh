#!/data/data/com.termux/files/usr/bin/bash

set -eu

REPO="TheJarret084/FMCE"

echo "FMCE - limpiador termo nuclear"

echo "================================"
echo " FMCE - NUCLEAR CLEANUP"
echo "================================"

# --- comprobar entorno ---
git rev-parse --is-inside-work-tree >/dev/null
gh auth status >/dev/null

REMOTE=$(git remote get-url origin)

case "$REMOTE" in
    *TheJarret084/FMCE.git|*TheJarret084/FMCE) ;;
    *)
        echo "ERROR: origin no apunta a $REPO"
        echo "Actual: $REMOTE"
        exit 1
        ;;
esac

echo "Repositorio: $REPO"
echo "Se eliminaran TODOS los artifacts y tags."

read -r -p "Escribe BORRAR para continuar: " CONFIRM

[ "$CONFIRM" = "BORRAR" ] || exit 0

# --- eliminar artifacts ---
echo ""
echo "[1/3] Eliminando artifacts..."

COUNT=0

while IFS= read -r ID; do
    [ -n "$ID" ] || continue

    if gh api -X DELETE "repos/$REPO/actions/artifacts/$ID"; then
        echo "Eliminado artifact: $ID"
        COUNT=$((COUNT + 1))
    fi
done < <(gh api --paginate "repos/$REPO/actions/artifacts" --jq '.artifacts[].id')

echo "Artifacts eliminados: $COUNT"

# --- eliminar tags remotas ---
echo ""
echo "[2/3] Eliminando tags remotas..."

COUNT=0

while IFS= read -r REF; do
    [ -n "$REF" ] || continue

    TAG="${REF#refs/tags/}"

    if git push origin --delete "$TAG"; then
        echo "Eliminada tag remota: $TAG"
        COUNT=$((COUNT + 1))
    fi
done < <(git ls-remote --tags --refs origin | awk '{print $2}')

echo "Tags remotas eliminadas: $COUNT"

# --- eliminar tags locales ---
echo ""
echo "[3/3] Eliminando tags locales..."

COUNT=0

while IFS= read -r TAG; do
    [ -n "$TAG" ] || continue

    git tag -d "$TAG"
    COUNT=$((COUNT + 1))
done < <(git tag -l)

echo "Tags locales eliminadas: $COUNT"

echo ""
echo "================================"
echo " LIMPIEZA COMPLETADA"
echo "================================"