# Relax Mode — Gate B

Approved policy: relax_small_v1; catalog relax_catalog_v1; score relax_score_v1.
The 8×8 board, legal placement, and simultaneous row/column clearing are shared
with ClassicSession. Classic scoring, catalog and immediate_fit_v1 are unchanged.

The frozen catalog order is single, domino_h, domino_v, line3_h, line3_v,
square2, corner_ne, corner_nw, corner_se, corner_sw. Coordinates match the
existing catalog_v1 definitions. Three slots are drawn with replacement using
Park–Miller and the existing bounded immediate-fit generator on this subset.
Only a fully consumed tray refills, after placement and clears. If a fresh tray
has no move but some catalog shape fits, slot zero is repaired once; otherwise
no retry occurs. Remaining slots can legitimately block. This is not endless
survival or a guarantee that all three pieces are playable sequentially.

Score increment is placed cells + 10 × cleared lines, counting rows and columns
separately; no combo or multiline bonus. No countdown, timer, undo, reshuffle,
continue, leaderboard, ads or purchase. No valid move in any remaining slot
ends the session. Restart after game over creates a new seed; replacing active
progress requires confirmation in Pause. Home and Android Back preserve the
session; Resume restores exact board/tray/score/RNG. Settings feedback remains
shared; Relax does not display best-score pressure.

Saves are isolated in relax_session_v1_a/b under user://foundation. Envelopes
contain revision and SHA-256 of a JSON payload; payload includes mode/catalog/
score versions and the full session. Highest valid revision wins; a damaged
latest slot can recover the previous snapshot with a warning. Unknown schema
or rules are preserved read-only. No Classic migration or retention system is
implemented. Classic session/best/preference keys are never written by Relax.
A move's candidate save must succeed before replacing live state or emitting
feedback. Pause/home also checkpoint already committed progress.

Dictionary restore requires integer schema version 1 and validates required
field types before comparisons. JSON restore checks JSON.parse return code,
rejects malformed/non-object data, validates integer schema tokens and only
then normalizes schema numbers decoded by Godot as floats. Score stays a decimal
string; finite integral board/RNG numbers preserve legitimate JSON decoding.
Checksum detects accidental corruption, not tampering. Temporary writes and
rename protect normal process interruption; power-loss durability and real
Android filesystem behavior still require device testing.

Run bash tools/test.sh, bash tools/test_extended.sh, and bash tools/test_relax.sh
with the pinned toolchain. The dedicated Relax runner includes unit, injected
GUI/touch/lifecycle, 10000 deterministic sessions, benchmarks and a subprocess
SIGKILL test during an injected partial temporary write. DEVICE VALIDATION PENDING.
