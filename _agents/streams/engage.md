# Stream: engage (his IFV behind his own squads finds a lane and fires; when it can't, the feed says who is in the way)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 344, 345), `_agents/judging.md`, `_agents/workstreams.md` **Round 46**
> (C46.1-C46.8, R46.3, R46.4), your last brief `streams/archive/round45/engage.md` (Status: the lone-IFV trace, E2, E2b / E6, the garage
> map), R45.19, R45.24, R45.29 in `workstreams.md`. **You own:** `game/ai/gunnery.gd`, `game/ai/fire_lanes.gd`, `game/ai/tank_brain.gd`'s
> CLEAR_LANE option and its constants, `game/ai/native/native_decide.gd`'s constant table (additive), `game/tactics/drills.gd`,
> `game/tactics/element.gd`'s player-authority code, `game/tactics/element_plan.gd`'s engagement functions, `game/tactics/firing_position.gd`,
> `game/ai/order_controller.gd` (trace lines), GRANT `game/control/order_executor.gd`'s `stop` / `hold` / `move` / `attack_move` crew
> branches, GRANT `game/ui/hud_messages.gd` (one additive line kind, C46.5), `tests/tactics/test_engage*.gd`, `tests/engage/**`,
> `tests/test_authority*.gd`, `tests/test_gunnery*.gd`, `tests/test_fire_lanes*.gd`, `mk/engage.mk`, `game/garage/**`, `mk/garage.mk`.
> **Model:** Opus. **Machine:** builder3. **Seeds:** 11901-11948 (Bar L1), 11949-11996 (E6 / reserve). Dev 7001-7012 (never a bar).

## The lead's direction (2026-10-29 ~23:00, Terminus, verbatim)

"I was controlling an individual IVF and it seemed like it wasn't shooting at anything the whole time. I'm not sure if it finally got
shots off toward the end."

Memory: smart AI on both sides (friendly units as smart as Gears of War squadmates); units must look smart and under his control.

## Where things stand (main at launch: see HANDOFF; code 96f199c45 GREEN builder3 3470/0)

- **Your trace (round 45, builder3):** his crew Green_Hunters_1 fired 3 rounds from 104 s to 140 s with an engaged target 10-30 m away,
  clear sight, 3-5 enemies in range; then 30 rounds in 3 s at 140 s. Not E2 (identical with `--authority-off-at`), not ammo / heat /
  reload / sight. **Cause: his own vehicles in its line of fire:** `Gunnery._clear_to_fire` (FireLanes) holds a shot whose lane crosses a
  friendly; the blocker changed throughout (Guns_4 116 s, Guns_2 120-122 s, Hunters_2 124-128 s, Hunters_3 130 s, Wrenches_3 132-136 s,
  Guns_4 138 s), blocked up to 198 ticks running while the brain chose CLEAR_LANE. Command: `make engage-authority-trace
  AUTH_RECORDING=references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl AUTH_UNITS=Green_Hunters_1 AUTH_FROM=3090 AUTH_SECONDS=145`.
- CLEAR_LANE: `tank_brain.gd` (`CLEAR_LANE_EDGE` 1.15, the search radius const near :98), mirrored into native's decide via
  `native_decide.gd`'s constant table: **a behaviour change there needs native's twin (C46.4)**.
- E6 (the stop cap, `--turn-in-cap=on`, OFF): Bar E2b failed only on G5 (native runs a `stop` itself except a fixed gun on wheels).

## Backlog (in order)

1. **L1 why CLEAR_LANE finds no lane in a crowd, on his recording.** Per tick 3090-4200 for Green_Hunters_1: the candidate spots CLEAR_LANE
   scored, why each was rejected (blocked lane, out of range, no path, occupied, leash / his order), the one it chose and whether it
   moved. Is the blocker moving (a squadmate driving through the lane) or parked? Write the cause in Status before code; message the
   orchestrator.
2. **L2 the lane move that works in a crowd, ON by default, `--lane-clear=off` the escape.** Candidates: score spots by the lane being
   clear of friends' *predicted* positions (their current route), not just this tick's; widen the search ring when the near ring is
   all blocked; a small lateral / forward step beats waiting; respect his order (E2: a crew he moved holds its post; the lane step
   stays within a few metres of it and returns). Optionally the blocking friend nudges aside when it is idle (manoeuvre's yield is
   theirs: ask through the orchestrator, don't edit movement). Symmetric (C46.6). Tests first: a staged crowd (his 116-140 s geometry)
   where today's crew holds > 10 s and the new one fires within ~3 s; a crew with no clear spot doesn't oscillate.
3. **L3 the feed line (C46.5):** when a crew in his selection holds a shot for a friend in the lane for > ~2 s, the feed says
   "<crew> holding fire: <friend> in the way" through `HudMessages` (its duplicate / rate rules apply). One line kind, no icon, no
   button; the escape is `--lane-clear=off` too. Screenshot it at desktop and phone aspect and look at it.
4. **L4 Bar L1**, filed BEFORE any number on 11901-11948, native's twin EQUAL first (C46.4), a staged crowd workload + full fights.
   Deciding: seconds a crew with an engaged target in range holds fire for a friend (his case's line), time to first shot after the
   lane blocks. Guards: friendly-fire hits (must not rise: the rule never fires through a friend), deaths of the stepping crew, his
   order held (E2's authority probe), the fight probe (kills / losses within base +/- 1.645 se), manoeuvre's one-squad arrival. Ships
   ON the minute it passes; name the green hash.
5. **L5 his acceptance read:** his Terminus replay on the shipped tree: Green_Hunters_1's shots 104-140 s before/after.
6. **E6 one try (R46.4):** the one-condition fix (fixed mount + wheels), a workload that stages it, Bar E6 on 11949-11996. If it fails,
   remove the code and say so.
7. **Stretch:** the garage (his ask list in `game_design.md`) — only if he adds one.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote`; `make engage-*` and
`make replay-match`; screenshots of the feed line looked at. Every number with its commit, machine, workload and n.

## Don't touch

`game/control/**` but your grant, movement / traffic (manoeuvre), `native/**` (native twins it), `game/camera/**`, `game/ui/**` but
`hud_messages.gd`, `game/match/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. If Bar L1 fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### L1 DONE: why his IFV found no lane (his Terminus replay, builder3, 7189e3ff3 + trace rows, native on, n = 1 replay, 3090-4380)

Command: `make remote T="engage-authority-trace AUTH_RECORDING=references/round45/playtest/2026-10-29T22-57-47-terminus.jsonl
AUTH_UNITS=Green_Hunters_1 AUTH_FROM=3090 AUTH_SECONDS=145 AUTH_EVERY=15 AUTH_TAG=l1base"` (log kept at `~/overnight-engage/r46/`).
New rows: `LANE_READ` (each `_lane_spot` search: 16 candidates, the reject reason of each, the pick) and, on AUTHORITY, the lane goal,
the move sent, moves refused by his post, and the blocker's speed / order / option. Shots 19 at 116.5 s, 19 at 139.1 s, then 31 in 3 s.
**Every blocker in the held windows was PARKED** (speed 0.0, phase `arrived`), except Guns_4 at 137.7 s (4 m/s, 45 m off). Three
separate causes, one per window:

| Window | What it did | Cause |
|---|---|---|
| 118.4-122.8 s (4.4 s), his move done, holding his post | `HOLD`, lane blocked by Guns_2 / Hunters_2 (parked) | the CLEAR_LANE gate needs a current fight target; a held crew's `HOLD` has none, so CLEAR_LANE is never a candidate (and its move would be refused by the post rule: `held_may_move` has no CLEAR_LANE) |
| 122.8-134.0 s (11.2 s), his attack on Eyes_3 | `ENGAGE`, lane blocked 28 -> 120 ticks by Hunters_2 / Hunters_3 / Wrenches_3 (all parked) | **scoring:** under his `attack` the order adds a +1.0 base to every candidate BEFORE the commitment bonus multiplies the current one, so ENGAGE = (1 + e) x 1.15 and CLEAR_LANE = 1 + e x 1.15 x 1.15: CLEAR_LANE wins only when e > 0.87. The exact trap the CLEAR_LANE_EDGE comment warns about, re-opened by the order's base |
| 134.0-139.1 s (5.1 s), CLEAR_LANE at last | picked spots 5.6 m and 6 m aside, arrived, still blocked by the SAME parked Wrenches_3 (10-11 m off), then Hunters_2 / Guns_4 | **the spot test is weaker than the trigger's:** `_lane_spot` checks a 2 m point disc with no spread (`FireLanes.in_line`), the gun's gate checks the real hull box plus spread (`Match.friendlies_in_line_of_fire`), so "ok" spots stay blocked; a re-pick only every 2 s; rings 6 / 10 m only |

At 139.1 s ENGAGE drove it 3 m forward, the lane cleared, 30 rounds in 3 s. **Not a moving squadmate**: parked friends between it and
the target, and a brain that would not (attack), could not (post) or did not correctly (spot test) step aside.

**L2 design from this (one switch `--lane-clear`, ON; `=off` restores today exactly):** (1) CLEAR_LANE keeps its edge after the order's
base (under attack / attack-move it is multiplied after the base is added); (2) a crew with no fight target (holding his post) serves
the gun's blocked target, and the post rule lets that step out to a few metres of the post (HOLD brings it back); (3) the spot test
uses the hull reach + the gun's spread + friends' positions 1-2 s ahead, a third ring at 16 m, and a re-pick 0.5 s after arriving
still blocked. (1) and (2) change decide's scoring: until native twins them (C46.4), decide runs the GDScript for exactly the
situations the rule can change (lane blocked >= LANE_BLOCKED_TICKS, switch ON); every other decide stays native.

### Plan (2026-10-30, round 46 start; fresh session on 7189e3ff3, launch check cb1014bed builder3)

1. L1: instrument `_lane_spot` (`TankBrain.LANE_READ`, trace only: the 16 candidates, each one's reject reason, the pick, fallback) and
   the authority trace (lane goal, the move sent, moves the post leash refused, the blocker's speed / order / option); read 3090-4200.
   Suspect to prove or kill first: `held_may_move` has no CLEAR_LANE, so a crew holding his post gets its lane move turned into a face.
2. L2 from L1's cause, tests first (staged crowd from his 116-140 s geometry), behind `--lane-clear` ON.
3. L3 the feed line; L4 Bar L1 filed before numbers; L5 his replay; E6 one try.

