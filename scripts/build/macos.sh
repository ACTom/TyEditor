#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

ARCH="${1:-all}"
X86_APP="$ROOT/dist/macos-x86_64/TyEditor.app"
ARM_APP="$ROOT/dist/macos-aarch64/TyEditor.app"
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

build_arch() {
  local cpu="$1"
  local app="$2"
  local bin="$ROOT/dist/.TyEditor-$cpu"

  echo "Building macOS $cpu..."
  "$LAZBUILD" "${LAZBUILD_OPTS[@]}" --os=darwin --cpu="$cpu" --ws=cocoa \
    "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"
  cp "$ROOT/TyEditor" "$bin"
  strip_binary "$bin"
  package_app "$bin" "$app"
  rm -rf "$ROOT/TyEditor.app"
  rm -f "$ROOT/TyEditor" "$ROOT/TyEditor.res" "$bin"
  echo "macOS $cpu: $app"
}

case "$ARCH" in
  all)
    build_arch x86_64 "$X86_APP"
    build_arch aarch64 "$ARM_APP"
    ;;
  x86_64)
    build_arch x86_64 "$X86_APP"
    ;;
  aarch64|arm64)
    build_arch aarch64 "$ARM_APP"
    ;;
  *)
    echo "usage: $0 [all|x86_64|aarch64]" >&2
    exit 2
    ;;
esac
