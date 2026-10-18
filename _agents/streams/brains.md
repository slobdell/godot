# Stream: brains (respawns never overlap a standing hull; a pushed-off rig returns to its post facing his way; seats stop jumping without blocking a squadmate; the yard's last crew in)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/doctrine.md`,
> `_agents/workstreams.md` **Round 33** (C33.3, C33.4, C33.5; R32.3, R32.6 stand), `_agents/roadmap.md` *Round 33
> candidates*, `_agents/orientation.md` trip-ups 82–83, and your round-32 brief `streams/archive/round32/brains.md` (B10's
> and B11's tables and readings; *Not reached*: B5c-v6). **You own:** `game/ai/**` EXCEPT traffic's, manoeuvre's,
> native's and the planner's carve-outs (`workstreams.md` *Round 33* ownership), `game/tactics/**`, `tests/ai_scenarios/**`
> (others add their own `scenario_<stream>*.gd`), `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`,
> `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `tests/test_wheeled_arrival.gd`, `mk/ai.mk`,
> `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`. **Granted this round (C33.5):** the respawn spot in
> `game/match/match.gd` (`tank.respawn(_jittered(spawn_position(...)))` ~2128 and one helper beside it; merge note).
> **The C++ (C31.2):** `decide`, `build_situation`, TacticalQuery and `_approach_gate` run in C++; v6's side-gate mirror is
> on `pair/brains-v6-carry`. **Model:** Opus.

## The lead's direction

Round 24: every squad across his bridge (shipped, 108/108). Round 28: the gate's job is the yard's last crew in. Round 28,
call 2: turn the whole vehicle to his drawn facing. No new words at round 33's preparation.

What he will notice: a vehicle respawning never appears inside another one; a War Rig shoved off the spot he told it to
hold drives back and faces his way; a crew's spot stops jumping about while its squad jostles, without it parking in a
squadmate's path; at the yard the last crew gets in.

## Where things stand (main at the round-33 docs commit; inherits `0c124cf7`'s green check: builder0 exited 0, 2724/0)

- **Shipped in round 32:** B3b-2c (his bridge 108/108), R32.6's fix (the test stage's overlapping spawns, trip-up 82).
- **Respawns can overlap (your round-32 finding):** `match.gd` ~2128 respawns at `_jittered(spawn_position(...))` with no
  check against hulls standing near the slot; physics recovers from an overlap differently in a process's first match and
  later ones (trip-up 82), so a session's later matches can play differently.
- **B11 PARKED** (`--hold-return=faced`, OFF; `c029cf70`/`ffba7f77`): turreted wheeled faced_move 48.4 → 17.3°, but
  wheels/fixed worse (7.5 v 3.0°, p 0.000) and s66 Green_Guns_5 still > 100° (needs the face at rest: manoeuvre's CP-F).
- **B10 PARKED** (`--ground-latch=on`, OFF): flips 22 → 0 on Sumps s16 t8, but Sumps s19 t8 +19.9 s (the held seat stood
  in two squadmates' passage).
- **B5c-v6 not reached:** `lab/brains-r32-gate` `b8a34c4f` (v5 + side gate + the latch; tuning n 1: Sumps s17 t11 35.8 v
  34.8 s, yard s27 t8 10/10 v 9/10); native's mirror on `pair/brains-v6-carry` (33db0ac1 + ba8d18d9).
- Your round-32 branch is `round32/brains` (merged).

## Backlog (in order)

1. **R1 Respawns clear of standing hulls (C33.5):** the respawn takes the nearest clear spot to its slot (the hull's
   footprint v every standing hull's), deterministic for both peers; a test that fails without it (a big hull respawning
   beside a parked one), mutation-checked; a check; name the hash. A sim-baseline move goes to the orchestrator with the
   reason. Ships alone.
2. **R2 B10b (C33.4):** the latch held only while the latched point is out of a squadmate's route corridor (or one
   re-ground with hysteresis); one reason for the form chosen. Bar first: Sumps s16 t8 flips (pass case), Sumps s19 t8 time
   (the case B10 failed), the arrive series within 8 m not below base − 1.645 se, fresh seeds. Ships ON if it passes.
3. **R3 B11b (C33.3), once manoeuvre's CP-F merges:** HOLD's return honours the post's facing for `mount == "turret"`
   wheeled hulls only; judged on a base with CP-F ON; pass case s66 Green_Guns_5 ≤ 90° in ≥ 2 of 3; no class worse at
   p < 0.05; never-settled within its line. If CP-F has not merged when you reach this, do R4 first.
4. **R4 B5c-v6:** v5's gate + planner's side gate for yard s27 t8, on a base with B10b ON if it shipped (else main); the bar
   as round 32 wrote it (Sumps s17 t11 and yard s27 t8 the pass cases, pursuit as R31.3's count); traffic may send you T4's
   circling-hull trace (the same yard head-on): read it before the series.
5. **R5 If traffic's CP-X design chooses an element make-room (C33.2 (2)(b)):** the seam, signature agreed through the
   orchestrator before either side writes code; this pre-empts R4.
6. **Stretch:** T1c-b2's price (round 32): in 6 of 18 fights a mortar truck waited ~20 s behind ANOTHER set-up mortar truck
   of its battery and two set up 10–19 m short. A battery's firing spots chosen so one truck's spot is not behind another's
   set-up truck. Trace first; bar before numbers.

## How to verify

`make quick-remote` to iterate; the pair-tree `make remote T=check` with the switch ON before any series, only for hashes
you name. `make squad-arrive-series`, `bridge-series` (the 108), `bridge-pooled`, `screen-slots`, the
hull-rest drawn series (B11's), `native-verify-scenarios`. Long remote runs under `systemd-run --user`. Every number:
commit, machine, workload, n, its row. A test that builds a `TacticsLab` must `dispose()` it (trip-up 83).

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; manoeuvre's drive body / unstick / H1 / H1b / k-turn executor / face
path, `manoeuvre*.gd`, `wall_contact.gd`, the two gunnery lead lines, the `_order_move` decline; the planner's
`game/ai/planner/**`; native's `native/**`; `game/control/**`, `game/tank/**`; `game/match/**` beyond the respawn grant;
`arenas/**`; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

## Overnight (round 33 extension, 2026-10-18 ~00:45 PDT)

The lead has gone to bed and wants builder2 kept busy. Take these items in order (`workstreams.md` *Round 33, overnight
extension*; the details are in `roadmap.md` *Round 34 candidates*). Merge main first. builder2 FIRST (`make gcp-remote`,
6 heavy slots). Every judged stage pinned at `--fixed-fps $(SIM_HZ)`. A bar is filed (sent to the orchestrator) before any
number, judged on FRESH seeds, and every number labelled with its machine. Keep this Status current: the lead reads it in
the morning.

1. **The battery item:** three switches judged alone, its filed bar (native mirrors arrivedgate).
2. **A scout under fire fights back when it can't get away:** your design (roadmap). Bar first. It pairs with
   manoeuvre's C33.9, so judge it on a tree that has C33.9 if C33.9 has shipped, else say which.
3. **An element that never arrives because one crew still drives** (foundry s8, the War Rig 4-of-5 case): trace, then
   a candidate ("arrived when 4 of 5 are in their slots and the rest are stalled").
4. **A respawned crew rejoins its squad's living element when it has room** (R33.6's side effect, improved).
