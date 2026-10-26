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

### Q2 lab 2 (v2, 6268e08a5): still FAIL, the rule dithered; v3 built (aaac5c133), lab 3 running

**Lab 2** (same 16 paired cells, both GDScript drive, `~/overnight-manoeuvre/r41/jamlab3/`): D1 jam-seconds 13,365 -> 14,346 (+7.3 %;
paired +61 s a run, se 32, 1.9 se WORSE) FAIL; D2 all-in 80.4 -> 83.0 (+2.5 s, se 2.2) FAIL; G5 never-in 10 -> 10 PASS; G6 contacts
+3.6 % PASS. Terminus worse in all four cells (55.7 -> 58.2, 57.6 -> 72.3, 56.6 -> 71.6, 68.6 -> 74.7). **The rule's counters:**
1,003 waits a run, 7,533 queued crew-ticks: the mean wait was 0.25 s. Slowing for the friend removed ORCA's deflection, the wait
ended (v2 ended it whenever ORCA did not deflect), the crew sped up, deflected, waited again: dithering at half pace, not holding a
lane; the crews behind read the ditherers as stalled (stalled 3,924 -> 4,872). The test stage's tick trace showed a second flaw: two
crews crossing each other's lane each wait for the other, each seeing the other's wait a tick late, so both flipped every tick.

**v3 (aaac5c133; `tests/test_traffic_wait.gd` 6/0 laptop NATIVE=off):**
- A wait, once begun, goes on with ITS friend while that friend is still ahead within the lane's band (12 m along, both radii + 0.5 m
  + a 2 m band) and still one to wait on; the blocker is not re-selected every tick. A fresh wait is taken only on a tick ORCA deflects.
- "Will clear" for a moving friend = its own lateral motion takes it out of my lane within WAIT_CAP_S (`Movement._lane_exit_s`); a
  leader going my way has ~0 lateral speed and never qualifies (v2's same_way drop, now by construction); head-on excluded as before.
- A mutual wait is a four-way stop: the lower name goes, the other waits (`_wait_kind` checks it before the speed branch).
- Stale waits end on a street-mouth hold, at the route's end and on ticks `_avoid` is skipped (reversing, arriving).
- On the stage: the crossing friend is now ONE wait of 2.2 s and 0.00 m off the line (v2: 54 waits, 6-8 m off the line).
- Lab 3 (v3, the 16 cells) started 03:59 on builder0 (`jamlab4/`); v3 bridge reads queued (`bridgelab3/`).

### Q2 lab 3 (v3, aaac5c133): FAIL again; the broad "wait for a crosser" rule stops here (three variants, same 16 cells)

Lab 3 (`~/overnight-manoeuvre/r41/jamlab4/`, same 16 paired cells, both GDScript drive): D1 jam-seconds 13,365 -> 14,506 (+8.5 %;
paired +71 s a run, se 32, 2.3 se WORSE) FAIL; D2 all-in 80.4 -> 83.3 (+2.9 s, se 2.3) FAIL; G5 never-in 10 -> 9 PASS; G6 contacts
+0.8 % PASS. Terminus worse in all four cells again (55.7 -> 66.5, 57.6 -> 69.0, 56.6 -> 69.2). Counters: 1,725 waits a run, 11,229
queued crew-ticks (0.22 s a wait; 31 waits >= 2 s a run), time-outs 6, longest 9.6 s; by kind moving 131k, waiting 30k, turning 18k.

**Reading (three variants, v1 +8.8 %, v2 +7.3 %, v3 +8.5 %, each 1.9-2.4 se worse on the same dev cells):** on his group order, where
25 crews merge into one street, waiting for a friend that is crossing my lane costs more than ORCA's steer-round, whatever the
wait's shape; the waits stay short even with lock-on because the crosser itself slows (for me, or for a third crew) and stops
qualifying, and the crews behind read the waiter as stalled. The census's counterfactual ("the blocker cleared within 3 s in 53 %
of jam-seconds") held, but the detour it replaced was cheaper than the wait on these maps. **The broad rule is not filed as a bar
and stays OFF** (`--traffic-on=waitcross` after v4's split, for the record). What the wait DID fix outright is the bridge (below):
a wheeled follower behind a leader turning onto the deck. v4 keeps that: the wait keys on a leader that is itself turning.

### v4 (R41.5, f7fd7819a): the wait keys on a leader that is itself turning; reads running

R41.5 (2026-10-26 ~04:15): the broad wait stops OFF with no bar; `--traffic-on=waitcross` keeps the crosser key in code for the
record. v4: `_wait_kind` returns "turning" for a friend under way whose nose is more than 30 deg off its own next leg (moving or
slow; the bridge's leader swinging onto the deck, his scout pointed north), "waiting" for the chain behind it, "" for a leader
driving straight, a parked, stalled or head-on friend. Tests 6/0 laptop NATIVE=off (a wheeled leader 12 m ahead facing east and
ordered north reads "turning" at 4.4 m/s). Running (`~/overnight-manoeuvre/r41/v4labs/`): bridge-pooled ON under the overrides
(bt = f7fd7819a + 8e257f3bc + d385cd308 = 225087f27), the group-order no-harm lab (16 cells, wait v main), bridge-pooled ON on main.
Then Bar Q3 on 9025-9048. **Q4 (the orchestrator's add, R41.5):** the long episodes (42 % of jam-seconds) are yields and reversing:
lab a cut of the give-way machinery when the blocker is a moving friend (slow and hold the lane), on fresh dev cells 7005-7008.

### C++ twin request for the judged rule (ready; the orchestrator relays it to native on a Bar Q3 pass)

The rule lives in the drive's C++ mirror (drive_native.cpp's `_avoid`) and in the drive's ask gate; its state is the four members
native already holds (pair/native-wait-fields). Twin check: `tests/test_traffic_wait.gd` under native, and bit-identity per seed
(R38.24) with `--traffic-on=wait` on and off once the GDScript path no longer forces native_drive off (Traffic._chain_native).
- **Where (in `_avoid`):** after ORCA's `chosen`, (1) in the branch `chosen.distance_squared_to(route_preferred) < 0.04`: if
  `_wait_for != ""` then `_wait_end()`; return [waypoint, 1.0]. (2) After `keep` is computed, BEFORE F1's block: if not `held` and
  `wait` is on: if `yield_to != ""` or `_pass_by != ""` or `_order_ticks < AVOID_GRACE_TICKS` then `_wait_end()`; else
  `waited = _wait(here, to / distance, route_preferred, desired)`; if `waited >= 0` return [waypoint, waited].
- **`_wait(here, way, preferred, desired)`:** tick = physics frame. If `_wait_for != ""` and tick - `_wait_since` >= 5 s x TICK_RATE:
  wait_timeouts++, `_wait_refused = _wait_for`, `_wait_refused_until = tick + 6 s x TICK_RATE`, `_wait_end()`, return -1. found =
  `_wait_blocker(here, way, preferred)`; empty: `_wait_end()`, return -1. other = found[0], kind = found[1], name = other.name. If
  name == `_wait_refused` and tick < `_wait_refused_until`: `_wait_end()`, return -1. If `_wait_for != name`: `_wait_end()`,
  `_wait_for = name`, `_wait_since = tick`, waits++. wait_queued++, wait_by_kind[kind]++ (measurement). off = other - here (flat);
  gap = radius_of(me) + radius_of(other) + 1.0; its_along = max(other.real_velocity (flat) . way, 0); v = max(off . way - gap, 0) /
  1.5 + its_along; return clamp(v / max(desired, 0.1), 0, 1).
- **`_wait_end()`:** if `_wait_for == ""` return; s = (frame - `_wait_since`) / TICK_RATE; if s >= 2.0 wait_long++; if s > wait_longest.s
  record {crew, for, s} (measurement); `_wait_for = ""`, `_wait_since = -1`.
- **`_wait_blocker(here, way, preferred)`:** over the living friends of my team (tanks_root children, not me): off = other - here,
  along = off . way; skip along <= 0. width = radius_of(me) + radius_of(other) + 0.5. If along <= 12.0 and |off x way| <= width: a lane
  candidate, nearest `along` wins. Else, only while no lane candidate yet (best_along == INF): v_rel = other.real_velocity (flat) -
  preferred; t = `_meet_in(off, v_rel, width)`; the smallest t < 2.0 wins. None: []. kind = `_wait_kind(best, way)`; "" -> [].
- **`_meet_in(p, v_rel, r)`:** a = |v_rel|^2, b = 2 p . v_rel, c = |p|^2 - r^2; c <= 0: 0 if b < 0 else INF; a < 1e-6: INF; disc = b^2 -
  4ac < 0: INF; t = (-b - sqrt(disc)) / 2a; t if t >= 0 else INF.
- **`_wait_kind(other, way)`:** v = other.real_velocity (flat), speed = |v|. If speed >= 1.0: cos = v . way / speed; "" if cos <= -0.5
  (head-on); "" if cos >= Traffic.FOLLOW_COS (0.866, going my way); else "moving". Else: mover = Movement.of(other); "" if null, not
  under way (phase == "arrived") or `_goal` == INF. If mover.`_wait_for` != "": "" if it equals MY name (a cycle) else "waiting".
  its_way = mover.`_travel_direction`(`_goal`, false); "" if zero or its_way . way <= -0.5. nose = -other.basis.z (flat, unit);
  "turning" if nose . its_way < cos(30 deg) else "".
- **The ask gate (drive):** the `_negotiate` call runs only if `(stalled_ticks >= ASK_SECONDS x TICK_RATE or held_back) and _wait_for == ""`.
- **`reset()`:** `_wait_for = ""`, `_wait_since = -1` beside `yield_to = ""`.
- **Traffic:** `wait` in DEFAULT_OFF; `--traffic-on=wait` turns it on; while on, Traffic._chain_native sets native_drive false until
  the twin lands (drop that clause when it does).

### v4 reads (f7fd7819a; `~/overnight-manoeuvre/r41/v4labs/`, builder0 light, native for the bridge, GDScript both arms for the group order)

| Read | OFF -> v4 ON |
|---|---|
| bridge, overrides tree (225087f27) | **17/18 -> 18/18**; pooled rim 14.2 -> 9.8 s (-31 %; paired -0.24 s a run, se 0.30, -0.8 se); deck jam 17.1 -> 10.4; worst crew 5.1 -> 1.5; arrival 34.9 -> 36.7 |
| bridge, main (f7fd7819a) | 18/18 -> 18/18; pooled rim 8.1 -> **10.7 s (+32 %**; +0.14 s a run, se 0.20); deck jam 7.5 -> 9.7; worst 1.5 -> 2.4; arrival 36.6 -> 37.8 |
| group order, 16 paired cells (7001-7004 crew) | jam-seconds 13,365 -> 14,015 (+4.9 %; +41 s a run, se 46, 0.9 se); all-in 80.4 -> 82.3 (+1.9 s, se 2.7); never-in 10 -> 10; contacts -1.3 %; waits 1,129 a run (17 >= 2 s), turning 57k / waiting 48k crew-ticks |

**The wait family's table so far (bridge rim pooled, 18 runs; group order 16 paired cells):**

| Variant | Keys | Overrides bridge | Main bridge | Group order jam-s |
|---|---|---|---|---|
| v1 (a553f85b0) | crossing + same_way + turning(slow) + chain | 17/18 -> 18/18, rim 14.2 -> 1.3, arrival 34.9 -> 32.7 | not read | +8.8 % (2.4 se) |
| v2 (c8e329b23) | crossing + turning(slow) + chain | read running (`bridgev2/`) | 18/18, rim 8.1 -> 3.4, deck 7.5 -> 16.2 | +7.3 % (1.9 se) |
| v3 (aaac5c133) | v2 + lock-on, lane-exit, tie-break | not read | not read | +8.5 % (2.3 se) |
| v4 (f7fd7819a) | turning leader (moving or slow) + chain | 17/18 -> 18/18, rim 14.2 -> 9.8 | 18/18, rim 8.1 -> 10.7 (+32 %) | +4.9 % (0.9 se) |

Reading: every variant clears the overrides' failing run (the CP41.1 gate as a hard guard); the deciding pooled-rim line on main is
met by v2's crosser key (-58 %) and failed by v4's turning key (+32 %): at the deck mouth the leader swinging onto the deck reads as a
CROSSER by its velocity before its nose is 30 deg off its next leg, so v4 fires late. The group order is neutral-to-worse for all
four (v4 the mildest). The wait family trades the bridge for his group order; the orchestrator rules (message sent 04:50).

### M1 v3 (stretch): BUILT OFF on the side branch wip/manoeuvre-m1v3 (9087f3b12); dev lab running

While Bar Q3's tree is frozen, M1 v3 lives in the side worktree `../godot-manoeuvre-m1` (branch `wip/manoeuvre-m1v3`, off
2e5848acd; cherry-picked onto stream/manoeuvre when the series ends). `--giveway-chain=v3` = givewaychain + `chainarriving`
(DEFAULT_OFF): M1's reach (a parked crew more than CHAIN_M off its seat takes no give-way spot farther from it) is in play only while
the crew's OWN element is still arriving (`Movement._own_squad_settled`: Elements.of_match(...).of(me).arrived and nothing queued);
a settled squad gives way as today, so the last squads threading past parked squads (Bar M1 v2's G5 trace) are not wedged behind
refusers. `chain_settled_passes` counts lifted reaches. No C++ mirror yet: ON runs the GDScript ask (native_yield off). Tests
`tests/test_traffic_chainarriving.gd` 3/0, `test_traffic_chain` 11/0 (laptop NATIVE=off). **Lab 1** (round 40 lab2's cells: the five
G5 regressions + two old never-ins + s3866, arms main / v3, both `--brains-off=native_yield`, probe_wedge, builder0 light J4):
running, `~/overnight-manoeuvre/r41/m1v3lab1/`.

### Q4 hold the lane (R41.5): BUILT OFF (0dc8a435f), lab 1 a NULL; stays OFF, no bar

`--traffic-on=holdlane`: a crew stalled behind a friend of a wait kind (crossing, turning, waiting) skips the ask / yield in
`_negotiate` (holdlane_skips) and, at the stuck clock, restarts it instead of backing off or escaping (holdlane_holds).
`tests/test_traffic_holdlane.gd` 4/0. **Lab 1** (ca843a664, builder0 light J4, orders' O1 probe, FRESH dev cells crossing / locks /
sumps / terminus x 7005-7008 crew, 16 paired runs, both arms GDScript drive; `~/overnight-manoeuvre/r41/q4lab1/`, judge filed under
`references/round41/manoeuvre/q2-labs-builder0/`): jam-seconds 13,284 -> 13,081 (-1.5 %; -13 s a run, se 19: flat); every-squad-in
75.2 -> 78.2 s (+3.0 s, se 1.5, **2.1 se WORSE**); never-in runs 8 -> 9 (squads a run 1.00 -> 1.06); **friendly contact ticks
+10.8 %** (223,917 -> 247,999; the strict 1.05x line fails). The rule acted 29 skips + 6 holds a run. Reading: not asking a
crossing friend to give way leaves the two nose-to-tail against each other (contacts up) until it has crossed; what the give-way
machinery costs in long episodes it also buys in separation. Q4 stays OFF; no bar (one lab, as R41.5 asked). A later Q4 + wait
combination is not pursued this round: both halves read neutral-to-worse on his group order on their own.

### Bar Q3: FILED 2026-10-26 ~05:00 PDT on tree f6d9d7b1b, BEFORE any number on 9025-9048 (R41.3 + R41.6)

- **The rule judged:** `--traffic-on=wait` as restored at 1199fad11 (v2's functions byte for byte; c8e329b23's reads are its dev
  reads): a crew ORCA would steer round a FRIEND ahead in its lane (12 m, both radii + 0.5 m; or meeting it there within 2 s) that is
  crossing its lane (moving >= 1 m/s, not head-on, not going its way), or slow, under way and turning toward its own next leg, or
  itself waiting for such a friend, keeps its route's steer point and follows at a closing pace, asking nobody to give way; 5 s cap,
  6 s cooldown. **Why these classes:** Q1's census (crossing 27 %, turning 5 % of jam-seconds, the blocker gone within 5 s for
  78 % / 59 % of them); same_way dropped after lab 1 (following a slower leader cost more than passing it). Q4 `holdlane` OFF.
  Orders' O2 OFF in both arms (`--group-depart` unset; R41.4). The overrides tree = f6d9d7b1b + 8e257f3bc + d385cd308.
- **Gate:** the tree's full check green on builder0 FIRST (C31.1; `make remote T=check` on f6d9d7b1b, result below), then the series from
  that frozen tree (R40.13: no game/ or tests/ commits until its end line).
- **Arms:** OFF (default) v ON `--traffic-on=wait`; **both `--brains-off=native_drive`** (the pair compares the rule alone; the
  GDScript and C++ drives are bit-identical per test_native_drive). Settle's and orders' switches at main's defaults.
- **Deciding (R41.3): pooled rim-seconds** on bridge-drill seeds 9025-9036 x start ticks (1, 8, 15) x both sides (72 runs an arm a
  tree), on main AND the overrides tree: ON <= 0.8 x OFF pooled AND the paired per-run mean < 0 by >= 2 se, on BOTH trees. Every
  surviving crew crosses in both trees with ON. Runs with a crew over the 3 s rim line: ON <= OFF (named). bridge-pooled's own 18/18
  line stays a hard guard (the check).
- **Group-order guards (R41.6, strict):** orders' O1 probe cells crossing / locks / sumps / terminus x 9037-9048 x crew headings
  (48 runs an arm), `q3_judge.py`: G5 every-squad-in mean ARM <= BASE + 1.645 se (paired; never-in reads as 90 s); G6 never-in
  squads a run ARM <= BASE + 1.645 se; G7 friendly contact ticks ARM <= 1.05 x BASE. "He asked for better traffic on exactly that
  order. A bridge fix that visibly worsens it doesn't ship."
- **Fight guards:** `manoeuvre-wedge-trace` locks / terminus / sumps x 9037-9042 (18 fights an arm), `follow_judge.py --on-arm=wait`
  G1-G4: give-way deaths and stuck deaths ON - OFF <= max(2 paired se x n, 3); friendly contact ticks <= 1.10 x; kill share within
  0.03 and deaths within 5 %. (Its D and G5-G7 lines are reported here, not judged: the group-order guards above replace them.)
- **Reported:** deck-jam seconds, mean arrival, jam-seconds (probe_jam), the rule's counters (waits, time-outs, longest) per tree
  and arm.
- **Dev history (C41.1):** four wait variants were labbed on the group-order cells 7001-7004 (v1 +8.8 %, v2 +7.3 %, v3 +8.5 %, v4
  +4.9 % jam-seconds) and the bridge drill's seeds 1-3 (v1 / v2 / v4 under the overrides; v2 / v4 on main). No number on 9025-9048
  has been read. Evidence: `~/overnight-manoeuvre/r41/` (jamlab2-4, v4labs, bridgelab1, bridgev2).
- **Judge:** `bridge_lab_table.py --pair` per tree (deciding), `q3_judge.py` (group-order guards), `follow_judge.py` (fight guards);
  `~/overnight-manoeuvre/r41/barq3.sh` runs the series. A pass goes to the orchestrator: ships ON with native's twin (CP41.1, the
  orchestrator merges it alone and tells balance). A fail: OFF, no re-run on these seeds; then R41.6's (c).

### C++ twin request for the judged rule (ready; the orchestrator relays it to native on a Bar Q3 pass)

The rule lives in the drive's C++ mirror (drive_native.cpp's `_avoid`) and in the drive's ask gate; its state is the four members
native already holds (pair/native-wait-fields). Twin check: `tests/test_traffic_wait.gd` under native, and bit-identity per seed
(R38.24) with `--traffic-on=wait` on and off once the GDScript path no longer forces native_drive off (Traffic._chain_native).
- **Where (in `_avoid`):** after ORCA's `chosen`, (1) in the branch `chosen.distance_squared_to(route_preferred) < 0.04`: if
  `_wait_for != ""` then `_wait_end()`; return [waypoint, 1.0]. (2) After `keep` is computed, BEFORE F1's block: if not `held` and
  `wait` is on: if `yield_to != ""` or `_pass_by != ""` or `_order_ticks < AVOID_GRACE_TICKS` then `_wait_end()`; else
  `waited = _wait(here, to / distance, route_preferred, desired)`; if `waited >= 0` return [waypoint, waited].
- **`_wait(here, way, preferred, desired)`:** tick = physics frame. If `_wait_for != ""` and tick - `_wait_since` >= 5 s x TICK_RATE:
  wait_timeouts++, `_wait_refused = _wait_for`, `_wait_refused_until = tick + 6 s x TICK_RATE`, `_wait_end()`, return -1. found =
  `_wait_blocker(here, way, preferred)`; empty: `_wait_end()`, return -1. other = found[0], kind = found[1], name = other.name. If
  name == `_wait_refused` and tick < `_wait_refused_until`: `_wait_end()`, return -1. If `_wait_for != name`: `_wait_end()`,
  `_wait_for = name`, `_wait_since = tick`, waits++. wait_queued++, wait_by_kind[kind]++ (measurement). off = other - here (flat);
  gap = radius_of(me) + radius_of(other) + 1.0; its_along = max(other.real_velocity (flat) . way, 0); v = max(off . way - gap, 0) /
  1.5 + its_along; return clamp(v / max(desired, 0.1), 0, 1).
- **`_wait_end()`:** if `_wait_for == ""` return; s = (frame - `_wait_since`) / TICK_RATE; if s >= 2.0 wait_long++; if s > wait_longest.s
  record {crew, for, s} (measurement); `_wait_for = ""`, `_wait_since = -1`.
- **`_wait_blocker(here, way, preferred)`:** over the living friends of my team (tanks_root children, not me): off = other - here,
  along = off . way; skip along <= 0. width = radius_of(me) + radius_of(other) + 0.5. If along <= 12.0 and |off x way| <= width: a lane
  candidate, nearest `along` wins. Else, only while no lane candidate yet (best_along == INF): v_rel = other.real_velocity (flat) -
  preferred; t = `_meet_in(off, v_rel, width)`; the smallest t < 2.0 wins. None: []. kind = `_wait_kind(best, way)`; "" -> [].
- **`_meet_in(p, v_rel, r)`:** a = |v_rel|^2, b = 2 p . v_rel, c = |p|^2 - r^2; c <= 0: 0 if b < 0 else INF; a < 1e-6: INF; disc = b^2 -
  4ac < 0: INF; t = (-b - sqrt(disc)) / 2a; t if t >= 0 else INF.
- **`_wait_kind(other, way)`:** v = other.real_velocity (flat), speed = |v|. If speed >= 1.0: cos = v . way / speed; "" if cos <= -0.5
  (head-on); "" if cos >= Traffic.FOLLOW_COS (0.866, going my way); else "moving". Else: mover = Movement.of(other); "" if null, not
  under way (phase == "arrived") or `_goal` == INF. If mover.`_wait_for` != "": "" if it equals MY name (a cycle) else "waiting".
  its_way = mover.`_travel_direction`(`_goal`, false); "" if zero or its_way . way <= -0.5. nose = -other.basis.z (flat, unit);
  "turning" if nose . its_way < cos(30 deg) else "".
- **The ask gate (drive):** the `_negotiate` call runs only if `(stalled_ticks >= ASK_SECONDS x TICK_RATE or held_back) and _wait_for == ""`.
- **`reset()`:** `_wait_for = ""`, `_wait_since = -1` beside `yield_to = ""`.
- **Traffic:** `wait` in DEFAULT_OFF; `--traffic-on=wait` turns it on; while on, Traffic._chain_native sets native_drive false until
  the twin lands (drop that clause when it does).

### v4 reads (f7fd7819a; `~/overnight-manoeuvre/r41/v4labs/`, builder0 light, native for the bridge, GDScript both arms for the group order)

| Read | OFF -> v4 ON |
|---|---|
| bridge, overrides tree (225087f27) | **17/18 -> 18/18**; pooled rim 14.2 -> 9.8 s (-31 %; paired -0.24 s a run, se 0.30, -0.8 se); deck jam 17.1 -> 10.4; worst crew 5.1 -> 1.5; arrival 34.9 -> 36.7 |
| bridge, main (f7fd7819a) | 18/18 -> 18/18; pooled rim 8.1 -> **10.7 s (+32 %**; +0.14 s a run, se 0.20); deck jam 7.5 -> 9.7; worst 1.5 -> 2.4; arrival 36.6 -> 37.8 |
| group order, 16 paired cells (7001-7004 crew) | jam-seconds 13,365 -> 14,015 (+4.9 %; +41 s a run, se 46, 0.9 se); all-in 80.4 -> 82.3 (+1.9 s, se 2.7); never-in 10 -> 10; contacts -1.3 %; waits 1,129 a run (17 >= 2 s), turning 57k / waiting 48k crew-ticks |

**The wait family's table so far (bridge rim pooled, 18 runs; group order 16 paired cells):**

| Variant | Keys | Overrides bridge | Main bridge | Group order jam-s |
|---|---|---|---|---|
| v1 (a553f85b0) | crossing + same_way + turning(slow) + chain | 17/18 -> 18/18, rim 14.2 -> 1.3, arrival 34.9 -> 32.7 | not read | +8.8 % (2.4 se) |
| v2 (c8e329b23) | crossing + turning(slow) + chain | read running (`bridgev2/`) | 18/18, rim 8.1 -> 3.4, deck 7.5 -> 16.2 | +7.3 % (1.9 se) |
| v3 (aaac5c133) | v2 + lock-on, lane-exit, tie-break | not read | not read | +8.5 % (2.3 se) |
| v4 (f7fd7819a) | turning leader (moving or slow) + chain | 17/18 -> 18/18, rim 14.2 -> 9.8 | 18/18, rim 8.1 -> 10.7 (+32 %) | +4.9 % (0.9 se) |

Reading: every variant clears the overrides' failing run (the CP41.1 gate as a hard guard); the deciding pooled-rim line on main is
met by v2's crosser key (-58 %) and failed by v4's turning key (+32 %): at the deck mouth the leader swinging onto the deck reads as a
CROSSER by its velocity before its nose is 30 deg off its next leg, so v4 fires late. The group order is neutral-to-worse for all
four (v4 the mildest). The wait family trades the bridge for his group order; the orchestrator rules (message sent 04:50).

### Bar Q3 (DRAFT, not filed; filed the minute v4's dev reads justify it, BEFORE any number on 9025-9048)

- **The rule judged:** `--traffic-on=wait` as of v4 (f7fd7819a or a later hash named at filing): a crew waits (holds its route's
  steering, follows at a closing pace, asks nobody) behind a friend that is itself turning toward its own next leg, or behind a
  friend waiting for such a one; 5 s cap, 6 s cooldown. `waitcross` OFF. Orders' O2 OFF in both arms (`--group-depart` unset, R41.4).
- **Gate:** the tree's full check green on builder0 first (C31.1), named here; the series from that frozen tree (R40.13).
- **Arms:** OFF (default) v ON `--traffic-on=wait`; both `--brains-off=native_drive` (the pair compares the rule alone; ON forces the
  GDScript drive anyway until the twin lands). **Trees:** main AND balance's v2 overrides (bt = the bar's hash + 8e257f3bc + d385cd308).
- **Deciding (R41.3): pooled rim-seconds** on bridge-drill seeds 9025-9036 x start ticks {1, 8, 15} x both sides (72 runs an arm a
  tree): ON <= 0.8 x OFF pooled AND the paired per-run mean < 0 by >= 2 se, on BOTH trees. Every surviving crew crosses in both trees
  with ON. Runs with a crew over the 3 s rim line: ON <= OFF (named). bridge-pooled's own 18/18 line stays a hard guard (check).
- **Guards on 9037-9048** (the group-order lines, so the bridge fix never costs his big order): orders' O1 probe cells crossing /
  locks / sumps / terminus x 9037-9048 x crew headings (48 runs an arm): G5 never-in runs ON <= OFF; D-style jam-seconds ON <= 1.05 x
  OFF (not deciding; a no-harm line); every-squad-in paired mean <= +2.0 s; friendly contact ticks ON <= 1.10 x OFF
  (`wait_judge.py` lines). Fight lines: the dev cells round 40 used (`manoeuvre-wedge-trace` locks/terminus/sumps x 9037-9042, M3's
  G1-G4 via `follow_judge.py`'s rows): give-way and stuck deaths within max(2 paired se x n, 3); contacts <= 1.10 x; kill share
  within 0.03 and deaths within 5 %.
- **Reported:** deck-jam seconds, mean arrival, the rule's counters (waits, >= 2 s waits, time-outs, longest) per tree and arm.
- **Dev history (C41.1):** Q2's three broad variants were labbed on 7001-7004 (+8.8 / +7.3 / +8.5 % jam-seconds) and stopped (R41.5);
  v4's dev reads: the bridge on seeds 1-3 (bridge-pooled), the group-order cells 7001-7004. No number on 9025-9048 has been read.
- **Judge:** `bridge_lab_table.py --pair` per tree for the deciding line; `wait_judge.py` for the group-order guards; `follow_judge.py`
  for the fight guards. A pass ships ON with native's twin (CP41.1: the orchestrator merges it alone and tells balance). A fail: OFF,
  no re-run on these seeds.

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

