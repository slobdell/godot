> **ARCHIVED (round 35 closed 2026-10-20).** The branch is `round35/manoeuvre`; its unmerged references (`references/round35/` or `_agents/streams/references/round35/`) stay on that branch. Round 36's brief is `streams/manoeuvre.md` where one exists.

# Stream: manoeuvre (fewer crews die shoved around in a lane mouth; a wheeled hull told to face a way faces it and goes still)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md` (M1's A/A rows), `_agents/workstreams.md` **Round 35**
> (C35.1, C35.3, C35.6, C35.7; R34.10, R34.18 in *Round 34*), and your round-34 brief `streams/archive/round34/manoeuvre.md`
> (its Status is the close-out: M0, M1, M2, CP-F 4, the wedged-death table). Evidence: `references/round34/manoeuvre/`
> (cpf4-series, wedged-deaths, m2-report), traffic's T5 census `references/round34/traffic/t5_jam_death_census.md`.
> **You own:** round 34's carve-outs: the `drive()` body, `_nose_stop`, `unstick`, `_pressing_escape`, the k-turn executor, H1/H1b,
> the face-at-rest path in `order_controller.gd`, the `_order_move` decline for wheeled turret hulls, `game/ai/manoeuvre*.gd`,
> `tests/manoeuvre/**`, `tests/test_manoeuvre*.gd`, `mk/manoeuvre.mk`, additive fields in `game/control/screen_playtest.gd`.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Smart AI on both sides; symmetric improvements ship without asking. His answer at round 34's close: **"Ship it"**: the scout
turn-in (M0) ships (the orchestrator merges `pair/c339-r34b` `3902ade09` on its green check, C35.3). His standing CP-F ask: a War
Rig or other wheeled turret vehicle told to face a direction ends facing it and sits still.

What he will notice: fewer crews dying while being shoved around in a lane mouth; a wheeled hull told to face a way turns to it
and goes still, without the squad hanging at each leg.

## Where things stand

- **Shipped in round 34:** M1 the ruler (real_mps, wedged apart, A/A), M2 the arrival hold (ARRIVE_LEG_DEFAULT on), the M0 turn-in
  (merging under C35.3).
- **Wedged deaths (C35.6):** 499 of 5984 (8.3 %, 3.5 a fight) in T5's census, all `driving`, none held; mid-weight hulls (suppressor,
  burner, IFV, tank, lancer 13–16 % of their own deaths); lanes, the Locks lane mouths worst; median speed at death 1.2 m/s, 85 %
  under fire, only 26 % below STUCK_SPEED, so the stall rule never sees most of them.
- **CP-F (R34.18):** the turn is right (3–4° v ~50°); it failed on settling: faces no plan fits creep at the 0.35 lock until the
  judge, and attack-move elements step ~30 s later when arrived crews sit on a sector face (brains' side).

## Backlog (in order)

1. **W1 Wedged deaths: trace first.** On main, fresh seeds on the Locks/Terminus lanes: for the three largest episodes, which force
   moves the hull (ORCA, avoid, around_friends, the drive's own steer), what `Movement.wedged` and unstick saw, and what the crew was
   ordered to do. Then a design note to the orchestrator (a wedged trigger that acts on walking-pace shoving; what a crew under
   fire should do instead: back off, hold, or push through). Then a bar before any number: deciding gain wedged deaths; guards open,
   stuck, jam deaths, far loops, kills, hit rate (as T6b's). Native mirrors anything in the drive.
2. **W2 CP-F attempt 5, the face side (C35.7).** A face that gives up cleanly after N refused plans (no creep at the 0.35 lock).
   The seam with brains' element step is agreed through the orchestrator before code. A fresh bar with guards from M1's A/A.
3. **Stretch:** the watch item from R34.16 (one 9.1 m both-planned face) if a face_pairs series runs.

4. **Round 35 extension X1 (workstreams.md *Round 35 extension*, 2026-10-20, the lead away for the day):**
   (a) finish the joint W1c + T9 ship (R35.66, in flight). (b) W1b's deciding probe: a FIGHT_CENSUS line per impact with the
   target's held / pace-0 state and exposure ticks, then a small A/B (locks x 24 fresh seeds, both arms, builder0) that says whether a
   still held hull is a sitting duck; W1b re-tries only if not. Bar filed before numbers. (c) R34.16's watch item from a face_pairs
   read on main (M5 in).
   (d) (orchestrator relay of brains' X4a, 2026-10-20) after (a) and (b): the choke wedge W1c doesn't cover. law-716 Green_Guns_7
   pushes at throttle 0.83 for 50 s, estimated_velocity 9.98 v real 0.32 m/s; the stuck test (movement.gd ~3673) reads
   estimated_velocity when there's no honest blocker, so _stuck_time never builds. Trace whether estimated_velocity is the right
   input when real velocity disagrees 30x; design note + bar before code. For bars: count movers by NET motion, not real_mps alone.

## How to verify

Tests first; `make quick-remote`; one full check at a time on builder0; series pinned, fresh seeds, no random twins
(`tools/judge/seed_twins.py`). Every number: commit, machine, workload, n.

## Don't touch

Traffic's give-way block, brains' tactics/ai outside your carve-outs, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Bar X1b (W1b's deciding probe; X1(b), R35.52's round-36 line) — FILED 2026-10-20 ~12:15 PDT, before any number

**Question:** is a still held hull a sitting duck? **Probe:** `tests/manoeuvre/fight_census.gd` `exposure` (stream 33e0f64d4):
per VICTIM team, crew-ticks and enemy hits taken in state **held_p0** (wheeled, route/direct drive at pace 0, `Traffic.holding`)
and **p0** (the same, not held), plus hits on a still hull (< 0.5 m/s), all live crews' ticks and hits, and `wheel_halts`.
**Arms, both native, builder0:** base = lab/x1b-base (main b7e55e68d + the probe, WHEEL_HALT_DEFAULT false, W1b's mirror inert
on main since R35.62); ON = lab/x1b-on (the same + WHEEL_HALT_DEFAULT true). No `--nav-off` arm (it would leave native's drive).
**Workload:** `make native manoeuvre-fights FIGHT_AT=locks FIGHT_SEEDS=4300..4323` (fresh, fixed arena, no twins), 180 s showmatch,
24 fights an arm. **Reader:** `tests/manoeuvre/x1b_judge.py base on` (paired by arena+seed).
**Counter first:** wheel_halts > 0 ON and 0 base; switch False/True; held_p0 exposure > 0 in both. Else NOT JUDGED.
**Deciding:** D = ON − base hits per exposed held_p0 second, pooled over both victim teams; se = sd of a paired bootstrap over
fights (4000 draws, seed 35). **D > 1.645 se → SITTING DUCK:** W1b does not re-try; the answer is traffic's T8.
**D ≤ 1.645 se → NOT A DUCK:** team 1's guard miss was a tail; W1b re-tries on a fresh bar (round 36).
**Reported:** the same rate per victim team, p0 and all-crew rates, hits on a still hull, team kills / hit rate (fight census).

### ROUND 35 REPORT, FINAL (2026-10-20 ~09:50 PDT) — read this first

**Green:** stream/manoeuvre **47826125c**: builder0 `make native check` exited 0, 2955/0, sim-baseline 13/13 unmoved. Commits after
it (8df3712a7, 2c212324d) are docs and references only.

**Backlog**
1. **W1 DONE:** traced (81/984 wedged deaths: 41 % Traffic holds under fire, 59 % 1–2 s ORCA slows), so no new unstick trigger.
   Traffic took T8 (leave the hold when hit) and the `jam:held` cause.
   - **W1b** (wheeled halt) JUDGED: one guard failed (team 1 hit rate) and it is PARKED (R35.52), default OFF. The round-36 probe
     design is in its README.
   - **W1c + T9, joint3: PARKED (R35.64)** with readings (below): FAIL as filed on (d) attack-move movers, 16 → 17 v ≤ −21.8.
     The base's count could not reach the line. Every other line passed. Default OFF.
2. **W2 / M5 DONE, MERGED** (main ed121d24f, green on builder2 2951/0). A War Rig told to face a way turns there and goes still.
3. **Stretch, R34.16 watch item: INCONCLUSIVE.** Only 5 both-planned faces in M5's rows, and no native clicked pair was run.

**Decisions:**
- W2's give-up is scoped to lifted faces only (R35.23). Plain faces and hull-fixed mounts behave as before.
- W1c counts only friends of another element (R35.39).

**Questions for the lead (the orchestrator's, at the close, R35.64):** joint3, either
(a) a round-36 re-run on fresh seeds, with (e) and crews-off-goal as the deciding lines and (d) as a guard (recommended), or
(b) ship it now on these numbers: never-settled 48 → 23, crews far off goal 105 → 59, every guard in.
Lesson filed: size each deciding line from the base's count at the judged n.

**Requests to other streams:**
- Traffic: T8 (round 36).
- Native: the W1b and W1c mirrors stay inert until their switches pass a bar (stream/native 44b2e04b5, R35.62).

**Known issues:** at the full check, perf-judge and one AI scenario were NOT JUDGED (they refused under load from the joint3
series). W1b's team-1 hit-rate line is still unexplained (the round-36 probe).

**Playtest:** on the Locks or Terminus, draw a face for a wheeled War Rig squad in a tight spot. It should turn and stop, not
creep back and forth at the lock.

**Round 36 list:**
1. joint3 per the lead's choice above. For (a): fresh seeds, a bar filed before numbers, every deciding line checked against the
   base's count.
2. W1b's hit-rate probe (the README's design), then re-judge or drop.
3. The R34.16 watch item, if a native clicked face_pairs pair runs.
4. Traffic's T8 (theirs).

**Merge notes:** the stream's extra code over main (wheelhalt, stallintent + element scope, census counters) is all default OFF.
Merging it into main is inert, as the 47826125c check shows.

### Joint3 (W1c + T9) JUDGED (2026-10-20 ~09:40 PDT): FAILS as filed on one deciding line — `references/round35/manoeuvre/joint3-series/`

builder0, ON lab/joint3-on 872f82ae5 v base lab/joint3-base 2a2682560 (main 5f05c997c: T7 ON, E1 in, E4 in; base carries T6b),
33/33 calls exited 0, hull-rest 128 pairs a task, fights 72. **(d) attack-move movers 16 → 17 v a line of ≤ −21.8: FAIL.** The base
had only 16 movers, so on these seeds the line was out of reach (sized from the dev read, about 56 at 128 pairs). Noted, not
loosened. Every other line passes:
- (0) counters fire;
- (e) attack-move never settled 48 → 23;
- more than 25 m off goal with a live move: 105 → 59;
- (f) +18; (i), (q), (r), (s) within;
- give-ways +208 (band 492); jam-under-fire 122 (limit 136.8); jam:yielding 125 (line 146.3).

W1c stays OFF on the stream. Re-filing is the orchestrator's call; the seeds are spent.

### Stream tip GREEN: 47826125c (2026-10-20 ~09:10 PDT)

`make native check` on builder0, stream/manoeuvre **47826125c** (main ed121d24f merged in, M5 on main): **exited 0, 2955 passed,
0 failed**, scenarios 52/0 (4 pending, 1 unexpectedly passing), sim-baseline 13/13 unmoved, determinism 8c3c1232b711a760. Two NOT
JUDGED, both refusals under load (the joint3 series shared the box): perf-judge (box busy, 3 refusals) and one AI scenario. The
stream's extra code over main (W1b `wheelhalt`, W1c `stallintent` + R35.39 element scope, census counters) is all default OFF.
Joint3's series is in its last stage (hull-rest base arm, builder0); verdict goes to the orchestrator when it lands.

### M5 JUDGED: PASSES as filed (2026-10-20 ~07:40 PDT) — `references/round35/manoeuvre/m5-series/README.md`

builder2, lab/cpf5 **63336d690** (base: the same tree `--nav-off=turnhull,facesettle`; native base lab/cpf5-base 4fb7493a2), main
1a18dd278, **E1 not in**; 60/60 calls exited 0; 7 hull-rest cells hit the 300 s per-run cap, unpaired. Every gate line passes:
(a) point tasks 4.3–5.0° / 71–80 % ≤ 15°; (b) no class worse; (c) clicked +0.00°; (d) on Bar M3's A/A guards (attack-move +6 v
+15.4; it would read FAIL on the series' own se, noted); (e) within; (f) +9; (g) Terminus −4 / +2; (h) 18/18; (i) within; (j) hull
turns 277 373 v 0; (o2) the builder2 sample's 16 cells identical crew for crew, 9 give-ups; (m) same sign; (n) face_creep 0 v 0.
(p) not readable on the series tree. Sent to the orchestrator as the merge candidate.
**Stretch (R34.16 watch item): INCONCLUSIVE.** face_pairs on M5's native drawn pair: 5 both-planned faces (< 10); R34.16's 9.1 m
face was clicked-both-planned and M5 ran no native clicked pair (`face_pairs_native_drawn.txt`). Reported only.

### Joint3 gate green; joint3 and M5 series running (2026-10-20 ~03:30 PDT)

- **W1b PARKS (R35.52)** as filed (team 1's hit rate, +0.0237 v 0.0230). OFF; mirror unmerged; round 36's probe line in its README.
- **Joint W1c+T9, joint3 (R35.53):** on main 5f05c997c (T7 ON, E1, E4). ON lab/joint3-on **872f82ae5** (pair/native-joint3 7a1435cdd +
  STALL_INTENT true + DEFAULT_OFF [] + a probe counter), base lab/joint3-base 2a2682560. Gate: builder0 `make native check` 2931/0,
  sim-baseline moved foundry/crossing/sumps/cut, base 13/13 unmoved (the moves are W1c+T9's). Series running on builder0
  (`~/overnight-manoeuvre/r35/joint3/`), reader `tests/manoeuvre/joint_judge.py` + traffic's `jam_ab.py` (5f2210a8c) `--any-arms`.
- **M5** running on builder2 (33+ of ~58 calls, all exited 0; native arms under way).

### W1b JUDGED (2026-10-20 ~03:00 PDT): as filed FAIL on one guard line — `references/round35/manoeuvre/w1b-series/`

builder0, native both arms, ON lab/w1b-on 7fc4a5307 v base lab/w1b-base ab9c50c76, E1 not in, 3820–3843 × locks/terminus/sumps,
72 pairs, 12/12 calls exited 0. Counter first PASS; deciding PASS (held wheeled crews creeping 63 % → 4 % of pace-0 ticks; wedged +
held deaths 242 v 239); guards PASS (open, stuck, jam deaths, far loops, kills both teams, team 0 hit rate) **except team 1's hit
rate +0.0237 v 1.645 se 0.0230 (a RISE, out by 0.0007)**. Sent to the orchestrator for the ruling; nothing re-run.
M5's series is running on **builder2** (R35.49, started 23:15, chunks at JOBS 6); (o2) so far: the 4 gangs cells common to the
counter sample (builder2) and the series are identical crew for crew, face_settles 9 in the sample. The joint2-on check
(lab/joint2-on 319d63fec on pair/native-w1c-t9 7372e6118) is running on builder0's full-check slot.
**What carried between tests:** brains' E4 (main 5f05c997c) found it: lab hulls placed without `Tank.place`; mixed_legs is now
order-independent.

### Evening (2026-10-19 ~20:30 PDT): queue, the joint check's reds, W1c's element scope

- **Builder0 rule (R35.36):** ONE judged series and ONE full check at a time. My series were stopped; queue: T7, E1, orders D6 →
  **W1b** → **M5** → the joint W1c+T9 (after T7's verdict). The orchestrator says when. Drivers ready, chunked under the slot's
  5400 s kill (`w1b_series3.sh`, `m5_series2.sh`, JOBS 3), outputs of the stopped runs moved to `stale/`.
- **M5 (o2) counters (R35.35):** `ManoeuvreCensus.counters()` carries face_settles / face_settle_fails / wheel_halts /
  stall_intent_ticks (c9974d82b). Sample on lab/m5-counters 43f7a0808 (63336d690 + that commit), 16 drawn runs (4 factions ×
  faced_move/attack_move × 701–702, M1_GD=1, builder0 light): face_settles > 0 in 13 of 71 counter rows (1–3 each). To compare with
  the series' matching rows within the A/A noise when the series runs (R35.35, corrected).
- **Joint-ON check RED** (lab/joint-on b04bfdda2, builder0 `make native check` exit 2, 2916/3; sim-baseline moved foundry, crossing,
  sumps, cut). (1) test_manoeuvre_h1b_guard and (2) test_nav_blocker_reach's control asserted today's behaviour: pinned stallintent
  OFF there + ON arms added (7c6888b2a). (3) test_tactics_mixed_legs (native, only after another test in the process): Green_M_3
  rocked nose-on to its OWN parked squadmate for 40 s, the element's round-18 re-seat never fired. **R35.39:** W1c's intent reading
  only against another element's crew (e795505ea); stream 15/0 native. Native's mirror update requested (spec 7620f67f0).
- **What carries between tests (unproven):** not my statics (per-instance ids, a counter). Leading candidate: trip-up 82 (physics
  settles touching bodies differently in a process's later matches); outside my paths.

### Gates green, series running (2026-10-19 ~17:35 PDT)

- **W1b gate GREEN:** lab/w1b-on **7fc4a5307**, builder0 `make native check` exited 0, **2891 passed 0 failed**, sim-baseline unmoved
  on all 13 maps (1 ai-scenario NOT JUDGED, load). Series running since 16:49 (JOBS 2, the orchestrator's GO):
  `~/overnight-manoeuvre/r35/w1b/series-summary.txt`.
- **M5 gate GREEN:** lab/cpf5 **63336d690** (main 1a18dd278; native base lab/cpf5-base 4fb7493a2), builder0 `make native check`
  exited 0, **2896 passed 0 failed**, sim-baseline unmoved on all 13 (1 ai-scenario NOT JUDGED). Series running since 17:34
  (HULL_JOBS/FIGHT_JOBS 2): `~/overnight-manoeuvre/r35/m5/series-summary.txt`.
- **Joint W1c+T9:** ON tree lab/joint-on b04bfdda2's `make native check` running (`~/overnight-manoeuvre/r35/joint/`).

### Where it stands (2026-10-19 ~16:00 PDT) — read this first

- **W1** traced and closed (design note, R35.7). **W1b** (a wheeled hull held to a standstill doesn't creep): dev read creep 60 % → 4 %;
  native's mirror green (`pair/native-w1b` f4f6bf1d2); series trees **ON lab/w1b-on 7fc4a5307** (WHEEL_HALT true) v **base
  lab/w1b-base ab9c50c76** (both native, + FIGHT_RANGE); the ON tree's C31.1 `make native check` is running (log
  `~/overnight-manoeuvre/r35/w1b/check_7fc4a5307.log`); the 4-step series (wedge probe + fights, 3820–3843 × locks/terminus/sumps,
  72 fights an arm) waits for `~/overnight-manoeuvre/r35/w1b/go_series` (write it when the check is read green AND the judged-series
  lane is free).
- **W1c** (stall gate reads intent against a friend) + traffic's **T9** as one series (R35.13/14): joint dev read frees both traced
  crews; native builds both mirrors on `pair/native-w1c-t9` (its base includes traffic's T6b, R35.19); joint bar on main (hull-rest
  901–932, 128 pairs; fights 940–963). Cut the series pair from native's green hash when it lands.
- **W2** (CP-F 5 face side), scope R35.23: the give-up acts only on a face he gave that turnhull lifts to a wheeled TURRET hull
  (`Manoeuvre.face_settles_here`); plain faces keep round 9. First gate 9a463b0b9 red 2891/3 (the wedged semi, the rolling face);
  three fixes + the scope; 49/0 native face/planner tests on **lab/cpf5 63336d690** (base lab/cpf5-base 4fb7493a2), both on main
  1a18dd278. Re-gate queued (`m5_gate2.sh`, log `m5_gate_63336d690.log`); the series driver `m5_series.sh` waits for
  `~/overnight-manoeuvre/r35/m5/go` (hull-rest 701–716, fights 740–763, Terminus 720–732, SBF 770–775, bridge).
- **Every full check** goes behind `tools/builder_checks.sh --wait-below 2` (R35.25), from the stream worktree.
- **Worktrees:** godot-manoeuvre (stream), -cpf5 / -cpf5base (M5), -w1bon / -w1bbase (W1b), -trace (lab/w1c-t9), -pair2 (old).

### W1c dev read: the counter fires, the crew still doesn't get out (2026-10-19 ~12:30 PDT) — `references/round35/manoeuvre/w1c-dev/`

builder0, GDScript both arms, ec991cf7f. stall_intent_ticks 0 v 1434/2088, H1 escapes and asks up. The traced crews now ROCK (ask,
stand, ≤ 3 m reverse, forward into the same friend): the parked Green_Eyes II_5 gave way once and refused every later ask. Hull-rest
attack-move 460–467 (32 runs an arm): movers 10 v 14, never settled 4 v 7. To the orchestrator: hold M6's series for traffic's T9 (the
parked crew's half), or drop the reverse against a parked friend. W1c stays OFF. **M5's gate** waits for its builder0 slot (orchestrator's
order: native N2, brains E1 → orders D1 → traffic T7 → M5).

### Dev reads (2026-10-19 afternoon; tuning seeds, NOT judged)

- **W1b** (builder0, stream a0c874924 tree, wedge 3500–3503 × locks/terminus/sumps, 12 fights an arm, both arms GDScript drive):
  wheeled pace-0 ticks still moving ≥ 0.5 m/s **60 % → 4 %** (7181/11871 → 636/15723; 7099 of the base's were Traffic holds); halts =
  asks 15727. Deaths 483 v 485, wedged 48 v 46 (dev n). `references/round35/manoeuvre/w1b-dev/`. Native's mirror queued (orchestrator).
- **W2** (builder0, lab/cpf5 bdacb1786, hull-rest 460–463 drawn, GDScript both arms): wheels/turret point tasks median 3.9–5.4° v
  32–72° (≤ 15°: 73–80 % v 11–33 %); movers at the judge new ≤ base on 5 of 6 tasks (right 7 v 5), `face_creep` 0 in the new arm.
  **Found:** hull-fixed scouts (wheels/fixed) ≥ 45° off rose 33 → 48 over six tasks: a scout's creep is how it aims, so the give-up is
  now TURRET hulls only (5c692b507, test added). lab/cpf5 is re-cut on that before the gate.
- **W1c traces** (brains' E1 laggards, native, main 0f4d528d7 + OFF switches): law-605 Green_Eyes_4 (scout) still wedges with the
  turn-in shipped: 70 s blocked by a PARKED crew of another squad (Green_Eyes II_5, which gave way once but only 2.4 m, still
  touching); law-607 Guns_6 the same in a pack of friends. ORCA pace 0.05–0.09 hides the stall from unstick's |throttle| > 0.5 gate.
  W1c approved (R35.12), Bar M6 filed; built OFF (f9b3bb7f3). `references/round35/manoeuvre/w1c-trace/`.

### W1b and W2 built, default OFF; quick green (2026-10-19 ~10:30 PDT)

`9d2486dab` builder0 `make quick-remote` (QUICK_BASE 0f4d528d7) **exited 0, 75 passed 0 failed**, lint clean. W2's boxed War Rig
(four parked squadmates, face 90° right): ON gives up after 3 failed plans and stands (throttle 0, moved 0.0 m over the last 3 s,
`face_settled()` true); OFF creeps (throttle 0.7, 3.2 m). Open ground: turns to 3.4°, no give-up. W1b's rule test: 3/3. Orchestrator: W1b
approved (R35.7, arenas locks/terminus/sumps); Bar M5 filed on main 8640ec500. Dev reads running (tuning seeds: wedge 3500–3503 ×
locks/terminus/sumps, both arms GDScript; hull-rest 460–463 drawn on lab/cpf5 bdacb1786).

### W1 TRACED, design note sent (2026-10-19 ~09:30 PDT): `references/round35/manoeuvre/w1-trace/README.md`

builder0, native path, behaviour of main a0ae0aafd + the probe, Locks/Terminus × fresh 3500–3511, 24 fights × 180 s, 984 deaths:
**81 stuck:wedged (8.2 %, T5's rate)**, 80/81 hit in the last 10 s, 67/81 wheeled. Two populations, neither one stuck: **41 % held by
Traffic's take-turns hold** at a street mouth under fire (median 5.4 s into the hold; the 3 longest episodes, 18 s, all holds; on
wheels the at-spot hold is throttle 0 at full lock = the plant's creep shuffle, 67/106 at-spot ticks moving); **59 % ORCA slowing a
crew in a fight's crowd, wedged a median 1.2 s** before death. Unstick drove 1 % of ticks. Proposals: (A) no new wedged trigger;
(B) traffic: a held crew that is hit leaves the hold (request); (C) mine W1b: a wheeled hull held to a standstill doesn't creep
(native mirrors); (D) traffic's death_cause gets `jam:held`. Waiting on the orchestrator for (C); built OFF meanwhile.

### Bar M5 (W2, CP-F attempt 5, the face side; C35.7, decoupled from brains by R35.3) — DRAFT, to the orchestrator before any number

**Candidate:** stream/manoeuvre + `TURN_HULL_DEFAULT := true` + `FACE_SETTLE_DEFAULT := true` (lab/cpf5). **Base:** the same tree,
`--nav-off=turnhull,facesettle`. **Gate (C31.1):** lab/cpf5's whole `make native check` green on builder0 (sim-baseline moves
attributed with `--nav-off=turnhull,facesettle`). **Machine:** builder0 only, one series at a time (C35.1), FAR_JOBS/HULL_JOBS 3 while a
check runs. **Seeds (fresh):** hull-rest 701–716 (4 factions × 16 × 6 tasks, drawn and clicked, GDScript M1_GD=1 both arms, plus
the native drawn pair), Terminus 720–732, SBF 770–775, bridge-pooled's 18, fights on FIXED arenas locks/terminus/sumps × 740–763
(`FIGHT_AT`, R34.15). **Ruler and noise:** M1's (real_mps, wedged apart, HULL_SHIFT_M 6, HULL_JITTER_DEG 20), the A/A table in
round 34's Status. **Lines:** Bar M3's (a)–(m) unchanged (same rules, same A/A guards), plus:
| line | reads | rule |
|---|---|---|
| (n) | `face_creep` crews at the judge (hull_rest_moving), wheels/turret, per task | new ≤ base + 1 (attempt 4 read 8 v 0 on screen; the mechanism this attempt removes) |
| (o2) | counters in the new arm | `face_settles` > 0 and `face_settle_fails` REPORTED; `hull_turns` > 0 |
| (p) | wheels/turret at rest error, the crews that gave up | REPORTED (median, and how many ≥ 45°): the price of standing still |
**Partial:** (a)–(j), (n) are the gate; a miss parks it with a trace. Attack-move's step (attempt 4's mechanism 2) is brains' (R35.3,
the straggler release); if (d)/(e) miss on attack-move only, the trace says which mechanism, and the verdict goes to the orchestrator.

### Bar M6 (W1c, the stall gate reads the drive's intent against a friendly hull; R35.12) — DRAFT, to the orchestrator before code

**Change:** in `Movement._unstick`, for a ROUTED move (`move_to`, not `direct`) whose hull is in contact with a friendly hull (slide
collision) or whose phase is `blocked` by a friend, the stall rule's throttle test reads the drive's intent, |throttle| / pace when
pace < 1; every other case keeps `|throttle| > 0.5`. H1's escape unchanged (ask, straight reverse by the sweep, stand). Switch
`--nav-off=stallintent` (default OFF until this bar passes); native mirrors after the dev read. **Candidate** = stream + the
default flipped (lab/w1c), as a pair with native's mirror; **base** = the same tree `--nav-off=stallintent`. **Gate:** the pair's
whole `make native check` on builder0. **Seeds (fresh, outside E1's and M5's 701–716):** hull-rest 901–916 (4 factions × 16 × 6
tasks, drawn, both arms on the pair's native path), fights on FIXED locks/terminus/sumps × 940–963 (`FIGHT_AT`; also the wedge probe's
WEDGE_RANGE 940–963 for far loops / contacts / asks). Tuning seeds stay 460–475 and wedge 3500–3511.
| line | reads | rule |
|---|---|---|
| (0) counter first | in the ON arm: stall clocks run under the intent reading (`stall_intent_ticks`), H1 escapes started (`esc_fires_hull`), asks (`esc_asks`) | each > 0, or nothing is read |
| (d) deciding | hull-rest attack-move crews moving at the judge by `real_mps` (wedged apart) | new ≤ base − 1.645 × sd_run(A/A 1.17) × √pairs; also no other task worse than Bar M3's (d) guard (+1.645 sd√n: right 0.64, move 0.51, screen 0.41, ambush 0.24, SBF 0.23) |
| (e) deciding | attack-move never settled (75 s) | new ≤ base, and no task over base + Bar M3's (e) guard (se 3.0 a task at 64 pairs) |
| (f) | arrivals within ARRIVED_M | not down beyond 1.645 se paired |
| (i) fights | kills, deaths, hit rate per team (fight_table) | within 1.645 se paired |
| (q) jams | stuck, jam (yielding/friend) and open deaths (wedge probe's causes) | each within 1.645 se paired |
| (r) far loops | ManoeuvreCensus far rows | ≤ base + 1.645 se |
| (s) friendly contacts | ticks touching a friendly hull (wedge probe) | ≤ base + 1.645 se |
| (t) asks | H1 asks and give-ways started, per fight | REPORTED (the churn risk) beside base |
**Partial:** (0), (d), (e), (f), (i), (q)–(s) are the gate. A miss parks it with a trace.

### Requests to other streams

- **traffic:** (B) release a Traffic hold for a crew being hit; (D) `jam:held` in `death_cause` before `stuck:wedged`.
- **native:** mirror W1b in drive_native (pace-0 wheeled hold: turn 0) once the switch's GDScript lands.

### Plan (2026-10-19, Opus)

1. **W1 trace** — `tests/manoeuvre/wedge_trace.gd` + `wedge_table.py`, `make native manoeuvre-wedge-trace` (WEDGE_AT, WEDGE_RANGE;
   fresh seeds 3500+ on Locks/Terminus; native path). Per wedged episode: what shaped the motion each tick (unstick / k-turn /
   yield / Traffic hold / ORCA turn / ORCA slow / sideways shove / the drive itself), what unstick's stall rule saw, the order and
   brain option, hits, friends near. Per `stuck:wedged` death (T5's `death_cause`, verbatim): a 10 s timeline. → design note to
   the orchestrator → bar → only then a change.
2. **W2 face settle** — seam proposed to the orchestrator 2026-10-19 (a face no plan fits 3 times in a row stops still, `--nav-off=facesettle`,
   ships with turnhull ON; `Movement.face_settled()` offered to brains). Code waits for the agreement.
3. **Stretch** — the R34.16 watch item, if a face_pairs series runs.

### W1 first read (laptop, stream a0ae0aafd + probe, locks s3500, 90 s, one fight, mechanism only)

The `wedged` flag counts every tick whose pace is under 0.999 — so a crew **holding at a street mouth on purpose** (Traffic's
take-turns hold, pace 0) and a crew **giving way** are "wedged" too. In that fight: 251 episodes; by tick, Traffic hold 37 %,
ORCA slow 36 %, yield 10 %, drive 8 %, ORCA turn 6 %, k-turn 3 %, shove 1 %. Of 5 wedged-at-death crews, one was holding (pace 0,
held True), which T5's `death_cause` files as `stuck:wedged`. The builder0 batch (24 fights) decides how big that share is.
