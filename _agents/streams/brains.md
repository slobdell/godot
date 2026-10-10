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

_(the worker keeps this current: plan, F0's table, each item's green commit, measurements with commit/machine/n,
questions for the lead, requests to other streams, merge notes)_
