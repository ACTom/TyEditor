#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"

# The Linux application uses Qt6. Building the tests with the same widgetset
# avoids compiling the GTK2 IME adapter without LCL's WITH_GTK2_IM define.
TEST_WS="${TEST_WS:-}"
if [ -z "$TEST_WS" ] && [ "$(uname -s)" = "Linux" ]; then
  TEST_WS=qt6
fi
WS_OPTS=()
[ -n "$TEST_WS" ] && WS_OPTS+=("--ws=$TEST_WS")

build_test() {
  local name="$1"
  echo "Building tests/$name..."
  "$LAZBUILD" "${LAZBUILD_OPTS[@]}" "${WS_OPTS[@]}" "${UNIT_OPTS[@]}" "$ROOT/tests/$name.lpi"
}

run_test() {
  local name="$1"
  shift
  echo "Running tests/$name..."
  "$ROOT/tests/$name" "$@"
}

for test in testencoding testfindasync testkeys testplugins testprint testsyntax testtools; do
  build_test "$test"
done
build_test testfindfiles

run_test testencoding
run_test testfindasync
run_test testkeys
run_test testplugins
run_test testprint
run_test testsyntax
run_test testtools
run_test testfindfiles "$ROOT" '*.pas' TyEditor

rm -f "$ROOT"/tests/link*.res

echo "All automated tests passed."
