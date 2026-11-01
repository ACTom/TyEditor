#!/usr/bin/env bash
# Archive the already-built distribution directories for a release.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PYTHON="${PYTHON:-$(command -v python3 || true)}"
[ -n "$PYTHON" ] || { echo "error: python3 is required" >&2; exit 1; }
VERSION="$("$PYTHON" "$ROOT/scripts/dev/version.py" --print "$ROOT/TyEditor.lpi")"
[ -n "$VERSION" ] || { echo "error: could not read project version" >&2; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "error: tar is required" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "error: zip is required" >&2; exit 1; }
DIST="$ROOT/dist"

die() {
  echo "error: $*" >&2
  exit 1
}

require_dir() {
  [ -d "$1" ] || die "missing build output: $1"
}

archive_tar() {
  local src="$1"
  local out="$2"
  rm -f "$out"
  ( cd "$src" && tar -czf "$out" . )
  echo "archive: $out"
}

archive_zip() {
  local src="$1"
  local out="$2"
  rm -f "$out"
  ( cd "$src" && zip -qr "$out" . )
  echo "archive: $out"
}

archive_app_zip() {
  local src="$1"
  local out="$2"
  rm -f "$out"
  ( cd "$src" && zip -qry "$out" TyEditor.app )
  echo "archive: $out"
}

require_dir "$DIST/linux-x86_64"
require_dir "$DIST/linux-aarch64"
require_dir "$DIST/win32-i386"
require_dir "$DIST/win64-x86_64"
require_dir "$DIST/macos-x86_64/TyEditor.app"
require_dir "$DIST/macos-aarch64/TyEditor.app"
[ -f "$DIST/TyEditorSetup-$VERSION.exe" ] || die "missing installer: $DIST/TyEditorSetup-$VERSION.exe"

archive_tar "$DIST/linux-x86_64" "$DIST/TyEditor-$VERSION-linux-x86_64.tar.gz"
archive_tar "$DIST/linux-aarch64" "$DIST/TyEditor-$VERSION-linux-aarch64.tar.gz"
archive_zip "$DIST/win32-i386" "$DIST/TyEditor-$VERSION-win32.zip"
archive_zip "$DIST/win64-x86_64" "$DIST/TyEditor-$VERSION-win64.zip"
archive_app_zip "$DIST/macos-x86_64" "$DIST/TyEditor-$VERSION-macos-x86_64.zip"
archive_app_zip "$DIST/macos-aarch64" "$DIST/TyEditor-$VERSION-macos-aarch64.zip"

(
  cd "$DIST"
  sha256sum \
    "TyEditor-$VERSION-linux-x86_64.tar.gz" \
    "TyEditor-$VERSION-linux-aarch64.tar.gz" \
    "TyEditor-$VERSION-win32.zip" \
    "TyEditor-$VERSION-win64.zip" \
    "TyEditor-$VERSION-macos-x86_64.zip" \
    "TyEditor-$VERSION-macos-aarch64.zip" \
    "TyEditorSetup-$VERSION.exe" \
    > SHA256SUMS
)

echo "version: $VERSION"
echo "checksums: $DIST/SHA256SUMS"
