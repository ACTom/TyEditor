#!/usr/bin/env bash
# Copy to scripts/env.local.sh and adjust the paths for your machine.
# scripts/env.local.sh is git-ignored.

export LAZBUILD="/path/to/lazbuild"
# Optional. Leave empty to use the default Lazarus primary config path.
export PCP=""

export TYCONTROLS_DIR="/path/to/TyControls/source"
export CCR_DIR="/path/to/fpcupdeluxe/ccr"

# Optional tool selection.
# export STRIP="llvm-strip"
# export PYTHON="python3"

# Cross-compilation only. These have no repository defaults.
# export CROSS_BIN="/path/to/aarch64-bin"
# export SYSROOT="/path/to/sysroot-aarch64"
# export QT6PAS_LIB="/path/to/qt6pas-aarch64/lib"
