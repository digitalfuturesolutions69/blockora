#!/usr/bin/env bash
set -euo pipefail
# CI-only bootstrap; cloud tasks should reuse the published environment instead.
if ! command -v rg >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y ripgrep
fi
tool_root="${RUNNER_TEMP:-/tmp}/blockora-ci-toolchains"
mkdir -p "$tool_root/godot" "$tool_root/android-sdk/cmdline-tools" "$tool_root/data/godot/export_templates/4.6.3.stable" "$tool_root/config/godot" "$tool_root/cache"
export XDG_DATA_HOME="$tool_root/data"
export XDG_CONFIG_HOME="$tool_root/config"
export XDG_CACHE_HOME="$tool_root/cache"
export ANDROID_HOME="$tool_root/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$tool_root/android-user"
export JAVA_HOME="$tool_root/jdk-17"
export GRADLE_USER_HOME="$tool_root/gradle"
curl -fsSL https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip -o "$tool_root/godot.zip"
echo "a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c  $tool_root/godot.zip" | sha512sum --check
unzip -qo "$tool_root/godot.zip" -d "$tool_root/godot"
ln -sf "$tool_root/godot/Godot_v4.6.3-stable_linux.x86_64" "$tool_root/godot/godot"
curl -fsSL 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_x64_linux_hotspot_17.0.20.1_1.tar.gz' -o "$tool_root/jdk.tar.gz"
echo "3808d1d15e3ec6bd5b84057fb5d84c33d8a1536a258146bcea2e603fc726e08e  $tool_root/jdk.tar.gz" | sha256sum --check
mkdir -p "$JAVA_HOME"
tar -xzf "$tool_root/jdk.tar.gz" --strip-components=1 -C "$JAVA_HOME"
curl -fsSL https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz -o "$tool_root/templates.tpz"
echo "da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68  $tool_root/templates.tpz" | sha512sum --check
unzip -qo -j "$tool_root/templates.tpz" 'templates/android*' 'templates/version.txt' -d "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"
curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -o "$tool_root/sdk.zip"
echo "5fdcc763663eefb86a5b8879697aa6088b041e70  $tool_root/sdk.zip" | sha1sum --check
unzip -qo "$tool_root/sdk.zip" -d "$tool_root"
if [[ ! -d "$ANDROID_HOME/cmdline-tools/19.0" ]]; then mv "$tool_root/cmdline-tools" "$ANDROID_HOME/cmdline-tools/19.0"; fi
export PATH="$JAVA_HOME/bin:$tool_root/godot:$ANDROID_HOME/cmdline-tools/19.0/bin:$ANDROID_HOME/platform-tools:$PATH"
python3 -c 'print("y\n" * 100)' > "$tool_root/license-responses"
sdkmanager --sdk_root="$ANDROID_HOME" --licenses < "$tool_root/license-responses"
sdkmanager --sdk_root="$ANDROID_HOME" 'platform-tools' 'build-tools;36.1.0' 'platforms;android-36' 'ndk;28.1.13356709' 'cmake;3.10.2.4988404'
curl -fsSL https://github.com/google/bundletool/releases/download/1.18.3/bundletool-all-1.18.3.jar -o "$tool_root/bundletool.jar"
echo "a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29  $tool_root/bundletool.jar" | sha256sum --check
export BUNDLETOOL_JAR="$tool_root/bundletool.jar"
cat > "$XDG_CONFIG_HOME/godot/editor_settings-4.6.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]
[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "$JAVA_HOME"
SETTINGS
mkdir -p "$HOME/.android"
# Persist environment for later steps in this same GitHub Actions job.
for variable in XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME ANDROID_HOME ANDROID_SDK_ROOT ANDROID_USER_HOME JAVA_HOME GRADLE_USER_HOME BUNDLETOOL_JAR; do
  printf '%s=%s\n' "$variable" "${!variable}" >> "$GITHUB_ENV"
done
printf '%s\n' "$JAVA_HOME/bin" "$tool_root/godot" "$ANDROID_HOME/platform-tools" >> "$GITHUB_PATH"
godot --version
javac -version
