# Stream: manoeuvre (traffic that queues: a crew waits for a turning friend instead of driving round it)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 41** (C41.1-C41.3,
> CP41.1) and *Rulings (round 40)* R40.20-R40.24. Your round-40 brief: `streams/archive/round40/manoeuvre.md` (Status: *ROUND-41 ITEM 1*,
> the F1 evidence table, the CLOSE REPORT). **You own:** movement's drive / unstick / side-step / avoidance and traffic's give-way
> block, `game/ai/traffic.gd`, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`,
> `mk/manoeuvre.mk`. The C++ mirror (`native/**`) is native's: request twins through the orchestrator. **Model:** Fable.
> **Machine:** builder0 light lane (J<=4); builder2 for any series over 24 fights. **Seeds:** Q2 9001-9024, Q3 9025-9048 (C41.1).

## The lead's direction

His standing bar: "the feel of the game needs to have the user perceive that the units are smart and under their control".
His playtest of round-40 main (2026-10-26, verbatim in `game_design.md`): "when I'm controlling a large set of squads at once and
commanding all of them to go somewhere, a bunch of units block other units, but this is a symptom of all units generally not moving in
the same direction (i.e. a scout is pointed north and thus blocking a unit that's trying to go West) ... if a unit is blocked, instead of
trying to figure out how to navigate around a blockage, if they're aware that the blocking unit will eventually get oriented correctly
to move out of the way, a unit might be able to just stand by and wait for the other unit to finish their turn, which is likely faster
than trying to navigate around it - ... if all cars tried to drive around the traffic jam it would just increase the traffic jam; the
correct thing to do would be for all cars to maintain their orientation in the road and wait for the cars ahead of us to move forward,
which they inevitably will."

He also allowed that some of it is the game ("a function of some vehicles needing wide turning radiuses"): the aim is fewer and shorter
jams, not zero contact.

## Where things stand (main at launch: see HANDOFF)

- ORCA avoidance steers every crew round every neighbour, friend or not, moving or turning. Round 40's F1 (a follower queues behind its
  leader) took three forms; each fixed its case and moved a failure elsewhere because it changed ORCA's direction (R40.22-R40.24). F1's
  code is OFF on main (`--traffic-on=follow`); don't build on its static table (`Movement._follow_runs`).
- The bridge drill: main's worst rims 1.5 / 1.4 / 1.1 s v the 3 s line (deterministic). Balance's stat change (v2 overrides) pushes one
  crew to 5.1 s (rust t15 s2: ORCA carries a wheeled follower wide past the deck mouth while its leader turns; 5a233f42b reproduces).
- Instruments: `tests/manoeuvre/probe_wedge.gd`, wedge_trace partner classes, `partner_table.py`, bridge-series / bridge-pooled,
  follow_judge.py (F1's), orders' `tests/orders_probe.gd` (shared: don't rename `_match`/`_squads`/`_order_tick` without telling orders).

## Backlog (in order)

1. **Q1 the jam census (report).** On orders' group-order workload (many squads, one click, mixed start headings; orders' O1 builds the
   probe: ask the orchestrator for its hash, or use probe_wedge's group order meanwhile), classify every stretch where a crew is slowed
   by a friend: is the blocker turning in place, about to drive off the asker's line, parked, or coming head-on? How long was each, and
   what did the asker do (steered round, stopped, reversed)? Name what share of jam-seconds would end by itself within N s if the asker
   just held its heading and waited. This number decides whether Q2 is worth building; send it to the orchestrator.
2. **Q2 wait, don't detour (his rule).** A crew blocked by a FRIEND that will clear its line soon (turning toward a heading that takes it
   off the line, or already pulling away) holds its heading and waits (slows / stops) instead of taking ORCA's sideways answer. A
   time-out (a few seconds; Q1's numbers pick it) hands back to today's avoidance, so a parked or wedged blocker is never waited on
   forever. Speed / hold only (C41.2): ORCA's direction is not rewritten while waiting; the crew just doesn't move into the gap. Build
   OFF (`--traffic-on=wait` or similar), lab on Q1's worst cases first, then file **Bar Q2** on 9001-9024 before any number: deciding =
   jam-seconds (or every-squad-in time) on the group-order workload; guards = G5 never-in, the wedge trace, bridge-pooled, fight lines
   (the dev cells round 40 used). Name orders' O2 switch state (C41.3). A pass ships ON with native's twin.
3. **Q3 the bridge speed cap (round-40 item 1, CP41.1).** A WHEELED crew slows before a sharp turn on its route that its leader is in, so
   it reaches the turn at a speed it can make with its 8 m radius; ORCA's steering untouched. Spec and evidence: your archived Status
   *ROUND-41 ITEM 1*. Before any number, decide (and write down) whether bridge-pooled's single-seed 3 s line becomes a pooled measure
   (R40.24's design item; the orchestrator rules on your proposal). **Bar Q3** on bridge-drill seeds 9025-9048, on main AND under
   balance's v2 overrides (`~/balance-guard-raw/v2/overrides-fm_c5r2_lawt5.json`, or check out balance/b2s-v2-arm d385cd308). Q3 and Q2
   may share one rule if Q1 shows the bridge case is the same "wait for a turning friend" case; say so before building twice.
4. **Stretch:** round 40's M1 v3 (archived orders/manoeuvre Status): limit a parked crew's give-way reach only while its own squad is
   still arriving.

## How to verify

Pure tests (`tests/test_traffic*.gd`); the wedge probe; bridge-series; `make quick-remote`; a full check of every hash you name before a
series. Smoke he can run: `make skirmish ARENA=terminus SKIRMISH_FLAGS="--traffic-on=wait"` against without: select every squad, send
them across the map, watch who waits and who weaves.

## Don't touch

orders' `game/control/**` and the planner (orders' C41.3 grant), settle's deploy functions in `element_plan.gd`, balance's paths,
`native/**` (request), `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Session start 2026-10-26 ~02:10 PDT (Fable). Starting commit de509b00f = main at launch (code c36217f79 GREEN builder0, 3243/0; no
baseline check re-run, per the contract). Orchestrator session: `godot-d6`.**

### Q1 the jam census: REPORTED (lab 1: 32851c0d8, builder0 light J4, native ON, 64 runs; sent to the orchestrator 03:15, decisions approved)

Workload: orders' O1 probe, his five full squads (25 crews), one click across the map, terminus / locks / crossing / sumps x dev seeds
7001-7008 x headings crew / formed, 90 s window, n 8 a cell. Evidence: `references/round41/manoeuvre/q1-census-builder0-32851c0d8/`
(table.txt, per_map.txt); raw logs `~/overnight-manoeuvre/r41/jamlab1/logs`.

| Map | Never-in (crew / formed, of 8) | All-in median s | Jam-seconds a run (crew / formed) | Blockers (both headings) |
|---|---|---|---|---|
| crossing | 8 / 8 | never | 1,099 / 981 | stalled 36 %, crossing 25 %, same_way 23 %, head_on 8 %, turning 4 %, parked 3 % |
| locks | 3 / 4 | 72.2 / 71.9 | 846 / 753 | stalled 28, crossing 27, same_way 25, head_on 9, parked 6, turning 5 |
| sumps | 7 / 4 | 67.2 / 77.0 | 856 / 712 | stalled 33, crossing 24, same_way 24, head_on 11, turning 5, parked 4 |
| terminus | 0 / 0 | 56.2 / 60.5 | 529 / 525 | crossing 33, same_way 29, stalled 15, head_on 11, parked 8, turning 4 |

- **Pooled (50,400 jam-seconds, 53k episodes):** blockers stalled 30 %, crossing 27 %, same_way 25 %, head_on 10 %, turning-in-place
  5 %, parked 5 %. Askers: reversed 30 %, slowed 24 %, yielded 22 %, steered 17 %, stopped 7 %. Episodes >= 3 s hold 42 % of the
  jam-seconds and are 46 % yields and 33 % reversing: the detour machinery is the long part. Same-squad blocker 37-40 %. 25 crews
  spend ~45 % of their time in crossing slowed by a friend. Headings barely matter (crew v formed 833 v 743 s a run), as orders found.
- **t_clear** (when the blocker actually left the asker's frozen lane), median / p90 / never within 20 s: crossing 1.5 / 6.7 s / 4 %,
  same_way 1.4 / 5.4 / 3 %, turning 2.1 / 9.6 / 9 %, head_on 1.7 / 8.3 / 7 %, stalled 3.3 / 11.9 / 19 %, parked 2.8 / 12.3 / 37 %.
- **The number Q2 hangs on:** the classes Q2 waits on (crossing + same_way + turning) are 56 % of all jam-seconds; of those the blocker
  had cleared within 2 s 49 %, 3 s 64 %, 4 s 73 %, 5 s 79 %, 6 s 83 %, 8 s 88 %. Over ALL jam-seconds: 3 s 53 %, 5 s 66 %, and in
  40 % the blocker cleared before the asker's own detour / yield ended. **Q2 is worth building.**
- **Decisions (approved by the orchestrator 2026-10-26 ~03:20):** Q2 waits on crossing, moving same_way, turning, and a friend that is
  itself waiting (stalled is 30 % and under the rule a share of those are waiting crews; cycle-guarded); never on parked,
  stalled-not-waiting or head-on. **Cap 5 s** (79 % of the waitable jam-seconds; past 5 s each second buys under 5 points while a
  never-clearing blocker costs the whole cap). Moves from 4 s after the first Q2 lab (running at 4 s).
- Caveat on t_clear: the lane is frozen at the episode's start, but the blocker's motion was not independent of what the asker did.

### Q2 lab 1: FAIL as built (a553f85b0); v2 built (c8e329b23); lab 2 and the bridge reads running

**Lab 1** (a553f85b0 = scaffold + native's exec_fields pair, builder0 light J4, orders' O1 probe, crossing / locks / sumps / terminus x
7001-7004, crew headings, 16 paired runs, BOTH arms `--brains-off=native_drive`, `wait_judge.py`, `~/overnight-manoeuvre/r41/jamlab2/`):

| Line | main -> wait | Verdict |
|---|---|---|
| D1 jam-seconds (16 runs) | 13,365 -> 14,537 s (+8.8 %; paired +73 s a run, se 30: 2.4 se WORSE) | FAIL |
| D2 every-squad-in (never-in = 90) | 80.4 -> 84.7 s (paired +4.3 s, se 2.6) | FAIL |
| G5 never-in runs | 10 -> 11 of 16 | FAIL |
| G6 friendly contact ticks | 235,328 -> 230,744 (-2 %) | PASS |

By blocker class (jam-s): crossing 3,656 -> 2,982 (the intended case, down), turning 685 -> 516, head_on 1,302 -> 1,169, parked
557 -> 423, but **same_way 3,241 -> 4,265 and stalled 3,924 -> 5,182**. Terminus, the always-in map, got worse (55.7 -> 60.4,
56.6 -> 88.3, 68.6 -> 87.4 s). Reading: waiting behind a slower friend going my way turns ORCA's overtake into following at that
friend's pace, and the crews behind chain up; Q1's "same_way clears within 2 s" was the leader driving out of the frozen lane, after
which the follower catches it again (F1 v1's lesson, R40.22, in another form).

**v2 (c8e329b23):** a leader going my way (velocity within 30 deg of mine, Traffic.FOLLOW_COS) is passed as today; Q2 waits on
crossing, turning and waiting friends only. Cap 5 s (R41.2). tests/test_traffic_wait.gd 5/0 (laptop NATIVE=off; the cap test now
calls the rule directly on a staged crossing friend). Lab 2 (v2, same 16 cells) queued on builder0 behind the bridge read.

### The bridge read (R41.3: bridge-pooled with `--traffic-on=wait`): THE WAIT RULE CLEARS THE BRIDGE

bridgelab1 (builder0 light, native, bridge-pooled 18 runs an arm, deterministic; `~/overnight-manoeuvre/r41/bridgelab1/`; reader
`tests/manoeuvre/bridge_lab_table.py`, checked against round 40's F1 v2 lab):

| Tree | Arm | bridge-pooled | Pooled rim s | Deck jam s | Worst crew | Mean arrival | Paired rim |
|---|---|---|---|---|---|---|---|
| overrides (bt 3430fd21a = 10d3a8d72 + 8e257f3bc + d385cd308) | OFF | **17/18** (rust t15 s2, Rust_S_3 5.1 s: R40.20 reproduced) | 14.2 | 17.1 | 5.1 | 34.9 | |
| overrides | ON, v1 rule (same_way waited) | **18/18** | 1.3 | 12.2 | 0.6 | 32.7 | -0.72 s a run, se 0.30 (-2.4 se) |
| main c8e329b23 | OFF | 18/18 | 8.1 | 7.5 | 1.5 | 36.6 | |
| main c8e329b23 | ON, v2 rule (no same_way) | 18/18 | 3.4 | **16.2** | 1.0 | 37.0 | -0.26 s a run, se 0.18 (-1.5 se) |

Reading: the bridge case is Q2's case (R40.21's follower carried wide round its slowing leader is a crew that should wait). v1 under
the overrides fixes the failing run outright and cuts deck jam and arrival too. v2 on main halves the rim but doubles deck-jam
seconds; bridgelab2 (v2 under the overrides) decides whether Q3 = Q2 v2 as is, or v2 plus the orchestrator's leader-in-turn gate
(a same_way leader is waited on only while it is itself turning: moving, nose off its own next leg).

### Q3 design decision, written BEFORE any bridge number (R40.24's item; for the orchestrator's ruling)

**Proposal:** bridge-pooled's single-run line (every surviving crew crosses, no crew at the rim over 3 s, 18/18 cells) stays a HARD
GUARD as it is: it is his bridge complaint and a guard is never loosened. It does not become the deciding measure, because its
margin on main is 1.1-1.9 s on a deterministic 18-cell drill, so a pass/fail flip there says little about a rule. **Bar Q3's deciding
line is pooled rim-seconds** (R40.23's design): fresh bridge-drill seeds 9025-9036 x start ticks {1, 8, 15} x both sides (72 runs
an arm a tree), on main AND under balance's v2 overrides; ON <= 0.8 x OFF pooled and the paired per-run mean < 0 by >= 2 se; every
surviving crew crosses in both trees; runs with a crew over the 3 s rim line ON <= OFF (named). Deck-jam seconds and mean arrival
reported. **Q2 may be the bridge rule:** the bridge case (R40.21) is a wheeled follower 7 m behind a leader slowing to turn onto the
deck, i.e. a moving same_way blocker that then reads "turning" (slow, nose off its next leg) at the mouth: both are Q2's waitable
classes, so the first bridge read is bridge-pooled with `--traffic-on=wait` on main and under the overrides. If that is green with
rim down, Q3 = Q2 (one rule, one twin) and Bar Q3 judges the same switch; a separate speed cap is built only if it is not.

### (superseded) Q1 the jam census: INSTRUMENT BUILT (32851c0d8), lab 1 running on builder0 (light J4, native, 64 runs)

- `tests/manoeuvre/probe_jam.gd` extends orders' O1 probe (`tests/orders_probe_group.gd`, cherry-picked 8b828ec59 = f8c9867c6 here:
  his five full squads, 25 crews, one click across the map, `--probe-headings=crew|formed`). Classifier `jam_class.gd` (pure,
  `test_jam_class.gd` 6/0 laptop). `make manoeuvre-probe-jam PJ_CELLS=map:route:seed... PJ_HEADINGS="formed crew"`;
  `probe_jam_table.py` pools. Rows: JAM_EP (one per asker x blocker episode), JAM_RUN.
- **Laptop read (32851c0d8, terminus crew s7001, n 1, 25 crews, all in 75.4 s = orders' own number):** 611 jam-seconds in 602
  episodes. Blockers (episode mode): crossing 29 %, same_way 28 %, stalled 24 %, head_on 10 %, parked 5 %, turning-in-place 4 %.
  Askers: reversed 31 %, slowed 26 %, steered 21 %, yielded 17 %, stopped 5 %. **Counterfactual:** the blocker had left the
  asker's frozen lane within 2 s for 46 % of jam-seconds, 3 s 57 %, 5 s 71 %, 8 s 80 %; in 45 % of jam-seconds the blocker
  cleared BEFORE the asker's own detour/yield ended. Same-squad blocker 25 %. Lab 1 (4 maps x 7001-7008 x crew/formed) pools it.

### Q2 wait, don't detour: SCAFFOLD BUILT OFF (e6624abe5, `--traffic-on=wait`)

- **The rule** (Movement._wait / _wait_blocker / _wait_kind, in `_avoid` after ORCA's answer, before F1's block): when ORCA would
  deflect a crew and the nearest living friend ahead in its lane (12 m, both radii + 0.5 m), or the friend meeting it there first
  within 2 s at its route velocity, is "moving" (>= 1 m/s, not head-on: crossing, or a leader going its way) or "turning" (slow,
  under way, nose > 30 deg off its own travel direction, which is not head-on to mine), the crew keeps its route's steer point and
  drives at a following pace: (along - (r_me + r_it + 1 m)) / 1.5 s + the friend's speed my way. It asks nobody to give way while
  waiting (the ask in `drive` is skipped while `_wait_for != ""`). After WAIT_CAP_S = 4 s on one friend: hand back to ORCA,
  that friend refused for 6 s. Parked / stalled / head-on friends: ORCA as today. The orchestrator's keying (2026-10-26 ~02:45):
  wait on "will clear soon", never on stalled or parked; the cap is for the ones that don't.
- Per-crew state: `_wait_for`, `_wait_since`, `_wait_refused`, `_wait_refused_until`, declared last; native has the four
  exec_fields.h lines (requested via the orchestrator 02:50; until the pair lands test_native_exec_state is red under native on
  this branch). ON runs the GDScript drive (Traffic._chain_native, as F1). Counters in route_arms: wait_queued, waits,
  wait_timeouts, wait_longest, wait_by_kind.
- Tests `tests/test_traffic_wait.gd` 5/0 (laptop NATIVE=off, e6624abe5): off by default; the kind read (crossing = moving, parked =
  no, head-on = no, pivoting tracked friend = turning); live crossing friend: ON lateral 0.32 m v OFF 0.94 m, waited 69 crew-ticks,
  50.6 m north in 8 s (OFF 66.3); crawler in lane: OFF passes at 4.7 s, ON times out at 4.0 s and passes at 8.7 s. OFF regression
  set traffic|test_manoeuvre|movement|steering|wedge|jam_class: 227 passed, 0 failed (laptop NATIVE=off).
- Next: lab on lab 1's cells (crossing first) ON v OFF, both GDScript drive; then Bar Q2 filed on 9001-9024 before any number.

### Plan (ordered; the brief's backlog as built)

1. **Q1 the jam census** (report, dev seeds 7001-7008, builder0 light J4). Instrument: `tests/manoeuvre/probe_jam.gd` (extends
   orders' probe as probe_wedge does; the probe itself untouched) + `jam_class.gd` (the classifier, pure-tested in
   `tests/manoeuvre/test_jam_class.gd`) + `probe_jam_table.py` + `make manoeuvre-probe-jam`. Workload until orders' O1 hash
   lands: the 5-squad group order (click and route) on terminus / locks / crossing, with and without `--jam-scatter=on` (every
   crew's hull turned to a seeded random heading the tick after the order: his "a scout is pointed north" case). Re-read on O1's
   probe when its hash arrives.
   - Decision: the BLOCKER of a slowed crew is read in this order: the crew it yields to; a friendly hull it touches; the nearest
     friend in its lane ahead (12 m, hull radii + 0.5 m); else the friend ORCA would meet first within 2 s at the route's
     preferred velocity (time to meet). No friend found = not a friend jam (terrain, route end, enemy): not counted. Why: ORCA
     exposes no binding neighbour; this is the same lane/horizon ORCA reasons about, from the public table.
   - Decision: the counterfactual "would end by itself within N s" is measured, not modelled: the lane is FROZEN at the episode's
     start (origin, direction, width) and `t_clear` is the first tick the blocker is out of that lane and will not enter it
     (time to meet = none), capped at 20 s. Caveat written here: the blocker's motion is not independent of what the asker did.
2. **Q2 wait, don't detour** (`--traffic-on=wait`, DEFAULT_OFF): built only if Q1 says a meaningful share of jam-seconds would
   clear within a few seconds. Speed/hold only (C41.2); per-crew state as Movement members with exec_fields.h entries; lab on
   Q1's worst cases; **Bar Q2** filed before any number on 9001-9024.
3. **Q3 the bridge speed cap** (CP41.1): the pooled-measure decision written BEFORE any number; Bar Q3 on 9025-9048, main and
   under balance's v2 overrides. Shares a rule with Q2 if Q1 shows the bridge case is the turning-friend case.
4. Stretch: M1 v3.

