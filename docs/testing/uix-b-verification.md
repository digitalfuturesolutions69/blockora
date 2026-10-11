# Blockora — Gate UIX-B verification

## Scope, baseline and root cause

Repository: `digitalfuturesolutions69/blockora`; branch `work`; approved local and remote HEAD `8d89b1a87de2af92ae8b0092f43f5ae64f2760a4`. All prior six modified/nine new files were recorded with SHA-256 in `/tmp/blockora-uix-b-before.json` before layout changes. Baseline `bash tools/test.sh` passed, including all 187 audio checks. No reset, clean, stage, commit or push was performed.

The omitted stretch aspect resolved to **keep**. With the 720×1280 reference, taller portrait windows retained a 720×1280 logical viewport and centered it vertically, producing 160/210/240/320 unused physical pixels at each edge on the tall requested sizes. Full-rect anchors filled the fixed logical viewport rather than the full window. Existing portrait orientation and Android immersive export were already enabled; no evidence required changing them.

The only project configuration change is explicit `display/window/stretch/aspect = "expand"`. `canvas_items`, the 720×1280 reference, portrait, embedded native dialogs, mouse-from-touch hotfix and renderer remain unchanged. Android package, target SDK 36, min SDK 26, signing and export configuration are unchanged. Physical-device fullscreen acceptance is still pending.

## Implementation

- `UsableLayout.safe_canvas_rect()` intersects Android's physical screen safe rectangle with the actual physical window rectangle, subtracts window origin, transforms through the inverse final canvas transform, and clips to the effective canvas. An inset already removed by the window is therefore not applied twice. Empty/invalid platform safe-area data falls back to the canvas; device validation must confirm the platform returns useful insets.
- ClassicApp applies conservative 24/28 logical-unit interior gutters after safe-area conversion. Resize cancels active drag before applying changed geometry. Android safe-area changes are polled at most four times per second so navigation/cutout changes do not require a full scene reload. Geometry is not rebuilt continuously.
- Controls/tray use a minimum derived from 48 dp using reported DPI and actual canvas scale, with the previous 96-logical-unit touch target retained as a floor. DPI correctness on each device remains a validation requirement.
- Labels wrap within their containers. Existing non-game screens scroll when required; active gameplay does not scroll. Layout metrics support explicit 100–200% font scaling and density/safe-area fixtures. This is not a new appearance/preferences feature and does not claim automatic forwarding of Android's OS font-size preference. Physical OS font-scale behavior requires verification.
- Board size is the smaller available width/height after reserving the hint, bottom gap and accessible tray. One uniform cell size covers all eight rows and columns. The tray's three equal slots remain below the square board and inside the surface.
- A fixed feedback row avoids changing board size when existing SFX clear text appears. Restart confirmation is centered/clamped to the safe content rectangle with accessible native Cancel/Restart buttons; Android Back behavior remains the existing implementation.
- Original single-pointer ownership, emulated-mouse exclusion, inverse canvas pointer mapping, deferred refresh/free lifecycle and all SFX routing/playback/preferences are retained. There are no new rendering styles, particles, animations, themes, Daily or Retention features.

## Responsive matrix: actual engine windows and injected platform metrics

The cloud headless backend cannot measure Android cutouts or density. Tests create actual Godot Window sizes/stretch transforms and inject explicit physical safe rectangles, DPI and font scale through the same conversion path used by Android. These are fixtures, not observed phone measurements.

| Window pixels | Effective logical canvas | Physical safe rectangle (x,y,w,h) | DPI | Font scale |
| --- | --- | --- | --- | --- |
| 720×1600 | 720×1600 | 0,0,720,1600 | 320 | 100% |
| 1080×1920 | 720×1280 | 0,0,1080,1920 | 480 | 100% |
| 1080×2340 | 720×1560 | 0,0,1080,2340 | 480 | 100% |
| 1080×2400 | 720×1600 | 0,0,1080,2400 | 480 | 100% |
| 1440×3200 | 720×1600 | 0,0,1440,3200 | 640 | 100% |
| 1080×2400, cutout/navigation | 720×1600 | 24,96,1032,2160 | 480 | 150% |
| 1080×1920, reduced usable height | 720×1280 | 60,180,960,1500 | 480 | 150% |
| 540×960, small screen | 720×1280 | 0,24,540,888 | 240 | 200% |

All eight cases have zero final-transform translation (no engine letterbox offset) and uniform axes. Safe rectangles round-trip from physical to logical bounds within one pixel. A separate shifted-window case proves no double application of 100-pixel system inset. Touch targets meet at least 48 dp for the supplied density fixtures.

Every case navigates Home → Settings → Back → Classic and Relax through native `Input.parse_input_event()` touchscreen button gestures. Both modes perform all 64 single-cell placements from their real tray, with real drag events and exact expected occupancy/score. Secondary pointer release cannot commit, preview origin and validity match the target before release, and overlapping invalid placement preserves the entire snapshot. Total **1,024 accepted physical-input placements**. Test-only session fixtures reset to an empty board using the existing restore contract; domain/controller placement logic is not bypassed.

The suite also checks entire board/tray/Pause bounds, absence of board/tray overlap, 19-digit int64 score and best labels, fixed clear-feedback geometry, Settings accessibility, Pause/Resume/Home, Cancel/confirm restart, real-engine game over, dialog safe bounds, and lifecycle cleanup. Menus/settings/paused/game-over screens may scroll in constrained or enlarged-text cases; gameplay board/tray/Pause stay simultaneously visible.

## Automated results

All final runners completed with **exit code 0**, zero assertion failures, no critical parser/runtime error, no unexpected `ERROR:` or crash, and no ObjectDB leak warning. Activate the prepared environment with `source /workspace/toolchains/blockora-env.sh`.

| Suite | Cases / sessions | Checks/assertions | Failures |
| --- | --- | --- | --- |
| Foundation | 7 | 35 | 0 |
| Classic gameplay | 36 | 6,623 | 0 |
| Fair Play unit | 11 | 27,578 | 0 |
| Touch/mouse integration | 14 | 89 | 0 |
| Lifecycle/freed-node | 2 | 8 | 0 |
| Audio integration | full suite | 187 | 0 |
| Responsive layout | 8 configurations, 1,024 placements | 4,674 | 0 |
| Classic smoke | 100 sessions | 25,990 | 0 |
| Fair smoke | 100 sessions | 19,468 | 0 |
| Relax unit/malformed saves | includes 134 malformed checks | 2,175 | 0 |
| Relax GUI/persistence/isolation | 8 cases, 1,000 switches | 1,039 | 0 |
| Relax deterministic simulation | 10,000 sessions | 5,472,836 | 0 |
| Relax process recovery | intentional SIGKILL fault checkpoint | 4 | 0 |
| Extended Classic simulation | 10,000 sessions | 2,357,854 | 0 |
| Extended Fair simulation | 10,000 sessions | 1,972,676 | 0 |
| Randomized Fair simulation | 1,000 sessions | 113,678 | 0 |

Total primary verification: **10,004,914 checks/assertions, zero failures**. Baseline and preliminary/standalone repetitions are excluded from this count. Final commands: `bash tools/test.sh`, `bash tools/test_relax.sh`, `bash tools/test_extended.sh`. Responsive tests are now registered in the strict general runner, alongside the prior audio registration.

During development, the new responsive fixture initially had an inferred type error (`confirmed[0]`) and then read drag preview before accumulated `InputEventScreenDrag` dispatch. Minimal fixture corrections supplied `int` and awaited the existing two-frame settling helper before checking the same preview assertion. The assertion was not removed or weakened. No unrelated production/gameplay fix was applied. Final runs include all strengthened preview assertions and pass.

Temporary raw outputs: `/tmp/blockora-uix-b-baseline.txt`, `/tmp/blockora-uix-b-final-tests.txt`, `/tmp/blockora-uix-b-relax.txt`, `/tmp/blockora-uix-b-extended.txt`. These logs are execution evidence outside the proposed source manifest.

Classic/Fair replay and Relax JSON save/resume/process recovery remain deterministic. Relax seeds 0–9,999 reproduce **860,313 moves**, **290,958 fresh trays**, **0 fairness violations**, **527 repairs**, **0 sampler fallbacks**. Extended Fair: **262,968 moves**, **91,900 eligible trays**, **0 violations**, **627 repairs**, **0 fallbacks**, **10,000 successful replays**. Randomized Fair: **14,897 moves**, **5,399 eligible trays**, **0 violations**, **48 repairs**, **0 fallbacks**, **1,000 successful replays**. Extended Classic completes **260,575 moves**, longest session 106 moves.

Cloud x86_64, five logical CPUs, Godot 4.6.3, headless display; some suites ran concurrently. Relax simulation took **194,897 ms**, maximum generation **3,712 µs**. Dedicated cloud benchmark p95 save/load/generation **257 / 1,109 / 601 µs**, maxima **4,106 / 15,537 / 5,486 µs**. Mode-switch p95 **27,622 µs**, max **29,548 µs** (includes four scene frames); memory growth across 1,000 switches **1,001,288 bytes**, final 200-switch interval **48 bytes**. Extended Fair observed generation max **32,267 µs** under shared CPU load. These figures are not Android frame-time, GPU rendering or audio latency claims.

## SFX and save preservation

The eight original cues, 115,540-byte PCM cache, two-voice bound, source event routing, deduplication, mute/volume and lifecycle behavior are unchanged. All pre-existing files outside the three shared integration files (`classic_app.gd`, `puzzle_surface.gd`, `tools/test.sh`) match their pre-UIX-B hashes. Source changes in shared files are layout/runner integration only. Audio tests and their recovered disk fixture are unchanged and pass all 187 checks.

Original domain/scoring/Fair Play, `ClassicSession`, `RelaxPolicy`, `RelaxSessionStore`, `RelaxController` and Android export presets have no new changes. Classic and Relax saves remain isolated and compatible; SFX preferences preserve prior defaults and persisted values. No appearance schema or theme system is added.

## Current complete manifest (all unstaged)

Total **7 modified + 14 new = 21 files**. Prior audio recovery/A-audit manifest of 6 modified + 9 new is preserved; UIX-B adds one tracked configuration change and five new files, and adds layout integration to three already modified files.

| Modified file | Ownership |
| --- | --- |
| `project.godot` | UIX-B only: expand aspect |
| `scripts/application/classic_controller.gd` | Prior SFX only, unchanged during UIX-B |
| `scripts/presentation/classic_app.gd` | Prior SFX plus UIX-B safe layout, text/controls/dialog/feedback geometry |
| `scripts/presentation/puzzle_surface.gd` | Prior invalid-drop SFX event plus UIX-B board/tray sizing |
| `tests/integration/run_input_tests.gd` | Prior SFX teardown wait only, unchanged |
| `tests/unit/run_gameplay_tests.gd` | Prior SFX preference expectation only, unchanged |
| `tools/test.sh` | Prior audio registration plus responsive test registration |

Prior new files, unchanged:

- `docs/audio/gameplay-sfx.md`
- `docs/design/uix-gate-a.md`
- `docs/testing/audio-recovery-verification.md`
- `scripts/audio/gameplay_audio.gd`
- `scripts/audio/gameplay_audio.gd.uid`
- `scripts/audio/sfx_library.gd`
- `scripts/audio/sfx_library.gd.uid`
- `tests/integration/run_audio_tests.gd`
- `tests/integration/run_audio_tests.gd.uid`

UIX-B new files:

- `scripts/presentation/usable_layout.gd`
- `scripts/presentation/usable_layout.gd.uid`
- `tests/integration/run_responsive_layout_tests.gd`
- `tests/integration/run_responsive_layout_tests.gd.uid`
- `docs/testing/uix-b-verification.md`

Required `.gd.uid` metadata is retained. Godot cache/import files, Android/Gradle/plugin generated binaries, APK/AAB, debug signing files and temporary diagnostics remain excluded by existing ignore rules. No unexpected source files or staged content are present. Whitespace and limited credential/signing-file scan are final release hygiene checks, not a comprehensive security audit.

## Android build and final hygiene

Only after all automated runners completed successfully, `bash tools/build_android.sh` completed with **exit code 0**. Existing verification passed APK package/SDK/permission allowlist/debug signature and unsigned test AAB bundletool/SDK/portrait/plugin checks. Export's optional ADB query could not connect to its daemon; no device install or physical test was performed.

| Ignored artifact | Size bytes | SHA-256 |
| --- | --- | --- |
| `builds/blockora-debug.apk` | 84,964,165 | `95cf690cdb4bb27d3a7f53fdbcb8b3bbe460dde55dab3a74db837a9f4b0264b7` |
| `builds/blockora-test.aab` | 32,512,280 | `e2e53b0ace57a97450223a424e7f81c03da8f54e6bac16a60a4cbb20059a5f44` |

Final `git diff --check` passes. Limited scan covers **216 Git candidate files** with no common credential/private-key/signing-file finding; no new generated artifacts enter the manifest. Local and remote HEAD both remain `8d89b1a87de2af92ae8b0092f43f5ae64f2760a4`; all 21 legitimate files remain unstaged/uncommitted. Source, metadata and documentation are the only nonignored changes. Build output is `/tmp/blockora-uix-b-android.txt`. No AdMob runtime or Play Billing transaction validation is claimed.

## Physical Android acceptance checklist — PENDING

After artifact verification, install the new ignored debug APK via `adb install -r builds/blockora-debug.apk`. Use only authorized test devices. No Google Play publication occurs.

1. Capture actual window/client pixels, effective viewport, final canvas transform, display safe rectangle and Android density. Confirm no aspect bars on tall portrait screens, while distinguishing OS status/navigation areas from game content.
2. Test immersive transitions, gesture and three-button navigation, display cutout and rounded corners, app switching, lock/unlock and Android Back. Confirm safe margins update without obscuring Pause/tray/dialog or changing game state.
3. Exercise all listed screens in Classic and Relax at representative phone sizes. Check 19-digit scores, Settings volume slider, restart Cancel/confirm and game over. Check reachability by scrolling on constrained non-game screens.
4. With larger Android fonts/display scaling, confirm actual target sizes, readability and usable board area. Explicit font-scale fixtures pass but automatic OS-to-app font preference forwarding is not established by cloud tests.
5. Drag near every board edge/corner; check preview/release mapping, invalid overlaps, outside/canceled drags, two simultaneous fingers and resize/interruption mid-drag. No double moves or score changes are allowed.
6. Listen for existing SFX timing, mute/volume, clear strengths and combos; ensure no crackle, playback backlog or delayed cue after resume. Confirm both saves survive app/process restart.
7. Record actual device frame time, input latency and responsiveness; cloud CPU timings are not proof of low-end Android performance.

**Automated UIX-B validation PASS; physical fullscreen/device validation PENDING.** No Crystal Pop rendering, themes or animations are implemented. STOP after this report; request owner review before UIX-C.
