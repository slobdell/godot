# Stream: brains (the bridge, again: wide shapes stick on the crossing, some crews never cross; seats by nearest)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 25 direction* (his words, the
> orchestrator's reading) and *Round 25: the launch* (the decisions made for him), `_agents/doctrine.md` *A plain move
> travels AS a formation*, `_agents/navigation.md`, `_agents/workstreams.md` *Round 25* (C25.1–C25.5), and round 24's
> brains report (`streams/archive/round24/brains.md` Status: CP1's bridge fix, R2's group route, B1). You own
> `game/ai/**` EXCEPT native's files and seams and pace's think-scheduling hunk (C25 ownership list), `game/tactics/**`,
> `tests/ai_scenarios/**`, `tests/tactics/**` (minus `l1_speed_table.py`), `tests/nav/**`, `tests/test_ai*.gd` (minus
> `test_ai_think_lod.gd`), `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `mk/ai.mk`,
> `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines you declare.
> **C25.2 matters to you most:** `Movement.drive`, `decide`, `build_situation`, the route tail, `_around_fire` and the
> two TacticalQuery functions run in C++ by default. A behaviour change in one of them needs native's port in the same
> merge. Decide seats, slots, legs, goals and gates in `game/tactics/**` / `formations.gd` / `squad.gd` where you can.

## The lead's direction (2026-10-10 ~05:45 PDT, playing main `77ad0e75`, the Crossing, seed 35967)

> *"The game is definitely way smoother. I played the game - I don't know if navigation go worse, but basically I click
> a point for my army to move to (across a bridge). Not[e] all of them make it to the other side. Vehicles are still
> going everywhere. I don't know how to correctly give feedback here because I don't understand enough of what's going
> on to diagnose. I could be wrong about what's happening, but trying to cross a bridge again, it looks like a lot of
> units had trouble / got stuck. This seems in part to be a function of trying to maintain formation (i.e. a wedge)
> while trying to cross a bridge. The formation is wider than the bridge, so since units are trying to maintain
> formation, they end up getting stuck crossing the bridge. IN another case, there appeared to be trouble crossing the
> bridge because it seemed like the formation alreayd had a pre-conceived notion of who the lead / point vehicle was
> supposed to be, and they were slowing down while a vehicle further back (the presumable point man) was trying to get
> to the front. All said, I don't know what the behavior is exactly, but in general squads trying to get into
> formation should determine whose position is whose based on who is already closest to the position in that
> formation."*

He says himself he may be wrong about the cause: **his symptoms are the facts, his diagnosis is a lead to check.**
Standing (memory *Smart AI on both sides*): the CPU's squads get the same behaviour; a symmetric improvement ships
without asking.

## Where things stand (the orchestrator's reading at `a497c1e1`; VERIFY it first, lessons 269/274)

- **The recording:** `streams/references/round25/his/2026-10-10T05-41-45-crossing.jsonl.gz` (+ `.perf`, `.booth.txt`).
  `make recording FILE=<that .gz> ORDERS=1` lists his orders (the reader takes `.gz` since `a497c1e1`+1); `UNIT=<name>`
  follows one crew. A first look: his squads mostly travel in **column** (the Guns from 45.6 s), a **wedge** at 43 s
  (Guns) and at 107.6 s (Eyes II, "bound forward behind suppressive fire"); at 107.6 s he splits the army into four
  moves (x5, x3, x3, x2). Find the moves that cross the bridge and read them crew by crew.
- **Seats today** (`game/tactics/tactics_formation.gd` `seat()`, ~line 680): a min-cost matching (Hungarian) with three
  rules above distance: (1) `leader` pinned to slot 0 (the point) when given; (2) toughness tiers onto exposed / front
  slots (`TIER_COST`, skipped under policy `"travel"`, a plain move); (3) `previous` kept unless a new seating saves
  `STABLE_MARGIN` × spacing; `"fixed": true` keeps it whatever it costs. `element.gd` has a re-seat with the leader
  unpinned (`_reseat`, `_unpinned`, `RESEAT_COOLDOWN_TICKS`, ~line 186–200). His "point man driving up from the back" is
  most likely rule (1) or (2), or a `previous`/`fixed` seating kept across a heading change. Name which from the trace.
- **The corridor fit exists and is OFF:** `fit_to_corridor` / `DEFORM_ENABLED := false` (A8, round 6). Read its comment
  block (~line 166–243): deforming the SLOTS paralysed the element because `ElementPlan._cohesive` gates the next leg on
  every member being near its slot; 0/5 arrived through the maze gap with it on, 4/5 off. Its own conclusion: the
  formation-through-a-choke intent belongs where legs/goals are chosen, with the gate, not in the slot layout alone.
- **Round 24 on the bridge:** CP1 (combat hops stop short of water, seats on the anchor's side and off bridge decks,
  `SlotGround.WET_ENABLED`) and R2 (squads ordered together keep one route). Those cases must stay fixed.
- **The give-way** (round 24 stretch b): ~+0.5 s of B1's +0.54 s on a plain move sits in Movement's give-way, and the
  bridge-mouth queue (crews finishing on the narrow quay) points at the same code. Movement's drive is in C++ (C25.2).
- Maps with a crossing: `crossing`, `crossing_dry`, `locks`, `locks_dry`, `pit`, `sumps`, `terminus_canal`,
  `archipelago` (verify from the arena JSONs).

## Backlog (in order)

**F0 — his crossing, counted.** From the recording: each move order that crosses the bridge, each crew in it, whether
and when it reached the far side, and for each that did not or was slow, the cause (stuck on a rail/edge, holding a
slot it cannot reach, waiting on a squadmate's seat, queued at the mouth, never routed over the bridge, fighting).
Then a headless scenario on the Crossing (and the same order on `locks`) that issues his move to a wedge squad and a
column squad from his start, and FAILS today on the count he would notice: crews across by t+N s, the time the last
crew clears, and a "point crew drove past ≥ 2 squadmates to its seat" count. Write the table in Status before any fix.

**F1 — seats by nearest (C25.5, DECLARED, CP1).** The nearest crew takes each spot: the leader is not pinned to the
point on a move; WHILE MOVING, toughness only as a swap that costs little driving (pick the threshold, write why);
ONCE THE SQUAD HALTS, the heavies take the front/outside spots (exposure) even when that is a longer drive (his
choice, 2026-10-10: *"yes option 2"*, `game_design.md` *Round 25: the launch* 1 amended; the halt re-seat must not fire
during a brief stop in a crossing or a give-way: define "halted" and write why), re-seat at
form-up and on a shape or heading change big enough that a new matching saves real driving (no swapping every tick:
keep the stability rule). Both sides. A unit test on `seat()` for each rule; F0's point-crew count to 0; the arrive
series and the paired series (C25.1). One commit, merged alone.

**F2 — through a crossing and open again (DECLARED, CP2).** A squad whose shape is wider than the crossing narrows or
goes to column at the mouth (in order of arrival, F1's nearest rule) and re-forms on the far side; no slot over water
or against a rail; the leg gate (`_cohesive` or its successor) agrees with the shape the squad is actually in, so it
never waits on a slot it took away (A8's paralysis). Design it before coding (a page in Status: where the corridor
width comes from, who decides narrow/open, how the gate follows); prefer `game/tactics/**`; if a ported function must
change, C25.2. Pass: F0's scenarios (every crew across, the last one inside a bound you set from a column's crossing
time), his bridge on every map with a crossing both sides, round 24's CP1/R2 cases, the maze defile.

**F3 — the bridge-mouth queue and the give-way.** After F2, measure whether crews still queue at the mouth or on the
quay; if the give-way is the cause (arm it on the same series), change it (C25.2: it is in the drive) or the order in
which the element feeds crews to the mouth. DECLARED if it moves crews.

**F4 — the overwatch bound stalls at one think timing in three (from the orchestrator, 2026-10-10; after F3).** The
squad overwatch scenario ("the overwatch element covers from cover + the bound makes progress") fails on main
`fccc520c` with NO rate change when every brain's first think is shifted (pace's measurement-only `--think-phase=1`, on
stream/pace at `53fdee00`+, `make pace-p0`): the bound stalls (commander z −13 v −60). Ruled a behaviour bug, not a
brittle line: the line stays; the fix is brains'. Not blocking CP1.

**Stretch:** (a) B1's +0.54 s on a plain move, the give-way share confirmed by removal (lesson: attribute a cost only by
removing it); (b) a nav guard in `make check` that runs a two-squad crossing on every crossing map in < 60 s.

## How to verify

`make remote T=check` (read the wrapper's `>> remote: make check exited <N>` and the runner's `N passed, M failed`, never
through a pipe). The AI scenarios (`mk/ai.mk`), the arrive series, the paired series (C25.1). Play the default path
(native ON): a behaviour behind a flag the default path never passes has not shipped. Screenshots or a top-down trace
of each crossing, looked at. Every number with its commit, machine, workload and n.

## Don't touch

Native's files and seams (`native/**`, `game/ai/native/**`, the `if BrainSwitches.native_*` lines, `avoidance.gd`,
`steering.gd`, `cover_map.gd`, `combat_motion.gd`, `brain_switches.gd` except one additive switch line), pace's
think-scheduling hunk in `tank_brain.gd` and its files, and the *Nobody this round* list in `workstreams.md` *Round 25*.
A pass line in an existing scenario is never loosened to make your change pass (C25.3).

## Waiting on the lead

Nothing. His decisions for this round are recorded (`game_design.md` *Round 25: the launch*); if F0 says his reading
was wrong, fix what the trace shows and write the difference for him in player terms.

## Status

_Updated 2026-10-10 by the brains worker (godot-brains, stream/brains)._

**Plan (in order):** F0 his crossing counted (recording + `make crossing-series`) → F1 seats by nearest (`seat()`,
the plain move's seats along its route, his option 2's halt re-seat; DECLARED, alone = CP1) → F2 the funnel (design page
below first) → F3 the mouth queue / give-way → stretch (a) B1 by removal, (b) the crossing nav guard.
**Baseline:** main `fccc520c` (+ the orchestrator's docs commit `f111176a`); `make remote T=check` started on it (builder0
busy: load 38, three checks and pace's series).

### F0: his crossing, counted (DONE; tooling `12e83585`)

**From his recording** (`references/round25/his/2026-10-10T05-41-45-crossing.jsonl.gz`, census 1 Hz; my reader:
per order, each crew's side of the river, when it crossed, its longest stall and where). Every order that crosses a
bridge, his side (all are plain right-click moves):

| order | squad, shape | crews across (s after the order) | the slow / missing crews, and why (from the trace) |
|---|---|---|---|
| 15.7 s → (80, −51), east bridge | Guns ×5, wedge | 4 of 5 by 25.3 s (16.3, 20.3, 22.3, 25.3); Guns_2 at ~28 s | **(a) the flanks parked beside the bridge mouth:** Guns_2 (right flank) stood on the quay EAST of the deck at (100–111, 3–18) for 8 s, Guns_1 (left flank) on the quay WEST of it at (68, 6) for 4 s, each then backed round onto the deck last. **(b) the back crew drove up:** Guns_4 started farthest back (36, 83) and crossed 2nd, past Guns_1 and Guns_2; Guns_1 stood 11 s at (50, 57–64) ("driving", not moving) while it did. |
| 65.5 s → (91, 62), east bridge north | Guns ×5, column | 5 of 5 in 8.5–18 s, in the order they stood | none: a column crosses clean (no stall over 1 s) |
| 107.6 s, four moves at once toward the west bridge | Guns ×5 column, Eyes II ×3 wedge, ×3 wedge, Eyes ×2 | **1 of 13** (Eyes II_6, 17.4 s) | **fighting, not navigation:** all 13 died 112–142 s on the north approach (z 14–48), the CPU holding the far landing (its objective (−76, −22)); Guns_1 also stood 7 s at the start, the column's tail waiting to fall in |

So his three symptoms are real and separate: (1) a wedge wider than the 14 m bridge leaves its flank crews parked on
the quay either side of the mouth (his "formation wider than the bridge"); (2) the seat at the point goes to a crew
behind its squadmates (his "point man"); (3) most of "not all of them make it across" was the army driving into a
defended bridge mouth one by one (a fight he lost there), not a crew stuck. (3) is out of this item's reach except
that a funnel (F2) crosses faster.

**The headless stage** (`tests/tactics/crossing_stage.gd`, `make crossing-series` / `crossing-trace`): his five Guns
at their 15.7 s census spots (±1.5 m jitter by seed), the same plain move, no enemy, wedge and column, his side and the
CPU's (mirrored through the centre), drills on (his attack-move's path), and the Locks with the same squad shape (R1's
quay → far quay). Fields: crews across and the last across, `point_passes` (squadmates the point crew starts behind
along the route by > 6 m), `seat_passes` (pairs the seating inverts), `overtakes` (pairs whose order along the route
really flips on the way), the longest stall and what held it, `wet_station_s` (the travelling shape put a station
over the water beside the deck). The trace (`CROSSING_TRACK`, 2 Hz) has each crew's seat, station, slot and phase.

**What the trace shows (laptop, `12e83585` code, wedge seed 1):** the wedge's right-rear crew's station rides the
route beside the deck, over the water; Element.ground moves it to the near quay at (104, 3), the crew drives there,
"arrives" beside the mouth at 13 s, sits 3 s, and backs round onto the deck at 16–19 s. Exactly his Guns_2. And the
point seat went to S_2, the crew standing at the BACK of the squad: a plain move seats against the final slots at the
click, 150 m away round a bend, so the crew nearest the click as the crow flies takes the point, whatever is in front
of it along the way.

(The F0 table of the headless series, both arms, is under F1.)

### F1: seats by nearest (in progress; DECLARED, CP1)

**Design (decided; reasons):**
- **One place, `TacticsFormation.seat`** (C25.5), both sides. When the crews have positions (they will drive): the
  nearest crew takes each seat. **The leader:** a plain move names none (round 10 already unpinned it there), so his
  right-click is nearest-for-all; a DRILL move (his attack-move, every CPU move) and the legacy Squad keep their named
  leader on the point. MEASURED (builder0, `ab045591`'s check: 6 failures; the same 4 test files with each part of F1
  switched back by a diagnostic: pin restored 33/33, strict tiers restored 27/6): the drill path's pursuit, round 24's
  Locks bridge (a crew 4.9 s at the rim), the leg advance and Squad's wedge are all laid off the leader leading from the
  point. So on drill moves his "point man" stays (known issue below; the fix is rebuilding those around the nearest
  seat, a bigger change than this item);
  toughness is a SHORT SWAP on the move, `SHORT_SWAP_M` = 8 m: the extreme swap (toughest crew in the most sheltered
  seat, most fragile in the most exposed) is worth exactly 8 m of the pair's driving, smaller tier differences
  proportionally less. Why 8 m: about one hull length (the Assault Gun's is 7.3 m): a heavy a hull behind a light
  slips past it to the front; a heavy at the back of the squad does not drive past its squadmates. **Halted**
  (`opts.halted`, or `opts.halt`, a halt drill's sectors): the old strict tiers (his option 2). A layout with no
  positions or teleported into place (`opts.layout`: ArmyLayout's deploy) keeps its old rule (pinned leader, strict tiers): nothing
  drives, so nothing is saved, and the thirteen dealt matches' spawns do not move for it. **A plain move (policy
  "travel") takes no swap at all**: tried, a short swap there sent a tank across an IFV's path on round 10's sideways
  move (`test_tactics_settle`), the driving-through-a-squadmate his rule is against; he allowed a short swap, he did not
  ask for one. So: plain move = nearest alone; drill move = nearest + the short swap; halted = strict tiers.
- **"Halted"** = the ELEMENT's state, never a crew's speed: a plain move whose element has stood on its spot for
  `HALT_RESEAT_TICKS` (2 s) seats once more, strictly by exposure, then the seating is fixed again (`Element.halt_seated`,
  once per task); a drill move's halt formation (`_halt`, firing lines, the herringbone) was already a halt. A crew
  stopped in a crossing or behind a squadmate is on a move: its element has not arrived, so nothing re-seats.
- **A plain move's seats along its route** (`ElementPlan.route_seats`): in transit the shape travels along the route,
  so each seat's place is its station there now (stations_along's geometry), and the crews are matched to those, not
  to the slots at the click. Matched by SQUARED distance (`SQUARED_ALONG_ROUTE`): when every crew stands behind every
  seat, the plain sum is the same for every order, and it gave the point to the crew standing out to the side
  (measured: the column's point_passes stayed 2 with the sum). Round 23's reason for the sum (two crews' straight
  paths to far seats crossing) does not arise: a travelling station starts where its crew stands and slides on.
  The final-slot seating (short moves, round 23's diagonal pair) keeps the sum.
- Re-seat moments: each new order (form-up), the halt re-seat; the stability rule (`STABLE_MARGIN`) stands. In
  transit the route frame makes the heading's turns irrelevant (the shape follows the road), so no mid-route re-seat.
- Switch `--seat-nearest=off` (TacticsFormation.NEAREST_ENABLED + ElementPlan.NEAREST_ON_ROUTE) = round 24's rule,
  the control arm.

### F2: the funnel — design page (written before coding, as the brief asks)

**The case it fixes:** F0's trace — a plain move's travelling shape lays every seat's station at its full width across
the route, so on a 14 m bridge the wedge's flank stations sit over the water; Element.ground moves each to the near
quay, and the flank crew parks beside the mouth until the shape's centre is across, then backs round onto the deck last.

1. **Where the corridor width comes from.** Once per plain move, when its travelling anchor is created
   (`Element._advance_transit`, the move's one impure step, beside the navmesh route): sample the route every 4 m and
   measure the standable width across the route's local tangent with `SlotGround._reach` (navmesh bisection, the
   measure A8's `corridor_width` uses; no navmesh over water, so on a deck it is the deck). Stored on the transit as
   CHOKES: `[s_in, s_out, width]` runs where the width is less than the shape's frontage plus a hull and a margin (the
   shape does not fit). Bridges, defiles and gaps all come out of the same measure; an open map has none and the
   transit is exactly round 24's.
2. **Who decides narrow / open: the travelling anchor, purely from its progress.** One FILE weight for the whole squad,
   0 = the formation, 1 = single file: it rises over FUNNEL_RAMP_M before the FRONT station reaches a choke's entry,
   holds at 1 while any part of the squad's file overlaps the choke, and falls over FUNNEL_RAMP_M once the TAIL has
   cleared the exit. One weight, so every station comes from one consistent shape (no crew half in a wedge and half in
   a column).
3. **The shape in the funnel.** Each seat's offset blends from the formation's toward its place in a file: lateral
   squeezed to what the corridor fits (to 0 when two hulls will not pass abreast), along to its file position. The
   file's order is the seats front to back (ties: the one nearer the route's centre line, then left) — after F1 that
   is the order the crews actually stand in, "in order of arrival". The file is FRONT-ALIGNED: its head stays where the
   formation's point was and the tail stretches back, so the lead crew keeps driving and the crews behind wait their
   turn at the mouth (their stations fall back to them; nobody is told to drive forward into the queue).
4. **The gate follows the shape it is in.** In transit the only gates are the anchor's lag rule (`_transit_pace`:
   crews BEHIND their station along the route) and B1's `form_pace` against `shape_along`; both read the stations
   `stations_along` produces, so they judge the file while the squad is a file (A8's paralysis was the LEG gate,
   `_cohesive`, judging deformed slots against the nominal shape; a plain move in transit does not use it). To check
   in the code: that a crew AHEAD of its station (the tail, waiting at the mouth) does not slow the anchor.
5. **Re-open on the far side** as the weight falls; the crews re-seat by F1's nearest rule along the route at that
   moment (a shape change), so a crew that came off the bridge first takes a front seat.
6. **Drill moves** (his attack-move, the CPU's moves) travel by legs, and R1 already keeps their seats off decks and
   water. v1 is the plain move; the drill path is measured in the same series (the `wedge+drills` case) and decided
   from that.
7. **No port needed:** all in `game/tactics/**` (the transit, the stations); `Movement.drive` and the ported functions
   are untouched (C25.2).

**Pass lines (pre-registered):** F0's scenarios with every crew across and the last one within the column's own
crossing time + 5 s (same seed, same side); `wet_station_s` 0 on every run; his bridge on every map with a crossing,
both sides (`make crossing-series` over crossing, locks, terminus_canal, sumps); round 24's CP1/R2 cases
(`make bridge-series`, `make body-series`) unmoved or better; the maze defile (`defile_probe`) not worse; the arrive
series and the paired series (C25.1).
