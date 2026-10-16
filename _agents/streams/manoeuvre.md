# Stream: manoeuvre (a vehicle pinned on a squadmate that never moves goes round or settles instead of looping; wheeled turret vehicles turn their hull to his facing AND settle)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 28 direction* (his call 2: turn
> the whole vehicle), `_agents/judging.md` (R31.8: no early stop on guard lines), `_agents/workstreams.md` **Round 32**
> (C32.2, C32.5, C32.8) and *Round 31* (C31.4, R31.1, R31.2, R31.5), `_agents/roadmap.md` *Round 32 candidates*, and your
> round-31 brief `streams/archive/round31/manoeuvre.md` (CP-H's bar and tables, the seed-31 trace, M1b(2)'s two attempts;
> tables under `references/round31/manoeuvre/`). **You own:** in `game/ai/movement.gd` the body of `drive()`, `_nose_stop`,
> `unstick`, `_pressing_escape`, H1 (`unstickback`), the k-turn / planned-reverse / circle block's EXECUTOR (`kturn_on`
> through `_look_stop`, `_kturn_start_leg`, `_planned_reverse`), NOT its plan source (the planner's seam, R31.2);
> `game/ai/manoeuvre*.gd`, `game/ai/clothoid.gd`, `game/ai/wall_contact.gd`; in `order_controller.gd` the face-at-rest path;
> `tests/test_manoeuvre*.gd`, `tests/test_kturn*.gd`, `tests/manoeuvre/**`, `tests/ai_scenarios/scenario_manoeuvre*.gd`,
> `mk/manoeuvre.mk`. **Granted:** the two aim-lead lines in `gunnery.gd`; `TankBrain._order_move`'s decline for wheeled
> turret hulls under `turnhull` (C31.8). **The C++ (C31.2):** the drive, unstick, the k-turn executor and gunnery's leads have
> C++ twins; send native each settled diff before its commit. **Keep counters off `Movement` statics** (round 31: one
> broke the twin; use `ManoeuvreCensus`). **Model:** Opus.

## The lead's direction

Round 28, call 2: turn the whole vehicle to his drawn facing (`game_design.md`). Round 31 shipped what he asked for a
wedged hull: it backs out instead of grinding. The known issue he was told about: **when the squadmate in the way never
moves, the pinned vehicle loops (ask, back 2–3 m, drive back in, about every 21 s) instead of going round.** He may see it.

What he will notice: a vehicle stuck behind a squadmate that won't budge drives round it or stops short and reports,
instead of nudging back and forth; a wheeled IFV or gang tank told to face a direction turns its hull there and then sits
still.

## Where things stand (main at the round-32 docs commit; inherits `e66b41f1`'s green check: builder0 exited 0, 2657/0)

- **CP-H is ON** (H1 `unstickback`, H2 `kturnarc`, H3 `realspeed` + brains' `realslow`): pinned crew-s at rest 3106 → 333,
  stuck 6578 → 3737. R31.5: hull pins get ask → straight reverse ≤ 3 m by the sweep → stand and report; pins with no hull
  take round 29's escape bit for bit.
- **The H1 loop (Terminus seed 31's last leg, shipped CP-H):** Green_S0_4 ends 9.1 m short touching Green_S0_2; asks 29,
  backs 29, all hull pins, refused 0. The friend's "pinned" ask never moves Green_S0_2. Clip:
  `~/projects/clips/round31/manoeuvre_rig_wedge_today_v_shipped_seed31_25c7421b.mp4`.
- **CP-P1 is ON:** hulls ≥ 10 m take the planner's legs (PlannerExecutor, R31.2); `last_refusal` and your handover
  counters `esc_after_refusal`, `refusal_then_free` (on ManoeuvreCensus) read live now.
- **M1b(2) PARKED** (attempt 2 `25ef8f7e`, the 'sector' lift): the hulls DO turn (wheeled turret at rest: move 46.5 → 2.5°,
  attack-move 45.0 → 3.8°; gang_ifv 37 → 62 % within 15°), but crews still moving at 75 s under attack-move +13 v a bound of
  11.2, and Terminus mixed arrivals 293 → 285, where the "misses" COMPLETED at slots the element re-seated 7–14 m off.
  facekeep refusals 11 997 in the new arm.
- Your round-31 branch is `round31/manoeuvre` (kept, not merged).

## Backlog (in order)

1. **H1b, the ask that never frees (C32.2).** Behind `--nav-off=h1b` (opt-in per R31.1 until judged). After N failed asks
   on the SAME blocker (pre-register N and what "failed" means: e.g. the blocker's real displacement < 0.5 m between asks),
   re-path round it (a temporary obstacle for that hull's route) or complete short and report; never re-drive into it.
   Test first: seed 31's last leg as a scenario that fails today. Bar to the orchestrator before numbers: seed 31 loops 0;
   CP-H's hull-rest pinned/stuck rows and nav-terminus-drive's PINNED/STUCK rows not worse (base + 1.645 se); Terminus
   arrivals (rigs and mixed apart) not down; fights within 1.645 se; R31.5's terrain fallback and `test_nav_wall_contact`
   unchanged; the whole suite on native's pair tree. Ships ON as a pair.
2. **M1b(3), turn the hull, settled (C32.5).** Before any number: agree with brains, in writing through the orchestrator,
   (a) whether an arrivals line counts "completed at a re-seated slot" as arrived (brains owns the re-seat), and (b)
   whether facekeep changes for gang hulls. The orchestrator records it as a ruling. Then solve the attack-move settle (the
   moving-at-75-s line) with attempt 2's turn kept; one bar, fresh seeds, one hull-rest arm per remote call.
3. **Test splits (C32.8):** after native's four, your files over ~60 s in `tests/shard_times.txt` (`make test-times` first).
4. **Stretch:** the C++ parity of anything you ship goes to native; a clip of seed 31 before/after H1b for him
   (`make manoeuvre-pin-clip`).

## How to verify

`make quick-remote` to iterate; `make remote T=check` on the pair tree with the switch ON before any series (C31.1), only
for hashes you name. `make manoeuvre-hull-rest` (one arm a call), `manoeuvre-fights`, `manoeuvre-census`,
`nav-terminus-drive` + `pinned_table.py`, `bridge-pooled`, `native-verify-scenarios`, `scenario_cp2`,
`test_tactics_mixed_legs`, `test_nav_wall_contact`. Long remote runs under `systemd-run --user`. Every number: commit,
machine, workload, n, its table row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; the planner's `game/ai/planner/**` and plan source; brains'
`_track_progress`, `_update_phase`, `_approach_gate`, the re-seat, elements, `game/tactics/**`, `tank_brain.gd` beyond the
granted decline, `gunnery.gd` beyond the two lead lines; native's `native/**`; `game/tank/**`; `game/control/**`;
`tests/baselines/**`; `tools/judge/**`. `origin` holds an old `stream/manoeuvre`: don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n and its row; bars to
the orchestrator before numbers; green hashes named)_
