# Phase 0B verification — Blockora

Decision: **FASE 0B PARTIAL / BLOCKED**. Local foundation, compilation, and artifact checks pass. Device/Play runtime validation and hosted CI are not complete. No Phase 1 work or production publishing was performed.

Date: 2026-10-10. Commands execute in `/workspace/blockora` after `source /workspace/toolchains/blockora-env.sh`, unless specified otherwise. Exit statuses were checked; no skipped or zero-test run is reported as passed. Evidence logs normalize ANSI escapes and trailing whitespace while preserving command outcomes.

## Initial inspection

- Working directory and origin: `/workspace/blockora`, `https://github.com/digitalfuturesolutions69/blockora.git`.
- Existing branch: `work`, valid symbolic unborn branch `refs/heads/work`; initial HEAD did not exist and the working tree was empty.
- Read `/workspace/toolchains/BLOCKORA-SETUP.md` and actual tool versions/template files. No prior implementation or AGENTS.md was present. No nested Git repository, worktree, history rewrite, reset, or push was created.
- Reused the published environment. Actual tool output is in [toolchain evidence](evidence/toolchain.txt).

## Verification matrix

| ID | Requirement | Command | Expected | Actual | Status | Evidence |
|---|---|---|---|---|---|---|
| ENV-01 | Engine/parser | `godot --version`; `bash tools/test.sh` | 4.6.3 and all GDScript checks exit 0 | 4.6.3; editor import and every discovered GDScript checked | PASS | [Toolchain](evidence/toolchain.txt), [tests](evidence/headless-tests.txt) |
| ENV-02 | JDK compiler | `java -version`; `javac -version` | JDK17 runtime/compiler | Temurin 17.0.20.1+1, javac17.0.20.1 | PASS | [Toolchain](evidence/toolchain.txt) |
| ENV-03 | SDK/platform/build tools | `sdkmanager --sdk_root="$ANDROID_HOME" --list_installed` | SDK36, build-tools36.1.0 | Installed under `/workspace/toolchains/android-sdk` | PASS | [Toolchain](evidence/toolchain.txt) |
| ENV-04 | NDK/CMake availability | Pinned NDK `clang --version`; pinned `cmake --version` | Executables work | NDK28.1.13356709 clang19.0.0; CMake3.10.2 | PASS | [Toolchain](evidence/toolchain.txt) |
| ENV-05 | Export templates | `ls "$XDG_DATA_HOME/godot/export_templates/4.6.3.stable"` | Matching APK and source templates | Android debug/release/source present | PASS | [Toolchain](evidence/toolchain.txt) |
| TEST-01 | Bootstrap scene | `godot --headless --path . --quit-after 2` | Startup marker, no external services required | `BLOCKORA_BOOTSTRAP_READY`, exit0 | PASS | [Tests](evidence/headless-tests.txt) |
| TEST-02 | Behavioral unit/integration checks | `godot --headless --path . --script tests/smoke/run_tests.gd` | Nonzero real checks; no failures | 7 cases, 35 checks, 0 failures | PASS | [Tests](evidence/headless-tests.txt) |
| TEST-03 | Service isolation/fallback | Same test runner | Five interfaces, no-op failures safe; no premium/reward | Interfaces, forwarding, null bridge and fail-closed checks pass | PASS | [Tests](evidence/headless-tests.txt) |
| TEST-04 | Local storage | Same test runner | Roundtrip/replacement; invalid keys/corrupt JSON handled | Commit/read, replacement, traversal rejection and corruption checks pass | PASS | [Tests](evidence/headless-tests.txt) |
| ADS-01 | AdMob compile feasibility | `bash tools/build_platform.sh`; `bash tools/build_android.sh` | Native callbacks compile; SDK/bridge packaged | Original bridge + GMA25.5.0 compiled and in APK/AAB DEX | PASS | [Build](evidence/android-build.txt), [artifact verification](evidence/android-artifacts.txt) |
| ADS-02 | Actual Google test ad load | Requires explicit Android device probe | Test load callback observed on device | No attached device; no ad request executed | BLOCKED | [ADB devices](evidence/devices.txt); **BLOCKED — REAL DEVICE REQUIRED** |
| BILL-01 | Billing compile feasibility | Same native/export commands | Billing9.1 connect/query/restore/pending/ack APIs compile | SDK and original bridge compiled and packaged | PASS | [Build](evidence/android-build.txt), [artifact verification](evidence/android-artifacts.txt) |
| BILL-02 | Purchase/ack/restore/revoke transactions | Requires Play-installed build, product/testers and implementation | Real tester transactions and state transitions evidenced | No purchase launch/verification workflow, Play test build or tester access | BLOCKED | [Feasibility details](platform-feasibility.md); **BLOCKED — PLAY CONSOLE TESTING REQUIRED** |
| AND-01 | Debug APK | `godot --headless --path . --export-debug 'Android Debug APK' builds/blockora-debug.apk` | Export exits0; signature/manifest/SDK/bridge validated | Signed debug APK exported and `apksigner verify` passed | PASS | [Build](evidence/android-build.txt), [artifacts](evidence/android-artifacts.txt) |
| AND-02 | Unsigned AAB | `godot --headless --path . --export-debug 'Android Test AAB' builds/blockora-test.aab`; `python tools/verify_android.py` | Valid unsigned AAB, target36/min26/portrait | Bundletool validation and effective manifest checks passed | PASS | [Artifacts](evidence/android-artifacts.txt), [manifest](evidence/aab-manifest.xml) |
| AND-03 | API36 compatibility | `bash tools/build_android.sh` | API36-supported AGP with no unsupported-compile-SDK suppression | AGP8.10.1 override, Gradle8.11.1, final native/APK/AAB checks passed | PASS | [Build](evidence/android-build.txt), ADR-003 |
| AND-04 | Permission review | `python tools/verify_android.py` | Only reviewed permissions; no AD_ID/location/foreground permission | Network/Billing/WAKE_LOCK/app signature receiver permission only | PASS | [Artifacts](evidence/android-artifacts.txt), [manifest](evidence/aab-manifest.xml) |
| AND-05 | Real Android startup/offline/minSDK/lifecycle | Device installation/launch/interruption tests | Correct behavior on API26+ reference device | No attached device | BLOCKED | [ADB devices](evidence/devices.txt) |
| AND-06 | Release signing/production publishing | Not authorized in this phase | No production key/publish action | Debug APK only; AAB intentionally unsigned; release not run | NOT RUN | Export presets/workflow; no release credentials in Git |
| CI-01 | Workflow static validation | `actionlint -shellcheck='' .github/workflows/android.yml`; `bash -n` on each shell script | Valid workflow/expressions/scripts | actionlint1.7.7 exit0; shell script syntax passes; shellcheck unavailable | PASS | [CI validation](evidence/ci-validation.txt) |
| CI-02 | Hosted GitHub Actions run | Requires approved push/dispatch | Hosted job evidence | No push or dispatch performed; no hosted run claimed | NOT RUN | `.github/workflows/android.yml`; owner approval needed for push |
| SEC-01 | Credential/signing material scan | `python tools/secret_scan.py` | No common credentials or staged keystores | Limited pattern/file-name scan passed | PASS | [Security evidence](evidence/security.txt) |
| GIT-01 | Whitespace/staged content review | `git diff --check`; `git diff --cached --check`; review staged file list | No errors/unrelated files/signing material | Passed before local commit; final hash reported in execution summary | PASS | Source review and final Git status |

## Failures investigated and corrected

1. Native standalone module initially lacked `android.useAndroidX=true`: added the supported property and retried.
2. Explicit compile-only annotation1.9.1 conflicted with runtime's consistent annotation1.8.1: removed the redundant direct dependency and used the resolved SDK annotation dependency.
3. Deprecated Godot `runOnUiThread` calls were replaced with `runOnHostThread`; final native compilation has no deprecation warning from these calls.
4. Manifest verifier initially rejected WAKE_LOCK/FOREGROUND_SERVICE. Merger provenance identified Google transport/WorkManager sources. WAKE_LOCK is necessary for those SDK jobs and documented/allowlisted; unused foreground service and permission were removed. AD_ID/location/ad-services permissions remain removed. Actual SDK operation under these restrictions still requires device testing.
5. Template AGP8.6.1 emitted an unsupported API36 warning. Upgraded to8.10.1 in both native and generated app config, keeping Gradle8.11.1, and repeated exports. No warning suppression or checksum/TLS bypass used.
6. A manual verifier invocation before environment activation failed with unset ANDROID_HOME. Repeated it after documented activation; the build script and final verification succeed. This confirms shell activation is a prerequisite.

## Scope and remaining limitations

No gameplay, solver, Daily manifest, premium UI, backend, database, accounts, or production app publishing was added. Analytics/crash reporting are no-op. The Billing acknowledgement helper is private and not invoked; no purchase or entitlement lifecycle is claimed working. Native singleton registration, ad callbacks, minSDK device compatibility, privacy/consent behavior and interruption handling remain unverified on-device.

The published environment has NDK28.1 but the template names NDK29.0. Phase 0B packages prebuilt Godot libraries, so no engine/native source rebuild was attempted or claimed. Current APK is a large debug build; no production download-size/performance target is certified.

Dependency versions/licenses and runtime owner actions are in [platform-feasibility.md](platform-feasibility.md). Checksums, artifacts and effective manifest refer to this execution, not a new task or hosted CI run. Environment startup/install instructions are saved separately as a draft; saving does not republish the environment.

All applicable local checks passed for committing the foundation on the existing `work` branch. Commit/hash and clean-tree confirmation are reported after commit; no remote push is authorized. Do not begin Phase 1 until the Product Owner approves the phase transition.
