# Stream: manoeuvre (a crew wedged between friends gets out; fewer crews left sitting behind their squad)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 36** (C36.1, CP36.1,
> C36.3) and in *Round 35*: R35.64, R35.66 (the joint), R35.67, R35.76 (X1(d) traced), R35.78 (X1b: W1b dropped). Then your round-35
> brief `streams/archive/round35/manoeuvre.md` (its Status is the close-out) and brains' `streams/archive/round35/brains.md` (X4a: the
> released crews that never rejoin are wedged; the net-motion mover rule). Evidence on `round35/manoeuvre`:
> `references/round35/manoeuvre/x1d-trace/README.md` (the trace, design (A)–(D), the stallnet bar draft), `joint3-series/`, `w1-trace/`.
> **You own:** the `drive()` body, `_nose_stop`, `unstick` (and its stall clock), `_pressing_escape`, the k-turn executor, H1/H1b,
> W1c's stall intent, the face-at-rest path in `order_controller.gd`, the `_order_move` decline for wheeled turret hulls,
> `game/ai/manoeuvre*.gd`, `tests/manoeuvre/**`, `tests/test_manoeuvre*.gd`, `mk/manoeuvre.mk`, additive fields in
> `game/control/screen_playtest.gd`. You may copy brains' read-only readers (`tests/tactics/mover_kind.py`) into `tests/manoeuvre/`.
> **Model:** **Fable** (this is the lingering problem: the wedged crew has been the biggest avoidable loss since round 34).
> **Machine:** builder0 (C36.1); light runs on either builder.

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. For round 36 he chose "use the agents' list" (2026-10-20).
From his playtests across rounds: a crew sitting idle and stuck while its squad has moved on is the thing he notices most.

What he will notice: a tank jammed between two friendly tanks at a choke backs out or finds a way within a few seconds instead of
rocking for a minute; fewer crews left behind, sitting still, when the squad has gone on.

## Where things stand

- **Round 35 shipped M5** (a War Rig told to face a way turns there and goes still) and the joint W1c + T9 lands at **CP36.1** (his
  yes): attack-move crews that never settle 48 -> 23, crews 25+ m off their goal 105 -> 59 (joint3 series, builder0).
- **W1b is dropped (R35.78):** X1b read SITTING DUCK (a held still wheeled hull takes ~2x the hits); T8 (traffic) is the answer.
- **X1(d) traced (R35.76):** the choke wedge's stall clock reads REAL velocity, but resets on any one tick >= 0.8 m/s; the contact pops
  ~once a second (one tick 8.5–9.9 m/s, net <= 0.1 m in 10 s), so the clock reaches 0.73–0.99 s and is zeroed just short of 1.0 for
  ~50 s. Rocking crews (`rocking_census.py`, joint3 hull-rest, 768 runs an arm): base 6, joint ON 3.
- **The left-behind crews (Bar E1, brains):** 9 of the 17 crews left > 25 m behind in E1's new arm were still wedged at the judge
  (law-605 Eyes_4, law-607 Guns_6, gangs-602 Hunters_3 traced; law-705 Eyes_3, law-711 Guns_7 never moved after release). X4b (did the
  joint free them?) was never run: it is your S2.
- **Measurement rule (brains, X4a):** count movers by NET motion (closing + wander in `mover_kind.py`), never `real_mps` alone: a
  wedged hull rocking reads >= 0.3 m/s.

## Backlog (in order)

1. **Carry over (C36.1):** after CP36.1, `git merge main`, then bring across from `round35/manoeuvre` what main lacks and you need
   (the STALL_TRACE probe `248e7495c` as measurement-only code, `rocking_census.py`, `fight_census.gd`'s exposure lines, the judges).
   Read `git diff main...round35/manoeuvre` first; W1c and the stall-intent tests arrive through the joint.
2. **S3 delete W1b (R35.78), first because it's small:** WHEEL_HALT and its tests out of GDScript; native deletes its inert mirror
   in the same pair (send native the commit). Switch-OFF inertness: sim-baseline unmoved (it was default OFF).
3. **S1 stallnet (C36.3), the bar draft in x1d-trace/README.md, filed in workstreams *Bars (round 36)* before any number:** the
   stall clock resets on NET motion from where it started (> STUCK_NET_M 0.5 m), routed move_to on the honest path only, behind
   `--nav-off=stallnet` (default OFF until judged); native mirrors `_stuck_from` (send native the spec). The DECIDING line is the
   deterministic lab stage `test_manoeuvre_stall_net` (a hull driven into a one-hull gap between two parked friends of another
   element; ON escapes within 3 s, base never in 20 s, both paths); the series lines are guards (no harm) on FRESH seeds; movers by
   net motion. A pass ships ON.
4. **S2 the left-behind crews after the joint (X4b, then the fix):** on a main with CP36.1 (and S1 if it shipped), re-run Bar E1's
   left-behind read (faced_attack_move + faced_move, fresh seeds, 4 factions, builder0 native) and REPORT: how many crews > 25 m behind
   at the judge, and how many of those are wedged (net motion). Trace the worst three. Then a design note to the orchestrator, and
   only then a bar. Expect the cause to be several mechanisms; name each with its count before choosing one.
5. **Stretch: R34.16's watch item** (one 9.1 m both-planned face) if a native clicked face_pairs pair runs.

## How to verify

Lab stage first (it is the deciding line); `make quick-remote`; one full check at a time a builder; series pinned, fresh seeds.
Every number: commit, machine, workload, n. Smoke like a player: `make skirmish ARENA=locks`, send two squads through the lock
together, and look at the screenshots for a crew rocking between friends.

## Don't touch

Traffic's give-way block and `traffic.gd`, orders' paths, brains' paths (no owner, C36.6: ask the orchestrator for a grant),
`native/**` (send native specs), `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-20 ~21:00 (worker): S2a + yieldgap GREEN, merge here: `32ba4ca99`** (pair/native-s2a-yg; both default OFF): builder0
`make check exited 0`, 2967/0, 25 passed + 2 NOT JUDGED (load), sim-baseline 13/13 unmoved; h1b_side 3/3, native yield 13/0.
Merged into the stream as `b3a42e018`. `tests/manoeuvre/s1_judge.py` (`e4ad75a9b`) reads Bar S1's series.

**2026-10-20 ~23:00 (worker): S4 (new, the orchestrator's: orders' turn-around LOOP squads): traced, split, note + Bar S4 filed**
(`references/round36/manoeuvre/s4/README.md`). builder0 light, 55c973cd4 + probe-only `lab/s4-trace` (c5fedd42c), GDScript path
(away_m equals orders' native numbers), 16 runs covering 16 of the 19 LOOP squads. Neither named loop is the drive. Locks s3624 Bravo_1 is traffic's
street hold (spot 35 m away across the lock); Terminus s3623 Bravo_4 is a give-way, ~22 m. Metres away (worst crews): give-way 196,
route after a give-way, hold or k-turn 96, FRESH route 100 (mine), k-turn 39, hold 32, escape 9. Give-ways: 124 of 172 from crews <= 10 m from their seat, 44 of them
sent >= 10 m from it; T7 lane for the asker in 22 of 124. That part goes to traffic (T10, via the orchestrator). Mine: 10 fresh episodes, goal 130–180 deg off
the nose, 5–11 m away. Proposal "back in" + lab stage (away_m deciding) + series guards (friendly contacts not up). Next: build the lab stage
and the rule behind a switch (OFF); no series until S1's and S2a's are done.

**2026-10-20 ~21:40 (worker): S1 series running** (builder0, ON arm: wedge + fights done, both exited 0; jam, then the base arm, then
hull-rest). T8 shipped as main `3d46b2884` (a crew holds in a take-turns hold until hit). The series stays on its two trees as filed.
**If S1 passes, the hand-over merges main (T8) FIRST**, because T8 changes fights. Next: judge it (`s1_judge.py`), re-read X4b (C)'s 6 crews on the ON arm, then S2a's
series.

**2026-10-20 ~20:15 (worker): S1's gate PASSES (C31.1), and the S1 series is launched.** ON tree `lab/s1-on` `d9864ab07` on builder2
(moved there by the orchestrator): `make native check exited 2`, 2961/0, 24 passed + 2 NOT JUDGED + sim-baseline the one red
(foundry, crossing, sumps, docks moved; 9 unmoved). Attribution = base `20acbda5f` (STALL_NET_DEFAULT false), read 13/13 unmoved by
native's builder0 check. Series: unit `manoeuvre-s1series`, builder0 after its checks clear, logs `~/overnight-manoeuvre/r36/s1/`.
Before the series started, both trees got one identical probe-only commit, in tests/manoeuvre only: WEDGE_TRACE / FIGHT_CENSUS
print `stall_net_holds` (the bar's counter-first line had no printer) and the run's unstick fires. Series trees: ON `78a93fdb4`, base
`9564cc66e`. Also fixed `3505cfb8d`: my 793ef5799 merge left diff3's base section in OFF_NAMES (a parse error on the stream branch
only; main took 20acbda5f).

**2026-10-20 ~19:15 (worker):** S1 + S3 are on main (5d6bb1de8, R36.5); main is merged into the stream (`4685fe5a4`). S2a +
yieldgap quick-remote on native's `8e6a52fc9` (builder0): 134/1, h1b_side 3/3 (native default arm = GDScript; ON past at 19.6 s,
one-hull street stands), traffic's long-hull tests PASS. The one red was native's own yield twin (it read a freed hull), fixed in
`32ba4ca99`, which becomes the S2a pair's full-check hash. builder0 queue: my S1 ON-tree check, then the S1 series.

**2026-10-20 ~18:45 (worker): S1 + S3 GREEN, merge here: `20acbda5f`** (pair/native-s1s3-main: S1 stallnet default OFF + S3 W1b
deleted + native's mirrors + main e45bb6632). builder0 `make check exited 0`: 2961/0, 25 passed + 2 NOT JUDGED (load),
sim-baseline 13/13 unmoved. Merged into the stream as `793ef5799`. Native cut the S2a mirror as `pair/native-s2a` `18bc084c9`, which
I reviewed; with traffic's yieldgap on top it becomes `8e6a52fc9` (quick-remote next on builder0).

**2026-10-20 ~18:15 (worker): S2a built (the orchestrator's GO); Bar S2a filed `5d80b6291` (+ traffic's T9 rider, `dca90d9c0`).**
`a1b7f7e59`, default OFF, `--nav-off=h1bside`: H1b's far loop goes round the friend (a side point abreast of it) or stands.
Laptop GDScript lab (`test_manoeuvre_h1b_side`, 3/3 + 33/33 neighbours): room on one side, ON past the friend at 19.6 s (line
20 s) v base 5 fires; one-hull street, ON stands (0 fires after the far loop, 0.00 m) v base 5 fires. Native mirror spec
`76486a045`, sent. Queue: native's check of the S1+S3 pair `20acbda5f` (running, builder0) → S1 ON-tree check (queued) → S1
series → the S2a pair (+ T9 rider) → its check → its series.

**2026-10-20 ~17:30 (worker): S2 / X4b READ, design note sent; waiting on the orchestrator's go before a bar.**
`references/round36/manoeuvre/x4b/README.md` (stream `5bf752b4f`). Main a318a2cd3, builder0 native, hull-rest drawn attack-move +
move, fresh 6301–6332 x 4 factions (256 runs): **29 crews > 25 m behind at the judge, 17 still by net motion** (per 128 runs: 14.5 /
8.5 v E1's 17 / 9; the joint did not free them in aggregate). Worst three traced (byte-identical repro). Mechanisms of the 17:
**(A) 10 refused forever** by the friend pinning them. It gave way once (or to T9's cap) without clearing them, then `ask` refuses
the same asker; 8 of the 10 blockers are parked/unseated, 7 have < 1 m room behind. **(B) 1** blocker busy yielding to another.
**(C) 6** no hull-pinned far loop (not traced yet; one presses at 0.96 with no escape: an S1 candidate). Recommendation: H1b's
far branch (mine) stops re-ramming. After H1B_ASKS refused asks on the same unmoved friend, re-drive to a side point clear of it,
or stand when there is no room.

**2026-10-20 ~16:45 (worker):** Main e45bb6632 (CP36.1 + adoption) merged into the stream as `4a0080504`. `4dd6ff750` adds the
missing `test_manoeuvre_stall_intent_sumps.gd.uid`. **S3 alone is GREEN** at native's `eefc379c5`: builder0 `make check exited 0`,
2950/0, sim-baseline 13/13 unmoved (W1b's removal is inert). **The merge candidate is `pair/native-s1s3-main` `20acbda5f`** (S1 + S3 +
both mirrors + main e45bb6632). Native's full check on it is running on builder0; it also stands in for main's own check.
Bar S1 trees: base `lab/s1-base` = `20acbda5f`, ON `lab/s1-on` `d9864ab07` (STALL_NET_DEFAULT true). ON's `make native check` is
queued behind `builder_checks --wait-below 1` (unit `manoeuvre-s1on-check`). The series (`~/overnight-manoeuvre/r36/s1_series.sh`)
starts after X4b finishes: one series per builder.

**2026-10-20 ~16:00 (worker):** CP36.1 is on main at `a318a2cd3`; the orchestrator's sim-baseline adoption is still running. S2 / X4b
started on a detached side worktree, `godot-manoeuvre-x4b`, pinned at a318a2cd3. Runs: builder0 native, hull-rest drawn,
faced_attack_move + faced_move, seeds 6301–6332 x 4 factions (256 runs), `--turn-states --element-trace=all`. systemd unit
`manoeuvre-x4b`, logs `~/overnight-manoeuvre/r36/x4b/`. Adoption touches only baselines, so play is identical. The stream merges
main after the orchestrator's adoption commit. The stacked S1+S3 pair is `pair/native-s1s3` `779f31be5` (its check is queued).
Bar S1 is copied to workstreams (7bf08f3ed): the stage proves the rule, the series guards carry the harm check.

**2026-10-20 ~15:30 (worker): where it stands.**
- **S1 GDScript** `dbe6ed396` (+ the mirror spec `ab71634f4`). quick-remote on dbe6ed396 (builder0, 11 test files + lint): 53/2.
  Both reds are the missing native mirror: the stage's native-default-arm line (holds 22 v 0) and test_native_h1b's twin
  (`_stuck_from`). The stage's GDScript lines PASS: **ON fires 1.03 s after wedging; base never fires in 20 s (clock peaks at 0.83 s);
  without the pop both arms fire alike**.
- **Native cut both pairs:** `pair/native-s3` `eefc379c5` (check running on builder0) and `pair/native-s1` `e12a381c4`, to be
  stacked on S3. The stream branch alone is red on those two lines until the pair merges back. That is by design (a pair).
- **Next:** on S1-pair green, cut ON/base trees on main+CP36.1 and run `~/overnight-manoeuvre/r36/s1_series.sh` (Bar S1 guards).
  S2's `x4b.sh` is ready and launches when CP36.1 is announced.

**2026-10-20 ~14:00 (worker, Fable).** Plan, in order (smallest foundation first):
1. C36.1 carry-over (measurement only) — DONE `05f4517e0`, `60a2dbc5c`: STALL_TRACE probe + census counters, fight_census
   exposure, wedge_trace under-fire/contact totals, joint_judge (+ w1b_judge, its import), rocking_census, mover_kind (brains'
   reader, copied; reads `tests/tactics/e1_bar.py` in place), x1d-trace + joint3-series references. `git merge main` waits for
   CP36.1's announcement (worker contract 6).
2. S3 drop W1b — GDScript half on **`lab/manoeuvre-s3` `d44c13377`** (kept off the stream branch: three `tests/native` files name the
   deleted statics, so it parses only as a pair). Native's half: `references/round36/manoeuvre/s3_native_spec.md`, sent to native.
3. S1 stallnet — code + deciding lab stage on the stream branch (below); bar filed below before any number; native mirror spec sent.
4. S2 X4b on main after CP36.1 (+ S1 if it ships), then the trace and a design note.
5. Stretch R34.16 watch.

### Bar S2a (h1bside: the far loop goes round or stands), filed before any number (2026-10-20, the orchestrator's GO and terms)

- **Change (my paths: unstick / H1b):** in `_h1b_gives_up`'s FAR branch (H1B_ASKS refused asks on the same friend that has not
  moved, goal beyond H1B_SETTLE_MAX_M; today a counter), with `h1bside` on, the escape is replaced: pick a SIDE point beside the
  friend (either side, clear of every hull by both hulls' half-widths + margin, on the navmesh, reached by a navmesh path no
  longer than SIDE_DETOUR_X x the straight line: never across a bridge or the river), and drive to it (it replaces the route's
  waypoint until reached, its timer runs out, or the friend moves); with no side clear, STAND (throttle 0, no re-ram) until the
  friend moves > H1B_MOVED_M or the goal changes. `--nav-off=h1bside` flips H1B_SIDE_DEFAULT (false until judged). Native mirrors
  the side waypoint and the stand.
- **Rider (the orchestrator's ruling, 2026-10-20): traffic's T9 "passed by half-lengths" fix** (GDScript `lab/yieldgap` `76aea1185`, quick-green builder0
  105/0; design `9030a12dc`; native stacks it as `pair/native-s2a-yg` `8e6a52fc9`; switch `yieldgap` in Traffic.DEFAULT_OFF, the
  ON tree flips it, the base keeps it off), note `_agents/streams/references/round36/traffic/t9_finished_while_pinned.md`): in `_yield_unfinished` only, "passed" =
  distance − both half-lengths > 2.0 m. It rides in this pair: ON = both switches on, base = both off; its own lab test
  (test_traffic_yieldfit2) decides its change; a red guard is traced by switch.
- **Arms:** native, two trees on main (+ S1 if shipped): ON = pair with H1B_SIDE_DEFAULT true, base = same code false. Gate:
  `make native check` on ON; base's sim-baseline.
- **(0) Counter first:** `h1b_side_steps` + `h1b_side_stands` > 0 in ON's series (counted only when ON acts; the base's far loops
  are the comparison).
- **DECIDING (lab, both paths):** `tests/test_manoeuvre_h1b_side.gd`. A hull H1-looping nose-on to a parked friend that never
  moves (its controller off), goal 30 m past it. (a) Room on one side (a second parked friend closes the other): ON is past the
  friend's front within 20 s; base is not, and fires >= 3 escapes in 30 s. (b) A one-hull street (parked friends abreast on both
  sides): ON stands — no escape fire after its first far loop and moved < 0.5 m in its last 10 s; base fires >= 3. Native: the
  tree-default arm equals GDScript (first fire, fires, final position within 0.05 m).
- **Guards (no harm), FRESH seeds, each within 1.645 se of base:** Bar S1's set (the joint bar's (d) movers by net motion, (e),
  (f), (i), (q), (r), (s), give-ways) on hull-rest 6501–6532 drawn x 4 factions x 6 tasks and wedge/fights/jam on
  locks/terminus/sumps x 6540–6563; plus **far loops (r) ON <= base + 1.645 se**, **far bank 0** (no hull of either arm ends a
  hull-rest run across the river from its goal where base did not), **unstick fires ON <= base + 1.645 se**.
- **Player line, REPORTED (paired ON v base):** crews > 25 m behind at the judge, and of those still by net motion
  (`left_behind.py`), hull-rest faced_attack_move + faced_move x 6501–6532 x 4 factions with `--element-trace=all`.
- **Pass = (0) + the lab (both paths) + every guard. A pass ships ON.** Series order: after Bar S1's (one series per builder).

### Bar S1 (stallnet), filed before any number (2026-10-20, from the x1d-trace draft; C36.3)

- **Change:** `Movement._unstick` on the HONEST path (routed move_to, `_honest_blocker` non-null): a fast tick (reading >=
  STUCK_SPEED) while the clock runs zeroes it only when the hull stands > STUCK_NET_M (0.5 m) from `_stuck_from` (where the clock
  started); otherwise the clock holds (no add). Blind path, other orders: bit for bit. `--nav-off=stallnet` flips
  STALL_NET_DEFAULT (false until judged). Native mirrors `_stuck_from` + the hold (one Vector3 in exec_fields).
- **Arms:** native, two trees on a main WITH CP36.1: ON = pair (stream + native's mirror) with STALL_NET_DEFAULT true; base = the
  same code with it false. Gate: `make native check` on ON (sim-baseline may move: attribution = base's sim-baseline), base's
  sim-baseline.
- **(0) Counter first:** `Movement.stall_net_holds` > 0 in ON's series (it counts in both arms; REPORTED in base).
- **DECIDING (lab, both paths):** `tests/test_manoeuvre_stall_net.gd`, the pinch stage (`tests/manoeuvre/stall_net_stage.gd`):
  a law_tank wedged at pace 1 in a funnel between two parked law_ifvs (Hunters_2/6, another element), the traced one-tick pop
  (9 m/s, net 0) injected every 26 ticks from the first wedged tick. ON fires an escape <= 3.0 s after wedging; base never in
  20 s (pinned premise; it asserts the honest path names a parked friend). Without the pop both arms fire alike (no-change
  line). Native: the tree-default arm's first fire, fires and holds equal GDScript's (on ON's tree that is the ON arm).
  **Why the pop is injected:** Jolt stops a lab hull wedged this way cleanly (real 0.00 every tick, six geometries tried), so the
  live pop doesn't arise in a lab; the stage injects the traced signal at the traced cadence (clock peaks 0.83 s, traced 0.73–0.99).
- **Series guards (no harm), FRESH seeds:** hull-rest 6201–6232 drawn x 4 factions x 6 tasks (128 pairs a task, `--turn-states`);
  wedge trace, fights, jam census on locks/terminus/sumps x 6240–6263 (72 fights an arm). Each within 1.645 se of base (series'
  own se; paired where paired): the joint bar's (d) movers at the judge BY NET MOTION (`mover_kind.py` closing + wander, never
  real_mps alone), (e) never settled, (f) squads arrived, (i) kills / hit rate per team, (q) open/stuck/jam deaths, (r) far loops,
  (s) friendly contact ticks, give-ways started; plus **unstick fires (H1 escapes) <= base + 1.645 se** (no reverse storm).
- **Series line, REPORTED:** `rocking_census.py` crews ON <= base (REPORTED only if base < 5, as the draft: ~3 in 768 expected).
- **Pass = (0) + the deciding lab (both paths) + every guard. A pass ships ON** (symmetric AI improvement, no lead gate).

**2026-10-20 (orchestrator, at launch).** Not started. CP36.1 (the joint ship) was checking on builder0 at launch.
