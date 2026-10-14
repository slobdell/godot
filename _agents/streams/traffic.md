# Stream: traffic (two of your squads crossing at an angle: the yielding squad is released once the other's tail clears; a set-up mortar truck stays set up while it is still ordered to fire)

> Read `_agents/orchestration.md` (the worker contract; lessons 295–305), `_agents/game_design.md` *Round 26 direction*,
> *Round 28 direction* (his call 1), `_agents/workstreams.md` **Round 30** (C30.1–C30.10), and round 29's traffic report
> (`streams/archive/round29/traffic.md`: *REPORT*, *T3 judged*, *T1c judged*, *the builder0 throughput extension*).
> **You own:** `game/ai/avoidance.gd`, `game/ai/steering.gd`, `game/ai/traffic*.gd`, in `game/ai/movement.gd` the give-way
> block (`right_of_way` through `_blocker`), `_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`;
> `tests/test_traffic*.gd`, `tests/traffic/**`, `tests/ai_scenarios/scenario_traffic*.gd`, `tests/test_avoidance.gd`,
> `mk/traffic.mk`; the builder0 tooling you built in round 29: `tools/series_cache.sh`, `tools/quick_tests.sh`,
> `mk/infra.mk`, `tests/shard_times.txt`, `tests/quick_neighbours.txt`, `tests/run_tests.gd`'s shard plan. **Granted
> (C29.3, standing):** your one gate line each at brains' `_track_progress`, `_update_phase`, the element's make-room /
> re-seat clock, and manoeuvre's `unstick`, `_pressing_escape`, the k-turn entry. **The C++ (C30.2):** `right_of_way`,
> `_avoid`, `Avoidance.solve` and the hold's read have C++ twins; develop on the GDScript path, send native the settled
> diff before the commit. **Model:** this stream runs on the usual model (Opus).

## The lead's direction

Round 26: *"if I take 2 squads and have them move in opposing directions such that they have to cross each other … vehicles
will get stuck bumping into each other … people would just generally each turn to the right in order to deconflict. The
same case might not be said if we're charging toward an enemy."*
**Round 28, his call (2026-10-12): TAKE TURNS:** "fewer bumps; both squads arrive a little later." The pass line may
trade some arrival time for fewer bumps, and never crews that fail to arrive.
**Round 30 (2026-10-14):** no new words from him on traffic; the street hold shipped in round 29 and he plays it. His
standing ask for this round is builder0's bottleneck (`roadmap.md` *a second build machine*: free fixes first).

What he will notice: two of his squads crossing at an angle (not head-on): the squad that yields does not crawl along as a
whole for 30–45 s; it goes as soon as the other squad's tail is past the crossing point. A set-up mortar truck that is still
ordered to fire does not pack up to let a squadmate by.

## Where things stand (main `0d35f215`, GREEN: builder0 2584/0, 26 ALL JUDGED)

- **T1 the street hold SHIPPED** (round 29, `3a94f38d` + native's port): Terminus head-on between-squad fast contacts
  475 → 91 (−81 %), crews 176 → 177, all-in 60.8 → 59.3 s, no wedge; CPU mirror 475 → 58. `Traffic.holding(crew)` gates
  brains' and manoeuvre's clocks. `--traffic-off=hold`.
- **T3 (the crossing) FAILED its bar — parked `traffic-t3` (`d9b3339c`; judged seeds 22–24 × 6, n = 18):** between-squad
  fast at the two crossing cases 206 → 95 (−54 %) and head-on = base PASSED; but Terminus crossing all-in 39.4 → 48.3 s
  (+23 %, bar +20 %), yard crossing crews 171 → 167 and one wedge (yard s22/t6) FAILED. **Worst runs: the yielding squad
  crawls at 0.4 as a whole for 30–45 s.** Tables: `references/round29/traffic/t3_*`. The yard far-end misses (both arms)
  were relayed to brains as a B5c sighting (brains has the gate this round).
- **T1c (a set-up hull does not give way) FAILED — parked `traffic-t1c` (`761bd727`; census seeds 4–6, n = 9):** set-up
  give-ways 25 → 9 against a bar of 0; friendly-stuck, fast contacts, artillery shots passed; repacks while giving way
  13 → 7. **The 9 are give-ways a set-up hull STARTS itself in `_negotiate` with a new move** (it is leaving anyway).
  Tables: `references/round29/traffic/t1c_*`.
- **builder0 tooling (round 29, on main at `de08392b`):** I1 time-balanced shards OFF by measurement (−6 % v a −30 % bar
  on a loaded box); I2 `make quick` / `quick-remote` built, its ≤ 10 min timing OWED; I3 `tools/series_cache.sh`
  (`CACHE=on` in `traffic-series`) built, OFF, its cached == fresh proof OWED. The floor at 5–6 shards is
  `test_tactics_scenarios.gd` (425 s): brains splits it (C30.9), not you.
- A fresh `make test` after merging `native/` runs a stale library: `check` and `quick` rebuild first (`verification.md`).

## Backlog (in order)

**T3b — the crossing, released on the tail (DECLARED; round 29's last attempt was used, so this is a NEW design with its
own last attempt named).** Keep v3's squad-pair crossing verdict (`--traffic-off=turns`; base = hold ON). Change what the
yielding squad does: (a) release every crew of the yielding squad once the passing squad's LAST crew is past the crossing
point (plus a short margin), not when each crew's own path is clear; or (b) crawl only the crews within one squad length
of the crossing point and let the rest drive normally. Trace the round-29 worst runs first (`traffic-t3`, Terminus
crossing seeds 22–24; yard s22/t6's wedge) and pick (a) or (b) from what the trace shows; write which and why before
tuning. Tune on seeds {1,2,3} only.
**Bar (send it before the numbers; name the last attempt; cite sizing's row for each line if CP-N has landed, C30.3):**
round 29's T3 bar as written (between-squad fast pooled over the two crossing cases −≥ 25 %, neither up; every case crews
≥ base − 2, all-in ≤ +20 %, no wedge; same-squad fast ≤ base × 1.2 + 10 per crossing case; head-on within 2 se; CPU
mirror reported; bridge-pooled 18/18; live test fires; ≤ 0.5 ms) **plus** the Terminus crossing all-in median ≤ base +
10 % (the crawl is the thing being fixed) and the yielding squad's own all-in reported. Fresh seeds (not 1–3, not 22–24).
No partial. Native diff (Traffic.shape callback in `_avoid`, anything in `right_of_way`) before the commit.

**T1c-b — a set-up hull ordered to fire stays set up (DECLARED).** Re-define what is judged (the orchestrator's round-30
note): a set-up hull with a NEW move of its own is leaving anyway, so its give-way is not the defect; the defect is a
**repack while still ordered to fire** (no new move; `deploy_ratio > 0`; a squadmate's ask). `Movement.ask()` refuses
while the asked hull is set up AND still on its fire order; the asker goes round (`--traffic-off=setup`). Count exactly
that: `repacks_while_firing` per arm.
**Bar:** traffic-census fresh seeds (not 4–6): `repacks_while_firing` 0 in the arm, > 0 in base (else NULL: lesson 300);
friendly-stuck ≤ base × 1.2 + 10; fast contacts ≤ base × 1.1 + 5; artillery fire not down > 2 se; bridge-pooled 18/18;
your four cases no wedge; **brains' ApproachStage drawn artillery (seeds 13–15 × 6, both arms, B1 on main): give-way
repacks → 0 and B1's lines hold** (from the side 18/18, first round ≤ clicked + 30 s). No native diff expected; say so.

**I3 — the series cache's proof (OWED).** On builder0: one `traffic-series` base row run fresh, then the same row with
`CACHE=on` twice (a miss then a hit); show the cached row equal to the fresh one FIELD FOR FIELD (every jsonl field,
diffed), and that a one-line change to `game/` misses. Write the proof into `verification.md` (where I3 is described)
and tell the orchestrator; adoption by brains' and manoeuvre's series is the orchestrator's call (C30.7).

**I2 — `make quick`'s timing (OWED).** Measure `make quick` on builder0 for a one-file `game/ai/traffic*.gd` change: the
whole thing ≤ 10 min, or say what is over and why. Record it in `verification.md` with commit and machine.

**Stretch — the friendly half of the creep.** Manoeuvre's round-28 census: about half of creep episodes are a squadmate in
the way. A give-way that lets a creeping long hull through (an ask from a hull mid-turn is answered by the squadmate
backing out of its arc). Only after T3b and T1c-b are judged, and only agreed with manoeuvre (and the planner's design
if it has landed) through the orchestrator; DECLARED with its own bar.

## How to verify

`make remote T=check` (builder0 only, C30.7); `make traffic-series`, `traffic-trace`, `traffic-census`, `bridge-pooled`,
`native-verify-scenarios`; a `traffic-clip` of his Terminus crossing case before and after for him (watch it: does the
yielding squad go as soon as the other's tail is past?). Every number carries its commit, machine, workload and n.

## Don't touch

Manoeuvre's drive body, k-turn block, `manoeuvre*.gd`, `order_controller.gd`; brains' `game/tactics/**`, elements,
`tank_brain.gd`, `_approach_gate` (except the granted gate lines); native's `native/**`; `game/control/**`;
`test_tactics_scenarios.gd` (brains splits it, C30.9); the planner's and sizing's paths.

## Waiting on the lead

Nothing: his calls are made.

## Status

_(the worker keeps this current: every number names commit, machine, workload and n; bars go to the orchestrator before
numbers; the report at the top)_

_Updated 2026-10-14 ~15:15 PDT (traffic worker, round 30). Every number names commit, machine, workload and n._

### REPORT (traffic, round 30) — read this first

- **I3 the series cache's proof: DONE, accepted.** Builder0, `bd05077d`, Terminus crossing, n = 18: a fresh run, then a
  miss and a hit into an empty cache directory are byte-identical (576 fields, 0 differences). A one-line `game/` change
  misses. Written into `verification.md`. Note that `CACHE=off` still writes rows, so a proof needs its own
  `SERIES_CACHE_DIR`. Adoption by other series is the orchestrator's call (C30.7).
- **I2 `make quick`: DONE, inside 10 min.** Builder0, a one-file `traffic.gd` change: 1272 s cold and 1081 s warm with
  the full lint (712 s of it); **487 s** with the narrowed lint (`tools/quick_tests.sh --lint`, `make quick-lint`: 13
  scripts, 24 s). `check` still lints all. Written into `verification.md`.
- **T3b the crossing: FAILED** one filed line (the yard crossing clock +2.80 s against +1.18 s); everything else passed
  (between-squad bumps −45 %). Parked on `traffic-t3b`. The trace corrected the brief: the crawl costs ~2–4 s, and the
  40–75 s last arrivals are a far-end seat trap (35.6, 23.9), relayed to brains. Recorded as his round-31 call.
- **T1c-b the set-up battery: FAILED** one filed line: artillery shots 318 → 163, one diverged run carrying it. The
  defect itself passed (repacks while firing 4/9 → 0/9 runs). Parked on `traffic-t1cb-judged`. Row 82's under-sizing
  (judged 1.645 se 237 v 21.6) goes to sizing.
- **T4 the ghost (the orchestrator's new item from manoeuvre's M4b trace): tuned, not judged, waiting on M4b's merge.**
  ORCA's neighbour table reads `estimated_velocity`, so a pinned hull is a 12 m/s ghost. On `lab/traffic-t4` (=
  stream/traffic + M4b's `77a1603f`; tuning data in `references/round30/traffic/t4_tuning/`):
  - **v1** (neighbours read `real_velocity`): fixes manoeuvre's oscillating IFV (mixed-21 stuck 74 → 12 s), but exposes a
    War Rig pinned at full throttle against a friend whose stall clock never fires (rigs 72 → 164 crew-s). M4b keeps the
    rig's unstick on `estimated_velocity`.
  - **v2** (its own velocity honest too) is neutral and leaves the IFV oscillating.
  - The probe's noise (sd ≈ 60 s a run) needs ~24 runs a squad to decide a halving. The bar was proposed to the
    orchestrator, with a request to manoeuvre about the rig's stall reading. **Next:** when M4b is on main, re-base on
    main, size the bar and judge v1 (native pair: `avoidance_gather` and the drive's solve).
- **Stretch (the friendly half of the creep): not started.** The orchestrator's T4 took its place; it overlaps (a
  pinned hull and its neighbours).
- **stream/traffic's `game/` equals main's** (`bd05077d`). The branch carries: the crossing clock in the traffic probe and
  table, `turns_verdict.py` (CP-N's guards), `make quick-lint`, `tools/quick_tests.sh --lint`, `verification.md`'s I2/I3
  text, and this round's data under `references/round30/traffic/`.

**Merge notes:** no game change. `mk/infra.mk` and `tools/quick_tests.sh` (granted, C30 I2) change `make quick` only.
`tests/traffic/traffic_stage.gd` adds report fields (`crossed_s`, `cross_*_s`), which changes the series-cache tree hash
for traffic rows (intended).
**Kept branches:** `traffic-t3b` (`cf124433`), `traffic-t1cb-judged` (T1c-b plus the census additions and
`traffic-native-verify`), `lab/traffic-t4` (`b63a90c1` = v2; v1 is `05bb2c22`). `traffic-t1cb` is superseded by
`traffic-t1cb-judged`. Round 29's `traffic-t3` and `traffic-t1c` are superseded by these two.
**Questions for the lead:** none blocking. His round-31 calls are recorded by the orchestrator in player terms: the
crossing ("the yielding squad gets through ~3 s later at a yard crossing and the squads bump half as often") and the
battery ("no longer packs up for a squadmate passing; whether it then fires less is not decided").
**What to playtest:** nothing new in play from this stream this round (both judged changes parked).
**Requests to other streams:**
- brains: the far-end seat trap (35.6, 23.9) at B's destination on the Terminus crossing, relayed.
- manoeuvre: a War Rig's stall clock against a friend under T4 v1, relayed.
- sizing: row 82 (artillery shots), under-sized ×10 on the T1c-b judged pair.

### T1c-b — a set-up hull on its fire order stays set up: FAILED one judged line (last attempt); parked on `traffic-t1cb-judged`

**The rule.** `Movement.ask()` refuses while the asked hull is **on its fire post**. That means deploy_ratio > 0, a weapon
order other than hold_fire, and its own order is not a move or the move has arrived (`Movement.on_fire_post()`). The asker
treats it as parked and goes round. `--traffic-off=setup`; counter `Movement.setup_refusals`; `test_traffic_setup` 5/5.
**The census counts the defect:** `repacks_while_firing`, a repack while giving way to an ask received on the post.

**Tuning** (builder0, `88e52c8f`, census seeds 1–3, n = 9 an arm): repacks while firing 13 → 0 (runs 5/9 → 0/9);
ApproachStage drawn artillery seeds 4–6 t1: the give-way repack 1 → 0, all else equal.

**Judged** (builder0, `16780030` both arms, GDScript path; census fresh seeds 7–9, n = 9; ApproachStage drawn artillery
seeds 13–15 × six ticks, n = 18; bar filed before numbers; data in `references/round30/traffic/t1cb_*`):
- **(1) the defect: PASS.** Runs with any repack while firing 4/9 → 0/9 (one-sided Fisher p = 0.041); total 11 → 0.
  Repacks while giving way 33 → 4; refusals 0 → 65.
- **(2) friendly-stuck:** 496 → 404 crew-s, pass. **(3) fast friendly contacts:** 589 → 563, pass.
- **(4) artillery shots, not down by more than 21.6 (row 82): 318 → 163, FAIL.** One run carries it. In parade s9, shots
  fell 171 → 26, and in that run BOTH sides' artillery fell: Rust's batteries refused nothing and still went from 19 to 7
  rounds. The run was re-run singly with per-battery counts: Green's batteries were set up for similar times but fired
  1–5 rounds each, against 14–19. The fight's geometry diverged. Without that run the census reads 147 → 137. The judged
  paired se (1.645 se = 237) is ~10× CP-N's row 82 (21.6), so this line's noise was under-sized. The verdict stands as filed.
- **(5) ApproachStage drawn:** repacks 8 → 2, from the side 18/18 both arms, first round median 27.1 s both, alive 3.00
  both, pass. (The 2 left were not traced: the verdict was already decided.)
- **(6) bridge-pooled** 18/18, pass. **(7) the four traffic-series cases, seeds 31–33:** all 72 rows equal T3b's base rows
  field for field (bar T3b-only counters), pass.
- **The orchestrator's additions, from the worst run only** (parade s9, arm): refused askers went round 7, never past in
  20 s 0, 2 pending at the end. Every refusal was on Green's side (that side's batteries were the ones set up).
  `traffic-native-verify` was built (on the branch) but not run, because the verdict was decided.
- stream/traffic's `game/` is back to main's. The rule, the counters and the native-verify target are on
  `traffic-t1cb-judged`.

**For whoever takes it next:** the defect line passes cleanly. The open question is whether artillery fire really falls.
Re-judge on more census seeds, with the artillery line re-sized from this run's paired sd, or with fire counted only for
batteries that had a target in range.

### T3b — the crossing, released early: FAILED its judged bar (last attempt); parked on `traffic-t3b` (= `cf124433`)

**What the trace showed first (it corrected the brief).** Round 29's "the yielding squad crawls at 0.4 for 30–45 s" is not
what happens. The probe now carries **the crossing's own clock** (`crossed_s`, `cross_a/b/clear_s`: when each crew is
8 m past the meeting point; `traffic_table.py` prints it). Both squads clear the crossing by 8–25 s. Round 29's 40–75 s
last arrivals (traced: Terminus s24/t3, s22/t6, reproduced run for run) come AFTER the crossing: a rear crew of the yielding
squad circles its far-end seat reading `no_path`/`terrain` for 25–40 s. Brains measured that this circling needs the rule
underneath (main's behaviour: 32.6 / 27.3 s, no circling).
- **The yard trace (s3/t3) picked option (b), not (a).** Round 29's whole-squad crawl ended by ~6.5 s, before the passing
  squad's tail was past, so (a) would change nothing there. The cost was the rear crews it left behind: the element's leads
  stopped at their next slots and waited ~4.5 s for them.
- **(b):** only crews within `CRAWL_REACH_M` (20 m) of the crossing keep the squad's share (`--traffic-off=reach` = round
  29's; counter `tr_cross_reach_free`). The crossing shipped DEFAULT-OFF (`Traffic.DEFAULT_OFF`, `--traffic-on=turns`)
  because the C++ `_avoid` has no `Traffic.shape` yet and the native drive tests compare against the GDScript.

**Tuning** (builder0, seeds 1–3, n = 18 a case, base = turns off; data in `references/round30/traffic/t3b_tuning_*`):
| case | between-squad fast | yielding squad's crossing (v2 → (b)) | crews |
|---|---|---|---|
| Terminus crossing | 116 → 42 | +2.8 → +2.0 s | 176 → 178 |
| yard crossing | 118 → 48 | +3.5 → +1.9 s | 169 → 169 |

12 m was tried and rejected (yard crews 169 → 163, two wedges).

**The bar** was sent before any judged number and filed by the orchestrator. It was sized by CP-N's rows, with the crossing
clock in place of round 29's all-in line (`tests/traffic/turns_verdict.py`).

**Judged** (builder0, `cf124433` both arms, GDScript path, fresh seeds 31–33 × six ticks, n = 18 a case; base no flag, arm
`--traffic-on=turns`; `references/round30/traffic/t3b_judged_*`, `t3b_verdict_cf124433.txt`): **VERDICT FAIL on one line.**
- Between-squad fast, crossings pooled: 176 → 96 (−45 %), pass. Terminus 76 → 50, yard 100 → 46.
- Crews: Terminus 176 → 176, yard 168 → 166, pass. No wedge. Same-squad fast 170 → 187 and 140 → 122, pass. Head-on
  cases within 1.645 se, pass.
- Crossing clock, Terminus: mean paired −1.17 s (se 1.05, limit +2.92), pass.
- **Crossing clock, yard: +2.80 s (se 0.22, limit +1.18), FAIL.** The yard's yielding squad pays +3.66 s (se 0.23) to
  pass behind the other. The judged paired sd (0.92 s) is under the tuning sd (1.77 s), so the 1.5× caveat does not apply.
- Reported: all-in median Terminus 50.8 → 42.8, yard 90.0 → 90.0 (CP-N se 7.0 / 10.2 s).
- Counters: verdicts 18 / 19, slowed crew-ticks 11592 / 10771, reach-free crew-reads 2041 / 1332. The rule also fires
  inside the head-on cases: 8 and 10 verdicts, a few hundred crew-ticks, no line moved.
- **The worst run read before the medians:** Terminus s33/t1, all-in 33.7 → 61.4 s, every crew in. B_4, the yielding
  squad's rear crew, gives way to two squadmates at the far end, then circles its seat (35.6, 23.9) reading
  `no_path`/`terrain` from 36 s to 61 s. Round 29's s24/t3 jammed on the same seat. Its share was 1.0 from 12 s on.
- The CPU mirror and `bridge-pooled` were not run: the chain was stopped after the verdict, by its own PIDs, and builder0
  was checked clear.
- stream/traffic's `game/` is back to main's. The crossing clock and the verdict script stay.

**For whoever takes it next:**
1. The bump cut is real on three seed sets (−45 % to −63 %).
2. What it costs is the yielding squad's ~2–4 s wait at the yard, which a +10 % line on a 9 s crossing cannot hold.
3. Its worst runs are a far-end seat trap that the changed arrival order exposes: (35.6, 23.9) on the Terminus,
   brains' gate.

### The plan (ordered; smallest foundation first)

1. **I3 the cache's proof** first: it needs no game change, and its fresh rows are T3b's tuning base (Terminus crossing,
   GDScript path, seeds 1–3 × the six ticks). Done below.
2. **I2 `make quick`'s timing** on the same one-line `traffic.gd` change that shows the cache missing.
3. **T3b the crossing, released on the tail**: re-apply round 29's v2 (`traffic-t3`), trace the worst runs, pick (a) or
   (b) in writing, tune on {1,2,3}, send the bar, judge on fresh seeds, native's diff before the commit.
4. **T1c-b a set-up hull ordered to fire stays set up**: the refusal in `ask()` and the `repacks_while_firing` counter,
   judged on fresh census seeds and brains' ApproachStage drawn-artillery arm.
5. Stretch (the friendly half of the creep) only after 3 and 4 are judged, and only once agreed with manoeuvre through the
   orchestrator.

