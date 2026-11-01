#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-linux-x86_64}"

case "$TARGET" in
  linux-x86_64)
    exec "$ROOT/build/linux-x86_64.sh" "${@:2}"
    ;;
  linux-aarch64)
    exec "$ROOT/build/linux-aarch64.sh" "${@:2}"
    ;;
  win32)
    exec "$ROOT/build/win32.sh" "${@:2}"
    ;;
  win64)
    exec "$ROOT/build/win64.sh" "${@:2}"
    ;;
  macos)
    exec "$ROOT/build/macos.sh" all
    ;;
  macos-x86_64)
    exec "$ROOT/build/macos.sh" x86_64
    ;;
  macos-aarch64|macos-arm64)
    exec "$ROOT/build/macos.sh" aarch64
    ;;
  all)
    "$ROOT/build/linux-x86_64.sh"
    "$ROOT/build/win32.sh"
    "$ROOT/build/win64.sh"
    ;;
  *)
    cat >&2 <<'EOF'
Usage: scripts/build.sh TARGET

Targets:
  linux-x86_64   native Linux build (default)
  linux-aarch64  Linux aarch64 cross build
  win32          Windows i386 cross build
  win64          Windows x86_64 cross build
  macos          macOS x86_64 + Apple Silicon (arm64) builds
  macos-x86_64   macOS Intel x86_64 build
  macos-aarch64  macOS Apple Silicon (arm64) build
  all            linux-x86_64 + win32 + win64
EOF
    exit 2
    ;;
esac
