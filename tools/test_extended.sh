#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Run tools/test.sh first to import/register types and validate scripts.
simulation_log=$(mktemp)
trap 'rm -f "$simulation_log"' EXIT
if ! godot --headless --path . --script tests/simulation/run_simulations.gd -- --sessions=10000 > "$simulation_log" 2>&1; then cat "$simulation_log"; exit 1; fi
cat "$simulation_log"
if rg -q 'SCRIPT ERROR|Parse Error|ERROR:' "$simulation_log"; then exit 1; fi
