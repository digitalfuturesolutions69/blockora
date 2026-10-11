# Gate C recovery: deterministic overlap fixture and freed Control crash

Approved HEAD remains c858e16d673750f474e9814f3578785c2022233c on work.
Initial 5 modified + 9 untracked files are listed in
[evidence](evidence/phase2/initial-changes.txt); exact files and patch were
preserved under /tmp/blockora-gate-c-recovery before any edits. No reset,
clean, checkout, commit or push was performed. Baseline comparison uses a
`git archive` extraction outside the checkout, not a worktree.

## Both input assertion failures

`new_game(42)` during PLAYING returns false without changing state, tray or RNG.
The old fixture ignored that result after tapping Play Classic, leaving its
wall-clock-selected seed in use. Same origin does not imply occupied-cell
overlap: shapes are normalized by bounds, not required to occupy (0,0).

A deterministic reproduction from allowed HOME with seed 222 gives
single/t_up/s4, RNG state 1073713583. Placing single at (0,0) produces masks
[1,0,0,0,0,0,0,0], score 1. t_up has cells (1,0), (0,1), (1,1), (2,1), so
origin (0,0) is LEGAL. Pointer (163.2,444.8) yields a valid preview. Releasing
correctly produces [3,7,0,0,0,0,0,0], score 5, tray ['', '', 's4']. Thus both
assertions were based on a false overlap assumption, not ignored collision
rules. Captured before/after state and pointer are in the reproduction logs.

Recovery asserts active new_game rejection and snapshot atomicity, pauses
through the existing API, then asserts seed 42 is accepted. Known fixture:
empty board, score 0, corner_se/line5_h/domino_v, RNG state 1054476435.
After corner_se at (0,0): masks [2,3,0,0,0,0,0,0], score 3. The line5_h
preview at origin (0,0) is invalid because it intersects occupied (1,0).
Pointer (245.2,362.8); release preserves the complete snapshot, including RNG,
board, score and tray. Two recovery runs yielded identical evidence. Original
invalid-preview, invalid-state and drag-return assertions remain intact.

## Native crash (investigated separately)

The valid placement that the old test called invalid emits controller.changed.
Deferred ClassicApp refresh removes and queue_frees its previous PuzzleSurface.
After two frames, the fixture's local typed surface is freed. Continuing after
failed assertions calls `surface.is_dragging()` on that freed script instance.

Controlled seed-222 reproduction crashes on both Phase 2 and the approved Phase
1 archive: process return codes -6 (Godot handles SIGSEGV then aborts) and -11
(SIGSEGV), respectively. Godot's native/GDScript backtrace points to the freed
is_dragging call. A minimal reproduction with no Fair Play, controller, GUI
input or signals is in minimal-freed-surface.txt: add a typed PuzzleSurface,
queue_free, wait two frames, call is_dragging. Without --debug, both baseline
and Phase 2 exit -11. With --debug, Godot reports 'previously freed' at that
exact call. Debugger runs return 0 but contain SCRIPT ERROR; they are NOT passes.
No gdb is installed; the built-in Godot debugger and native crash handler
provided the diagnostic stack. Package-index access for gdb was unavailable;
no network policy or system package configuration was changed.

Separate foundation, Classic and Fair Play unit groups exited 0 without crash.
Four deliberate native crashes were captured during this investigation (two
full reproductions, two minimal cases), in addition to the original Gate C
failure. This is a Godot 4.6.3 stale-reference hazard exposed by the fixture.
The engine itself was not patched; invalid-object method calls must be avoided.

The fixture now checks instance validity before invoking a potentially stale
surface and fails/returns immediately if unexpectedly destroyed. It never
reacquires a surface to hide the failed invalid-placement assertion. A new
lifecycle regression verifies deferred refresh frees the old surface, consumers
use the current surface after legal commits, seed-222 legal behavior is
preserved, and queued callbacks/signal receivers disconnect safely on teardown.

## Additional Phase 2 correction

Local refill integration initially passed the pre-move board to the provider.
It now passes the staged post-placement/post-clear candidate board before the
atomic commit. Recording-provider regression fills a row on the ninth legal
single placement (also the last tray piece) and asserts the provider receives
[0,2,0,0,0,0,0,0], not [127,2,0,0,0,0,0,0]. No state-transition, scoring,
input-emulation, Android, Ads, Billing or production credential rule is relaxed.

Final Gate C/D evidence and device limitations are recorded separately in the
Phase 2 verification report. Diagnostic crashes above must not be confused with
post-recovery validation results.
