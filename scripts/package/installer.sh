#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
WINE="${WINE:-$(command -v wine || true)}"
WINE_PREFIX="${WINE_PREFIX:-$HOME/.wine64}"
ISCC="${ISCC:-}"

[ -n "$WINE" ] || die "wine not found (set WINE=/path/to/wine)"
[ -n "$ISCC" ] || die "Inno Setup compiler not found (set ISCC=/path/to/ISCC.exe)"
[ -f "$ISCC" ] || die "ISCC does not exist: $ISCC"

if [ ! -d "$WINE_PREFIX" ]; then
  WINEARCH=win64 WINEPREFIX="$WINE_PREFIX" "$WINE" wineboot -u
fi
"$ROOT/scripts/build/win32.sh"

WIN_ISS="$(WINEPREFIX="$WINE_PREFIX" "$WINE" winepath -w "$ROOT/packaging/windows/tyeditor.iss" 2>/dev/null | tail -1)"
[ -n "$WIN_ISS" ] || die "winepath failed to resolve packaging/windows/tyeditor.iss"
WINEPREFIX="$WINE_PREFIX" WINEDEBUG="${WINEDEBUG:--all}" \
  "$WINE" "$ISCC" "/DAppVersion=$APP_VERSION" "$WIN_ISS"
echo "Installer: $ROOT/dist/TyEditorSetup-$APP_VERSION.exe"
