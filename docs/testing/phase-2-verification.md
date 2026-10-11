# Phase 2 — Gate C recovery and local verification

Repository digitalfuturesolutions69/blockora, branch work, HEAD
c858e16d673750f474e9814f3578785c2022233c. All Phase 2 changes remain local and
uncommitted. No push, merge, publication, credential change or Phase 3 work.

| Gate | Result |
| --- | --- |
| A | Previous audit/specification completed; same immediate_fit_v1 contract retained |
| B | Previous engine retained; refill corrected to use staged post-clear board |
| C | PASS: critical input/lifecycle failures resolved, invariant/replay/oracle/benchmark checks pass |
| D | PASS for local builds and automated integration; physical Android acceptance pending |
| E | READY FOR OWNER REVIEW; commit/push require separate authorization |

## Recovery evidence

[Crash investigation](phase-2-crash-recovery.md) records exact before/after
snapshots, pointer positions, shape cells, return codes, native/GDScript stacks,
and a minimal stale-reference reproduction on both approved baseline and
Phase 2. The old fixture's seed call was rejected during PLAYING; a supposed
collision could actually be legal, freeing the old surface before its next
method call. Production transition rules were not weakened. Seed-42 fixture
now asserts accepted state, known board/tray/RNG and unchanged invalid releases.
The existing Android synthetic-mouse guard and presentation code remain intact.

Four deliberate native crashes were recorded while diagnosing the old unsafe
pattern, plus the previously reported Gate C crash. Post-recovery validation
crash count: **0**. Minimal unsafe code still demonstrates a Godot 4.6.3 hazard;
the engine was not patched. Debug-mode script errors with exit 0 were recorded
as diagnostic failures, never passes. New lifecycle tests exercise deferred
refresh ownership, teardown and disconnected callbacks without stale access.

## Tests and numerical results

| Primary named suite | Cases | Assertions/checks | Failed |
| --- | ---: | ---: | ---: |
| Foundation | 7 | 35 | 0 |
| Classic gameplay, scoring, persistence | 36 | 6623 | 0 |
| Fair Play analyzer/provider/integration | 11 | 27578 | 0 |
| Actual injected GUI/touch/mouse events | 14 | 89 | 0 |
| UI lifecycle | 2 | 8 | 0 |
| Total named cases | 70 | 34333 | 0 |

`bash tools/test.sh` passed script parsing/import, all named suites, 100 legacy
sessions (2579 moves, 25990 assertions), 100 fair sessions (2595 moves, 19468
assertions) and bootstrap. `bash tools/test_extended.sh` passed:

| Primary seeded player | Sessions | Moves | Assertions | Failed |
| --- | ---: | ---: | ---: | ---: |
| Legacy first legal | 10000 | 260575 | 2357854 | 0 |
| Fair first legal | 10000 | 262968 | 1972676 | 0 |
| Fair randomized legal | 1000 | 14897 | 113678 | 0 |

Primary full + extended acceptance: **4523999 assertions/checks, zero failures**.
This includes 21200 primary simulated sessions across modes/smokes; overlapping
seed ranges are intentional, not additional distinct seed claims. Mirror runs
are not counted as additional primary sessions. Every one of the 10000 fair
first-legal sessions and 1000 randomized sessions reproduced all snapshots;
JSON save/resume at move four retained consumed slots and next RNG state.
Failures would report seed, action, board, tray, RNG and score and halt early.
No failure reproduction seed remains after recovery; seed 222 diagnoses the old
fixture, not a failed fairness session.

Auxiliary matched 1000-seed legacy/fair measurements passed 189381/200295
assertions respectively. Legacy reference has no immediate-fit promise; its
57 violations of the NEW policy are measurement, not a claim it passed fairness.
Recovered input repeated twice with identical overlap snapshots. The same
recovered input and lifecycle scripts also pass against the archived Phase 1
production code. X11/OpenGL Mesa llvmpipe input/lifecycle runs pass (14/89 and
2/8). V-Sync unsupported on the virtual display; sound uses Dummy. A final
input run after adding a second stale-node guard passes 14/89 again.

## Fairness, distribution and difficulty

The hard invariant is one immediate move in a fresh tray if any catalog shape
fits. It does not promise sequential playability of all three or infinite life.
After clears the remaining tray can legitimately block. Analyzer fixtures cover
empty/nearly full/single legal/no legal boards, order-dependent clear-opening
sequences, boundary/malformed input, immutable evaluation, and exact 256-node
budget exhaustion. 100 adversarial benchmark searches also hit exactly 256.

Main 10000 fair sessions: **91900 fresh/eligible trays, 91900 contract passes,
0 violations (100%)**, 627 repairs (0.6823%), 0 bounded-sampler fallbacks.
Randomized 1000 sessions: 5399 fresh trays, 0 violations, 48 repairs.
Game-over causes were remaining_tray_blocked in all measured fair sessions;
board_exhausted is exercised by synthetic no-placement fixtures. Stable live
boards clear completed lines immediately, so a fully occupied board is not a
persisted live state. No game over was deliberately induced for monetization.

Matched seeds 0..999, same first-legal slot/y/x player:

| Metric | Legacy reference | Fair policy |
| --- | ---: | ---: |
| Fresh trays | 9268 | 9318 |
| Avoidable blocked fresh trays | 57 | 0 |
| Contract percent | 99.38498% | 100% |
| Legal counts min / median / p95 / max | 0 / 48 / 137 / 192 | 1 / 48 / 137 / 192 |
| Mean legal count | 56.7801 | 56.5924 |
| Mean moves | 26.483 | 26.711 |
| Moves min / median / p95 / max | 8 / 23 / 47 / 98 | 8 / 25 / 47 / 98 |
| Mean score | 200.898 | 203.427 |
| Scores min / median / p95 / max | 30 / 174 / 436 / 983 | 30 / 178 / 444 / 983 |
| Repairs | 0 | 59 |

Repair modifies conditional shape/slot distribution and subsequent trajectory.
[Per-shape counts and normalized shares](evidence/phase2/shape-distribution.csv)
show the largest matched marginal change, domino_h, +0.04591 percentage points.
This is descriptive evidence under one player, not a causal estimate of human
difficulty. The main 10000 fair sample has moves min/median/p95/max 8/23/47/106,
mean 26.2968; scores 27/175/423/1169, mean 199.0004. Randomized player mean
length 14.897 and mean score 76.472 demonstrate dependence on player strategy.
Difficulty stays a fixed catalog/policy with no adaptive score/clock weights.

## Performance

Cloud CPU, pinned Godot 4.6.3; these are observed timings, not universal bounds
or low-end device FPS. Main fair simulation: 87498 ms; max observed individual
generation 3528 us. Randomized simulation: 6057 ms, max generation 1113 us.

Benchmark 10000 generations on empty/checkerboard/diagonal-hole/full synthetic
boards: min 3, median 706, p95 885, max **5816 us**, mean 524.5999 us; 4355
repairs, zero invariant failures. 100 diagnostic 256-node searches: max 16350 us.
Lookahead is not called on the live generation or drag paths.

Board benchmark: 200000 fit probes in 146647 us; 10000 deserialize/cross-clears
in 81946 us. Acceptance counters: 100000 valid probes, 150000 removed cells.
Structural live-generation bounds: 32 RNG advances and at most 1728 fit probes;
search caps at 256 simulated placements. No Fair Play allocation or analyzer
work was added to pointer movement; existing cached preview rules remain intact.

## Android artifacts and configuration

`bash tools/build_android.sh` exited 0: native plugin compile, debug APK export,
unsigned test AAB export and verifier PASS. New analyzer/provider resources are
present in both artifacts; tests/docs remain excluded. Package ID remains
com.digitalfuturesolutions.blockora, min SDK 26, target SDK 36, portrait, ARM64,
existing six-permission allowlist, v2 bridge metadata and public test AdMob ID.
Signing credentials and Ads/Billing/backend code were not modified. The dev
version label remains the existing 0.1.0-phase1; this is not a production release.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| builds/blockora-debug.apk | 84943828 | 774ba3ecad320c96b6066edbc280bb7bf2e31182d9b28406fe3e93e15ba0fd0d |
| builds/blockora-test.aab | 32491000 | 2067953dbfead5b0ba8dae730a879a5d5aeccde0d40f3ae466de62e57d8ffe30 |

Godot emitted a nonfatal ADB connection message during export; package
verification succeeded. `adb devices -l` subsequently completed with an empty
attached-device list. **DEVICE VALIDATION PENDING**. No installation or device
acceptance is claimed; AdMob runtime/Billing transactions remain untested.

Owner device checklist: Home/Settings taps exactly once, preferences/Back,
valid drag/drop once, invalid release unchanged, multitouch/cancellation,
background/resume, resize/safe areas, sound/vibration, low-end frame responsiveness
at refill, new-policy save/relaunch/restart and legacy-save resume. Install with
`adb install -r builds/blockora-debug.apk`; if debug signatures differ, preserve
needed saves before uninstall, since uninstall deletes data. AAB is not directly
installable via adb. No Play publication is authorized.

## Files, status and review

[Exact changed-file manifest](evidence/phase2/changed-files.txt) lists all modified
and new paths, including UID metadata and verification evidence. Engine changes
are confined to new BoardAnalyzer/FairPieceProvider, provider hook, staged
session refill/restore and controller new-game selection. Presentation, input
emulation setting, score rules, catalog, platform adapters and export settings
are unchanged. Tests, runners, architecture/rules/ADRs and evidence are updated.

All gates above describe local evidence. No hosted Phase 2 CI run exists, and
there is no new commit. Work remains uncommitted for owner review. Diff checks
and limited credential/signing/artifact scans must pass before any commit;
commit and push need new explicit authorization under the recovery prompt.
