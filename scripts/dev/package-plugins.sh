#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$ROOT/dist/plugins"
for plugin in "$ROOT"/data/plugins/*; do
  [[ -f "$plugin/plugin.json" ]] || continue
  "$ROOT/scripts/dev/package-plugin.py" "$plugin"
done
