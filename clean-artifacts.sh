#!/usr/bin/env bash

set -e

echo "======================================"
echo "   GitHub Actions Artifact Cleaner"
echo "======================================"
echo

# Verificar GitHub CLI
if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI (gh) no está instalado."
    echo "Instálalo desde: https://cli.github.com/"
    exit 1
fi

# Verificar autenticación
if ! gh auth status >/dev/null 2>&1; then
    echo "❌ No estás autenticado en GitHub CLI."
    echo "Ejecuta: gh auth login"
    exit 1
fi

# Detectar repo automáticamente
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

if [ -z "$REPO" ]; then
    echo "❌ No se pudo detectar el repositorio."
    echo "Ejecuta este script dentro de un repositorio GitHub."
    exit 1
fi

echo "📦 Repositorio: $REPO"
echo

# Obtener artifacts
ARTIFACTS=$(gh api \
    "repos/$REPO/actions/artifacts?per_page=100" \
    --paginate \
    --jq '.artifacts[] | [.id, .name, .size_in_bytes] | @tsv')

if [ -z "$ARTIFACTS" ]; then
    echo "✨ No hay artifacts para borrar."
    exit 0
fi

COUNT=$(echo "$ARTIFACTS" | wc -l)

echo "🗑️  Se encontraron $COUNT artifacts:"
echo

echo "$ARTIFACTS" | while IFS=$'\t' read -r ID NAME SIZE; do
    MB=$(awk "BEGIN {printf \"%.2f\", $SIZE / 1024 / 1024}")
    echo "  • $NAME — ${MB} MB"
done

echo
read -p "⚠️  ¿Borrar TODOS estos artifacts? [y/N]: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "❌ Cancelado."
    exit 0
fi

echo
echo "🧹 Limpiando..."

echo "$ARTIFACTS" | while IFS=$'\t' read -r ID NAME SIZE; do
    echo "  🗑️ $NAME"
    gh api --method DELETE \
        "repos/$REPO/actions/artifacts/$ID" \
        >/dev/null
done

echo
echo "======================================"
echo "✅ Limpieza completada."
echo "======================================"