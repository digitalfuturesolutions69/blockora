# Fair Play — immediate_fit_v1

Gate A specification, recorded before implementation. Baseline:
`c858e16d673750f474e9814f3578785c2022233c`, Classic work branch.

## Audit and measured baseline

Reuse PuzzleBoard's eight byte masks, GamePiece/PieceLibrary's stable 24 shapes,
atomic simultaneous clears, ScoreRules, ClassicSession's staged transactions,
Park–Miller state, controller persistence and the Android touch hotfix.
Existing generation is uniform with replacement, board-independent. It offers
replay but no fit guarantee; a blocked fresh tray can end an otherwise playable
board. Existing tests cover placement/clear/score and deterministic replay, but
not a fairness contract or generation distributions.

Baseline regressions: foundation 7/35, gameplay 36/6623, input 14/84, smoke
100 sessions/2579 moves/25990 assertions; all pass. Extended 10000 seeds:
260575 moves/2357854 assertions, zero failures, longest 106 moves.

Additional baseline measurement, seeds 0..999, deterministic first legal
slot/y/x player: 9268 fresh trays, 57 entirely blocked despite catalog moves
(0.61502%); 99.38498% satisfy the new immediate-fit contract. Legal placement
counts over fresh trays: min 0, median 48, p95 137, max 192, mean 56.7801.
Session moves: min 8, median 23, p95 47, max 98, mean 26.483. Scores: min 30,
median 174, p95 436, max 983, mean 200.898. This is one reproducible player,
not a human difficulty rating or optimal policy.

## Contract and trade-offs

Only a completely consumed tray is replaced. Three independently sampled IDs
with replacement preserve the catalog, duplicates, and tray UX. If at least
one candidate has a legal placement, accept it unchanged. Otherwise enumerate
catalog shapes that fit and replace slot zero with one RNG-selected fitting
shape. If none fit, keep the candidate: board exhaustion permits a blocked tray.
There are no rerolls. On a board with any supported placement, every fresh tray
must have at least one immediate legal move (100%, zero avoidable dead trays).
Consumed trays are not repaired: player decisions can legitimately block the
remaining pieces. Fairness does not promise endless survival.

Repair biases distribution toward currently fitting shapes and slot zero on
otherwise dead draws; unmodified draws retain Phase 1 distribution. Selecting
uniformly among fitting SHAPES is not uniform among placements. No hidden
weights, score/clock-dependent difficulty, solvability rerolls, advertising,
monetization, or cloud inputs. Difficulty is a fixed catalog and policy, not a
progressive ramp. Record distributions to characterize this intervention;
there is no arbitrary target score/session length or fallback percentage.

All three pieces are NOT required to be sequentially playable. A bounded
optional analyzer searches all slot orders and row-major legal positions,
including line clears; it returns found with a witness, proven impossible,
or budget_exhausted (unknown, never called impossible). It is diagnostic and
not on drag or generation paths. Budget is 1..256 placement simulations and
at most 256 * 3 * 64 fit probes plus root checks, recursion depth three.

## Rules, determinism, and persistence

Analyzer delegates placement validation and clearing to the live PuzzleBoard;
all evaluations clone the board. Invalid/null/unknown inputs fail closed.
Game over means no remaining tray piece has any legal placement. Report cause
as remaining_tray_blocked when another catalog shape fits, otherwise
board_exhausted. Single is in the catalog, so any empty cell is a catalog move.

Reuse Park–Miller modulus 2147483647, multiplier 16807 and Phase 1 seed
normalization. Fair selection bounds rejection sampling to eight state advances
per sample; after eight rejected samples, use the last sample modulo the
requested count and count this rare bounded-sampler fallback. This theoretical
small bias is an explicit bound versus perfect uniform rejection sampling.
At most four samples (32 RNG advances) and 24*64 + 3*64 board fit probes per
fresh tray. No wall-clock value enters decisions; timings are diagnostics only.

Save the same schema/ruleset/scoring plus RNG policy immediate_fit_v1 and the
31-bit state. Legacy saves WITHOUT policy keep the original Phase 1 generator
for their entire resumed session; unknown policies fail closed. Restart/new
game uses the new policy with a newly selected initial seed. Resume restores
board, consumed slots and exact next-draw state without regenerating the tray.
Per-process diagnostic counters/timing are not decision state or persisted.

## Acceptance and performance

Require zero rule/oracle, contract, replay or input failures; 10000 seeded fair
sessions with recorded failure seed, board, tray, RNG and action. Compare the
same first-legal player and seeds to the baseline; also exercise randomized
legal actions. Measure legal counts, scores, length, fallback count, game-over
cause and max generation time. Every seed must reproduce independently and
resume across refill. A 5000-move simulation cap is a failure, never a pass.
Structural bounds are hard acceptance; timing is measured cloud CPU evidence,
not an Android frame-time guarantee. Low-end device responsiveness remains a
release prerequisite. No analyzer work or new allocation is added to drag.
