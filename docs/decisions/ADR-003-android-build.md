# ADR-003: Android debug APK and unsigned test AAB

Status: accepted for Phase 0B, not a release-signing decision.

Application ID: provisional `com.digitalfuturesolutions.blockora`. Compile/target API 36, minimum API 26, ARM64, portrait. Minimum SDK compatibility is checked by Gradle manifest merging and final artifact verification; actual API 26 device behavior is still blocked on a device.

Use the Godot 4.6.3 Android template with AGP 8.10.1, Gradle 8.11.1 and JDK 17. Build-tools 36.1.0 matches the template. The verified template ships AGP 8.6.1; `prepare_android.sh` applies an explicit 8.10.1 override to the generated config to support API 36 without suppressing compatibility warnings. A wrapper distribution SHA-256 is written to the generated template; source artifacts have pinned checksums. Native bridge dependencies are pinned and its Gradle resolved configurations are locked.

`prepare_android.sh` only extracts into ignored build output, rejects unversioned existing builds, and refuses mismatched template versions. It does not overwrite application source. `build_platform.sh` compiles the bridge; `build_android.sh` exports and verifies two presets. CI uses the same commands after a verified toolchain bootstrap.

Debug APK signing uses a development keystore outside Git. Test AAB signing is explicitly disabled. No production keystore, signing password, release pipeline, or publishing step exists. CI checkout/upload actions are pinned to commits; job permissions are contents read-only. A hosted run is not claimed until it actually executes after an approved push.

Manifest permissions are restricted to network state, Internet, Billing, WAKE_LOCK for Google SDK transport/WorkManager jobs, and the app's own signature-level AndroidX receiver permission when generated. Foreground service permission and WorkManager foreground service are removed because this spike does not request foreground work; this restricted SDK configuration still requires runtime device validation. Advertising ID, location and ad-services permissions are removed in the bridge manifest. Merged manifests and final exports must obey the allowlist. This is not a production privacy/compliance certification.
