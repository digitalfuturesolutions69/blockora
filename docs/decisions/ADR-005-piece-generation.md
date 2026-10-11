# ADR-005: seeded uniform piece provider

Status: accepted for Phase 1, replaceable by a later approved Fair Play Engine.

Park–Miller LCG: modulus 2147483647, multiplier 16807. Normalize seed via `((seed % 2147483646) + 2147483646) % 2147483646 + 1`; seed 0 starts at state 1. Next state is `(16807 * state) % 2147483647`. Products fit signed-int64; states fit exact JSON numbers.

Sample state-1 in [0,2147483645]. Reject values ≥ `2147483646 - (2147483646 % catalog_size)`; accepted value modulo stable 24-shape catalog selects an ID. Draw three with replacement only when tray empties. Persist algorithm park_miller_16807_v1/state and ruleset classic_v1. Seed-0 reference states 16807/282475249/1622650073 give line4_v/single/l4_top.

New games use time/tick-derived seeds; tests inject seeds. This is gameplay RNG, not cryptographic RNG. No board/score/monetization input, filtering, weighting, or fit guarantee. Same seed/catalog/actions reproduce snapshots and save/resume continuation. PieceProvider exposes next_tray/snapshot/restore; replacements must return three valid IDs and honor rollback. Phase 2 solver is not implemented.
