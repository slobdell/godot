# Stream: brains (the bridge: crews ordered across the Locks drive into the river; then the squad that leaves the army)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 24 direction* (his words and the
> orchestrator's reading), `_agents/navigation.md`, `_agents/doctrine.md` *A plain move travels AS a formation*,
> `_agents/workstreams.md` *Round 24* (C24.1 the freeze, C24.2–C24.5), and round 23's brains report
> (`streams/archive/round23/brains.md` Status). You own `game/ai/**` EXCEPT native's files (C24.1: `avoidance.gd`,
> `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `brain_switches.gd`, `game/ai/native/**`, the C23.1 seams in
> `movement.gd`, the C23.1a seam in `pathing.gd`), `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`,
> `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`,
> `mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines you declare.
> **The freeze (C24.1):** the moment CP1 (your R1) is on `main`, the per-vehicle tick's files become native's to port
> and you change no behaviour in them for the rest of the round. Your R2 lives in `game/tactics/**` and the order-level
> files listed in C24.1.

## The lead's direction (2026-10-08 ~20:20 PDT, playing round 23's close: the Locks, seed 15833)

> *"ok I also found another obvious bug that one of the workstreams should take on. I just tried smoke testing the
> game, and on the map there's a bridge. I told all my units to go and attack at the remote locationa cross the
> bridge, and a whole bunch of them got stuck seemingly trying to drive through the river. Clearly our pathing
> algorithms are not navigating maps correctly, i.e. identifying that they need to cross a bridge to get where they
> need to go. Additionally, this is more minor but I think a subtle thing that should be accounted, but I had a lot of
> units selected, I moved them all to the west side of the map, and one squad took a whole different route and
> basically arbitrarily detached from the rest of the force - I'm not sure how our navigations algorithms work but
> presumably in decision making there should be a cost associated with a vehicle or vehicles detaching from the
> safety of the rest of their army"*

Also standing (`game_design.md`, memory *Smart AI on both sides*): whatever makes his crews smarter makes the CPU's
equally smart; a symmetric improvement ships without asking.

## Where things stand (read at `fc56bd64` = round 23's close; the orchestrator's reading, VERIFY it first, lesson 274)

- **The recording:** `streams/references/round24/his/2026-10-08T20-17-24-locks.jsonl.gz` (+ `.perf`, `.booth.txt`).
  `make recording FILE=<path> ORDERS=1` lists his orders with their times; `UNIT=<name>` follows one crew. Read the
  orders before forming a theory: which order (attack-move or move), to where, which squads, and which crews ended in
  the water and where.
- **The layers a crew's route passes through** (candidates in the order to test): (1) the navmesh: does a path over
  the bridge exist on `locks`, and is the river cut out of it (`make nav-*` targets in `mk/nav.mk`; `navigation.md`)?
  (2) the route: does `Pathing.find_path` (`game/ai/pathing.gd`) return the bridge route, and does the element's
  transit (`game/tactics/element.gd`) and the crew's leg (`game/ai/movement.gd`) follow it, or does an attack-move's
  leg, a slot, or a straight-line steer take the direct line across? (3) slot grounding (`game/tactics/slot_ground.gd`):
  a slot snapped to the far bank, a crew driving straight at it. **Round 23's N2a (native) reimplemented
  `closest_point` bit for bit** (13 maps × 961 points equal); it should not be the cause: prove it by running his order
  with `--brains-off=native` (same stuck crews → not native).
- `locks_dry.json` exists beside `locks.json` (the dry variant): a scenario on both tells water from geometry.
  Other maps with water or a crossing: `crossing`, `crossing_dry`, `pit`, `sumps`, `terminus_canal`, `archipelago`
  (verify the list from the arena JSONs).
- `game/tactics/coherence_probe.gd` exists (a body-coherence instrument from an earlier round): the natural meter for
  R2's "one squad left the army".
- B1 of round 23 (the squad paces itself) and the seat fix are on main; the arrive series is part of green for any
  movement change (lesson 261).

## Backlog (in order)

**R0 — his bridge case, reproduced.** From the recording: the order, the squads, the crews that went into the water,
the time each stuck. Then a headless scenario on the Locks (`tests/ai_scenarios/`) that issues his order from his
start and FAILS today: count crews in water / off the bridge route / stuck at t+N s. Run it with
`--brains-off=native` too. Write in Status which layer leaves the bridge, with the trace that shows it (lesson 269:
the trace before the ruling).

**R1 — the bridge fix (CP1; the round's first merge, ALONE).** Fix the layer R0 names. Acceptance: his scenario passes
on 3 seeds, both teams (the CPU ordered the same way crosses too); a new nav check across EVERY map with water or a
crossing (`tests/nav/`): for a lattice of start/goal pairs on opposite sides, the route a squad is given never crosses
water and the crews reach the goal; the arrive series (five maps × 4 seeds × both arms, builder0) shows no cost on the
ordinary move; the thirteen lines + determinism UNMOVED or DECLARED (C24.3). The moment it is green, message the
orchestrator **"CP1 GREEN, merge here: <sha>"**: native's freeze starts on the fixed code, so speed matters more
than polish here: a narrow correct fix first, a broader one later in R2 if it belongs there. **After CP1 you change no
behaviour in the C24.1 freeze set.**

**R2 — the squad that leaves the army (a cost on detaching; DECLARED, alone, symmetric).** His second case from the
recording: many squads ordered west together, one squad routes another way. Design (yours; record the reason): squads
ordered together share the body's corridor (one route for the body, each squad's route offset within it), or each
squad's route choice carries a cost for leaving the body's route (distance from the body's corridor, exposure while
alone). It applies to the CPU's grouped orders too. Lives in `game/tactics/**` and the order-level files C24.1 leaves
you (`squad.gd`, `order_controller.gd`, `formations.gd`, `cpu_commander.gd`, the route queries of `pathing.gd` minus
native's seam); if it needs a hunk inside the freeze set, it is a request through the orchestrator (C24.1). Acceptance:
his case reproduced (FAILS before), the coherence probe's reading before/after on his case and 3 seeds, the arrive
series, the thirteen lines declared or unmoved. A real alternative route the body should split over (two bridges both
needed for time) is a judgement: the cost is a cost, not a ban; write the case in Status.

**Stretch (in order):**
- (a) A standing nav guard: the R1 nav check folded into `make check` (fast, every map), so a map edit that cuts a
  bridge or a navmesh change that opens the river fails the check.
- (b) Price B1's +0.75 s on an ordinary 150 m move (round 23's unpriced cost: the creep of crews ahead of their seat,
  or the give-way's dips) by MEASUREMENT only (by removal, lesson: attribute a cost only by removing it): no edits in
  the freeze set; a finding for round 25.

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). ALL JUDGED; thirteen lines + determinism UNMOVED unless declared.
- The arrive series for any movement change (lesson 261), five maps × 4 seeds × both arms, builder0, tabled with commit
  and machine; `make element-digest` identical on the OFF arm.
- His scenario's numbers before/after, builder0, 3 seeds; ONE recording of the fixed bridge looked at frame by frame
  (desktop and phone aspect screenshots of the crossing, `make` targets in `mk/ai.mk`).
- Every number: commit, machine, workload, sample size (C16.3). A `.uid` for every new test committed with it (lesson 273).
- **The laptop is the orchestrator's** for its native-ON perf table at the launch (C24.4): run Godot on builder0 until
  the orchestrator says the table is done.

## Don't touch

`native/**`, `mk/native.mk`, `game/ai/native/**`, `avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`,
`brain_switches.gd`, the C23.1 seams in `movement.gd` and the C23.1a seam in `pathing.gd` (native) · **after CP1: the
whole C24.1 freeze set's behaviour** · `game/control/**`, `game/ui/**` (resting) · `game/match/**`, `game/tank/**`,
`game/units/**`, `game/modes/**`, `arenas/**`, `game/arena/**` (nobody: a request, e.g. if the map itself is wrong) ·
`tests/baselines/**` except lines you declare · `mk/core.mk`, `tools/remote.sh` (the orchestrator's).

## Waiting on the lead

- Nothing blocks you. Decide, record the reason in Status, keep going.

## Status

_Updated 2026-10-09 by the brains worker (godot-brains, stream/brains)._

**Report (round 24, brains):** R0 done; **R1 = CP1 merged (`9692ebbe` → main `b6bd539a`)**; **R2 merged
(`e48b45ca` → main `1fccccfb`)**; stretch (a) the nav guard is in `make check` (`tests/nav/test_nav_water_routes.gd`);
(b) priced (a finding: ~+0.5 s is the give-way, freeze set); (c) the feed cache merged (`395a732b` → main `59a161f2`,
laptop −1.1 ms a tick); (d) the tactical queries measured and granted to native as C24.6. **Final: GREEN, merge here: `7b17baf0`** (builder0, `make check exited 0`, 2310 passed / 0 failed, 23
targets ALL JUDGED, thirteen lines UNMOVED): what it adds over main is EQUAL ANSWER (the `sq.*` profile counters, the
B1 part switch at its default, the benches `feed_bench`/`poll_bench`, Status). Known issue left: queues at a bridge mouth (an anchor-placement fix tried and reverted; next is the crew
give-way, freeze set). Questions for the lead: none.

**Plan (in order):** R0 reproduce + name the layer → R1 narrow fix, his scenario + nav check on every wet map, the
arrive series, `make check` → **CP1** → R2 (squads ordered together keep to the body's route) → stretch (a) the nav
guard (already in `make check`: `tests/nav/test_nav_water_routes.gd`) → stretch (b) price B1's +0.75 s.
**Baseline:** main `fc56bd64` = round 23's close, checked by the orchestrator (builder0 2295/0 ALL JUDGED); `bfc00f53`
adds docs only, so no separate baseline check was run here.

### R0: his bridge case, reproduced (DONE)

**His recording** (`references/round24/his/2026-10-08T20-17-24-locks.jsonl.gz`, census every 30 ticks): he never
issued one order to cross; he issued many attack-moves/moves from the north quay toward the far quay (90.3 s:
attack_move Hunters 2/4/5/6 → (-59, -55), Guns_4 → (-95, -49), etc.). The crews that "drove into the river" were
**in contact** (census order `attack`, i.e. fighting on an attack-move) and sat 2-25 s at z ≈ 10-12 (the north rim; the
canal is z -7..7): Green Hunters_2 14 samples at (-51..-54, 11-12), Guns_8, Guns_4, Hunters_3, Guns_2, Eyes_4 … and the
CPU's crews the same on the south quay (Rust Hunters_3 25 s at z ≈ -12). Hunters_4 on the same order crossed by the
west swing bridge fine: the navmesh and the route are right.

**The headless stage** `tests/tactics/bridge_stage.gd` (`make bridge-series`, `make bridge-trace`): four Law tanks on
the north quay attack-moved (element task, drills on: his attack-move's path) to the far quay, three lancers on the far
bank; `side=rust` mirrors it (the CPU ordered the same way). Each crew sampled against the arena's own water; the
trace prints the crew's order, `direct` flag, K1 order, seat, anchor, and what its hull touched (`get_slide_collision`).

**The layers that left the bridge (traces, builder0):**
1. **Combat hops over the water (the bug he saw).** In contact, `TankBrain._combat_move` sends `CombatMotion`'s hop as a
   `direct` move (no navmesh: the brain "already checked the straight line"), and CombatMotion's feasibility asks the
   CoverMap (walls and props), which does not know water (water is fire-transparent by design). Trace: crews at
   (-58, 12) ordered `move_to (-48.8, -10.0) direct` straight over the canal, then pressing the rim. 385-784 crew-ticks
   of such hops per fight run on main.
2. **Seats on the wrong bank** (`Element.ground`): a seat laid in the canal is grounded to the nearer bank (a coin toss),
   and round 21's side rule (`SlotGround.standable_from`) steps it back to the bank the element came FROM (it treats the
   canal like a row of containers: the far bank "needs a detour"). A wedge whose anchor has just crossed also lays its
   rear seats on the near quay (dry, never touched). Trace: S_4's seat flips from (-74.1, -12.1) to (-73.1, +12.1).
3. **A crew sent to stand on a bridge** (found while fixing 2): a seat in the water grounded to the nearest navmesh
   = the deck; the crew arrived on the bridge, "covered its sector", and the squad queued behind it for 50 s. A second
   form: a seat reseated at the deck's far end (z -7.6). Main has these too (OFF arm: bridge jams up to 163 s).

**Ruled out (with traces):** the navmesh (routes cross by the bridges on every wet map: `test_nav_water_routes`); the
floor/deck seam (a probe drove hulls straight over both bridge mouths at 0/±15/-20°: all cross); native
(`closest_point` is not on any of these paths; the probe's `--brains-off=native` flag is wired, not needed). One
artifact of my own stage, recorded so nobody repeats it: crews laid inside the warehouse at (-30, 42) are pushed out
DOWNWARD by the physics and drive under the floor into the water's pan (TANK_OFF_FLOOR); the stage now starts clear.

### R1: the fix (`a44fbc91`, candidate; DECLARED, symmetric, switch `SlotGround.WET_ENABLED`)

- `SlotGround` (game/tactics): `wet` / `leg_wet` / `over_water` (a deck and its mouth, +2 m, count: no place to be
  told to stand; routes still cross decks) / `dry_leg_end` / `pulled_dry` / `on_anchor_side`, all read from
  `Arena.active` (a dry map pays one dictionary lookup).
- `TankBrain._combat_move`: the hop is cut a hull's half length + 2 m short of the first water on its leg; a hop with
  under 2 m left is a halt facing the target (this branch only runs with the target visible and in gun range: he fires
  across the water). Counter `TankBrain.wet_hops_cut`.
- `Element.ground`: every seat on its anchor's side of the water and off a bridge (`on_anchor_side`); an order's goal
  over the water is pulled toward the anchor (`pulled_dry`); an anchor HE put on a bridge or in the water is left alone.

**His scenario, `make bridge-series`, builder0, 6 seeds × (green, rust with 3 lancers; green with none), both arms**
(stage start (-62, 30); ON = `a44fbc91`'s rules, OFF = `--wet-ground=off` = main's behaviour):

| | crews pressed into the water ≥ 3 s (runs) | every crew crossed (fight runs) | straight hops over water |
|---|---|---|---|
| OFF (main) | 11 of 12 fight runs (rim up to 71 s) | 7 of 12 | 436-784 crew-ticks a run |
| ON | **0 of 18** (rim ≤ 2.6 s) | 11 of 12 (+ 6/6 plain) | **0** |

The plain crossings (no enemy) are identical in both arms on these seeds. The one ON run that leaves a crew behind is
the known issue below.

**Tests (in `make check`):** `test_tactics_wet_ground` (the helpers on the Locks' layout), `test_tactics_bridge` (his
case seed 1, both sides: no hop over water, no crew pressed into it; his side crosses 4/4, the CPU's ≥ 3/4, see known
issue), `tests/nav/test_nav_water_routes` (every map with water or pits, read from the arena list: crossing routes
between points either side of each carving reach the far side and never cross water; seven maps). That last one is
also stretch (a), the standing nav guard.

### Stretch items (orchestrator's relay, after R2)
- **(b) B1's +0.75 s, priced by removal (DONE; a finding for round 25, no change shipped).** The arrive series on
  the PLAIN move where B1 lives (`ARRIVE_DRILLS=off`; my first attempt ran the attack-move default, where B1 never acts:
  100/100 identical, a null that only proved that), builder0, code `fa254a48` (+ the part switch, default-identical),
  5 maps × 5 squads × 4 seeds, paired: **all of B1 off: shipped is +0.54 s slower** (se 0.33, median +0.80, OFF faster
  in 61 of 100; stopped +0.46, se 0.50), consistent with round 23's +0.75 (se 0.31). **The anchor's form_pace removed:
  +0.16 s** (se 0.20, removal faster in 56); **the crews' crew_paces removed: −0.17 s** (se 0.18: removing it is SLOWER,
  faster in 34). Neither of the two parts in `game/tactics` carries the cost; by what is left (assuming the parts add)
  **~+0.5 s is Movement's give-way** (`GIVE_WAY_*` in `movement.gd`: a paced crew blocked behind a squadmate eases to
  half speed for a second), in the freeze set. Round 25: a give-way arm (`GIVE_WAY_AFTER_TICKS` large) on the same
  series would confirm it directly. Switch `ElementPlan.PACE_PART_OFF` / `--pace-part-off=anchor|crew` stays for that.
- **(c) ElementFeed.context cache** (native measured `t.poll` 7.9 % of the brains' work at 50 v 50): EQUAL-ANSWER only.
  `4e31cdd9`: `Element.feed_state()` (the state dictionary once per element per physics frame, re-stamped by every
  mutator; `ElementFeed.FEED_CACHE`, `--feed-cache=off` = control). Check on `4e31cdd9` (builder0): 2309 passed / 0
  failed, all thirteen lines UNMOVED, but perf-judge and the perf scenario NOT JUDGED (box busy: my own sizing runs were
  in the light lane; lesson for me: no perf A/B beside a check). Same fight in both arms at 50 v 50 (`state_hash`
  `01c52e9a7eb96a63` in both). First pinned pair (n = 1 each): t.poll 3.90 → 3.14 ms a tick, but an untouched part
  (`t.rate_progress`) moved 18 % too, so n = 1 is noise; an interleaved n = 4 per arm is running.
  **Lesson (mine, cost an hour):** a remote run's copy-back mirrors builder0's `build/` over the local one and DELETES
  anything else there; my A/B script and its results lived in `build/` and vanished under a check. Keep anything that
  must outlive a remote run in the scratchpad.

  **v3 = `395a732b` (GREEN, merge here, EQUAL ANSWER):** what the time really was (`tests/tactics/feed_bench.gd`,
  builder0, in-process, both arms interleaved, 10 000 calls each): one context ~50 us = `Element.state()` 11-13 us +
  the feed's own per-crew `normalize` ~27 us; caching state() alone bought -11 %. v3: `Element.feed_state()` is a lean
  view of the 14 keys the feed reads (3.7-4.4 us, state()'s values and formats, no copies), and ElementFeed builds the
  element-wide half of a context (members, leader, technique, drill, task, id, formation, pitch, transit velocity) once
  per element change, shared by its crews: ~20 us a crew on a hit. At 50 v 50 with leaders (`native-sizing`, builder0
  pinned 0-3): 4.75 shared builds per 14 calls a tick (66 % hit); one pair's feed share of t.poll 0.43 → 0.34 (absolute
  numbers swing 2x with the box's load). **Honest expectation: ~0.3 ms a tick at 50 v 50 on builder0 (~0.8 ms on
  the laptop) out of t.poll's 2.1 ms there;** the orchestrator prices it on the laptop with native's instrument once
  both are on main. **Proof:** `test_tactics_feed_view` (the view == state(); every crew's context equal with the cache
  off and on, a moving element, six moments, three verbs); `state_hash` equal at 50 v 50 (`01c52e9a7eb96a63`);
  `make check` on `395a732b` (builder0): **2310 passed, 0 failed, ALL JUDGED, thirteen lines UNMOVED**; element-digest
  `0a9a1b36cbd7d6028dd2aac27764d6b5` (64 runs) = CP1's, identical. **Merged alone on main as `59a161f2`.**
  **Laptop price (the orchestrator, native's tick-profile instrument, windowed, his preset, 25 a side, foundry+parade
  × 3 seeds, 8-20 s in contact, paired by seed, `--feed-cache=on` v `off`):** tick scripts −1.1 ms a tick (se 0.47,
  ~−3 %), one outlier OFF run excluded; controllers 26.6 → 24.5 ms.

- **(d) TacticalQuery / SquadTactics in build_situation** (native measured ≈ 2 ms a tick of ~34 on the laptop in
  contact, 25 a side). Measured where it goes (builder0, `native-sizing` 50 v 50 with leaders, pinned 4-7, n = 1,
  profiling on: read shares, not absolutes; counters `tq.cover_fire`, `tq.cover`, `tq.hull_hidden` (taken back out
  at `081cb7f4`: native's C24.6 seam goes at the top of those functions) and `sq.gather`, `sq.plan` (kept; profile-only,
  equal answer)): `s.cover_fire` 1.17 ms a tick, of which
  `TacticalQuery.find_cover_fire` 0.86 at 0.8 calls a tick = **~1.1 ms a call** (~15 `hull_hidden` + peek searches per
  call); `s.cover_spots` 0.57, of which `find_cover` 0.21 (~0.7 ms a call, 0.29 a tick); `s.tactics` 0.73, of which
  `SquadTactics.for_squad`'s misses 0.44 (gather 0.18 + `plan()` 0.25, 1.03 misses a tick) and its hits ~0.3 (the
  frozen `_tactics` glue); `s.squad` 0.65 is `AiTickCache.squad_context` (frozen). **Finding: a C++ port, not a cache.**
  Every crew asks `find_cover_fire` / `find_cover` its own question (its position, its target; already cached per crew
  for QUERY_EVERY_TICKS in tank_brain), the sight lines underneath are already memoised and native, and what is left is
  GDScript loop overhead over CoverMap: the whole-loop shape lesson 276 asks a port to have (one call per query, the
  candidate points and the CoverMap in native). The only equal-answer share I found (one team contact list per tick for
  all its squads' `for_squad` misses) is worth < 0.1 ms: not done. **Granted to native as C24.6 (main `c4d2ce7d`); I don't edit those functions while the seam is open.** The request was: port
  `TacticalQuery.find_cover_fire` + `find_cover` (+ `hull_hidden`, `peek_from`, `_cover`, `_candidates`; pure functions
  of CoverMap and a request dictionary; `tests/test_ai_tactical_query.gd` covers them) behind a switch, equal answer.

### Known issue (not the river; for after CP1)

**Queues at the bridge mouth.** A crew can stop on the one-hull strip between the rim and the warehouses, short of its
seat (its K1 order completes; Movement's goal repair or a shape anchor laid at the water's edge), and the crews behind
it push at it for 30-60 s. Trace (CPU side, seed 1): S_2 parks at (73.5, 13.5), S_1 pushes it for 35 s. Present on main
(the OFF arm's bridge jams are larger). Candidate fixes: leg anchors kept ≥ a shape's depth off the water; "idle crews
are pushed aside" for a crew that has finished its order. Not in CP1 (narrow fix first).
**Tried after R2 and reverted (2026-10-09, builder0, bridge series 6 seeds × 3 cases):** a leg anchor kept 12 m off the
water (moved on along the leg). The fight runs did not change at all (in contact the leg rule is not what places the
squad), and the plain crossings got WORSE (bridge jams 64-81 s on two seeds, one crew pressed 17 s, later arrivals): a
shape pushed past the bridge's far end makes the trailing crews turn in the mouth. So the queue is not the anchor's
placement. The next thing to try is the crew level: a crew that finished its order and stands in a bridge mouth gives
way to a crew pushing at it (Movement's give-way/pushidle, the freeze set: native's this round).

### CP1: GREEN, merge here: `9692ebbe` (sent to the orchestrator 2026-10-08 night)

- **Check:** builder0, `make check exited 0`, **2306 passed, 0 failed, 23 targets ALL JUDGED**
  (`build/brains-check-9692ebbe.log`). The first check (`a44fbc91`) was 2306/0 with sim-baseline MOVED on exactly two
  maps, crossing (river) and gorge (pits), DECLARED (C24.3) and adopted at `9692ebbe` (`make sim-baseline-adopt`, every
  map read twice on builder0, agreeing): crossing `efc8449e` → `f6d8b9e0`, gorge `c53b4eb1` → `f5d988dd`; the other
  eleven unmoved (locks, sumps, pit, docks, archipelago included: their dealt matches never hop at water). Determinism
  passed.
- **Arrive series** (lesson 261; builder0, `a44fbc91` game code, `make squad-arrive-series ARRIVE_ARM_FLAG=wet-ground`,
  5 maps (yard terminus pit sumps cut) × 5 squads × 4 seeds × both arms): **100/100 arrive in both arms, identical
  median times, re-seats and swaps** → no cost on the ordinary move. (The arm is live: the bridge series' arms differ.)
  That series ran the attack-move default; **on the PLAIN move** (`ARRIVE_DRILLS=off`, builder0, 2026-10-09, code
  `fa254a48`) too: **100/100 arrive in both arms, all 100 identical.**
- **Frames looked at** (`make bridge-shots`, builder0, 1600x900 and 1080x2340, both arms; `build/tactics-shots/`):
  ON, the squad fights from the near quay at 10 s with nobody in the canal, crosses by the west swing bridge at 30 s, and
  all four are on the far quay in formation at 40 s; OFF, crews bunched at the bridge mouth and one crew went to the lock
  and stood on its deck.
- **Freeze set touched:** `tank_brain.gd` (`_combat_move`'s hop clip only). From CP1 on I change no behaviour there.

**What to playtest (his path):** `make garage` → the Law → FIGHT on the Locks (or `make skirmish ARENA=locks`), select
everything, attack-move to the far quay across the canal: crews in a fight on the quay stand and shoot across the water
instead of driving into it; squads cross by a bridge; nobody parks on a bridge.

### R2: squads ordered together keep with the army (GREEN, merge here: `e48b45ca`; DECLARED, alone)

**His case, read from the recording** (26.8 s): three squads selected together and moved west: Sirens (four
suppressors, ~(4, 62)) to (-69, 21), Hunters 2/3/4/6 to (-61, 117), Hunters 1/5/7 to (-65, 70). The Sirens drove south
down the middle toward the canal, alone (one died 4 s later); the Hunters went west along the north. The goals were
already ~50 m apart (orders' frontage layout); the ROUTE is what left the army.

**Design (decided; reason):** a cost, not a ban (his words: "a cost associated with ... detaching"). Squads ordered
together = elements of one team whose task arrived on the same physics frame (`Element.task_frame`: his selection, or a
CPU commander's pass). On a plain move each weighs its own shortest navmesh route against "with the body": join the
body's route (the army's centre → the army's destination centre) where it passes nearest, leave it nearest its own
spot. Cost = length + `BODY_DETACH_WEIGHT` (2) × metres farther than `BODY_CORRIDOR_M` (25) from the body's route;
the cheaper wins (`Element._route_with_body`, `body_choice` for the probe and the log). Switch `Element.BODY_ENABLED`.
Lives in `game/tactics/element.gd` only (no freeze-set file).

**Measured overturn (lesson 266):** I also offered the body's route to the CPU's grouped DRILL moves (its attack-moves:
`ElementPlan._route_step`). Measured, they already keep together (13.5-15 squad-seconds alone OFF) and the body route
made them worse (21-104 s, one seed never arrived): reverted. Symmetry holds where the problem lives: any plain move
given to several elements together, his or a CPU commander's (its fall-backs are plain moves).

**Why the computer's attack-moves do not need it (in player terms):** a computer squad on an attack-move never drives a
long route of its own. Its leader moves it in short steps straight toward the objective (each step a few dozen metres,
the squad re-forming around the step's end before the next), and its commander sends its squads to places set relative
to each other (the main body, the support a fixed distance behind it). So the squads advance side by side by
construction, and there is no single long path for one of them to wander off on. His squads on a right-click move are
different: each is handed a far destination and drives the whole shortest path to it at once, so one squad can pick
the other side of a building and be 50-75 m from the rest for half a minute. That is the case the cost fixes. Offering
the army's route to the computer's step-by-step squads made their steps zig-zag between the army's route and the
straight line (measured worse), so they keep their steps.

**Numbers** (`make body-series`, builder0, the R2 tree = `e48b45ca`, seeds 1-6, his case on both sides + the CPU's
drill-move case): CoherenceProbe `alone_s` (element-seconds no other squad within 40 m) his side **42-102 → 6.5-23.5
(12/12 runs)**, the Sirens take the army's route every time, the last squad in **mean 26.9 → 22.6 s**; CPU drill
moves identical in both arms (12/12). **A split that pays still happens** (`test_tactics_body`, the split case): two
squads ordered across the Locks by the two flank bridges keep their own (84 m own vs 305 m with the army).
**Check** (`e48b45ca`, builder0): `make check exited 0`, **2309 passed, 0 failed, ALL JUDGED**; the thirteen lines
UNMOVED (the dealt matches are CPU drill moves). The arrive series is single-squad, so R2 cannot touch it (no
siblings): not re-run.

**Playtest:** select three squads, right-click a spot across the map with a building block between them and it: no
squad goes the other way round the block on its own.

### L1 (phase 2, C24.7): think less often where it does not matter — PLAN (2026-10-09)

The bar: game speed ≥ 0.97 in the 8–20 s window on his laptop at 25 a side (today ≈ 0.79: 124 ms frames at 2.94
ticks, pinned at the catch-up cap). By native's breakdown (tick scripts 34.5 ms, think 15.1), real time at 3 ticks a
frame needs a full tick of ≈ 29 ms: roughly −9 ms, i.e. thinking in contact must fall by more than half.
1. **Census first** (sim state only): in the opening clash, of the crews the LOD calls "fight" (in reach), how many have
   fired, been hit or had a round come at them in the last ~2 s ("engaged") v not ("quiet")?
2. **Rule:** engaged → 10 Hz (as today); in reach but quiet → a lower rate (the knob); wake at once on a hit, an incoming
   round (already, for dodgers), a new contact coming into reach (already: the re-rate), an order or element call
   (already: signals). Then `brain_stride` / far-unit levers reopened as further knobs.
3. **Prove:** a scenario (think calls in the opening clash fall, the first shot is not later), the paired series (arrive,
   beaten zone, pursuit, his bridge and body cases, a match series both sides for win-rate symmetry), the laptop's
   in-contact price (booked through the orchestrator), and a knob table (speed bought v behaviour cost).

### Questions for the lead
- None blocking.

### Requests to other streams
- **native (via the orchestrator; the freeze set): what the rest of `t.poll` is, measured from outside
  `tank_brain.gd`** (`tests/tactics/poll_bench.gd`, builder0, in-process, a player squad moving under its element,
  20 000 calls each; absolute numbers swing with the box, ratios hold): `OrderFeed.current` ~9-22 us (control's
  `Orders.current` 1-3, `goal_position` 1.6-4.4, `pace_factor` 1.8-5.5, the feed's own `normalize` 4-15: I tried a
  memo of its identity text, -36 % of normalize in an interleaved A/B but only ~0.04 ms a tick at 50 v 50 because it
  runs on thinks only; reverted as not worth it); `OrderFeed.station` 1.3-3.8 us; `Match.squad_for` 1.3 us;
  `OrderFeed.key` 0.8-1.5 us; the two `AiTickCache` source lookups and `player_team` 0.2-0.4 us each. The poll's lap
  runs EVERY tick for every brain (65 calls a tick at 50 v 50) and the per-tick path is these small pieces: the
  station (player's idle units, every tick) and `squad_for` are the largest per-tick ones. Equal-answer candidates,
  all inside `_tick`'s poll in `tank_brain.gd`: (1) read `OrderFeed.station` only when `order` changes or the order
  source signals (`_order_dirty`), not every tick; (2) cache `squad_for(tank)` per brain until the match's squad table
  changes. I can't sub-lap or edit it (frozen); numbers above are the ceiling of what each would save.
