# Round 33 traffic X4: T4's circle loop traced (C33.7)

**Run:** builder0 light lane, tree `4b87f72a` (= main `ae3dad71` + traffic's measurement and the parkedroom code, OFF),
`make traffic-trace TRAFFIC_SEED=42 TRAFFIC_TICK=3` (yard_open head-on, both squads, native path), arms: ghost ON
(`--traffic-on=ghost`) v base. Round 32's case (s42/t3: circle reverses 8 → 138) reproduces: **Green_A_5 arrives 44.6 s
with the ghost v 25.2 s without** (end 49.2 v 29.7 s). Rows: `x4_t4_yard_head_s42t3_{ghost,base}.txt` (A_5 every 0.5 s).

**What A_5 does (ghost ON):** a wheeled hull with a FACED slot at (-14.0, -70.4), approach heading west. `_approach_gate`
routes it to a gate one approach length east of the slot, (5.97, -70.06). It reaches the gate area at 18–19 s, a k-turn
starts, and by 21 s it stands ~5 m from the gate pointing NE (heading ~ +50°, the approach is −90°). From then until 39 s
the steer point stays ON THE GATE ("no_path" is only the label: the route ends at the gate, not the goal), the gate lies
inside its turning circle, and Steering's circle rule backs it at full lock, then it drives forward, then backs again:
**circle reverses 11 → 134 in 16 s** with the hull inside a 2 m patch at (0..1, −69). It gets out at 39–44 s and arrives.
**Base:** the same gate; at 19 s it is giving way to A_3 there, one k-turn, and it drives west to the slot by 25 s.

**Mechanism (not the ghost's code):** `_approach_gate` re-aims the gate on every route unless the hull is within
`_arrive_gate()` (2.5 m) of it, or already within the approach length of the goal AND pointing along the approach
(`APPROACH_ALIGNED_COS`). A hull interrupted NEAR its gate (here by a k-turn after ORCA's honest neighbour velocities put it
there differently) and pointing the wrong way is in neither case, so the gate is re-aimed from inside the turning circle
and the circle rule loops round a point the car cannot reach. The ghost only changes where A_5 is when the k-turn ends.

**For brains (B5c-v6's case; `_approach_gate` is brains'):** a gate the hull is already within ~1–2 turning radii of and
cannot reach forward (inside the circle) should be refused ("inside_circle") so the route aims at the slot (the faced
finish then belongs to the k-turn / M1b(3)'s face at rest), or the gate counts as reached once the hull has been within its
circle. Traffic changes nothing here.
