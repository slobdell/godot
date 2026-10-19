> **ARCHIVED (round 34, closed 2026-10-19).** The round-34 brief as the stream left it (its Status is the record). Round 35 briefs are in `streams/`.

# Stream: traffic (a crew stuck behind a parked crew of another squad gets by, and the parked crew goes home: parkedroom v4; then T4's circling hull)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 34**
> (C34.1–C34.3; C31.1–C31.3, R31.1–R31.10, R32.1–R32.7, R33.20, R33.32 stand), its *Round 33* rulings R33.12, R33.36,
> R33.37 and R33.29–R33.30, `_agents/roadmap.md` *Round 34 candidates*, and your round-33 brief
> `streams/archive/round33/traffic.md` (**ROUND 34: OPEN ITEMS** at the top of its Status, the v2/v3 results, T4's G2).
> Evidence: `streams/references/round33/traffic/` (ov_parkedroom_v2_bar.md "v3 result", ov_parkedroom_v3_l3_trace.md,
> ov_t4_bar.md, ov_replay.md; `r33_traffic_overnight_runs.tar.gz` holds the raw per-fight logs).
> **You own:** round 33's traffic paths (`game/ai/avoidance.gd`, `steering.gd`, `traffic*.gd`; in `movement.gd` the
> give-way block `right_of_way` through `_blocker` including `_negotiate`, ask, `_begin_yield`, plus `_avoid`,
> `_around_friends`, `_ask_behind`, `_hull_within`, and v3's `_room_home` / `_room_home_inside`; `tests/test_traffic*.gd`,
> `tests/traffic/**`, `tests/ai_scenarios/scenario_traffic*.gd`, `tests/test_avoidance.gd`, `mk/traffic.mk`,
> `tools/series_cache.sh`, `tools/quick_tests.sh`, `mk/infra.mk`, `tests/run_tests.gd`'s shard plan).
> **The C++ (C31.2):** the drive's ask and the execute path have native twins. parkedroom's hand-back is native's,
> rebased onto your pair. **Model: FABLE** (this problem has parked three times).

## The lead's direction

Round 28: **TAKE TURNS**: "fewer bumps; both squads arrive a little later." His standing rule: smart AI on both sides,
and symmetric AI improvements ship without asking him. He was told at round 32's close, as a known issue: **a crew stuck
behind a parked crew of ANOTHER squad nudges back and forth instead of getting by.** What he will notice when this ships:
that crew gets by, because the parked crew makes room and then goes back to its post. Fewer crews die stuck in a jam, on
both sides.

## Where things stand (main at the round-34 docs commit)

- **Shipped in round 33:** item 4, the fire mission (a set-up mortar truck counts as firing only with a target: idle
  fire-post loops 20 → 0, main `8684a97bb`), plus islands and the far census tools.
- **parkedroom v1, v2, v3 all PARKED (R33.12, R33.36, R33.37).** v3 (a hold-order crew returns to its hold point after
  making room) is on `round33/traffic-overnight`, DEFAULT_OFF. On fresh 820–867 × 3 (builder2, n 144) it PASSED
  L1a hold-post loops 59 → 18, L1b parked loops 224 → 63, L2 far loops 411 → 201, L4 and L5. It FAILED L3, kills
  2072 → 1992 (se 40.9) with the hit rate equal, and L6, 89.96 % home (line 90 %).
- **Your random-859 trace** (`9e3474e61`, builder0, n 1): give-ways from 13 s branch the fight, and the base's rout of
  Rust's artillery park (14 lost, caught driving or stuck) never happens with the fix. **The orchestrator's ruling (C34.2):
  fewer crews dying stuck is the fix working.** L3 is re-shaped, not dropped.
- **Native's hand-back for v3** sits on `pair/native-parkedroom` `5e5465af8` (`ae8d6e858`, `f16f49867`, `a7999c5c4`,
  `bcb0af2ba`, `6596e871c`) on an OLDER main. Native rebases it onto your v4 pair.
- **T4 PARKED on G2 (R33.30):** `pair/ghost-on-r34` `aacdfb4b6`; alone_s rises > 3 s on seeds 7, 8, 9, 14. Native's
  ghost-aware twins `pair/native-ghost-on` `b2b97188d` are unmerged.

## Backlog (in order)

1. **X1 The stuck-death census (REPORTED, dev fights only).** v3 ON v OFF on dev random fights (not 820–867, not any seed
   you will judge on), both arms, native, `far_census --far-kills=on`. Report deaths by cause: caught stuck or jammed, v in
   the open (define both in code before the run), kills by side, routs (a side losing ≥ N in a window). Does random-859
   generalise? Commit the table; send the orchestrator the hash and a three-line reading.
2. **X2 v4's design and bar, filed before any v4 number (C34.2).** v4 = v3 plus whatever the census and L6's 19 owed
   returns call for (L6's read time, or a way back that doesn't wait behind a still-driving asker). The bar: L1a/L1b/L2/L4/L5
   as v3's; **L3** = deaths in the open two-sided, stuck/jammed deaths ON ≤ base (one-sided), hit rate one-sided; **L6** read
   at a time named in the bar with its reason. FRESH fights from 868 up, × 3, native, ONE machine.
3. **X3 The v4 pair (C31.1, R33.32):** current main + v4 ON + native's rebased hand-back, nothing else. The full `make
   native check` goes green first, then the series, then the hand-over hash.
4. **X4 T4's trace (C34.3):** per-seed traces of 7, 8, 9 and 14 (ghost ON v OFF): which body route the Sirens' crews take
   and why the ghost changes it. Write it up. A fourth try is filed only if the traces name a fix; ask brains for an
   order-free body stage if the trace needs one.
5. **Stretch:** the engaged fire-post loops (a firing battery holds against its own column) are his T1c-b2 yes. Report the
   count on X1's fights; don't change it.

## How to verify

`make quick-remote` to iterate; `make native check` on the pair tree (switch ON) before any series, only for hashes you
name. `make traffic-far-census`, `far_ab.py --v3` (extend for v4), `traffic-series`, `traffic-census`,
`make traffic-t4-guard` / `traffic-t4-drive`. Long remote runs under `systemd-run --user`, launched FROM the pair's
worktree (round 33's slip: a script ran the stream worktree). Every number: commit, machine, workload, n.

## Don't touch

Manoeuvre's drive body, `_nose_stop`, `unstick`, the executor; brains' elements, `game/tactics/**`, `tank_brain.gd`;
planner's `game/ai/planner/**`; native's `native/**`; `game/match/**`; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

## ROUND 34 CLOSE-OUT (traffic, 2026-10-19 ~14:45 UTC; R34.20). Branch `stream/traffic` (final tip below); every number carries its commit, machine, workload, n.

**What merged, in player terms.** (1) **O4** (`o4-on-main` `6c44c0394`, INHERIT; `make native check` 2840/0 on builder2): a
shift-clicked route on a squad is the squad's route. The first leg starts at once as the squad's move, the squad flows through
in-between waypoints at about its own width without stopping to re-form (a wedge of five passes at ~21 m), and when several
squads share a route an in-between waypoint is a gate as wide as the ground there: abreast in the open, queued back along the
road where it narrows, single file over a bridge. The last waypoint packs as before. Before this, a shift route was each crew's
own queue: every vehicle aimed at every point (his "25 vehicles rolling through the same waypoint"). (2) **o4b** (`o4b-on-main`
`9d8535d8a`, 2856/0): the gate is laid for whichever squads have the waypoint queued, so one squad queued behind its crews'
orders no longer takes the gate away from the others. Planner's probe (O5) reads routes that used to time out now finishing
(Crossing 3 and 5, Locks 3 and 5, Terminus 5). Known follow-up, brains': an element whose first anchor O3 put inside a block
waits for an arrival that cannot come (planner's bisect to O4's queue change; before, the crews' direct orders bulldozed
through); brains grounds anchors and adds a stall fallback (offered a home in `Element.passed_waypoint`).

**What parked, and why (three rules that each worked and failed their totals).**
- **parkedroom v4 / v4b** (R34.9, R34.13): a crew parked on its hold post makes room for a squadmate of another squad and comes
  home. Hold-post far loops fell 50–74 % on three fresh blocks and 90–94 % of the crews came home; no harm to kills, deaths by
  cause, arrivals or the battery rule. It failed L1a by one loop (one cramped Locks fight, 868–915) and then L2's all-far-loops
  gain at n 144 (1100–1147; drop 42, se 55), because the far-loop total is dominated by crews looping behind a mortar truck that is
  SET UP AND FIRING, which his T1c-b2 yes keeps. **The question for him:** should a crew stuck behind a firing mortar truck get by
  too (the truck packs up for a moment, or the stuck crew is sent round)? The X1 census showed parkedroom changes neither how
  many die nor how; the jammed-deaths line rose 79 → 116 in v4b (within its guard) and is watched.
- **T4, the ghost** (R34.11, fourth try): on today's main it buys nothing. Round 33's body-stage cost is gone with main's drift
  (every seed 0.0), and on fresh Terminus seeds friend-stuck time rose 307 → 426 (not distinguishable; 34 of 48 cells identical):
  the gain it had in round 32 is spent by later rules. No fifth try without a new case.
- **T6 / T6b, a crew under fire holds its lane** (R34.15, R34.17, R34.20): built from the T5 census (337 of 5984 deaths were
  crews jammed by friendly traffic, 83 % of them GIVING WAY for a median 1.5 s, 77 % already under fire). The gain line passed by
  7 se both times (jam-under-fire deaths 231 → 72, then 256 → 121). T6 failed four guards (the mid-step abort tripled friendly
  contacts); T6b dropped the abort and fixed that, but stuck deaths rose 902 → 963 (7 %) against a line of 954: the rule moves the
  dying from stepping aside to stalling behind the refuser (far loops doubled on the Terminus and the gorge); total deaths flat.

**Round-35 design idea (for the orchestrator; not filed).** Refuse a give-way under fire ONLY when the asker has another way:
the room search's own test from parkedroom (a spot or a route off the lane). The free half of T6 (the asker can go round) keeps
its −53 % jam deaths; the costly half (a lane: the asker can only wait) gives way as today. It needs a design note first; the
tooling (`jam_census`, `jam_ab`, `far_kills`) and native's mirrors (`15b1523da`) are the right shape for it.

**Measurement notes for the record.** (a) `--arena=random` deals a map from the seed: 14 of 48 random seeds dealt the Locks or the
Terminus and were byte-identical twins of the fixed-arena fight of the same seed (true of X1, v4, v4b; paired readings
unaffected, totals double-count; planner's `seed_twins` now drops them; T5+ used fixed arenas). (b) A fresh builder folder's
`make import` segfaulted three times today, two of three on a first launch, once at the CSV reimport (before `references/.gdignore`)
and once AFTER the reimport finished (with it): intermittent; a relaunch cured it every time; a check with no `passed, failed`
line is not a result. (c) An OPT_IN behaviour named with EITHER flag is ON (trip-up 84). (d) A piped shell chain hides a merge
conflict and the next `git commit -a` commits the markers (trip-up 85; I did it twice). (e) The heavy lane's 90-minute cap
kills a 144-fight census at 3 jobs; split it (trip-up 86).

**Branches.** Merged: `o4-on-main`, `o4b-on-main`. NOT to merge: `stream/traffic` (parkedroom's and underfire's base, DEFAULT_OFF;
its own check is red by construction on the native-twin tests the pairs resolve), `pair/parkedroom-x1`, `pair/parkedroom-v4`,
`pair/ghost-on-r34b`, `pair/underfire-r34`, `pair/underfire-r34b`, `t5-on-main`, `o4-on-main`/`o4b-on-main` (merged), and
native's `pair/native-parkedroom-v4m`, `pair/native-ghost-r34`, `pair/native-underfire(-b)`. Measurement tooling that could go to
main on its own, if wanted (a check first): `far_kills.py` (+ test), `far_census.gd`'s death rows and `--room-read-s`,
`jam_census.gd` / `jam_table.py` / `jam_ab.py` (+ test) and `traffic-jam-census`, `t4_trace.gd/.py` and `traffic-t4-trace`,
`T4G_ON_FLAGS`. Scratch worktrees in the session scratchpad (removable; the branches hold the record); raw runs in
`~/overnight-traffic/r34/{x1,x3,x3b,x4,x4series,o4,o4b,o4trace,stream,t5,prlocks,x6,x6b}`.


**FINAL REPORT (2026-10-19 ~10:45 UTC; stream/traffic `3cfce4794`+; every number carries its commit, machine, workload, n).**

- **T6b JUDGED (14:36 UTC 2026-10-19): T6 PARKS for the round (R34.17: no third try).** G PASS by 7 se (jam-under-fire deaths
  256 -> 121); open deaths +45 (inside), kills flat, hit rate PASS, post-abort contacts 336 -> 167 PASS, far loops 96 -> 192 PASS
  by 0.1, crossings identical; **stuck deaths 902 -> 963 (+61, se 31.7, line 954) FAIL**; all deaths 5768 -> 5735 (flat). The
  rule moves the dying from stepping aside to stalling behind the refuser (far loops doubled); it does not remove it.
  `x6_underfire_bar.md` "T6b result"; raw `x6b_series_104ca5a11.txt`. `underfire` stays DEFAULT_OFF; `pair/underfire-r34b` and
  native's `pair/native-underfire-b` are NOT to merge.

- **T6b (R34.17) BUILT, bar amended, waiting on native's pair (2026-10-19 ~13:40 UTC):** (a)+(b) only, the mid-step abort gone
  (`adff1bbdf`; test_traffic_underfire 6/6 + test_movement, 15/0 laptop); native's mirror re-cut (`stream/native` `15b1523da`).
  Bar: `x6_underfire_bar.md` "T6b", fresh fixed-arena block 1500-1527, the same lines and guards; if open or stuck deaths still
  rise, T6 parks for the round. **Pair `pair/underfire-r34b` `104ca5a11`** = native's `pair/native-underfire-b` `a11fa6232` (their mirror
  `15b1523da` + my T6 and T6b commits on main) + the census tooling + the ON flip; switch-OFF sim-baseline 13 unmoved (inert);
  perf-judge JUDGED PASS 1.00x alone on builder0 (ai_usec_per_tick 7139); its first `native check` died at import with the
  intermittent fresh-folder segfault (after the reimport finished; the pair has references/.gdignore), relaunched unchanged on
  builder2: exited 2 with 2863/0 and sim-baseline the only red (11 of 13 MOVED = the ON arm's own). **Named green for the series,
  which started on builder2** (`traffic-x6b.sh`; `~/overnight-traffic/r34/x6b/`). `x6b_c311_104ca5a11.txt`. Note: native's
  pair sits on an older main snapshot (main is ahead); a hand-over, if any, is re-cut on current main with one fresh check.

- **T6 JUDGED (13:05 UTC 2026-10-19): FAIL as filed.** G PASS by 7 se (jam-under-fire deaths 231 -> 72), but deaths in the open
  4674 -> 4843 (+169, se 75), stuck deaths 812 -> 936 (+124, se 39), kills 5717 -> 5855 (+138, se 68) and contacts in the 3 s
  after a hit-ended give-way 331 -> 1049 (+718, se 98) all FAIL; far loops, hit rate, crossings PASS; standoffs 1 v 2 (the named
  risk did not arise); all deaths +135 (+2.3 %, 2 se). The deaths moved from "stepping aside" to "holding where it stands";
  the mid-step abort (c) triples the contacts after it. `x6_underfire_bar.md` Result; raw `x6_series_ac1bf4692.txt`. A second
  attempt without (c) is the orchestrator's call; nothing ships; underfire stays DEFAULT_OFF.

- **parkedroom v4 on planner's Locks 3-squad route cell (REPORT, n 1, the orchestrator's ask):** v4 ON does not get squad 1
  through (28.9 m short at 90 s v 29.3 OFF; squads 2 and 3 arrive in both arms, squad 3 25.8 -> 19.1 s). The probe prints no
  parkedroom counters, so ask-never-made v no-room-on-the-quay is undecided. `references/round34/traffic/x3_v4_locks_route_cell.txt`.

- **T6 (R34.15) BUILT, bar FILED, waiting on native's twins (2026-10-19 ~13:00 UTC):** a crew under fire holds its lane
  (`95d160ce1`, `--traffic-on=underfire`, DEFAULT_OFF): `Movement.under_fire()` = hit within 5 s; `ask()` refuses, the asker's own
  step aside is held, a give-way ends the tick a hit lands. `test_traffic_underfire` 6/6 (+ test_movement, test_traffic_setup:
  23/0 laptop). Bar `references/round34/traffic/x6_underfire_bar.md` (G jam-under-fire deaths the gain; guards open/stuck
  deaths, far loops, kills/hit rate, post-abort contacts, crossings; standoffs reported; fixed arenas x 1300-1327, no twins).
  Tooling `3df42fc4f` (jam_census STANDOFF/ABORT rows, jam_ab.py + test); driver `traffic-x6.sh` (scratchpad, START file). Pair
  **`pair/underfire-r34` `ac1bf4692`** = native's main-based `pair/native-underfire` `3c6090101` (my T6 commit cherry-picked onto
  main, no parkedroom, + their twin `979c3fa5b`) + my census tooling + the ON flip; its `native check` (builder2) exited 2 with
  2863/0 and sim-baseline the only red, 11 of 13 maps MOVED = the ON arm's own (the switch-OFF run read main's 13 hashes);
  perf-judge REFUSED by load x3 in the check, then **JUDGED PASS 1.07x alone on a quiet builder0** (ai_usec_per_tick 7799
  pinned to the P-cores; the orchestrator's ship condition). `references/round34/traffic/x6_c311_ac1bf4692.txt`. **Named green for the series,
  which started on builder2** (`traffic-x6.sh`; results `~/overnight-traffic/r34/x6/`).
- **O4 follow-ups:** (2) a 5-squad route with no gate: fixed `0afc740c5` (the gate is laid for the squads that have the waypoint
  queued; 10/10). (1) the Terminus-3 squad-3 stall: identical with the gate re-lay disabled (gates 0), so not the gate; planner's bisect
  then put it on O4's queue change `a5a362737` in effect: before O4 a shifted MOVE on a squad fell to crews' direct orders that
  bulldozed through an anchor O3 had placed inside a block; now the legs queue behind an element arrival that cannot come.
  Brains grounds anchors (the cause) and adds a stall fallback; offered to carry it in `passed_waypoint` (centre moved < ~2 m in
  ~8 s on an in-between waypoint = passed), brains' call. Trace `references/round34/traffic/o4_terminus3_route_trace.log`.
  **o4b hand-over tree `o4b-on-main` `9d8535d8a`** = main `929c0f688` + `0afc740c5`: GREEN, builder2 `make native check exited 0`,
  2856/0, sim-baseline 13/13 unmoved; named to the orchestrator (INHERIT).

- **T5 DONE (REPORTED, 2026-10-19 ~12:20 UTC):** `references/round34/traffic/t5_jam_death_census.md` (+ `t5_jam_table.txt`).
  `t5-on-main` `fda16c670`, builder2, fresh 1200-1247 x 3, 144 fights, 5984 deaths. Jammed by friendly traffic 337 (5.6 %, 2.34
  a fight): 83 % giving way, 69 % held by another squad's crew, 1 % by a set-up battery, 74 % in lanes, 77 % under fire, median
  jam 1.5 s (6 % over 5 s). Largest episodes 7/5/5 deaths, all Locks lanes, two or three squads of one side through one lane
  under fire, rear crews yielding to the front. Nothing proposed. Note: 14 of 48 "random" seeds dealt the Locks/Terminus (twins
  of the fixed-arena fights; true of X1/v4/v4b too).
- **T5 (R34.13, measurement on MAIN, RAN 2026-10-19 ~11:30 UTC):** crews that die jammed by friendly traffic.
  `tests/traffic/jam_census.gd` + `jam_table.py` + `make traffic-jam-census` (stream/traffic `dffc84ca8`, `+1` main-compat fix),
  on `t5-on-main` `fda16c670` = main `7afbf120e` + those files; builder2, light lane, `native traffic-jam-census`, fresh
  1200-1247 x {terminus, locks, random} (n 144), pinned; results `~/overnight-traffic/r34/t5/`. The reader gives deaths by
  cause, jam deaths by doing x holder (own squad / other squad / unseated; set-up battery named) x where (dense / lanes / open /
  base), the under-fire share (last hit during the jam, or >= 2 hits in the 10 s before), jam time before death, and the three
  largest episodes (one team, within 20 s and 40 m). Table and three lines of reading follow; nothing proposed before them.

**Done, in player terms.** (1) A shift-clicked route on a squad is now the squad's route (O4): the first leg starts at once as
the squad's move, in-between waypoints are passed at about the squad's width with no stop to form up, several squads take an
in-between waypoint as a gate as wide as the ground (abreast in the open, queued back where it narrows, single file over a
bridge), the last waypoint packs as before. **Hand-over: `o4-on-main` `6c44c0394`** (main `35bc2dd12` + five commits; builder2
`make native check exited 0`, 2840/0, sim-baseline 13/13 unmoved). (2) The parked crew making room (parkedroom v4) does what it
was built for and PARKS for the round (R34.9): hold-post far loops −74 % and 93 % of the crews back home on fresh fights, no
harm to kills, deaths by cause, arrivals or the battery rule, but the far-loop TOTAL it was judged on is dominated by crews
looping behind FIRING batteries (his T1c-b2 yes) and did not clear its noise. (3) T4 (the ghost) PARKS a fourth time (R34.11):
on today's main it no longer buys anything on Terminus (friend-stuck 307 → 426, not distinguishable; 34 of 48 cells identical)
and the body-route cost that parked it in round 33 is gone with main's drift. (4) The stuck-death census (X1): the rule changes
neither how many crews die nor how (every line within 1 se); random-859 was one fight's draw.

**Numbers (headline; every file under `references/round34/traffic/`).**
- X1 (`x1_stuck_death_census.md`; pair `4450a92a9`, builder0, random 600-647, n 48): stuck/jammed deaths 428 → 443 (se 22),
  open 1668 → 1634 (se 43), kills 2065 → 2051 (se 35), routs 161 → 163.
- v4 (`x2_parkedroom_v4_bar.md` Result; pair `5914d3ac5`, builder2, fresh 868-915 × 3, n 144): FAIL L1a by one loop (34 → 18, line
  17; one locks-913 episode of 16 with no room spot); L1b 92 → 47, L2 124 → 60, L3 by cause within bands, L4 identical, L5 0/9,
  L6 94.2 % at 45 s.
- v4b (same doc, "v4b result"; same pair, builder0, fresh 1100-1147 × 3, n 144): FAIL L2 (169 → 127, se 55); L1a 82 → 21 (se 23),
  L1b 136 → 102, L3 within bands (jammed deaths 79 → 116 named), L4, L5, L6 93.3 % PASS; engaged fire-post loops 44 → 67.
- T4 (`x4_t4_trace.md`, `x4_t4_fourth_bar.md` Result; pair `777820d7b`, builder2, fresh 920-931 / 940-987 / 1000-1023): T(1)
  307 → 426 (se 210) FAIL; T(2)-T(4), T(6), G1-G3, r1 PASS (G lines carry no information: body-ON alone_s 3.0 v 3.0 everywhere).
- O4 (`o4_waypoints_tests.txt`, `o4_c311_6c44c0394.txt`): laptop GDScript 9/9 on `test_control_waypoints`; a wedge of five passes
  its middle waypoint at 20.9 m (pass_m 21.6), never arrives on that leg, centre ≥ 4.34 m/s; pre-O4 the same route test fails
  at "an element carries it".

**Decisions taken (one line each).** X1 ran on builder0 (rule 5). L3 became a guard by cause (X1 said no effect). L6 read at
45 s (the rule's own clocks). v4's gate = ONE definition `Movement.at_post()` (hold crew inside its hold line counts). T4's
fourth-try seeds above 915; identical arms read NOT ARISEN. O4's pass radius clamp(frontage/2, 12, 30); gate centred in the
clear width; only QUEUED waypoints re-laid; a shifted MOVE on a squad is the squad's route (granted). The stream branch is
parkedroom's base and does not merge by itself (its own check `740f3c6d6`: 2804/6, the six are native-twin reds the pairs
resolve); hand-over trees are the pairs and `o4-on-main`.

**Questions for the lead (through the orchestrator, in his terms).** Should a crew stuck behind a mortar truck that is SET UP
AND FIRING get by too (the truck packs up for a moment, or the stuck crew is sent round)? Today his earlier yes keeps the
truck firing, and that is now most of what is left in a jam (67 of the 127 loops on 1100-1147). A new parkedroom design needs
that answer first.

**Requests to other streams.** Native: nothing open (the v4 hand-back `4445f6b4c` and the ghost twins `3a45b58b4` are parked
with their rules; they return only with a future try). Brains: merge note for `element.gd` (`passed_waypoint`, `relay_queued`,
one clause in `_next_queued`); if a through-waypoint shows a re-seat shuffle in play, brains reviews a "through" flag (theirs).
Planner: after O4 merges, an O5 route arm reading `RtsControls.gates_laid` / `route_starts` on the 3-waypoint routes
(the orchestrator relays). Control (no stream): merge notes for `test_control_queued_task.gd` line 110 and
`test_control_squad_formation.gd` lines 108-110 (both granted).

**Known issues.** Jammed deaths rose 79 → 116 with parkedroom ON (within the combined guard; crews driving among friends when
hit): for any future try. A hold-order crew with no room spot (cramped ground, wheels) refuses as OFF does; the asker loops.
`_relay_previous_waypoint` centres the gate on the previous anchors' mean, not the exact click (tasks carry no `waypoint` key:
`ElementTask.KEYS` is brains'). The pre-O4 fixture's camera does not see clicks far from the origin; the route test issues
orders through `order_selection` instead. builder0's heavy lane kills a 144-fight census at 3 jobs (trip-up 86).

**What to playtest (him).** `make skirmish`, select a squad, shift-click three waypoints with a corner: the squad should flow
through the middle one without bunching up to re-form; select three squads and shift a route over the Locks bridge: they should
file over it rather than fan out across the water. Nothing of parkedroom or the ghost is on by default.

**Merge notes.** `o4-on-main` `6c44c0394` (INHERIT from main `35bc2dd12`): `game/control/rts_controls.gd` (gate helpers, re-lay,
the shifted-move entry, `_start_route`), `game/tactics/element.gd` (brains' file: the agreed methods + clause),
`tests/test_control_waypoints.gd` + uid, `tests/test_control_queued_task.gd` l.110, `tests/test_control_squad_formation.gd`
ll.108-110. Do NOT merge `stream/traffic`, `pair/parkedroom-x1`, `pair/parkedroom-v4`, `pair/ghost-on-r34b`, or native's
`pair/native-parkedroom-v4m` / `pair/native-ghost-r34`. Measurement tooling that could go to main alone if wanted: `far_kills.py`
(+ test), `far_census.gd`'s death rows and `--room-read-s`, `t4_trace.gd/.py`, `traffic-t4-trace`, `T4G_ON_FLAGS`, the
`DEFAULT_OFF` fix is only meaningful with parkedroom. Scratch worktrees in the session scratchpad: `pair-parkedroom-x1`,
`pair-parkedroom-v4`, `pair-ghost-on-r34b`, `o4-on-main`, `pre-o4` (branches kept; folders removable). Raw runs outside the
repo: `~/overnight-traffic/r34/{x1,x3,x3b,x4,x4series,o4,stream}`.

**Next steps (if the round continues).** None owed. Candidates: a parkedroom design that answers the firing-battery question;
O5's route arm; a `waypoint` key in `ElementTask.KEYS` so the gate centres on the exact click.

**REPORT (2026-10-19 ~06:00 UTC; stream/traffic, laptop + builder0 as named):**
- **O4 GREEN, hand-over named (2026-10-19 ~10:55 UTC): `o4-on-main` `6c44c0394`** = main `35bc2dd12` + O4's five commits
  (also on stream/traffic `854c5dda4`): builder2 `make native check exited 0`, 2840/0, sim-baseline 13/13 unmoved
  (`references/round34/traffic/o4_c311_6c44c0394.txt`). The second granted test change: `test_control_squad_formation` lines
  108-110 assert the squad's element move carrying the pick (merge note for control). Next, after the merge: planner's O5 route
  arm reading `gates_laid` / `route_starts` (the orchestrator relays).
- **O4 DONE on the branch, named check RUNNING (2026-10-19 ~10:30 UTC):** the shifted-move entry granted and built (`346289963`:
  a shifted MOVE on a squad starts the element's move at once, later moves queue, loose units keep the direct queue); the
  granted line-110 change in `test_control_queued_task.gd` (`030b1ea3c`, merge note for control). Laptop GDScript:
  `test_control_waypoints` 9/9 (route: passes wp2 at 20.9 m, pass_m 21.6, never arrived on the leg, centre >= 4.34 m/s, the
  last arrives), `test_control_commands` green, the queued-task file green after line 110. **Fails today, recorded:** the same
  route test on the pre-O4 tree fails at "a shifted route on a squad is the squad's: an element carries it"
  (`references/round34/traffic/o4_waypoints_tests.txt`). **Hand-over tree `o4-on-main`** = main `35bc2dd12` + the four O4 commits
  (cherry-picked, 5 files: rts_controls.gd, element.gd, the two tests, a uid); its `native check` runs on builder2 now
  (`~/overnight-traffic/r34/o4/`). Measurement counters: `RtsControls.gates_laid`, `route_starts`. Not done: O5's probe (orders'
  item; his eye) and a screenshot of a gate: the orchestrator decides who.
- **O4 BUILT (design agreed by the orchestrator and brains), one entry gap found, waiting on a grant (2026-10-19 ~09:30 UTC):**
  `1c700c51b` (+ main `d13064b6f` merged at the checkpoint, `715f0c913`): `RtsControls.gate_width` / `gate_anchors` (pure) and
  `_relay_previous_waypoint` (a further shift-waypoint re-lays the previous QUEUED one as a gate); `Element.passed_waypoint`
  (the living centre within max(12, frontage/2) <= 30 m; pass_m 21.6 m for a wedge of 5) and `relay_queued` (state + revision
  bumped, bounds refused), the clause in `_next_queued`; `tests/test_control_waypoints.gd` 6/8 green on the laptop
  (GDScript): the four gate tests incl. a searched Locks lock-gate deck (clear 2 + 2 m: single file), relay_queued, passed_waypoint.
  **The route test fails at "the shifted route formed an element": a plain shift route is each crew's OWN direct queue
  today** (order_selection ~1016 and _order_squads ~1140 send a shifted MOVE to the element queue only when a task is already
  queued; round 28 B5), so no element exists for the pass rule. Proposed to the orchestrator: a shifted MOVE on a squad starts
  its element move at once, later shifted moves queue behind it; needs a grant beyond `_queue_task_for`. Not a lead gate.
- **O4 (R34.8 extended to traffic, 2026-10-19 ~08:30 UTC): the waypoint design SENT to the orchestrator, no code yet.** (a)
  "passed" decided in `Element._next_queued` for a move with a queue behind it: the element's centre within pass_m =
  clamp(frontage/2, 12, 30) of the task's point, no arrived wait; the last waypoint keeps today's rule. (b) when a further
  shift-waypoint is queued, the previous (queued, not running) waypoint's per-squad anchors are re-laid as a GATE: width read
  on the navmesh with O1's drive_on/crosses_on along the across line from the click; k abreast, the rest in ranks back along the
  approach, single file on the click where narrower than a squad. (c) seam: two small Element methods for brains to agree,
  `passed_waypoint(game_match)` and `relay_queued(i, to)`; no signature change. (d) `tests/test_control_waypoints.gd`: a
  3-waypoint route passes waypoint 2 without a stop (speed >= 2 m/s, never arrived); three squads through the Locks bridge
  get single-file anchors; a pure `_gate_anchors` corridor test. Waiting on agreement (not a lead gate; the orchestrator asked
  for design first).
- **X1 DONE (REPORTED): random-859 does NOT generalise.** `references/round34/traffic/x1_stuck_death_census.md` (+ `x1_far_kills.txt`,
  `x1_far_tables.txt`, `x1_far_ab_dev.txt`). Pair `pair/parkedroom-x1` `4450a92a9` (= `1a4aa7317` v3 + census definitions +
  native's hand-back `6992bcf5a`), builder0, `native traffic-far-census`, random 600-647, both arms, n 48 paired, 180 s, pinned,
  hand-back live (ask_handed_back 2-18 a fight). Deaths stuck or jammed 428 -> 443 (se 22.3), in the open 1668 -> 1634 (se 43),
  kills 2065 -> 2051 (se 35), rout windows 161 -> 163: the rule changes neither how many die nor how. v4's L3 is a guard by cause.
  Caveat: the overnight merge had `firemission` in DEFAULT_OFF, so item 4 was OFF in both arms (paired reading stands; fixed `e6468b2e0`).
  Dev read of parkedroom's own lines on the same fights: L1a 20 -> 2, L1b 63 -> 27, L2 70 -> 29, v3's L6 at 30 s 88 %.
  Stretch: engaged fire-post loops base 21, arm 23 (n 48; REPORTED, nothing changed).
- **X2 FILED:** `references/round34/traffic/x2_parkedroom_v4_bar.md` (design + bar, before any v4 number). v4 = v3 + ONE gate change
  (`1b2fd26f1`): `Movement.at_post()` = not under way AND (still >= 2 s OR a HOLD crew inside its hold line); native's hand-back calls
  `at_post_of` (native `6231e7222`, green on builder2 twins 33/0). Reason: 22 of v3's 45 L6 misses were crews just home, asked
  again within 2 s, given the ordinary give-way. L3 = deaths in the open two-sided, stuck/jammed one-sided, hit rate one-sided
  (sized from X1); L6 read at 45 s (the rule's clocks: room <= 20 s + way back <= 20 s; 19 of v3's 45 misses were inside them at
  30 s); FRESH 868-915 x 3 on builder2. test_traffic_neck 13/0 (laptop GDScript, `1b2fd26f1`).
- **The stream branch's own check (`740f3c6d6`, builder2 `make native check`): exited 2, 2804/6, sim-baseline 13/13 unmoved.**
  The six: `test_native_exec_state::test_the_table_is_the_scripts_members` (main's exec_fields.h lacks v2's seven Movement
  members: native's commit, carried by the pairs) and five `test_traffic_neck` ON tests that drive through native without the
  hand-back (the native-ask bypass, R33.33): all six are green on the pair `5914d3ac5` (2824/0). relay-smoke: NET_CHECK FAIL
  one client saw 4/5 tanks (a network-smoke flake under load, not traffic's). **As in round 33, `stream/traffic` is parkedroom's
  base and does NOT merge by itself; the hand-over trees are the pairs, each with its own named check.**
- **X4 T4 PARKED a fourth time (08:24 UTC 2026-10-19), on T(1):** mixed friend-stuck crew-s 307 -> 426 (+119, se 210.5), 34 of 48
  cells byte-identical; T(2)-T(4), T(6), G1-G3, r1 all PASS (the G lines with every body-ON difference 0.0: no information).
  `x4_t4_fourth_bar.md` Result; raw `x4_t4_fourth_series_777820d7b.txt`. The ghost's round-32 gain is gone with main's drift;
  no fifth try without a new case; `pair/ghost-on-r34b` is NOT to merge.
- **X4 T4 SERIES RAN on builder2 (started 08:03 UTC 2026-10-19) on `pair/ghost-on-r34b` `777820d7b`, named green for line 7:**
  C31.1 `make native check` exited 2, 2826/0, the only red sim-baseline with all 13 maps MOVED (the ghost ON's own: the same tree
  with `--traffic-off=ghost` reads main's 13 hashes, so the carried v4 code is inert); perf-judge PASS 1.32x (loaded box).
  `references/round34/traffic/x4_c311_777820d7b.txt`. Order: G/r1 (920-931), T drive (940-987), T(6) fights (1000-1023), T(5)
  series (41-43); results `~/overnight-traffic/r34/x4series/`.
- **X4 T4 PAIR CUT, C31.1 QUEUED on builder2:** `pair/ghost-on-r34b` `777820d7b` = main `ba04f19a9` + stream/traffic `fc109516c`
  + native's ghost twins `pair/native-ghost-r34` `3a45b58b4` + the OPT_IN flip (ghost ON; OFF arm `--traffic-off=ghost`). The
  tree's extra contents are named in `x4_t4_fourth_bar.md`. Its `native check` runs on builder2 after the stream branch's own
  check (`740f3c6d6`); the series driver `traffic-x4.sh` (session scratchpad) starts on a START file once the check is read;
  results `~/overnight-traffic/r34/x4series/`.
- **X3 v4b JUDGED (10:28 UTC 2026-10-19): FAIL on L2, the deciding gain (all far loops 169 -> 127, drop 42, se 54.9: not
  distinguishable); every guard PASS (L1a hold-post loops 82 -> 21, L1b 136 -> 102, L3 by cause within bands with jammed
  deaths 79 -> 116 named, L4 identical, L5 0/9, L6 93.3 %).** Per R34.9 (4) **parkedroom PARKS for round 34**; no fifth try
  without a new design. Traced: the arm's remaining loops are 67 behind FIRING batteries (his T1c-b2 yes, untouched by design;
  44 -> 67, branched fights) and one no-room hold-post episode of 16. `x2_parkedroom_v4_bar.md` "v4b result"; raw
  `x3_v4b_series_5914d3ac5.txt`, `x3_v4b_far_tables.txt`. The base census hit the heavy lane's 90-min cap at 3 jobs and was
  completed in parts (pinned child processes: one series).
- **X3 v4b RAN on builder0 (R34.9; restarted 07:27 UTC 2026-10-19 at FAR_JOBS=3 per the orchestrator's memory caution):** v4 PARKED as filed (R34.9); the SAME code `5914d3ac5`
  re-judged on fresh 1100-1147 x 3 with the gain on L2, L1a/L1b guards, L3-L6 as filed (bar: `x2_parkedroom_v4_bar.md` "v4b").
  Driver `traffic-x3b.sh` (session scratchpad), results `~/overnight-traffic/r34/x3b/`. A fail parks parkedroom for the round.
- **X3 JUDGED (07:21 UTC 2026-10-19): FAIL on L1a by one loop (hold-post far loops 34 -> 18, line 17; se 20.2), every other
  line PASS (L1b 92 -> 47, L2 124 -> 60, L3 by cause within bands, L4 identical, L5 0/9, L6 94.2 % at 45 s, n 451).** v4 does
  not ship as filed; parkedroom stays DEFAULT_OFF; the orchestrator rules. Traced: 16 of the 18 are one locks-913 episode (a
  wheeled battery on its hold post with no room spot anywhere, asked 16 times by its squadmate; refuses as OFF does). R: +19
  give-ways a fight (median 133 -> 152), 27 rooms a fight. `x2_parkedroom_v4_bar.md` Result; raw `x3_v4_series_5914d3ac5.txt`.
  (Earlier:) SERIES RUNNING on builder2 (started 06:36 UTC 2026-10-19) on `pair/parkedroom-v4` `5914d3ac5`, named green:** C31.1
  `make native check` exited 2, 2824/0, 24/26 targets, perf-judge PASS 1.05x (7077 usec a tick pinned). Two reds, both
  attributed (`references/round34/traffic/x3_c311_5914d3ac5.txt`): sim-baseline terminus/sumps/parade/docks MOVED = parkedroom
  ON's own (same tree with --traffic-off=parkedroom: 12 unmoved, docks = B1's 4074d105e1739377); native-verify-scenarios'
  scenario_perf red was load (alone on builder2 PASS 17435 usec at 1.41x; in the check 29238 at 1.50x; main's own last check
  there read 22407 at 1.51x, refused). Pre-series trace PASS (random-618 ON, L6 at 45 s: 103 rooms, 72 ways back,
  ask_handed_back 102, 13 of 18 unchanged-order crews home at 45 s, no script error). Driver `traffic-x3.sh` (session
  scratchpad): far census 868-915 x 3 both arms (--far-kills=on --room-read-s=45), far_ab --v3, far_kills --arena random +
  pooled, item4_lines, then L4 (traffic-series 44-46) and L5 (traffic-census); results `~/overnight-traffic/r34/x3/`.
  (Earlier:) PAIR CUT, C31.1 RUNNING on builder2: `pair/parkedroom-v4` `5914d3ac5` = main `8a577fbad` + stream/traffic `82c95fe53`
  + native's `pair/native-parkedroom-v4m` `fc2c1e816` (hand-back on current main, incl. N5 `17876e4b6` test-only and the
  parkedroom stage's floors: named here per R33.32) + one commit flipping DEFAULT_OFF to [] (parkedroom ON). Diff v main:
  traffic's paths, native/src (3 files), tests/native + test_native_yield, references. `make native check` on builder2
  (`~/overnight-traffic/r34/x3/check-5914d3ac5.log`); the pre-series trace (random-618 ON, L6 at 45 s) on its light lane;
  the series driver (`traffic-x3.sh`, session scratchpad) starts on a START file once the check is green. builder0 went
  unreachable ~22:55 PDT: my X1 and guard runs finished and copied back (verified) before it; nothing of mine runs there.
  (Earlier:) WAITING ON NATIVE: the pair cut on current main `16db9e19b` (`pair/parkedroom-v4` `301b66409` = main + stream/traffic)
  conflicts with `pair/native-parkedroom-v4` in `tests/test_native_yield.gd` (main's N5 batch moved the Sumps stage); asked
  native for the hand-back on current main. Then: DEFAULT_OFF flip commit, C31.1 `native check` on builder2, the series.
- **X4 TRACED, guard re-read PASS on current main (dev):** `references/round34/traffic/x4_t4_trace.md`. 12-seed guard
  (`2c63dca44`, builder0, native, pinned, seeds 7-18): G1 3.0 v 3.0, G2 0 of 12 (every ON-OFF difference 0.0), G3 7/12 both,
  r1 36/36. R33.30's G2 failure does not exist on today's main (body-ON alone_s 2-6 s everywhere; it read 6.5-57.5). No fix in
  the ghost's code; a fourth try needs a fresh bar (proposed to the orchestrator, after the v4 series). Earlier note:
- **X4 TRACED (so far):** `references/round34/traffic/x4_t4_trace_reading.txt` (`c5fa4bdfe`, builder0 light, native, seeds 7/8/9/14,
  60 s, pinned, a child a run). **On current main the ghost no longer changes alone_s on any of the four seeds** (2.0-3.0 s in both
  arms; R33.30 read 13.0/19.5, 10.5/14.5, 13.5/17.0, 6.5/10.5), and the Sirens' route choice is the same in both arms; the arms
  part 1-7 s in when crews jostle at the start (asked-real velocity gaps up to 11 m/s) and Sirens' arrival moves -3.0/-4.6/-0.8/+1.8 s.
  The 12-seed guard re-read on current main (dev, same tuning seeds) is CHAINED on builder0 after X1. First run of the trace read two
  identical arms: an OPT_IN behaviour named with --traffic-off is ON (`c5fa4bdfe` fixes the target; `2c63dca44` the guard's knob).
- Branch: `e6468b2e0`. Not yet checked (quick-remote / check queued behind the X3 pair).


**2026-10-18 (Fable; worktree `godot-traffic`, branch `stream/traffic` from the docs commit `918ede503`). Plan, in order:**
1. **X1 the stuck-death census (RUNNING).** Tree: v3 merged from `round33/traffic-overnight` (`5eac365bf`, DEFAULT_OFF) +
   the census's definitions (`1a4aa7317`: far_census's FAR_KILL rows carry the tick-before drive state and a `cause`;
   `tests/traffic/far_kills.py` groups them, `test_far_kills.py` 3/3 laptop). The run needs native's hand-back, so it runs
   on a scratch pair `pair/parkedroom-x1` `4450a92a9` = `1a4aa7317` + `pair/native-parkedroom-r34` `6992bcf5a` (native's
   six hand-back commits rebased on the docs commit; game code otherwise = main). builder0, `native traffic-far-census`,
   dev random fights 600-647 (never judged; not 820-867, not 868+), both arms, n 48 paired, 180 s, --fixed-fps 30.
   Script `traffic-x1.sh` (session scratchpad), results in `~/overnight-traffic/r34/x1/`. Smoke (builder0 light, s600,
   20 s, GDScript path): rows print, no script error, 1 room + 1 way back.
   **Definitions (in code before the run; `far_census.gd death_cause`, `far_kills.py`):** *stuck or jammed* = the crew was
   under way the tick before it died and (jam) giving way or blocked by a friendly hull, or (stuck) blocked with no path
   or by a static, wedged, or still >= 2 s; *in the open* = driving and moving, blocked by an ENEMY hull (a contact),
   or not under way (parked, arrived, holding). *Rout* = one side losing >= 6 crews inside 30 s (greedy windows).
2. **X2 v4's design and bar**, from X1 and from v3's L6 misses (re-read from the archived judged logs, below). Filed with
   the orchestrator before any v4 number.
3. **X3 the v4 pair** on current main + native's hand-back; `make native check` first; FRESH fights from 868 up.
4. **X4 T4's traces** (seeds 7, 8, 9, 14).
5. Stretch: engaged fire-post loops counted on X1's fights.
Decision: X1 on builder0 (gcp_builder rule 5: dev runs there; builder2 is RUNNING, kept for the judged series).
