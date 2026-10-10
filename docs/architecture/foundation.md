# Foundation architecture

`scenes/bootstrap` hosts the minimal startup screen and composes services without initializing advertising or billing. `scripts/domain` is intentionally empty: no gameplay, scoring, generator, or premium-sensitive difficulty code exists.

`platform/interfaces` defines Advertising, Billing, Analytics, Crash Reporting, and Local Storage contracts. No-op implementations return unavailable/false, never a fake ad reward or permanent entitlement. `platform_services.gd` owns composition: default bootstrap uses no-ops, while an explicit Android feasibility selection can use the native bridge only when its singleton exists.

`infrastructure/json_local_storage.gd` writes a same-directory temporary JSON file, flushes/closes it, and renames it over the committed record. Keys must be identifiers to prevent traversal. Missing/corrupt records return structured errors. This is a storage smoke foundation, not the future versioned gameplay save/migration/backup implementation; concurrent writers and power-loss durability are not guaranteed in this phase.

`platform/android` wraps the small native bridge. No monetization object, token, analytics identifier, or SDK type enters domain code. No external SDK failure can grant entitlement. Native events contain only service/status codes; purchase tokens stay in native memory and are cleared on disconnect/destruction and refreshed queries.

`android/plugins/blockora-platform` contains original, reviewed Java source using Godot v2 plugin metadata and pinned official Google dependencies. `addons/blockora_platform` registers the Android export plugin; it does not make requests on editor or bootstrap startup. Native test ads load only after an explicit `load_test_rewarded_ad()` call, use Google's rewarded test unit, and have no show/reward path.

Billing scaffolding compiles connection, product query, restoration, pending purchase observation, and a private acknowledgement helper. Purchase launch, verification, acknowledgement orchestration, and premium grant remain unimplemented. Refund/revocation is not claimed working; authoritative state refresh and lifecycle tests are prerequisites to Phase 5. No backend is introduced.

Analytics and crash diagnostics remain no-op; no vendor analytics/crash service is selected. Google SDKs have their own transitive diagnostics/transport components; application-level no-op analytics does not imply zero SDK network traffic after explicit SDK activation. Consent/privacy work and device observation are required before production activation.

Generated Android builds/AARs, caches, credentials, keystores and artifacts are ignored. Build tools and verification evidence are separate from product flow. Each cloud task already has isolation; use the existing checkout rather than making worktrees.
