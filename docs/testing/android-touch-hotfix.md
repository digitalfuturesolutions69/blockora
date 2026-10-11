# Phase 1 Android touch hotfix

Baseline: `6ae791fdc1a84ee6a2c4d5cd82e93ab0914680a9` (branch `work`).

## Root cause and input ownership

The baseline disabled `input_devices/pointing/emulate_mouse_from_touch`.
Godot 4.6.3 `BaseButton::gui_input()` accepts masked mouse buttons and
`ui_accept`; it does not activate from `InputEventScreenTouch` directly.
The old integration suite emitted GUI signals directly, so it missed this defect.

Verified against the pinned engine source:
- [BaseButton](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/gui/base_button.cpp)
- [Input translation](https://github.com/godotengine/godot/blob/4.6.3-stable/core/input/input.cpp)
- [InputEvent device identifiers](https://github.com/godotengine/godot/blob/4.6.3-stable/core/input/input_event.h)

Enabling mouse emulation lets Godot's normal GUI routing activate Buttons.
Godot dispatches the synthesized mouse event before the original touch and marks
it with `InputEvent::DEVICE_ID_EMULATION`, device `-1`. PuzzleSurface ignores
that device for mouse buttons/motion, without marking those events handled, so
GUI controls still receive them. Gameplay owns the original touch index; real
mouse device events continue to work. Cancellation is honored for both paths.

GUI actions defer content replacement until dispatch completes. This avoids
removing controls while Godot is still delivering the paired original touch.
The bootstrap is a full-screen Control with ClassicApp as its child; it has no
input interception or overlay. Containers do not cover sibling button targets,
and the puzzle surface's STOP filter is confined to its board/tray region.
The confirmation dialog is the intended modal overlay. No UI redesign is needed.

## Regression coverage

All GUI interactions in `run_input_tests.gd` now use `Input.parse_input_event()`
with press/release positions, including embedded confirmation buttons. No
`button.pressed.emit()` bypass remains. Coordinates include viewport stretch
and embedded window offsets.

Checks cover touch Play Classic exactly once, Settings, sound/vibration and
persistence, Back, restart cancel/confirm, Play Again, desktop mouse buttons,
touch/mouse drag, one committed move, collision/outside/canceled releases,
unrelated fingers, interruption, resize, automatic engine mouse synthesis,
touch pointer ownership, ignored synthetic mouse motion/press, and stale paired
releases after the surface refresh. GUI actions are counted: zero on press,
exactly one after release. Moves are counted independently of visual state.

## Validation

- `bash tools/test.sh`: PASS. Foundation 7 cases/35 checks; gameplay 36 cases/
  6,623 assertions; input 14 cases/84 assertions; all zero failures.
- Same input suite on X11/OpenGL Mesa llvmpipe: 14 cases/84 assertions, zero
  failures. V-Sync is unavailable on this virtual display; audio uses Dummy.
- Smoke simulation: 100 completed sessions, 2,579 moves, 25,990 assertions,
  zero failures.
- `bash tools/test_extended.sh`: 10,000 completed sessions, 260,575 moves,
  2,357,854 assertions, zero failures.
- `bash tools/build_android.sh`: PASS; plugin compilation, debug APK export,
  test AAB export, and verifier exited successfully. Package/SDK/portrait,
  permission allowlist, debug APK signature, bundle validation and unsigned test
  AAB checks passed. Godot emitted a nonfatal ADB connection message during
  export; this does not establish installation or physical device validation.
- APK: 84,937,628 bytes; SHA-256
  `cc598de3c711db1ecc1ed18978211af446dfecdb1ccf39e09c03f3c41313090d`.
- AAB: 32,484,518 bytes; SHA-256
  `6b18b889a1603bd5f33572a1ce22b318f83c634257ca05359d47fd226cc2b5ed`.
- `git diff --check`: PASS. Limited credential/signing-file scanner: PASS for
  126 candidate files. Generated artifacts remain ignored, outside the commit.
- `adb devices -l`: no attached devices. **DEVICE VALIDATION PENDING**.

Package ID, target SDK 36, min SDK 26, Android exports, permissions, scoring,
Ads/Billing/backend and Fair Play behavior remain unchanged.

## Install and physical acceptance

The generated development artifacts are `builds/blockora-debug.apk` and
`builds/blockora-test.aab`; neither is a Play release.

Connect an Android device with USB debugging enabled, then run:

```bash
adb devices -l
adb install -r builds/blockora-debug.apk
adb shell am start -n com.digitalfuturesolutions.blockora/com.godot.game.GodotAppLauncher
```

An APK signed by a different debug key cannot replace the installed APK.
If Android reports `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, preserve any needed
local saves before uninstalling/reinstalling: uninstall deletes application data.
The AAB is a test bundle, not directly installable by `adb install`.

On the device verify one tap opens Classic once, Settings opens, each preference
changes once, Settings Back and Android Back work, one-finger dragging previews
correctly, release consumes exactly one tray slot and awards one move's score,
invalid/canceled placements preserve board/score, and a second finger cannot
steal the drag. Test background/resume and repeated gestures. Actual device
sound/vibration, safe area behavior, and OS input delivery remain pending;
desktop injected events are not physical Android acceptance. AdMob runtime and
Play Billing transactions have not been tested by this hotfix.
