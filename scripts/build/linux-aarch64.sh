#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
DIST="$ROOT/dist/linux-aarch64"

# Cross build prerequisites:
#   - gcc-aarch64-linux-gnu, binutils-aarch64-linux-gnu
#   - FPC aarch64-linux RTL/packages installed
#   - an aarch64 sysroot with glibc and Qt6
#   - libQt6Pas.so.6 for aarch64
# Configure CROSS_BIN, SYSROOT and QT6PAS_LIB in scripts/env.local.sh.
[ -n "${CROSS_BIN:-}" ] || die "CROSS_BIN is required for the aarch64 build"
[ -n "${SYSROOT:-}" ] || die "SYSROOT is required for the aarch64 build"
[ -n "${QT6PAS_LIB:-}" ] || die "QT6PAS_LIB is required for the aarch64 build"

export PATH="$CROSS_BIN:$PATH"
"$LAZBUILD" "${LAZBUILD_OPTS[@]}" --os=linux --cpu=aarch64 --ws=qt6 \
  "--opt=-k-rpath=\$ORIGIN" \
  "--opt=-k--sysroot=$SYSROOT" \
  "--opt=-Fl$QT6PAS_LIB" \
  "${UNIT_OPTS[@]}" "$ROOT/TyEditor.lpi"

mkdir -p "$DIST"
cp "$ROOT/TyEditor" "$DIST/TyEditor"
strip_binary "$DIST/TyEditor"
rm -f "$ROOT/TyEditor" "$ROOT/TyEditor.res"
copy_runtime "$DIST"
# The runtime loader resolves this through the $ORIGIN RUNPATH.
cp -a "$QT6PAS_LIB"/libQt6Pas.so* "$DIST/"
echo "Linux aarch64 build: $DIST/TyEditor"
