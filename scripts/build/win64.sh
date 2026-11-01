#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
DIST="$ROOT/dist/win64-x86_64"

# Native Win32 widgetset, 64-bit PE. Qt6 is not used on Windows.
RESCOMP="${RESCOMP:-$(command -v llvm-rc || command -v windres || true)}"
[ -n "$RESCOMP" ] || die "Windows resource compiler not found (set RESCOMP=llvm-rc or windres)"
mkdir -p "$ROOT/build"
if [[ "$(basename "$RESCOMP")" == "windres" ]]; then
  "$RESCOMP" -i "$ROOT/packaging/windows/tyeditor.rc" -o "$ROOT/build/tyeditor_icon.res"
else
  ( cd "$ROOT" && "$RESCOMP" /fo "$ROOT/build/tyeditor_icon.res" "$ROOT/packaging/windows/tyeditor.rc" )
fi

"$LAZBUILD" "${LAZBUILD_OPTS[@]}" --os=win64 --cpu=x86_64 --ws=win32 \
  "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"

mkdir -p "$DIST"
cp "$ROOT/TyEditor.exe" "$DIST/TyEditor.exe"
strip_binary "$DIST/TyEditor.exe"
OBJCOPY="${OBJCOPY:-$(command -v llvm-objcopy || command -v objcopy || true)}"
if [ -n "$OBJCOPY" ]; then
  "$OBJCOPY" --remove-section=.stab --remove-section=.stabstr "$DIST/TyEditor.exe"
fi
rm -f "$ROOT/TyEditor.exe" "$ROOT/TyEditor.res" "$ROOT/build/tyeditor_icon.res"
copy_runtime "$DIST"
echo "Windows x86_64 build: $DIST/TyEditor.exe"
