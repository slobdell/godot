# Stream: nav, round 13 (right-of-way sized for long hulls)

> Read [`navigation.md`](../navigation.md) (round 12's back-and-fill, N6, the drive test), the archived round-12 brief
> `archive/round12/nav.md` and its Status (the six-arm attribution, the rotation sweep, the recommendation this brief
> is built on), [`game_design.md`](../game_design.md) *Round 13 direction* (his answer 1 is *"I need clarification"*: the
> orchestrator's clarification is recorded there and this item starts on its recommendation; **his veto stands** — if
> he says stop, stop). **You own** what round 12's nav stream owned: `game/ai/movement.gd`, `pathing.gd`, `steering.gd`,
> `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`, `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`,
> `_agents/navigation.md`, `_agents/algorithms.md`.

## The lead's direction

Round 12's rig work was on the list he approved; his standing words: the rig stays 14 m; *"a 4s slower march for a
tidier traversal is better, yes."* Round 13: no new words on this item beyond *"I need clarification"*; the
clarification is in `game_design.md`.

## Where things stand (round 12's Status; verify on main)

- The back-and-fill + steering-guard fix + blockreach + N6 are on main (`c8e80f5b`; baseline `6313a38d7ecd99bb`).
  Rigs on the Terminus drive (builder0, 8 seeds): refusals 130 → 56, arrivals 104 → 115/128, press/unstick 227 → 83.
- **The declared cost:** rigs' reverse-gear wall contacts **+57 %** — *blockreach: rigs giving way back into walls with
  round 6's small-hull yield spots*. On `nav-fight-maps FIGHT_MAPS=rotation` (both arms, seed 3): stalled share fell on
  10 of 12 runs, wall contacts rose on 9 of 12 (~5–30 %). Same mechanism.
- Round 6's right-of-way (`avoidance.gd`, the yield/ask protocol) chooses a yield spot and a back-up distance sized for
  the hulls of the day (≤ 4 m); a 14 m rig with a 12 m turning radius cannot use most of them.
- Tools: `make nav-terminus-drive` (8+ seeds, both squads, arms from one build), `nav-fight-maps`, `nav-sim-arms`,
  `nav-rig-clip` (`RIG_YAW`), `nav-wall-clip`.

## Backlog (in order)

**R1. Where the rig backs into walls when it yields.** Instrument the yield: for every reverse-gear contact on the rig
drive, was the hull yielding (right-of-way) or executing a planned leg; for the yielding ones, the yield spot chosen,
the hull's length, the clearance behind, what it hit. Buckets, counts, in Status, before design.

**R2. Yield spots sized by hull.** The give-way rule takes the yielding hull's length and turning envelope: a spot is
valid only if the hull's swept reverse arc to it clears the navmesh with the TRAILING end (the same sweep the planned
reverse uses); when no spot fits, the long hull holds and the SHORT hull yields instead (the asymmetry a driver would
use), counted. Behind `--nav-off=<name>`; **name what it replaces** (the yield-spot choice, not the protocol).
Pre-register: rigs' reverse-gear contacts fall by most of the +57 %, arrivals and refusals do not regress, the mixed
squad is a null control, no stall regime (`wedged`) rises.

**R3. Measure like round 12:** the drive test 8+ seeds × both squads, both arms; `nav-fight-maps` on the rotation both
arms; the rig clip and the wall clip, looked at. Sim baseline: pre-register MOVED (the yield protocol runs in the
baseline match), attribute with `nav-sim-arms`, declare it; **CP1**, merged alone.

**R4 (stretch).** Whatever R1's buckets name that R2 does not cover.

## How to verify

`make remote T=check`; every number with commit, machine, seeds, arm; the clips.

## Don't touch

`game/tactics/**`, `game/ai/{squad,tank_brain,formations}.gd` (squad's); `game/units/units.gd`; `game/arena/**`.

## Waiting on the lead

His clarification answer, if it changes the item; nothing blocks R1.

## Status

_(the worker keeps this current)_
