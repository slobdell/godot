# Stream: brains (an arrival means every crew arrived; a crew blocked by a parked squadmate gets a seat; flank attacks)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* and *Round 27
> direction*, `_agents/doctrine.md`, `_agents/workstreams.md` *Round 27* (C27.1–C27.6), and round 26's brains report
> (`streams/archive/round26/brains.md`, **FINAL REPORT** and its round-27 rows: your backlog's source). You own
> `game/ai/**` EXCEPT scout's, orders' and native's carve-outs (C27 ownership list: notably `combat_motion.gd` and the
> fight-motion hunk of `tank_brain.gd` are scout's this round), `game/tactics/**`, `tests/ai_scenarios/**` (others add
> their own `scenario_<stream>*.gd` and one registration line each), `tests/tactics/**`, `tests/nav/**`,
> `tests/test_ai*.gd` (except `test_ai_combat_motion.gd`), `tests/test_tactics*.gd`, `tests/test_nav*.gd`,
> `tests/test_form_up.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`.
> **The C++ freeze (C27.2):** native is moving the execute step into C++. Think-side code (elements, tactics, `tank_brain`'s
> situation/decide/act, squads) is NOT frozen; the drive (`movement.gd`'s drive and its callbacks), `gunnery.gd`,
> `order_controller.gd`'s execute path, `steering.gd`, `avoidance.gd` are. `decide` and `build_situation`'s core run in
> C++: a change there goes to native as a diff before your commit, merged as a pair.

## The lead's direction

Round 26's (still his): squads that arrive together and fight as squads; his bridge drill (passes now: keep it).
Round 27 adds no new words for you; your items are round 26's carry-overs, which are his round-26 complaints not yet
fully fixed, plus the flank attack that makes his armed-order gesture complete (orders, C27.3).

## Where things stand (main `04845af7`; check green at `090b345d`, builder0, 2464/0)

- **The Sumps arrive cell:** a TRACKED law_ifv presses a squadmate parked on its station; make-room never fires because
  `Element._watch_progress` resets its 4 s not-closing clock on every sub-1 m/s dip. The clock pause (lab branch
  `lab/brains-mr2`, `26b94aa6`) turns "never" into 52 s — but HOLLOW: the re-seat hands the parked crew a far seat and
  it ends 19–26 m off while the element reads arrived (lesson 293).
- **The arrive line counts the element, not every crew** — two of round 26's "arrivals" were hollow.
- **Make-room has no falsifier on main** (traffic's CP1a freed the corner it was tested on): price it by removal.
- **B2 drill seats by nearest** (paired at `fe45a510`): nearest 4/3 fight tests v pinned 7/0 — pursuit lets go at 7.5 s,
  the bay ambush springs early (x 55.7 at 12.1 s v 64.6 at 15.5 s), the Sumps two-scout squad 26.1 v 20.4 s.
- **Ambush's guns sit at a flat 30° off the drawn facing** in every run (orders' facing probe, round 26).
- The rig carrot (`lab/brains-carrot`, `f082af36`) is a drive-side rule: frozen this round; leave it parked.

## Backlog (in order)

**B0 — CP0: an attack task honours a drawn approach (C27.3), small, first.** When `task["approach"]` is present (a
normalised `[x, z]`: the direction the squad comes FROM, toward the target), the attack's plan sets up on that side of
the target and goes in from it; absent = today's code path, byte-identical (thirteen lines and determinism unmoved).
A unit test per verb, a TacticsLab stage showing the approach side honoured (n stated). Merge as CP0 (not declared: the
default path is unchanged); the orchestrator tells orders to merge main.

**B1 — the arrive line counts every crew.** An arrival = every living crew inside its settle radius of its own slot
(tooling first, with a mutation check: a crew 20 m off must fail it). Re-run the arrive series and the Sumps cell under
it on main; report which existing passes were hollow. This is the instrument for B2–B4.

**B2 — the crew pressing a parked squadmate gets a seat around it.** Start from `lab/brains-mr2`'s clock pause; the
re-seat seats the blocked crew around the parked one (the parked crew keeps its seat). Acceptance: the Sumps cell
arrives under B1's line; the bridge 108 and `bridge-pooled` unmoved. DECLARED (C27.1).

**B3 — make-room priced by removal** under B1's line (lesson: attribute a cost to a behaviour only by removing it): with
and without, the arrive series and the Sumps cell, n stated. Keep it, retire it, or give it a stage that needs it.

**B4 — drill seats by nearest that keep the lead crew's role.** Nearest seats, but the crew with the role (the lead in
a pursuit, the ambush's trigger, the two-scout squad's pair) keeps it. Guards: round 26's paired table (pursuit, bay
ambush, Sumps two-scout) must pass in both arms; his bridge drill. DECLARED.

**B5 — ambush guns on the drawn facing**, not 30° off: trace where the offset comes from (lay, slot, or the line's
geometry) and fix it on the think side; if it is gunnery's lay, it is a request to native (frozen).

**B6 — stretch:** the street-funnel trade stays his call (held); F6 only with a new reason.

## How to verify

`make remote T=check` (builder0 only, C27.6); `make bridge-pooled` (in check) and the 108 for declared changes; the
arrive series; TacticsLab stages pooled over start ticks {1,3,6,8,11,16} (C27.5); the thirteen lines and determinism.
A pass line changes only with its reason written and the orchestrator's approval (C27.5).

## Don't touch

Scout's `combat_motion.gd` and `tank_brain.gd`'s fight-motion hunk (`_combat_move`, `_hold_motion_plan`, the ORBIT
controller); native's frozen execute files (C27.2) and `native/**`; orders' `game/control/**`.

## Waiting on the lead

Nothing.

## Status

**Plan (2026-10-11, in order):** B0 (attack honours `approach`; CP0 → orders) → B1 (the every-crew arrive line, tooling
+ mutation check, re-read the arrive series and the Sumps cell) → B2 (re-seat round the parked crew, from
`lab/brains-mr2`; DECLARED) → B3 (make-room priced by removal under B1's line) → B4 (drill seats by nearest keeping the
lead's role; DECLARED) → B5 (ambush guns 30° off: trace first) → B6 held.

**B0 — DONE. CP0 GREEN, merge here: `9603c1d7`** (builder0, `make check exited 0`, 2475 passed / 0 failed = main's
2464 + B0's 11; thirteen UNMOVED; determinism `2875411ff4ec6be7` unchanged; 2 NOT JUDGED for the busy box only:
perf-judge refused ×3 at ratio ~2.4, scenario_perf unpinned). Told the orchestrator 2026-10-11 ~19:50; orders confirmed
the sign (approach = enemy − release point, the run in). `task["approach"] = [x, z]` (attack only; validated; the
direction of the run IN, toward the target, as orders' brief reads it). Design (decided, one line each): the attack
drives ROUND the target at its crews' longest reach (`range`, 70 m for a tank; at 45 m effective it drove inside the
target's guns) in 45° notches, each at least 15° ahead (fixed points, so crews are not re-sent every update; a notch
it had to land on exactly stalled the squad 6° short for 25 s), until its centre is within 30° of the drawn side; then
it is "in" for the life of the task and attacks as before. The way round is the shorter one, kept once chosen. On the
way the crews are on a NAMED MOVE (guns laid on the target, shooting on the move); react to contact, far ambush and a
near ambush on the target itself yield until it is round (each sends crews straight in from the wrong side). A running
target is a pursuit and has no side. Absent = today's path (the plan writes `approach_round` only when the key is there;
`Drills.rounding_to_approach` reads false for every other task).
- Tests: `tests/test_tactics_approach.gd` (9, plan level: validation per verb, on-side identical to no approach, far
  side goes round at reach, notches, kept way, latched in, line in reach, pursuit unchanged),
  `tests/test_tactics_approach_live.gd` (2, a real match, both arms). builder0: 11 passed / 0.
- Stage `make approach-series` (`ApproachStage`: his four tanks 100 m south of two enemy tanks on yard_open, a hold-fire
  scout spotting; attack one from the EAST v no approach), builder0, tree `c37605f0` + B0, n = 18 per arm (seeds 1–3 ×
  start ticks {1,3,6,8,11,16}): **east 18/18 closed in from within 35° of the east side** (median 27°, worst 30°),
  control 0/18 (median 88°: straight up from the south). Cost of the drive round: target killed 18.9 s v 14.5 s
  (medians), his crews alive 3.61 v 3.11 (mean).
- CP0 is NOT declared (default path unchanged). Merge note: touches `element_task.gd`, `element_plan.gd`,
  `element.gd`, `drills.gd` (all mine), `mk/tactics.mk` (+ approach-series), new tests and `tools/tactics/approach_table.py`.

**Candidates noted (not preempting B0–B4):** scout's census (main `c37605f0`, builder0, 12 showmatch seeds): 254 of 365
enemy hull contacts came while the crew was on an ordered MOVE (squads, the CPU's included, moved into the enemy outside
CombatMotion): an arrive point inside the enemy, or an attack-move that does not stand off. Seeds/ticks in scout's Status.
