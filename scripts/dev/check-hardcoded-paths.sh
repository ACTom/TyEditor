#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
status=0

check_pattern() {
  local description="$1"
  local pattern="$2"
  local path="$3"
  local result
  result="$(grep -RInE --exclude=check-hardcoded-paths.sh --exclude='link*.res' --exclude='*.o' --exclude='*.ppu' "$pattern" "$path" 2>/dev/null || true)"
  if [ -n "$result" ]; then
    echo "hardcoded path/version check failed: $description" >&2
    echo "$result" >&2
    status=1
  fi
}

check_pattern "personal absolute path" '(/home/|/Users/|/opt/|C:\\Users\\)' "$ROOT/scripts"
check_pattern "personal absolute path" '(/home/|/Users/|/opt/|C:\\Users\\)' "$ROOT/tests"
check_pattern "temporary path in tests" '/tmp/' "$ROOT/tests"
check_pattern "hardcoded release version in scripts" '0\.1\.0' "$ROOT/scripts"

if [ "$status" -ne 0 ]; then
  exit 1
fi
echo "hardcoded path/version check: ok"
