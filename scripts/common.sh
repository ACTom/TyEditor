#!/usr/bin/env bash
# Shared build paths/helpers. Source this file from the platform scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAZBUILD="${LAZBUILD:-/home/Tom/fpcupdeluxe/lazarus/lazbuild}"
PCP="${PCP:-/home/Tom/fpcupdeluxe/config_lazarus}"
TC_SOURCE="${TC_SOURCE:-/home/Tom/Projects/TyControls/source}"
FPC_CCR="${FPC_CCR:-/home/Tom/fpcupdeluxe/ccr}"
STRIP="${STRIP:-/usr/bin/llvm-strip}"
APP_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"

UNIT_OPTS=(
  "--opt=-Fu$TC_SOURCE"
  "--opt=-Fu$FPC_CCR/atsynedit/atsynedit"
  "--opt=-Fu$FPC_CCR/atsynedit_ex/atsynedit_ex"
  "--opt=-Fu$FPC_CCR/econtrol/econtrol"
  "--opt=-Fu$FPC_CCR/bgrabitmap/bgrabitmap"
  "--opt=-Fu$FPC_CCR/atflatcontrols/atflatcontrols"
)

# The About box reads TyEditorVersion from this generated include.
printf "const TyEditorVersion = '%s';\n" "$APP_VERSION" > "$ROOT/src/version.inc"

strip_binary() {
  local bin="$1"
  if [ -x "$STRIP" ]; then
    "$STRIP" --strip-all "$bin"
  else
    strip --strip-all "$bin"
  fi
}

copy_runtime() {
  local dist="$1"
  rm -rf "$dist/data" "$dist/languages"
  cp -a "$ROOT/data" "$dist/data"
  cp -a "$ROOT/languages" "$dist/languages"
}
