# ADR-006: bounded immediate-fit generation and versioned generator policy

Status: local Phase 2 implementation, pending owner review; no commit/push.

Retain classic_v1 board, 24 catalog IDs, scoring and three-slot consumption.
Use the existing Park–Miller sequence but bound sample rejection to eight
advances. Draw three candidates once. Repair only entirely unusable fresh trays
by replacing slot zero with one uniformly selected fitting shape. There are no
retry loops, sequential-solvability selection or monetization inputs.

The post-placement/post-clear staged board must be passed to generation; the
live board is committed only after validating the replacement tray. Tests
observe this boundary through an injected recording provider. Legacy providers
ignore the board-aware hook and keep their previous sequence.

Serialize algorithm/state plus policy immediate_fit_v1, keeping session schema
and scoring rules unchanged. Restore legacy saves without policy to the
original SeededPieceProvider; reject unknown policies. Restart creates a new
fair session; resume never repairs/replaces its persisted tray. Old APKs are
not promised to preserve the new policy on downgrade.

BoardAnalyzer uses live validation/clear rules on cloned masks. Optional search
permutes slot order and placement origins, applies clears at each depth, and
caps at 256 simulated placements. Found includes a replayable witness;
impossible requires exhaustive search, whereas budget_exhausted means unknown.
The analyzer is not used on drag, and no solver is run in tray generation.

Trade-off: repairing dead draws changes conditional shape/slot distribution
and can lengthen sessions. The guarantee concerns one immediate legal move,
not three sequential moves or endless play. Difficulty stays fixed by catalog
and policy. Measurements use reproducible first-legal and randomized players,
not inferred human skill. Cloud timings cannot prove low-end Android FPS.

See [policy](../gameplay/fair-play-policy.md),
[recovery](../testing/phase-2-crash-recovery.md), and final verification evidence.
