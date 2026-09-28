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

_(the worker keeps this current)_
