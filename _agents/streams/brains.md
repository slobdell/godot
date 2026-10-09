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

_Not started. The worker keeps this current: plan, baseline, per-item results with commit/machine/n, "GREEN, merge
here: <sha>", questions for the lead, requests to other streams, known issues, what to playtest, merge notes._
