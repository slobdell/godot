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

### REPORT — Bar S v6 FINAL (02:49 PDT): FAILS as filed on FOUR lines; stays OFF; the ON recommendation WITHDRAWN

All legs read (evidence `references/round46/manoeuvre/barss6-builder3-4e72c5470/`): group G5-G7 identical PASS; G1 corridor 180 / 180
byte-identical PASS; fights G1-G3 PASS; **fights G4 kill share worst move 0.040 (line 0.03) FAIL** (Green 0.529 -> 0.489, 18 fights; S
v4's old miss); 0 SCRIPT ERROR. The orchestrator's condition (R46.15: ON only if the last legs pass) withdraws the recommendation.
Ship candidate `wip/manoeuvre-seat-on` e8051bbde stays ready if he says yes anyway. Frozen tree removed (lesson 341).

#### The deciding leg (read 02:35, before the other legs)

**Bar S v6** (frozen 4e72c5470 GREEN builder3; 12001-12024, 72 paired cells, native ON, 0 SCRIPT ERROR;
`~/overnight-manoeuvre/r46/bars_s6/judge-workload-early.txt`): **D1 seated within the bound by 15 s 249 -> 352 (+1.43 a run, +7.9 se)
PASS.** Wedged per arena crossing -2.24 (-1.0 se), locks +2.58 (+1.8 se), terminus +0.35 (+0.2 se): **PASS (S v4 / S v5's miss is
gone)**. Never-arrived 194 -> 149 PASS. Terminus every line better (yield+blocked -5.2 se, k-turn -6.6 se). **FAIL:** crossing
yield+blocked +5.95 s a run (+2.1 se; S v5 +4.1 se), crossing k-turn +2.48 (+2.6 se), locks yield+blocked +2.84 (+2.2 se).
**Cause read (START_YIELD rows, Green crews):** the squad no longer gives way to ITSELF (same-squad rows crossing 80 -> 60, locks 52 ->
24: fewer than today); what rises is squads giving way to EACH OTHER (Guns <-> Hunters crossing 46 -> 77, locks 35 -> 59): squads that
now settle compactly at their clicks sit in the neighbouring squad's way out of the start zone.
**In his terms (lesson 339: the seat bound's second failed bar):** with it ON, the squad he orders settles at his click (about 1.4 more
crews a run seated within 15 s), no crew gives way to its own squadmates any more and nothing wedges; but on Crossing and Locks, while
squads leave the start, one squad stops to let the next squad's crews by a little more often: about 3-6 s more waiting a run, and on
Crossing about 2.5 s more three-point turning. On Terminus everything is better. **Stays OFF**; the ON/OFF call is his (sent to the
orchestrator).

**Session start 2026-10-30 (Opus, `godot-manoeuvre`). Starting commit 7189e3ff3 (code 96f199c45 GREEN builder3 3470/0, the launch
check; not re-run).** Persistent evidence in `~/overnight-manoeuvre/r46/` on the laptop (never in a worktree's `build/`).

**Plan (in order):** M1 S v6 dev read -> M2 Bar S v6 (file before numbers) -> M3 holdway A6 v5 -> M4 backout pose 10 + Terminus
k-turn by removal -> M5 shortfwd. Item 6 (engage's relay) jumps the queue if it arrives.

### M1 S v6 (DONE)

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

### M3 holdway A6 v5 — dev reads, then FILED (2026-10-30 ~02:35 PDT, before any number on 12049-12096)

- **Dev read 1 (f6a91735f, builder3 light, A6 v4's spent seeds 11449-11472, n 24): byte-identical to round 45's dev read.** Cause: the
  hold probe's squads run DRILL moves, which have no transit anchor, so the squad way fell back to the station way every tick.
- **f91c6cf84:** a squad with no transit reads the crew's own navmesh path to the SQUAD's destination (found once per order, read at
  its nearest segment). Laptop 11466 (A6 v4's worst head-on cell): far contacts 0 -> 0 (A6 v4 0 -> 32).
- **Dev read 2 (f91c6cf84, builder3 light, native, 11449-11472, n 24; `~/overnight-manoeuvre/r46/a6v5_dev2/table.txt`) against A6 v4's
  lines:** deciding side jam_s 397 -> 78 (-26.6 a run, z -5.4) PASS; 1 off_arrive_s (side) -11.8 a run PASS; 2a head-on verdicts +0.25 a
  run (se 0.13, z 1.91; line +/- 2 se) PASS at the edge; 2b held_on_s -2.2 a run PASS; 3 contacts_mouth -1.83 a run (z -0.38) PASS;
  **4 contacts_far 9 -> 24, +0.62 a run (se 0.47; line max(1.645 se, 2) = +2) PASS** (A6 v4 +2.54, FAIL); 5 last_a_s -1.9 PASS. Left:
  11464 (locks_lock) 0 -> 11 and 11458 3 -> 6, each with a second verdict.
- **The tie rule: DROPPED (decided, reversible).** The verdict trace on builder3 (a temporary print, removed) shows Locks' head-on
  first verdicts are EXACT ties in BOTH arms (11458 6.94 v 6.94 s base, 6.84 v 6.81 s holdway), decided the same way (the id rule);
  the extra far contacts come from a later re-verdict (11458 f1770), not from a tie decided differently. A tie rule would change
  today's ties too, which is not holdway's change (lesson 348: the smallest change). Round-47 note if guard 2a fails: the re-verdict
  after a wait ends.

**Bar A6 v5, the street hold decided on where the SQUAD is going (manoeuvre M3; R45.20's round-46 starting point; C46.1, C46.3, C46.4,
C46.6).** Bar A6 v4's shape and lines UNCHANGED (workstreams.md *Bars (round 45)*): ONE arm, **ARM-W** = `--traffic-on=holdway` v BASE
(today), on a FROZEN tree = stream/manoeuvre at the hash whose `make remote T=check` reads exited 0 (named at launch), native ON in every
log (`native-fresh` first). **What changed since A6 v4 (C46.1):** a crew's ordered way is its SQUAD's way where it stands: the nearest
segment of `Element.transit`'s route, or for a squad with no transit (a drill move) the crew's own path to the squad's destination,
found once per order (f6a91735f + f91c6cf84); A6 v4 read the crew's next station. No tie rule (above). **C46.4:** the street hold is
Traffic's GDScript, read by both drives (no C++ copy exists; A6 v4 ran the same way); native confirms before the freeze or the bar says
"native path unchanged". **Workload:** `make engage-hold` (odd seeds side-street, even the three head-on stages), **12049-12072**, n 24
paired, 75 s, builder3 light; Bar E1's lines (`make engage-probe`, ARM `ENGAGE_FLAGS=--traffic-on=holdway`) on **12073-12096**.
**Deciding:** jam_s on the side 12 ARM < BASE by >= 2 se (paired) AND pooled ARM < BASE. **Exercised floor:** 8 of 12 side seeds with a
verdict in BASE, else INCONCLUSIVE. **Guards (A6 v4's):** 1 off_arrive_s (side 12) ARM <= BASE + 2 se; 2a verdicts (head-on 12) within
BASE +/- 2 se (**the named risk: dev z 1.91**); 2b held_on_s (head-on 12) ARM <= BASE + 2 se (one-sided); 3 contacts_mouth (24) ARM <=
BASE + 1.645 se; 4 contacts_far (24) ARM <= BASE + max(1.645 se, 2) (A6 v4's miss; dev +0.62); 5 last_a_s (24) ARM <= BASE + 1.645 se;
6 Bar E1's lines (stuck crew-seconds, first hit, deaths each within BASE +/- 1.645 se); 7 the frozen tree's check (perf NOT JUDGED on
builder3: a builder0 read of the merge before ON); 8 no SCRIPT ERROR. **Ships ON** (`holdway` out of `Traffic.DEFAULT_OFF`,
`--traffic-off=holdway` the escape) only if the deciding line and every guard pass. C46.6: the hold reads any squad's way (the CPU's
too). **Machine:** builder3 light, `~/overnight-manoeuvre/r46/bars_a6v5.sh` from a frozen worktree; evidence filed under
`references/round46/manoeuvre/barsa6v5-builder3-<hash>/`. **Dev history (never a bar):** dev reads 1-2 above (11449-11472, spent).

### Series running (2026-10-30 ~02:40 PDT)

- **Bar S v6: frozen 4e72c5470 GREEN builder3** (`>> remote: make check exited 0`, 3474 passed / 0 failed, sim-baseline unmoved, perf
  NOT JUDGED on builder3; `~/overnight-manoeuvre/r46/check/check-4e72c5470.log`). Series launched 02:25 on builder3 light from
  `../godot-manoeuvre-s6` (`bars_s6.sh`; evidence `~/overnight-manoeuvre/r46/bars_s6/`). Recorded on main 6ae7775a6.
- **Bar A6 v5: frozen 97403a089** in `../godot-manoeuvre-a6`; its full check runs on **builder0** (builder3 holds S v6; the orchestrator's
  go), then the series on builder0 light (`check_a6.sh` -> `bars_a6v5.sh`). Native confirmed (C46.4, code read of 97403a089): the street
  hold has no C++ copy; both drives call back into the GDScript `Traffic.refresh` / `hold_of`, so no twin. Recorded on main 3098180d3.
- Disk (lesson 341): ~/overnight-manoeuvre r39-r45 rows deleted (2.3 G freed; judge/table/driver files kept in
  `~/overnight-manoeuvre/summaries-r39-r45.tar.gz`); each frozen tree is removed the hour its series ends.

### M4 backout follow-ups (read; no bar: the pose-10 fix is not a small change)

- **Pose 10 (Bar B3's three ties), traced at 335d6160d, builder3 light, C++ drive (`NOSED_SEEDS=11701-11748 NOSED_ONLY=11711
  NOSED_TRACE=on`; `~/overnight-manoeuvre/r46/m4/trace2-wrapper.log`):** both arms never clear in 12 s (clear -1, contacts 106, first
  reverse t40 in both). ON: the look fires (departure 43 deg off), the forward arc hits the box at 1.0 m, and the reverse search is
  "blocked at 2.0 m back (hull)": the search reverses on FULL LOCK, so the tail swings into the squadmate 1.7 m beside it; with no room
  for the back-up the look plans nothing and hands back (fallbacks 3) -> exactly today's drive (the tie). **The fix it needs:** a
  straight (or opposite-lock) first reverse leg, then the arc. A planned leg is driven on the plan's one lock (`cmd.turn =
  _kturn_turn` for every leg), so this is a per-leg turn in the drive's state: a C++ twin change (C46.4) for three tied cells of 48. Not
  built this round; a round-47 candidate (native's per-leg `turn` field first).
- **Terminus k-turn seconds by removal (335d6160d, builder3 light, terminus x 7001-7012, today v `--traffic-off=backout`, 12 paired;
  `~/overnight-manoeuvre/r46/m4/kturn/judge.txt`):** backout costs **+4.45 s of k-turning a run (+4.1 se)** and saves yield+blocked
  -4.9 s a run (-1.8 se); wedged -1.3, never-arrived -0.58 a run. **It is not the backing rigs:** rows with a k-turn live per crew
  (summed over 12 seeds) Guns_5 (the Resupply Tanker) 125 -> 471, Guns_4 (the Gun Truck) 313 -> 454, while the rigs Guns_1 / _2 / _3 move
  474 -> 464, 398 -> 428, 359 -> 320. The crews BEHIND the rigs turn to make way for them. Reported (as B3 did), not a line.

### M5 shortfwd (corpus built; waiting on native's twin before the bar)

- **His geometry:** `make replay-match RECORDING=references/round44/playtest/2026-10-29T09-35-51-gorge.jsonl REPLAY_SECONDS=105
  "REPLAY_FLAGS=--trace=2505-3080"` (builder3) posed the lone scout (Green_Hunters_5) at each of his seven move clicks (83.7-102.6 s):
  10.7-29.5 m, 21-158 deg off the nose; two are inside the rule's reach (83.7 s: 11.5 m / 91 deg; 87.0 s: 12.4 m / 32 deg).
- **Corpus (51e9eacc4):** `make test FILTER=short_move SHORT_CORPUS=on SHORT_SEEDS=a-b [SHORT_ONLY=s]` stages each pose at rest on Gorge,
  jittered by seed, both arms; SHORT_ROW rows (reversing ticks, metres away from his click, arrival tick, metres off the navmesh,
  shortfwd ticks). **Dev 7001-7007 (builder3 light, one cell a pose):** pose 0 OFF reverse 28 ticks / 2.3 m away / arrived t62 v ON 17
  / 0.8 m / t49; poses 1-6 identical in both arms; off-navmesh identical. **ON runs the GDScript drive** (`native_drive: false`: the rule
  is untwinned), so a fair bar needs native's twin first (C46.4). **Requested from native directly (02:40).**
- **Bar plan (to file once the twin is EQUAL, before any number):** 12121-12144; pose mapping concentrated on the two in-reach poses for
  the deciding block, the other five as guards (identical or no worse).

### Requests to other streams

- **native:** the C++ twin of `shortfwd` (M5); sent 02:40.

### Ship candidate for S v6 (his call; the orchestrator takes it to him, R46.15)

- `wip/manoeuvre-seat-on` **e8051bbde** = stream/manoeuvre e3a3133e7 + one commit: SEAT_BOUND / SEAT_ORDER / SEAT_LAST_OPEN default ON
  (`--seat-bound=off` / `--seat-order=off` / `--seat-last=bound` the escapes), the two default tests flipped. Its builder3 check is queued
  behind orders' (`~/overnight-manoeuvre/r46/check_on/`). The sim baseline WILL move (CPU squads seat too, C46.6): the orchestrator
  re-records it if he says yes.
