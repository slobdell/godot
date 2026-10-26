# Stream: manoeuvre (fewer shoves in his big order, judged on what he sees; the bridge crossing clean under the stat change)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 42** (C42.1, C42.4,
> CP42.0, CP42.1) and *Rulings (round 41)* R41.5-R41.10, R41.13; your round-41 brief `streams/archive/round41/manoeuvre.md` (Status:
> CLOSE REPORT, the Q5 labs, the reversing report, the `_wait` timer artefact, *Round-42 notes*). **You own:** movement's drive /
> unstick / side-step / avoidance in `game/ai/movement.gd`, `game/ai/traffic.gd`, `tests/manoeuvre/**`, `tests/traffic/**`,
> `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`, `mk/manoeuvre.mk`. **Model:** Fable. **Machine:** builder0 light lane (J<=4);
> builder2 for a bar series (`make gcp-start`; Spot). **Seeds:** 9801-9824 (Bar Q5), 9825-9848 (the bridge, fresh BRIDGE_POOLED_SEEDS).
> Dev 7001-7012 (never a bar). Side refs: `wip/manoeuvre-m1v3` (Q5: a45c0b953 + fc8f3697d), `pair/native-wait` 20300bb52.

## The lead's direction

His round-40 playtest (verbatim in `game_design.md`): "when I'm controlling a large set of squads at once and commanding all of them to
go somewhere, a bunch of units block other units ... I suspect that we might get better navigation with a little more coordinated
movements". Round 41 tried both forms of his traffic idea (wait for a friend: Q2 v1-v3; hold the lane: Q4) and both made his 5-squad
order slightly worse (R41.7); G1 v9 (orders) now lays his group click as a column (contacts -23 %). What he sees of what is left is
crews shoving each other (Q5: contacts -28 %, shoved ticks -34 %, but all-in +2 s and never-in 6 -> 7: R41.10). His standing bar
(memory, *units must look smart*): he must perceive units as smart and under his control; contention first.

## Where things stand (main at launch: see HANDOFF)

- **Q5 "no pressing" v2** (`--traffic-on=nopush`, capped ease ~3 s per friend then today's press; fc8f3697d on `wip/manoeuvre-m1v3`):
  OFF, no bar, R41.10's frame for round 42 verbatim: *"a bar decided on what he sees (friendly contacts / shoved ticks), with all-in
  and never-in as strict guards, on fresh seeds; jam-seconds reported, not deciding."* Your proposed lines are in the archived Status
  (*Round-42 notes* 1). Its four members (`_nopush_for`, `_nopush_until`, `_nopush_since`, `_nopush_press_until`) need
  `native/src/exec_fields.h` lines before the commits can sit on a checked tree: **CP42.0, native merges them first; you cherry-pick
  after the orchestrator announces it.**
- **The bridge under the stat change:** balance's v2 overrides tree crossed bridge-pooled 72/72 on fresh 9025-9036 x ticks {1,8,15}
  (pooled rim 26.7 s, worst crew 2.2 s); its only known failure is the 18-run drill's rust t15 s2 (Rust_S_3, 5.1-5.4 s at the rim v
  3 s; cause R40.21: ORCA steers a wheeled follower out past the deck mouth while its leader turns). bridge-pooled is a hard guard,
  not re-seeded or loosened (R40.24, R41.3). Three F1 forms (round 40) and the wait family (round 41) each fixed it and broke
  something else. Bar B2s v2 (balance) waits on this: **CP42.1.**
- `_wait`'s timer artefact (archived Known issues): any revived wait or hold rule must end its timer from every drive phase.
- Every per-crew state is a real Movement member with an exec_fields.h entry (C42.4 = C41.2); a rule that steers differently from ORCA
  says so in its bar; native twins a rule before it ships ON (request via the orchestrator).

## Backlog (in order)

1. **Q5.1 Bar Q5 on fresh 9801-9824, inside R41.10's frame.** After CP42.0: cherry-pick a45c0b953 + fc8f3697d onto main, quick-green.
   File the bar before any number: deciding = friendly contact ticks AND shoved crew-ticks (the reverse attribution) on his 5-squad
   across click (orders' probe, crew headings, 4 maps), ON <= 0.8 x OFF pooled AND paired mean < 0 by >= 2 se, both; strict guards
   (filed first): never-in runs ON <= OFF, every-squad-in mean ON <= OFF + 1.645 se, the wedge trace's fight lines G1-G4; jam-seconds
   REPORTED only (ruled: the orchestrator records your eased-ticks-removed variant as a reported column, not a guard). Both arms
   GDScript drive (`--brains-off=native_drive`) until twinned. The whole suite ON (C31.1) before the series. On a pass: native's twin,
   then ON (the orchestrator merges; perf-judge in a quiet window).
2. **Q6 the bridge rim crew (speed only, C42.4).** Trace rust t15 s2 on today's main with balance's v2 overrides
   (`~/balance-guard-raw/b5/` has override files; the v2 recipe is in balance's archived Status): which crew, which tick, which steer.
   A rule that slows a wheeled follower at the deck mouth while its leader turns (no steering change), real members, OFF behind
   `--traffic-on=<name>`. Bar Q6 before any number on 9825-9848: deciding = bridge-pooled 18/18 under the overrides (the hard line)
   AND pooled rim on 9825-9836 x ticks {1,8,15} x both sides, main and overrides, ON <= OFF (no worse) with the drill's worst crew
   <= 3 s; guards = R41.6's group-order lines on 9837-9848 (all-in mean and never-in squads ARM <= BASE + 1.645 se, contacts <= BASE x
   1.05) and fight G1-G4. A pass = CP42.1: tell the orchestrator the minute the hash is green; balance's Bar B2s v2 runs on it.
3. **Stretch:** the `_wait` timer fix (so a future wait rule's counters can be trusted), tested; a lab on the long shoved episodes
   (15-30 s, stalled or parked heads at street mouths) with Q5 ON: what remains.

## How to verify

`make test FILTER=traffic NATIVE=off`; `make manoeuvre-probe-jam` (the judges and tables under `tests/manoeuvre/`); `make remote
T=native bridge-pooled BRIDGE_POOLED_SEEDS=... BRIDGE_FLAGS=...`; `make quick-remote`; a full check of every hash you name. Smoke like
a player: `make skirmish ARENA=terminus SKIRMISH_FLAGS="--traffic-on=nopush"` v without: select all, send them across; who shoves,
who waits, does anyone stand.

## Don't touch

`game/control/**` and the planner (orders' / nobody's), `game/tactics/**` (engage, settle's functions), `game/camera/**`, `native/**`
(ask via the orchestrator), `game/units/**` (balance), `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing. (His decision 2, a click beside his army, is orders' question and needs no code from you.)

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Session start 2026-10-26 ~14:55 PDT (Fable). Starting commit 18982e8df = main at launch (code 21b20bdce GREEN builder0, 3289/0, 28 ALL
JUDGED; no baseline check re-run, per the contract). Orchestrator session: `godot-8c` (godot-45 stood down).** Side trees: `../godot-manoeuvre-bt`
(`wip/manoeuvre-bt-r42` = main + 8e257f3bc + d385cd308: balance's v2 overrides, for the bridge reads), `../godot-manoeuvre-q5`
(`wip/manoeuvre-q5-r42` = main + native's 75495744b + a45c0b953 + fc8f3697d: Q5 dev until CP42.0 lands). Evidence outside every
worktree: `~/overnight-manoeuvre/r42/`.

### Where it stands (2026-10-26 ~16:50 PDT): both bars filed; the gate check of the frozen tree 7569747ce is queued on builder0

- **Frozen tree 7569747ce** (code ac64ce939 = main bf99631b5 with CP42.0 + Q5 a45c0b953 / fc8f3697d cherry-picked + deckwait v4 +
  this stream's judges/instruments): `make remote T=check` launched ~16:45 (`~/overnight-manoeuvre/r42/gate1/`; behind engage's and
  camera's checks in builder0's lock). One check gates Bar Q5 and Bar Q6 (R42.7). Laptop: `make test FILTER=traffic NATIVE=off`
  127/0 at 520516ec3; deckwait 7/0 at ac64ce939.
- **Bar Q5** (recorded on main as filed): the series `~/overnight-manoeuvre/r42/barq5.sh` (HOST=builder2 on the orchestrator's word
  after engage's guards, else builder0 light) starts after the gate's green wrapper line.
- **Bar Q6** (recorded on main as filed, 7569747ce): `~/overnight-manoeuvre/r42/barq6.sh` (builder0 light lanes: this worktree's and
  the overrides tree's `../godot-manoeuvre-bt` = d9382eed7 = 7569747ce + 8e257f3bc + d385cd308) after the same green line; one half
  at a time if `tools/loaded.sh` says the lane is full.
- **Stretch 3 (running, dev seeds):** the long shoved episodes with Q5 ON, `q5lab3` (crossing/locks/sumps/terminus x 7009-7012,
  main v nopush, GDScript both): what remains after no-pressing.
- Rulings this round so far: R42.7 (the arrival guard; one check gates both bars; v4 the last re-file).

### Plan (ordered; the brief's backlog as built)

1. **Bar Q5 FILED** (below) before any number; its judge `tests/manoeuvre/q5_judge.py` and the reported column's instrument
   (`probe_jam.gd` eased ticks) on the branch. Waits on CP42.0 for the frozen tree (cherry-pick, quick-green, full check, series).
2. **Q6 step 1 (done, below):** the failure reproduced on today's main + overrides and traced. Step 2: the rule, speed-only, built OFF
   behind `--traffic-on=<name>`, with its test; Bar Q6 filed before any number on 9825-9848; dev reads on the drill's seeds 1-3 only.
3. Stretch: the `_wait` timer fix; the long shoved episodes lab.

### Q6 step 1: the bridge failure is on today's main + overrides, and it is the mouth (2026-10-26 ~15:05 PDT)

Tree d1e91f74c (`wip/manoeuvre-bt-r42` = 18982e8df + 8e257f3bc + d385cd308), builder0 light lane, `--brains-off=native_drive`,
`~/overnight-manoeuvre/r42/q6trace1/`: **bridge-pooled 17 of 18, failing rust tick 15 seed 2, Rust_S_3 rim 5.1 s (rim_total 5.4,
deck jam 2.7, arrived 48.9 s)**: R40.21's numbers exactly, so the case is unchanged by rounds 41-42's merges. The trace (BRIDGE_TRACK,
every 0.5 s): the east swing bridge's deck is x 85-99, z -12..12 (the canal z -7..7); the route's lane hugs the deck's west side
(steer points (86,-10.5) -> (88,9) -> (86,11.7)), so each crew arrives heading east along the north bank and turns right (south) at the
mouth. S_4 (first) enters at t14 at 6 m/s and swings wide to x 93; S_1 (second) reaches the mouth at t15.5 at 7.8 m/s with S_4 3 m
ahead, is steered east (93,-4.5), crawls to (91,-2) by t18 and spends t18.5-22.5 reversing / "blocked by terrain" at x 91 before
driving south at t22.5 (6 s lost, rim 0.3 s: it was never still). **S_3 (third) arrives at t17.0 at 11.1 m/s, 4 m behind S_1 which
is in the mouth at 0.6-3.8 m/s; ORCA moves its steer point east past the mouth ((92.7,-11.3) then (95.8,-2.9)); S_3 stalls at
(90-91,-10) by t18.5, S_1 reverses into it (t19-20), S_3 yields to S_1 and backs west 7 m (t20.5-24.5), re-enters at t26.5 and
crosses at 10 m/s.** At the exit every crew swings wide again (x 90-91, z 7-13, v 0-4 for 2-4 s). The rim seconds are S_3's two stalls
(the mouth, then the exit). **What a speed-only rule must do:** S_3 must not arrive at the mouth at 11 m/s while S_1 is turning in it;
at S_1's speed ORCA has no reason to carry S_3 east past the mouth, and S_1 has room to come round. That is the brief's rule (slow
a wheeled follower at the deck mouth while its leader turns), with the trigger read from the trace: a friend ahead on my route, within
~12 m, inside the deck's mouth (the turn vertex within 8 m of it) and slow or turning. Built next, OFF, with a test on this case.

### Q6 step 2: `deckwait` built OFF (v1 460f3591b ... v4 ac64ce939; `--traffic-on=deckwait`); dev reads 1-13 (2026-10-26 15:25-16:35 PDT)

**The rule (speed only, C42.4):** a WHEELED crew with a friend ahead in its lane (WAIT_AHEAD_M 12 m, both radii + 0.5 m) that is in
a bridge deck's MOUTH (the deck's rectangle grown by DECKWAIT_MOUTH_M 6 m, less the water it spans: the aprons and the bank at
either end, read from `Arena.active`'s terrain) lowers its SPEED WISH to a following speed (the friend's speed my way, closing to
WAIT_GAP_M over WAIT_FOLLOW_S) BEFORE ORCA solves; the direction wish and ORCA's answer (direction, steer point) are untouched, and
the pace returned is read against the route's full wish so the cap reaches the throttle. A friend through the mouth at speed lowers
nothing. DECKWAIT_CAP_S 5 s per friend, then today's wish for WAIT_COOLDOWN_S 6 s (a head that never clears is passed as today).
**Why the friend's place and not my route's turn vertex:** the first build keyed on `_turn_vertex` and the trace in
`test_traffic_deckwait` showed the vertex come and go while ORCA deflects me (the path is re-planned / the index advances), which
reset the cap every few ticks. **State:** Q2's wait members (`_wait_for`, `_wait_since`, `_wait_refused`, `_wait_refused_until`:
the same meaning; exec_fields.h lines already in place, so no native request for a checked tree); `deckwait` and `wait` are
exclusive (`wait` wins). Counters deckwait_waits / _queued / _timeouts (route_arms, JAM_RUN); ON forces the GDScript drive
(`Traffic._chain_native`) until twinned. **The `_wait` timer artefact (stretch 3, done with it):** `drive()` ends a wait on any tick
that never reaches the rule (goal within reach, a reverse, no avoidance), and `_avoid`'s hold path and near-waypoint return end it
too, so `_wait_since` only counts ticks the rule was asked on (test: `test_a_wait_ends_on_a_tick_that_never_weighs_it`).
**Tests** (`tests/test_traffic_deckwait.gd`, laptop NATIVE=off, 80d8b5582): 6/0: off by default; the mouth test on the Locks (the
deck's corners and apron in, over the water and the bank 20 m west out, no mouths on yard_open); the slow-leader case (ON queues
300 ticks and still crosses; in that staging the leader crawls at 3 m/s and ON costs the cap twice, 27.1 s v 9.5 s to cross:
whether waiting beats passing in the real mouth is the drill's question); a parked head (waited on 150 ticks = the 5 s cap, then
timed out and refused for the cooldown); tracked crews / a clear lane / `wait` named too leave it off; the timer artefact.
`make test FILTER=traffic NATIVE=off` on the branch: pending (the full traffic filter runs after the drill read).
**Dev read 1 (39c2f55ad = d1e91f74c + the rule, builder0 light, GDScript drive, `~/overnight-manoeuvre/r42/q6dev1/`): the hard
line passes, the squad is slower.** bridge-pooled under the overrides ON **18/18** (OFF 17/18): rust s2 t15 Rust_S_3 rim 5.4 -> 2.3 s,
arrived 48.9 -> 41.8 s. But pooled rim 14.2 -> 15.5 s and mean arrival 34.9 -> 39.0 s over the 18 runs (worst: green s1 t8 43.0 ->
60.1 s, rust s3 t1 39.6 -> 51.3, green s3 t1 27.2 -> 37.3). The ON trace of rust s2 t15: the rule never slowed S_3 before the mouth
(S_1, the leader, was 1 m onto the water at 1-3 m/s, and the first mouth zone excluded the whole water span), S_3 still arrived at
10.5 m/s and stalled at the deck's north-east edge 4.5 s; what the rule changed was downstream. Fixed in 550e96c07: the mouth reaches
DECKWAIT_MOUTH_M onto the water. **Dev read 2 (q6dev2, traces of green s1 t8 OFF / ON, 39c2f55ad):** ON, Green_S_2 sat 8 s at v 0
on the north apron (-81,-12) after crossing (OFF: 1-2 s there, blocked, then on), and S_1 and S_4 queued 6 s behind that; a chain of
waits in the exit's mouth zone, each capped at 5 s on a new friend. **Dev read 3 (q6dev3, the same run ON with `--deckwait-trace`, 550e96c07):** two causes. (1) At the entry the followers stood
8 m behind a leader that was turning north onto the deck at 3 m/s: its speed along MY way read 0, so the cap was the closing term
alone (0.5-1.3 m/s) for the whole 5 s. (2) At the exit a leader parked on the far apron (Green_S_2 at (-81,-12), v 0 for 8 s) was
never asked to give way: the ask gate (`_wait_for == ""`, Q2's) was shut for every waiting follower, each 5 s on a new friend.
**v2 (0b47dfbd8):** the leader counts by its speed AWAY from me (`v . off_hat`, never negative), and the ask stays as today (only
Q2's `wait` holds it). Unit tests 6/0 (laptop). **Dev read 4 (q6dev4, v2 on the overrides tree, bridge-pooled ON, builder0 light,
GDScript):** **18/18, pooled rim 14.2 -> 9.3 s (-35 %), worst crew 1.5 s** (rust s2 t15: rim 5.4 -> 0.8, deck jam 2.7 -> 4.6,
arrived 48.9 -> 53.4); mean arrival 34.9 -> 36.5 s (+1.6; green s2 t8 39.1 -> 48.0, green s2 t15 35.0 -> 41.8, green s1 t8 43.0 ->
38.5, rust s3 t1 39.6 -> 36.2). **Dev read 5 (q6dev5, green s2 t8 traced OFF / ON, 0b47dfbd8):** the crossing itself is +3.6 s (crossed 23.2 -> 26.8:
S_4 waited ~2 s at the deck's north end on S_3 stopped on the far apron, S_1 behind S_4; rim 1.8 v 1.9, deck jam 1.3 both); the
other +5.4 s of the arrival (39.1 -> 48.0) is after the bridge: the crews reach the far quay in another order and their regroup
differs (no DECKWAIT line after t 28). Arrival on 18 deterministic cells is a reshuffle (R40.24's lesson), which is why the bar
decides on rim-seconds pooled over 72 fresh runs a tree and reports arrival. **Dev read 6 (q6dev6, v2 on MAIN, OFF / ON, this stream's light folder):** 18/18 both; pooled rim 8.1 -> 7.3 s, worst 1.5 -> 1.1;
but deck-jam seconds 7.5 -> 17.2 and mean arrival 36.6 -> 39.1 s: followers queued on the deck behind a leader stopped at the exit.
**v3 (a765e2ba6): a leader already beyond the water (through the crossing, on the far apron) is passed as today; the rule is the
entry's.** Dev reads 7-8 (v3 ON, both trees, `bridge_lab_table.py --q6`): OVERRIDES 18/18, rim 14.2 -> 11.2 s (-21 %), worst 1.9,
arrival +0.92 s a run (se 0.66); MAIN 18/18, rim 8.1 -> 7.8, worst 1.1, deck jam 7.5 -> 17.2, **arrival +2.51 s a run (se 1.38,
+1.8 se)**. An arrival guard joins Bar Q6 (paired per-run arrival ON <= OFF + 1.645 se, each tree: a bridge fix that makes every
crossing slower is not what he asked for), and v3 would fail it on main's drill seeds, so dev read 9 (q6dev9, running) traces
main's worst run (green s2 t1, 28.8 -> 42.6 s) OFF / ON before the rule is tuned or the bar filed. Native's OFF-path read of
0b47dfbd8 (a wish under 0.1 m/s read wish / 0.1 on the clear-way return) fixed in 520516ec3 with a test. CP42.0 taken: main
bf99631b5 merged (8026d9696), Q5 cherry-picked (09db261b7, 8f1166f69; conflicts in DEFAULT_OFF / _chain_native / route_arms
resolved); `make test FILTER=traffic NATIVE=off` laptop 127/0.

### Bar Q6: FILED 2026-10-26 ~16:40 PDT, BEFORE any number on 9825-9848 (the brief's lines + R42.7's arrival guard)

- **The rule judged:** `--traffic-on=deckwait` **v4** as at code ac64ce939 (the frozen tree = this branch's tip at the gate check,
  named below; R40.13: no game/ or tests/ commit until the series' end line): a WHEELED crew with a friend ahead in its lane
  (WAIT_AHEAD_M 12 m, both radii + 0.5 m) that is in a bridge deck's MOUTH (the deck's rectangle grown by 6 m, less the water more than
  6 m in from its edge) and not yet beyond the water lowers its SPEED WISH, before ORCA solves, to the friend's speed away from me plus
  closing to 1 m behind it over 1.5 s, never under 0.4 x its own top speed (a limit at the mouth, not a queue); ORCA's direction and
  steer point are its own answer to that wish (speed only, C42.4); asks, give-ways and right-of-way as today; 5 s per friend then that
  friend refused for 6 s. State = Q2's wait members (exec_fields in place); `wait` and `deckwait` exclusive; ON runs the GDScript
  drive until twinned. Every other switch at main's defaults; `nopush` OFF in both arms.
- **What it could break (named first):** a slower approach to every mouth (the drill's arrival: the arrival guard; his 5-squad order on
  the two maps with decks, crossing and locks: G5 / G6); a crew easing in a fight (G1-G4); contacts (G7).
- **Gate:** the frozen tree's full check green on builder0 FIRST (C31.1; one check gates Bar Q5 and Bar Q6, R42.7). **Arms:** OFF
  (default) v ON `--traffic-on=deckwait`, both `--brains-off=native_drive`; same seeds, same cells, paired.
- **Deciding 1 (the hard line):** bridge-pooled 18/18 under balance's v2 overrides, ON (seeds 1-3 x ticks {1,8,15} x both sides; the
  overrides tree = the frozen tree + 8e257f3bc + d385cd308).
- **Deciding 2 (`bridge_lab_table.py --q6`, each tree, main AND overrides):** pooled rim-seconds on fresh 9825-9836 x ticks {1,8,15}
  x both sides (72 runs an arm a tree) ON <= OFF; every surviving crew crosses ON; the worst crew's rim ON <= 3 s.
- **Arrival guard (R42.7), each tree:** paired per-run arrival ON <= OFF + 1.645 se over the 72 runs.
- **Group-order guards (R41.6's lines, `q3_judge.py --arm=deckwait`):** orders' O1 probe cells crossing / locks / sumps / terminus x
  9837-9848 x crew headings (48 paired runs): G5 all-in mean ARM <= BASE + 1.645 se (paired; never-in reads as 90 s); G6 never-in
  squads a run ARM <= BASE + 1.645 se; G7 friendly contact ticks ARM <= 1.05 x BASE.
- **Fight guards:** `manoeuvre-wedge-trace` locks / terminus / sumps x 9837-9842 (18 fights an arm), `follow_judge.py --on-arm=deckwait`
  G1-G4 (give-way deaths and stuck deaths ON - OFF <= max(2 paired se x n, 3); friendly contact ticks <= 1.10 x; kill share within
  0.03 and deaths within 5 %).
- **Reported:** deck-jam seconds, mean arrival per tree, the rule's counters (deckwait_waits / _queued / _timeouts; wait_longest),
  jam-seconds and the per-cell table on the group order.
- **Dev history (C42.1, R42.7: four variants, the drill's seeds 1-3 only; no number on 9825-9848 read):** v1 460f3591b (keyed on my
  route's turn vertex; the vertex flickered under ORCA's deflection, the cap reset); v2 0b47dfbd8 (keyed on the friend's place in the
  mouth, the leader's speed away from me, the ask as today): overrides 18/18, rim 14.2 -> 9.3, arrival +1.6 s; main rim 8.1 -> 7.3,
  arrival +2.5 s, deck jam 7.5 -> 17.2 (followers queued on the deck behind a leader at the exit); v3 a765e2ba6 (a leader beyond the
  water passed as today): overrides rim -21 %, arrival +0.9; main rim -4 %, arrival +2.5 s (1.8 se: would FAIL the arrival guard; the
  trace: a follower crawling at 2-3 m/s into the mouth corner caught the near rail's end, 16 s); **v4 ac64ce939 (the wish never under
  0.4 x top speed):** OVERRIDES (q6dev12 OFF 17/18 / q6dev10 ON 18/18, tree 2dca03baf): rim 14.2 -> 8.6 s (-39 %), worst 1.3 s,
  arrival +1.33 s a run (se 0.95; line +1.57) PASS; MAIN (q6dev13 / q6dev11, ac64ce939): 18/18 both, rim 8.1 -> 7.4 s, worst 1.1,
  arrival +1.36 s a run (se 1.23; line +2.02) PASS; both trees PASS every --q6 line. builder0 light lane, GDScript drive, n 18 a cell.
- **Machine:** the drill halves on builder0's light lane from this worktree's and the overrides tree's folders (deterministic cells);
  the group-order guards on builder2 if free, else builder0 light; the fights on builder0 light. `~/overnight-manoeuvre/r42/barq6.sh`
  runs it; evidence `~/overnight-manoeuvre/r42/barq6/`, filed under `references/round42/manoeuvre/barq6-<machine>-<hash>/`. A pass =
  CP42.1 (the orchestrator asks native for the twin, merges it alone, tells balance). A fail: OFF, no re-run on these seeds.

### Bar Q5: FILED 2026-10-26 ~15:20 PDT, BEFORE any number on 9801-9824 (R41.10's frame; the brief's lines)

- **The rule judged:** `--traffic-on=nopush` v2 exactly as at fc8f3697d (no pressing, capped): a crew whose hull touches a FRIEND ahead
  (the friend's centre forward of mine) that is not pulling away (its speed along my nose no more than 0.3 m/s above mine) holds its
  forward throttle at 0 while the contact lasts and 0.5 s after, for at most 3 s per friend, then today's press for 6 s, then it may
  ease again; reverse orders exempt; ORCA's steer point, the asks, the give-ways and right-of-way exactly as today (speed only,
  C42.4). The tree = CP42.0's main + a45c0b953 + fc8f3697d + this branch's judge/instrument; its hash is named at the series' launch
  (frozen, R40.13: no game/ or tests/ commit until the end line). Every other switch at main's defaults (G1 v9 ON, camera-glide ON).
- **What it could break (named first, round 37's lesson):** a column whose head has stopped stands instead of grinding through (his
  squads never arrive: G6 / G5); a crew easing in a fight dies where it would have pushed clear (fight G1-G4); jam-seconds rise by
  construction (the eased ticks count as "slowed by a friend"), so they are reported, never deciding (R41.10).
- **Gate:** the frozen tree's full check green on builder0 FIRST (C31.1), read from the wrapper line. **Arms:** OFF (default) v ON
  `--traffic-on=nopush`, BOTH `--brains-off=native_drive` (the rule alone; the GDScript and C++ drives are bit-identical per
  test_native_drive). Same seeds, same cells, paired.
- **Workload:** his 5-squad across click (orders' O1 probe through `make manoeuvre-probe-jam`, `PJ_HEADINGS=crew`), 4 maps crossing /
  locks / sumps / terminus x seeds 9801-9824 = **96 paired runs an arm**, 90 s window. Fight guards: `manoeuvre-wedge-trace` locks /
  terminus / sumps x 9801-9806 (18 fights an arm).
- **Deciding (both must hold; `q5_judge.py`):**
  - **D1 friendly contact ticks** (ORDERS_PROBE.contact_ticks): ON pooled <= 0.8 x OFF pooled AND the paired per-run mean < 0 by >= 2 se.
  - **D2 shoved crew-ticks** (JAM_EP.reverse_why "shoved": moving backward with no reverse throttle, a hull in contact; the reverse
    attribution of the reversing report): ON pooled <= 0.8 x OFF pooled AND the paired per-run mean < 0 by >= 2 se.
- **Strict guards (filed first):** **G5** every-squad-in mean ON <= OFF + 1.645 se (paired; a never-in run reads as 90 s); **G6** never-in
  runs ON <= OFF (a count, no slack); **fight G1-G4** (`follow_judge.py --on-arm=nopush`): give-way deaths and stuck deaths ON - OFF <=
  max(2 paired se x n, 3); friendly contact ticks <= 1.10 x; kill share within 0.03 and deaths within 5 %.
- **Reported, never deciding:** jam-seconds (probe_jam's); jam-seconds with the rule's own eased ticks taken out (JAM_EP.eased_s, this
  branch's instrument: the asker's ticks under `_nopush_until`; the orchestrator's ruling on the variant: a reported column); the rule's
  counters a run (eased crew-ticks, episodes, capped); never-in squads; per-cell table.
- **Power / dev history (C42.1):** the same rule's two dev labs (round 41, 7009-7012 x 4 maps = 16 paired runs, builder0 light, GDScript):
  v2 D1 233,375 -> 168,724 (-27.7 %, paired -3.6 se), D2 26,997 -> 17,689 (-34.5 %, -3.2 se), G5 76.9 -> 78.9 s (inside the line),
  **G6 6 -> 7 runs (would FAIL)**; `q5_judge.py` on those logs reproduces every number (the judge's own check). At n 96 the deciding
  se is ~2.4x smaller; G6 is the line at risk and is a count, so one more standing column than OFF fails the bar. No number on
  9801-9824 has been read. No early stop (deterministic cells, the grid runs out).
- **Machine:** the group-order series on builder2 (`make gcp-remote`; C42.1: a bar series over 24 fights) if it is up, else builder0's
  light lane; the fights on builder0 light; the gate check on builder0. Evidence `~/overnight-manoeuvre/r42/barq5/`, filed under
  `references/round42/manoeuvre/barq5-<machine>-<hash>/`. A pass: the orchestrator asks native for the twin, then ON (perf-judge in a
  quiet window). A fail: OFF, no re-run on these seeds; the long-episode lab (stretch 3) says what remains.
