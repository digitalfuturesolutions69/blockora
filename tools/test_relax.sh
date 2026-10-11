#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
validation_log=$(mktemp)
trap 'rm -f "$validation_log"' EXIT
run_godot() {
  if ! godot --headless --path . "$@" > "$validation_log" 2>&1; then cat "$validation_log"; return 1; fi
  cat "$validation_log"
  if rg -q 'SCRIPT ERROR|Parse Error|ERROR:' "$validation_log"; then return 1; fi
}
run_godot --import
run_godot --script tests/unit/run_relax_tests.gd
run_godot --script tests/integration/run_relax_input_tests.gd
run_godot --script tests/simulation/run_relax_simulations.gd -- --sessions=10000
run_godot --script tests/simulation/benchmark_relax.gd
python3 tools/test_relax_process.py
