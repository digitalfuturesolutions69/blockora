# Blockora — UIX-B.1 Hotfix 2: drag stutter/jitter

Report date: 12 October 2026, Asia/Jakarta. Repository `digitalfuturesolutions69/blockora`, branch `work`. Approved baseline/local/remote HEAD: `25203906e3daba5fe4dad146b170d649bec2be69`.

## Workspace and scope

The expected five uncommitted UIX-B.1 files were present before this work. Exact copies and SHA-256 were saved under `/tmp/blockora-hotfix2-before/`. Previous report, runner registration and drag UID remain byte-identical; the presentation implementation and focused tests were extended/corrected within the approved hotfix scope. No reset, clean, discard, stage, commit or push was performed.

Owner-observed physical smoothness remains **FAILED**. Hotfix 2 physical acceptance is **DEVICE VALIDATION PENDING**. CPU improvements and headless tests do not override the owner observation. The installed APK's build hash must be recorded during the next retest.

## Hypotheses examined, in requested order

| Area | Evidence | Conclusion |
| --- | --- | --- |
| A: frame pacing | Engine max FPS 0, configured/default V-Sync enum 1, `gl_compatibility`, physics 60 ticks/s; no custom frame cap or physics-only drag. No attached Android device; headless display cannot measure GPU presentation. | No evidence warrants changing FPS, V-Sync or backend. Android frame mean/median/p95/p99/max remain unmeasured. |
| B: input | Native touch ownership and emulated-mouse exclusion intact. In a controlled 10,000-event synthetic burst, accumulation on took 11,891 µs, off 53,560 µs; both queried one candidate. | Disabling accumulation increases measured burst CPU overhead. This does not prove actual phone delivery/FPS. Normal accumulation is preserved; raw mode is diagnostic-only. |
| C: ghost updates | Prior `_move()` performed geometry/preview work per packet; `queue_redraw()` already coalesced drawing requests. New input stores latest pointer; `_process()` consumes it at most once per frame. | Bound CPU geometry work to a visual frame without time smoothing. No claim that actual GPU draws fell from 240 to 60. |
| D: coordinates | Prior travel-based interpolation changes ghost offset/size within 24 units of pickup. A pointer step of 1 unit produced a ghost step up to 6.3321 units and 128.4218 units of offset drift. | Confirmed **geometric continuity defect** in UIX-B.1. Constant offset gives 1:1 motion with zero offset drift. This is not proof of the phone's sole root cause. |
| E: layout | Ghost is primitive drawing inside PuzzleSurface, not a piece Node placed by a Container. Surface hierarchy remains stable during motion; layout/resize cancels drag. | No demonstrated Container interference; no extra overlay hierarchy introduced. |
| F: allocations/redraw/audio | Existing background/cell cache and candidate cache retained. `_move()` now stores state, with no per-packet preview evaluation, node changes or logs. SFX source and routing unchanged. | Optimize demonstrated CPU/geometry work; GPU drawing stalls remain unmeasured. |

No fullscreen, renderer, project/export settings, domain, scoring, Fair Play, save schema or audio-source changes are made.

## Controlled experiments

Before-snapshot script is `/tmp/blockora-hotfix2-before/probe_surface.gd` (exact behavior copy with its class registration removed to allow side-by-side loading). Source snapshots are also retained unchanged. Reproduce the current comparison:

```bash
source /workspace/toolchains/blockora-env.sh
godot --headless --path . --script tests/diagnostics/run_drag_experiments.gd -- --baseline-surface=/tmp/blockora-hotfix2-before/probe_surface.gd
```

The checked-in experiment runner also works without the optional snapshot argument for current-only geometry/cadence measurements. Historical exact baseline comparison requires the retained snapshot.

| Experiment | Outcome | Decision |
| --- | --- | --- |
| Existing geometry, 48 one-unit upward samples | Max ghost step 6.3321, initial-to-final offset drift 128.4218 | Correct variable offset. |
| Disable pickup scaling only | Max ghost step still 6.3321 | Scaling alone does not remove the defect. |
| Stable geometry | Max ghost step 1.0, offset drift 0 | Retain fixed offset/size throughout drag. |
| Accumulation on/off | 11.891 / 53.560 ms for synthetic 10,000-event injection+flush | Preserve normal accumulation; offer opt-in A/B raw mode. |
| 240 packets in 60 groups: callback work vs frame work | Update opportunities 240 → 60; CPU group mean 1.95 → 1.333 µs, median 2 → 1 µs, p95 2 → 2 µs, p99/max 20 → 6 µs | Keep latest-per-frame geometry. These tiny CPU samples are not rendered frame durations. |
| Every-frame vs every-two-frame update | Latest-pointer error 0 vs 5 logical units | Reject reduced frame cadence: it adds stale visual state. |
| Isolated overlay | No dragged Node/Container conflict found | Not warranted; no speculative rewrite retained. |
| Reduced preview redraw frequency | Ghost/preview share one once-per-frame update; skipping alternate frames fails latest-pointer accuracy experiment | No throttling below visual-frame cadence retained. GPU preview cost remains a device profiling question. |

Environment: cloud x86_64, five available logical CPUs, Godot 4.6.3, headless display. Experiments measure CPU geometry and drawing-submission state, not Android FPS, GPU stalls, rendered pixels or input-to-photon latency. Logs: `/tmp/blockora-hotfix2-experiments.txt`, `/tmp/blockora-hotfix2-after-experiments.txt`.

## Minimal correction

- Initial 4% pickup enlargement, actual grab location, eight-unit lift and shadow are retained. **Size and pointer-to-ghost offset stay constant for the entire drag**; travel-distance interpolation is removed. The compact ghost is separate from the full board-cell footprint preview, and accepted placement uses the normal full-size board cells.
- Input updates the latest local pointer. Active `_process()` applies the newest pointer once per visual frame, using identical local/canvas transforms and fixed offset. There is no physics-tick-only motion or trailing Tween/interpolation.
- Candidate validity is evaluated only when needed, and never for every motion packet. Board preview can remain cell-snapped while the ghost moves continuously.
- Release recomputes the candidate from its actual event coordinates **immediately**, even if no visual frame has consumed the newest motion. No interpolated coordinates or extra visual-frame wait affect authoritative placement.
- Normal engine accumulation is retained. Existing emulated-mouse exclusion, single-pointer ownership, 120 ms invalid return, deferred refresh/free protections and cleanup remain. Raw mode restores the exact prior flag after cancellation/release/teardown.
- Development diagnostics are disabled by default and gated by `OS.is_debug_build()`. With no marker, no sample buffer, per-event clock/log or JSON output is created. Normal release behavior cannot enable them.

The focused test was adapted to the newly approved fixed-size/offset and frame-update behavior, with stronger continuity and final-release assertions. An initial invalid fixture used an origin whose pointer was now outside the Control under the corrected offset; outside cancellation correctly produced no return. It was corrected to find an actual in-Control overlapping placement, preserving rejection/state/return assertions. That preliminary run failed two assertions and is not counted as PASS. No gameplay rule was changed to satisfy the fixture.

## Automated verification

Exact final commands:

```bash
source /workspace/toolchains/blockora-env.sh
bash tools/test.sh
bash tools/test_relax.sh
bash tools/test_extended.sh
bash tools/build_android.sh
```

The general and extended runners exited 0. Relax was repeated after an interrupted tool session to persist its final exit code; `/tmp/blockora-hotfix2-resumed-relax.exit` records 0. Repetition and preliminary experiments are excluded from the primary count. Strict final logs contain no `SCRIPT ERROR`, parser error, unexpected `ERROR:`, segmentation fault or ObjectDB leak warning. Deliberate SIGKILL in process recovery is expected fault injection.

| Suite | Cases/sessions | Checks/assertions | Failures |
| --- | --- | --- | --- |
| Foundation | 7 | 35 | 0 |
| Classic | 36 | 6,623 | 0 |
| Fair Play unit | 11 | 27,578 | 0 |
| Touch/mouse | 14 | 89 | 0 |
| Lifecycle/freed-node | 2 | 8 | 0 |
| Audio integration | full suite | 187 | 0 |
| Responsive/safe-area | 8 configurations, 1,024 placements | 4,674 | 0 |
| Drag/diagnostics | 2 modes, 20,000 same-cell motions, 40 repeated placements | 564 | 0 |
| Classic smoke | 100 | 25,990 | 0 |
| Fair smoke | 100 | 19,468 | 0 |
| Relax unit/malformed saves | includes 134 malformed checks | 2,175 | 0 |
| Relax GUI/persistence/isolation | 8 cases, 1,000 mode switches | 1,039 | 0 |
| Relax simulation | 10,000 | 5,472,836 | 0 |
| Relax process recovery | 1 deliberate SIGKILL | 4 | 0 |
| Classic simulation | 10,000 | 2,357,854 | 0 |
| Fair simulation | 10,000 | 1,972,676 | 0 |
| Randomized Fair | 1,000 | 113,678 | 0 |

**10,005,478 primary checks/assertions, zero failures.** Focused drag verifies fixed offset/size and 1:1 displacement across pickup/candidate boundaries, bounded per-frame evaluation, current-frame coordinates, unchanged hierarchy, final release without an intervening visual update, exact move/score/SFX, invalid return, multitouch, cancellation, pause/resume, teardown, default-off diagnostics, ring capacity/order and summary statistics. Existing native mouse/fullscreen/safe-area/font fixtures, save/malformed-save/process recovery and audio suites remain intact.

Relax seeds 0–9,999: 860,313 moves, 290,958 fresh trays, **0 violations, 527 repairs, 0 fallbacks**; deterministic replay/save-resume checks run in every session. Extended Fair: 262,968 moves, 91,900 eligible trays, **0 violations, 627 repairs, 0 fallbacks, 10,000 successful replays**. Randomized Fair: 14,897 moves, 5,399 eligible trays, **0 violations, 48 repairs, 0 fallbacks, 1,000 successful replays**. Classic: 260,575 moves, longest session 106 moves. Classic/Relax saves and preference isolation pass existing tests.

Logs: `/tmp/blockora-hotfix2-final-tests.txt`, `/tmp/blockora-hotfix2-final-extended.txt`, `/tmp/blockora-hotfix2-resumed-relax.txt`, `/tmp/blockora-hotfix2-android.txt`. The first completed Relax log remains preserved at `/tmp/blockora-hotfix2-final-relax.txt`.

## Android build

Build command `bash tools/build_android.sh` exited **0** after successful automated validation. Existing APK package/min SDK 26/target SDK 36/permission/debug-signature and bundletool AAB/portrait/plugin checks pass. The test AAB has no signature entries. Optional ADB query reported daemon connection refused; no attached device or install was validated.

| Ignored artifact | Bytes | SHA-256 |
| --- | --- | --- |
| `builds/blockora-debug.apk` | 84,970,104 | `21d531f8bd6564e19f32d6934c1f20f85f88d4618ca8e3a44bbc019839e7909d` |
| `builds/blockora-test.aab` | 32,518,344 | `7e873a9fa26def96594d5661132be386c7c8d823465e21e8a5b5b13c8f70afcd` |


## Development-only device data collection

Diagnostics maintain a maximum 512 frame samples. Each sample includes process wall interval, latest pointer, submitted ghost/offset, candidate, motion packet count, draw-call counter and last submitted draw corner. The summary includes engine FPS counter and interval mean/median/p95/p99/max. These are engine CPU/submission observations, **not actual display presentation or input-to-photon**. `input_events` counts native drag/mouse-motion packets, not synthetic GUI actions. No console logging occurs per packet; one JSON file and one compact summary are emitted at gesture end. Profiling/file output can affect diagnostic runs, so final perceptual acceptance must also be tested with diagnostics off.

The new APK is currently a local workspace artifact. It is not downloadable from the existing Actions run and must not be confused with the older APK. A distribution/commit/push action requires separate owner approval.

On a connected computer with ADB, install the approved debug APK and open it once so the app data directory exists. Check the package's `files` directory with `adb shell run-as com.digitalfuturesolutions.blockora ls files`. The commands below use Godot's Android `user://` mapping to app-private `files`; debug `run-as` access is required. Do not clear app data or uninstall: preserve valid saves.

```bash
adb devices -l
adb install -r blockora-debug.apk
adb shell am force-stop com.digitalfuturesolutions.blockora
adb shell run-as com.digitalfuturesolutions.blockora touch files/enable_drag_diagnostics
adb shell run-as com.digitalfuturesolutions.blockora rm -f files/enable_drag_raw_input
adb shell monkey -p com.digitalfuturesolutions.blockora -c android.intent.category.LAUNCHER 1
```

Drag continuously for roughly 10 seconds, across the tray/board and cell boundaries, then release. Collect **before another gesture overwrites the last recording**:

```bash
adb exec-out run-as com.digitalfuturesolutions.blockora cat files/drag-diagnostics-last.json > accumulated.json
```

For the controlled raw-input comparison, stop/restart the same APK with the second marker:

```bash
adb shell am force-stop com.digitalfuturesolutions.blockora
adb shell run-as com.digitalfuturesolutions.blockora touch files/enable_drag_raw_input
adb shell monkey -p com.digitalfuturesolutions.blockora -c android.intent.category.LAUNCHER 1
```

Repeat the same gesture/mode/display refresh rate and collect `raw.json` with the same `adb exec-out ... cat` command. Compare summary intervals/event counts and samples. Compute ghost-step minus pointer-step from adjacent samples to detect geometry discontinuities; compare candidate transitions against observed preview movement. Repeat multiple times in Classic and Relax and record phone/SoC/RAM, Android version, refresh rate, DPI, navigation mode, battery/thermal conditions, video and exact APK hash. FPS counter or process intervals alone do not prove smooth presentation.

Capture scheduling/rendering activity during a separate repeated drag trial with Android Perfetto where supported:

```bash
adb shell perfetto -o /data/misc/perfetto-traces/blockora-drag.perfetto-trace -t 20s sched freq idle gfx view
adb pull /data/misc/perfetto-traces/blockora-drag.perfetto-trace
```

Inspect scheduling, CPU frequency, RenderThread/SurfaceFlinger and available FrameTimeline data with a compatible trace viewer; correlate freezes with the video. Check supported Perfetto categories on the actual phone if the command reports unavailable categories. Android `gfxinfo` may miss Godot's GL SurfaceView frames and must not be treated as complete rendering evidence. No Perfetto/device results were collected in this cloud environment.

Disable both diagnostic modes, restart and perform the actual acceptance run:

```bash
adb shell am force-stop com.digitalfuturesolutions.blockora
adb shell run-as com.digitalfuturesolutions.blockora rm -f files/enable_drag_diagnostics files/enable_drag_raw_input
adb shell monkey -p com.digitalfuturesolutions.blockora -c android.intent.category.LAUNCHER 1
```

Required acceptance: no stop-and-jump, cell-boundary jitter or frame freezes; stable finger offset; accurate preview; no delayed placement; invalid return; exactly one move/score/SFX; mute/volume; multitouch; pause/background/resize/resume; stable Classic/Relax saves and fullscreen. Owner-reported smoothness remains FAILED until this physical retest passes.

## Complete manifest and change control

2 modified + 8 new files relative to HEAD:

- Modified `scripts/presentation/puzzle_surface.gd` — existing UIX-B.1 plus this scoped continuity/frame/diagnostic correction.
- Modified `tools/test.sh` — prior drag runner registration, unchanged in Hotfix 2.
- New `tests/integration/run_drag_tests.gd` — prior suite strengthened for this contract and diagnostics.
- New `tests/integration/run_drag_tests.gd.uid` — prior legitimate UID, unchanged.
- New `docs/testing/uix-b1-verification.md` — prior historical evidence, unchanged.
- New `scripts/diagnostics/drag_diagnostics.gd` and `scripts/diagnostics/drag_diagnostics.gd.uid` — bounded opt-in debug recording.
- New `tests/diagnostics/run_drag_experiments.gd` and `tests/diagnostics/run_drag_experiments.gd.uid` — reproducible geometry/CPU/cadence comparisons.
- New `docs/testing/uix-b1-hotfix2-verification.md` — this report and device procedure.

No generated binaries, cache/import artifacts or signing credentials are source changes. Existing ignore rules retain build/cache exclusions. Whitespace and limited credential/private-key/signing-file scan pass. No workflow change; this uncommitted hotfix has no hosted CI evidence. The previously documented dedicated Relax CI gap remains.

Local/remote HEAD stay at the approved baseline; working tree intentionally contains the above uncommitted changes, index empty. No commit/push, main merge, Play publication, Crystal Pop, themes, Ads/Billing/backend, fairness or scoring change. Stop for owner review before any such action. Remaining uncertainty is on-device frame pacing/input delivery/perceived continuity and diagnostic overhead, not a claimed physical PASS.

Resumed Relax cloud measurements: simulation 195,924 ms, max generation 5,097 µs. Dedicated save/load/generation p95 255 / 1,045 / 499 µs; maxima 3,489 / 2,815 / 3,044 µs. Mode-switch p95 27,639 µs, max 38,485 µs (four scene frames included). Memory growth across 1,000 switches 1,001,288 bytes; last 200-switch interval 48 bytes. Extended Fair simulation 90,675 ms, max generation 3,398 µs; randomized 6,154 ms, max 1,101 µs. These are cloud CPU/filesystem observations, not Android frame-time acceptance.
