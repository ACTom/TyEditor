#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
LIPO="${LIPO:-/usr/bin/llvm-lipo}"
X86_APP="$ROOT/dist/macos-x86_64/TyEditor.app"
UNI_APP="$ROOT/dist/macos-universal/TyEditor.app"
X86_BIN="$ROOT/dist/.TyEditor-x86_64"
ARM_BIN="$ROOT/dist/.TyEditor-aarch64"
mkdir -p "$ROOT/dist"

package_app() {
  local bin="$1"
  local app="$2"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$bin" "$app/Contents/MacOS/TyEditor"
  chmod +x "$app/Contents/MacOS/TyEditor"
  cp "$ROOT/assets/macos/Info.plist" "$app/Contents/Info.plist"
  sed -i "s#<string>0\.1\.0</string>#<string>$APP_VERSION</string>#g" "$app/Contents/Info.plist"
  cp "$ROOT/data/icons/tyeditor.icns" "$app/Contents/Resources/TyEditor.icns"
  cp -a "$ROOT/data" "$app/Contents/Resources/data"
  cp -a "$ROOT/languages" "$app/Contents/Resources/languages"
  printf 'APPL????' > "$app/Contents/PkgInfo"
}

echo "Building macOS x86_64..."
"$LAZBUILD" --pcp="$PCP" --os=darwin --cpu=x86_64 --ws=cocoa "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"
cp "$ROOT/TyEditor" "$X86_BIN"
strip_binary "$X86_BIN"
package_app "$X86_BIN" "$X86_APP"
rm -rf "$ROOT/TyEditor.app"
rm -f "$ROOT/TyEditor" "$ROOT/TyEditor.res"
echo "macOS x86_64: $X86_APP"

if [ "${MAC_UNIVERSAL:-1}" = "0" ]; then
  rm -f "$X86_BIN"
  exit 0
fi

echo "Building macOS aarch64..."
"$LAZBUILD" --pcp="$PCP" --os=darwin --cpu=aarch64 --ws=cocoa "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"
cp "$ROOT/TyEditor" "$ARM_BIN"
strip_binary "$ARM_BIN"
rm -rf "$ROOT/TyEditor.app"
rm -f "$ROOT/TyEditor" "$ROOT/TyEditor.res"

if [ -x "$LIPO" ]; then
  mkdir -p "$(dirname "$UNI_APP")"
  rm -rf "$UNI_APP"
  cp -a "$X86_APP" "$UNI_APP"
  "$LIPO" -create "$X86_BIN" "$ARM_BIN" -output "$UNI_APP/Contents/MacOS/TyEditor"
  chmod +x "$UNI_APP/Contents/MacOS/TyEditor"
  echo "macOS universal: $UNI_APP"
else
  echo "llvm-lipo not found; skipped universal binary" >&2
fi
rm -f "$X86_BIN" "$ARM_BIN"
