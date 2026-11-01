#!/usr/bin/env bash
# Shared build paths/helpers. Source this file from the platform scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT

die() {
  echo "error: $*" >&2
  exit 1
}

# Optional local configuration. Copy scripts/env.example.sh to
# scripts/env.local.sh and adjust the paths for your machine.
if [ -n "${TYEDITOR_ENV:-}" ]; then
  [ -f "$TYEDITOR_ENV" ] || die "TYEDITOR_ENV does not exist: $TYEDITOR_ENV"
  # shellcheck disable=SC1090
  source "$TYEDITOR_ENV"
elif [ -f "$ROOT/scripts/env.local.sh" ]; then
  # shellcheck disable=SC1091
  source "$ROOT/scripts/env.local.sh"
fi

PYTHON="${PYTHON:-$(command -v python3 || true)}"
[ -n "$PYTHON" ] || die "python3 is required (set PYTHON=/path/to/python3)"

LAZBUILD="${LAZBUILD:-$(command -v lazbuild || true)}"
[ -n "$LAZBUILD" ] || die "lazbuild not found (set LAZBUILD=/path/to/lazbuild)"
[ -x "$LAZBUILD" ] || die "lazbuild is not executable: $LAZBUILD"

PCP="${PCP:-}"
LAZBUILD_OPTS=()
if [ -n "$PCP" ]; then
  LAZBUILD_OPTS+=("--pcp=$PCP")
fi

if [ -z "${TYCONTROLS_DIR:-}" ]; then
  for candidate in \
    "$ROOT/../TyControls/source" \
    "$HOME/Projects/TyControls/source"; do
    if [ -d "$candidate" ]; then
      TYCONTROLS_DIR="$candidate"
      break
    fi
  done
fi
[ -n "${TYCONTROLS_DIR:-}" ] || die "TyControls source not found (set TYCONTROLS_DIR)"
[ -d "$TYCONTROLS_DIR" ] || die "TYCONTROLS_DIR is not a directory: $TYCONTROLS_DIR"

if [ -z "${CCR_DIR:-}" ]; then
  for candidate in \
    "$HOME/fpcupdeluxe/ccr" \
    "$ROOT/../ccr"; do
    if [ -d "$candidate" ]; then
      CCR_DIR="$candidate"
      break
    fi
  done
fi
[ -n "${CCR_DIR:-}" ] || die "fpcupdeluxe ccr directory not found (set CCR_DIR)"
[ -d "$CCR_DIR" ] || die "CCR_DIR is not a directory: $CCR_DIR"

STRIP="${STRIP:-$(command -v llvm-strip || command -v strip || true)}"

APP_VERSION="$("$PYTHON" "$ROOT/scripts/dev/version.py" --print "$ROOT/TyEditor.lpi")"
[ -n "$APP_VERSION" ] || die "could not read project version from TyEditor.lpi"
"$PYTHON" "$ROOT/scripts/dev/version.py" --write "$ROOT/TyEditor.lpi" "$ROOT/src/version.inc"

UNIT_OPTS=(
  "--opt=-Fu$TYCONTROLS_DIR"
  "--opt=-Fu$CCR_DIR/atsynedit/atsynedit"
  "--opt=-Fu$CCR_DIR/atsynedit_ex/atsynedit_ex"
  "--opt=-Fu$CCR_DIR/econtrol/econtrol"
  "--opt=-Fu$CCR_DIR/bgrabitmap/bgrabitmap"
  "--opt=-Fu$CCR_DIR/atflatcontrols/atflatcontrols"
)

strip_binary() {
  local bin="$1"
  if [ -n "$STRIP" ] && command -v "$STRIP" >/dev/null 2>&1; then
    "$STRIP" --strip-all "$bin"
  else
    echo "warning: strip tool not found; leaving $bin unstripped" >&2
  fi
}

copy_runtime() {
  local dist="$1"
  rm -rf "$dist/data" "$dist/languages"
  cp -a "$ROOT/data" "$dist/data"
  cp -a "$ROOT/languages" "$dist/languages"
  for file in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
    [ -f "$ROOT/$file" ] && cp "$ROOT/$file" "$dist/"
  done
  return 0
}
