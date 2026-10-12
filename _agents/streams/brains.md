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

_Not started._
