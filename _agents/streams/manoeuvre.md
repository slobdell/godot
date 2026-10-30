# Stream: manoeuvre (his squad settles where he clicks; squads at a street mouth wait for the right one; a short move inside the turning circle)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 344, 345), `_agents/judging.md`, `_agents/workstreams.md` **Round 46**
> (C46.1-C46.8), your last brief `streams/archive/round45/manoeuvre.md` (ROUND 45 FINAL REPORT: S v4 / S v5, holdway A6 v4, shortfwd,
> backout's 75 %), R45.17, R45.20, R45.26, R45.28 in `workstreams.md`, and
> `references/round45/manoeuvre/barss5-builder0-fc639d7e0/README.md` (S v6's starting point). **You own:** movement's drive / unstick /
> side-step / avoidance / yield / backout (`game/ai/movement.gd` but the planner seam), `game/ai/traffic.gd`,
> `game/tactics/tactics_formation.gd`'s `pitch` / `hull_floor` / `offsets_at` / `fit_to_corridor` / seat bound / shape latch,
> `game/tactics/element_plan.gd`'s `grouped()` and converge, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`,
> `tests/test_traffic*.gd`, `tests/test_formation*.gd`, `mk/manoeuvre.mk`. NOT `element.gd` (engage's), NOT `game/control/**` (orders').
> **Model:** Opus. **Machine:** builder3 (builder0 a second light lane). **Seeds:** 12001-12048 (S v6), 12049-12096 (A6 v5),
> 12097-12144 (backout / shortfwd / reserve). Dev 7001-7012 (never a bar).

## The lead's direction

His standing asks this stream serves: his squad settles where he clicks (round 43: "units must look smart"); a War Rig backs out of
the box (shipped ON round 45). Round 46 brings no new words for this stream; it finishes the round-45 starting points so they can
reach his default game. Memory: units must look smart and under his control; contention first.

## Where things stand (main at launch: see HANDOFF; code 96f199c45 GREEN builder3 3470/0)

- **Shipped ON:** backout (R45.26; `--traffic-off=backout`). Missed 9 of 12 base-stuck poses' "sooner" only on exact ties (pose 10: a
  squadmate 1.7 m beside the rig, the back-up refused). Terminus pays ~3 s of k-turning a run (reported).
- **Seat bound S v5 FAILED (R45.28):** the settle is real (seated within the bound by 15 s 220 -> 329, +8.4 se) but Crossing's Battery
  squad yields to ITSELF (+9.85 s a run, cell 11751) and Locks wedged +3.37 s. Cause: the open seat + rear-crew term deal two-row
  layouts seats whose paths cross. S v6: the rear-crew term keeps S v4's lateral order.
- **Holdway A6 v4 FAILED (R45.20)** on guard 4 by -0.16 se (the judging table's closest line): the "ordered way" was the crew's next
  station (sideways at an order's first ticks). Fix: the squad's route tangent (as backout's look uses) + a tie rule (the squad whose
  lead is nearer the street's inside waits). One real bug fixed on main (fc639d7e0).
- **Shortfwd** (his short move inside a wheeled crew's turning circle drives forward, not back): parked, code on the branch.
- Every switch of this stream's new code is DEFAULT_OFF on main.

## Backlog (in order)

1. **M1 S v6 dev read on Crossing's Battery layout (11751's geometry, dev seeds):** the rear-crew term keeps the squad's lateral order;
   show no self-yield on Crossing and Locks wedged within noise BEFORE filing. Status first, then message the orchestrator.
2. **M2 Bar S v6** on 12001-12048 (filed before numbers; S v5's guards unchanged + Crossing yield+blocked and k-turn as named risks).
   Native twin EQUAL first (C46.4). Ships ON when it passes.
3. **M3 holdway A6 v5:** ordered way = the squad's route tangent at the crew, the tie rule; Bar A6 v5 on 12049-12096 (A6 v4's lines
   unchanged). Native twin. Ships ON when it passes.
4. **M4 backout pose 10:** the refused back-up beside a squadmate (a shorter first leg or a lateral look); and the Terminus k-turn
   seconds read by removal. Its bar on 12097-12120 only if the change is real.
5. **M5 shortfwd:** a bar on 12121-12144 using his Gorge recording's geometry (`references/round44/playtest/...gorge.jsonl`, the lone
   scout's 1-11 m moves) as the staged workload.
6. **Relay seat for engage's L2:** if engage asks (through the orchestrator) that an idle crew blocking a firing lane steps aside, it
   is yours to build in the yield code; it outranks M4-M5.

## How to verify

`make remote T=check` (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote`; `make manoeuvre-*`;
the B1 corpus and the default orders probe (60/60 byte-identical v main for any OFF code); top-down shots looked at. Every number with
its commit, machine, workload and n.

## Don't touch

`game/tactics/element.gd` (engage's), `game/control/**` (orders'), `game/ai/gunnery.gd` / `fire_lanes.gd` / `tank_brain.gd` (engage's),
`native/**`, `game/camera/**`, `tests/baselines/**`.

## Waiting on the lead

Nothing at launch. A bar that fails twice on the same fix: write in player terms what he would see and message the orchestrator
(lesson 339).

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Session start 2026-10-30 (Opus, `godot-manoeuvre`). Starting commit 7189e3ff3 (code 96f199c45 GREEN builder3 3470/0, the launch
check; not re-run).** Persistent evidence in `~/overnight-manoeuvre/r46/` on the laptop (never in a worktree's `build/`).

**Plan (in order):** M1 S v6 dev read -> M2 Bar S v6 (file before numbers) -> M3 holdway A6 v5 -> M4 backout pose 10 + Terminus
k-turn by removal -> M5 shortfwd. Item 6 (engage's relay) jumps the queue if it arrives.

### M1 S v6 (in progress)

- **Cause found (laptop, crossing 11751 S v5 arm, a temporary seat() trace, 6-12 s):** S v5's order term ranked the seats by their
  STATIONS (`at`, laid along the route). Battery's route bends east round the block; two stations swap sides as they slide (slot 3
  jumped x -23.9 -> -30.7 at a vertex), so the term re-dealt Battery_1 and Battery_4 back and forth tick to tick, the
  squadmate-yields R45.28 read. (The rank shift from the pinned deep seat was real too, but did not change this cell's deal.)
- **S v6 (659c9ab9b, OFF; `--seat-bound=on --seat-order=on --seat-last=open`):** under the open last seat the seats are ranked
  by the shape's own left-to-right offsets, and the deep seat + its rear crew are left out of the ranks. Test
  `test_seat_last_open_keeps_the_rest_of_the_squad_in_its_lateral_order` (11751's real positions and route): FAILS on S v5 (crossed
  order + a re-deal at s 24.2), PASSES on S v6; formation / seat / settle / element_plan tests 195/0 (laptop, 659c9ab9b). Laptop trace:
  the Battery's seating now holds for the whole first order.
- **Dev read (DONE; 659c9ab9b, builder3 light, `native-fresh` first, `manoeuvre-bar-s` 20 s, crossing / locks / terminus x 7001-7012 =
  36 paired runs, 0 SCRIPT ERROR; `~/overnight-manoeuvre/r46/dev_s6/judge.txt`):** D1 seated within the bound by 15 s 141 -> 187 (+1.28
  a run, +4.9 se). Per arena (paired a run, se): yield+blocked crossing +3.75 (+0.8 se), locks +0.97 (+0.5), terminus -4.90 (-2.4);
  k-turn crossing +1.98 (+1.2), locks -1.98 (-1.7), terminus -10.2 (-4.0); **wedged crossing -4.13 (-1.0 se), locks +1.00 (+0.5 se)**,
  terminus -3.41 (-1.7). Never-arrived 99 -> 74 (-0.69 a run, se 0.30); seat moves 1652 -> 810. **A squad giving way to ITSELF
  (START_YIELD rows, asker and yielder in one Green squad): crossing 43 -> 29, locks 22 -> 11, terminus 47 -> 58.** For comparison
  S v5's dev read (R45.20, older commit): crossing yield+blocked +1.7 se, Locks wedged -0.5 s a run, Terminus wedged +8.0 s.
  **M1 condition met: no added self-yield on Crossing, Locks wedged within noise.** -> M2: Bar S v6 filed below BEFORE any 12001 number.

### M2 Bar S v6 — FILED (2026-10-30 ~01:40 PDT, before any number on 12001-12048; stream/manoeuvre, this commit)

**Bar S v6, his first squad settles where he clicks (manoeuvre M2; R45.28's round-46 starting point; C46.1, C46.3, C46.4, C46.6).**
Bar S v5's shape and lines stand unchanged; only the code under the same arm flags changed. ONE arm, **s6** = `--shape-latch=off
--seat-bound=on --seat-order=on --seat-last=open` v **base** = `--shape-latch=off` (today), on a FROZEN tree = stream/manoeuvre at
the hash whose `make remote T=check` reads exited 0 (named at launch), native ON in every log (`native-fresh` first). **What changed since
S v5 (C46.1):** under `--seat-last=open` the order term ranks the seats by the SHAPE's own left-to-right offsets, not by their route
stations, and leaves the deep seat and its rear crew out of the ranks (659c9ab9b; R45.28's cause, found as station rank flips on a
bending route). **C46.4:** the change is planner-side GDScript (`TacticsFormation.seat`); the drive is unchanged and twinned, so no new
twin is needed (as R45.20 ruled for S v5); the default orders probe 60/60 byte-identical v main proves OFF unchanged. **What it could
break (named first):** Crossing yield + blocked (S v5's miss; dev +0.8 se) and Crossing k-turn (S v5 +2.1 se; dev +1.2 se); Locks wedged
(S v4 / S v5's miss; dev +0.5 se); a squad yielding to itself on Terminus (dev rows 47 -> 58, its yield+blocked -2.4 se); the G1 group
column (byte-identical by scope, R43.34). **Workload (deciding), `make manoeuvre-bar-s`:** locks / terminus / crossing x **12001-12024**
= 72 paired cells, 20 s; `tests/manoeuvre/s_judge.py` paired per cell. **D1** crews seated within the bound 15 s after their order ARM >
BASE by >= 2 se AND pooled. **Guards, per arena (24 seeds each), each ARM <= BASE + 2 se:** start-zone yield + blocked s; k-turn s;
wedged s; and never-arrived pooled ARM <= BASE + 2 se. **Group guards (`q3_judge.py`), 12025-12036 x crossing / locks / sumps / terminus x
crew:** G5 all-in ARM <= BASE + 1.645 se, G6 never-in ARM <= BASE + 1.645 se, G7 friendly contact ticks ARM <= 1.05 x BASE. **G1 v9
corridor, 12025-12036:** `orders-probe` locks / crossing / terminus x 5 squads x click: ORDERS_PROBE_SQUAD rows byte-identical base v s6,
`orders_judge.py g1v8` lines each ARM <= BASE + 2 se. **Fights (`manoeuvre-wedge-trace` locks / terminus / sumps x 12037-12042), G1-G4
as Bar S** (G4 kill share worst move <= 0.03: S v4's miss, S v5 at 0.029). **No SCRIPT ERROR** in any leg. **Perf:** the frozen tree's
check (builder3: perf NOT JUDGED there; a builder0 perf read of the merge before ON). **Ships ON** (`SEAT_BOUND`, `SEAT_ORDER`,
`SEAT_LAST_OPEN` default on; `--seat-bound=off` / `--seat-order=off` / `--seat-last=bound` the escapes) only if D1 and every guard pass.
C46.6: the bound seats any squad on its own order (the CPU's too). **Machine:** builder3 light, `~/overnight-manoeuvre/r46/bars_s6.sh`
from a frozen worktree of the hash; evidence filed under `references/round46/manoeuvre/barss6-builder3-<hash>/`. **Dev history (never a
bar):** the M1 dev read above (7001-7012).
