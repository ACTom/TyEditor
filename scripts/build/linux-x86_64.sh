#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
DIST="$ROOT/dist/linux-x86_64"

"$LAZBUILD" "${LAZBUILD_OPTS[@]}" --ws=qt6 "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"

mkdir -p "$DIST"
cp "$ROOT/TyEditor" "$DIST/TyEditor"
strip_binary "$DIST/TyEditor"
rm -f "$ROOT/TyEditor" "$ROOT/TyEditor.res"
copy_runtime "$DIST"
echo "Linux Qt6 build: $DIST/TyEditor"
