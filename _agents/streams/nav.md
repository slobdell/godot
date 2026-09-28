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

### Plan (the brief's order)

| # | item | state |
|---|---|---|
| 0 | green start: `make remote T=check` on `b5c11813` | **green**: builder0, `make check exited 0`, 1790 passed / 0 failed, sim-baseline `6313a38d7ecd99bb` unmoved, determinism `ca7e3cbe26cf708d` |
| N1 | the instrument: circle reverses vs other, k-turn legs planned vs driven | **done** `8554f3b8` (below) |
| N2 | the circle rule consults the wall (`--nav-off=circlefit`) | pre-registered (below), building |
| N3 | k-turn legs that end in a wall | N1 names the mechanism: momentum (below) |
| N4 | the stall share re-read; does a holding rig block the street | — |
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
