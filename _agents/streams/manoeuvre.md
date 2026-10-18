# Stream: manoeuvre (a wheeled turret vehicle given a facing turns its hull there at rest and sits still: CP-F)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 28 direction* (his call 2: turn
> the whole vehicle), `_agents/judging.md`, `_agents/workstreams.md` **Round 33** (C33.3; R32.3 stands), `_agents/roadmap.md`
> *Round 33 candidates*, your round-32 brief `streams/archive/round32/manoeuvre.md` (*Round 32 close*, *Round-33 lessons*,
> M1b(3)'s carry), brains' `streams/archive/round32/brains.md` (*B11 JUDGED*: its table and reading) and planner's
> `streams/archive/round32/planner.md` (the hull-rest trace: s66 "a `stop` with no face step after the move").
> **You own:** in `game/ai/movement.gd` the body of `drive()`, `_nose_stop`, `unstick`, `_pressing_escape`, H1 / H1b, the
> k-turn / planned-reverse / circle EXECUTOR (`kturn_on` through `_look_stop`, `_kturn_start_leg`, `_planned_reverse`), not
> its plan source; `game/ai/manoeuvre*.gd`, `game/ai/clothoid.gd`, `game/ai/wall_contact.gd`; in `order_controller.gd` the
> face-at-rest path; `tests/test_manoeuvre*.gd`, `tests/test_kturn*.gd`, `tests/manoeuvre/**`,
> `tests/ai_scenarios/scenario_manoeuvre*.gd`, `mk/manoeuvre.mk`. **Granted:** the two aim-lead lines in `gunnery.gd`;
> `TankBrain._order_move`'s decline for wheeled turret hulls under `turnhull` (C31.8). **The C++ (C31.2):** the drive,
> unstick, the executor and the leads have twins; send native each settled diff. Counters go in `ManoeuvreCensus`, never
> `Movement` statics. **Model:** Opus.

## The lead's direction

Round 28, call 2: **turn the whole vehicle to his drawn facing.** No new words at round 33's preparation.

He was told at round 32's close, as a known issue: **a War Rig on a faced move can end ~150° backwards.** What he will
notice when CP-F ships: a War Rig, gang tank or IFV he tells to face a direction ends with its hull pointing there and then
sits still; with brains' B11b on top, one pushed off its post goes back and faces his way again.

## Where things stand (main at the round-33 docs commit; inherits `0c124cf7`'s green check: builder0 exited 0, 2724/0)

- **H1b is ON** (round 32): near-goal settle-short. The far loops are traffic's this round (C33.2); your `H1B_FAR` rows and
  `blocker_kind` are their census tool, so answer traffic's questions about them.
- **The face at rest is the missing piece.** B11 (brains, OFF, `--hold-return=faced`) halved the turreted rigs' error
  (faced_move 48.4 → 17.3°) but the named case s66 Green_Guns_5 still ended > 100°: the return completes inside the 6 m
  settle radius still turned, and nothing faces a wheeled turret hull at rest. Fixed-gun wheeled hulls got worse with B11
  (B11b will touch turret hulls only).
- **A likely main bug (planner's trace, round 32):** hull-rest faced_move s66, both queue arms end ~150° off and the seam
  never acted: a `stop` with no face step after the move.
- R32.3 stands: arrived = the held seat at completion (ARRIVED_M 7 m), re-seats a guarded FAIL line; facekeep unchanged
  for gang hulls; the heading reaches the seating through the arrival halt's shape.
- Your round-32 branch is `round32/manoeuvre` (merged); `lab/manoeuvre-swap2`, `pair/swap-ship` are records only.

## Backlog (in order)

1. **F0 The missing face step (trace first).** Reproduce s66 faced_move on main (hull-rest, drawn, the War Rig); find why
   the order ends in a `stop` with no face step. If it is a bug, fix it alone on its own commit with a test that fails
   without it; a check; name the hash (it may ship before F1).
2. **F1 CP-F, turn the hull at rest (M1b(3), C33.3):** a wheeled turret hull that completes a faced order turns its hull to
   the facing at rest (the planner's face plan where the room needs legs: agree with planner, C33.6 (c), who owns a faced
   finish), then settles. The attack-move settle (crews still moving at 75 s) is the line attempt 2 failed: solve it, don't
   re-prove the turn. Bar first (`judging.md` noise): faced error by class down, never-settled not up, settle time within
   its line, re-seats guarded (R32.3). Whole suite on the pair tree with the switch ON; ships ON as a pair. **Tell brains
   the hash the day it merges: B11b judges on it.**
3. **F2 Help B11b:** brains' turret-only HOLD return judges on CP-F; answer its questions on the face step.
4. **Stretch:** a short clip of a War Rig told to face behind, before and after, for him.

## How to verify

`make quick-remote` to iterate; `make remote T=check` on the pair tree with the switch ON before any series, only for
hashes you name. `make manoeuvre-hull-rest` (one arm a call), `manoeuvre-fights`, `manoeuvre-census`,
`test_manoeuvre_face_behind`, `scenario_cp2`, `native-verify-scenarios`. Build squad-facing fixes on stages that form
elements (lesson 1). Long remote runs under `systemd-run --user`. Every number: commit, machine, workload, n, its row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; the planner's `game/ai/planner/**` and plan source; brains'
`_track_progress`, `_update_phase`, `_approach_gate`, HOLD's return, the re-seat, elements, `game/tactics/**`,
`tank_brain.gd` beyond the granted decline; native's `native/**`; `game/tank/**`, `game/control/**`, `game/match/**`;
`tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### C33.9 attempt 2, DEV ONLY (R33.24; not judged, waiting on the lead; data in `references/round33/manoeuvre/c339-attempt2-dev/`)

builder0, pinned, dev seeds 11-23, n 13 a cell. Turn in ONLY within the gun's effective reach; out of reach, today's motion.
- **C `96d6a1521`** (branch `lab/c339-attempt2`): the reach rule alone. (a) in reach 24.6 % (FAIL by 0.4), (b) PASS, (c)
  exchange 0.18 -> 1.57 PASS, (c-out) hits 42 -> 49 FAIL. **Out of reach the shuffle is back:** (d) up to 203 commanded
  reverse ticks and 42 gear changes in a run, (d2) 20 at stop, (e) 75.6 m from the post. That is what he reported.
- **D `9fb3b9db6`**: C + catch-up gain 5 + the jink's slow half 0.3: worse, (a) 17.7 %, the exchange fails in one cell.
- Reading: attempt 2 trades the lead's own complaint back in for out-of-reach hits; the orchestrator's HANDOFF now
  recommends shipping attempt 1 (781801da0) as is and leaving out-of-reach to brains' fight-or-leave work.

### C33.9 JUDGED: PARKS (2026-10-18; data in `references/round33/manoeuvre/c339-judged/`)

**Candidate:** ea043755's turn-in, judged tree **781801da0** (branch `lab/c339-turnin`) = ea043755's game code + measurement only
(the stage's `damage_dealt`, the table's in-reach exchange). Chosen over 835da0875 (out-of-reach evasion): its only gain was
out-of-reach hits 53 -> 47 (OFF 42) and it cost in-reach (a) 25.7 -> 21.9 % on dev (law v gang 30 m 20.8 -> 14.9; gang v gang
15 m 37.9 -> 31.7). **Judged:** FRESH seeds 31-36, both arms, builder2 start to end, `--fixed-fps 30` a seed process, n 6 a
cell (288 rows), every seed exited 0. **Machine equivalence:** dev 11-23 OFF rows, builder2 v builder0 (both pinned): 312 of
312 identical (unpinned, builder0 paced v laptop: 0 of 19).

| line (the bar as ruled, workstreams.md main) | OFF | ON | verdict |
|---|---|---|---|
| (a) in-arc %, in-reach cells (gang 15 m; law 15, 30 m) | 3.7 | **23.9** | **FAIL** (>= 25) |
| (b) shots, every player cell | 2 | 10 | PASS |
| (c) exchange in reach, damage dealt / taken | 0.20 | 1.77 (no cell worse; hits 111 -> 104 reported) | PASS |
| (c-out) out-of-reach pooled hits / worst cell | 42 | 57 / +37 % gang v syn 45 m | **FAIL** |
| (d) commanded reverse / commanded gear changes, face | | 0 / 0 (72 runs) | PASS |
| (d2) reverse at stop | max 30 | 0 | PASS |
| (e) furthest from post | | 25.8 m | PASS |
| (g) free cells | | identical | PASS |

**Reading:** the shuffle is gone (no reverse chosen under a face or a HOLD, in any run), the scout stays by its post and fights:
4-5x the shots and 9x the damage exchange in reach. It misses on two lines: aim time in reach (23.9 v 25) and hits taken
out of its gun's reach (it faces a target it cannot hit). Out of reach is brains' question (stand or hang back), on the lead's
morning list. Not shipped: the bar is the gate.

### Overnight status (2026-10-18 ~02:00 PDT; for the lead's morning read)

**What you'll notice when these ship:** a lone scout (law or gang) circled by a faster enemy stops driving forward-and-back.
It rolls forward and turns in toward the attacker, changing speed as it goes, and it does the same while it holds its post
between looks. A War Rig, gang tank or IFV told to face a direction ends with its hull pointing there and sits still.

| Item | State |
|---|---|
| **C33.9 the scout** | **JUDGED: PARKS** ((a) 23.9 v 25; out-of-reach hits 42 -> 57), section above. Was: built on a scratch tree (main + 0ef2443b..., last commit **d7cf8cbf**), dev cells on builder2 under `--fixed-fps` running. Dev seeds 11-23 at 9456b4f3 (builder2, n 13 a cell): (e) PASS 23.6 m, (b) PASS, (g) PASS, (d) 0 commanded reverse in 156 runs; (a) 23.0 % (bar 25), (c) worst cell +53 % (gang_scout v syn_scout 45 m: it cannot shoot that far). d7cf8cbf adds the HOLD-shuffle hook (d2). Judged run 31-36 on builder2 when dev is clean. |
| **CP-F attempt 3** | R33.23: pair **pair/cpf3-on 60d2d86a** (+ the 3 m pulled-off give-up becb15d8, + the hull-rest pin 670f4e12). Full check and the tuning sanity (40-45) running on builder2; then the series 460-475 on builder2. |
| Hull-rest judge fixes | Queued after CP-F's series. |

**Found tonight (each traced, numbers below in the sections):**
- **CP-F's judged miss was mostly pacing:** hull-rest ran wall-clock paced on a loaded builder0. Under `--fixed-fps` (builder2,
  tuning seeds 40-45) the extra movers vanish (ambush 7 v 6 against the paced 51 v 35); `manoeuvre-hull-rest` is now pinned
  (670f4e12); earlier hull-rest numbers do not compare. One real loop left (support-by-fire: the face crept a gang tank off
  its seat, the dressing move pulled it back, every second): fixed by the 3 m give-up.
- **Why the scout was hit more:** the orbiter only fires once its turret's lay settles on a lead point. Today's creep
  shuffle keeps that from settling by accident (45 m: 42 enemy shots v 198 when the scout braked), so the turn-in jinks:
  it changes speed on uneven dwells (from the match tick and the hull's name: deterministic, tested in two fresh children).
- **The shuffle you saw lives under HOLD too:** at `stop`, gunnery's swing of a fixed gun with no throttle is the creep. Now
  it goes through the turn-in (OFF 8 v ON 0 reverse ticks at stop in the test).
- Bugs fixed in the turn-in on the way: a stall check that read a full lap as "no yaw"; a leash whose side flipped every
  tick with the post behind (31.5 m out); the jink's clock read the engine frame, not the match tick.

### Report (2026-10-17, CP-F judged: parks; C33.9 in development)

| Item | State |
|---|---|
| F0 the missing face step | **DONE: not a main bug** (no fix commit). A real main bug found on the way, in planner's file: stale `PlannerSeam.live()` (sent to planner + orchestrator) |
| F1 CP-F | **JUDGED: PARKS** (series on pair/cpf-on b6c2a974, builder0, 14/14 calls exited 0): misses (a) attack-move 69.5 % (needs 70), (b) wheels/fixed ambush p 0.042, (c) as written, **(d) movers on ambush / move / screen**, (e) move. Passes (f)–(l), (q). Verdict below; orchestrator rules |
| F2 help B11b | waiting on CP-F (parked) |
| Stretch clip | DONE (CP-F (r)): **`build/manoeuvre/face_clip_rigs.mp4`** (War Rigs, squad 1 alone, laptop, commit 8fc224fa) + the IFV clips; for his eye, not evidence |

### CP-F JUDGED SERIES: PARKS (2026-10-17; tables in `references/round33/manoeuvre/cpf-series/`)

Tree **pair/cpf-on `b6c2a974`** (switch ON), BASE the same tree with `--nav-off=turnhull`; GDScript arms (`M1_GD=1` /
`--brains-off=native`), builder0 heavy lane, one arm a call, 14/14 calls exited 0 (two builder0 drops on call 3, resumed;
`series-summary.txt`). (m)'s native arms: flagless pair/cpf-on v **pair/cpf-off `e5b767da`**. Hull-rest 440-445: 4
factions x 6 tasks x 6 seeds; runs read NEW drawn 143 / BASE drawn 141 / NEW clicked 143 / BASE clicked 140 of 144
(gangs runs wrote no row; pairs dropped). Paired lines at **1.645 se of the summed paired difference** (`tests/manoeuvre/cpf_judge.py`;
`hull_rest_ab.py`'s own M1_CLASS uses 2 se).

| line | reading (GDScript, n as stated) | verdict |
|---|---|---|
| (a) wheels/turret drawn point tasks | move 4.3 deg / 78.0 %; right 2.8 / 82.3 %; attack-move 6.0 / **69.5 %** (n 164 crews each; native 71.3 %) | **FAIL** by 0.5 pt (attack-move) |
| (b) every class, drawn, worse at p < 0.05 | **ambush wheels/fixed 3.9 v 2.6 deg, p 0.042** (p90 76 v 7); every other class/task better or p > 0.13 | **FAIL** (wheels fail as written, (o)) |
| (c) clicked wheels/turret within +-5 deg | move 47.7 v 47.7, screen 52.0 v 55.1 PASS; ambush -6.8, right -7.1, attack-move **+9.5**, SBF **+8.8** (all p >= 0.197, both signs) | **FAIL as written**: the +-5 deg line is under the clicked arm's run-to-run spread (my bar's error, reported, not tuned) |
| (d) crews moving at the judge, wt and all classes | ambush **+14 / +16** (lim 13.0 / 12.7); move **+13 / +11** (8.9 / 9.5); screen **+20 / +20** (15.7 / 15.5); attack-move +5, right +4/-2, SBF -10 PASS (n 23-24 paired runs) | **FAIL** on 3 of 6 tasks: attempt 2's line again |
| (e) never settled, runs with wheels/turret | move **+3** (lim 2.6); others within; settle medians 75 v 75 s on 5 tasks | **FAIL** (move) |
| (f) squads arrived, paired | 289 v 287 (140 pairs), diff +2, se 5.3 | PASS; re-seats NOT MEASURED (hull-rest rows carry no re-seat count) |
| (g) Terminus 450-462 arrivals | mixed 294 v 293 of 312 (+1, lim 7.8); rigs 181 v 186 of 208 (-5, lim 9.2) | PASS |
| (h) bridge-pooled | 18/18 both arms | PASS |
| (i) fights 470-493 (21 pairs) | kills 894 v 896 (se 25.6), deaths 902 v 899 (se 25.0), hit rate 0.703 v 0.685 (+0.018, se 0.017) | PASS |
| (j) counters, new drawn | hull_turns 113 355 (base 0); `hull_holds` is a Manoeuvre static never written to the census: **not read**; face_keep_refused 11 686 (by unit in counters.txt) | hull_turns PASS, hull_holds unmeasured |
| (l) SBF gang_ifv drawn 500-505 | 24/24 in both; hull error at in **2.3 v 34.0 deg** (>= 45: 0 v 9) | REPORTED |
| (m) native sign v GDScript | (a) agrees (move 3.3 v 62.6, right 3.3 v 92.7, attack-move 6.1 v 59.6); (d) agrees on ambush (+17/+21, FAIL) and attack-move all classes (+14, lim 12.8: FAIL natively); disagrees on move/screen (native +0/+2, +1/+1) | sign agrees on (a); (d) fails on both paths, on different tasks |
| (q) fire while the hull turns | fights shots 24 086 v 20 146, hits 16 684 v 13 091 (both outside 2 se, UP) | the turn does not cost fire |

**Reading.** The turn works where the bar aimed it: wheeled turret hulls on drawn point tasks end 3-6 deg off v 60-100
deg (both paths), the squad still arrives, Terminus/bridge/fights hold and the turret fires more. **What fails is the
settle**, the line attempt 2 failed: more crews are still moving at 75 s on ambush / move / screen. Who they are
(`hull_rest_moving.txt`, MOVING_KIND): ambush NEW drawn 55 moving = **39 driving a move > 8 m from its goal**, 11
pinned, 3 dressing, **2 face_legs, 0 face_creep**; BASE 35 = 28 driving, 7 pinned. So the extra movers are not hulls
still turning: they are crews sent a NEW seat after they faced (goal 8-28 m out at the judge), as on tuning seeds
40-45 before R33.9's latch. R33.9 latched `arrived`; something else still moves seats once the hulls turn (candidates:
the turn's own drift moving the element centre, or the drawn station (p) changing what the seat is laid by). Gangs and law
carry it (ambush 17/14 and 23/15, screen 23/10 and 17/8). **(b)**'s wheels/fixed tail (p90 76 v 7 deg on ambush) is a
fixed-gun crew the switch should not touch; not traced. **Next if the orchestrator wants a second attempt:** trace the
re-seat on one ambush run (gangs or law, a tuning seed 40-45) with seat-goal prints, NEW v BASE; no tuning on 440-445.

### F0: s66 faced_move traced on main (2026-10-17)

builder0, main `ae3dad71` (round-33 docs commit), `manoeuvre-hull-one` gangs seed 66 faced_move, n 1 a run, temporary prints
(not committed). **Native path, turnhull OFF (today's game):** Green_Guns_5 ends **109.1°** off, still (squadmates 0.2–172°).
Its move becomes `stop` at f≈360 with 12 m left and stays `stop`: the element's faced hold replaces its move (brains',
round 10's rule), and every face the brain sends it after that (`from` order / sector, and contact when the quiet enemy is
seen) is declined to `stop` by round 8's turret-carries-aim rule (`TankBrain._order_move` ~3487), because turnhull is OFF.
No face reaches the mover, so the seam never acts. **That is the design CP-F changes, not a lost step.** GDScript path the
same (104.9°).

**With turnhull ON** (`--nav-off=turnhull --brains-off=native`, 4 runs; hull-rest is not repeatable run to run): 176 hull
turns, but G5 still ends 44–126° off. Traced: (1) the seam plans G5's face (4–5 legs) and the legs start, then a face
`from: "contact"` (the quiet enemy seen at ~74 m) is declined to `stop` (turnhull lifts only order/sector), so the hull
STOPS MID-PLAN; when the contact drops it gets a new face and a new plan; (2) **stale seam crew (main bug, planner's
file):** once the order leaves face/kturn, `take`/`hold` are never called again, so the Crew is never released and
`PlannerSeam.live()` (no staleness check) reads true to the match end (G5 f≈500 → 2300+). While it does,
`Movement.unstick` returns early for that hull (movement.gd ~3080), `manoeuvring()` reads true, and the census is blind.
Proposed to planner: `live()` false past STALE_TICKS since `tick_seen`, with a test. **Planner's fix:** branch `fix/planner-live-stale` `03d1a50c`
(stale crews released once a tick before any controller runs; `tests/test_planner_seam_stale.gd`), check running; the
orchestrator ruled it R33.3 and will name the hash when it merges. No guard in `unstick` (agreed).

**Agreed with planner (C33.6 (c), 2026-10-17):** manoeuvre owns WHEN a faced finish turns the hull and the residual;
planner owns HOW only while `PlannerSeam.take()` holds the hull (rigs ≥ 10 m). CP-F's at-rest face goes through
`face_turn`, so the seam may take it.

### CP-F bar (DRAFT 2026-10-17, sent to the orchestrator before any number; base = main with R33.9's arrival latch)

**Candidate:** ONE switch `turnhull` (`Manoeuvre.TURN_HULL_DEFAULT`), as M1b(2) attempt 2 (the decline lifted for a
DRAWN face from `order` / `sector`; facekeep), **plus** round 33's `Manoeuvre.drawn_face`: a face still declined under it
(a contact the turret takes) keeps the hull on his drawn heading instead of `stop` (`hull_holds`). Both arms on the
GDScript path (`M1_GD=1`), one arm per remote call (lesson 311), base = the same tree with the switch at its default.
**Gate first (C31.1):** `make remote T=check` on the pair tree (= the R33.9 main + CP-F + `TURN_HULL_DEFAULT = true`),
whole suite green with `native-verify-scenarios` inside it; native states its pair (wheeled face orders go back to
GDScript, execute_native.cpp ~363). Sim-baselines may move (CPU elements' drawn task facings lift the decline too,
symmetric by his rule): the orchestrator adopts with that reason.
**Fresh seeds** (unused in rounds 28–33): hull-rest **440–445** (4 factions × 6 tasks × 6 = 144 runs an arm, drawn and
clicked), Terminus census **450–462** (13), fights **470–493** (24), SBF gang_ifv **500–505**, bridge-pooled's 18 cells.
Tuning only on 40–45 (and s66 for the trace).
| line | reads | rule |
|---|---|---|
| (a) | drawn POINT tasks (move, right, attack-move), wheels/turret at rest | per task median ≤ 15° AND ≥ 70 % within 15° |
| (b) | drawn LINE tasks (screen, ambush, SBF) and every hull class on every task, fixed-gun wheels included | no class median worse than base at permutation p < 0.05 |
| (c) | clicked arm, wheels/turret | median within ±5° of base (the lift is drawn-only) |
| (d) | crews still moving at the judge, per task, wheels/turret AND all classes | ≤ base + 1.645 se (C31.3's form) — **attempt 2's failed line** |
| (e) | never settled (75 s), per task | ≤ base + 1.645 se; settle time paired median REPORTED |
| (f) | R32.3 (a): arrived = within ARRIVED_M 7 m of the held seat at completion; re-seats | arrivals not down beyond 1.645 se paired; re-seats ≤ base + 1.645 se (FAIL line) |
| (g) | Terminus arrivals, rigs and mixed apart | not down beyond 1.645 se paired (`sequential.py arrived:guard:0.10`, no early stop before 6 seeds) — attempt 2's other failed line |
| (h) | bridge-pooled | 18/18 |
| (i) | fights 470–493: kills, deaths, hit rate per team | within 1.645 se (GATE, R31's (j)) |
| (j) | counters in the new arm | `hull_turns` > 0 and `hull_holds` > 0 (lesson 300); `face_keep_refused` by unit REPORTED |
| (k) | the named case hull-rest gangs s66 faced_move Green_Guns_5, 3 runs | REPORTED (B11b's pass case judges on CP-F + B11b) |
| (l) | SBF gang_ifv drawn 500–505 | REPORTED |
**FILED on main with the orchestrator's amendments (2026-10-17):** (m) the DEFAULT path: native mirrors whatever CP-F
reaches in the drive, twins at 0 as a gate, and the arms run on the default (native) path; if only a GDScript series is
affordable, one hull-rest drawn seed set on the native path must agree with it in sign on (a) and (d). (n) Fights 470–493
run wholly before R33.6 merges, or with it in both arms. (o) In (b) a lone p < 0.05 in a class CP-F does not touch
(tracks, hover) is traced before it fails the series and reported either way; wheels (fixed or turret) fail as written.
(p) The station gap is closed INSIDE CP-F (orchestrator, main 76656f29): GRANTED one additive field in
`game/control/orders.gd::_remember_station`, `"drawn"` (the order named a facing AND its source is "player"; an
element's sector facing is not his), read by `Manoeuvre.drawn_direction` under the same switch, only when no order is
current. **Merge note: control's file, one field, additive.** It rides CP-F's series, no separate bar. (q) REPORTED:
turret shots in the first 20 s of a contact while the hull turns (test: ON 1 v OFF 5, n 1). Line (i)'s hit rate judges
it; fights showing the turn costing fire is a reason to FAIL, not to tune.
Base = the R33.9 main (hash from the orchestrator). **Native's statement (2026-10-17, read on `136c3828`): no C++ change.**
`_order_move` and its decline are not in C++; N5.M reads none of TURN_HULL_DEFAULT / facekeep; no Movement members added.
Every face CP-F creates is a WHEELED one (`turret_carries_aim` is wheels + turret only), handed back to GDScript by
execute_native (~363). The pair tree's plain check (switch ON) runs the native twins: that is the proof.
**Partial:** (a)–(j) are the gate; any miss = parked with the trace. Ships ON as a pair if it holds; brains is told the
merge hash the day it lands (B11b).

### F1: what attempt 2's attack-move line was (tuning, not judged; 2026-10-17)

builder0, code = main `ae3dad71` (census coordinates added for the second table), GDScript (`M1_GD=1`), drawn
faced_attack_move, seeds **40–45** (tuning; the judged seeds will be fresh), one arm per call.

| reading | base | turnhull ON |
|---|---|---|
| crews still moving at the judge, 4 factions (n 24 runs an arm) | 27 | 44 (wheels/turret 22 v 39) |
| of which gangs (n 6 / 5 runs: turnhull's gangs s45 wrote no row) | 22 | 36 |
| wheels/turret median hull error, gangs runs | 42–76° | 4–6° (s41 114°) |
| moves re-sent to a crew that had faced, 4 factions | 43 | 129 |
| gangs re-run with coordinates (n 6 an arm): moving / re-sends | 25 / 15 | 39 / 155 |
| ...re-sends whose SEAT moved > 2 m | 10 | 106 (median 10.0 m) |
| ...the hull's drift during its face, median | 7.1 m | 1.8 m |

**Reading:** the turn keeps the hull where it stood (facekeep works); what keeps the crews moving is that their SEATS
move after they have faced, several crews of one squad on the same frame (Battery: 4 crews 15–49 m at once, repeatedly).
**Candidate mechanism (being traced):** a faced attack-move lays its seats by the drawn facing only while
`center.distance_to(destination) <= ARRIVE_M` (12 m, `element_plan.gd` ~289, no hysteresis); the members' face legs
move the centre, and if it crosses 12 m every seat switches between the arrival shape and the travelling one. The
orchestrator's alternative (R32.3 (c), the averaged-heading halt) needs no drawn facing, which this task has.
**CONFIRMED, and it is a MAIN bug (brains' file), not turnhull's** (builder0 light, `97bcd952` + a temporary goal print,
gangs s40, GDScript, n 1 an arm; rows + diff in `references/round33/manoeuvre/f1-arrived-flip/`): the Battery element
(14 crews, swarm) flips `arrived` every 0.5–3 s from t≈15 s to the end on the SAME anchor; arrived lays the seats on his
drawn heading (0.50, −0.87), not-arrived on ≈(0.2, 0.97); each seat jumps 19–27 m per flip. Flips base 67 v turnhull 59
(Hunters 17 v 5); reseat goal moves 286 v 234. So turnhull does not cause the attack-move movers: it catches more crews
mid-turn at the judge. (My "re-sent after a face" count above is biased: base declines wheeled turret faces to `stop`, so
its crews rarely "face" before a re-send.) Sent to the orchestrator to broker with brains: latch arrival per task (leave
only past ARRIVE_M + a margin), a test on a 14-crew swarm attack-move; CP-F's bar then judges on a tree with it.

**Native (2026-10-17):** N5.M (stream/native `145ada3a`) ports `_manoeuvre`'s decision: C26.2 now covers
`Manoeuvre.choose / behind / simulate / _others / _hull_hit / _note`, `TankMotion.state_of`, `_outline_offs` and the
constants MAX_M, BEHIND_DEG, FACING_KEEP_DEG, SIM_*, CHECK_EVERY, HULL_MARGIN_M, REAIM_TICKS, KTURN_MARGIN_M,
CUSP_DEADBAND (values are handed over live). `plan_face` / `face_turn` / facekeep stay GDScript.

### CP-F's contact-face test (light lane, builder0, branch tip after 129e4c48 on main ae3dad71, GDScript, n 1 per arm)

`test_manoeuvre_turn_hull::test_a_declined_contact_face_keeps_the_hull_on_his_drawn_heading`: a gang_tank in a
one-crew real `Elements` element, task `move` with drawn facing (1,0), starting about 130 deg off, a durable contact
30 m north. ON: 133 declined faces, all 133 held on his heading, 600/600 drawn-face ticks, ends **4.6 deg** off, 1
shot. OFF (round 8): 134 declined to stop, ends **49.9 deg** off, 5 shots. The turret still fights ON but fires less
during the 20 s while the hull comes round (1 v 5, n 1, unjudged); the fights rows of the series will say if that costs.
The first two stagings were wrong (a K1 move/attack-move onto its own spot completes at once, leaving nothing
drawn: ON == OFF); quick-remote at 136c3828 showed that as 76 passed, 1 failed.

**The K1-completed gap** (a plain move with a drawn facing completes; then a contact) is now CP-F's: amendment (p). Its test,
`test_after_a_plain_move_with_a_drawn_facing_completes_a_contact_keeps_the_hull_on_it` (light lane, builder0, on main
ae3dad71, GDScript, n 1 per arm): the move completes and its station is `drawn`; ON 117/117 declined faces held, ends
**4.2 deg** off, 1 shot; OFF 598/600 stop ticks, ends **49.9 deg** off, 5 shots. `test_an_elements_own_facing_is_not_a_drawn_station`
pins the player-only rule. quick (light lane) on turn_hull + control_orders + wheeled_face: 18 passed, 0 failed.

### CP-F pair tree (C31.1) — GREEN `887ac6d2` (branch `pair/cpf-on`, 2026-10-17)

`pair/cpf-on 887ac6d2` = main 227d0bb6 + R33.9's latch 429ebc4b (green on lab/brains-r339, not yet merged) +
stream/manoeuvre e5c66718 + `TURN_HULL_DEFAULT := true`. **`make remote T=check` on builder0 exited 0, 2735 passed, 0
failed, sim-baseline unmoved on all 13 maps** (the whole suite with the switch ON). Native's twins on 887ac6d2 (builder0
light lane, `make native test FILTER=native_drive|native_execute|native_face_behind` exited 0, 9/0, n 1): 0 mismatches
everywhere; War Rig face_behind 928 handed back, tank 142 native / 2 handed back; no C++ change (stations' `drawn` is
never read natively). The orchestrator: these settle bar line (m). **The series waits for R33.9's verdict:** if it passes,
the base matches main; if it PARKS, rebuild the pair tree on main without it and the orchestrator rules on (d).

### Stretch: the War Rig clip (laptop flightdeck, commit 8fc224fa, 2026-10-17; for his eye, NOT evidence)

`make manoeuvre-face-clip FACE_CLIP_SEED=8 FACE_CLIP_SQUADS=1` (`--faced-squads`, granted under (r), default 1,2
unchanged, tested) -> **`build/manoeuvre/face_clip_rigs.mp4`**, 30 s at 2x: squad 1 alone (five War Rigs), his right-drag
180 deg off the travel. Windowed, n 1 per arm: BEFORE all 5 told, hulls [0, 8, 170, 179, 10] deg off his heading (settled
37.5 s); **AFTER [0, 7, 6, 1, 4]** (settled 54.5 s). Headless on the laptop preset the same probe ends AFTER [141, 4, 2, 7,
162] still moving at the 75 s cap: a War Rig's turn behind is slow and n 1 says only that.
**Corrections to the entry below:** (1) the War Rigs did NOT jam: their MANOEUVRE_STATE rows are never `blocked`, all
five do 9-12 m/s by ~8 s; the YIELDING/BLOCKED labels on screen are other units at the start. They stop 20-45 m from the
spot and Guns_4 drives on to ~52 s, so the squad never read `arrived`. (2) `--seed` DOES reach the windowed run; seeds 5
and 8 are identical because of the LAPTOP render preset (headless `--render-preset=laptop`: identical too; desktop:
they differ): the capped faction army is the same and nothing in this probe then depends on the seed.

**Handed to brains (round-34 candidate, not manoeuvre's):** why the War Rig squad never reads `arrived` (laptop,
windowed, 86447a3e, foundry s8, both squads, n 1). The element's anchor = its task "to" (28.2, 116), 22.6 m off his drawn
spot (orders' share of a 2-squad order). The swarm laid 5 seats as a file through it at z=116; 3 were grounded 6 m (in
`slots_asked`), and 2 were pushed 28 m and 56-68 m south with NO `slots_asked` entry, so the centre can never come within
12 m. Read with a temporary print in element.gd, reverted. Details are in the messages to brains.

### Stretch: the face-behind clip (laptop flightdeck, commit 77348a53, 2026-10-17; for his eye, NOT evidence)

`make manoeuvre-face-clip` (CP-F (r), granted: `--faced-off-deg` in screen_playtest.gd, default 60 unchanged, test
`test_manoeuvre_face_clip`, laptop 1/0) films his faced right-drag drawn 180 deg off the travel on gangs, BEFORE (today)
v AFTER (`--nav-off=turnhull`), both GDScript, side by side at 2x: `build/manoeuvre/face_clip_s8.mp4` (FACE_CLIP_SEED=8)
and `build/manoeuvre/face_clip.mp4` (seed 5), 27 s each. **What it shows:** the five gang_ifv (wheeled turret) crews
arrive and stand 99-156 deg off his heading BEFORE (one 16), **2-3 deg AFTER**. **What it does not show:** the War Rigs
(Guns): in the WINDOWED run they jam at the start (YIELDING / BLOCKED labels) in both arms and never reach the spot inside
the probe's window (crews_told 0), and the windowed runs come out identical on seeds 5 and 8 (the flags carry the seed;
not traced, a filming quirk, not CP-F). Headless on the same commit and flags (n 1 per arm) the War Rigs do arrive:
seed 8's first Guns squad, told 5/5, hulls **82-151 deg BEFORE v 1-8 deg AFTER**; seeds 3, 11, 13 agree on every squad
that arrives (before: most crews 100-180 deg off; after: most under 10, a few 105-149 off).

### CP-F judged series: the plan (2026-10-17; starts when the orchestrator says main's check has read)

Tree: **pair/cpf-on `b6c2a974`** = 887ac6d2 + main e420b524 (R33.9 merged as 9396e795): `merge_check_needed.sh` INHERIT
from 887ac6d2's green check (docs only). The (r) clip commits are left out (default runs byte-unchanged; they ride the
ship merge's own check). One builder0 call at a time, one arm a call, in this order. Fights FIRST, because R33.6 is
unmerged (n).
GDScript arms through `manoeuvre-cph` / `manoeuvre-hull-rest M1_GD=1`: NEW = the tree's default (switch ON), BASE =
`--nav-off=turnhull` (flips it OFF). Fights 470-493 (i), hull-rest 440-445 drawn and clicked (a)-(f) and (j), Terminus
census 450-462 (g), SBF gang_ifv 500-505 (l), bridge-pooled 18 cells (h). **(m), native path:** hull-rest drawn
440-445 run flagless on pair/cpf-on (NEW) v **pair/cpf-off `e5b767da`** (= b6c2a974 with TURN_HULL_DEFAULT false, BASE),
agreeing in sign with the GDScript series on (a) and (d). (k) gangs s66 faced_move x3 on the light lane, REPORTED.
Driver: a scratchpad script; the per-arm data is filed under references/round33/manoeuvre/cpf-series/ when read.

### Plan (ordered)

1. F0 trace (done above).
2. F1: on tuning seeds (not judged ones), trace turnhull's attack-move crews still moving at 75 s; first suspect: the
   contact decline cutting a hull turn mid-plan and the sector face restarting it (churn). Fix under the one switch, test
   first; then the bar to the orchestrator before numbers; C31.1 suite with TURN_HULL_DEFAULT true on the pair tree; the
   judged series on fresh seeds; ship ON as a pair; tell brains the hash.
   - R33.10 (orchestrator): one heavy builder0 job per stream at a time; priority merge-hash checks > judged series >
     tuning (light lane or laptop). CP-F's series runs after parkedroom's and R33.9's.
   - R33.11 (orchestrator, main 54edea83): traffic may edit the setup lines of tests/test_nav_yield_fit.gd's two
     fixed-set give-way tests (pins parkedroom OFF). Nothing for manoeuvre to do; don't revert those lines.
3. F2: answer B11b.
4. Stretch: the War Rig face-behind clip.

### Decisions

- F0 gets no fix commit: the decline is round 8's deliberate rule, and the brief's "if it is a bug" is answered no.

