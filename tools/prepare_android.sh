#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
cd "$repo_root"
templates_root="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.6.3.stable"
if [[ ! -f android/.build_version ]]; then
  if [[ -e android/build ]]; then
    echo 'Existing Android build directory has no version marker; inspect it before replacement.' >&2
    exit 1
  fi
  mkdir -p android/build
  unzip -q "$templates_root/android_source.zip" -d android/build
  printf '4.6.3.stable\n' > android/.build_version
fi
[[ "$(cat android/.build_version)" == '4.6.3.stable' ]]
# Pin the official wrapper distribution checksum in the generated (ignored) template.
python3 - <<'SCRIPT'
from pathlib import Path
config = Path('android/build/config.gradle')
text = config.read_text()
assert "androidGradlePlugin: '8.6.1'" in text or "androidGradlePlugin: '8.10.1'" in text, 'Unexpected AGP version'
config.write_text(text.replace("androidGradlePlugin: '8.6.1'", "androidGradlePlugin: '8.10.1'"))
p = Path('android/build/gradle/wrapper/gradle-wrapper.properties')
s = p.read_text()
assert 'gradle-8.11.1-bin.zip' in s, 'Unexpected wrapper version'
checksum = 'f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6'
lines = [line for line in s.splitlines() if not line.startswith('distributionSha256Sum=')]
p.write_text('\n'.join(lines) + '\ndistributionSha256Sum=' + checksum + '\n')
SCRIPT
chmod +x android/build/gradlew
