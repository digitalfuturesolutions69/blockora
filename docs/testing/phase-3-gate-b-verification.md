# Phase 3 Gate B — local verification

Baseline: a79bd798beff6b46d53da8d7bbf6457af6e8af40; branch work.
Local implementation only. No staging, commit, push, Daily, statistics, streaks,
achievements, Ads/Billing additions or Google Play publication.

## Gates

B1 domain/policy PASS; B2 gameplay integration PASS; B3 persistence/navigation
PASS; B4 automated simulations/regression PASS; B5 cloud performance/regression
PASS. These statuses cover automated local evidence, not physical Android.

Original failures were recorded before these passing runs: two uninferred test
Dictionary variables, unsafe schema String/int comparison, and noisy malformed
JSON.parse_string error logging. Recovery adds explicit Dictionary declarations,
strict Relax boundary type/range/version validation, checked JSON.new().parse,
and persisted schema-token validation preserving legitimate numeric decoding.
Assertions and production gameplay rules were not weakened. The existing menu
assertion now checks one disabled Daily placeholder and enabled Relax instead
of the superseded two-disabled-placeholder requirement.

## Accepted tests

| Suite | Assertions/checks | Failures |
|---|---:|---:|
| Existing 70 named foundation/Classic/Fair/input/lifecycle cases | 34333 | 0 |
| Legacy 100-session smoke | 25990 | 0 |
| Fair 100-session smoke | 19468 | 0 |
| Legacy 10000 sessions | 2357854 | 0 |
| Fair 10000 sessions | 1972676 | 0 |
| Randomized Fair 1000 sessions | 113678 | 0 |
| Relax unit (includes 134 malformed-save checks) | 2175 | 0 |
| Relax input (8 cases; 1000 mode switches) | 1039 | 0 |
| Relax 10000 sessions | 5472836 | 0 |
| Subprocess recovery (one injected SIGKILL checkpoint) | 4 recovery checks | 0 |

Primary total: 10000053 checks, zero failures. Repeated preliminary unit/parser
runs and benchmark samples are not added again to this total. All accepted
commands exited 0, without SCRIPT ERROR, unexpected ERROR, segmentation fault
or infrastructure warning. Logs in evidence/phase3/gate-b retain accepted runs.

Malformed matrix covers missing/String/float/Boolean/null/negative/future schema,
valid supported integer, missing/wrong-type metadata and session/RNG fields,
nonfinite/out-of-range state, invalid board/tray, empty/truncated/syntax/trailing
JSON, non-object root, decoded JSON followed by schema rejection, valid JSON
resume, and no mutation of a valid state. Unit tests retain valid Classic restore,
failed-save atomicity, independent Classic data equality, checksum backup recovery,
unknown-version read-only behavior and actual disk JSON reload. Subprocess test
kills an injected partial-temp-write adapter and confirms old committed hashes,
exact reloaded snapshot, and unchanged Classic sentinel. It does not simulate
power loss or prove all rename/fsync interruption windows on Android.

## Relax simulations and determinism

Seeds 0..9999, first legal slot/y/x player: 10000 finished sessions, 860313 moves,
5472836 assertions, 290958 fresh trays, zero fairness violations, 527 repairs,
zero bounded-sampler fallbacks. Every primary move is compared against independent
boolean-grid clearing/scoring and a same-seed/action mirror; JSON save/resume at
move four retains exact continuation. The 5000-move cap is a failure, never a
successful completion. No failed seed remains in these accepted runs.

Length min/median/p95/max 16/77/167/440; mean 86.0313 moves. Score distribution
45/418/949/2557; mean 466.9988. These are one simulated player's outcomes, not
human retention/difficulty claims. Simulation elapsed 188571ms; observed maximum
generation 12485us under concurrent cloud workload. Bounded generation still has
at most 32 RNG advances; no solver/allocations were added to drag movement.

Classic extended results match the approved baseline exactly: 260575 legacy
moves, 262968 Fair moves; Fair 91900 fresh trays, zero contract violations,
627 repairs, zero sampler fallbacks. Fair source, ScoreRules and the touch-input
owner were not modified. Legacy and Fair restore regressions both pass.

## Performance and limits

| Cloud metric | p95 | Maximum |
|---|---:|---:|
| Mode switch, includes four settling frames | 27.632ms | 29.241ms |
| Save, 1000 samples | 0.209ms | 0.453ms |
| Load, 1000 samples | 0.855ms | 7.477ms |
| Generator, 10000 checkerboard samples | 0.468ms | 2.958ms |

Mode switch meets Gate A <=100ms p95/250ms max; save/load meet <=25ms p95/100ms
max. No Daily/statistics benchmark applies at Gate B. Generator structural bounds
are retained; cloud wall-clock outliers do not establish Android frame-time.
Static memory: initial 33126209 bytes; samples after each 200 switches were
33373357, 33625849, 34122817, 34131361, 34131409. Increment 1005200 bytes,
last-window increase 48 bytes, below the proposed 20MiB/1MiB plateau criteria.
Static monitor is not total process RSS or a hardware memory acceptance result.

APK/AAB not rebuilt during this recovery. Existing Phase 2 builds are historical
and do not establish current Relax Android acceptance. DEVICE VALIDATION PENDING:
real touch/multitouch/Back/pause/resume/resize, debug install, process interruption,
low-end frame responsiveness and storage behavior require phone evidence. AdMob
runtime/Billing transactions are not claimed PASS. No hosted Phase 3 CI exists.

The exact changed-file manifest accompanies this report. UID metadata is kept;
Godot cache/import/translation output and build binaries are excluded. Limited
credential scans and per-file whitespace checks are required before review.
Owner review is required; no commit or push is authorized by this report.
