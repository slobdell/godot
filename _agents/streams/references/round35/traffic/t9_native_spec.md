# T9 (R35.14): the native mirror spec (traffic → native)

GDScript reference: `game/ai/movement.gd` on stream/traffic (the block "Round 35 (traffic T9 …)" and `_end_yield`), switch
`Traffic.off("yieldfit2")` (DEFAULT_OFF on the stream: `["underfire", "holdfire", "yieldfit2"]`; OFF = main bit for bit).

1. **`_end_yield`** (drive_native.cpp ~1863, `v.set__last_yielded_to(yield_to)`): becomes
   `if not _yield_unfinished(): _last_yielded_to = yield_to` — evaluated BEFORE yield_to is cleared.
2. **New `_yield_unfinished() -> bool`** (false when yield_to is "" or the switch is off or no tanks_root):
   - asker = tanks_root/yield_to; null or dead → false.
   - passed = flat dist(me, asker) > YIELD_CLEAR (9.0) OR (asker − me)·_yield_dir > 0 OR (asker's mover exists and NOT
     is_under_way()) — right_of_way's own reading. passed → false.
   - reach = radius_of(me) + radius_of(asker); touching = dist − reach ≤ YIELD_CONTACT_M (1.0); ahead = (me − asker)·_yield_dir > 0;
     on_line = ahead AND `_distance_to_ray(me, asker, _yield_dir)` < reach + YIELD_LINE_MARGIN (0.75). Neither → false.
   - Retry bookkeeping (instance vars `_unfinished_to`, `_unfinished_count`, `_unfinished_since`, physics frames): if
     `_unfinished_to != yield_to` or frame − `_unfinished_since` > YIELD_RETRY_WINDOW_S (30) · TICK_RATE: reset to (yield_to, 0,
     frame). Then count += 1; count > YIELD_RETRIES (2) → `yields_unfinished_capped += 1`, false. Else `yields_unfinished += 1`, true.
3. **`ask()`**'s first line (~2480) is unchanged (`yield_to != "" or asker == _last_yielded_to`); T9 acts only by not writing
   `_last_yielded_to`.
4. **Counters** in route_arms / reset_route_arms: `yields_unfinished`, `yields_unfinished_capped`.

Tests: `tests/test_traffic_yieldfit2.gd` 4/4 (builder0 quick, 2af7d3528+fix). Twin cases: unfinished (asker 8 m behind, under way,
crew on its line) not recorded; the third recorded (cap); asker past → recorded; switch off → recorded.
