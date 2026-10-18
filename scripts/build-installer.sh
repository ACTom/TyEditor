#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
WINE="${WINE:-wine}"
WINE_PREFIX="${WINE_PREFIX:-$HOME/.wine64}"
ISCC="${ISCC:-/home/Tom/Temp/Naotu-Setup/innosetup/ISCC.exe}"

if [ ! -f "$ISCC" ]; then
  echo "Inno Setup compiler not found: $ISCC" >&2
  echo "Set ISCC=/path/to/ISCC.exe" >&2
  exit 1
fi
if [ ! -d "$WINE_PREFIX" ]; then
  WINEARCH=win64 WINEPREFIX="$WINE_PREFIX" "$WINE" wineboot -u
fi
"$ROOT/scripts/build-win32.sh"

WIN_ISS="$(WINEPREFIX="$WINE_PREFIX" winepath -w "$ROOT/scripts/tyeditor.iss" 2>/dev/null | tail -1)"
if [ -z "$WIN_ISS" ]; then
  echo "winepath failed to resolve tyeditor.iss" >&2
  exit 1
fi
WINEPREFIX="$WINE_PREFIX" WINEDEBUG="${WINEDEBUG:--all}" \
  "$WINE" "$ISCC" "/DAppVersion=$APP_VERSION" "$WIN_ISS"
echo "Installer: $ROOT/dist/TyEditorSetup-$APP_VERSION.exe"
