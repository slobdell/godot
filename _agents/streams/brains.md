# Stream: brains (a squad forms up on the move; the computer's opening lets it be ahead; the transit never sends a crew away from the click)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 18 direction* (*His pick*),
> *Round 19 direction* (item 2) and *Round 20 direction*, `_agents/doctrine.md`, `_agents/navigation.md`,
> `_agents/workstreams.md` *Round 20*, and round 19's final reports: yours (`streams/archive/round19/brains.md`
> Status: the four known limits, the series) and orders' (`streams/archive/round19/orders.md` Status: the three
> requests to you, the probe `make two-squads-playtest`). You own `game/ai/**`, `game/tactics/**`,
> `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`,
> `tests/test_nav*.gd`, `mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`, `doctrines/doctrine_*.json`, the baseline lines you
> declare. Orders' probe files (`game/control/two_squads_playtest.gd`, `tests/test_control_two_squads.gd`) are
> READ-ONLY instruments for you; a change to them is a request.

## The lead's direction (standing)

> *"Yes make the CPU smarter, this would apply to all units… our friendly players are just as smart"* (2026-10-04).
> On round 19's main: *"ok this is much better."* (2026-10-06). Nothing new from him for your paths this round: the
> items below are round 20 candidates 1 and 2, launched on his standing rule because they are what he sees when he
> orders a squad and when he crosses the floor.

## Where things stand (read at `c355a41e`; your own numbers)

- **The form-up stray (candidate 2):** a travelled move forms the shape around the travelling anchor at the spawn and
  then moves (round 12's transit design): orders measured crews 12–20 m off a straight line in the first 5 s and a
  Sumps straggler driving 17.7 m AWAY from the click to its seat before its squad moved off; your option (b) (tie-break
  by travel within a role) changed nothing (12.1 → 12.1, 20.0 → 20.0, 13.6 → 13.3 m) and was reverted. The fix you
  named: form up on the move, stations that start where the crews stand and converge on the shape over the first leg.
- **The computer's opening (your limit 2):** it attacks first, turns to HOLD only when its zone is threatened (an enemy
  33–35 m off), and by then its line is in contact, where the commander refuses an ambush; in his frame it took 0
  ambushes (in-contact refusals 148 / no-site 11 / late 18 on parade). The bay ambush fires only when the CPU is
  ahead before he arrives (8 of 8 in that stage). The price in his frame: +5.1 ms a tick mean, +3.4 median, sd 4.5
  (23 bins). CPU elements OFF on his path; his switch `make skirmish ARENA=parade CPU_LEADERS=1`. **His answer on the
  default is pending**; nothing here changes the default.
- Your other limits: the ambush spot hides one point, not the line; the hold costs vehicles in the 8-v-4 stage
  (−1.4 ± 1.2 alive per pair).
- Thirteen baseline lines; C19.3's rule (declared, alone, adopted) carries as C20.2.

## Decided by the orchestrator (each reversible; record a reason if you overturn one)

- **Form up on the move is the round's centre.** A travelled move starts every crew toward the click at once; the
  stations begin where the crews stand and converge on the formation over the first leg (or by a distance, say the
  formation's depth), so no crew drives away from the click and no squad shuffles before it sets off. Both sides.
  The acceptance is orders' probe: worst off-line distance in the first 5 s and worst "away from the click", before
  and after, three selection shapes, parade and the Sumps; and the arrive series (100 of 100) unchanged.
- **The opening:** a CPU that spawns nearer a ring than the enemy does takes it first and HOLDS from the start when
  the map gives it a bay or a flank site (parade, the Open Yard), rather than racing to the centre and turning only
  when threatened; otherwise it attacks as today. Declared; a paired series on parade and the Sumps (ambushes taken,
  sprung, the outcome per seed with its spread); the price re-measured only if the tick's work changes (ask for a
  quiet window through the orchestrator).
- **The ambush hides the line, not a point** (your limit 1): the site search tests every slot of the element's
  formation at the site, or the element takes a coil / column that fits what the site hides. Stretch if the first
  two take the night.

## Backlog (in order)

- **M1. Form up on the move.** The transit's stations start at the crews and converge; the probe before/after
  (`make two-squads-playtest`, three shapes, two maps); `tests/tactics/` scenario for a line and a wedge from a
  spawn row; the arrive series on one tree. Declared; pre-registered where it moves (every map's CPU armies travel).
- **M2. The opening posture** as decided, with the series and the refusal census.
- **M3. The ambush hides the line** (stretch if time is short).
- **M4. The guard tests and the stray numbers in `_agents/doctrine.md`** (a short section: how a squad travels now,
  with the numbers), and `navigation.md` if the transit's routing changed.
- **Stretch.** (a) The hold's vehicle cost in the 8-v-4 stage: can the holding element fall back one bound when it
  is losing the trade? (b) The CPU's squad leaders' price: the next equal-answer cut, if the profiler shows one.

## How to verify

`make remote T=check` green on every commit you report. **Every change to fights is DECLARED, merged alone, lines
adopted with `make sim-baseline-adopt` and named in the commit; everything else pre-registers UNMOVED** (C20.2).
Scenario or probe first; a paired series with its spread for anything that changes who wins (lesson 256); laptop
series only in a quiet window asked for through the orchestrator (lesson 260); the arrive series is part of green for
a movement change (lesson 261). Every number: commit, machine, workload, N, spread.

## Don't touch

`game/control/**`, `game/ui/**` (orders' and board's, closed; the probe is read-only for you) · `game/garage/**`,
`game/progression/**`, `game/units/**` (garage) · `game/match/**` (read; a signal is a request) · `arenas/**`,
`game/arena/**` · `mk/core.mk`, `tests/baselines/**` except declared lines · balance values (C12.6) · the elements
flag's default on his path (his).

## Waiting on the lead

- **CPU squad leaders on by default** (asked with the price; nothing here depends on it).

## Status

(the worker keeps this current)
