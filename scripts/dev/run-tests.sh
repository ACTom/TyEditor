#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

build_test() {
  local name="$1"
  echo "Building tests/$name..."
  "$LAZBUILD" "${LAZBUILD_OPTS[@]}" "${UNIT_OPTS[@]}" "$ROOT/tests/$name.lpi"
}

run_test() {
  local name="$1"
  shift
  echo "Running tests/$name..."
  "$ROOT/tests/$name" "$@"
}

for test in testencoding testfindasync testplugins testsyntax testtools; do
  build_test "$test"
done
build_test testfindfiles

run_test testencoding
run_test testfindasync
run_test testplugins
run_test testsyntax
run_test testtools
run_test testfindfiles "$ROOT" '*.pas' TyEditor

rm -f "$ROOT"/tests/link*.res

echo "All automated tests passed."
