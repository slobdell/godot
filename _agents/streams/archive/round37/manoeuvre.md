> **ARCHIVED (round 37 closed 2026-10-22).** The branch is `round37/manoeuvre`; its unmerged references stay on that branch. Round 38's brief is `streams/manoeuvre.md` where one exists.

# Stream: manoeuvre (the last odd-looking side steps and stuck crews)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 37** (C37.1, C37.7)
> and in *Round 36*: R36.27, R36.28, R36.31, R36.32. Then your round-36 brief `streams/archive/round36/manoeuvre.md` (its Status is
> the close-out). **You own:** in `movement.gd` the `drive()` body, `_nose_stop`, `unstick`, `_pressing_escape`, the
> k-turn/planned-reverse executor and the side-step rule (h1bside); traffic's give-way block (`right_of_way` .. `_blocker`, `_avoid`,
> `_around_friends`, `_ask_behind`, `_hull_within`) and `game/ai/traffic.gd` (traffic has no stream this round); `tests/manoeuvre/**`,
> `tests/traffic/**`, `tests/test_manoeuvre*.gd`, `tests/test_traffic*.gd`, `mk/manoeuvre.mk`, `mk/traffic.mk`.
> **Model:** Opus. **Machine:** builder0 (C37.1); light runs on either builder.

## The lead's direction

**"the feel of the game needs to have the user perceive that the units are smart and under their control"** and **"the general
priority is to mitigate vehicle contention with one another"** (game_design.md, round 36). A behaviour with a good internal reason
that LOOKS dumb counts against the game.

What he will notice: a crew blocked by a long friend seen at an angle stops trying the same side step every few seconds; fewer crews
left wedged behind their squad.

## Where things stand

- **S2a ON** (main eee5b0afa, R36.32): far loops 91 -> 35, left behind 77 -> 65 / 768 runs (builder2). **T8 ON** (R36.12).
- **Eyes_3 (R36.31):** `_side_clear` tests only the POINT against hull centres, never the DRIVE to it against the friend's oriented
  box; a long hull at an angle blocks the drive and the crew picks nearly the same point every ~3 s (9 picks, net 1.0 m). 17
  crew-friend pairs reached the side rule in 48 fights; 15 fired once, 1 twice, Eyes_3 9 times.
- **WEDGE_TRACE** on main has no `unstick_fires` total (R36.32; the judge rebuilt it from rows).
- **S1 stallnet** failed its series (R36.27: an unstick storm, kills up); parked OFF on `round36/manoeuvre`.

## Backlog (in order)

1. **M1 Eyes_3's stand rule** (fix (ii)): a side step that ends still blocked by the same unmoved friend makes the next far fire a
   stand. Deciding lab case: a long friend at 30–45 deg (both paths). Bar in *Bars (round 37)* before numbers; native twins the change.
   Symmetric: a pass ships ON.
2. **M2 the `unstick_fires` total** in main's WEDGE_TRACE, so `s1_judge.py` reads it (census lint N5: it must print).
3. **M3 S1 v2:** a design note to the orchestrator on what a fresh stall net would do differently from R36.27's (no code before a
   ruling).
4. **M4 once rules' R3 (suppression slows) is ON:** re-read wedge and left-behind lines on main; report any rise.
5. **M5 seated crews step aside and come back (R37.6, the orchestrator via godot-b0, 2026-10-21):** in traffic's give-way
   block, a SEATED crew (arrived, deployed) yields by stepping aside and reversing straight back to its seat; spots scored by
   distance to the yielder's seat; it no longer leads the asker out. Bar in Status before any number (deciding: metres a seated
   crew is moved off its seat, base = round 36's S4 trace; guards: the asker's wait and all-in time, friendly contacts, kills).
   Symmetric: a pass ships ON. After M1.
6. **M6 a parked wheeled hull told to `face` drives off its spot (R37.13, godot-b0, 2026-10-21):** orders' trace (laptop
   GDScript, locks 3 click s34, scouts): under SPOT the command is `face`, the move refused, yet a wheeled scout drives ~7 m in
   a second (43.4 -> 26 m from its seat over 3 s); builder0 re-count (18 fights, orders' 23ffe47fb): 23 SPOT + 4 ENGAGE leaves
   of parked crews were this face-path motion. After M1/M5: trace (how far, which units, why the turn needs travel), propose
   a turn-in-place or a short back-and-forth limit for a parked hull, bar before any number.
7. **Stretch:** the post-deploy twitch that is neither depth nor seating (orders' engagement / stopped short / traffic split), trace only.

## How to verify

Lab cases first; `make quick-remote`; one full check per named hash; series on fresh seeds; every number with commit, machine,
workload, n. Smoke: `make skirmish ARENA=locks`, two squads through one street.

## Don't touch

Orders', rules', cover's, feedback's paths; brains' paths; `native/**`; `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### ROUND 37 CLOSE NOTES (worker, 2026-10-22)

**Shipped on main** (da3193cf5 merges 775c009fe alone, R37.41; green builder2 `make native check exited 0`, 3036/0,
sim-baseline 13/13 unmoved; perf owed on builder0 with main's):
- **M1 `sidestand` ON:** a crew whose side step didn't get it past an unmoved friend stands instead of stepping again. Bar M1
  PASSED (builder0 native, ON 339d3f2e2 v base b822e6696, 72 fight pairs + 128 hull-rest pairs per task): side repeats
  30 -> 9, far loops 61 -> 38, every guard flat. Evidence `references/round37/manoeuvre/m1-series/`.
- **M2:** WEDGE_TRACE prints the game's `unstick_fires` total (a static; round 36's per-crew sums were inexact).
- The unstick stall clock ignores rules' short halt (+ native twin). Inert while R2 is OFF (rules closed, R37.33).
- R37.35: the h1b_side bank stage re-pinned west of the lock (BANK_X -50), clear of cover's K5 barricade runs. Native =
  GDScript on main's arenas and on cover 3923ba026's (builder0 light, 4/0 each, 2026-10-22). Native's traffic_stage seam
  (`stage_override`, 3891cbabd).

**Closed, not shipped:**
- **M5a `seatstep`: FAIL as filed** (R37.30). Deciding passed: seat metres -8.5 %, lead-out give-ways 747 -> 436. Guards
  failed: team 1 kills -89 (limit 81), and hull-rest never-settled ambush 5 -> 10 / attack_move 17 -> 23 (limit +4.9).
  It stays OFF on `lab/manoeuvre-r37-m5` (936612334). Evidence `references/round37/manoeuvre/m5-series/`.
- **M6 closed by the lead:** the parked scouts' circling turn-in stays (game_design.md). A leash measured harmful
  (`lab/manoeuvre-r37-m6leash`).
- **M4 never triggered:** rules' R3 (pin_slow) failed Bar R alone (R37.25), and the package closed at R37.33. Nothing to re-read.
- **Stretch (post-deploy twitch):** decomposed, no rule. Of 1,696 s off-seat while parked: turn-in 945, standing off the
  seat 579, brain moves 81, give-ways 80, driving code about 11.

**For round 38** (the orchestrator assigned the M5 v2 there, R37.30):
1. **M5 v2, a new bar filed first.** Re-use M5a's rule (lab/manoeuvre-r37-m5 + native's pair 156d563d9). Two guard changes,
   decided before any number:
   - **(a) fight volume:** a symmetric rule that only makes fights smaller must not fail on "fewer kills". Guard the
     kill SHARE per team (kills_t / total kills, paired, within 1.645 se) plus total deaths of both teams not up. For
     scale only (aggregate totals from M5a's judge, not a paired line): team 0's share 1572/2983 = 0.5270 -> 1515/2837 =
     0.5340; total kills 2983 -> 2837.
   - **(b) never-settled (e) needs its noise floor first:** the laptop GDScript re-run of M5a's 5 ambush flips reversed
     them (ON settled in all 5, base missed 1; trace below). So run base v base on two paths (native v GDScript, same
     seeds) to size how much (e) moves with no rule. Then set (e)'s limit from that, or replace it with a paired line.
2. **Ambusher-settle read (done, step 2):** in condemned 6830 the arms match to f359, where one seated give-way picks
   (0,8) v (3,-6). The later asks then differ, and whether the whole army settles is redrawn. No mechanism, no rule.
   Trace build: `lab/manoeuvre-r37-ambushtrace` aae71e74e (`--yield-trace`). Not done: a native self-repeat of the
   series' ON arm on those seeds.
3. **M5b (seated crew reverses straight back to its seat after a give-way):** trace the return drive first (how often,
   how far, against what). It needs a native twin. Not started.
4. **M3, S1 v2 (stall net):** note `references/round37/manoeuvre/m3_s1v2_note.md`. Round 36's +22 % unstick fires was
   inexact (the static, M2). Recommendation unchanged: count the base rate on main with M2's total (light lane, about 1 h)
   before building; v2 = hold only in contact with an unmoved friend, fire through H1's ask, cap per goal.

**Branches kept (labs, never merged):** lab/manoeuvre-r37-m5 (M5a OFF tree), lab/manoeuvre-r37-m5on,
lab/manoeuvre-r37-ambushtrace, lab/manoeuvre-r37-bankcover (stream + cover arenas, the R37.35 read),
lab/manoeuvre-r37-m6trace, lab/manoeuvre-r37-m6leash, lab/manoeuvre-m1on/m1base. **Worktrees left:** godot-manoeuvre-m5 (its
builder folders stay too). The M1/M5 series trees and their builder folders are removed. Process lessons: give a single seed to
`M1_SEEDS` as `N-N` (a bare N ran seeds 1..N for 90 min); grep check verdicts only on `^>> check:` lines (the check's own self-test
prints "NOT RUN").

**2026-10-22 (worker): HAND-OVER GREEN at stream/manoeuvre 775c009fe (builder2):** `make native check exited 0`, 3036 passed /
0 failed, 25 passed + 2 NOT JUDGED (perf-judge: builder2 is not a judging machine; scenario_perf loaded), sim-baseline 13/13
unmoved (log `~/overnight-manoeuvre/r37/check_775c009fe_builder2.log`). It contains M1 ON, the h1b_side bank re-pin
(R37.35, 6eda892a4), native's traffic_stage seam (3891cbabd), and main merged (775c009fe). Earlier tries got no verdict:
on 76c325844/6eda892a4 builder0 was overloaded and the check was cut off at 82 min (22 NOT RUN); on 80b59598d builder2 at
load 33 failed one quiet-window self-test (load-sensitive tooling, not this stream's), and N5's UNEXPECTED PASS showed until
main was merged. Perf is owed on builder0 (main's, separately).

### M1 VERDICT: PASS, ships ON (2026-10-22 01:35, builder0 native, ON lab/manoeuvre-m1on 339d3f2e2 v BASE stream b822e6696)

`python3 tests/manoeuvre/s1_judge.py ~/overnight-manoeuvre/r37/m1 --bar m1` (evidence `references/round37/manoeuvre/m1-series/`):
wedge/fights/jam locks/terminus/sumps x 6640-6663 (72 pairs), hull-rest 6601-6632 x 4 factions x 6 tasks (128 pairs per task).
- (0) side_restands ON 9. PASS. side_repeats 30 -> 9, side steps 44 -> 14 (REPORTED). The lab decided earlier (both paths).
- Every guard PASS. Notable: far loops 61 -> 38 (-23, 1.645 se 18.9), unstick fires 2802 -> 2738 (-64, 1.645 se 51.7);
  deaths, kills and hit rate per team, contacts, give-ways, and hull-rest (d)/(e)/(f) were flat in all 6 tasks.
- Player line (REPORTED): left behind 54 -> 56 of 768 runs (wedged:idle 34 -> 36); rocking 4 = 4.
- ON tree check (339d3f2e2, builder0): 3011/0, sim-baseline 13/13 unmoved, 25 passed + 2 NOT JUDGED (load), the same as base.
- Hand-over: the stream plus `SIDE_STAND_DEFAULT := true`. Its game code equals 339d3f2e2's exactly, and the only other
  changes since b822e6696 are docs and judges. One full check on that commit follows.

### Bar M1 (manoeuvre, `sidestand`: one side step per unmoved friend, then stand), filed 2026-10-21 before any series number

- **Change (my paths: the side-step rule):** in `Movement._h1b_side`, a far fire on the friend a side step was already taken on,
  for the same goal, with that friend unmoved since the step began (`_side_over()` false), STANDS (the existing stand: throttle 0
  until the friend moves > H1B_MOVED_M or the goal jumps > NEW_GOAL_JUMP) instead of picking another side point. Fix (ii) of
  R36.31. `--nav-off=sidestand` flips SIDE_STAND_DEFAULT (false until judged). GDScript only: the choice runs in the escape
  callback both paths share; native reads `_side_stand` as today (no new exec field). Counters (ManoeuvreCensus, printed in
  `h1b_report()`): `h1b_side_repeats` (both arms: the base's repeat loop) and `h1b_side_restands` (ON acts).
- **(0) Counter first:** `h1b_side_restands` > 0 in ON's series; `h1b_side_repeats` REPORTED in both.
- **DECIDING (lab, both paths):** `tests/test_manoeuvre_side_stand.gd`, the stage's `eyes3:<yaw>` (R36.31's traced Locks spot,
  a law_scout behind a parked law_artillery, the artillery's yaw the parameter). At yaw 125/130/135 (its axis 45-55 deg off the
  lane) base takes >= 3 side steps (>= 2 repeats) and never gets past; ON takes 1 step + 1 stand, identical fires up to the
  stand, then still (< 0.5 m, no pressing) in the last 10 s. Guard: yaw 140 (one step gets past) ON = base exactly. Native =
  GDScript in both arms (fires, stands, end within 0.05 m). The round-36 h1b_side cases unchanged.
- **Series guards (no harm), FRESH seeds, each within 1.645 se of base:** Bar S2a's set on main: hull-rest 6601-6632 drawn x 4
  factions x 6 tasks ((d) movers by net motion, (e), (f)); wedge/fights/jam on locks/terminus/sumps x 6640-6663 ((i) kills / hit
  rate per team, (q) open/stuck/jam deaths, (r) far loops, (s) friendly contacts, give-ways); **unstick fires** from WEDGE_TRACE's
  new total (M2) ON <= base + 1.645 se.
- **Player line, REPORTED:** crews left behind (`left_behind.py`, hull-rest faced_attack_move + faced_move). Expect little: the
  rule's base rate is small (R36.31: 17 crew-friend pairs reached the side rule in 48 fights, 2 repeated). So the series is a
  harm check, not a gain line (R35.64): the lab decides, the series guards.
- **Pass = (0) + the lab (both paths) + every guard. A pass ships ON** (symmetric movement fix, C37.7).

### M5a VERDICT: FAIL, NOT SHIPPED (2026-10-21 23:15, builder2 native, ON lab/manoeuvre-r37-m5on 7ebbc7bdd v BASE lab/manoeuvre-r37-m5 936612334)

`python3 tests/manoeuvre/m5_judge.py ~/overnight-manoeuvre/r37/m5` (evidence `references/round37/manoeuvre/m5-series/`):
jam census locks/terminus/sumps x 6840-6863 (72 pairs); hull-rest 6801-6832 x 4 factions x 6 tasks (128 pairs per task).
- (0) counter first: yields_seated ON 3506, lead-outs avoided 327. PASS.
- **DECIDING seat metres: base 43206.5, ON 39519.1, -3687.4 (-8.5 %), 1.645 se 3051.3. PASS.** Lead-out give-ways
  747 -> 436, back-ups 647 -> 793, episodes 4047 -> 4152 (REPORTED).
- Guards: asker's wait, timeouts, friendly contacts, jam deaths, deaths of both teams, team 0 kills: PASS.
- **FAIL: team 1 kills 1411 -> 1322 (-89, 1.645 se 81.0).** Every fight count went down: team 0 deaths -89 (the same kills,
  seen from the other side), team 1 deaths -56, team 0 kills -57. The rule is symmetric, so the fights got smaller, not one-sided.
  But the guard as filed is "kills per team no worse than base + 1.645 se", and fewer kills counts as worse.
- **FAIL: hull-rest (e) never settled: faced_ambush 5 -> 10, faced_attack_move 17 -> 23** (limit +4.9). The others
  passed or went down (screen 26 -> 19, right 20 -> 17). (f) arrivals passed in all 6 tasks.
- ON check (`make native check exited 2`, builder2): 3019 passed / 0 failed. The two red rows are not M5's:
  ai-scenarios-check / native-verify-scenarios exited 1 on `UNEXPECTED PASS scenario_scout_suppress::test_target_behind`
  (52,0,4,1). That is N5's promotion, which main took in 4b62d2186 (53,0,5,0 -> 54,0,4,0); the ON tree predates it. 0 verify
  mismatches; perf NOT JUDGED (loaded). sim-baseline MOVED on yard, pit, archipelago and cut. Its base (stream b822e6696 plus native's
  pair, both 13/13 unmoved) means seatstep ON moved them, which is expected for a behaviour switch and now moot.
- Shipped as judged: nothing. `seatstep` stays OFF on its lab branch, not merged into the stream. No re-run to look for a pass.
  A v2 would need a new bar filed first: the open questions are a fight-volume guard that a symmetric rule can't fail
  just by meaning fewer fights, and why parked ambushers settle less (needs a trace before any rule).

**R37.30 (godot-b0):** M5a fails as filed. The v2 goes to round 38: a fight-volume guard, the ambusher-settle trace, and
M5b's reverse-back. Close notes carry it. This round: judge M1, then, if builder0 time allows, the ambusher-settle trace
(light lane): why faced_ambush never-settled doubles.

**Ambusher-settle trace, offline first look (2026-10-21, from the series' own run.logs, no new runs):** faced_ambush
never-settled went 5 -> 10. All 5 flips are ON-only (none base-only): condemned 6805/6819/6830, gangs 6816, law 6828.
In the 3 condemned cases, the last crew moving is a second-squad scout. With its order stop, it alternates move_to and face
orders 4-6 m from its seat to the run's end (6830: Green_Eyes II_9 from f450 to f2460, seat (-2.4, 101.7)). In base 6830
the never-ordered Green_Eyes III_3, parked at (3.0, 101.2) by that seat, moves away at f600-660 to (12.5, 98.7), and II_9
settles by f840. In ON, III_3 never moves. Hypothesis: with seatstep, the parked crew's give-way either never starts or
picks a spot that doesn't clear the asker (its seat is its face slot, so "nearest the seat" can mean staying). gangs 6816 /
law 6828 differ (tanks under face orders turning late) and are not yet read. Next (light lane, after M1's judge): re-run
the 5 cases ON and base with the give-way log, confirm reproduction, and read III_3's ask/pick.

**Ambusher-settle trace, step 2 (2026-10-22, laptop, GDScript `--brains-off=native`, lab/manoeuvre-r37-ambushtrace = 936612334
+ a `--yield-trace` print; ON = `--traffic-on=seatstep`):** I re-ran the 5 series flips (faced_ambush, the same seeds and
factions), one run per arm. Settled after (s), ON / base: condemned 6805 45.0 / 52.5, 6819 40.5 / 32.5, 6830 31.0 / never;
gangs 6816 49.0 / 43.5; law 6828 39.0 / 34.5. **ON settled in all 5 here (never-settled 0 v base 1), the reverse of the
series (builder2 native: ON never in all 5, base settled).** In 6830 the two arms match until f359, where one seated give-way
picks differently (spot(0,8) v spot(3,-6)); the scouts' later asks then differ (ON: III_3 steps to (0,-5) at f370; base: III_2
twice). Reading: in this task, whether the whole army settles flips on small path differences, so seatstep's (e) +5 / +6 is a
redraw, not a mechanism found. No rule is supported. Caveat: one path, n = 5. Not done yet: re-running the series' native arm
on these seeds (light lane) to confirm the native run reproduces itself. For round 38, the (e) guard should be read with that
redraw in mind (the same task, base v base on a second path, gives its noise floor).

### Bar M5 (`seatstep`, named `seatyield2` when filed: a seated crew steps aside and comes back), filed 2026-10-21 before any number (R37.6)

- **Change (traffic's give-way block, mine this round):** a SEATED yielder (its move_to arrived, within SEAT_NEAR_M 10 m of its
  seat = the move_to goal) picks, of the spots legal today (none added, none refused), the one nearest its seat. This is
  round 36's T10 G (`round36/traffic` 7f9760329), reused. The ahead-along-the-asker spots (10/16/24, 0) are taken only when
  no side or back spot is legal. After the give-way, its return to the seat may reverse straight back when the seat is
  straight behind (round 26's back-in law, unchanged). One switch, `seatstep` in Traffic.DEFAULT_OFF. The native twin is a
  request to native (T10's mirror is on `round36/native`, if any, or new).
- **Why not T10's deciding line again (R36.23/R36.24):** orders' away_m counted goal flicker as driving. M5 measures only
  inside give-way episodes, against the seat fixed at the give-way's start.
- **Base rate first (R36.23):** on main, count seated give-ways and their seat metres, in orders' probe (12 street cells) and
  in the jam census. n is sized from that count before the series. Lab first: a "not farther than standing" test
  (R36.24 (3)); each pick is no farther from the seat than today's pick.
- **DECIDING:** seat metres summed over seated give-ways, paired by seed. Seat metres = the give-way's farthest flat distance
  from the seat, plus the path driven from its end until the crew is back within 2 m of the seat (cap 15 s). ON < base by more
  than 1.645 se. The ahead-spot share is REPORTED.
- **Guards, each no worse than base + 1.645 se:**
  - the asker's wait: ticks from the give-way's start to the asker reading passed, and give-ways never cleared;
  - all-in time (squads arrived, deploy seconds);
  - friendly contact ticks;
  - kills and deaths per team, jam deaths (fights on locks/terminus/sumps).
- **Pass = the lab + the base rate seen + deciding + guards. A pass ships ON** (symmetric).

**2026-10-21 ~13:20 (worker): THE STREAM IS GREEN at b822e6696 (builder0):** `make native check exited 0`, 3011 passed / 0
failed, 25 passed + 2 NOT JUDGED (perf-judge refused 3x for load, ratios 1.41-2.30x), sim-baseline 13/13 unmoved,
determinism 8c3c1232b711a760 (log `~/overnight-manoeuvre/r37/check_b822e6696_builder0.log`). It contains M1 (OFF), M2,
main a10846307, the unstick short-halt skip, and native's twin of it (pair/native-unstick ca6978178). The commits after it are
judges and docs only. The M1 series started 13:22 on builder0 (unit `manoeuvre-m1-series2`).

**2026-10-21 14:57 (worker): M1's ON tree is green** (lab/manoeuvre-m1on 339d3f2e2, builder0): `make native check exited 0`,
3011 passed / 0 failed, 25 passed + 2 NOT JUDGED (the same two as the base: perf-judge lock held 300 s, ai-scenarios unpinned),
sim-baseline 13/13 unmoved, determinism 8c3c1232b711a760. The driver stopped on a false "NOT RUN" (it matched
check's own self-test lines `ok   ... NOT RUN`); I anchored that grep to `^>> check:` and restarted the series at 14:58 (unit
`manoeuvre-m1-series3`, wedge/fights/jam then hull-rest; the check is not re-run).

**Stretch (the post-deploy twitch, trace only): DONE by decomposition, no new rule.** On one workload, orders' fight probe
(f4437d26a + my probe-only driver tag, builder0 native light, locks/crossing/terminus x 3 squads x click x 3621-3626,
budget 1500, deterministic), the 1696.4 s parked crews spent > 6 m off their seat split as follows:
- **Scout turn-in, 944.7 s / 8,247 m.** M6, parked by R37.15: the lead was told "leave it". The leash measured harmful.
- **Standing off the seat, 579.4 s.** Orders' O2 drive-back.
- **Brain moves under move_to, 81.2 s.** Orders' engagement.
- **Give-ways, 79.9 s.** M5.
- **Face plan, creep and coasting under stop, about 11 s.** This is the "drive layer" twitch proper. Too small to act on.

**Player smoke, M1 ON** (lab/manoeuvre-m1on 339d3f2e2, builder0 light, `orders-probe-shots` on the Locks, 3 and 5 squads, click,
arrival + 5 s, desktop frames looked at): every squad is seated by its marker south of the canal, with no crew wedged and none
nosing into a friend. The rule does not arise in a clean move (as designed); the lab case and the series carry it.

**2026-10-21 (worker): M1 built + lab-decided on GDScript; M2 done; M3 note written.**
- **Plan (order):** M1 sidestand (switch OFF, lab case, Bar M1 filed in workstreams *Bars (round 37)*) -> M2 WEDGE_TRACE total ->
  M3 note -> M1 pair check + series (builder0) -> M4 after R3 is ON -> stretch.
- **M1 (`sidestand`, SIDE_STAND_DEFAULT false):** `Movement._h1b_side`: a far fire on the friend a side step was already taken
  on, same goal, friend unmoved since (`_side_over()` false) stands instead of picking again. GDScript only (native reads
  `_side_stand` as today). Counters `h1b_side_repeats` / `h1b_side_restands`, printed in `ManoeuvreCensus.h1b_report()`.
  - **Lab case** `tests/test_manoeuvre_side_stand.gd`, stage `eyes3:<yaw>`: R36.31's own Locks spot (scout behind a parked
    artillery). The base reproduces the trace exactly: side points (45.35..45.86, -83.9), the trace's were (45.3..45.9, -83.9).
    Laptop GDScript sweep (NATIVE=off): yaw 125/130/135 base 4 steps, 3 repeats, 9-10 fires in 30 s, never past; ON 1 step + 1
    stand, 5 fires, the last one the stand's. yaw 140: one step, past at 19.6 s, both arms. 110-115 and 145: rule never reached.
  - Why (ii) not (i): it bounds every loop shape, not only the traced one (R36.31's recommendation).
  - Idea for later, not built: on the repeat, try the OTHER side point once before standing (a stood scout is still left behind).
- **M2:** WEDGE_TRACE prints `unstick_fires` = `Movement.unstick_fires` (the game total); `wedge_table.py` prints its sum.
  **Caveat found:** `unstick_fires` is a STATIC. Round 36's S1-tree helper summed it over every crew (static x crew count), and
  WEDGE_EP's per-episode `unstick_fires` counts every crew's fires during that episode. So R36.27's +22 % and R36.32's rebuilt
  "fires inside wedged episodes" were in the right direction but not exact in size. Detail: `references/round37/manoeuvre/m3_s1v2_note.md`.
- **M3:** `references/round37/manoeuvre/m3_s1v2_note.md`. Recommendation: count the base rate on main first, then build v2
  (hold only in contact with an unmoved friend, fire through H1's ask, cap per goal) only if the count is worth a series.
- **M5a (seatstep):** the GDScript is on `lab/manoeuvre-r37-m5` b94025dbe (builder0 light 10/0). Native's mirror is on
  `pair/native-m5` 156d563d9: builder0 light quick 21/0, every twin stage 0 mismatches. Native runs the pair's full check on
  builder2 after its CP37.1 check. Then come the base-rate count and the series. M5b (reverse straight back) gets a trace
  first.
- **M1 fix:** the new member `_side_stepped` broke test_native_exec_state (every Movement member is a native exec field).
  bf904625b drops it, and the repeat reads `_side_over()` alone. Native confirms M1 needs no mirror.
- **M6 traced (waiting on a ruling):** it is round 33's shipped scout turn-in (R33.24). Workload: orders' fight probe,
  builder0 native light, 18 fights (seeds 3621-3626), deterministic. 405 of 409.5 face-drift s and 3,500 m are
  `Manoeuvre.turn_in`, all scouts: catching up 243 s, jinking on target 162 s, mostly 10-18 m from the seat (the 14/18 m
  leash). Evidence: `lab/manoeuvre-r37-m6trace` 99e9b2bf4 `references/round37/manoeuvre/m6/README.md`. Options sent; I
  recommend a ~6/9 m leash for a parked scout.
- **M5 base rate (first look, R36.23's rule):** builder0 native light, `lab/manoeuvre-r37-m5` 3f23c12cc, jam census Locks
  6700-6701, seatstep OFF. 97 + 39 seated give-ways; 27 + 8 of them lead-outs; seat metres 994 + 508; back on the seat
  within 15 s in 10 + 11; closed by a new order in 55 + 13 (CPU orders change). The deciding line has a workload. The
  series is sized from the base arm's first map.
- **M6 parked (R37.15):** the parked leash measured harmful (aim lost, no closer: `lab/manoeuvre-r37-m6leash` 23add418f).
  Reconciled with orders' 956.2 s on their exact command: the turn-in is 944.7 s / 8,247 m of it (`lab/manoeuvre-r37-m6trace`
  e20f9ba89). The lead was told "leave the turn-in". **CLOSED (2026-10-21, his answer, game_design.md on main via godot-b0):**
  the parked scouts' circling turn-in stays as it is; nothing more owed on M6.
- **Main merged** (a10846307 -> stream d8ba445d9). `unstick` skips a crew in rules' R2 short halt (`Tank.short_halt_seconds`;
  b496101bd, inert while R2 is OFF). Native's twin is requested.
- **Series queue (2026-10-21 ~12:45):**
  - **M1:** builder0. Unit `manoeuvre-m1-series` waits for the stream check on b822e6696 and starts only on its green
    verdict. ON lab/manoeuvre-m1on 339d3f2e2 v BASE = stream b822e6696. Its ON-tree check runs first. Judge:
    `s1_judge.py <dir> --bar m1`. Logs `~/overnight-manoeuvre/r37/m1/`.
  - **M5a:** builder2 (R37.18), queued after rules' Bar R series (unit `manoeuvre-m5-series4` waits until a godot-rules
    process has been seen there, then none for 10 min). ON lab/manoeuvre-r37-m5on 7ebbc7bdd v BASE lab/manoeuvre-r37-m5
    936612334 (stream + native's green pair 156d563d9). Judge: `tests/manoeuvre/m5_judge.py`. Logs
    `~/overnight-manoeuvre/r37/m5/`. START/FINISH get marked here.
    **START 2026-10-21 18:36** on godot-b0's release (rules' units inactive 18:36): unit `manoeuvre-m5-series5` (the waiting
    unit `-series4` stopped; a `go` file skips the wait, so its "no rules process for 10 min" line is the release, not a
    measured 10 min). Same false-"NOT RUN" grep fix as M1's driver. The ON check runs first (`--wait-below 1`).
    Restarted at J=14 at 22:36 (godot-b0's machine note; unit `manoeuvre-m5-series6`, no finished step redone). **FINISH
    2026-10-21 23:15**, all steps complete.
- **Requests / follow-ups:** rules (via godot-b0): R2's `Tank.short_halting()` must not read as a stall. When R2 merges, my
  `_unstick` stall clock skips a short-halting hull, and native mirrors that in its unstick twin (a request to native then).
- **Parked yielders (godot-b0's question, from orders' O2 probe):** round 36's S4 trace (55c973cd4, builder0 light, 16 looping
  squads): 124 of 172 give-ways (72 %) had a yielder within 10 m of its seat; 44 of those were sent >= 10 m away. The give-way
  block is mine this round, so I can take a "parked crews step aside and come back, or passers go round" item if it is ruled.
