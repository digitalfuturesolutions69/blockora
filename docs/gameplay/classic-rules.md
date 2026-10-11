# Classic rules — classic_v1

8×8 board; no gravity, timer, or player rotation. New games generate three curated pieces under immediate_fit_v1; legacy saved sessions retain uniform generation. Consume each slot once and replace only after all three are placed. Pieces must fit entirely without overlap; invalid/canceled actions change nothing. Clear full rows and columns simultaneously, counting intersections once. End only when none of the remaining shapes has any legal placement; a single blocked piece does not end a playable tray. A fresh new-policy tray must contain a legal move if any catalog shape fits; a remaining partially consumed tray can be blocked. All-three sequential solvability is not guaranteed. See [Fair Play policy](fair-play-policy.md).

## Scoring

`ScoreDelta = P + 10L + 5L(L - 1) + 5C`

P = placed cells; L = full rows plus full columns; C = combo before this event, capped at 5. After scoring, a clear increments combo, saturated at 5; a non-clear resets it. Following the approved literal formula, a non-clearing move still receives previous 5C before reset: there is no implicit L>0 condition.

Examples: 4 cells/no combo/clear score 4; 3 cells/one line/C=0 score 13, then combo=1; 4 cells/two lines/C=2 score 44, then combo=3; 3 cells/no clear/C=3 score 18, then combo=0.

Coefficients are injectable, nonnegative, and bounded for safe arithmetic. Persistent Classic uses approved defaults/classic_v1; changing saved rules needs a version/migration decision. Total is nonnegative signed-int64, saturated at 9223372036854775807, limiting granted delta to remaining room. Legal placement never decreases score. Confirmed restart resets current score/combo and preserves best.

Phase 2 adds diagnostic bounded lookahead and immediate-fit generation through PieceProvider without changing placement, score, or UI. Adaptive difficulty, guaranteed three-piece solvability, monetization weighting, Undo, rewards, purchases, Daily/Relax gameplay, and backend remain outside scope.
