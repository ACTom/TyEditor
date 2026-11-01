#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
DIST="$ROOT/dist/win32-i386"

# Qt6 does not ship a 32-bit Windows target; the Windows build uses the
# native Win32 widgetset so it can run on 32-bit and 64-bit Windows.
#
# Compile the icon into the PE file explicitly. lazbuild does not regenerate
# the Lazarus .res from the .lpi <Icon> setting in command-line builds.
RESCOMP="${RESCOMP:-$(command -v llvm-rc || command -v windres || true)}"
[ -n "$RESCOMP" ] || die "Windows resource compiler not found (set RESCOMP=llvm-rc or windres)"
mkdir -p "$ROOT/build"
if [[ "$(basename "$RESCOMP")" == "windres" ]]; then
  "$RESCOMP" -i "$ROOT/packaging/windows/tyeditor.rc" -o "$ROOT/build/tyeditor_icon.res"
else
  ( cd "$ROOT" && "$RESCOMP" /fo "$ROOT/build/tyeditor_icon.res" "$ROOT/packaging/windows/tyeditor.rc" )
fi

"$LAZBUILD" "${LAZBUILD_OPTS[@]}" --os=win32 --cpu=i386 --ws=win32 \
  "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"

mkdir -p "$DIST"
cp "$ROOT/TyEditor.exe" "$DIST/TyEditor.exe"
strip_binary "$DIST/TyEditor.exe"
# PE debug sections are not removed by llvm-strip; drop them explicitly.
OBJCOPY="${OBJCOPY:-$(command -v llvm-objcopy || command -v objcopy || true)}"
if [ -n "$OBJCOPY" ]; then
  "$OBJCOPY" --remove-section=.stab --remove-section=.stabstr "$DIST/TyEditor.exe"
fi
rm -f "$ROOT/TyEditor.exe" "$ROOT/TyEditor.res" "$ROOT/build/tyeditor_icon.res"
copy_runtime "$DIST"
echo "Windows i386 build: $DIST/TyEditor.exe"
