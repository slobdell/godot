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

_Worker: nav, round 13. Started 2026-09-27 from `8f96a43c`. Every number names its commit and machine._

### Plan (the brief's order)

| # | item | state |
|---|---|---|
| 0 | green start: `make remote T=check` on `8f96a43c` | **green**: builder0, `make check exited 0`, 18 targets, 1773 passed / 0 failed, sim-baseline `6313a38d7ecd99bb` unmoved, determinism `550d53790035ddb4` |
| R1 | instrument the give-way; buckets before design | **done** `5866e387` (below); round-11 arm's buckets running |
| R2 | yield spots sized by hull (`--nav-off=yieldfit`) | next |
| R3 | drive 8 seeds x 2, fight-maps rotation both arms, clips, `nav-sim-arms`, CP1 | — |
| R4 | whatever R1 names that R2 does not cover | — |

### R1: where the rig backs into walls when it gives way (builder0, `5866e387`, `make nav-yield-buckets`, 8 seeds x 2 squads, default path)

The instrument (`--yield-log`, measurement only; `tests/nav/test_nav_yield_log.gd`): every give-way logs the spot it
chose (round 6's `spot(along,across)` table, or the straight `back(m)` last resort), the hull (length, radius), the
room behind its tail, and whether the straight run to the spot keeps the WHOLE outline inside the clear reach (the
sweep the planned reverse validates with); WallContact adds the contacts made while giving way by gear, collider and
end, and a `driver/gear` cross-tab. The run's totals reproduce round 12's HEAD exactly (rigs 5715 contacts / 1488
reverse-gear; mixed 2660 / 284): the instrument moves nothing.

**Rigs' 1488 reverse-gear contact ticks by the layer driving:** `yield` **661 (44 %)**, `route` 559 (38 %), `kturn`
226 (15 %), `press` 42. Every one of the 81 give-ways is a 14 m rig for a 14 m rig; only 27 reached their spot.

| gear to the spot | spot | the straight run's outline sweep | give-ways | contact ticks | reverse-gear | reached |
|---|---|---|---|---|---|---|
| forward | table | nose_corner leaves the clear reach | 12 | 638 | **251** | 5 |
| reverse | `back(6)` | rear_corner (median room behind the tail **2.5 m**) | 5 | 325 | **213** | 0 |
| reverse | table | clear | 22 | 81 | 65 | 2 |
| reverse | table | rear_corner | 6 | 72 | 44 | 1 |
| forward | table | side_fore / side_aft | 5 | 369 | 54 | 1 |
| reverse | table | nose_corner | 2 | 19 | 19 | 1 |
| reverse | `back(6)` | clear | 6 | 35 | 10 | 3 |
| forward | table | clear | 16 | 54 | 1 | 12 |
| (4 more buckets) | | | 7 | 129 | 4 | 5 |

**What it says:** **585 of the 661 (89 %)** yield reverse-gear contacts are give-ways whose run to the spot the
outline sweep would have refused; the spot's centre was on the mesh (`_free_spot`), the hull's ends were not. The
largest single mechanism is round 7's last resort `back(6)`: 6 m straight back from a CENTRE 7 m from the tail, i.e. a
point inside the hull's own footprint, so the centre check passes whatever is behind (13 give-ways, 223 reverse
contacts). The second: forward spots a 12 m-radius hull cannot drive onto without its nose corner meeting a block;
the wheeled pursuit then shuffles gears against the face (forward give-ways, 251 reverse contacts). Ends: reverse/rear
298, reverse/nose 286 (a hull swinging while it backs). Hit: Block_6 343, Block_1 286, Block_7 276, Block_0 233, the
two containers 286. Begun via: asked 44 (359 reverse), self 37 (302) — both routes.

**Mixed (the control):** 284 reverse-gear ticks: route 128, `yield` 93, kturn 58, press 5; 111 give-ways, 84 of the
93 yield reverse contacts are in sweep-refused buckets (the tank/artillery pairs backing into Block_0/Block_1).

**Design read:** validating the run to the spot with the outline sweep addresses ~89 % of the yield share on both
squads; the other 44 % + 38 % of the rigs' reverse contacts (`route` 559, `kturn` 226) are not right-of-way (R4).

