# Stream: squad, round 13 (the default plain-move shape is the wedge; S6 measured)

> Read [`game_design.md`](../game_design.md) *Round 13 direction* (his answers; verbatim) and *Round 12: the lead's
> verdicts as they land*; [`doctrine.md`](../doctrine.md) (round 12's S5 section and *A plain move travels AS a
> formation*); the archived round-12 brief `archive/round12/squad.md` (its Status is the round's record: what S5
> measured, the terrain correction, the S6 candidate's pre-registered signature). **You own** what round 12's squad
> stream owned: `game/tactics/**`, `game/ai/{formations,squad,squad_tactics,tank_brain,element_feed,directives}.gd`,
> `doctrines/`, `mk/tactics.mk`, `tools/tactics/**`, `tests/test_tactics_*.gd`, `tests/tactics/`, `tests/ai_scenarios/`,
> `_agents/{doctrine,tank_brain,squad_ai_design}.md`; the round-12 carve-outs (`game/ui/command_icons.gd`,
> `game/ui/selection_panel.gd`) only if the icon's label needs the new default.

## The lead's direction (2026-09-27)

Answer 2: *"Default wedge."* Answer 3, on S6: *"I don't understand the question"* — so it is measured, not asked again.
Answer 4: the partial selection stays (*"leave"*). Standing: *"a 4s slower march for a tidier traversal is better, yes."*

## Where things stand (round 12's Status, verify)

- S5 (`161465ef`, builder0, 4 seeds × 8 cells, same seeds): the wedge settles faster in 23 of 32 paired runs and its
  first-10-s station error is lower in 7 of 8 cells (yard forward mixed 16.0 → 9.1 m); the column wins only the yard's
  forward move through the chokepoint and looks tidier in a Terminus street. The row was kept as column pending him.
- No squad he fields uses `doctrine_standard.json`; the Condemned and Law tables' plain-move catch-alls pick a
  **column in any terrain**. `make tactics-terrain` classifies the yard's spawns as dense, the Terminus as lanes.
- S6 candidate (pre-registered in the round-12 Status with its signature): after arrival, wheeled fixed-gun scouts get an
  idle `face` with nothing in sight; nav's N6 (`c8e80f5b`, on main) bounds the multi-point turn's drift (mixed stop time
  18.9 → 12.1 s on the laptop). Squad's half: do not issue the face at all when nothing is in sight.
- Tools: `make squad-shape-series` (column vs wedge, paired), `squad-transit-series`, `squad-settle
  UNITS=scout:scout:ifv:ifv:tank`, `make remote T=formation-shots`, `tactics-test`.

## Backlog (in order)

**Q1. The wedge is the default plain-move shape.** Change the faction tables' plain-move rows (`doctrines/doctrine_*.json`,
and `doctrine_standard.json` for parity) so a plain move on `open` and `lanes` forms a **wedge**; for `dense`, run the
paired series once more on the same seeds with the round-12 tooling and keep `column` there ONLY if it still wins
(the yard's chokepoint was the one cell) — otherwise wedge everywhere, and say which. The reason goes in the table's
`why` so the card reads "wedge (default)". Tests: the doctrine-table coverage test, and a test that a Condemned plain
move on the Terminus at t = 10 s is a wedge. Frames at his pose: yard and Terminus, before/after. The CPU's tasks run
drills and never take the plain-move path — pre-register the sim baseline UNMOVED and check it.

**Q2. S6, measured.** Behind a switch: `TankBrain` does not issue an idle `face` to a no-pivot (wheeled, fixed-gun) hull
when no enemy is in sight after arrival. Measure with `make squad-settle UNITS=scout:scout:ifv:ifv:tank` both arms, same
seeds, 8 seeds, on the tree WITH nav's N6 (main): stop time, worst off-slot, and whether any drill or hold that needs the
facing (an ambush's facing, a hold's `facing`) is unchanged — those carry an explicit facing and must not be touched.
CPU scouts face too, so **pre-register the sim baseline MOVED** and attribute it (both arms); the orchestrator records
it if it lands. Ship ON only if the numbers say so; otherwise OFF with the write-up.

## How to verify

`make remote T=check` green on every named commit; the series on builder0 with commit and machine; `make remote
T=formation-shots`; look at the frames. Declare any baseline move.

## Don't touch

`game/ai/movement.gd` and nav's other files; `game/control/**` beyond the two carve-outs; `game/audio/**`, `game/garage/**`.

## Waiting on the lead

Nothing; his answers are in.

## Status

_Worker, 2026-09-27. Every number carries its commit and machine._

### Plan (ordered; smallest foundation first)

1. Green start: `make remote T=check` on `8f96a43c` (builder0).
2. **Q1 tests first:** the plain-move rows (open/lanes → wedge, the `why` reads "wedge (default)") in
   `test_tactics_doctrine.gd`; the Condemned plain move on the Terminus at t = 10 s is a wedge
   (`test_tactics_formation_readout.gd`, which pinned "column" in round 12).
3. **Q1 dense, pre-registered BEFORE the run:** `make remote T=squad-shape-series` (seeds 1–4, the round-12 tooling, the
   same 8 cells) on the current tree. The yard is the dense map. **The column is kept for `dense` only if, over the 16
   paired yard runs, it stops first in MORE than half (≥ 9) AND its median first-10-s station error is lower in at least
   2 of the 4 yard cells**; otherwise wedge in every terrain. (Round 12 at `161465ef`: column first in 6 of 16 yard
   runs, gap10 lower in 0 of 4 — so wedge-everywhere is expected.)
4. Q1 build: the Condemned, Law and standard plain-move catch-alls → wedge (Gangs swarm and Syndicate wedge are
   already not a column; untouched). The plain move's card line carries the table's reason so it reads "wedge
   (default)" (`ElementPlan._plan_form_up` overwrote the table's `why` with "moving as ordered: travelling in X").
   **Sim baseline pre-registered UNMOVED** (the brief's claim). Caveat written down before the run: CPU elements are
   given `move` tasks (`ElementCommander`, `ArmyPlan`), which also reach the catch-all with nothing in sight, so if the
   hash moves the cause is a CPU Condemned/Law move changing shape; I will attribute it, not adopt it silently.
5. Q1 frames: `make remote T=formation-shots` before (column, AUTO) / after (wedge) at his pose, yard and Terminus.
6. **Q2:** `TankBrain.IDLE_FACE_NO_PIVOT` switch; `--idle-face=on|off` in the settle probe; a
   `squad-idleface-series` (8 seeds, both arms, the mixed squad). **Sim baseline pre-registered MOVED** (scout and
   gang_scout are in the baseline match: wheeled, fixed gun). Ship ON only on the numbers.

### Decisions

- The plain-move rows changed are the tables' catch-alls (the row a plain move with nothing in sight reaches); the
  `possible`/`likely` rows (Law's `possible + dense → column`, standard's `likely + dense → column`) are contact
  doctrine, not the plain-move default, and stay.
