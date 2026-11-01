#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
install -d "$PREFIX/bin" "$PREFIX/share/applications" "$PREFIX/share/icons/hicolor/256x256/apps"
install -m 755 "$ROOT/dist/linux-x86_64/TyEditor" "$PREFIX/bin/tyeditor"
# Resource locators resolve data/ and languages/ next to the executable.
rm -rf "$PREFIX/bin/data" "$PREFIX/bin/languages"
cp -a "$ROOT/dist/linux-x86_64/data" "$PREFIX/bin/data"
cp -a "$ROOT/dist/linux-x86_64/languages" "$PREFIX/bin/languages"
for file in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
  [ -f "$ROOT/dist/linux-x86_64/$file" ] && install -m 644 "$ROOT/dist/linux-x86_64/$file" "$PREFIX/bin/$file"
done
install -m 644 "$ROOT/packaging/linux/tyeditor.desktop" "$PREFIX/share/applications/tyeditor.desktop"
install -m 644 "$ROOT/data/icons/tyeditor-256.png" "$PREFIX/share/icons/hicolor/256x256/apps/tyeditor.png"
command -v update-desktop-database >/dev/null && update-desktop-database "$PREFIX/share/applications" || true
