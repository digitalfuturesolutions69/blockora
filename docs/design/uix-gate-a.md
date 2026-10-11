# Blockora — Gate UIX-A: audit and visual specification

Status: AUDIT AND SPECIFICATION ONLY. No UIX-B/C/E implementation is authorized by this document. Owner review is required before further UIX implementation. The separate previously authorized SFX work remains uncommitted.

## 1. Repository and scope

Repository: `digitalfuturesolutions69/blockora`, HTTPS origin; branch `work`; local and remote baseline `8d89b1a87de2af92ae8b0092f43f5ae64f2760a4`. Engine: Godot 4.6.3 stable, GL Compatibility renderer, Android portrait-first and offline-first.

The six existing tracked modifications and seven existing new files at the start of audio recovery are the explicitly approved SFX work. Recovery changes the new audio test only; existing production persistence and gameplay domain/fairness files remain unchanged. This document records proposals, not implemented appearance or device acceptance. Neither commit nor push is performed.

## 2. Existing architecture audit

| Source | Current responsibility and observed behavior |
| --- | --- |
| `project.godot` | 720×1280 reference viewport; `canvas_items` scaling; effective aspect `keep`; portrait orientation; mouse-from-touch emulation enabled |
| `export_presets.cfg` | Both Android presets use immersive mode, arm64, package `com.digitalfuturesolutions.blockora`, min SDK 26, target SDK 36 |
| `scenes/bootstrap/bootstrap.tscn`, `bootstrap.gd` | Full-rect anchored root Control creates services and the full-rect ClassicApp; offline adapters remain default |
| `scripts/presentation/classic_app.gd` | Builds shared Home/Classic/Relax/Settings/Pause/Game-over screens with MarginContainer → ScrollContainer → VBoxContainer, native buttons and confirmation dialog; mode switching delegates to controllers |
| `scripts/presentation/puzzle_surface.gd` | Immediate drawing of board/tray/previews; square board from `min(width−16,height−170)`; eight uniform cells per side; trays use three equal columns and a minimum height; single native pointer owns drag |
| Application/domain | Existing accepted-placement signal carries cleared rows/columns, combo and terminal status; deterministic board/RNG/fairness and scoring stay authoritative |
| Audio work | Reusable two-voice manager and cached original PCM cues; confirmation-only routing; optional persisted SFX volume with default 70%; headless event instrumentation |

Current board cells and tray pieces are flat rectangles, with a straight highlight on occupied board cells. The surface background has rounding but the individual block silhouettes do not. Occupied cells use mint while tray pieces use their render palette; a per-cell historical color is not persisted. The proposed style must not introduce gameplay-save changes to recover historical colors.

UI refresh currently cancels drag, removes the old content and defers node cleanup. Confirmed moves refresh on deferred signals to retain touchscreen lifecycle safety. `PuzzleSurface` listens to raw input, ignores mouse device −1 synthesized by touch, and transforms canvas coordinates through the inverse global canvas transform. Android safe margins are applied in ClassicApp only when running on Android, using `get_display_safe_area()` and screen size. This calculation needs real window/screen/stretch consistency checks before changing it.

## 3. Fullscreen root-cause investigation

A read-only diagnostic ran the current code in the cloud headless display with five actual Window sizes. Project settings resolve omitted `window/stretch/aspect` to **`keep`**, confirmed at runtime (`Window.content_scale_aspect = 1`). The app's effective canvas remains **720×1280 at all five sizes**. Its full-rect anchors fill that logical canvas, not the tall device window. Godot's final canvas transform centers that fixed aspect vertically.

| Window pixels | Effective canvas | Uniform scale | Vertical origin / unused pixels per edge |
| --- | --- | --- | --- |
| 720×1600 | 720×1280 | 1.0 | 160 |
| 1080×1920 | 720×1280 | 1.5 | 0 |
| 1080×2340 | 720×1280 | 1.5 | 210 |
| 1080×2400 | 720×1280 | 1.5 | 240 |
| 1440×3200 | 720×1280 | 2.0 | 320 |

The resulting letterboxing is reproduced in the engine's layout transforms; this is the strongest source-supported explanation for the owner report. It is not proof that every bar in a physical screenshot comes from this cause. The diagnostic preserves a square 656×656 logical board, uniform scaling, and a touch-coordinate round-trip error below 0.000016 logical units. The Pause button lies inside the fixed canvas at `(24,1156)` with size `(672,96)`.

**Android evidence unavailable:** headless `get_display_safe_area()` returns an empty rectangle and cannot reproduce cutouts, system bars, actual density, keyboard, window insets, manufacturer behavior or immersive-mode transitions. Effective Android viewport/safe-area telemetry and screenshots must verify the diagnosis on a device. Existing immersive export settings are enabled; no source evidence indicates that orientation is landscape or root anchors are missing.

Additional risks: the safe-inset conversion currently assumes app/screen dimensions describe the same coordinate system; long score labels and 96-unit buttons can consume height; the tray minimum height and fixed `height−170` board budget may require tighter constraints; Home allows scrolling, gameplay disables it. The new clear text consumes an extra row and must be budgeted in UIX-B. Display density must be verified separately from resolution to ensure a real 48 dp touch target.

**Proposed UIX-B correction after approval:** explicitly use `canvas_items` with aspect `expand`, keep the 720×1280 reference, and lay out from the actual expanded usable rectangle. At these portrait sizes the expected logical canvas becomes 720×1600, 720×1280, 720×1560, 720×1600, and 720×1600 respectively, subject to engine rounding/window insets. Keep native portrait and immersive settings. Draw the full background to the window while putting interactive content inside measured safe insets. Apply a single documented physical-window-to-canvas conversion, avoiding both double-inset and inset scaling through a letterboxed canvas.

Acceptance: background coverage reaches every intended usable-window edge; no aspect bars; board width equals height within one rendered pixel; Pause/tray/dialog remain inside the safe rectangle; all cells retain accurate touch selection. Exercise every mode/screen at all five resolutions, small 540×960 regression, rotated/interrupted window events, gesture/three-button navigation, cutouts and at least two Android density classes. Do not change current configuration during Gate A.

## 4. Shared theme tokens and block specification

Theme data is presentation-only. Proposed tokens: background, panel, board, empty cell, primary/secondary text, five piece colors, valid/invalid outline, focus outline, shadow opacity, corner ratios, spacing, typography and motion strengths. The default is Crystal Pop; mode, collision, shape definitions, RNG and board coordinates never depend on the selected theme. No theme seed or rendering color is saved in game sessions.

| Token | Crystal Pop | Soft Zen | Night Glow |
| --- | --- | --- | --- |
| Background | `#0B1224` deep navy | `#14292D` muted forest | `#070D1C` ink navy |
| Panel | `#15233B` | `#203B40` | `#131A30` |
| Board | `#111C31` | `#1C3438` | `#10182C` |
| Empty cell | `#26364F` | `#355056` | `#26324B` |
| Primary text | `#F3F7FF` | `#F4F6EC` | `#F3F7FF` |
| Secondary text | `#B2C3DB` | `#BECDC7` | `#B2C3DB` |
| Blue | `#68A9FF` | `#A6C8FF` | `#7A9DFF` |
| Cyan | `#56DCEB` | `#9FE5E0` | `#64CFFF` |
| Amber | `#FFC568` | `#F0D99F` | `#FFD36B` |
| Mint | `#75E2B4` | `#B6DDA8` | `#68E6BC` |
| Berry | `#F58DAF` | `#EAB9CF` | `#EB9BFF` |
| Valid / invalid | `#B6F6D6` / `#FFB0B7` | `#C4EBC1` / `#F3BBC2` | `#8FF1CB` / `#FFB0CC` |

Soft Zen uses pastel blocks on a subdued dark board; it is not required to be a white/light theme. Night Glow uses bright accents without bloom. Crystal Pop is the default theme.

Calculated solid-color occupied-block/board contrast ratios: Crystal Pop **7.05–10.89:1**, Soft Zen **7.72–9.47:1**, Night Glow **6.81–12.43:1**. These are token calculations, not measured final rendered contrast; gradients/shadows must preserve at least 3:1 edge distinction. All ordinary text must meet 4.5:1, large text 3:1 against its actual backing; test dimmed/disabled states separately.

Proposed native renderer: reusable cached `StyleBoxFlat`/lightweight polygon primitives with rounded radius **0.14 × cell side** (allowed 0.12–0.16), inset gap approximately 0.06 × cell side, one subtle lower shadow, and two or three flat highlight bands approximating gradient depth. A highlight stays at the top-left; bevel/shadow never changes the occupied-cell silhouette or interactive geometry. Avoid custom heavy shaders and texture imports. Cache color/style resources per theme/scale instead of allocating them every draw. Occupied board cells may use a stable coordinate-based palette or uniform mint because their original piece color is not in the approved save. Require owner review if exact historical colors would require schema changes.

Clear valid/invalid preview uses an outline plus check/cross mark and high-contrast text, rather than color alone. Preserve accurate shape geometry in every board, tray and ghost rendering path. Focused controls have a visible 2-unit outline, with physical width checked after scaling.

## 5. Screen and interaction proposal

| Screen | Proposed composition and objective constraints |
| --- | --- |
| Home | Compact original icon/wordmark, primary Play Classic, Relax, conditional resumes, Settings; disabled Daily remains clearly marked Coming Soon; scroll only when usable height cannot fit content |
| Classic | Mode and compact score/best/combo header; centered square board; a reserved feedback strip; three equal touch-friendly tray slots; Pause below; no gameplay scrolling |
| Relax | Same board/tray/Pause geometry; clear Relax label and gentle no-timer subtitle; no best/combination pressure or scoring change |
| Settings | SFX ON/OFF, 0–100% slider and percentage, Vibration, then proposed Theme selection and Reduce Motion; persistent selected states, Back; scrolling permitted for accessibility |
| Pause | Score/context, Resume, Restart, Home; feedback/audio stopped immediately; confirmation blocks only while explicitly opened |
| Restart dialog | Clear mode-specific replacement warning, Cancel/Restart, safe-area-clamped dimensions; cancel preserves session and drag stays canceled |
| Game over | Terminal status and score (Classic best only), Restart/Play Again and Home; one ending event from the accepted final move, no replay on re-opening |

Use one spacing rhythm (8 logical units), primary gutters 24, compact header 20–32 text, score 44–56 with measured fallback for long int64 values, buttons approximately 96 logical units but never below **48 dp** after density verification. Larger accessible fonts must reflow instead of obscuring score/controls. Board size derives from the smaller of available width and remaining height after header, safe margins, feedback strip, tray and Pause minimums. Reserve at least three equally sized tray targets with visible silhouettes and gaps; scale illustrations, not input-space axes, when space is tight. No new assets imitate another game's protected design.

## 6. Confirmed line-clear effects proposal

Subscribe to the existing accepted-placement event; retain its cleared row and column indices and derive a unique cell union at intersections. Audio's transaction identifier can also deduplicate visual requests. Capture only view data; never delay or change the confirmed game-state update, scoring, save or RNG for animation.

| Clear count | Effect and timing | Maximum particles |
| --- | --- | --- |
| 1 | Brief cell/line illumination (0–60 ms), fading/scaling fragments (60–200 ms) | 8 |
| 2 | Stronger illumination plus `DOUBLE CLEAR!`, total about 200 ms | 12 |
| 3+ | Controlled sparkle burst plus `AMAZING!`, total about 220 ms | 16 |

Overlay is noninteractive (`MOUSE_FILTER_IGNORE`), clipped to the board, and uses at most one active effect group; a rapid new transaction replaces the older effect instead of accumulating emitters. Pool simple CPU-drawn fragments or one bounded native emitter. No screen shake, full-screen flash or bloom. Clear text uses a reserved strip so layout cannot jump during drag.

Reduced Motion disables particles, displacement and scale; replace them with a static clear outline/text fading at most once over 120 ms. No effects on invalid placement, resume, restoring a save or rebuilding the UI. Pause/background, resize, theme switch, scene exit and restart cancel effects, disconnect callbacks and free/reset pooled nodes. Tests must check no orphan tweens/particles after 1,000 switches, and that effects cannot consume input or generate additional placement signals.

## 7. SFX design and licensing plan

The separately approved uncommitted audio system is reused, not reimplemented for UIX. Eight original cues are procedural mono PCM (115,540 bytes total) with source/composition provenance and CC0 output dedication in `docs/audio/gameplay-sfx.md`. Pop, soft invalid, three clear strengths, escalating combo, ending and reserved Daily victory are cached once and have two bounded voices with comfortable gain/headroom. Clear rows and columns are both counted. Daily victory has no current trigger.

Authoritative confirmation routes playback; preference writes, save loading and refresh never trigger it. Existing SFX defaults to ON at 70%; old preferences retain their sound state, with missing/invalid volume safely defaulted. Audio tests instrument playback requests and actual engine results. They do not verify audible polish, mixer timing, headphones/calls or Android latency. Physical listening is a release prerequisite. Future UIX-D should review/validate the existing work, not change fairness or game saves.

## 8. Appearance persistence and accessibility plan

For UIX-E, prefer a separate explicit `appearance_v1` record with schema 1, stable theme enum (`crystal_pop`, `soft_zen`, `night_glow`) and boolean `reduced_motion`; leave Classic/Relax sessions and the approved SFX preference schema untouched. Missing appearance uses Crystal Pop and normal motion; invalid keys/types/version are rejected safely with defined fallback and without rewriting valid game data. Specify unknown-future-version preservation before implementing the store.

Visual feedback must work with mute, color vision differences, reduced motion and enlarged text. Check/cross silhouettes supplement preview colors. Avoid harsh flashes, rapid flicker, unexpectedly loud effects, icon-only ambiguous actions and background music. Proposed theme selection uses labeled options and a preview, retaining Android Back behavior. Native button labels/focus order remain explicit; Android screen-reader behavior must be tested on a device rather than inferred from Godot Control metadata.

## 9. Performance targets and validation plan

These are proposed acceptance budgets for owner review, not existing Android performance claims. Use a nominated low-end Android device with documented SoC, RAM, Android version, density, refresh rate and export settings, plus cloud CPU/filesystem details for headless measurements.

| Metric | Proposed budget / method |
| --- | --- |
| UI creation including cached audio | p95 ≤150 ms on nominated device; report cold/warm separately, no additional synthesis after initialization |
| Layout recalculation | p95 ≤2 ms; measure resize/insets/theme/font changes across the five sizes |
| Board draw / visual overhead | p95 ≤2 ms for board draw; effect overhead ≤1 ms and ≤16 particles; measure rendered frames, not headless draw submissions |
| Frame time | p95 ≤16.7 ms at 60 Hz; p99 ≤33.3 ms during repeated clears; profile warm and cold paths separately |
| Audio request routing | p95 ≤1 ms CPU excluding pre-existing persistence; physical event-to-audible p95 target ≤60 ms via external loopback/high-speed recording |
| Memory | audio PCM <150 KB; UIX resource growth <8 MiB over baseline; last 200 of 1,000 mode/theme switches <1 MiB net growth |
| Cleanup | zero live orphan effects/tweens, duplicate cue/effect, script/parser errors or crashes |

Baseline and proposed gate validation: foundation, Classic unit/integration, Fair Play contract, Relax policy/malformed-save/persistence, native touch/multitouch/emulated mouse, lifecycle, deterministic replay and representative sessions. Final UIX-F should include 10,000 Relax, 10,000 Classic and 10,000 Fair sessions plus 1,000 randomized Fair sessions, reporting seeds, accepted moves, fairness violations, repairs/fallbacks and runner exit/error logs. Tests must assert real input and output, never bypass buttons with `pressed.emit()`.

Layout tests must record physical window, effective viewport, canvas transform, safe rectangle and density, not dimensions alone. Verify all 64 cells through transformed touch centers and edge boundaries at all five requested resolutions; test cutout/gesture inset fixtures plus real device insets. Test persistence across app/process restart; rapid animation replacement, mute/zero/live volume, reduced motion, theme switching during pause and no replay on restore. APK build, install and device acceptance occur in UIX-F after separate implementation approval.

## 10. Proposed future file-change manifest

These are candidate future files, not changes made during Gate A. Required `.gd.uid` metadata accompanies new scripts. Final gate-specific manifests must be reviewed before commit.

| Gate | Candidate files | Purpose |
| --- | --- | --- |
| UIX-B | `project.godot`, `scripts/presentation/classic_app.gd`, `scripts/presentation/puzzle_surface.gd`; new `scripts/presentation/usable_layout.gd`, `tests/integration/run_responsive_layout_tests.gd` | Expanded canvas, consistent safe-area mapping and square board/tray constraints |
| UIX-C | `puzzle_surface.gd`, `classic_app.gd`; new `scripts/presentation/block_renderer.gd`, `scripts/presentation/clear_feedback.gd`, `tests/integration/run_visual_feedback_tests.gd` | Cached block styles, bounded confirmation-only overlay effects and cleanup |
| UIX-D | Existing uncommitted `scripts/audio/gameplay_audio.gd`, `sfx_library.gd`, controller/app/surface, audio tests and documentation | Review and validate separately authorized SFX, no duplicate implementation |
| UIX-E | New `scripts/presentation/visual_theme.gd`, `scripts/infrastructure/appearance_store.gd`, `tests/unit/run_appearance_tests.gd`; app/renderer | Three token sets, versioned separate appearance settings, reduced motion |
| UIX-F | Test runner registration, dedicated performance/layout/cleanup tests, verification documents and ignored APK/AAB outputs | Complete regression and physical device validation |

No fairness/domain/scoring, Ads/Billing/backend, signing credentials or package-ID changes are proposed. Export presets need not change unless device measurements reveal a specific immersive-mode defect and the owner approves the correction.

## 11. Risks, dependencies and gate decisions

- Headless layout demonstrates fixed-aspect bars, but Android cutout/insets and actual usable viewport remain unverified. UIX-B must begin with device telemetry rather than treating screen size as its safe area.
- Additional clear text currently uses layout height. Reserve its space so a clear cannot shrink the board or shift touch mapping during a gesture.
- Current full-content refresh frees surfaces. Effects must live in a stable host or cleanly cancel on deferred rebuild; preserve the existing freed-node/touch hotfix protections.
- Original per-cell piece colors are absent from approved saves. Use a presentation-only fallback unless separately authorized to change persistence.
- Procedural SFX are digitally bounded and tested, but audible polish is a physical listening decision. Android audio-focus and low-end frame-time measurements remain pending.
- Repeated save loading on the same Relax store is stateful; restart tests must instantiate a reader/controller as production does. No persistence API redesign is part of UIX.
- Choose one actual low-end device and collect screenshots/telemetry before accepting performance targets. Neither cloud timing nor a successful build validates device performance.

**Gate UIX-A deliverable complete for owner review. STOP: request approval before UIX-B responsive layout or any further rendering, animations or theme implementation.**
