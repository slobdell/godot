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

**F1b — seats by nearest on drill moves too (the real fix; after F2).** F1 keeps a drill move's leader pinned to the
point because its machinery is laid off the leader: the legacy Squad lays every slot as an offset from its commander's
CURRENT position (`squad.gd` ~373: `to_world(lead.global_position, heading, offsets[index])`, so a commander off slot 0
puts the whole shape in the wrong place); the element drill path's pursuit, round 24's Locks case and the leg advance
broke the same way with it unpinned (mechanism not yet traced: trace first). The pin is a WORKAROUND. None of his
crossing orders take that path (below); his attack-moves do, and the CPU's moves do.

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

**F0's table, the headless series** (laptop, code `017e1184` with `--seat-nearest=off` = round 24's seating, which
reproduces the 11 runs taken before the change exactly; 3 seeds a case; no enemy):

| case | point crew started behind (per seed) | real overtakes | last across (mean s) | what else |
|---|---|---|---|---|
| Crossing wedge, his side | 2, 0, 2 | 2, 1, 2 | 21.9 | flank stations on the rim beside the deck 7–9 s each (seed 1, 23.7 crew-s) |
| Crossing column, his side | 2, 2, 2 | 5, 3, 6 | 19.0 | |
| Crossing wedge, CPU side | 2, 2, 0 | 2, 2, 1 | 19.9 | |
| Crossing column, CPU side | 2, 2, 2 | 4, 6, 3 | 20.5 | |
| Crossing wedge, drills (his attack-move), his side | 2, 2, 2 | 0 | 19.8 | element arrived 65.7 s / never / 55.3 s; 1–3 fresh seatings |
| Crossing wedge, drills, CPU side | 2, 2, 2 | 0 | 22.6 | element never arrived in 90 s (3/3); 3 fresh seatings each |
| Locks wedge / column | 1, 1, 1 / 1, 1, 1 | 0 / 1–2 | 15.8 / 19.0 | |
| Locks wedge, drills | 0, 0, 0 | 0–1 | 38.1 (2 of 3 all across) | **one crew never crossed** (74.6 s on the north quay at (−38, 13)); 13 s and 19 s there on the other seeds |

It FAILS today on what he would notice: the point crew comes from behind in 23 of 27 runs; a column reshuffles on the
way; a drill move's squad never settles; on the Locks one crew in three runs never crosses.

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
  the control arm (the settle, bridge, body and pursuit probes take it too).

**CP1: GREEN, merge here: `6bb01c44`** (F1 alone; DECLARED): builder0, `make check exited 0`, **2348 passed, 0 failed**,
thirteen UNMOVED, determinism `762a0576f944f5b7` (`references/round25/brains/check-6bb01c44.log`). It is `2c141b0c` with
the drill move's short swap turned OFF by measurement: `2c141b0c`'s paired series (builder0) had the pursuit (16 paired)
and his Locks bridge cases (24 paired) identical in both arms, his three-squad move (R2) at 12.1 → 16.8 squad-s alone on
his side and 15.9 → 16.5 on the CPU's (inside round 24's fixed 6.5–23.5; 42–102 before R2), but the DRILL move's
arrive series +0.85 s (se 0.41) with one squad of 100 never arriving (the Sumps, mixed, three fresh seatings; 36.8 s
without F1). The short swap was F1's only change on the drill path, so F1 = the PLAIN move only (seats along the route
by nearest + the halt re-seat); the drill path's seating is F1b. (Superseded record below.)

**(Superseded) `2c141b0c`** (F1 alone; DECLARED). builder0, `make check exited 0`, **2348 passed, 0 failed**,
the thirteen sim-baseline lines UNMOVED, determinism `762a0576f944f5b7` (log `check-2c141b0c.log` in my scratchpad;
the copy goes to `references/round25/brains/`). **Arrive series, the plain move** (builder0, `ab045591` = the same plain
path, 5 maps × 5 squads × 4 seeds, paired by `--seat-nearest=on|off`): 100/100 arrive in both arms, no re-seats or swaps;
on − off −0.13 s (se 0.20, median 0, 60 of 100 identical): neutral. The rest of C25.1's paired series (the drill move's
arrive series, his bridge cases, his three-squad case, the pursuit, F0's stage at n = 4) run on `2c141b0c` and land
below. **Merge note:** the mechanism I am sure of for the drill-move pin: the legacy Squad lays every slot as an offset
from its commander's current position (`squad.gd` ~373), so a commander off slot 0 shifts its whole shape; the element
drill path's cause is not traced yet (F1b). Control's `GroupFormation.slots` gets the nearest rule through `seat()`
(file unchanged).

**Which of his orders take which path (`rts_controls.gd:682`):** a right-click `move` is `drills: false`, the plain
move (the task text "moving as ordered, travelling: <the table row>" is the plain path's own words, `_plan_form_up`):
every crossing order in his recording (15.7, 43.0, 49.3, 59.3, 65.5, 107.6 s) is one. Only his `attack` (53.7 s) and
`attack_move` (94.9 s) run drills, and neither crossed a bridge. So F1 covers his complaint; the drill path is F1b.

**Candidate (superseded): `ab045591`** (= `017e1184` F1 + the pursuit probe's arm). Tests: `tests/test_tactics_seat_nearest.gd` (one per
rule: nearest + leader unpinned, the short swap, halted strict, a layout unchanged, the stability rule, `at`, seats
along the route, the plain move's halt re-seat once), `tests/test_tactics_crossing.gd` (his wedge and the CPU's column
on the Crossing: point_passes 0, every crew across), `test_formation_slots` updated (a layout pins; a driver does not).

**F0's series with F1 ON** (laptop, `017e1184`, same seeds):

| case | point crew behind | overtakes | last across (mean s) off → on | element arrived (s) off → on |
|---|---|---|---|---|
| Crossing wedge, his side | 0, 0, 0 | 0, 0, 0 | 21.9 → 19.7 | |
| Crossing column, his side | 0, 0, 0 | 1, 0, 0 | 19.0 → 13.8 | |
| Crossing wedge, CPU side | 0, 0, 0 | 0, 0, 0 | 19.9 → 22.0 | |
| Crossing column, CPU side | 0, 0, 0 | 0, 0, 0 | 20.5 → 15.0 | |
| Crossing drills, his side | 0, 0, 2 | 0 | 19.8 → 21.2 | 65.7 / never / 55.3 → 51.7 / 44.0 / 57.8 |
| Crossing drills, CPU side | 0, 2, 0 | 0 | 22.6 → 20.0 | never ×3 → 67.0 / never / never |
| Locks wedge / column | 0 / 0 | 1–2 / 1–2 | 15.8 / 19.0 → 15.0 / 15.7 | |
| Locks drills | 1, 1, 1 | 3 | 2 of 3 all across → 3 of 3 (mean 46.8 s) | stall on the quay at (−36, 12): 74.6 / 13 / 19 → 14.6 / 28.4 / 41.5 s |

The Locks drill stall is at the same spot in both arms (a drill-move problem on that quay, before F1; F2/F3 look at it).
The crossing-drill CPU side still often never "arrives": also both arms (F3).

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

### F2: what the funnel became (built against the design page above; measured changes to it)

- **Only a choke whose LANES do not fit counts** (`ElementPlan.funnel`): the Crossing's streets read 33–48 m against a
  48 m wedge, and squeezing for each flicked the shape between targets on the way; there the shape keeps round 24's
  behaviour. A choke is a run of profile samples narrower than the shape's lanes need abreast (lanes × (hull + 3 m)).
- **As many lanes as the choke holds** (the orchestrator's ruling after the first table): `k = floor(room / (hull + 3 m))
  + 1`; k = 1 is the file. Lanes as close as hulls pass, about the corridor's middle (spread to its edges they put the
  Sumps catwalk's outer lane on the pit's rim). The Locks' and the Terminus' bridges hold two and three.
- **The file in order of ARRIVAL** (`Element._rank_file` / `ElementPlan.file_ranks`): fixed once per choke when the
  narrowing starts, by how far along the route each crew stands. Seat order first: on the Sumps a back-wing crew
  reached the catwalk first, was told to drop behind a squadmate, yielded, and the squadmate pressed the pit's rim
  trying to get past it for 3.5 s (trace, laptop).
- **The corridor's middle**, not the route's edge: a shortest path hugs one side of a deck (the Crossing's east deck:
  the route at x 87–88, the corridor's middle 4 m right of it), applied only around the choke, tapered over 30 m.
- **Two chokes at once** (a squad starting by a crossing): the narrower wins at equal pull.
- The meter: `wet_station_s` counts the shape's own stations (recomputed before grounding) in the water OR on its rim
  beside a deck: the arena's clamp pulls a station laid over the water back to the rim, which is where the flank crews
  parked.
