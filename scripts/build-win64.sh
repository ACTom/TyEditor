#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
DIST="$ROOT/dist/win64-x86_64"

# Native Win32 widgetset, 64-bit PE. Qt6 is not used on Windows.
RESCOMP="${RESCOMP:-llvm-rc}"
if command -v "$RESCOMP" >/dev/null 2>&1; then
  ( cd "$ROOT" && "$RESCOMP" /fo "$ROOT/tyeditor_icon.res" "$ROOT/TyEditor.rc" )
else
  echo "Windows resource compiler not found: $RESCOMP" >&2
  exit 1
fi

"$LAZBUILD" --pcp="$PCP" --os=win64 --cpu=x86_64 --ws=win32 \
  "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"

mkdir -p "$DIST"
cp "$ROOT/TyEditor.exe" "$DIST/TyEditor.exe"
strip_binary "$DIST/TyEditor.exe"
OBJCOPY="${OBJCOPY:-llvm-objcopy}"
if command -v "$OBJCOPY" >/dev/null 2>&1; then
  "$OBJCOPY" --remove-section=.stab --remove-section=.stabstr "$DIST/TyEditor.exe"
fi
rm -f "$ROOT/TyEditor.exe" "$ROOT/TyEditor.res" "$ROOT/tyeditor_icon.res"
copy_runtime "$DIST"
echo "Windows x86_64 build: $DIST/TyEditor.exe"
