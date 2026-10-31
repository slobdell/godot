# Stream: orders (a following tank keeps its station; the group click never stalls)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 348, 352, 353, 354), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 48** (C48.1-C48.4) and **Round 47** (C47.1-C47.11; R47.21, R47.37, R47.41 Bar O2 and O1 v3), your last brief
> `streams/archive/round47/orders.md` (FINAL REPORT and its round-48 list: the follow station, support by fire, O7), spotter's classes
> `streams/references/round47/spotter/batch1-classes.md` (**D** is yours), `game_design.md` *His answers mid-round 47* (the group click,
> the army cap). **You own:** `game/control/**` (incl. `orders.gd`'s `goal_of` / `goal_position`, `selection_squads.gd`,
> `group_formation.gd`, `rts_controls.gd`) EXCEPT engage's crew branches in `order_executor.gd` and native's C++ seams; GRANT
> `game/ui/selection_markers.gd`, `game/ui/selection_panel.gd`, `game/ui/squad_chip.gd`, `game/ui/group_bar.gd`; the `inp` row;
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`. **Model:** Opus. **Machine:** builder3.
> **Seeds:** 13409-13504. Dev 7001-7006.

## The lead's direction (verbatim)

2026-10-30, on the group click: "Columns only at the end" (his pick; shipped ON as O1 v3, R47.41).

2026-10-31, on spotter's flagged clips: "For 100% cases that I've checked, it does in fact look dumb."

Memory: units must look smart and under his control; he rejects UI buttons and "cheating" visuals.

## Where things stand (main df9aacc1a GREEN builder3 3630/0)

- **ON:** the group click (`merged_mode` "all": 2-3 squads finish side by side; Crossing 14.0 v 39.4 m), the recipient cue, `inp` rows,
  the battery screen, the army cost cap (both sides 1000 credits).
- **Class D #17, reproduced by you** (builder3, e26a1bf7a, `make spotter-fights SPOT_MAPS=locks SPOT_SEEDS=13216`): Rust_Guns_2 FOLLOWs
  Rust_Guns_1 10-25 m behind at 11 m/s, then at 41-44 s the leader turns north and the follower REVERSES (-2.6 m/s) and spins (87 deg/s):
  `Orders.goal_of` puts the station at the leader's pose + slot turned by the leader's NOSE that instant, so a pivot swings the station
  round the leader. Candidate: the leader's smoothed heading of travel. It moves every follower (CPU and his): a bar.
- **Class D's other clips** (#23, #25, #13, #22, #28, #4): support-by-fire moves and slow movers. #13 / #22 are the CPU's assault plan
  (a firing spot 214 m across the map) and the element's transit pace, not your order layer: say so per clip, and send what is not yours
  to the orchestrator (engage / manoeuvre).
- **The group-click stall** (Bar O2's G2): wedging only on clicks laid as files, by map ON-OFF a click: sumps +61 / +82 crew-s (2 / 3
  squads), yard_open +22 / +18; Locks / Crossing / Terminus where the ground refuses the files.
- O7, his acceptance read of the click, not done.

## Backlog (in order)

1. **O1 the follow station by heading of travel**, ON (smallest change): a station that does not swing when the leader pivots in place.
   Tests first: a staged leader that turns 90 deg on the spot; the follower's speed never goes negative and its yaw rate stays under the
   leader's. **Bar F** filed before any number on 13409-13456: deciding = follower reverse-seconds and spin-seconds a fight, and class D's
   follow clips; guards = follow distance, arrival, contacts, the group-click probe rows, authority. Twin through native if the native
   drive reads the station (C47.6). Replay stamp entry in the same merge.
2. **O2 class D's per-clip owners:** each D clip at main df9aacc1a, with its cause and owner. Message the orchestrator the non-orders ones.
3. **O3 the Sumps / yard stall in the group click:** why files wedge on Sumps (+61 / +82 crew-s); the narrow fix (e.g. a file that can't
   lay falls back to the merged column before it wedges). Bar O3 on 13457-13504.
4. **O4 Crossing / Terminus where the ground refuses the files** (Locks 39.4 v 39.4: unchanged).
5. **O5 (O7) his acceptance read** of the group click on his recordings once they carry `inp` rows.

## How to verify

`make quick-remote` to iterate; `make remote T=check` for a hash you will NAME (read `>> remote: make check exited <N>` and `N passed, M
failed`). `make spotter-fights` / `make spotter-clip` to watch a case before and after; screenshots at desktop and phone aspect, looked at.
Spotter re-reads class D at the new main after your merge (C48.2). Every number with commit, machine, workload, n.

## Don't touch

engage's crew branches, RETREAT and target choice; movement / yield (manoeuvre); `native/**`; the planner and `pathing.gd`; `game/camera/**`;
`arenas/**`; `game/units/**`; `tests/baselines/**`; `tools/spotter/**`.

## Waiting on the lead

Nothing at launch.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
