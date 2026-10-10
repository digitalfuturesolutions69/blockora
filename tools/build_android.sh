#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
bash tools/build_platform.sh
mkdir -p builds
godot --headless --path . --export-debug 'Android Debug APK' builds/blockora-debug.apk
godot --headless --path . --export-debug 'Android Test AAB' builds/blockora-test.aab
python3 tools/verify_android.py
