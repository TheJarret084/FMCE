#!/data/data/com.termux/files/usr/bin/bash

set -eu

REPO="TheJarret084/FMCE"

echo "================================"
echo " FMCE - NUCLEAR CLEANUP ⚠️⚠️⚠️"
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
echo "Se eliminaran TODOS los artifacts, tags y Draft Releases."
echo "Los releases publicados se conservaran."

read -r -p "Escribe BORRAR para continuar: " CONFIRM

[ "$CONFIRM" = "BORRAR" ] || exit 0

# --- eliminar artifacts ---
echo ""
echo "[1/4] Eliminando artifacts..."

COUNT=0

while IFS= read -r ID; do
    [ -n "$ID" ] || continue

    if gh api -X DELETE "repos/$REPO/actions/artifacts/$ID"; then
        echo "Eliminado artifact: $ID"
        COUNT=$((COUNT + 1))
    fi
done < <(
    gh api --paginate "repos/$REPO/actions/artifacts" \
        --jq '.artifacts[].id'
)

echo "Artifacts eliminados: $COUNT"

# --- eliminar draft releases ---
echo ""
echo "[2/4] Eliminando Draft Releases..."

COUNT=0

while IFS= read -r ID; do
    [ -n "$ID" ] || continue

    if gh api -X DELETE "repos/$REPO/releases/$ID"; then
        echo "Eliminado Draft Release: $ID"
        COUNT=$((COUNT + 1))
    fi
done < <(
    gh api --paginate "repos/$REPO/releases" \
        --jq '.[] | select(.draft == true) | .id'
)

echo "Draft Releases eliminados: $COUNT"

# --- eliminar tags remotas ---
echo ""
echo "[3/4] Eliminando tags remotas..."

COUNT=0

while IFS= read -r REF; do
    [ -n "$REF" ] || continue

    TAG="${REF#refs/tags/}"

    if git push origin --delete "$TAG"; then
        echo "Eliminada tag remota: $TAG"
        COUNT=$((COUNT + 1))
    fi
done < <(
    git ls-remote --tags --refs origin | awk '{print $2}'
)

echo "Tags remotas eliminadas: $COUNT"

# --- eliminar tags locales ---
echo ""
echo "[4/4] Eliminando tags locales..."

COUNT=0

while IFS= read -r TAG; do
    [ -n "$TAG" ] || continue

    if git tag -d "$TAG"; then
        COUNT=$((COUNT + 1))
    fi
done < <(git tag -l)

echo "Tags locales eliminadas: $COUNT"

echo ""
echo "================================"
echo " LIMPIEZA COMPLETADA"
echo "================================"
