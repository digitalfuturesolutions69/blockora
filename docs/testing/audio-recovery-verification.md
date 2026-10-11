# Audio test recovery and Gate UIX-A verification

Date: 11 October 2026, Asia/Jakarta. Repository `digitalfuturesolutions69/blockora`, branch `work`. Local and remote HEAD: `8d89b1a87de2af92ae8b0092f43f5ae64f2760a4`. No stage, commit or push.

## Root cause and minimal correction

The failing disk-preferences fixture saved a fresh Relax session (seed 42) and immediately called `load_session()` on the same `RelaxSessionStore` writer. Saving updates the store's `_revision` to 1. Loading starts with a null selected candidate and only assigns it for `record.revision > _revision`; the equal revision is not selected. Consequently the fixture received null and passed it to `RelaxPolicy.snapshot()`, which requires a real session.

This is misuse of the store's stateful revision cursor in a restart test, not missing/corrupt disk data or a production restart-persistence defect. Production `RelaxController` constructs a fresh store and loads once before later saving; a restarted controller constructs another fresh store. The isolated `user://audio_preferences_<ticks>` directory is created by real `JsonLocalStorage.write_record()`. Fixture cleanup occurs after all comparisons. The test does not share a directory with earlier fixtures; no earlier fixture deletes or overwrites these saves.

Only `tests/integration/run_audio_tests.gd` was corrected during recovery. It now checks Classic initialization, verifies the initially missing Relax save explicitly, creates the intended valid session, requires save return `OK`, loads using a fresh reader, checks non-null before snapshots, verifies exact equality with intended state, and checks the post-preferences load before its original isolation assertion. Existing assertions remain; six checks were added. No production persistence, domain, scoring, fairness, save-schema or SFX implementation change was needed.

The same-store load API remains stateful rather than idempotent. No general persistence API redesign is claimed or included.

## Executed validation

Activate existing environment with `source /workspace/toolchains/blockora-env.sh`. Commands below completed with **exit code 0**, no critical `SCRIPT ERROR`, parser error, unexpected `ERROR:` or crash. Final logs contain no ObjectDB leak warning. Audio assertions count instrumented requests and real engine events, not audible output.

| Suite | Cases / sessions | Checks or assertions | Failures |
| --- | --- | --- | --- |
| Foundation | 7 cases | 35 | 0 |
| Classic gameplay | 36 cases | 6,623 | 0 |
| Fair Play unit | 11 cases | 27,578 | 0 |
| Android-compatible injected GUI/touch/mouse | 14 cases | 89 | 0 |
| Lifecycle / freed-node | 2 cases | 8 | 0 |
| Audio integration | full suite | 187 | 0 |
| Classic smoke simulation | 100 sessions, 2,579 accepted moves | 25,990 | 0 |
| Fair smoke simulation | 100 sessions, 2,595 accepted moves | 19,468 | 0 |
| Relax policy/unit | includes 134 malformed-save matrix checks | 2,175 | 0 |
| Relax input/navigation/save isolation | 8 cases, 1,000 mode switches | 1,039 | 0 |
| Relax deterministic simulation | 10,000 sessions, 860,313 moves | 5,472,836 | 0 |
| Process recovery | 1 intentional SIGKILL at injected partial temp write | 4 | 0 |

Combined primary suites: **5,556,032 checks/assertions, zero failures**. Standalone rerun of the 187 audio checks is not double-counted. Benchmark samples are separate. No extended 10,000-session Classic/Fair rerun was required for this fixture-only correction; the 100-session smoke/replay runners were executed and the approved prior extended results remain historical evidence.

Commands: `godot --headless --path . --script tests/integration/run_audio_tests.gd`, `bash tools/test.sh`, `bash tools/test_relax.sh`. The general runner imports and checks all GDScript sources, executes baseline suites plus audio, simulations and bootstrap. The Relax runner executes units, GUI integration, deterministic simulation, benchmark and process recovery. Strict runners reject Godot error logs in addition to checking exit status.

Logs in the current execution workspace: `/tmp/blockora-audio-recovery-suite.txt`, `/tmp/blockora-audio-recovery-regression.txt`, `/tmp/blockora-audio-recovery-relax.txt`. These are temporary diagnostic outputs, not files proposed for commit.

## Audio and persistence coverage

Verified ordinary placement, one/two/three-plus clears, simultaneous row+column counted as one two-line cue, Classic combo and terminal move, invalid touch drop, no clear on rejected placement, native/emulated/multitouch deduplication, bounded two-voice playback, mute/zero/live volume, 70% legacy default, malformed volume fallback, real JSON preference reload, background/pause/foreground, duplicate confirmation signals, and no playback on save/resume or recreated app. Both real Classic and Relax controllers were exercised.

The corrected fixture verifies exact Relax snapshot before/after preferences, unchanged Classic session/best records, and persisted mute/volume through a fresh JSON storage/controller. Existing malformed Relax-save rejection and process-termination backup tests pass. Classic and Relax game save contracts remain unchanged.

Eight original synthesized mono 22,050 Hz 16-bit PCM cues occupy **115,540 bytes**; provenance/CC0 dedication for audio output and device listening checklist are in `docs/audio/gameplay-sfx.md`. Daily victory is reserved and unconnected; no Daily gameplay or music added.

Relax seeds **0–9,999**, score mean **466.9988**, median **418**, p95 **949**, min/max **45/2,557**; session-length mean **86.0313**, median **77**, p95 **167**, min/max **16/440**. **290,958 fresh trays, zero fairness violations, 527 repairs, zero sampler fallbacks**. Same-seed replay compares every accepted move and JSON save/resume at move 4 in each session. Fair smoke also has zero contract violations, 903 eligible/fresh trays, 2 repairs, zero sampler fallbacks and 100 successful replays.

Cloud x86_64, five logical CPUs, Godot 4.6.3, headless display; Android build ran concurrently during part of the Relax simulation. Relax simulation elapsed **201,707 ms**, observed maximum generation **17,562 µs**. Dedicated benchmark p95 save **251 µs**, load **964 µs**, generation **486 µs**; maxima **1,052 / 7,123 / 4,625 µs**. Mode-switch p95 **27,639 µs**, max **70,727 µs**, including four scene frames; memory delta across 1,000 switches **1,005,200 bytes**, final 200-switch interval **48 bytes**. These are cloud measurements, not Android responsiveness or audible latency claims.

## Android artifacts

`bash tools/build_android.sh` completed with exit 0. APK debug signature/package/min SDK 26/target SDK 36 checks passed; bundletool test-AAB validation, portrait, permissions and plugin metadata checks passed. Existing Android/package/signing configuration is unchanged.

| Ignored artifact | Size bytes | SHA-256 |
| --- | --- | --- |
| `builds/blockora-debug.apk` | 84,960,662 | `063a88d00d7bad55386944f51bb2b52a45f81ff217b3ccd761cf1af66a277dda` |
| `builds/blockora-test.aab` | 32,508,648 | `62a6ed3e4186165694d68ecd871969155683c8a8dba7686a21efa6f451067354` |

No attached Android device was available; export's optional ADB query reported daemon connection refused. No install or physical listening took place. Install on an authorized device with `adb install -r builds/blockora-debug.apk`, then execute the device checklist in the audio document. **DEVICE VALIDATION PENDING**. Neither AdMob runtime nor Billing transactions were tested or declared PASS.

## UIX-A result

`docs/design/uix-gate-a.md` provides the requested source audit, fullscreen investigation, Crystal Pop/Soft Zen/Night Glow tokens, screen proposals, bounded line-clear effects, accessibility, audio/licensing plan, performance targets, test plan, future manifest and dependencies. A temporary read-only headless probe returned exit 0 and confirmed effective fixed 720×1280 canvas with `keep` aspect at all five requested sizes. It reproduced centered vertical letterboxing of 160/0/210/240/320 pixels per edge respectively. No fullscreen/rendering/effect/theme code or configuration was implemented.

The probe is outside the checkout (`/tmp/blockora_uix_a_probe.gd`); output `/tmp/blockora-uix-a-layout.txt`. Android safe areas return empty on the headless backend and require actual device verification. UIX-A is complete for owner review; later UIX gates are unimplemented and require separate approval.

## Complete working-tree manifest

**6 modified + 9 new = 15 files**, all unstaged. The seven previously new SFX files and all six previous modifications are preserved. Recovery changes only the audio test among those files; two new audit/verification documents were added.

Modified:

- `scripts/application/classic_controller.gd` — optional persisted SFX volume and preference notification.
- `scripts/presentation/classic_app.gd` — reusable audio routing, shared settings/volume UI and lifecycle handling.
- `scripts/presentation/puzzle_surface.gd` — invalid in-control drop event; existing native-touch filtering unchanged.
- `tests/integration/run_input_tests.gd` — audio-thread teardown wait; existing assertions preserved.
- `tests/unit/run_gameplay_tests.gd` — expected preferences include default volume; original sound/vibration assertion retained.
- `tools/test.sh` — audio test registration in strict general runner.

New:

- `docs/audio/gameplay-sfx.md`
- `docs/design/uix-gate-a.md`
- `docs/testing/audio-recovery-verification.md`
- `scripts/audio/gameplay_audio.gd`
- `scripts/audio/gameplay_audio.gd.uid`
- `scripts/audio/sfx_library.gd`
- `scripts/audio/sfx_library.gd.uid`
- `tests/integration/run_audio_tests.gd`
- `tests/integration/run_audio_tests.gd.uid`

Generated Godot cache/imports, Android build directories/plugin AAR, APK/AAB and debug signing files remain ignored. Legitimate new `.gd.uid` metadata is retained. `git diff --check` and limited common-credential/private-key/signing-file scan pass; this pattern scan is not a comprehensive security audit. No unrelated tracked modifications, unexpected untracked files or staged content were found. Working tree is intentionally not clean because approved SFX and documentation remain uncommitted. STOP for owner review before any further UIX implementation or version-control operation.
