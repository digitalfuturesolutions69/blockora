#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
command -v rg >/dev/null || { echo "ripgrep is required for script discovery" >&2; exit 1; }
# The editor registers class_name types before checking all script resources.
import_log=$(mktemp)
trap 'rm -f "$import_log"' EXIT
if ! godot --headless --path . --import > "$import_log" 2>&1; then cat "$import_log"; exit 1; fi
if rg 'SCRIPT ERROR|Parse Error|ERROR:' "$import_log"; then cat "$import_log"; exit 1; fi
while IFS= read -r file; do
  godot --headless --path . --script "$file" --check-only
 done < <(rg --files scripts scenes tests addons -g '*.gd' | sort)
godot --headless --path . --script tests/smoke/run_tests.gd
godot --headless --path . --quit-after 2
