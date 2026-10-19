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

## How to verify

Tests first; `make quick-remote`; one full check at a time on builder0; series pinned, fresh seeds, no random twins
(`tools/judge/seed_twins.py`). Every number: commit, machine, workload, n.

## Don't touch

Traffic's give-way block, brains' tactics/ai outside your carve-outs, `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

**M0, the scout turn-in (R34.10, 2026-10-19):** by the bar it does not ship ((c-out)'s pooled median 60 is above the 57 he
accepted; every other line passes). It goes to him with the orchestrator's and my recommendation to SHIP, in the player
terms under *M0 JUDGED* in Status. Pair `pair/c339-r34` c8fb8b6a3 is FROZEN and ready; on his yes the orchestrator merges
it and adopts sim-baseline's three maps. What he would notice: his circled scout turns and fights (74 % of the time with
the attacker in its sights, 10× the shots, fewer hits in reach); where the attacker's gun outranges its own it turns in
and often closes to fight instead of dodging, taking 60 hits a run against 46 today and 57 accepted, and dealing 1.45
per damage taken there (was 0.06).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### M0 JUDGED (2026-10-19 ~03:40 PDT): PASSES every line but (c-out); (c-out) misses as written and sits 3 hits (+1.0 sd) over what he accepted — the lead's call (R34.1)

**Pair `pair/c339-r34` c8fb8b6a3** = stream/manoeuvre 764ef5427 (the turn-in) + `pair/native-c339` 25fd4298e (native's stop
hand-back). **Check green:** builder2, `make native check exited 2`, 2818/0 tests, 26 of 27 targets, twins 0 mismatches,
the only FAIL sim-baseline (crossing, parade, archipelago MOVED; attributed to the turn-in: the same tree with
`--nav-off=turnin` reproduces main's 13 lines, tsv filed). **Series:** builder2 start to end, FRESH seeds 101–112, n 12 a
cell, 576 rows, both arms GDScript, each seed its own `--fixed-fps 30` process; rows and table under
`references/round34/manoeuvre/m0-series/`. Every line as filed (Bar M0, R34.1), k = 1.645:

| line | OFF | ON | noise | verdict |
|---|---|---|---|---|
| (a) in-arc median, in-reach cells | 3.1 % | **74.2 %** | sd_boot 4.6 (90 % 66–80) | PASS (≥ 2× and ≥ 25); +10.9 sd over the accepted 23.9 |
| (b) shots median, player cells | 1 | **10** | — | PASS (≥ 1.5×) |
| (c) exchange pooled in reach (dealt / taken) | 0.13 | **2.34** | gain 2.22, sd_boot 0.14, gain − k·sd 1.98 | PASS |
| (c) guard: in-reach hits taken, totals | 8088 | **5690** (−2398) | se 219, k·se 360 | PASS |
| (c) guard: damage taken a run, each in-reach cell | — | −38 … −280 a run in all six | k·se 16–74 | PASS (all six) |
| (c-out) hits out of reach: totals / pooled median / worst cell | 3139 / 46 / — | 4627 (+1488) / **60** / +10 % (gang_scout v syn_scout 45 m) | k·se 437; median sd_boot 3.3 | **FAIL as written** (totals); worst cell ≤ 20 % passes. **V accepted (57, +37 %): 60 v 57 = +1.0 sd WORSE on the pooled median; worst cell well inside** |
| (d) reverse under a reverse command / commanded gear changes, face | — | **0 / 0** in 144 runs | deterministic | PASS |
| (d2) reverse at stop | max 48 (median 6) | **0** in 144 runs | deterministic | PASS |
| (e) furthest from post | — | **26.0 m** | deterministic | PASS (≤ 29) |
| (g) free cells | byte-identical arms | | | PASS |
| (h) report | holds median 0 (hold ticks fire in 2 % of runs), stalls 0; mean distance 26.4 → 20.8 m | | | |

**In player terms, for the lead.** The scout you saw shuffling forward and back now turns and fights: in every one of
144 runs it never once chose reverse under a face or at a stop (OFF reversed up to 48 ticks a run at stop). Where its gun
reaches it has the attacker in its sights 74 % of the time (was 3 %), fires 10× as often, deals 10× the damage it takes
(was 0.13), and takes fewer hits in every one of the six cells (−25 % overall). **The one miss is out of its gun's reach**
(an attacker circling at 30–45 m where only the attacker's gun reaches): it now turns to face and often closes in to
fight instead of dodging, and over those six cells it takes 60 hits a run against 46 today, and against the 57 you
accepted in round 33 (+1.0 sd of the measurement). What it buys there: it now deals 1.45 damage per damage taken out of
reach (was 0.06): a gang scout circled by an IFV at 30 m kills it in 5 of 12 runs (dealt 854 v 47 a run, hits taken 91 v
95), and a law scout under an IFV at 45 m deals 186 (was 8) while taking 54 hits (was 0, it was never in the fight). The
worst cell for hits is the gang scout under a syn scout at 45 m, +10 % (48 v 44), a fight it cannot win (dealt 3).
**My recommendation: ship it.** The shuffle is gone everywhere, the in-reach fight is won, and out of reach the extra hits
buy kills; whether a scout should instead LEAVE an attacker it can't outgun is brains' C34.5, now on main, and the two
compose (brains' rule decides whether to stand; mine decides how a standing scout turns). **The merge candidate, if he
says yes: the pair c8fb8b6a3 (code = stream/manoeuvre 764ef5427 + pair/native-c339 25fd4298e), green as above; main's
sim-baseline is then adopted at the three attributed hashes.** Later stream commits are docs, references and the table
script's R34.1 block only.

**Process (2026-10-19 ~06:50 PDT):** two of my detached (`setsid nohup`) check wrappers died mid-run with no wrapper exit
line (M2 on builder2 at 0d0f22027 read "27 targets, all passed, 2829/0" in its own summary; M2 on builder0 stopped at 18
min; CP-F 4's step 2 wrapper died 6 min in) while the remote makes ran on as orphans (killed by cwd, nothing else
touched). Neither M2 run is named from those logs. Both the M2 check (builder0) and the CP-F 4 series (resumed from step
2; step 1's wrapper line is in its summary) now run under `systemd-run --user` as the brief orders; orientation trip-up 86.

### Round-34 close-out (manoeuvre, 2026-10-19 ~10:00 PDT; branch stream/manoeuvre with main 165953b64 merged at ed353a1df)

**Shipped this round:** M1 the hull-rest ruler (lab/m1-ruler 6c54f4e66, main f97e5fdb1); M2 the k-turn arrival flicker
(lab/m2-arriveleg 0d0f22027, main 75a1d8c51). **Judged, not shipped:** M0 the scout turn-in (pair c8fb8b6a3, R34.10:
to the lead), M3 CP-F attempt 4 (R34.18: parks). **Done:** the War Rig clip (stretch). **Running:** the M2 before/after
report on main (builder0; result appended below when it lands).

**M2 before/after report (DONE, `references/round34/manoeuvre/m2-report/`, builder0, main c4aa9e2e0 then stream
b33b12fec/34f363b03 = main 165953b64 + the unshipped turn-in):** `--nav-off=arriveleg` v main over 288 drawn runs (all
factions), 144 gangs drawn+clicked runs under planner's flags, and planner's s69 stage (keep 1, clicked attack-move 66–71):
**every row identical** — (d), (e), settle, planner's face episodes, the short face spells — and the hold fired 3 times in
144 runs (one tick each; seed 66 clicked attack-move, under keep 0 and keep 1 alike), so nothing else moved and the mid-leg
arrival is rare on this stage. Planner's s69 shape is not on today's stage in either arm (the ruler moved the seeds).
Trap found and written on `M1_GDD`: under `--brains-off=native` the seam abandons every k-turn ask (driven 0), so a
hull-rest pass with M1_GD=1 cannot see the seam's legs at all; planner's `--brains-off=native_drive` is the flag.

**Open with the lead (M0):** the scout turn-in passes every bar line but (c-out): out of reach of its own gun it now trades
1.45 damage per damage taken instead of 0.06 and kills the IFV at 30 m in 5 of 12 runs, taking 60 hits instead of 46
(pooled median; the accepted margin was 57). Recommendation stands: SHIP; it is a stronger scout, not a reckless one. The
pair stays frozen until he says.

**CP-F for round 35 (a fifth needs a new design, R34.18):** the hull turn is right (point tasks 3–4° v 50°); what misses is
the stage settling. Two designs, one each side of the seam: (1) manoeuvre: a face no plan fits must give up cleanly —
after N refused plans the hull stops and the face is declared done-as-is (today it creeps at the 0.35 lock to the judge:
face_creep at the judge screen 8 v 0, attack-move 4 v 0); (2) brains: the element's step to its next attack-move leg must
not wait on a `face from sector` (law/faced_attack_move-614 stepped at t 60 v t 32 with the same laggard in both arms).
Both filed before any number; the bar re-uses Bar M3 with the A/A noise. Terminus mixed's −5 arrivals (one a seed in five
of thirteen) gets a trace in the design, not a re-run.

**Traffic's wedged deaths, a candidate item (measurement only, `references/round34/manoeuvre/wedged-deaths/`):** from
T5's 5984 rows, 499 (8.3 %, 3.5 a fight) died `stuck:wedged`: mid-weight hulls (IFV, tank, suppressor, burner 13–16 % of
their deaths; scouts 2–3 %), in lane mouths at the enemy (Locks 10 %, the x ≈ 0 column holds 57 of 195), 85 % under fire,
moving at walking pace (median 1.2 m/s, 58 % ≥ 0.5 m/s, only 17 % still ≥ 1 s). Unstick's stall rule can have been
counting on at most a quarter of them (under 0.8 m/s); the rest it never sees. The round-35 candidate: `wedged` as a
second unstick trigger, bar first (a back-off under fire is the question).

**The stream branch's own check (252380fda, builder2, `make native check exited 2`, 2872/1):** the one red test is
`test_manoeuvre_orbit::test_a_scout_at_stop_does_not_shuffle_under_turn_in` (ON 29 reverse ticks, 0 swings turned in) and
sim-baseline moved on yard/terminus/crossing/locks/gorge/cut. Both are the known shape of M0 WITHOUT native's stop hand-back:
on the native path the stop swing never reaches `_stop_turn_in`, so the creep shuffles as before; the same test on the
laptop's GDScript path passes (ON 0 reverse, 104 swings turned in, 7/7), and on the pair c8fb8b6a3 (stream + pair/native-c339
2f9ad0fb9) builder2 read 2818/0 with the twins at 0. So stream/manoeuvre alone is not a candidate and never was: M0's
candidate is the pair, frozen (R34.10). If he says SHIP, the pair is re-cut on current main and its check re-run there
(six baselines move on today's main v three on the pair's base; attribution as before via sim-variants --nav-off=turnin).
Commits after 252380fda are docs and one additive Makefile variable (M1_GDD, b33b12fec).

**What a fresh agent needs:** worktrees godot-manoeuvre (this), -pair (c8fb8b6a3, frozen), -m1 (merged), -m2 (now detached
on main for the report), -cpf4 (e76f6dab6, parked); raw runs in ~/overnight-manoeuvre; long runs under systemd-run with
`--setenv=PATH="$PATH"` (orientation 86); the clicked faces never reach the hull turn (`hull_turns` 0 in the clicked arms) —
a fifth design should say whether that is intended.

### CP-F attempt 4 JUDGED (2026-10-19 ~09:00 PDT): PARKS on (d), (e), (g) — the hull turn works, the stage does not settle

Series on `lab/cpf4` e76f6dab6, builder2 start to end, 14/14 steps exited 0, fresh seeds as filed; every reader's output
and the trace in `references/round34/manoeuvre/cpf4-series/` (README has the full table). In his terms: a wheeled turret
crew told a drawn facing now ends facing it (point tasks median 3.0–4.0° v 47–57° today, 82–94 % within 15° v 14–24 %;
ambush and support-by-fire 3.7° v 80° and 78°), every other class unchanged, fights/bridge/arrivals unchanged, the native
path agrees in sign. But more crews are still moving when the stage judges at 75 s — ambush 8 v 1, move 14 v 5, screen
23 v 10 (guards +3.2 / +6.7 / +5.4) — attack-move never settles in 20 runs v 14, and Terminus mixed squads lose one arrival
in five of thirteen seeds (285 v 290, −5, 1.645 se 4.6). Two mechanisms traced: faces no plan fits creep to the judge
(face_creep at the judge: screen 8 v 0, attack-move 4 v 0), and attack-move elements step to their next leg ~30 s later when
their crews sit on a `face from sector` instead of a `stop` (7 of 26 pairs ≥ 10 s later), so legs 2–3 run past the judge.
**By R33.34's clause this was the last re-run: a fifth attempt needs a new design** (a face that gives up cleanly when no
plan fits, and the element step not waiting on a sector face), not a seed change. Not shipped; brains keeps B11b on the
seam as is (no merge hash). The clip below stays mechanism-only.

### Stretch: the War Rig face-behind clip is CUT (2026-10-19 ~08:30 PDT, laptop)

`references/round34/manoeuvre/face-clip/` (4 MB mp4, frames, both SCREEN rows, README): lab/cpf4 e76f6dab6, gangs
faced_right 180° seed 5, before (`--nav-off=turnhull`) v after (the tree's default) side by side at 2x. Before: the ten
hulls rest 134–174° off the arrow (two IFVs 62°/16.5°), faced_ok false. After: 0.9–7.2° off, all still, faced_ok true,
settled 34.5 s. Mechanism only (laptop); whether he sees it ships with CP-F 4's verdict. Note for the target: on a tree
where TURN_HULL_DEFAULT is true the arms must be passed the other way round (its own comment says so; my first cut had
them swapped, the labels inverted; re-cut).

### M1 the ruler is GREEN: merge here `lab/m1-ruler` 6c54f4e66 (2026-10-19 ~06:30 PDT)

builder2, `make native check exited 0`, 2831 passed 0 failed, 27 targets ALL JUDGED, sim-baseline unmoved (no behaviour
change: CP-F's code rides with its switch OFF). It carries: round33/manoeuvre's CP-F attempt-3 code (default OFF) and judge
fixes (HULL_JITTER_DEG, `--wedged`, `--distinct`, manoeuvre-hull-seeds-differ); 1B `real_mps`/`mps` on every hull-rest crew
row; 2B `--faced-shift-m` (hull-rest passes HULL_SHIFT_M=6); cpf_judge reads still by real velocity, wedged apart;
`tests/manoeuvre/hull_rest_aa.py`; tests test_manoeuvre_ruler, test_manoeuvre_turn_hull. **Merge notes (shared files,
all granted):** `game/control/screen_playtest.gd` additive (1B/2B, control has no stream); `game/control/orders.gd` one
additive field (`drawn`, CP-F (p)); `game/ai/tank_brain.gd` the C31.8 decline (4 lines); `game/ai/manoeuvre_census.gd`
counters; `mk/manoeuvre.mk` targets and HULL_SHIFT_M. Numbers from hull-rest before this do not compare with after.

### CP-F attempt 4: gate green, series RELEASED (2026-10-19 ~05:40 PDT)

lab/cpf4 e76f6dab6's C31.1 `native check` on builder2: 2815 passed, 0 failed, twins 0 mismatches, sim-baseline UNMOVED
(the switch lifts the decline for drawn facings only), 24 of 27 targets; net-smoke (one client saw 1 of 2 tanks under
load) and remote-guard-test (the shared-box flake) were red in the check and GREEN re-run alone in the same folder
(`make net-smoke remote-guard-test exited 0`). Bar M3 is recorded on main. The 14-step series (attempt 3's shape) runs on
builder2 from godot-manoeuvre-cpf4 (the native base arm from godot-manoeuvre-m1), results to
`/home/slobdell/overnight-manoeuvre/r34_cpf4_series_e76f6dab6/`, then `references/round34/manoeuvre/cpf4-series/`.
### M2 the k-turn arrival flicker is GREEN: merge here `lab/m2-arriveleg` 0d0f22027 (2026-10-19 ~08:10 PDT)

builder0 under systemd-run, `>> remote: make native check exited 2`: 2829 passed 0 failed, 25/26 targets green,
sim-baseline unmoved, native-verify-scenarios 52/0 with 0 mismatches; the one red, web-smoke, is builder0's pre-N6
WebGL2/Xwayland-auth failure (HANDOFF, main 71bd4e466's case; native's N6 on main since c9dea4337 fixes it, my tree
predates it). Cleared on the laptop: `make web-smoke exited 0` at 0d0f22027 (WEB SMOKE PASSED, TANK_SQUAD_READY 8.9 s, no
console error, export-guard 0 disagreements over 905 files, WEB MATCH SMOKE PASSED; screenshot looked at). The
orchestrator agreed to this reading before the laptop run. Named to the orchestrator; planner's P5 waits on the merge.
Re-cut on main ≥ 2c7c1d0dc (C34.6's concern): the hold is keyed by the Movement INSTANCE, dead movers pruned, a test runs
two matches in one process with the same crew name (4/4 laptop, 74/0 builder0 quick). Paths: game/ai/manoeuvre.gd,
game/ai/movement.gd (new_order → arrive_hold_forget; OFF_NAMES "arriveleg"), tests/test_manoeuvre_arrive_leg.gd; no
native change. Logs: ~/overnight-manoeuvre/r34_m2_check4_0d0f22027.log, r34_m2_websmoke_laptop_0d0f22027.log.

**Native's pin-moves (C34.8 (a), relayed 2026-10-19):** hull-rest-probe reads differently pinned v free (drawn ALL median
10.3° pinned v 8.7/7.2° free; tracks/turret drawn worst 59.7° pinned v 3.3/4.8° free; faced_ambush facing-probe 75.2° v
86.8/70.7°). CP-F attempt 3 (R33.34) and attempt 4 are both pinned, and the new ruler (jitter + shift) changes the stage
again, so attempt 4's rows are read against their own base arm only, never against attempt 3's. If a tracks/turret crew
lands near 60° in attempt 4's rows, it gets one trace before the verdict.

### M1 A/A read (2026-10-19 ~05:00 PDT; builder2, lab/m1-ruler e28ba432d, native path, the OFF arm on seeds 201–209 v 210–218: 4 factions × 9 × 6 tasks a set, 36 pairs a task; `references/round34/manoeuvre/m1-aa/`)

The new ruler's noise, per task (A total, B total; paired sd a run; se of the summed difference over 36 pairs; the swing):
| task | moving (by `still`) | moving_real (by `real_mps`) | wedged (reported moving, made < 0.3) | settle s (sum, sd/run) | wt error med (sum of run medians, 21 pairs, sd/run) |
|---|---|---|---|---|---|
| ambush | 6 v 3, sd 0.65, se 3.9 | 1 v 1, sd 0.24, se 1.4 | 5 v 2, sd 0.50 | 1143 v 1167, 20.0 | 1923 v 1796, 35 |
| attack-move | 23 v 11, sd 1.41, se 8.5 | 12 v 5, sd 1.17, se 7.0 | 11 v 6, sd 0.80 | 1625 v 1570, 31.5 | 1106 v 832, 23 |
| move | 5 v 10, sd 0.68, se 4.1 | 3 v 4, sd 0.51, se 3.0 | 2 v 6, sd 0.46 | 1315 v 1476, 27.7 | 1152 v 747, 27 |
| right | 17 v 11, sd 0.77, se 4.6 | 11 v 3, sd 0.64, se 3.8 | 6 v 8, sd 0.63 | 1608 v 1533, 27.7 | 1210 v 825, 41 |
| screen | 10 v 6, sd 0.71, se 4.2 | 3 v 1, sd 0.41, se 2.5 | 7 v 5, sd 0.53 | 1608 v 1535, 20.9 | 1031 v 658, 21 |
| support by fire | 9 v 5, sd 0.62, se 3.7 | 2 v 0, sd 0.23, se 1.4 | 7 v 5, sd 0.58 | 1198 v 1224, 21.4 | 2241 v 2427, 45 |
**Reading:** about half of the old ruler's "crews still moving at the judge" were WEDGED hulls (reported moving, made
nothing): the old (d) line judged the stage's wedges, not the candidate. By `real_mps` the movers are 0–12 a task over 36
runs with a paired sd of 0.23–1.17 a run; the A/A swing of the totals is 0–200 %, so a fixed "+N" guard is meaningless
and the guard must be `base + 1.645 × sd_run × √pairs` (attack-move at 64 pairs: +15.4; right +8.4; move +6.7; screen
+5.4; ambush +3.2; SBF +3.0). The per-run median hull error of wheels/turret crews swings 28–44 % between seed sets on
four tasks (sd 20–45° a run): (a) stays on the pooled crews, never on run medians. Settle sums swing 2–12 % (sd 20–31 s a
run). **For planner's `judging.md` table (C34.8 (b)): the rows above are the hull-rest probe's pre-registered noise for
round 34's bars.**

### Bar M3 (CP-F attempt 4) — FILED 2026-10-19 (the A/A's noise in); no attempt-4 number before the orchestrator records it

**Candidate:** `lab/m1-ruler`'s tree (= main + round33/manoeuvre's CP-F attempt-3 code, `TURN_HULL_DEFAULT` flipped to
true) + M1's ruler; the pair = that + native's mirrors (native cuts them on the tree; round 33's statement: no C++ change,
wheeled faces are handed back). **Base:** the same tree, `--nav-off=turnhull`. **Gate first (C31.1):** the pair's whole
suite green on builder2 (sim-baseline moves adopted with the reason). **Machine:** builder2 start to end. **Seeds:** FRESH
hull-rest 601–616 (4 factions × 16 × 6 tasks = 384 runs an arm, drawn and clicked), Terminus 620–632, fights 640–663, SBF
670–675, bridge-pooled's 18; 41/44/45/66/67 and 460–475 stay tuning. **Ruler:** the new one (M1): "still" by `real_mps`,
wedged crews their own line, the seed shifts the destination (HULL_SHIFT_M 6) and the facing (HULL_JITTER_DEG 20), every
target pinned; distinct pairs reported beside all pairs (R33.23). **Noise:** from the A/A `references/round34/manoeuvre/
m1-aa/` (two seed sets of the OFF arm, 36 pairs a task): each guard's k·se below is that table's se, not the series' own,
as judging.md S5 asks; (d) and (e) are re-sized to the MDE the A/A gives.
| line | reads | rule |
|---|---|---|
| (a) | drawn POINT tasks (move, right, attack-move), wheels/turret at rest | per task median ≤ 15° AND ≥ 70 % within 15° (as R33.21) |
| (b) | drawn LINE tasks and every class on every task | no class median worse than base at permutation p < 0.05; (o) stands |
| (c) | clicked arm, wheels/turret | paired median NEW − BASE ≤ +1.645 se, one-sided (R33.23) |
| (d) | crews moving at the judge by `real_mps`, per task, all classes (wheels/turret reported) | ≤ base + 1.645 × sd_run(A/A) × √pairs, sd_run per task from the A/A table above (attack-move 1.17, right 0.64, move 0.51, screen 0.41, ambush 0.24, SBF 0.23; at 64 pairs the guards are +15.4 / +8.4 / +6.7 / +5.4 / +3.2 / +3.0); **wedged crews counted apart and REPORTED**; distinct pairs reported beside |
| (e) | never settled (75 s), per task | ≤ base + 1.645 × sd_run × √pairs with sd_run from the A/A's settle column read as a count (the A/A: 0–3 never-settled a set; se filed as 3.0 a task at 64 pairs); settle paired median REPORTED |
| (f) | arrived within ARRIVED_M 7 m; re-seats | arrivals not down beyond 1.645 se paired; re-seats ≤ base + 1.645 se |
| (g) | Terminus arrivals, rigs and mixed | not down beyond 1.645 se paired |
| (h) | bridge-pooled | 18/18 |
| (i) | fights: kills, deaths, hit rate per team | within 1.645 se (gate) |
| (j) | counters in the new arm | `hull_turns` > 0; `hull_holds` REPORTED (R33.34: 0 when the judged seeds have no contact) |
| (k) | the named case s66 Green_Guns_5 | REPORTED |
| (l) | SBF gang_ifv drawn | REPORTED |
| (m) | the default path | the pair's twins at 0 as the gate (native, 2026-10-19: no C++ change, every change is GDScript decision code the C++ does not port; wheeled faces handed back, reason 3; on e76f6dab6 builder2 `native test` of the execute/face_behind/drive/manoeuvre/h1b/decide twins 14/0, 0 mismatches); the hull-rest drawn arms ALSO run on the native path, ON on lab/cpf4 and base on lab/m1-ruler e28ba432d (the same code, default false; a --nav-off arm would leave the native path), agreeing in sign with the GDScript arms on (a) and (d) |
| FACE_KEEP_FAR | | REPORTED only (R34.5); face distance judged on face_pairs, CAND_ONLY reported |
**Partial:** (a)–(j) are the gate; any miss parks it with the trace. Ships ON as a pair; brains told the merge hash the
day it lands (B11b). **Last attempt:** this is the fourth; a fifth needs a new design, not a re-run.

### Report (2026-10-19 early, round 34 in progress; Fable)

**Attribution (2026-10-19 ~03:00 PDT, builder2, pair c8fb8b6a3):** the C31.1 check: 2818/0, 26 of 27 targets, twins 0
mismatches; sim-baseline's three MOVED maps (crossing 87d6a60d2b9e7497, parade f16fd810ae957839, archipelago
74099e787f74682c). `sim-variants VARIANTS_EXTRA=--nav-off=turnin` on the SAME tree: all 13 base40 hashes equal main's
recorded lines (crossing f8024203917ca808, parade 27580bb53aa4ebe3, archipelago f97836b7868c7906, docks 4074d105e1739377):
**the moves are the turn-in's own.** Files: `references/round34/manoeuvre/m0-series/` (check summary, the variants
tsv, dev-11-23 rows and table at 764ef5427, the syn_lancer report rows). The series runs.

**Earlier (2026-10-19 ~02:15 PDT): the judged series is RELEASED** on pair c8fb8b6a3 (builder2, seeds 101–112, n 12, after
its check and the `--nav-off=turnin` attribution in the same folder); no candidate change from here. **Dev 764ef5427**
(builder2, 11–23, n 13): (a) 3.8 → 74.1 % (sd_boot 5.9); (b) 2 → 10; (c) exchange 0.18 → 2.15 (gain − k·sd 1.72);
in-reach hits −1436 v k·se 597; per-cell damage taken all six PASS (−17 to −250 a run); (d) 0; (d2) 0; (e) 26.9 m; (g)
identical. (c-out) as written FAIL (totals +1265 v k·se 505; medians 45 → 56; worst +25 % gang_scout v syn_scout 45 m),
inside what he accepted (57, +37 %); the out-of-reach rule took gang_scout v gang_ifv 30 m from 133 to 80 hits (OFF 86).
**M1 the ruler** is built on `lab/m1-ruler` (round33/manoeuvre + main 82feffa86): 1B `real_mps`/`mps` on every crew row,
2B `--faced-shift-m` (seed-hashed direction; hull-rest passes HULL_SHIFT_M=6), cpf_judge reads still from real_mps and
counts wedged apart; test_manoeuvre_ruler 1/1 laptop. Next for M1: its A/A on builder2 after M0's series.
M0's candidate is stream/manoeuvre 764ef5427 (fa5226f14 + the out-of-reach rule +
main 82feffa86); its pair `pair/c339-r34` **c8fb8b6a3** (= 764ef5427 + `pair/native-c339` 25fd4298e, clean) runs on
builder2: `native check` → `sim-variants VARIANTS_EXTRA=--nav-off=turnin` (the sim-baseline attribution) → the judged
series 101–112 (one chain, folder godot-manoeuvre-pair). Dev cells 11–23 at 764ef5427 run beside it. **M2's quick-remote
is green** (builder0, bbf1f6b77: 74 passed, 0 failed, 161 scripts lint). **The REPORTED cell** (gang_scout v syn_lancer
15 m post, builder2 fa5226f14, dev 11–23, n 13, both arms GDScript): OFF in-arc 2.4 %, 2 shots, dealt 5, 85 reverse
ticks under a face and 53 at stop (the shuffle, brains' "held fixed gun k-turns, 0 shots"); ON in-arc 81.8 %, 10 shots,
dealt 871, 0 reverse; hits taken 23 → 25, damage taken 736 → 805 (+9 %), furthest 21.7 m. **Dev table at fa5226f14**
(builder2, 11–23, n 13; steering only): every in-reach line passes, the per-cell damage guard too (law v scout 15 m now
−82 a run); (c-out) FAILS as written (hits out of reach +1393 over 13 seeds v k·se 518; medians 45 → 55; worst cell
gang_scout v gang_ifv 30 m +55 %, beyond the accepted +37 %): there the gang scout (reach 24 m) closes to 15–18 m INTO
reach and kills the IFV (dealt ~1000 a run) while taking 133 hits v 86. The exchange out of reach is reported beside it.
Earlier:  M0's candidate is now stream/manoeuvre **fa5226f14**; its dev cells 11–23 run on
builder2, then the REPORTED syn_lancer cell. The superseded pair d38f688f2's C31.1 check on builder2 (`make native check
exited 2`): every test passed (2818/0), native twins 0 mismatches (test_native_execute_turn_in PASS, 276 turn_in_stop
hand-backs), lint clean; the one FAIL is sim-baseline with four maps MOVED (crossing, parade, archipelago, docks: brains'
scouts in contact now turn in), the NOT JUDGED is perf-judge's load refusal. The orchestrator asks the moves attributed on
the pair tree with `--nav-off=turnin` before the series (`make gcp-remote T="sim-variants VARIANTS_EXTRA=--nav-off=turnin
VARIANTS_TAG=turninoff"` against main's lines), and main ≥ 82feffa86 (docks adopted at B1's hash) merged at the re-cut.

**Third round of fixes (fa5226f14), from the 5055a6ed8 dev cells (builder2, 11–23, n 13):** the 5055a6ed8 table read
(a) 3.8 → **75.7 %** in-arc on in-reach cells, exchange 0.18 → 2.02, in-reach hits taken 104 → 85, (d)/(d2)/(e)/(g)
pass, but law_scout v syn_scout 15 m dealt **0 in every seed** and took 496 against 440 damage: my creep-line floor
`sqrt(yaw_share × 0.55 × 1.1)` read 1.15 for a 310 deg/s want, so the hull ran at 16 m/s, past the speed at which full
lock reaches its yaw cap, and sat 60° off the orbiter for 25 s (the failure the original code's comment names). Now the
floor is capped at TURN_IN_ROLL and the throttle at the yaw-cap speed; and when the bearing's own swing (rate + own)
outruns what full lock at the cap can yaw (a 17 m/s scout at 10 m), the catch-up JINKS instead of chasing smoothly (a
smooth circle is the easiest motion for the orbiter's lead). Laptop: that cell s11 0 → 31 dealt, 19 → 23 % in arc; s36
91 %; the other four cells unchanged. R34.1's lines read on the 5055a6ed8 dev rows (dev seeds; steering only, the bar
stays as filed): (a) PASS (75.7, sd_boot 3.0), (b) PASS, (c) exchange PASS (gain 1.84, k·sd 0.13), in-reach hits guard
PASS (−1317 v k·se 528), per-cell damage guard **FAIL on law v scout 15 m** (+56 a run v k·se 47; the other five pass by
12–257), (c-out) FAIL as written (+996 v k·se 592) but within what he accepted (medians 45 → 50, worst +23 %), (d) (d2)
(e) (g) PASS. The one line at risk is that cell's damage guard, at the hull's physical limit; fa5226f14's jink is aimed at
it, and the series' verdict falls where it falls (the orchestrator, 2026-10-19).

**Traffic's X1 census, the wedged-and-killed class (asked by the orchestrator; code read only, main 82feffa86):** 133 of
2096 deaths were crews `Movement.wedged` with a live move. My view: it is the UNSTICK NEVER FIRING, not firing slowly.
`wedged` (movement.gd ~1490) is a measurement: avoidance shaped the hull's velocity on > 50 % of the last 2 s and it moved
less than a hull length; nothing acts on it (counters only). The blind stall rule in `_unstick` (~3410) needs |throttle|
> 0.5 and a reading < STUCK_SPEED for 1 s, and a hull that avoidance is shaping has its throttle shaped DOWN, so the
stall clock never runs while the hull grinds in place; the honest reading (`unstickback`, H1) is opt-in and applies to
routed moves pinned on a HULL. Candidate (round 35, manoeuvre): a second trigger for `_unstick`, `wedged` itself (2 s of
avoidance with under a hull length made good) → the H1 ask/escape path, judged on traffic's far_census deaths-by-cause
(stuck/jammed deaths ON ≤ base) with the x1 rows as the base. Not this round.

**M2 is built:** `lab/m2-arriveleg` bbf1f6b77 (main 9c0f4dfce merged, brains' adapter in): `Manoeuvre.leg_holds_arrival`
holds a move_to's arrival while a planned leg drives, bounded at 3 s of leg time per order (`Movement.arrive_hold_until`,
reset by new_order), `arrivals_held` once per order + `arrivals_held_ticks`, `--nav-off=arriveleg` (default ON), census
counters; tests/test_manoeuvre_arrive_leg.gd (the hold, its bound, the counters; the seam end to end through brains'
`_leg_holds_arrival`, the hold counted, held_moves_refused 0) + brains' tests/test_ai_arrive_leg.gd: 3/3 laptop. Its
quick-remote runs on builder0; its check waits behind M0 on builder2.

**M0 (C34.10): candidate stream/manoeuvre 5055a6ed8 (main 9c0f4dfce merged); pair tree `pair/c339-r34` d38f688f2 (= 5055a6ed8 +
`pair/native-c339`'s three native commits, clean). Its C31.1 `native check` runs on builder2 (folder godot-manoeuvre-pair);
dev cells 11–23 both arms run on builder2 (godot-manoeuvre), then the REPORTED gang_scout v syn_lancer cell. The bar is
filed (R34.1). Nothing judged yet.** builder0 went down ~22:55 PDT; nothing was read from it after that.

**M0, the second round of fixes (5055a6ed8; from the first dev set at dd0b2127c, builder0, 11–23 n 13: (a) 18.8 against
the judged tree's 21.3; the loss was all in the 30 m fast-orbit cells, law_scout v syn_scout 30 m 71 → 14 % in-arc,
while law v IFV 15 m went 23 → 71 % and hits taken 130 → 11):**
1. The catch-up (live) branch floored its speed at TURN_IN_ROLL 0.55 with a FULL lock whatever the wanted yaw. Once the
   want was small it chattered left-right every tick (yaw 92 deg/s read per tick, the heading net still), and a hull
   with an 11° error drove nearly straight at 6.9 m/s, out past its leash every time. Now: the lock is proportional
   (yaw_share / throttle) and the speed floor is the creep line (sqrt(yaw_share × WHEEL_CREEP × 1.1)), as the on-target
   branch already had.
2. The leash's first tier (14–18 m from the post, heading away) SLOWS THE DANCE: no fast dwell, the tightest circle that
   still tracks the target (creep-line share, the lock it needs). Round 33's override (full lock the shortest way home)
   was the target's far side half the time and lost a 48 deg/s orbiter for a lap; on the target's own side alone a
   gang_scout spiralled 65 m from its post (seed 17). Past 18 m, round 33's override as it was.

| laptop cell (n 1, --fixed-fps 30; mechanism only) | judged tree 781801da0 | dd0b2127c | 5055a6ed8 |
|---|---|---|---|
| law_scout v syn_scout 30 m s11: in-arc / hits / far | 71 % / 108 / 15 m | 11 % / 111 / 17 m | **91 % / 82 / 17 m** |
| law_scout v syn_scout 15 m s36 | 50 % / 150 | 22 % / 129 | **91 % / 147 / 20 m** |
| gang_scout v syn_scout 15 m s17 | 76 % / 149 | 7 % / 159 | **86 % / 108 / 17 m** |
| law_scout v gang_ifv 15 m s19 | 19 % / 140 | 94 % / 0 | **94 % / 1 / 12 m** |
| gang_scout v gang_ifv 30 m s12 | — | — | 32 % / 36 / 24 m |
Every run: 0 reverse ticks under a reverse command. The 7 orbit tests pass (laptop).

**Plan (ordered):** M0 C33.9 (the fix → quick-remote → dev cells 11–23 on builder0 → the bar to the orchestrator →
C31.1 full suite ON on the pair tree, builder2 → the judged series, fresh seeds, builder2) → M1 the ruler (1B/2B, A/A) →
M2 the flicker (seam agreed with brains, see below) → M3 CP-F attempt 4 → M4 → stretch clip.

**M0, what round 33's narrowing really failed on (laptop traces, commit dd0b2127c's tests; `C339_ONE=law_scout,syn_scout,15,36 C339_DENSE=1.4-5.4 make test FILTER=c339_cells`):**
1. Seed 36's 13 reverse ticks (R33.39): the scout turned in, closed from 15 to 3 m and sat on the orbiter's nose; the
   orbiter STOPPED for 3.0 s (its velocity read 0.0 from t1.6 to t4.6); the turn-in's "spot stood still 3 s → the face
   planner" rule handed a live threat face to the planner, whose first leg was a reverse (NEGCMD t4.63–5.17). Neither
   narrowing (speed gate on the first ticks, R33.38) touched this path; the speed gate itself made it worse because the
   stage's orbiter starts from rest.
2. The brain's face spot is STALE by 1–2 m: `TankBrain._order_move` drops a face within 2 m of the one executing (its
   near-duplicate rule, brains' code, correct for a fixed point), so after the enemy stops the spot sits where it was
   last re-issued (seed 14 halt trace: spot (13.7,−13.2), enemy (15.3,−12.4): 7° at 14 m, half a scout's arc). A hull
   holding on the spot had the real enemy at the edge of its arc and fired once in 10 s.
3. The judged ruler: (c)'s per-cell exchange on gang_scout/syn_scout/15 is 0.04 → 0.02 ("−46 %") in a cell where the
   gang scout deals nothing in 5 of 6 runs; its seed bootstrap at n = 6 spans −100..+135 %. That line cannot carry a
   verdict at any n this round can run; the bar below re-forms it.

**M0, the fix (dd0b2127c, `game/ai/manoeuvre.gd` turn_in, `order_controller.gd` _stop_turn_in, `movement.gd` face_drop):**
the turn-in resolves its spot to the LIVE ENEMY HULL it stands for (`Manoeuvre.live_enemy_near`: the nearest within
10 m; a brain's crew only; a threat face only, `from` empty, or a stop's swing) and reads the bearing, its rate (from the
enemy's velocity: d(theta)/dt = (p × v).y / |p|², smoothed a tick) and whether it STANDS (< 0.5 m/s) from that hull every
tick. A standing enemy in the arc: hold still and shoot. Out of the arc: come round forward (full lock at ≥ 0.55 share).
The face planner takes a face only when NO live enemy is at its spot (a memory, a drawn, post, sector or squad facing, a
scripted order): so creep_bound's plain faces, the suppression scenario's scripted scout and every drawn facing are
untouched, and a live threat face never reaches the planner's reverse legs. The planner's leftover legs are dropped the
tick a turn-in has the hull. The spot-step rate machinery (`_turn_in_bearing/_tick/_seen`, TURN_IN_MOVING_S, the speed
gate `facing_mover`) is gone. Native's stop hand-back (`pair/native-c339` 2f9ad0fb9) is untouched by this: the C++ hands
every stop on a fixed gun on wheels back under the switch, and the GDScript decides.

| test (laptop, --fixed-fps 30, n 1) | old code (fc809b60a's gate) | dd0b2127c |
|---|---|---|
| halted orbiter (gang_scout v syn_scout 15 m, seed 14, enemy stops at 2 s) | rev cmd 12, gear changes 1, in-arc 60 % | rev cmd 0, 0, in-arc 69 %, held still 181 ticks, dealt 137 |
| parked enemy (law_scout, syn_scout standing at 20 m 133° off, seed 36, 10 s) | turn-in never ran; the creep reversed 81 ticks; in-arc 44 % | rev cmd 0; in-arc 83 %; 84 shots; 9.4 m from post |
| (d2) stop (gang_scout v syn_scout 15 m, seed 14) | OFF 27 reverse ticks at stop | ON 0 |
| static drawn face (6 cells), determinism (2 fresh children) | pass | pass |

Laptop rows are for mechanism only: a pinned laptop run of seed 36 did NOT reproduce builder2's row (in-arc 22.4 v 12.4,
reverse 0 v 13 under the same code), so the laptop is not row-equivalent to the builders even at --fixed-fps (builder0 v
builder2 were 312/312 in round 33). Every judged or dev number below is a builder's.

**M2 seam (agreed through the orchestrator, 2026-10-18):** brains takes `lab/cpf-arriveleg` 7e0953f9d's one condition into
`TankBrain._act` as-is and keeps `_order_move`'s held-post refusal; manoeuvre owns `Manoeuvre.leg_holds_arrival` and the
`arriveleg` switch, bounds the hold at 3 s of leg time, and ships it with a test that fails without it. The counter's unit
(think ticks v arrivals) waits on brains' answer via the orchestrator.

**Native (C34.8):** native pinned command.mk's hull-rest/facing/flank probes (d8ce74b91, one $(PIN_FPS) token each): M1 adds
no second pin. `tests/test_manoeuvre_wedge.gd`'s "native: absent" return goes to `NativeExpect.absent(self)` once native's
12ac7b172 is on main (they will say).

### Bar M0 (C34.10): the scout turn-in, round 34 (filed 2026-10-18 before any fresh-seed number)

**Probe:** the orbit stage, `tests/test_manoeuvre_orbit.gd` `_orbit_stage` via `make manoeuvre-c339-cells` (one
`--fixed-fps 30` Godot a seed, both arms GDScript): 2 subjects (law_scout, gang_scout) × 2 orbiters (syn_scout, gang_ifv)
× 3 radii (15, 30, 45 m) × post (player / free) × arm (ON / OFF), 30 s a cell. In reach = radius ≤ the scout's
`reach_m` (35 m): the six in-reach player cells are gang 15 m, law 15 and 30 m against each orbiter.
**Candidate:** stream/manoeuvre at the hash whose C31.1 check is green (the pair tree = main + this branch +
`pair/native-c339`'s three native commits rebased; TURN_IN_DEFAULT true). **Base:** the same tree, `--nav-off=turnin`.
**Machine:** builder2, start to end; builder0 for dev only. **Seeds:** FRESH 101–112 (n = 12 a cell, 576 rows); 11–36 are
tuning. **Last attempt:** this is C33.9's second judged series (R33.24 was the first); a third would need a new design.
**Counters:** `turn_in` ticks/stalls, `holds`, `hold_ticks`, `stop_turn_ins` in every row.
**Noise, read from round 33's rows** (c339-judged/cells-31-36.jsonl n 6; dev-11-23 n 13; the bootstrap resamples seeds):
(a) pooled in-arc median sd_boot 3.5 at n 6 (≈ 2.5 at n 12); in-reach pooled exchange sd_boot 0.13 at n 6 (≈ 0.09);
per-cell damage-taken sd a run 12–90 (law/syn/15 11.7; gang/syn/15 89.6); per-cell hits-taken sd 6–38.

Lines, player-post cells (R33.24's lines kept, each in its variance-aware form; k = 1.645):
- **(a)** in-arc % median on in-reach cells: ON ≥ 2 × OFF and ≥ 25 (the point as R33.24 wrote it). Beside the verdict:
  sd_boot and the margin to R33.24's 23.9, the value he accepted (R33.38). *Ship reading:* ≥ 25 passes; ≥ 23.9 − k·sd_boot
  is "no worse than what he accepted" and is reported as such for the orchestrator's ruling; below that is a regression.
- **(b)** shots median, every player cell: ON ≥ 1.5 × OFF.
- **(c)** exchange (damage dealt / taken) pooled on in-reach cells: ON ≥ OFF (point) AND the gain distinguishable from
  nothing (ON − OFF − k·sd_boot > 0). **Re-formed:** the per-cell −20 % exchange ratio is a REPORT, not a line (a cell
  whose OFF deals 0.04 cannot carry a ratio: bootstrap −100..+135 %). In its place, two guards on harm he would see:
  in-reach pooled hits taken ON ≤ OFF + k·se (se = paired se of the sum over the 72 run pairs), and per in-reach cell
  damage taken ON ≤ OFF + k·se_cell (se_cell from that cell's 12 paired differences).
- **(c-out)** out-of-reach player cells: pooled hits taken ON ≤ OFF + k·se, and no cell with OFF ≥ 10 worse than +20 %
  (as R33.24 wrote). Beside the verdict: R33.24's accepted 42 → 57 / +37 %. *Ship reading* as (a): ≤ 57 and ≤ +37 % is
  "no worse than what he accepted"; out of reach is brains' C34.5 (the outgunned scout leaves), so the orchestrator rules.
- **(d)** while a face holds: 0 ticks under a reverse command in every ON run; commanded gear changes ≤ 2 a run. A
  deterministic count: a failing run is named and its trace read before the medians (lesson 302).
- **(d2)** while the order is `stop`: 0 reverse ticks in every ON run (OFF reported: the shuffle he saw).
- **(e)** furthest from the post ≤ 29 m in every ON run (14 m leash + a turning circle + a hull).
- **(g)** free cells: ON no worse than OFF on (a)–(c) medians; if the arms are byte-identical, say so.
- **(h) reported:** holds / hold_ticks, mean distance, damage, stalls, the per-cell exchange table.
**Before the series:** C31.1, the whole suite with the switch ON on the pair tree, green on builder2, with any sim-baseline
move named and explained as the turn-in's own (the brains' scouts that now turn in). **Partial rule:** (a) alone missing
by less than its sd_boot does not park a candidate that passes (b)–(g); any (d)/(d2)/(e) run fails it.

