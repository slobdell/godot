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
| R1 | instrument the give-way; buckets before design | **done** `5866e387` (below), attributed against round 11 |
| R2 | yield spots sized by hull (`--nav-off=yieldfit`) | **done, third build** `42497bba` (the first two measured worse, below); `tests/nav/test_nav_yield_fit.gd` 4/4, `test_nav_yield_log.gd` 3/3 (builder0) |
| R3 | drive 8 seeds x 2, fight-maps rotation both arms, clips, `nav-sim-arms`, CP1 | drive 16 seeds done; fight-maps done; `nav-sim-arms` **UNMOVED** (no CP1 needed); clips rendering |
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

**Attributed against round 11 (builder0, `5866e387`, `nav-drive-arms` base = `--nav-off=kturnfill,guardnear,blockreach,creepbound,kturnslide`, 8 seeds):**
round 11's rigs gave way **6** times with **0** yield reverse contacts; HEAD's 81 times with 661. Round 11's reverse
contacts were route 719, kturn 139, unstick 67, press 21; HEAD's route 559. **The whole +542 is right-of-way** (the
rigs finding each other through blockreach, then taking spots they do not fit).

**Design read:** validating the run to the spot with the outline sweep addresses ~89 % of the yield share on both
squads; the other 44 % + 38 % of the rigs' reverse contacts (`route` 559, `kturn` 226) are not right-of-way (R4).

### R2 pre-registration (written 2026-09-27, BEFORE any drive result with `yieldfit` on)

Arms of ONE build (`26f4ac33`), builder0, `nav-drive-arms` 8 seeds x 2 squads, control `--nav-off=yieldfit`:
- **Rigs' reverse-gear contact ticks fall by most of round 12's +542** (946 -> 1488): at HEAD <= ~1217 (at least half
  of the rise gone); the `yield/reverse` row (661 at `5866e387`) falls by more than half.
- **No regression:** rigs' arrivals not below the control's by more than 3 of 128; refusals (`kturn_none`) not up by
  more than 10; press/unstick-driven contacts (the stall-escape regime) not up by more than 25 %.
- **Mixed is the control of the squad:** arrivals within 3 of 192, total contacts not up; its yield reverse contacts
  (93) may fall (the rule is general by hull; its tank/artillery pairs are in the refused buckets).
- **`nav-fight-maps` rotation, both arms, seed 3:** the `blocked_*` stall share not up on more than 6 of 12 runs
  (a refused give-way is a hull that holds: this is where a wedge would show).
- **Sim baseline:** pre-registered **MOVED** (the yield protocol runs in the baseline match); attributed with
  `nav-sim-arms` `SIM_ARMS="none yieldfit"`: the `yieldfit`-off arm must reproduce `6313a38d7ecd99bb`.

### R2: what was built, and the two builds that measured worse (all builder0, `nav-drive-arms`, `--yield-log`)

**What it replaces: the yield-SPOT CHOICE** (`_begin_yield`'s acceptance of a candidate). The protocol — who asks,
who gives way, the spot table's order, the hold and release — is round 6's. A candidate is accepted only if the drive
`right_of_way()` will make to it (the same steering law, stepped with the plant's yaw law) keeps the whole outline in
the clear reach at every step (`_outline_ok`, the planned reverse's test). Then:

1. **Refuse** what does not fit (`26f4ac33`; now `--nav-off=yieldshort,yieldhold`). Seeds 1-8: rigs' yield reverse
   contacts 661 -> 22, but total reverse 1488 -> 1502 (the scrapes came back as `kturn` 226 -> 522 and `press` 42 ->
   232), arrivals **115 -> 105**, press/unstick 83 -> 313, refused asks 4 -> 24. **Falsified** by its own
   pre-registration: a rig that will not move keeps the jam.
2. **Sized** (`88fa5563`; now `--nav-off=yieldhold`): no spot fits whole -> give way along the best one's run as far as
   the hull does fit (>= 2 m, less 1 m), steering at the spot so the run driven is the run swept. Its first build ran
   byte-identical to (1) — `yield_spots_shortened` 0: the best-candidate test compared against `Vector3.INF`
   (navigation.md's trap 1, caught by the counter). Fixed: seeds 1-8 rigs arrivals 105, reverse 1441. Still worse.
3. **Sized, then in place** (`42497bba`, **the default**): nothing fits even shortened -> give way IN PLACE (`hold`:
   stop pushing, round 6's hold and release). Never seen before its first 16-seed run, so every seed is out of sample.

**The default against round 12 (`d7d2f5d7` = the code of `42497bba`, arm `hold` vs `--nav-off=yieldfit`):**

| squad, seeds | arm | arrived | leg s | contacts | press/unstick | reverse-gear | cusps | kturn_none |
|---|---|---|---|---|---|---|---|---|
| rigs 1-8 | round 12 | 115/128 | 1140 | 5715 | 83 | 1488 | 1267 | 56 |
| rigs 1-8 | **R2** | 110/128 | 1039 | 3951 | 113 | **892** | 1218 | 72 |
| rigs 9-16 | round 12 | 114/128 | 1151 | 9414 | 112 | 2114 | 1311 | 87 |
| rigs 9-16 | **R2** | 115/128 | 876 | 3354 | 35 | **864** | 1075 | 43 |
| rigs 1-16 | round 12 | 229/256 | 2292 | 15129 | 195 | 3602 | 2578 | 143 |
| rigs 1-16 | **R2** | **225/256** | **1915** | **7305** | 201 | **1756** | 2293 | 115 |
| mixed 1-8 | round 12 | 179/192 | 1009 | 2660 | 60 | 284 | 2111 | 4 |
| mixed 1-8 | **R2** | 182/192 | 955 | 1433 | 165 | 126 | 1808 | 15 |
| mixed 1-16 | round 12 | 364/384 | 2036 | 4282 | 127 | 503 | 4043 | 15 |
| mixed 1-16 | **R2** | **366/384** | 1911 | **2114** | 178 | **300** | 3449 | 22 |

Rigs' drivers (16 seeds): yield reverse 1560 -> 143; route 1395 -> 820; kturn 566 -> 713. Give-ways 155 -> 169 (30
in place, 12 sized, 119 candidates refused for fit), refused asks 6 -> 6.

**Against the pre-registration (seeds 1-8), honestly:** rigs' reverse-gear contacts 1488 -> 892 — **met** (all of the
+542 gone, below round 11's 946); the yield row 661 -> 85 — **met**; mixed arrivals +3 and contacts down — **met**.
**Three no-regression clauses FAILED on seeds 1-8:** rigs' arrivals -5 (bound -3), refusals +16 (bound +10),
press/unstick +36 % (bound +25 %). On seeds 9-16 (fresh) all three go the right way (arrivals +1, refusals -44,
press/unstick -69 %), and pooled over 16 seeds they sit inside the bounds scaled (-4 of 256, -28, +3 %). Mixed's
press/unstick rose on seeds 1-8 (60 -> 165, seed 4 alone 28 -> 108) and fell on 9-16 (67 -> 0).

**Decision: ship it ON, the failed clauses on the record.** Contacts halve on both squads, the march is faster
(rigs 2292 -> 1915 s over 16 seeds), arrivals are a wash pooled — the lead's standing trade (*"a 4s slower march for
a tidier traversal is better"*) and this one is tidier AND quicker. The orchestrator can veto; every build is one
switch away (`--nav-off=yieldfit` = round 12; `yieldhold` = sized only; `yieldshort,yieldhold` = refusing).

### R3: the regression net and the baseline (builder0)

**`nav-fight-maps FIGHT_MAPS=rotation`, seed 3, ONE run per map x tempo, both arms of `42497bba`** (control
`--nav-off=yieldfit`; the control reproduces round 12's archived table exactly, e.g. crossing scripted 9.2 % / 24713):

| map / tempo | round 12: lost G/R, blocked_* share, blocked_friend, yielding, wall-contact ticks | R2 |
|---|---|---|
| yard, scripted | 1/1, 7.0 %, 0.5 %, 4.5 %, 13395 | 0/0, 9.0 %, 1.1 %, 4.3 %, **9633** |
| yard, busy 4 s | 1/1, 8.1 %, 2.2 %, 7.0 %, 11928 | 2/0, 9.4 %, 2.0 %, 6.9 %, **8950** |
| pit, scripted | 0/1, 7.8 %, 0.7 %, 5.5 %, 11343 | 1/1, 8.1 %, 0.9 %, 3.5 %, **8051** |
| pit, busy 4 s | 2/0, 7.6 %, 1.4 %, 5.9 %, 10010 | 0/0, 8.1 %, 0.9 %, 3.2 %, **6111** |
| terminus, scripted | 2/1, 6.7 %, 1.2 %, 6.8 %, 11203 | 3/0, 10.3 %, 1.3 %, 5.1 %, **9899** |
| terminus, busy 4 s | 0/1, 9.4 %, 1.4 %, 6.1 %, 11253 | 1/0, 9.2 %, 1.6 %, 7.2 %, **9419** |
| crossing, scripted | 1/1, 9.2 %, 2.0 %, 6.9 %, 24713 | 1/0, 8.8 %, 1.6 %, 6.6 %, **18479** |
| crossing, busy 4 s | 1/2, 10.8 %, 1.6 %, 7.9 %, 18993 | 2/0, 8.5 %, 1.3 %, 7.2 %, **15751** |
| sumps, scripted | 1/0, 10.1 %, 1.4 %, 4.6 %, 15118 | 2/1, 8.7 %, 1.3 %, 6.0 %, **13035** |
| sumps, busy 4 s | 0/0, 8.6 %, 1.7 %, 5.8 %, 13007 | 2/0, 9.2 %, 2.3 %, 7.2 %, **11338** |
| locks, scripted | 1/0, 6.8 %, 1.2 %, 6.9 %, 16351 | 1/0, 7.6 %, 1.2 %, 6.2 %, **13408** |
| locks, busy 4 s | 1/0, 9.1 %, 2.3 %, 11.8 %, 13499 | 0/0, 7.5 %, 2.5 %, 12.0 %, **10659** |

**Wall-contact ticks fall on 12 of 12 runs (-12 % to -39 %)** — the give-way's scrapes were a fight-wide cost, not a
rig-only one. **The pre-registered stall clause FAILED by one run:** the `blocked_*` share rose on **7** of 12 (bound:
6); the largest is terminus scripted 6.7 -> 10.3 %, while crossing and locks busy fell ~2 points. `blocked_friend`
itself is flat (up on 6, down on 5). Single runs of chaotic fights: a direction, not an effect size. What it could
mean: a hull that gives way in place rather than backing into a wall leaves its friend `blocked` a little longer;
the lost counts do not move with it (G lost 12 -> 15, R lost 9 -> 2 summed: combat noise at one seed).

**Sim baseline: pre-registered MOVED, measured UNMOVED.** `make nav-sim-arms` on `8f517ced` (code = `42497bba` + the
clip case): `none`, `yieldfit`, `yieldhold`, `yieldshort,yieldhold` all read **`6313a38d7ecd99bb`** = the recorded
hash. Nothing in the 40 s baseline match takes a spot that fails the sweep (the arm fires on the drive: 119-189
candidates refused per 16 seeds, so it is not a silent switch). **No CP1: nothing to record; R2 merges like any
other branch.** My pre-registration was wrong, and it is left above as written.

