# Blockora — UIX-B.1 Smooth Drag & Drop verification

Date: 2026-10-11. Repository `digitalfuturesolutions69/blockora`, branch `work`.
Approved baseline, local HEAD and remote `origin/work`: `25203906e3daba5fe4dad146b170d649bec2be69`.
The checkout was clean before edits. No stage, commit, push, workflow change or subsequent UIX gate is part of this delivery.

## Findings and limits of diagnosis

Review covered the UIX-A specification, UIX-B evidence, PuzzleSurface, ClassicApp input/refresh/lifecycle, existing touchscreen/layout/audio tests and SFX. Existing expand fullscreen/safe-area conversion, native touch ownership, emulated-mouse exclusion and deferred surface replacement remain intact.

Three observable contributors were found:

1. Godot's `Input.use_accumulated_input` was true, including during active drag. This groups motion at frame dispatch. A focused injected-event test now verifies the latest motion is consumed without awaiting a process frame once the gesture is established.
2. Every `_move()` called `can_place()`, even when the candidate origin stayed constant. A 10,000-update same-cell probe called it 10,000 times before the change. The new cache calls it only when the candidate changes or a new gesture begins.
3. Pickup immediately changed the ghost from tray-cell size (at most 27 logical units) to board-cell size, with a fixed above-finger offset. This source-supported discontinuity was removed: the initial ghost uses the actual grab position, 4% enlargement and an eight-unit lift, then continuously transitions over 24 logical units of pointer travel to the existing board-size/above-finger geometry.

These are demonstrated engine/source behaviors, **not proof of a single physical-device root cause**. Cloud headless tests do not measure screen pixels, Android touch sampling, input-to-photon latency, GPU frame time or perceived smoothness. Low frame rate, manufacturer behavior and actual device rendering remain unmeasured. No repeated per-motion UI rebuild or time-based pointer smoothing existed in the baseline, and neither was introduced.

## Implementation

Only presentation drag behavior changes:

- Raw motion dispatch is enabled while a single pointer owns a gesture. The exact previous accumulation setting is restored on accepted/invalid release, cancellation, pause, resize, session replacement and scene exit. Mouse emulation remains enabled for GUI buttons; synthetic mouse events remain excluded from gameplay.
- Pointer position is used immediately. Pickup scale and offset depend on spatial travel rather than a trailing interpolation timer. Candidate coordinates use the same current offset as the ghost; final above-finger placement geometry and `pointer_for_origin()` stay unchanged.
- Candidate validity is cached for the fixed board/piece while the candidate origin remains unchanged. The application/domain still confirms every placement transaction authoritatively. No presentation animation changes board, tray, RNG, score or save data.
- Ghost rendering uses existing primitive drawing, cached background and cells, one light shadow, and no additional scene nodes, textures or shaders. `queue_redraw()` coalesces drawing requests; it does not rebuild the GUI per packet.
- Invalid in-control release relinquishes pointer/input ownership immediately and shows a bounded 120 ms cubic return to the tray. Per-frame processing is enabled only during that return and stops when finished. Lifecycle cancellation removes it immediately. A subsequent pickup replaces it. Accepted moves and SFX still originate from the existing controller confirmation.
- Existing square board, safe margins, resize cancellation, non-color-only preview marks, scoring, Fair Play, save contracts, package ID, SDK 36, SFX settings and audio sources are unchanged.

No Crystal Pop renderer, clear particles, theme selector, audio redesign, Daily or Retention feature is implemented.

## Commands and final outcomes

Activate the prepared toolchain:

```bash
source /workspace/toolchains/blockora-env.sh
bash tools/test.sh
bash tools/test_relax.sh
bash tools/test_extended.sh
bash tools/build_android.sh
```

All four final commands exited **0**. Final automated logs have no `SCRIPT ERROR`, parser error, unexpected `ERROR:`, segmentation fault or ObjectDB leak warning. The process-recovery suite intentionally SIGKILLs its own checkpoint child; this is controlled fault injection, not an unexpected crash.

A baseline general runner also passed before edits. The focused new drag runner passed separately, then again inside the final general runner. Duplicate baseline/focused runs are excluded from the total below.

| Final suite | Cases / sessions | Assertions/checks | Failures |
| --- | --- | --- | --- |
| Foundation | 7 | 35 | 0 |
| Classic gameplay | 36 | 6,623 | 0 |
| Fair Play unit | 11 | 27,578 | 0 |
| Touch/mouse integration | 14 | 89 | 0 |
| Lifecycle/freed-node | 2 | 8 | 0 |
| Audio integration | full suite | 187 | 0 |
| Responsive/safe-area | 8 configurations, 1,024 cell placements | 4,674 | 0 |
| New drag integration | 2 modes, 20,000 same-cell motions, 40 repeated placements | 168 | 0 |
| Classic smoke | 100 sessions | 25,990 | 0 |
| Fair smoke | 100 sessions | 19,468 | 0 |
| Relax unit/malformed saves | includes 134 malformed checks | 2,175 | 0 |
| Relax input/save isolation | 8 cases, 1,000 mode switches | 1,039 | 0 |
| Relax deterministic simulation | 10,000 | 5,472,836 | 0 |
| Relax process recovery | 1 deliberate SIGKILL checkpoint | 4 | 0 |
| Extended Classic simulation | 10,000 | 2,357,854 | 0 |
| Extended Fair simulation | 10,000 | 1,972,676 | 0 |
| Randomized Fair simulation | 1,000 | 113,678 | 0 |

Total primary final verification: **10,005,082 checks/assertions, zero failures**.

The new suite uses `Input.parse_input_event()` and actual controllers in both modes, an actual 1080×2400 window, DPI 480 and cutout/navigation inset fixtures. It verifies same-dispatch motion position, pickup geometry, final ghost scale and cell preview, bounded evaluation, stable surface identity, zero pre-release mutation, multitouch exclusion, one accepted move/score/SFX, rejected placement, return cleanup, exact prior-input-setting restoration (true and false), OS cancellation, pause/resume and teardown. Existing suites cover desktop mouse, all-cell mapping across eight resolutions/inset/font fixtures, invalid overlap, outside release, resize and save compatibility.

During development the new fixture initially checked an accumulated initial press before dispatch, then retained a surface freed by deferred refresh; it also initially restarted a playing Classic session without the required pause. Fixture corrections await the initial press dispatch, guard initialization, follow pause-before-restart and compare exact placed-cell score. An indentation typo in that correction was fixed. These preliminary runs were **not PASS** and are not counted. Production gameplay/persistence was not changed to satisfy the fixture. Final suites reran after these corrections and passed.

Raw outputs in this workspace: `/tmp/blockora-uix-b1-baseline.txt`, `/tmp/blockora-b1-final-tests.txt`, `/tmp/blockora-b1-final-relax.txt`, `/tmp/blockora-b1-final-extended.txt`, `/tmp/blockora-b1-android.txt`. Temporary failed-fixture diagnostics are also outside the checkout; none are included as source artifacts.

## Determinism, fairness and persistence

Relax seeds 0–9,999: 860,313 accepted moves; 290,958 fresh trays; **0 violations, 527 repairs, 0 sampler fallbacks**. Same-seed replay and JSON save/resume checks execute within every simulated session. Scores mean 466.9988, median 418, p95 949, range 45–2,557. Length mean 86.0313 moves, median 77, p95 167, range 16–440.

Extended Fair seeds 0–9,999: 262,968 moves; 91,900 eligible trays; **0 violations, 627 repairs, 0 fallbacks; 10,000 replays passed**. Randomized Fair seeds 0–999, action seed offset 104729: 14,897 moves; 5,399 eligible trays; **0 violations, 48 repairs, 0 fallbacks; 1,000 replays passed**. Classic completes 260,575 moves over 10,000 sessions; longest session 106 moves. Dedicated regression and existing malformed-save/process-recovery tests confirm Classic/Relax compatibility and isolation.

## Performance observations

Environment: cloud x86_64, five available logical CPUs, Godot 4.6.3 stable, headless display. Final regression runners overlapped; timings are subject to shared CPU scheduling.

A temporary counting-board probe (`/tmp/blockora-drag-probe.gd`) warms one candidate, then performs 100 batches of 100 sub-cell `_move()` updates on the same candidate using seed 222. No board mutation occurs. Before/after logs: `/tmp/blockora-drag-before.txt`, `/tmp/blockora-drag-after.txt`.

| CPU-only observation | Before | After |
| --- | --- | --- |
| Redundant placement queries for 10,000 warmed same-cell updates | 10,000 | 0 |
| 100-update batch p95 | 144 µs | 54 µs |
| Maximum 100-update batch | 247 µs | 98 µs |
| Input accumulation during gesture | true | false |

The checked-in integration suite separately verifies one necessary query for each initially unknown candidate across 10,000 injected motion events per mode. These microbenchmarks do **not** establish Android FPS or visual latency.

Relax simulation: 191,815 ms, maximum generation 4,363 µs. Dedicated generation/save/load p95: 509 / 180 / 762 µs; maxima 7,923 / 422 / 1,760 µs. Mode switching p95 27,643 µs, max 32,196 µs (includes four scene frames). Memory samples grow 1,001,288 bytes from initial across 1,000 switches; last 200-switch interval is 48 bytes. Extended Fair simulation 91,050 ms, max generation 3,478 µs; randomized 6,218 ms, max 1,235 µs. These are CPU/filesystem measurements, not Android rendering/audio acceptance.

## Android artifacts

Both ignored outputs built after automated verification. Existing verifier passes APK package/SDK/permissions/debug signature and AAB bundletool/SDK/portrait/plugin checks. The AAB is an unsigned test bundle. The existing optional ADB query reports daemon connection refused; no installation/device validation occurred.

| Artifact | Bytes | SHA-256 |
| --- | --- | --- |
| `builds/blockora-debug.apk` | 84,966,137 | `6589859d5aa2fd4ec00e46dfb8d613546c0d63fd9dabd306a8967bd38002acc9` |
| `builds/blockora-test.aab` | 32,514,237 | `1eb0040cbef7c9fecbedcd4861bd45b0d7ecf66f47fcf11cff8725d94c17d7ab` |

No AdMob runtime or Play Billing transaction test is claimed.

## Complete change manifest and hygiene

**2 modified + 3 new files**, all uncommitted/unstaged:

- Modified: `scripts/presentation/puzzle_surface.gd` — scoped motion dispatch, spatial pickup, candidate cache, shadow/return and cleanup.
- Modified: `tools/test.sh` — register the new strict drag integration runner.
- New: `tests/integration/run_drag_tests.gd` — focused input/controller/audio/cleanup regression.
- New: `tests/integration/run_drag_tests.gd.uid` — legitimate Godot script UID metadata.
- New: `docs/testing/uix-b1-verification.md` — this evidence and owner/device review checklist.

`git diff --check` and limited credential/private-key/signing-file scan pass. Generated Godot caches, Android/plugin build outputs, APK/AAB, signing files and temporary diagnostics remain ignored/outside the checkout. No workflow, domain, scoring, Fair Play, save schema, audio source/preferences, fullscreen/project or export-preset modifications are included. No commit or push was performed; local and remote HEAD remain the approved baseline.

## Hosted CI gap and proposed improvement

This uncommitted gate has **no hosted run**. The previous hosted run for baseline 2520390 passed the general/extended runners, APK/AAB and upload, but did not execute `tools/test_relax.sh`: dedicated Relax regression, 10,000 Relax simulations and process recovery were local-only.

Proposal for separate approval: add a named workflow step running `bash tools/test_relax.sh` after the general runner and before Android build, keeping strict exit/error handling, pinned toolchain, existing permissions and the 40-minute timeout. Measure hosted duration before adjusting timeout. The general runner will include the new drag suite once this gate is separately approved for commit/push. No workflow modification or hosted-coverage claim is made here.

## Physical Android acceptance — DEVICE VALIDATION PENDING

Install on an authorized arm64 test device:

```bash
adb install -r builds/blockora-debug.apk
```

Record phone/SoC/RAM, Android version, resolution, density, navigation mode, display refresh rate and build hash. Validate Classic and Relax:

1. Confirm fullscreen, cutout/gesture/three-button safe areas and square board/tray/Pause/dialog bounds remain correct.
2. Pick up pieces from center/edge/blank tray areas. Confirm small immediate lift, comfortable size transition, shadow, accurate finger relationship, no jitter or trailing lag, and legible preview in all board corners.
3. Release valid/invalid/outside drops rapidly. Check exactly one move/score/primary SFX, correct target occupancy and smooth invalid return without mutation. Try new pickup during return.
4. Test two fingers, canceled touches, pause during drag/return, background/lock/unlock, resize/inset changes, resume, restart and sustained mode switching. No delayed placement/audio or orphan ghost is permitted.
5. Compare touch-to-visual latency, frame-time p95/p99, GPU/CPU load and memory on a nominated low-end device against the baseline, using actual profiling/recording. The raw-input mode may increase event processing at high sampling rates; benchmark that device behavior rather than inferring it from cloud CPU timings.
6. Listen for placement/invalid and single/double/multi-clear/combo/game-over cues; verify volume/mute/background handling and saves after process restart.

The cloud environment has no physical Android evidence. Actual perceived smoothness, FPS, input-to-photon and audio synchronization remain pending. **Automated UIX-B.1 PASS; owner/device review required before UIX-C or any commit/push.**
