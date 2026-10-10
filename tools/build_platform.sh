#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
bash tools/prepare_android.sh
bash android/build/gradlew -p android/plugins/blockora-platform --no-daemon --max-workers=2 assembleDebug "$@"
mkdir -p addons/blockora_platform/bin
cp android/plugins/blockora-platform/build/outputs/aar/BlockoraPlatform-debug.aar addons/blockora_platform/bin/
