# ADR-001: Godot 4.6.3 for the Android foundation

Status: accepted for the approved Phase 0B baseline.

The approved PRD specifies Godot 4.x with GDScript. The published environment supplies Godot 4.6.3 and matching checksum-verified Android templates; pin this exact engine and template version rather than changing engine during feasibility work.

Use the compatibility renderer for the minimal portrait bootstrap and headless validation. The project has no gameplay or backend. Native Android services remain isolated from future domain logic, preserving an iOS adaptation path without changing the game engine decision.

The official template uses AGP 8.6.1, Gradle 8.11.1, Kotlin 2.1.21, compile/target SDK 36 and build-tools 36.1.0. The published docs initially listed build-tools 35/36.0; actual template settings take precedence for this repository's Android build. Template `ndkVersion` is 29.0.14206865, but Phase 0B packages precompiled native libraries and requires no NDK compilation. Do not claim an engine source build with the available NDK 28.1.

A source-template update requires revalidation, not silent substitution. Runtime performance and Android device compatibility are not inferred from headless compilation.

The initial build emitted a compile SDK support warning: template AGP 8.6.1 is tested only through API 35. Phase 0B pins AGP 8.10.1 in the native module and applies the same override to the generated Godot config (keeping Gradle 8.11.1), then repeats the real exports. No unsupported-SDK suppression is used. The template itself remains the verified Godot 4.6.3 artifact.
