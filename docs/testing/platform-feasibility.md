# Platform integration feasibility review

Inspection date: 2026-10-10. Candidate repositories were fetched read-only for source inspection; their scripts and binaries were not executed.

## Candidates and maintenance evidence

| Candidate | Reviewed source / release | Actual build requirements inspected | Decision |
|---|---|---|---|
| Poing Studios legacy `godot-admob-android` | HEAD `a8d30ce9c4a38b9565e8832c82d6a81e5251adbe`, commit 2026-03-17 | README directs users to monorepo; AGP 8.13.2, Kotlin 2.3.0, compile 36, min 24; AD_ID/network permissions | Legacy repo is not selected |
| [Poing monorepo](https://github.com/poingstudios/godot-admob-plugin) | HEAD `c75c79fc5438a8a599d792da5c71a8adbc3e1f8f`, 2026-09-30, v5.2.0-nightly tag; v5.1.0 stable tag exists | Default remote Godot 4.7.0; Next-Gen GMA `ads-mobile-sdk:1.5.0`; extensive optional mediation/UI dependencies; source compile SDK 35, min 24 | Maintained, but not built or imported; does not itself prove 4.6.3 compatibility |
| [Godot Billing integration](https://github.com/godot-sdk-integrations/godot-google-play-billing) | HEAD / v3.3.0 `e494f370ee591fa11823ad2749a070ed1149de99`, 2026-07-26 | Billing KTX 9.1.0, Godot 4.5.1 stable, AGP 8.13.2, Kotlin 2.2.21, compile 36, min 23 | Maintained/auditable; not built or imported |

Both candidate plugins use MIT licenses. README compatibility claims are treated only as claims; dependency files, manifest permissions, tags and commit dates were inspected. Candidate plugin compilation is NOT RUN; the separately compiled original bridge is the chosen feasibility integration.

## Chosen compile spike

Direct official artifacts: `com.google.android.gms:play-services-ads:25.5.0` (current classic Mobile Ads line) and `com.android.billingclient:billing:9.1.0`. Google Maven metadata on inspection lists these versions as latest releases, dated 2026-09-17 and 2026-06-18 respectively. Poing now uses the newer Next-Gen ads SDK; that alternative was not integrated or runtime-verified in this phase.

Sources: [Google Maven Ads metadata](https://dl.google.com/dl/android/maven2/com/google/android/gms/play-services-ads/maven-metadata.xml), [Billing metadata](https://dl.google.com/dl/android/maven2/com/android/billingclient/billing/maven-metadata.xml), [Godot Android plugin API](https://docs.godotengine.org/en/4.6/tutorials/plugins/android/android_plugin.html), [official test ad units](https://developers.google.com/admob/android/test-ads).

The original Java bridge compiles against the Godot 4.6.3 template's local AAR (compile-only, not a second bundled engine). It compiles Google rewarded-ad callbacks and Billing connect/query/restore/pending/acknowledgement APIs. No ads show path, reward callback, production ad ID or purchase launch exists. Native asynchronous statuses remain diagnostics rather than verified entitlements. A compile success does not demonstrate JNI runtime loading, ads delivery or a transaction.

Official test app ID: `ca-app-pub-3940256099942544~3347511713`. Rewarded test unit: `ca-app-pub-3940256099942544/5224354917`. These identifiers are public Google examples, not secrets. Bootstrap makes no explicit SDK calls. Ad measurement initialization is deferred by metadata, and opt-in test calls must remain behind a developer-only probe until consent/privacy implementation exists.

## Entitlement lifecycle reserved for later implementation

| State | Required future behavior | Current scaffold |
|---|---|---|
| Unavailable/disconnected | Start game; keep entitlement unknown/denied; reconnect safely | Starts with no-op; native diagnostic emitted |
| Pending | No permanent entitlement, wait for authoritative purchased state | Emits pending/no entitlement |
| Purchased/unacknowledged | Verify product/package/account and purchase legitimacy, then acknowledge within Play deadline | Observes correct product; private acknowledgement API compiles, orchestration not implemented |
| Acknowledged/verified | Grant locally cached, revalidated Remove Ads entitlement | No grant implemented |
| Restore | Query current INAPP purchases after successful connection; verify before grant | Query compiles; no fake permanent state |
| Refund/revoke/absence | Reconcile on resume/connect and remove stale entitlement; account for offline uncertainty | No entitlement persisted; revoke handling not implemented/tested |

Do not consume the non-consumable `remove_ads_lifetime`. No raw token is written to logs, analytics or domain state. No backend added. An owner-approved verification design is still required before enabling real purchase UI.

## Runtime blockers and owner actions

**BLOCKED — REAL DEVICE REQUIRED**: no Android device is attached. Provide an API 26+ reference Android device, install the debug APK, verify native singleton registration and startup offline, explicitly invoke Google test ad load, and record callback/log/device evidence. Test interrupted/failed ads and SDK behavior before reporting delivery success.

For a developer-controlled Android probe, get `Engine.get_singleton("BlockoraPlatform")`, connect `platform_status`, call `load_test_rewarded_ad()` for Google test ads, and call `connect_billing()`; wait for `billing/ready` before `query_remove_ads_product()` or `restore_purchases()`. These methods are not automatically triggered by bootstrap and provide no gameplay assistance.

**BLOCKED — PLAY CONSOLE TESTING REQUIRED**: owner must create/select the matching Play app, configure active non-consumable `remove_ads_lifetime`, approve a release/signing strategy separately, configure license testers and a Play-installed internal-test build, and enable tester access. This unsigned AAB cannot be uploaded. Purchase launch/verification/acknowledgement orchestration must first be implemented in the later approved monetization phase. Record pending, purchase, acknowledgement, restore, cancellation, refund and revoke cases on Play. No credentials should be posted in chat or committed.

## Dependency/security audit scope

| Dependency/tool | Pinned version | License / use |
|---|---|---|
| Godot | 4.6.3 | MIT; existing verified engine and templates |
| Google Mobile Ads | 25.5.0 | Android SDK license per Google Maven POM |
| Google Play Billing | 9.1.0 | Android SDK license per Google Maven POM |
| AndroidX artifacts | Exact resolved versions in native Gradle lockfile | Apache-2.0; review effective app dependency report too |
| AGP / Gradle | 8.10.1 / 8.11.1 | Apache-2.0; template build chain |
| Kotlin (template) | 2.1.21 | Apache-2.0 |
| Temurin JDK | 17.0.20.1+1 | GPL-2.0 with Classpath Exception |
| bundletool | 1.18.3 | Apache-2.0; build verification only |
| Android SDK/NDK/CMake | SDK36/NDK28.1/CMake3.10.2 | Android SDK terms and bundled open-source notices; build tools only |

Google Ads transitively brings UMP, AndroidX, Google transport and ads-services libraries; Billing 9.1 also declares Google transport/location libraries. No separate Firebase analytics SDK or project config is added. Permission removals avoid requesting location/advertising identifiers despite transitive libraries. WorkManager foreground service/permission are removed for this foreground-only load spike; SDK behavior under that restriction is not device-verified. WAKE_LOCK is retained for Google transport/WorkManager background jobs. The final manifest allowlist is an enforced test, not a claim that every SDK is privacy-safe. Consent, data-safety declaration, transitive SDK behavior and device validation remain production gates.

Audit covers pinned direct dependencies, native resolved dependency lock/report, source boundaries, official provenance/checksums for downloads, manifest permissions, and repository secret/signing exclusions. It is not a comprehensive CVE audit or production compliance approval. SDK-native diagnostics cannot be considered tested by headless no-op tests.
