# Blockora — Classic (Phase 1)

Android-first Fair Play Block Puzzle technical foundation for Digital Future Solutions.
Classic is an offline playable 8×8 block puzzle: drag three curated pieces onto the board, clear rows/columns simultaneously, build combos, and play until none of the remaining shapes fits. There is no timer or rotation. Home offers Play Classic, Resume, Settings, and disabled Relax/Daily Coming Soon controls. Pause supports confirmed Restart/Resume/Home; Game Over supports Play Again. Best score and sound/vibration preferences persist locally.

## Requirements

Godot **4.6.3**, JDK **17**, Android SDK platform **36**, build-tools **36.1.0**, Gradle **8.11.1**, Android Gradle Plugin **8.10.1**, and the matching Godot Android export templates. Android min SDK is **26** and application ID is provisionally `com.digitalfuturesolutions.blockora`. The published cloud machine also has NDK 28.1.13356709 and CMake 3.10.2; this phase uses prebuilt Godot libraries and does not rebuild the engine.

## Run and test in the published cloud environment

```bash
cd /workspace/blockora
source /workspace/toolchains/blockora-env.sh
bash tools/test.sh
bash tools/test_extended.sh # 10,000 complete deterministic sessions
godot --editor --path .
# Or run the playable game directly:
godot --path .
# For a headless startup smoke:
godot --headless --path . --quit-after 2
```

No server, account, or production credentials are required. Default external services remain no-op; gameplay never activates Ads/Billing SDKs. Native feasibility calls remain opt-in and grant neither rewards nor premium. Select the entire tray card and drag: the piece floats above the pointer, valid preview has check marks/white outlines, and invalid preview has crosses. A valid release commits once; invalid/canceled input leaves board/score/tray/RNG unchanged. Interruption cancels the drag and pauses. Resume restores the committed session. Replacing a resumable board requires confirmation; best survives.

Tests include import/parser checks, all Phase 0B cases, domain/controller tests, real Godot mouse/touch event injection, and 100-session smoke simulations. Extended testing runs 10,000 complete sessions against an independent 64-cell clearing oracle and seed/save replay. Script errors are rejected even if Godot exits zero. `tests/simulation/benchmark_board.gd` provides a reproducible cloud CPU benchmark. Tests use isolated temporary saves and no third-party framework.

## Android test exports

```bash
bash tools/build_android.sh
```

This prepares the matching Android template in ignored `android/build`, compiles the small native bridge into ignored `addons/blockora_platform/bin`, exports a debug APK and unsigned test AAB, then verifies identity, SDKs, portrait orientation, permission allowlist, SDK packaging, and signatures where applicable. The verifier uses checksum-pinned bundletool 1.18.3; cloud default path is `/workspace/toolchains/bundletool-1.18.3.jar`, or set `BUNDLETOOL_JAR` to that verified tool elsewhere.

Artifacts are ignored in `builds/`. APK uses a development key outside the repository. AAB is intentionally **unsigned**, unsuitable for Play. No release/publishing steps are added. SDK 36/ARM64 and the bridge are retained. The only new permission is `VIBRATE` for user-controlled local placement haptics; dependencies are unchanged.

`tools/install_ci_toolchain.sh` bootstraps verified tools in GitHub Actions and persists their paths using `GITHUB_ENV`/`GITHUB_PATH`; it is not a cloud reinstall instruction. The workflow does not sign production artifacts or publish anything. Hosted workflow execution requires an owner-approved push; no push is performed by this phase.

## Documentation

- [Core architecture and saves](docs/architecture/core-gameplay.md)
- [Classic rules](docs/gameplay/classic-rules.md)
- [Phase 1 verification](docs/testing/phase-1-verification.md)
- [ADR-004: state](docs/decisions/ADR-004-game-state.md)
- [ADR-005: generation](docs/decisions/ADR-005-piece-generation.md)
- [Foundation](docs/architecture/foundation.md)
- [Verification matrix and evidence](docs/testing/phase-0b-verification.md)
- [Dependency and integration review](docs/testing/platform-feasibility.md)
- [Godot decision](docs/decisions/ADR-001-godot-android.md)
- [Platform adapters](docs/decisions/ADR-002-platform-adapters.md)
- [Android build and signing](docs/decisions/ADR-003-android-build.md)

Phase 1 remains **PARTIAL / BLOCKED for Android device acceptance** until real touchscreen/lifecycle/safe-area/audio/haptics tests. Desktop/headless checks do not establish device performance. Fair Play Solver, board-aware/guaranteed-solvable trays, Undo, Daily/Relax gameplay, backend, and monetization are deferred. Implementation authorizes local commits only; no push or publishing.

Optional rendered desktop evidence requires an X11 display:

```bash
godot --display-server x11 --audio-driver Dummy --rendering-method gl_compatibility \
  --path . --script tests/integration/capture_screens.gd
```

Original UI captures are ignored under builds/screenshots. Dummy audio is not an audible sound test.

Phase 2 Fair Play local validation adds an immediate-fit generator, bounded board
analyzer, legacy save compatibility, and deterministic input/lifecycle fixtures.
See [policy](docs/gameplay/fair-play-policy.md) and
[Gate C recovery](docs/testing/phase-2-crash-recovery.md) and
[Phase 2 verification](docs/testing/phase-2-verification.md).
`tools/test.sh` includes Fair Play/input/lifecycle units and both simulation
smokes; `tools/test_extended.sh` runs 10,000 legacy sessions, 10,000 Fair Play
sessions with replay/save-resume, and 1,000 randomized legal-player sessions.
Optional cloud CPU benchmarks:

```bash
godot --headless --path . --script tests/simulation/benchmark_board.gd
godot --headless --path . --script tests/simulation/benchmark_fair_play.gd
```

## Relax Mode — Phase 3 Gate B

Relax uses the shared board with a ten-shape catalog and cells + 10×lines scoring.
See [rules](docs/gameplay/relax-mode.md) and [local validation](docs/testing/phase-3-gate-b-verification.md).
Run `bash tools/test_relax.sh` after loading the pinned toolchain; Classic regression
remains `bash tools/test.sh` and `bash tools/test_extended.sh`.
