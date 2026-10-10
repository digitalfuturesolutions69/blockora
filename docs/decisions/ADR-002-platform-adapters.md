# ADR-002: Isolate platform SDKs behind fail-closed services

Status: accepted for Phase 0B; production integrations remain gated.

Advertising, Billing, Analytics, Crash Reporting, and Local Storage use separate service interfaces. Bootstrap depends on contracts composed by `platform_services.gd`, not native SDK classes. Default external implementations are no-op. Missing services return unavailable and never grant premium or ad rewards.

Use an original small Java bridge with official Google Mobile Ads 25.5.0 and Google Play Billing 9.1.0 for compile feasibility. Reviewed community integrations are documented in the feasibility report; neither their binaries nor their code are imported. This avoids pulling unrelated mediation/UI dependencies into the foundation and compiles against the exact local Godot library.

Only Google test ads are configured. SDK requests require explicit opt-in. Billing reports diagnostics and purchased/pending observations, but no callback enables entitlement. A private acknowledgement API scaffold is compile-checked and never invoked without a future verification workflow. Purchase UI, verification and refund/revoke handling require later implementation and Play testing.

There is no monetization dependency in `scripts/domain`; generator, solver and difficulty logic will remain unable to read ads/billing data. No backend or fake permanent purchase state is added.
