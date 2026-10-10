# Blockora — Phase 0B

Android-first Fair Play Block Puzzle technical foundation for Digital Future Solutions.
This repository contains bootstrap and platform feasibility scaffolds only. Gameplay, solver, Daily Challenge, premium UI, backend, and production publishing are not implemented.

## Requirements

Godot **4.6.3**, JDK **17**, Android SDK platform **36**, build-tools **36.1.0**, Gradle **8.11.1**, Android Gradle Plugin **8.10.1**, and the matching Godot Android export templates. Android min SDK is **26** and application ID is provisionally `com.digitalfuturesolutions.blockora`. The published cloud machine also has NDK 28.1.13356709 and CMake 3.10.2; this phase uses prebuilt Godot libraries and does not rebuild the engine.

## Run and test in the published cloud environment

```bash
cd /workspace/blockora
source /workspace/toolchains/blockora-env.sh
bash tools/test.sh
godot --editor --path .
# For a headless bootstrap smoke instead of opening the editor:
godot --headless --path . --quit-after 2
```

No server, account, production ad identifier, or billing credentials are required to start the project. Bootstrap always selects no-op external services. Native test SDK calls are explicit opt-in; ads never grant rewards and billing never creates a premium entitlement.

## Android test exports

```bash
bash tools/build_android.sh
```

This prepares the matching Android template in ignored `android/build`, compiles the small native bridge into ignored `addons/blockora_platform/bin`, exports a debug APK and unsigned test AAB, then verifies identity, SDKs, portrait orientation, permission allowlist, SDK packaging, and signatures where applicable. The verifier uses checksum-pinned bundletool 1.18.3; cloud default path is `/workspace/toolchains/bundletool-1.18.3.jar`, or set `BUNDLETOOL_JAR` to that verified tool elsewhere.

Artifacts are ignored in `builds/`. APK uses Godot's development key outside the repository. The AAB is intentionally **unsigned**, not suitable for a Play upload. Release exports are unsupported in Phase 0B; `--export-release` is deliberately not provided by the build scripts.

`tools/install_ci_toolchain.sh` bootstraps verified tools in GitHub Actions and persists their paths using `GITHUB_ENV`/`GITHUB_PATH`; it is not a cloud reinstall instruction. The workflow does not sign production artifacts or publish anything. Hosted workflow execution requires an owner-approved push; no push is performed by this phase.

## Documentation

- [Architecture](docs/architecture/foundation.md)
- [Verification matrix and evidence](docs/testing/phase-0b-verification.md)
- [Dependency and integration review](docs/testing/platform-feasibility.md)
- [Godot decision](docs/decisions/ADR-001-godot-android.md)
- [Platform adapters](docs/decisions/ADR-002-platform-adapters.md)
- [Android build and signing](docs/decisions/ADR-003-android-build.md)

Phase 1 requires Product Owner approval after reviewing Phase 0B results.
