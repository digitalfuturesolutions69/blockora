# Phase 1 verification

Verdict: **FASE 1 PARTIAL / BLOCKED** for Android device acceptance. Implementation and local verification succeeded; no physical Android device is attached. No Phase 1 hosted run is claimed because pushing this phase is not authorized.

Verification date: 11 October 2026 (Asia/Jakarta). Repository digitalfuturesolutions69/blockora, branch work, approved starting HEAD `4a07ab31ca35855bf96026b55f3f92373e196b30`. Baseline origin/work matched and initial tree was clean. Phase 0B services/native bridge/dependency pins remain intact; no main change or publication. Final commit is identified by `git log -1`; [changed-files evidence](evidence/phase1/changed-files.txt) lists every delivered path.

## Implemented

- Eight-row-mask board, strict coordinate/collision/serialization checks, atomic placements, simultaneous row/column union clears.
- 24 validated connected normalized shapes and semantic render metadata; no player rotation.
- Deterministic configurable scoring, pre-event combo formula, reset/cap, signed-int64 saturation.
- Three-slot batch-consumption tray with seedable Park–Miller/rejection-sampling provider and exact RNG continuation.
- Explicit lifecycle/controller, correct all-remaining-shapes game-over test, independent best and versioned offline saves/preferences.
- Real Home, Classic, Pause, Settings, Game Over, confirmed restart, resume, Play Again, and disabled Coming Soon controls.
- Mouse/touch drag, pointer ghost, valid/check and invalid/cross previews, collision/outside/canceled/multitouch handling, interruption/resize cancellation, local sound and opt-in preference-controlled haptics.

Architecture/save format: [core-gameplay](../architecture/core-gameplay.md). Rules: [classic-rules](../gameplay/classic-rules.md). Decisions: ADR-004/005. No gameplay dependency on Ads/Billing, backend, or connectivity.

## Automated results

| Target | Cases/sessions | Assertions | Failures |
| --- | ---: | ---: | ---: |
| Phase 0B regression | 7 named cases | 35 | 0 |
| Domain/controller/storage | 36 named cases | 6,623 | 0 |
| Headless input/UI integration | 11 named cases | 39 | 0 |
| Deterministic smoke | 100 completed sessions; 2,579 moves | 25,990 | 0 |
| Extended independent-oracle simulation | 10,000 completed sessions; 260,575 moves | 2,357,854 | 0 |

Total for one final headless + extended verification: **54 named cases**, **2,390,541 assertions**, **0 failures**, **10,100 completed sessions / 263,154 moves**. The separate rendered desktop repetition adds 11 passing cases/39 assertions and is not double-counted above. Capture and benchmark are additional checks, not named unit cases.

`tools/test.sh` imports/registers class names, parser-checks every GDScript, runs the above smoke targets, and launches bootstrap. It fails on script/error logs even if Godot exits zero. `tools/test_extended.sh` is a separate full workload; hosted CI is configured to run it rather than silently reducing coverage.

Board tests include all 64 cells, bit/coordinate boundaries, all 24 shapes over 100 origins, collisions/atomic invalid placements, corrupt serialization, full row/column, 15-cell cross, 28-cell four-line union, and legal search. Shape tests cover coordinates/duplicates/connectivity/normalization/IDs/bounds/serialization and snapshot independence. Score tests cover no/one/multiple clears, literal pre-event combo bonus on non-clears, progression/reset/cap/configuration/overflow. Session tests cover consumption/refill/reuse/provider rollback, terminal all-shape logic, exact save/RNG restore, malformed saves, inactive moves, restart/best/settings, disk errors, and bounded record reads.

Simulation uses fixed seeds 0–9999 and a deterministic first-legal-slot/y/x policy, continuing until actual game over with a 5,000-move safety failure bound. Every move compares simultaneous clearing to an independent boolean 64-cell grid, checks illegal-move immutability, score formula/monotonicity, dimensions, valid tray references, and termination. First 100 seeds mirror every action and test save/resume replay. Longest extended session: 106 moves. This is an invariant workload, not a Fair Play solvability study or arbitrary-human-strategy coverage.

Extended workload took **24,347 ms** on this cloud CPU, including oracle/assertions. Board benchmark: 200,000 legal/collision probes in **145,686 µs**; 10,000 deserialize+cross-clears in **88,135 µs**. These are descriptive single-run measurements, not Android FPS, latency thresholds, or comparative bitboard speed claims.

Input integration injects actual InputEventMouseButton/Motion/ScreenTouch/ScreenDrag through Godot input dispatch. It verifies selection/preview, no drag save, commits, collisions, outside/canceled release, unrelated fingers, interruption/stale release, restart confirm/decline, resized layout/cancel, settings persistence, Game Over/Play Again. Desktop repetition uses X11/Mesa llvmpipe; audio is Dummy. No human hardware touch/audio/haptics test is inferred.

## Android and security

Debug APK and unsigned test AAB export successfully using the existing build pipeline. Final artifact sizes/hashes and manifest checks are in [Android build evidence](evidence/phase1/android-build.txt) and [effective manifest](evidence/phase1/android-manifest.xml). APK development signature verifies; AAB validates with checksum-pinned bundletool. Package is com.digitalfuturesolutions.blockora, version 0.1.0-phase1, min SDK 26/target SDK 36, portrait, ARM64. The packaged Godot v2 bridge, Ads and Billing classes are verified; native module/dependency locks are unchanged.

The only permission addition is **android.permission.VIBRATE**, needed for the requested local haptic preference/feedback. Retained permissions: INTERNET, ACCESS_NETWORK_STATE, WAKE_LOCK, Billing, own signature-level AndroidX receiver permission. APK/AAB allowlist rejects other permissions and requires VIBRATE. No advertising ID/location/ad-services/foreground-service permissions are added.

Limited-pattern secret scan and a file-content/extension audit find no credential/signing-key/generated-binary candidates in delivered files. Generated APK/AAB/AAR/keystore/cache/screenshots remain ignored. Export filters and capture .gdignore prevent Godot from importing/packaging generated screenshots; the APK/AAB ZIP verifier rejects build/test/documentation evidence resources. This is not an exhaustive secret/CVE certification. Dependency changes: **none**. Production Ads/Billing identifiers, signing credentials, and publishing configuration are unchanged. Workflow actions remain commit-pinned/read-only; actionlint and shell syntax checks pass. Phase 1 hosted result is **NOT RUN**; the prior Phase 0B hosted PASS is historical evidence, not Phase 1 CI proof.

## Evidence and reproducibility

See evidence/phase1 for headless-tests, simulations, desktop-input, render, benchmark, android-build, android-manifest, devices, security, and changed-files. Reproduce with the README commands. Original rendered captures under ignored builds/screenshots include Home/resume, board, valid/invalid previews, committed move, Pause, Settings, Game Over, and narrow portrait. No competitor artwork or new third-party asset/dependency is used.

## Remaining acceptance and limitations

1. **BLOCKED:** no attached Android device. Verify physical touchscreen/multitouch, interruption/background/resume, system Back/confirmation, navigation/cutout safe areas, density/font/target sizes, audio and haptics toggles, offline cold launch/resume, and low-end/API 26 hardware behavior. APK compilation is not a touch-runtime PASS.
2. **NOT RUN:** Phase 1 hosted workflow awaits an explicitly owner-approved push. All equivalent local targets pass; no push is performed.
3. Fair Play Solver, guaranteed-solvable/board-aware trays, weighting/difficulty, Undo, Daily/Relax gameplay, backend, and Phase 2 are deferred.
4. AdMob runtime and Play Billing transactions remain **UNVERIFIED**, requiring real device/Play setup and later transaction implementation. No fake rewards/entitlements or transaction PASS.
5. Local single-writer temp/rename persistence has no concurrent-writer, backups/migration, cross-file atomicity, or power-loss durability guarantee. It rejects malformed/unsupported saves and retains independent best. Cloud CPU/rendering measurements do not certify Android performance.

No known critical domain/controller defect remains in the tested scope. Full device acceptance remains blocked rather than declared complete.
