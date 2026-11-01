#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
LIPO="${LIPO:-$(command -v llvm-lipo || command -v lipo || true)}"
X86_APP="$ROOT/dist/macos-x86_64/TyEditor.app"
UNI_APP="$ROOT/dist/macos-universal/TyEditor.app"
X86_BIN="$ROOT/dist/.TyEditor-x86_64"
ARM_BIN="$ROOT/dist/.TyEditor-aarch64"
mkdir -p "$ROOT/dist"

update_plist_version() {
  local plist="$1"
  "$PYTHON" - "$plist" "$APP_VERSION" <<'PY'
import plistlib
import sys

path, version = sys.argv[1], sys.argv[2]
with open(path, "rb") as handle:
    data = plistlib.load(handle)
data["CFBundleShortVersionString"] = version
data["CFBundleVersion"] = version
with open(path, "wb") as handle:
    plistlib.dump(data, handle, sort_keys=False)
PY
}

package_app() {
  local bin="$1"
  local app="$2"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$bin" "$app/Contents/MacOS/TyEditor"
  chmod +x "$app/Contents/MacOS/TyEditor"
  cp "$ROOT/packaging/macos/Info.plist" "$app/Contents/Info.plist"
  update_plist_version "$app/Contents/Info.plist"
  cp "$ROOT/data/icons/tyeditor.icns" "$app/Contents/Resources/TyEditor.icns"
  cp -a "$ROOT/data" "$app/Contents/Resources/data"
  cp -a "$ROOT/languages" "$app/Contents/Resources/languages"
  for file in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
    [ -f "$ROOT/$file" ] && cp "$ROOT/$file" "$app/Contents/Resources/"
  done
  printf 'APPL????' > "$app/Contents/PkgInfo"
}

echo "Building macOS x86_64..."
"$LAZBUILD" "${LAZBUILD_OPTS[@]}" --os=darwin --cpu=x86_64 --ws=cocoa "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"
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
"$LAZBUILD" "${LAZBUILD_OPTS[@]}" --os=darwin --cpu=aarch64 --ws=cocoa "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"
cp "$ROOT/TyEditor" "$ARM_BIN"
strip_binary "$ARM_BIN"
rm -rf "$ROOT/TyEditor.app"
rm -f "$ROOT/TyEditor" "$ROOT/TyEditor.res"

if [ -n "$LIPO" ]; then
  mkdir -p "$(dirname "$UNI_APP")"
  rm -rf "$UNI_APP"
  cp -a "$X86_APP" "$UNI_APP"
  "$LIPO" -create "$X86_BIN" "$ARM_BIN" -output "$UNI_APP/Contents/MacOS/TyEditor"
  chmod +x "$UNI_APP/Contents/MacOS/TyEditor"
  echo "macOS universal: $UNI_APP"
else
  echo "llvm-lipo/lipo not found; skipped universal binary" >&2
fi
rm -f "$X86_BIN" "$ARM_BIN"
