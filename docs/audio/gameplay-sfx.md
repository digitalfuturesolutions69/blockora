# Gameplay sound effects

## Assets and provenance

All eight cues are original procedural compositions in `scripts/audio/sfx_library.gd`, created for Blockora during this implementation. No downloaded recordings, samples, third-party music, network services, or external audio dependencies are used. The synthesized waveforms/compositions are offered under CC0 1.0 (https://creativecommons.org/publicdomain/zero/1.0/); this dedication applies to the audio outputs only, not a relicensing of the repository source code.

| Cue | Character | Duration |
| --- | --- | --- |
| piece_placed | Short rounded tonal pop | 120 ms |
| line_clear_1 | Filtered whoosh, two bright sparkle notes | 280 ms |
| line_clear_2 | Rising three-note double-clear | 380 ms |
| line_clear_3_plus | Four-note ascending celebration | 520 ms |
| combo | Two-note accent; pitch rises for combos 2–5 | 180 ms |
| invalid_placement | Soft low tonal tap | 90 ms |
| game_over | Short descending ending melody | 550 ms |
| daily_completed | Ascending victory chime, reserved and unconnected | 500 ms |

Daily Challenge is not implemented or enabled. Its cue is cached but has no gameplay trigger. There is no background music.

All cues are generated once when the app's audio manager is created, cached as mono 22,050 Hz 16-bit `AudioStreamWAV` resources, and played with Godot `AudioStreamPlayer`. Total PCM is 115,540 bytes. No synthesis, file reads, or resource loads occur in the placement handler. Smooth envelopes give silent boundaries; sample magnitude is capped at 0.45 and playback has a further −9 dB gain ceiling. Two concurrent mono voices therefore retain substantial digital headroom even at 100% volume. Comfortable audible quality, distortion and latency still require device listening.

## Transaction routing and lifecycle

Both existing controllers emit `move_completed` only after accepted placement. Presentation routes its actual `cleared_rows.size() + cleared_columns.size()` to a reusable `GameplayAudio` manager. Clear cues replace the ordinary placement pop: exactly one primary cue per transaction. A Classic combo greater than one adds one musical accent. A terminal placement adds the ending melody instead of a combo accent. Relax has no combo bonuses and does not create combos.

The source session instance and confirmed score identify the transaction; the most recent 32 keys are remembered even when muted/backgrounded. A duplicate confirmation cannot replay it. Neither refresh/animation nor restore/resume invokes playback. The two players each have polyphony one; a new accepted placement stops both older cues and replaces them, rather than queueing a backlog. Extremely rapid input may shorten earlier cues deliberately. Invalid in-control drops emit a separate presentation event; canceled gestures and secondary pointers remain silent. Invalid drops never trigger a clear or change game state.

Pausing, returning Home, muting, setting volume to zero, backgrounding or losing application focus immediately stops existing playback. Backgrounded or paused requests are rejected. Foregrounding does not replay anything or resume paused gameplay automatically. Godot's normal Android audio backend handles the device output route; no audio-focus override is introduced. Interruptions, calls, headphones, and Android volume behavior require physical validation.

Visual board clearing, score, combo, invalid preview and game-over UI remain available independently of sound. A text cue also displays the confirmed clear count/combo.

## Preferences

Existing Sound ON/OFF and Vibration settings are retained. A touchscreen-compatible SFX Volume slider provides 0–100% with default 70%. The optional `sound_volume` field extends `preferences_v1` with its existing schema version; old preferences keep their sound/mute state and receive 70%. Finite integral numeric values in range are accepted (including legitimate JSON numeric decoding); invalid values default safely. Classic and Relax game-save schemas, scoring, placement rules, fairness, and package/SDK configuration are unchanged. The slider does not rebuild itself during its input gesture.

## Automated verification

`source /workspace/toolchains/blockora-env.sh` activates the prepared cloud toolchain. Run `bash tools/test.sh` for parser checks, foundation/Classic/Fair Play/touchscreen/lifecycle regressions and the added audio integration suite. `bash tools/test_relax.sh` covers dedicated Relax regression and 10,000 deterministic sessions. The audio suite instruments actual playback requests without claiming that a headless test verified audible quality. It covers real engine single/double/multi/cross clears in both modes, real Classic combo and game-over, duplicate signals, invalid touch drops, multitouch, two-voice limits, volume, mute, lifecycle, old preferences, actual JSON preferences restart, and save isolation. A short test teardown wait allows the audio server to release stopped playback resources.

## Physical Android acceptance — PENDING

Build via `bash tools/build_android.sh`; output `builds/blockora-debug.apk` (and unsigned test AAB). Install with `adb install -r builds/blockora-debug.apk`. Build outputs and debug signing material remain ignored.

On a physical Android device, test both Classic and Relax:

1. Listen to ordinary placement, one/two/three-plus line clears and simultaneous row/column clear. Confirm one primary cue per accepted transaction and synchronization with visual clearing.
2. Verify consecutive Classic clears escalate combo pitch, and game over plays one brief ending. Invalid drops give only a soft cue; canceled/multitouch input cannot duplicate it.
3. Exercise fast placements and clears; check for crackle, clipping, excessively loud output, lag, and cutoffs that feel uncomfortable.
4. Toggle mute and set volume to 0, 25, 70, and 100%; compare with Android media volume. Restart the app and confirm preferences persist without altering either mode's save.
5. Pause, background, lock/unlock, switch apps, interrupt with a call, and change speaker/headphone route. Confirm immediate silence while backgrounded and no delayed/replayed effects on return.
6. Confirm play remains understandable with sound disabled, including clear count, combo and game-over feedback. Verify Settings/slider at common Android resolutions.

No physical device or listening evidence is supplied by cloud/headless validation. DEVICE VALIDATION PENDING.
