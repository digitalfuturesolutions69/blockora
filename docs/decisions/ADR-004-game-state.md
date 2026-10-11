# ADR-004: row masks and committed state

Status: accepted for Phase 1 implementation; Android device acceptance pending.

Godot integers are signed 64-bit; bit 63, logical shifts, and JSON precision add risks for one board word. Choose eight 8-bit row masks: still 64 occupancy bits, shifts only 0–7, serialized values ≤255. Column completion ANDs rows; clearing combines rows and column masks. Domain is independent of scene nodes.

Tradeoff: snapshots validate/index eight values instead of one word. Placement visits at most the curated piece's five cells; legal-move search probes at most 64 origins. Object/buffer overhead exceeds eight payload bytes. No claim of eight bytes total RAM or superiority over an unmeasured single-word implementation. Reproducible board benchmark and 10,000-session timing are in Phase 1 evidence; cloud CPU is not Android frame-time.

Stage board/tray, validate refill, score, then commit. Expose snapshots, cache in presentation, and emit signals. Explicit lifecycle rejects inactive moves. Version saves/rules; store score/best as decimal strings and best independently. Temp/flush/rename supports each record, without cross-record atomicity, backups/migrations, concurrent writers, or power-loss guarantee. Unknown/corrupt sessions recover to Home; write failures remain visible.
