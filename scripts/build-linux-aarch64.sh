#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
DIST="$ROOT/dist/linux-aarch64"

# Cross build prerequisites (Fedora):
#   - gcc-aarch64-linux-gnu, binutils-aarch64-linux-gnu
#   - FPC aarch64-linux RTL/packages installed under $FPC_UNITS
#   - /opt/sysroot-aarch64: aarch64 glibc + Qt6 (dnf --forcearch=aarch64 --installroot=...)
#   - libQt6Pas.so.6 for aarch64 in $QT6PAS_LIB
CROSS_BIN="${CROSS_BIN:-/opt/aarch64-bin}"
SYSROOT="${SYSROOT:-/opt/sysroot-aarch64}"
QT6PAS_LIB="${QT6PAS_LIB:-/opt/qt6pas-aarch64/lib}"

export PATH="$CROSS_BIN:$PATH"
"$LAZBUILD" --pcp="$PCP" --os=linux --cpu=aarch64 --ws=qt6 \
  "--opt=-k-rpath=\$ORIGIN" \
  "--opt=-k--sysroot=$SYSROOT" \
  "--opt=-Fl$QT6PAS_LIB" \
  "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"

mkdir -p "$DIST"
cp "$ROOT/TyEditor" "$DIST/TyEditor"
aarch64-linux-gnu-strip --strip-all "$DIST/TyEditor"
rm -f "$ROOT/TyEditor" "$ROOT/TyEditor.res"
copy_runtime "$DIST"
# The runtime loader resolves this through the $ORIGIN RUNPATH.
cp -a "$QT6PAS_LIB"/libQt6Pas.so* "$DIST/"
echo "Linux aarch64 build: $DIST/TyEditor"
