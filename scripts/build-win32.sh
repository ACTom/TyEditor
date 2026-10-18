#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
DIST="$ROOT/dist/win32-i386"

# Qt6 does not ship a 32-bit Windows target; the Windows build uses the
# native Win32 widgetset so it can run on 32-bit and 64-bit Windows.
#
# Compile the icon into the PE file explicitly. lazbuild does not regenerate
# the Lazarus .res from the .lpi <Icon> setting in command-line builds.
RESCOMP="${RESCOMP:-llvm-rc}"
if command -v "$RESCOMP" >/dev/null 2>&1; then
  ( cd "$ROOT" && "$RESCOMP" /fo "$ROOT/tyeditor_icon.res" "$ROOT/TyEditor.rc" )
else
  echo "Windows resource compiler not found: $RESCOMP" >&2
  exit 1
fi

"$LAZBUILD" --pcp="$PCP" --os=win32 --cpu=i386 --ws=win32 \
  "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"

mkdir -p "$DIST"
cp "$ROOT/TyEditor.exe" "$DIST/TyEditor.exe"
strip_binary "$DIST/TyEditor.exe"
# PE debug sections are not removed by llvm-strip; drop them explicitly.
OBJCOPY="${OBJCOPY:-llvm-objcopy}"
if command -v "$OBJCOPY" >/dev/null 2>&1; then
  "$OBJCOPY" --remove-section=.stab --remove-section=.stabstr "$DIST/TyEditor.exe"
fi
rm -f "$ROOT/TyEditor.exe" "$ROOT/TyEditor.res" "$ROOT/tyeditor_icon.res"
copy_runtime "$DIST"
echo "Windows i386 build: $DIST/TyEditor.exe"
