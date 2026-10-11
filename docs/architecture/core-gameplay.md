# Core gameplay architecture

Bootstrap retains Phase 0B service composition and injects only LocalStorageService into ClassicApp. External adapters remain no-op. No advertising, billing, SDK identifier, asset filename, or remote dependency enters the domain.

| Layer | Classes and responsibility |
| --- | --- |
| Domain | PuzzleBoard, GamePiece, PieceLibrary, ScoreRules, ClassicSession, PieceProvider, SeededPieceProvider, FairPieceProvider, BoardAnalyzer: pure game rules |
| Application | SessionStateMachine/ClassicController: lifecycle, transactions, best/preferences, save/resume |
| Presentation | ClassicApp: screens/confirmation/local feedback; PuzzleSurface: board/tray drawing and real mouse/touch events |
| Infrastructure | Phase 0B JsonLocalStorage: same-directory temp/flush/rename, identifier keys, bounded reads |

## Board, pieces, and transactions

Board is eight 8-bit row masks in PackedByteArray, exactly 64 occupancy bits. Payload is eight bytes; object/buffer overhead is additional. Column x is bit `1 << x`; row y is `_rows[y]`. Invalid reads return -1. Saves accept eight finite integral values in [0,255]. Validate whole-piece bounds/collision before mutation. Detect rows and columns before clearing their union; unique removed cells are `8R + 8C - RC`.

Placement results return status, piece ID, placed count, row/column indexes, unique removed count, and resulting board. Sessions stage board/tray, validate refill, score, then commit once. A faulty replacement provider returns provider_error and restores saved RNG; board/score/combo/tray stay unchanged. Providers must honor snapshot/restore. Accessors expose copies; underscore fields are internal by convention, since GDScript cannot enforce field privacy. UI caches board/coordinates on committed changes rather than copying per pointer move.

The stable classic_v1 catalog contains 24 IDs: single, horizontal/vertical 2/3/4/5 lines, square, four 3-cell corners, four 4-cell L shapes, four T shapes, S, and Z. Factory requires integer Vector2i coordinates, normalized origin, bounds ≤8, uniqueness, and orthogonal connectivity; canonical order is row-major. Dimensions/count derive from coordinates. Semantic render palette keys avoid filename coupling. Saves reference catalog IDs; unknown IDs fail. No player rotation.

PieceProvider generates exactly three valid IDs; its board-aware hook defaults to the original next_tray for legacy/injected providers. New Classic games use FairPieceProvider immediate_fit_v1. Three Park–Miller candidate draws are preserved unless all are blocked; then slot zero is replaced by an RNG-selected fitting catalog shape. The provider receives the staged post-placement/post-clear board. Duplicates remain allowed; consumed slots remain empty strings and refill only when all three are consumed. A fresh tray has an immediate legal move whenever any catalog shape fits; partial trays can legitimately become blocked. Score and monetization never affect generation. See ADR-006 and the fairness policy.

BoardAnalyzer enumerates legal placements, clones for line-clear simulation, distinguishes tray blocking from board exhaustion, and offers diagnostic order-dependent search capped at 256 placement simulations. Search budget exhaustion is unknown, not a proof of impossibility. Lookahead is not invoked during drag or generation.

## Lifecycle and presentation

BOOT→HOME; HOME→PLAYING; PLAYING→PAUSED/HOME/GAME_OVER; PAUSED→PLAYING/HOME; GAME_OVER→PLAYING/HOME. HOME→GAME_OVER is reserved by the machine for restoration; current UI leaves completed saves on Home. Invalid/self/unknown transitions fail. Restart from Pause transitions to Playing after confirmation; Home also confirms replacement of a resumable board. Only Playing accepts placement.

After commit the controller emits move_completed(result) and changed; UI renders and handles local sound/haptics. Preview cannot authorize a mutation. Interruption cancels dragging and pauses; stale releases cannot place. Only the initiating finger can finish. Coming Soon buttons are disabled.

PuzzleSurface transforms viewport pointers to local positions, shows a continuous offset ghost and cell-snapped preview, and uses outlines/check/cross symbols alongside colors. Entire tray cards are targets. Buttons have minimum 96 logical pixels at 720-wide reference size (48 pixels at 360-wide scaling). Device density/accessibility sizing remains unverified. Android safe-area margins use display-safe-area/screen-to-logical scaling with fallback padding; real OEM navigation behavior needs device tests.

## Offline records

Use the existing user://foundation storage root. Session schema:

```json
{
  "schema_version": 1,
  "ruleset_version": "classic_v1",
  "board": [0, 0, 0, 0, 0, 0, 0, 0],
  "tray": ["single", "square2", "line3_h"],
  "score": "0",
  "combo": 0,
  "rng": {"algorithm": "park_miller_16807_v1", "state": 1, "policy": "immediate_fit_v1"},
  "session_status": "active"
}
```

classic_session_v1.json stores this schema. Independent classic_best_v1.json stores schema_version=1/best="123"; preferences_v1.json stores schema_version=1/sound=true/vibration=true. Score/best are canonical decimal strings through signed-int64 max, avoiding JSON number precision loss. Masks/combo/RNG fit exactly in JSON. Status is active/game_over; UI pause/home are not half-turn states. Cold launch enters Home with valid active Resume.

Persist every completed placement, new game, lifecycle transaction, and settings change, never a drag. Write best independently before session; crash between files may leave best ahead of the saved board, which is safe. A valid session repairs a lower best on load. Reject unsupported versions, bad masks/shapes/RNG, wholly consumed tray, completed lines, bad score/combo, and inconsistent terminal status. Corrupt session is ignored with notice; independent best/preferences and new game remain available. Write failures are visible; reads above 1 MiB fail.

Temp+flush+rename supports per-record atomic replacement, not cross-file atomicity, concurrent writers, backups/migrations, fsync, or power-loss durability. One controller owns records; there is no remote persistence.

New saves identify their generator policy. Legacy saves without policy restore SeededPieceProvider unchanged; unknown policies fail closed. This supports old saves in the new app, not a guarantee for downgrading to old APKs. Generation counters/timings are diagnostic and not persisted or used for decisions.
