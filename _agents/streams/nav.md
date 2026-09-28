# Stream: nav, round 14 (the other 53 %: route reverses and k-turn legs)

> Read [`navigation.md`](../navigation.md) (round 13's give-way section and its three switches), the archived round-13
> brief `archive/round13/nav.md` and its **Status** (R1's buckets, R2's 16-seed table, the four failed clauses and the
> fresh-seed reversal, *Next steps* 1–3 — this brief is built from them), and `references/round13/nav/` (the yield
> sheet, the clips, `r1_yield_buckets.txt`, `r2_drive_16seeds.txt`). **You own** what nav owned in rounds 12–13:
> `game/ai/movement.gd`, `pathing.gd`, `steering.gd`, `avoidance.gd`, `wall_contact.gd`, `clothoid.gd`,
> `game/tank/tank_motion.gd`, `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`, `_agents/algorithms.md`.

## The lead's direction

No new words this round. Standing: the rig stays 14 m; *"a 4s slower march for a tidier traversal is better, yes."*
Round 13 shipped the give-way fix ON on that trade; **his veto stands** (`--nav-off=yieldfit` is round 12).

## Where things stand (round 13's Status; verify on main)

- After R2 (builder0, 16 seeds × 2 squads): rigs' reverse-gear contacts 3602 → 1756; what is left is **`route` 820 and
  `kturn` 713 (up from 566), `yield` 143.** Neither is right-of-way: `route`-driver reverses are Steering's circle rule
  (a point inside the turning circle → reverse at full lock, no wall consulted); `kturn` are planned-reverse legs.
- The fight-maps `blocked_*` stall share rose on 7 of 12 (bound 6) on ONE seed (3); not yet re-run.
- The yield sheet (seed 7, first leg): with the fix ON two rigs are still in the Terminus gap at 8 s where OFF had
  cleared it by 5 s; the 16-seed leg time is nonetheless 16 % lower. `--nav-off=yieldhold` is the sized-only build
  (fewer holds, more scrapes) if he finds rigs waiting too long for each other.
- Tools: `make nav-terminus-drive`, `nav-drive-arms`, `nav-fight-maps`, `nav-sim-arms`, `nav-yield-buckets`,
  `nav-yield-clip`, `nav-rig-clip`, `nav-wall-clip`.

## Backlog (in order)

**N1. The instrument, before design.** Split `route/reverse` contacts into circle reverses vs other, and log each k-turn
leg's end (planned distance, distance driven, what it hit, which end) the way `--yield-log` logs a give-way. Buckets and
counts in Status (8 seeds × 2 squads, builder0), with the rig/mixed split. Say which bucket is the biggest and what
mechanism it names.

**N2. The circle rule consults the wall.** Steering's "point inside the turning circle → reverse at full lock" reverses
without asking whether the swept outline clears (round 13's give-way now does). Make the reverse leg a swept, validated
leg (the same sweep the planned reverse uses; when it does not fit, the shorter fit or a forward arc instead). Behind
`--nav-off=<name>`. Pre-register on fresh seeds (name them BEFORE the first variant: the design seeds are 1–8, the
acceptance seeds 9–16; lesson 224): rigs' `route/reverse` contacts fall by most of the 820, arrivals and refusals within
round 13's bars, press/unstick not up 25 %, mixed a null control.

**N3. K-turn legs that end in a wall.** From N1's leg log: if legs are planned to a clearance the drive does not achieve
(steering-law drift), close the gap in the planner's model or the leg's exit test — measure which by the leg log's
"planned vs driven" column. Same pre-registration shape.

**N4. The stall share, read properly.** Re-run `nav-fight-maps` on seeds 1–4, both arms of the round-13 give-way, before
`blocked_*` "up on 7 of 12" is read as an effect; and answer the question the sheet asks: does a rig that HOLDS instead
of yielding block the street behind it (count the hulls queued behind a holding rig, and for how long)?

**N5 (stretch).** The kinematic planner the round-12 N5 write-up priced: only if N1–N3 leave a count that names it.

## How to verify

`make remote T=check`; every number with commit, machine, seeds, arm; the clips looked at. **Sim baseline: pre-register
per item WITH the path** (lesson 223: which unit, which state, which second of the 40 s baseline match reaches the
changed code — or UNMOVED). Only nav may move the baseline this round; declare it, attribute it with `nav-sim-arms`,
and the orchestrator records it twice (CP1, merged alone).

## Don't touch

`game/tactics/**`, `game/ai/{squad,tank_brain,formations}.gd` (squad's); `game/units/units.gd`; `game/arena/**`;
`game/theme/**`.

## Waiting on the lead

Nothing. If he plays and says the rigs wait too long, `yieldhold` is the arm to offer him, with the numbers.

## Status

_Worker: nav, round 14. Started 2026-09-27 from `b5c11813`. Every number names its commit and machine._

### Report in one screen

- **N1 (done):** `--reverse-log` / `make nav-reverse-buckets` log every circle-rule reverse and every k-turn leg. The
  rigs' `route/reverse` is Steering's circle rule, all of it, and the biggest single mechanism in BOTH buckets is
  **momentum**: a reverse commanded on a rig still rolling forward at ~6 m/s (2-3 m to stop), nose into the face.
- **N2 (falsified, OPT-IN):** the circle rule's reverse gated on an outline sweep — three builds, all worse on the
  design seeds (the forward alternatives scrape; half the contacts are momentum anyway). `--nav-off=circlefit` turns
  it on. Kept: the dense outline (a 14 m hull's 10-point outline misses block corners) and the roll-out model.
- **N3 (ON, moves the sim baseline — CP1):** a planned leg ends within its stopping distance and counts from where the
  hull moves in its gear. Target (kturn reverse contacts -50 %) FAILED on both seed sets (-12 %, -25 %); on the fresh
  seeds every other clause held: rigs' contacts -19 %, leg time -13 %, arrivals equal, mixed contacts 3252 -> 870.
  Shipped on the lead's standing trade; veto `--nav-off=kturnbrake`. Baseline `6313a38d7ecd99bb` -> `784069348a1b5423`
  (attributed: the `kturnbrake`-off arm reads the recorded hash).
- **N4 (done):** round 13's stall-share rise is a coin flip (25 of 48 runs, seeds 1-4); a holding hull queues ~3.4x
  more hull-seconds per second than a moving give-way, but holds are 6 % of yielding and queues max 4 hulls: +13 %
  queued time overall.
- **N5 (stretch):** named, not built: first k-turn legs planned inside the stopping distance, and the circle rule's
  reverses — a planner that looks earlier from a moving hull (the pieces are written: `_rollout`, `_dense_outline`).

### What to playtest (exact commands)

- `make skirmish` on the Terminus with the Condemned: a War Rig squad sent back and forth through the streets. Expect:
  a rig's multi-point turn in a tight street stops at each end instead of rolling its nose into the block, and
  finishes sooner.
- `make nav-rig-clip RIG_CLIP_OFF=kturnbrake` (display; builder0: `make remote T="nav-rig-clip RIG_CLIP_OFF=kturnbrake"`)
  -> `build/nav-rig-clip/rigfill_{off,on}.mp4`. Looked at (sheets in `references/round14/nav/rigfill_kturnbrake_*`):
  with N3 the five-point turn is done ~2 s sooner, heading up the street by the 8th sheet frame against the 13th; in
  THIS episode N3 then touches the container on the way out (21 contact ticks, round 13's arm 0) — one episode, the
  aggregate is above.
- `make nav-reverse-buckets DRIVE_SEEDS="1 2 3 4 5 6 7 8"`; the A/B: `tools/remote.sh nav-drive-arms
  'DRIVE_SEEDS=9 10 11 12 13 14 15 16' 'DRIVE_ARMS=ctl=kturnbrake on=none' NAV_FLAGS=--reverse-log`.

### Merge notes

- **CP1: merge ALONE; the sim baseline moves** `6313a38d7ecd99bb` -> `784069348a1b5423` (N3, `kturnbrake`), attributed
  by `nav-sim-arms SIM_ARMS="none kturnbrake circlefit"` on builder0. `make check` reads MOVED until the orchestrator
  runs `make sim-baseline-adopt`.
- Only nav's paths: `game/ai/movement.gd`, `game/ai/wall_contact.gd`, `tests/nav/`, `mk/nav.mk`, `_agents/navigation.md`,
  this brief, `references/round14/nav/`. No shared file touched.
- New `--nav-off` names: `kturnbrake` (off = round 13), `circlefit` (INVERTED: turns the gate ON). `route_arms()` gains
  `circle_kept`, `circle_forward`, `circle_none`. `WallContact.report()` gains `by_reverse_why`; `NAV_DRIVE` and
  `NAV_FIGHT` gain `queues`. Movement gains `yield_spot`, `queue_census()`, `QueueTally`, `reverse_log` (+ logs).
- New tests: `test_nav_reverse_log` (3), `test_nav_circle_fit` (3), `test_nav_kturn_brake` (2), `test_nav_queue_census` (2).
- New targets / tools: `nav-reverse-buckets`; `nav-rig-clip RIG_CLIP_OFF=`; `tests/nav/reverse_buckets.py`, `queue_table.py`.
- Drive note: the airship A0 deploy fix (main `197364a8`) moved the rigs' drive control (seeds 1-8: 892 -> 1082
  reverse-gear contacts); compare across it only through a control on the same tree.

### Questions for the lead

- None blocking. For his eye: a War Rig's multi-point turn in a narrow street now stops at each end instead of rolling
  2 m on into the wall, and finishes sooner. Does it read like a driver?

### Requests to other streams / the orchestrator

- CP1 as above (merge alone, adopt the hash). Nothing else.

### Next steps (not done, in order)

1. **N5, a planner that looks earlier from a moving hull.** The count that names it: on the merged tree, 25 of 80
   first k-turn legs (190 reverse contacts, rigs, seeds 1-8, control) are planned when the forward arc's hit is 1-3 m
   and the rig needs 3.5 m to stop; and the circle rule's reverse (rigs' `route/reverse` 588-791 per 8 seeds). Start
   state = `_rollout`; sweep = `_dense_run_ok`; pre-register on seeds 17-24 (1-16 are now spent).
2. The give-way hold: if the lead finds rigs waiting, `--nav-off=yieldhold` (N4: holds queue ~3.4x more per second).

### Plan (the brief's order)

| # | item | state |
|---|---|---|
| 0 | green start: `make remote T=check` on `b5c11813` | **green**: builder0, `make check exited 0`, 1790 passed / 0 failed, sim-baseline `6313a38d7ecd99bb` unmoved, determinism `ca7e3cbe26cf708d` |
| N1 | the instrument: circle reverses vs other, k-turn legs planned vs driven | **done** `8554f3b8` (below) |
| N2 | the circle rule consults the wall (`--nav-off=circlefit`) | **falsified on the design seeds in three builds; shipped OPT-IN** (the switch turns it on); default = round 13. Acceptance seeds 9-16 never run with it (nothing to accept) |
| N3 | k-turn legs that end in a wall (`--nav-off=kturnbrake`) | **built `0974fd4b`, ON**: the target failed on both seed sets (below), every other clause held on the fresh seeds; shipped on the lead's standing trade, the veto is one switch |
| N4 | the stall share re-read; does a holding rig block the street | **done** `fc113358` (below): the stall share is a coin flip (25 of 48); a hold queues ~3.4x more per second than a moving give-way, but holds are short and rare (+13 % queued time overall) |
| N5 | stretch: the kinematic planner | only if N1–N3 leave a count that names it |

### N1: the other 53 %, bucketed (builder0, `8554f3b8`, `make nav-reverse-buckets DRIVE_SEEDS="1 2 3 4 5 6 7 8"`, 8 seeds x 2 squads, default path)

The instrument (`--reverse-log`, measurement only; `tests/nav/test_nav_reverse_log.gd` 3/3 on builder0): every circle-rule
reverse episode (`NAV_CIRCLE`: the point in hull coordinates, the reverse the rule commits to vs how far the outline
sweep clears, the forward arcs' clear runs, the hull's speed when it began, contacts by gear / end / actual roll) and
every planned k-turn leg (`NAV_KTURN_LEG`: planned vs driven metres, the planner's pose at the same distance vs the
real one, predicted vs actual clearance margin, the speed at the leg's start, how far it went the WRONG way, how it
ended, contacts). WallContact splits `route/reverse` by rule (`by_reverse_why`). The run reproduces round 13's R2
exactly (rigs' reverse-gear contacts 892 at seeds 1-8): the instrument moves nothing. Table:
`references/round14/nav/n1_reverse_buckets_seeds1-8.txt`.

**Rigs' 892 reverse-gear contact ticks:** route 431, kturn 305, yield 85, press 44, unstick 27.
- **`route/reverse` is the circle rule, all of it:** 429 of 431 (2 other; station and reverse orders 0). Mixed: 139 of 139.
- **The biggest single mechanism is MOMENTUM, in both buckets.** A reverse commanded while the hull is still rolling
  forward: the rig brakes at 8 m/s2 from a median 5.7-6.8 m/s, i.e. ~2-3 m of forward roll on the lock the reverse
  was commanded with, and its NOSE goes into the face the reverse was meant to avoid.
  - k-turn legs: **236 of the 305 reverse contacts are `reverse/nose` with the hull rolling forward**; legs with
    contacts start at a median 5.74 m/s (clean legs 3.56) and go 1.14 m the wrong way first (clean 0.44). 23 of the
    30 contact legs were predicted clear along their whole length; the leg's end pose is clear by the sweep (end
    margin 1.6 m) — the plan was right about where it would go, wrong about where it STARTED. Planned vs driven
    metres agree (the exit test counts the forward roll as progress: `backed` is a flat distance), drift 1.3 m / 10.6
    deg on contact legs vs 0.73 m / 1.9 deg over all legs. Worst bucket: back-and-fill reverse legs, 15 legs, 222.
  - circle episodes: of 429 reverse contacts, **189 are the rule backing the rear into a wall** (`reverse/rear/back`:
    the sweep's case) and **~227 are the forward roll-out** (`reverse/nose/fwd` 165, `reverse/rear/fwd` 35, side 27).
    By sweep: `blocked:rear_corner` 88 episodes -> 224 reverse contacts (needed 2.25 m, clear 1.25 m);
    `fits` 195 -> 138 (the roll-out, not the sweep); the rest small.
- **Mixed (the control):** 188 reverse: route 139 (circle), kturn 40. 1075 circle episodes, 893 of them
  sweep-clean one-tick flickers at the circle's edge (median driven 0.0 m, 22 contacts) — a leg planned for every
  flicker would turn 893 zero-metre reverses into metres of reversing, so N2 plans only a reverse the rule would
  actually drive.

**What it names:** N2 as briefed (the rule's reverse swept) addresses the ~189 true backing contacts; the other half
of both buckets is the start state — both reversing rules plan from a hull at rest while it is rolling at 6 m/s. So
N2 plans the circle reverse from the ROLL-OUT pose (the forward arc the hull will brake through: v^2 / 2b on the same
lock, the plant's own law) and counts the leg from where the hull stops; N3 does the same for the k-turn planner.

### N2 pre-registration (written 2026-09-28, BEFORE any drive with the arm on)

The build: a circle reverse on a forward routed move becomes a planned leg (the k-turn leg machinery, driver still
`route`/why `circle` so the counts stay comparable): from the roll-out pose, the reverse the rule commits to (until it
lets go, with its own hysteresis) is swept with the whole outline (`_outline_ok`); fits -> that leg; else the part
that fits (>= 1 m) -> the shorter leg; else a forward arc on the other lock until the rule lets go, if it is clear;
else the rule as before (counted `circle_none`). A flicker (the rule would reverse < 1 m) stays the rule's. The
leg's distance counts from where the hull stopped rolling forward. Control: `--nav-off=circlefit`, same build.
Design seeds **1-8**; acceptance seeds **9-16** (never run with the arm on before the design is frozen).
- **Target:** rigs' `route/reverse` contact ticks fall by more than half (429 at seeds 1-8), on BOTH seed sets.
- **No displacement:** rigs' total reverse-gear contacts fall (not just moved to kturn/press/unstick); all contacts not up.
- **No regression (rigs, per 128 legs):** arrivals not below the control by more than 3; `kturn_none` not up by more
  than 10; press+unstick contacts not up 25 %; leg time not up more than 10 %.
- **Mixed is the null control:** arrivals within 3 of 192, all contacts not up.
- **Sim baseline:** the 40 s baseline match drives wheeled hulls on routed moves, and the circle rule fires ~130 times
  per mixed drive leg, so **MOVED** is expected (path: any wheeled unit whose route carrot falls inside its turning
  circle while above flicker size); attributed with `nav-sim-arms SIM_ARMS="none circlefit"` — the `circlefit`-off
  arm must read `6313a38d7ecd99bb`. If it reads UNMOVED, no CP1.


### N2: what was built, and why it does not ship (builder0, `nav-drive-arms` 8 design seeds x 2, control = the same build with the rule as round 13)

The control reproduces round 13 exactly in every run below (rigs 110/128, 1039 s, 3951 contacts, 892 reverse).

| build | rigs arrived | leg s | contacts | reverse-gear | `route/reverse` | press+unstick | mixed arrived / contacts |
|---|---|---|---|---|---|---|---|
| control (round 13) | 110/128 | 1039 | 3951 | 892 | 431 | 113 | 178/192, 1729 |
| 1 `0df01263`: the rule's reverse as a committed leg planned from the roll-out pose (fits / shorter / forward arc / the rule) | 108 | 1668 | 8029 | 2136 | 1272 | 448 | 175, 1240 |
| 2 `8291a371`: tick-by-tick gate on a DENSE-outline sweep (side samples <= 1 m apart); blocked -> a latched forward arc on the other lock | 102 | 1306 | 7220 | 1055 | 342 | 221 | 177, 1855 |
| 2b `d8fba199`: + the latch releases on a nose contact or no progress | 104 | 1263 | 5708 | 1048 | 410 | 192 | 180, 1627 |

**Against the pre-registration: the target failed in every build** (`route/reverse` needed to fall below ~215); arrivals,
contacts, press/unstick and leg time all failed too. Mixed is roughly a null in 2b, as registered. Not run on the
acceptance seeds: nothing to accept, and seeds 9-16 stay fresh for whoever builds the next variant.

What each build predicted, and what killed it:

| build | predicted (from N1) | killed by (the leg / episode log) |
|---|---|---|
| 1 | the ~189 rear-into-wall contacts go (swept reverse) AND the ~227 roll-out contacts go (planned from where the hull stops) -> `route/reverse` well under half | a committed leg overrides the rule's tick-by-tick let-go (long reverses where the rule backed centimetres); the 10-point outline passed legs that scraped their sides; `route/reverse` 431 -> 1272 |
| 2 | keep the rule tick by tick; a dense sweep stops only the reverses that hit; the ~189 go, the roll-out stays -> `route/reverse` about halves | where the reverse does not fit a forward arc rarely does either: `route/forward` 2646 -> 5550; the turn-away latch pinned a rig on a floodlight 51 s; `route/reverse` 431 -> 342 |
| 2b | the latch releases on contact / no progress, so 2's reverse saving stands without the wedge | the wedge went (contacts 7220 -> 5708) but `route/reverse` 431 -> 410: once the forward arcs stop wedging, the rule reverses into the same walls a few ticks later; still +44 % contacts vs control |

What each build taught (all from the leg/episode logs, not guessed):
1. **A committed leg overrides the rule's own let-go.** The rule re-decides every tick and often lets go after a few
   centimetres (N1: median driven 0.3 m); a leg planned from a roll-out 6 m ahead at 10 m/s committed rigs to 5-20 m
   reverses. And the **10-point outline misses block corners** between a 14 m hull's side samples: legs predicted
   clear by 0.1-0.4 m scraped their sides along `Block_1` (seed 5, one rig looped there ~700 contact ticks).
2. **Where the reverse does not fit, there is rarely a clean alternative.** With a dense sweep, 1391 of the 5394 unit-
   ticks the rule wanted to reverse had neither the reverse nor a 2 m forward arc clear; the forward arcs that were
   chosen scraped (`route/forward` contacts 2646 -> 4025-5550). The first latch pinned a rig nose-on against
   `Floodlight_31` for 51 s: the sweep lets a pressed point stay where it is, and the pose never changed.
3. **Half the rule's contacts are momentum, which no reverse gate touches** (N1: ~227 of 429 are the forward roll-out).

**Decision:** OPT-IN (`--nav-off=circlefit` turns it ON, like `a7`), default path = round 13 (so the sim baseline cannot
move from N2). The dense outline (`_dense_outline`, `_dense_run_ok`) is kept: it is the sweep any later planner needs.
The remaining `route/reverse` count names the kinematic planner (N5), not another rule on the rule.

### N3: which column names it (builder0, `9e7215aa` = pre-merge, `nav-reverse-buckets` seeds 1-8, rigs)

The leg log's planned-vs-driven answer: **the exit test, not the planner's model.** On clean legs the drive follows the
plan (drift 0.7 m / 1.8 deg median over all legs; planned and driven metres agree). The contacts are momentum at a leg
BOUNDARY: a back-and-fill's forward leg accelerates for its 2.5 m (0.7 throttle, 7 m/s2 -> ~5.7 m/s) and ends
KTURN_FILL_MARGIN_M = 0.25 m short of the clear reach; the rig needs v^2 / 2b = ~2 m to stop (braking 8 m/s2), so the
next REVERSE leg begins with the hull rolling forward and the nose goes into the face. By leg position:

| legs | n | contacts | reverse | median speed at the leg's start (+ = forward) |
|---|---|---|---|---|
| back-and-fill reverse, later leg | 25 | 241 | **241** | **+5.73 m/s** |
| single back-up, first leg | 50 | 53 | 53 | +5.1 |
| back-and-fill forward, first leg | 10 | 13 | 0 | +5.3 |
| back-and-fill reverse, first leg | 10 | 11 | 11 | +1.3 |
| back-and-fill forward, later leg | 19 | 4 | 0 | -2.8 |

First legs whose own roll-out is not clear (the planner looked too late: arc hit 2.5 m, stop 3.0 m median): 26 of 70,
53 reverse contacts. Mixed: 40 kturn reverse contacts, too few to bucket.

### N3 pre-registration (written 2026-09-28, BEFORE any drive with the arm on; on the MERGED tree, `14e7897d` + the build)

The build (`--nav-off=kturnbrake` = round 13): a planned leg ends when the distance left is within the hull's stopping
distance in the leg's gear (v^2 / 2b from the catalog's braking), so the NEXT leg's opposite throttle brakes it to rest
at the planned end instead of 2 m past it; and a leg counts its distance from where the hull begins to move in the
leg's gear (a roll the other way is not progress). The planner's geometry is unchanged. Design seeds **1-8**,
acceptance seeds **9-16**; control = the same build with the switch.
- **Target:** rigs' `kturn/reverse` contact ticks fall by more than half of the control's, on both seed sets.
- **No displacement:** rigs' total reverse-gear contacts fall; all contacts not up.
- **No regression (rigs, per 128 legs):** arrivals not below the control by more than 3; `kturn_none` not up more than
  10; press+unstick not up 25 %; leg time not up 10 %.
- **Mixed null control:** arrivals within 3 of 192; all contacts not up.
- **Sim baseline:** path = a wheeled hull in the 40 s baseline match driving a planned k-turn leg. I do not know that
  one is driven; pre-registered **UNMOVED unless it is**, decided by `nav-sim-arms SIM_ARMS="none kturnbrake"` (any
  move must be reproduced by the `kturnbrake` arm reading `6313a38d7ecd99bb`).

### N3: the leg ends where the hull can stop (builder0, `0974fd4b` on the merged tree, `nav-drive-arms`, control `--nav-off=kturnbrake`, same build)

What it changes: the planned leg's EXIT TEST only (the planner's geometry is round 13's). A leg is done when what is
left is within the stopping distance in its gear (v^2 / 2b, the catalog's braking), so the next leg's opposite throttle
brakes the hull to rest at the planned end; a leg that starts with the hull rolling the other way counts its distance
from where the hull begins to move in its gear (the control counted a forward roll as a reverse leg's progress: in
`test_nav_kturn_brake`'s control the reverse leg is never driven at all). `test_nav_kturn_brake` 2/2.

The merge moved the rigs' control (the airship A0 deploy fix changes where rigs start): design seeds 1-8 read 1082
reverse-gear contacts on the merged tree against 892 before it; mixed is identical (188). Every comparison below is the
two arms of one build.

| squad, seeds | arm | arrived | leg s | contacts | press+unstick | reverse-gear | `kturn/reverse` | kturn_none |
|---|---|---|---|---|---|---|---|---|
| rigs 1-8 (design) | control | 111/128 | 1172 | 6415 | 257 | 1082 | 313 | 53 |
| rigs 1-8 (design) | **N3** | **113** | **1106** | **4900** | **133** | 1153 | 276 | 38 |
| rigs 9-16 (acceptance) | control | 109/128 | 1283 | 9147 | 162 | 1400 | 552 | 69 |
| rigs 9-16 (acceptance) | **N3** | **109** | **1113** | **7386** | **138** | **1266** | 416 | 70 |
| mixed 1-8 | control | 178/192 | 1139 | 1729 | 105 | 188 | 40 | 8 |
| mixed 1-8 | **N3** | 174 | 1265 | 1670 | 27 | 199 | 11 | 12 |
| mixed 9-16 | control | 173/192 | 1198 | 3252 | 198 | 208 | 20 | 7 |
| mixed 9-16 | **N3** | **175** | **965** | **870** | **0** | **151** | 0 | 6 |

**Against the pre-registration, honestly:**
- **Target FAILED on both sets:** rigs' `kturn/reverse` -12 % (design) and -25 % (acceptance); registered: more than half.
  On the design seeds the forward-roll nose contacts halved (`reverse/nose/fwd` 201 -> 99), but on the merged tree the
  biggest kturn bucket is FIRST legs planned too late (the forward arc's hit 1-3 m when the planner first looks, the
  rig's stop 3.5 m: 25 legs, 190 reverse contacts in the control), which an exit test cannot reach.
- **No displacement:** failed on design (total reverse-gear 1082 -> 1153; `route/reverse` 588 -> 791), met on acceptance
  (1400 -> 1266). All contacts down on both (-24 %, -19 %).
- **No regression:** arrivals +2 / 0 (met), `kturn_none` -15 / +1 (met), press+unstick -48 % / -15 % (met), leg time -6 % /
  -13 % (met).
- **Mixed null:** arrivals -4 on design (bound 3: FAILED by one), +2 on acceptance; contacts down on both.

**Decision: ON.** The count it was built for moved a quarter, not half; everything a player sees moved the right way
on the fresh seeds (fewer scrapes, a faster march, the same arrivals), which is the lead's standing trade (*"a 4s slower
march for a tidier traversal is better"*: this one is tidier and quicker). The orchestrator's veto: `--nav-off=kturnbrake`.
The remaining `kturn` count names the planner that looks earlier (first legs planned inside the stopping distance) —
N5's case, with the roll-out model (`_rollout`) and the dense outline already written.

### N4: the stall share, read properly, and the queue behind a holding hull (builder0, `fc113358` = pre-garage-merge tree, `nav-fight-maps FIGHT_MAPS=rotation`, seeds 1-4 x scripted / busy 4 s, both arms of round 13's give-way: `r12` = `--nav-off=yieldfit`, `r13` = default)

Instrument: the queue census (`Movement.queue_census` / `QueueTally`, `test_nav_queue_census` 2/2): each tick, every hull
giving way is a yielder labelled by its spot kind; every blocked hull whose `blocked_by` chain (through other blocked
hulls, up to 4 links) ends at a yielder is queued behind it. Table: `references/round14/nav/n4_fight_maps_seeds1-4.txt`
(`tests/nav/queue_table.py`).

- **The stall share is not an effect.** `r13`'s `blocked_*` share is above `r12`'s on **25 of 48** runs (round 13 read
  "7 of 12" on seed 3 alone). The seed moves it far more than the arm does (seed 2 runs 8-17 %, seed 1 runs 2-6 %, both
  arms). `blocked_friend` goes the same way, and losses are combat noise.
- **Does a hull that HOLDS block the street behind it? Yes, per second, and it barely matters in total.** Over the 48
  `r13` runs: 1096 holds, 2494 unit-s holding (6 % of all yielding), 30 % with someone queued behind, **0.24 queued
  hull-seconds per second of holding** against 0.07-0.09 for a hull moving to a spot or backing up (~3.4x). Queues are
  short: the longest is 4 hulls, typically 1. Queued time behind ANY yielder: `r12` 2998 unit-s, `r13` 3396 (+13 %),
  of which 587 behind holds.
- **What a player would see:** a hull that stops to let a friend by now and then holds up the one or two behind it for
  a moment. If the lead reads it as rigs waiting too long, `--nav-off=yieldhold` is the arm (round 13: fewer holds,
  more scrapes).

### N3b: CP1 held — a scenario moved, attributed, and the variant that answers it (pre-registered 2026-09-28 BEFORE any run of it)

`make check` on the merged tree (`edad0ba7`, builder0): runner 1814 passed / 0 failed, sim-baseline MOVED as declared,
**`ai-scenarios-check` FAILED**. `make nav-scenario-arms` (new; the suite once per `--nav-off` arm; twice each, identical):
`scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` fails with N3 ON (deck hits **41/43 -> 3/13**) and passes
with `kturnbrake` off — N3's. (`scenario_cover::test_peeking_while_the_enemy_reloads_takes_fewer_hits` fails on main
`3955efec` too, in both arms: main's recorded count, not nav's.) Mechanism: the orbiting scout (~14 m/s) plans short
reverse legs; before N3 the forward roll counted as the leg's progress, so a leg was a brake tap; N3's count-from-rest
made it a full stop and back-up mid-orbit.

**N3b:** count-from-rest only for a leg that CONTINUES a plan (a back-and-fill's second and later legs — where the
rigs' 241 momentum contacts were); a plan's FIRST leg counts as round 13 did. The stopping-distance exit test is
unchanged. Pre-registered, on the merged tree, arms of one build (control `--nav-off=kturnbrake`):
- **Scenario:** `scenario_cp2` engine-deck passes (deck share >= 0.5) with the arm ON; the suite's counts equal main's.
- **Sim baseline:** MOVED or not, attributed by `nav-sim-arms` (the off arm must read `6313a38d7ecd99bb`).
- **Drive, design seeds 1-8 and FRESH acceptance seeds 17-24** (9-16 were spent on N3): rigs' all contacts down;
  total reverse-gear not up; arrivals not below control by more than 3; `kturn_none` not up 10; press+unstick not up
  25 %; leg time not up 10 %; mixed arrivals within 3, contacts not up. (N3's failed target is not re-registered: an
  exit test does not reach the first-leg bucket; that is N5.)
