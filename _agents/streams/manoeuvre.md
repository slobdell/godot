# Stream: manoeuvre (a long truck wedged against a wall backs out instead of sitting at full throttle; wheeled turret vehicles end nose-on to the facing you draw; the creep judged on an honest base)

> Read `_agents/orchestration.md` (the worker contract; lessons 295–305), `_agents/game_design.md` *Round 28 direction*
> (his call 2) and *Round 26 direction* (three-point turns), `_agents/workstreams.md` **Round 30** (C30.1–C30.10,
> especially **C30.5** and **C30.6**), and round 29's manoeuvre report (`streams/archive/round29/manoeuvre.md`: *Final
> report*, *Requests and round-30 leads*; round 28's `streams/archive/round28/manoeuvre.md` for M1's trace). **You own:**
> in `game/ai/movement.gd` the body of `drive()`, `_nose_stop`, `unstick`, `_pressing_escape`, `_manoeuvre`, the k-turn /
> planned-reverse / circle block (`kturn_on` through `_look_stop`); `game/ai/manoeuvre*.gd`, `game/ai/clothoid.gd`,
> `game/ai/wall_contact.gd`; in `game/ai/order_controller.gd` ONLY the face-at-rest path (`_same_face`, `face_giveup_on`,
> `_face_giving_up`, the face branch of `_apply_move`; native keeps its seams); `tests/test_manoeuvre*.gd`,
> `tests/test_kturn*.gd`, `tests/manoeuvre/**`, `tests/ai_scenarios/scenario_manoeuvre*.gd`, `mk/manoeuvre.mk`.
> **Granted:** round 28's three lines in `TankBrain._order_move`; **C30.6**: ONE new member in `game/tank/tank.gd` beside
> `estimated_velocity` (~721), `real_velocity`, behind `--tank-off=real_velocity` (nothing else in `game/tank/**`).
> Traffic's gate lines at your `unstick`, `_pressing_escape` and k-turn entry stay as the first lines. **The C++ (C30.2):**
> the drive, the unstick and the tank's velocity lines have C++ twins; develop on the GDScript path, send native each
> settled diff before the commit. **Model:** this stream runs on **Fable 5.1** — this problem has failed its bar three
> rounds running (M1 ×2, M2 ×2, M4), and it is the one he named as lingering.

## The lead's direction

**Round 28, his call (2026-10-12): TURN THE WHOLE VEHICLE** (`turret-hull-facing` = turn-hull): a wheeled vehicle with a
turret turns its whole hull to a drawn facing, so its front armour faces where he pointed, "a few seconds longer on
arrival". Round 26, on three-point turns: a stuck vehicle should make a planned three-point turn, not shuffle back and
forth. **Round 30 (2026-10-14), his ask for Fable:** *"hard or lingering problems that we can throw at Fable to mitigate
any bottlenecks in our project"* — this stream is one of them (the planner stream is the other half: C30.4).

What he will notice: a 10 m truck pushed nose-first into a wall backs out and goes round instead of sitting at full
throttle, so Terminus columns arrive whole. Draw a facing for gun trucks or IFVs and they end nose-on to it a few seconds
after they arrive. In a tight street a long truck turns in two or three deliberate legs instead of creeping.

## Where things stand (main `0d35f215`, GREEN: builder0 2584/0, 26 ALL JUDGED)

Nothing of yours shipped in round 29; each candidate is parked with its judged table (`references/round29/manoeuvre/`):

- **M4 (`manoeuvre-m4-r29`, `9db2a57c`) — the wedge cause and a failed fix.** Cause: `game/tank/tank.gd` ~721 sets
  `estimated_velocity = velocity` after `move_and_slide`, which returns the WANTED velocity when the slide is fully
  blocked, so a pinned truck reports 12 m/s at zero displacement and `unstick` never fires. The fix tried (A: make
  `estimated_velocity` the real displacement) PASSED the pinned probe (pinned crew-s 2902 → 1040, se 460) and the fights
  guard, but FAILED Terminus (rigs arrived 81 → 64/96, rig wall contact-ticks 5337 → 8542) and bridge-pooled 17/18:
  **the honest velocity zeroes wheels' `_speed` on every wall brush, so rigs grind along walls instead of sliding off.**
  Tests ready on the branch: `tests/test_manoeuvre_wedge.gd` (a pinned truck 0.00 v 12.00 m/s), `pinned_table.py`,
  `make manoeuvre-fights`.
- **M1 (`manoeuvre-m1-r29`, `d7385da2`; `manoeuvre-m1-pointonly`) — turn the hull: so close.** Point tasks at rest
  3.2–3.3° median, 80–82 % within 15° (base 41–59°, 14–32 %); line tasks = hover/turret; settle +0. MISSED: the 75 s
  moving-at-judge guard on attack-move +8 (98 v 90; wheeled turret +12, se 8.9) and support by fire +8; clicked medians
  outside ±5° on 4 tasks (3 of them LOWER error). **The clicked pair, where M1 never acts, moved the same class +10, so
  that guard's noise is about ±10 at n = 288** (round 28's re-run on the same seeds swung ±17): the guard was below the
  noise. And **`face_slot` is a bug fix on its own:** round 28's faceslot read `mover._goal`, which `Movement.idle()`
  wipes, so it never anchored; with it, clicked faces improve too (support by fire −17.8°, p 0.02).
- **M2 (`manoeuvre-m2-r29`, `7b895eed`) — the creep lift.** Open+static creep 125 → 75 (−40 % v a −50 % bar); rigs' wall
  contact-ticks 3938 → 6494 (the lift rolls long rigs into street walls). The long pins traced in M2's runs were NOT creep
  but M4's wedge, so M2's base is confounded until M4b ships.
- **M5 — the Terminus escape (from brains' B5c worst run, C30.5):** Terminus seed 3, B_4, 9 m from its east-facing slot,
  sent 17.5 m back to a gate by the west edge, reaches it (latched) and **jams on terrain ~8 s**. Brains owns the gate's
  placement; the escape from terrain a wheeled hull is jammed on is yours.
- Known (not yours): at hull-rest 18–28 wheels/turret crews a task are still DRIVING to their slots at 75 s even at base
  (formation/traffic); the hull-rest screen probe runs in real time (read classes over an arm).
- `wall_contact.gd` was not touched in round 29; native's N7.4 observer is ported and OFF by its price.

## Backlog (in order)

**M4b — the real displacement to the progress readers only (DECLARED; CP-M4b; a pair with native).** Design (B) from
round 29's report: keep the plant's `_speed` and `estimated_velocity` exactly as today; add `real_velocity` in `tank.gd`
(C30.6: the flat displacement a tick ÷ dt, capped at the asked planar speed, `--tank-off=real_velocity` makes it equal
`estimated_velocity`); make `unstick`, `_pressing_escape` and the pinned probe judge progress by `real_velocity`; aim
leads read it too (say which gunnery lines, and send native the diff). Test first: `test_manoeuvre_wedge` (pinned truck
reads 0.00 by the readers, 12.00 by the plant), plus a wall-brush test (a rig sliding along a wall keeps `_speed`).
**Bar (send before numbers; last attempt named; fresh seeds; cite sizing's rows if CP-N has landed):** round 29's M4
bar: (b1) Terminus census rig wall+hull contact-ticks DOWN and arrivals ≥ base, also with each arm's two worst runs
dropped; (b2) pinned crew-seconds (hull-rest probe) down by > 2 se paired; (b3) bridge-pooled 18/18; (b4) tank segment
reported; fights guard (`manoeuvre-fights`, 180 s): kills, deaths, hit rate within 2 se paired, hit rate on touching
targets reported; net-smoke, combat-smoke, determinism; the thirteen re-recorded twice with the reason if they move;
a tracked row. **Added:** a rig's mean speed along a wall brush within 2 se of base (the thing (A) broke). Native ports
the `tank.gd` line in `tank_drive_native` as a pair; after the pair, Terminus + bridge-pooled on the default path.

**M1b — `face_slot` alone, then turn-hull with a guard sized to the noise.**
(1) `face_slot` as its own DECLARED bug fix (`--nav-off=faceslot`): bar = hull-rest fresh seeds, every class, every task:
at-rest medians ≤ base, clicked support-by-fire error down (the p 0.02 finding reproduced on fresh seeds or stated NOT
reproduced), the 75 s moving-at-judge count within the measured noise (below), bridge-pooled 18/18, ≤ 0.5 ms.
(2) Turn-hull (`turnhull`, `facekeep`) re-judged with the guard WRITTEN FROM MEASURED NOISE: run two BASE arms on the
fresh seeds first (an A/A pair; cite sizing's CP-N row if it has landed, C30.3), set the 75 s guard at base + 2 se of
that pair (not +5 by feel), state n, and only then run the candidate. Point tasks median ≤ 15° and ≥ 70 % within 15° of
crews at rest; line tasks = hover/turret ±5°; wheeled-turret at-rest share not down > 5 pts; settle ≤ +6 s; the guard
on every task; clicked within the A/A noise. Partial rule as round 29's (point tasks only). Last attempt named.

**M2b — the creep lift on top of M4b (DECLARED).** Re-base `manoeuvre-m2-r29` on main after CP-M4b; re-judge with round
29's M2 bar (open+static creep −≥ 50 %; > 3-leg episodes not up; Terminus arrivals ≥ base and wall contact-ticks ≤ base +
10 %; bridge-pooled 18/18; ≤ 0.5 ms; symmetric; friendly creep not up > 10 %; the rigs' wall-contact direction explained),
fresh census seeds. If the lift still rolls rigs into walls, say so with the trace and park it for the planner (C30.4):
that is a finding, not a failure.

**M5 — the Terminus escape (DECLARED; C30.5).** Reproduce brains' worst run (`lab/brains-r29-gate`'s rule ON, Terminus
seed 3, B_4) on your path; trace what the hull does for those ~8 s (throttle, `_speed`, `real_velocity` after M4b,
unstick/k-turn state, wall contact); design the escape (a planned reverse out of terrain contact; the k-turn with a
terrain-aware leg); bar from the trace: that run's jam ≤ 2 s, Terminus census arrivals ≥ base, contact-ticks ≤ base,
bridge-pooled 18/18, fights guard. Tell the orchestrator what the gate did to the hull (brains needs it for B5c-v4).

**For the planner (C30.4; not code):** when `godot-planner` asks (through the orchestrator) for traces, give the three it
names from your branches (a creep episode, a wedge, a boxed-in face leg) with the commands that reproduce them. Read its
design doc when it lands and write one paragraph in your Status: what of it you would wire in first and where.

## How to verify

`make remote T=check` (builder0 only, C30.7); `make manoeuvre-hull-rest`, `manoeuvre-hull-one`, `manoeuvre-fights` (on `manoeuvre-m4-r29` until you merge it in),
`manoeuvre-census` (`--turn-trace`, `--turn-states`), the Terminus census (`nav-terminus-drive`), `bridge-pooled`, `native-verify-scenarios`;
`tests/manoeuvre/hull_rest_ab.py`, `pinned_table.py`. Screenshots/clips of a wedged truck before and after M4b for him.
Every number carries its commit, machine, workload and n; the worst run's trace before the median.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; brains' `_track_progress`, `_update_phase`, `_approach_gate`, elements,
`game/tactics/**`, `tank_brain.gd` beyond the three granted lines; native's `native/**`; `game/tank/**` beyond C30.6's
one member; `game/control/**`; the planner's `game/ai/planner/**` and sizing's `tools/judge/**`.

## Waiting on the lead

Nothing: his calls are made (turn the whole hull; planned turns).

## Status

_Updated 2026-10-14 by the manoeuvre worker (`godot-manoeuvre-65`, `stream/manoeuvre`, from main `bd05077d` = code
`0d35f215`, GREEN). Round 30, Fable 5.1. Report at the top; the progress log below it._

### Report (2026-10-14, running; the final numbers land as each judged chain closes)

| item | candidate (branch) | state |
|---|---|---|
| M4b run 1 | `e8bfef2e` (`stream/manoeuvre`, judged tree `1b3e2e56`) | NOT PASSED (orchestrator's ruling): rigs arrivals −1.1 se, rigs' wall contact-ticks +141 % |
| M4b run 2, the last | `77a1603f` (`lab/manoeuvre-m4b2`): escapes only for hulls ≤ 10 m | passed every filed line, then its PAIR CHECK went red on two tests (traced: the escape's reverse on lock in single file; a `drive` order's hull backing off): **the ESCAPES are PARKED for round 31** (ruled ~16:45 PDT) with the findings and the design note |
| **M4b reader (SHIPS)** | **`8cbdcfad`** (`lab/manoeuvre-m4b-reader`): `Tank.real_velocity`, the census `real` column, the probe's honest class; nothing in play reads it | **the pair is GREEN: native's `3bc2c476` = `8cbdcfad` + the one `tank_drive_native` write; builder0 `make check exited 0`, 2606 passed / 0 failed, ALL JUDGED, the thirteen unmoved, twin tests 0 mismatches (native, ~18:20 PDT). My branch's tests 20/0 (wedge, wall_contact, mixed_legs). Merge `3bc2c476`.** |
| M1b(1) face_slot | `55622870` (`lab/manoeuvre-m1b`, on `8cbdcfad`) | tests re-running on the rebase, then its judged chain (GO) |
| M2b creep lift + kturnarc | `1f1c9835` (`lab/manoeuvre-m2b`, on `8cbdcfad`) | tests re-running on the rebase, then its judged chain after M1b's (GO) |
| M5 the Terminus escape | `34f34ea0` (`lab/manoeuvre-m5`, parked) | PARKED with the finding: case 1 closed by brains' v4, case 2 is the planner's F4 |

**Decisions:** design B kept exactly (C30.6); the escapes sized to the plant's momentum (run 1) and then gated to
hulls ≤ 10 m (run 2); M1b/M2b stacked on M4b (M2b's arc rule reads `real_velocity`); the planner's four executor
findings taken (two in M2b behind `kturnarc`, two as M2b's design). **Questions for the lead:** none (his calls are
made). **Requests to other streams:** traffic: `avoidance.gd` reads neighbours' `estimated_velocity`, a pinned hull is
a 12 m/s ghost to ORCA (routed by the orchestrator to traffic's next item); brains: nothing (M5 case 1 is theirs and
done); planner: the seed-31 grind trace and the F4 case. **Known issues:** the plant's yaw fit is OFF by default so a
pinned hull yaws through what pins it (Status finding); a freed hull with no way round loops back into its blocker
(mixed seed 21's IFV, 73 s). **What to playtest (once the pair is on main, `make native && make skirmish`):** send a squad of IFVs or scouts
through a Terminus street with a parked squadmate in the way, or watch a tight formation seat: a hull pinned nose-on
to another no longer sits at full throttle, it backs off within ~2 s and goes round (pinned crew-seconds −75 % on the
hull-rest probe, −100 % of the ≥ 10 s pins on the Terminus drive); gun trucks and War Rigs drive exactly as before. **Merge notes:** the M4b reader `8cbdcfad` with native's `pair/m4b-reader` (no twin test red: Movement and
Gunnery are main's); then M1b(1) `55622870`, then M2b `1f1c9835`, each alone, both on `8cbdcfad`; the stream branch
(`stream/manoeuvre`, docs and tooling: Status, judged tables, pinned_table, mk) for the record. Parked, kept:
`lab/manoeuvre-m4b2` `77a1603f` (the escapes, judged twice), `lab/manoeuvre-m5` `34f34ea0`. Lab worktrees `godot-manoeuvre-{m1,m2,m5,v2}` and their
builder0 folders to remove at the close.

### Plan (smallest foundation first)

1. **M4b** — `real_velocity` (C30.6) + the readers (`unstick`, the pinned probe's state line, gunnery's two lead lines)
   + **the escape sized to the plant's momentum** (`--nav-off=unstickback`), because the honest reader alone frees
   nothing: see *Design* below. Tests first (`tests/test_manoeuvre_wedge.gd`), tuning seeds, the bar to the
   orchestrator, then the judged run; the diff to native before the commit (C30.2).
2. **M1b(1)** `face_slot` alone as a bug fix; **M1b(2)** turn-hull with the A/A-sized guard.
3. **M2b** the creep lift re-based on M4b.
4. **M5** the Terminus escape (trace first; brains' B_4 run).
5. Planner traces when asked (C30.4).

### Design: why M4b is more than the reader (decided before any run; reversible)

The plant's `_speed` on a pinned wheeled hull is the phantom 12 m/s (design B keeps it, C30.6). The stall escape
(`_unstick`) reverses for `UNSTICK_SECONDS` = 0.9 s: a rig (`gang_tank`, braking 8 m/s²) needs 1.5 s only to brake
that phantom momentum to zero, so a 0.9 s reverse never moves it (the velocity asked stays forward, blocked); the
route then resumes, `_speed` climbs back, the stall rule fires again a second later. The same for the pressed-wall
escape (`PRESS_ESCAPE_MAX_S` 2.0 s: ~0.6 m of the 1.5 m it wants). Round 29's (A) freed hulls because it zeroed
`_speed` too (and broke brushes). So M4b = the honest reader **and** escapes that hold reverse until the hull has
REALLY backed off (`UNSTICK_BACKOFF_M`), with the time cap extended by the momentum to shed (|speed|/braking).
`_pressing_escape` already judges progress by net displacement (round 10), so it keeps that; only its cap is sized.
If the tuning seeds show rigs still sitting, the next (not granted) step is the plant losing its momentum on a PIN
only (real < 25 % of asked), never on a brush: a request through the orchestrator with the trace, not a unilateral
edit of `tank.gd`.

### M4b bar (DECLARED; to the orchestrator before any judged number; round 29's M4 bar carried, plus the brush line)

Candidate: `stream/manoeuvre` at the hash named when sent; GDScript path (`--brains-off=native`) both arms; base arm =
`--tank-off=real_velocity --nav-off=unstickback` on the same commit. **Last attempt: this is the first run of M4b; a
second run on fresh seeds would be the last.** Sizes are round 29's (CP-N not landed; re-sized once in writing if it
lands first, C30.3). Tuning seeds: Terminus 20–22, hull-rest 40–41 (one faction), fights 1–8. **Judged, fresh:**
Terminus 23–28 (mixed and rigs apart), hull-rest 42–47 (4 factions × 6 tasks, drawn, `--turn-states`), fights 133–156.
- (b1) Terminus census (`nav-terminus-drive`): rigs' wall contact-ticks DOWN and arrivals ≥ base, with and without
  each arm's two worst runs dropped; mixed arrivals ≥ base − 2 and contact-ticks ≤ base + 10 %. The arm's own counters
  (`unstick_fires`, `press_escapes`) reported: a candidate that never fires is null (lesson 300).
- (b2) Pinned crew-seconds (`pinned_table.py` on hull-rest, by command and real displacement) DOWN by > 2 se paired; the
  pinned-crew count reported.
- (b3) `bridge-pooled` 18/18.
- (b4) The tank segment (`tracks`) reported apart in (b2).
- (b5) **The brush line:** a rig's mean speed while touching a wall (Terminus rigs, `MANOEUVRE_STATE` `v` while
  `touch true`) within 2 se of base (the thing (A) broke).
- Fights guard (`manoeuvre-fights`, 180 s, 24 seeds): kills, deaths, hit rate within 2 se paired; hit rate on touching
  targets reported (the lead change should move it UP or not at all).
- net-smoke, combat-smoke, determinism green; the thirteen re-recorded twice with the reason if they move (a changed
  stall reading moves the sim); ≤ 0.5 ms a tick (`sim-profile`); a tracked row.
- Partial rule: (b1) is the gate (it is what he sees). (b2) missed with (b1) met = ship, with the miss written down.
  (b1) missed = nothing ships; the trace of the worst run goes to the planner (C30.4).
- After native's pair: Terminus + bridge-pooled once on the default (native) path, equal for run.

**Re-sized ONCE from CP-N (C30.3; `judging.md` on `stream/sizing` `44a8b95a`), before any judged run, 2026-10-14:**
- (b1) is judged on **Terminus ARRIVALS** over **13 seeds (23–35)**, rigs and mixed apart: the paired total NOT DOWN
  beyond 1 se (the table: rigs sd 1.94 a seed, −10 % needs 13 seeds; mixed sd 1.47, 8); DOWN beyond 2 se = the gate
  missed. Wall contact-ticks and the arm's counters are REPORTED, not judged (MDE +127 % at any affordable n).
- (b2) pinned crew-seconds at **n = 144 runs** (4 factions × 6 seeds × 6 tasks): the table decides −50 % at n ≈ 90
  (sd 38.3 a run, se 460 on base 2902), so 144 decides about −40 %; the line stays DOWN beyond 2 se paired.
- Fights at **24 seeds**: kills and deaths within 2 se decide a 5–6 % loss (n = 28 for 5 %); the hit-rate guard decides
  about −3 pts at 24 (−2 needs 54): the line stays within 2 se, read with that MDE.
- (b5) the brush speed has no row: reported with its paired se (a first measurement, not a decided line).
- (f) (the orchestrator's addition) each stall escape's END is counted: by the real 1.5 m backoff (`unstick_backed`)
  or by the time cap (`unstick_capped`), reported per arm; an escape that mostly caps is a finding.
- (g) `real_velocity` and `unstickback` are ONE declared change (the reading alone is a no-op for rigs): both switches
  in the merge message, both in native's one pair.
- (h) mixed arrivals: the table has the row (sd 1.47 a seed): the line is ≥ base − 1.645 se over the 13 seeds.
- (b3) bridge-pooled 18/18: a 17/18 against 18/18 is "a coin" by the table's McNemar row; read the cell's trace
  (lesson 302) before calling it either way.

### M1b(1) bar (DECLARED; the face_slot bug fix alone; to the orchestrator before any judged number)

Candidate `lab/manoeuvre-m1b` `37c47851` (= M4b `e8bfef2e` + the fix; both arms carry M4b, so the A/B isolates the
anchor); base arm `--nav-off=faceslot` on the same commit; GDScript path. No turn-hull, no facekeep. **First run;
a second on fresh seeds would be the last.** Sized from CP-N (`judging.md`), early stop by `tools/judge/sequential.py`
where it has a row (the Terminus arrivals guard); the hull-rest probe runs its full grid.
- (a) hull-rest, fresh seeds **48–53**, 4 factions × 6 tasks, DRAWN and CLICKED × new/base, `--turn-states` (576 runs):
  the at-rest hull-error median per class × task not WORSE with permutation p < 0.05 (the table's A/A: ±5° is inside
  the noise, so p, not degrees), drawn and clicked both (the fix acts on every face at rest).
- (b) crews still moving at 75 s per task ≤ base + 2 se (`M1_CLASS`'s paired se quoted; the table: ~+12 wheeled
  turret, ~+15 all classes at n = 27), all classes and wheeled turret.
- (c) REPORTED: the clicked support-by-fire error (round 29's −17.8°, p 0.02) reproduced on fresh seeds (p < 0.05) or
  stated NOT reproduced; settle at 75 s (censored, per sizing); `face_slot_kept` / `face_slot_refused` > 0 in the new
  arm (lesson 300: the anchor acted).
- (d) Terminus census, rigs and mixed, **13 fresh seeds 36–48**: arrivals not down beyond 1 se (sequential.py
  `arrived:guard:0.10`, stop on SERIES PASS/FAIL, never before 6 seeds); wall contact-ticks reported; "a face left the
  slot" misses (a leg miss under a face order, `gap_m` > the settle radius) counted both arms, reported.
- (e) bridge-pooled 18/18; net-smoke, combat-smoke, determinism; the thirteen re-recorded twice with the reason if
  they move (a face plan's end moves the sim); ≤ 0.5 ms a tick (`sim-profile`); native told (plan_face is GDScript on
  both paths: no port expected, confirmed with `native-verify-scenarios`).
- Partial rule: none (a bug fix): any judged line missed = not shipped, the finding written down.
- **Accepted by the orchestrator with:** (f) judged on top of M4b, so it merges only after M4b's pair; if M4b fails its
  gate, re-base on main and re-run the hull-rest lines before any merge; (g) the project's first early stop: the row
  where `sequential.py` printed SERIES PASS/FAIL and the n reached go in this Status; (h) rigs seed 21 (the defect in
  the wild) re-run on the candidate and reported.

### M2b bar (DECLARED; the creep lift on top of M4b + the executor's arc and stopping fixes; before any judged number)

Candidate `lab/manoeuvre-m2b` (hash named when its tests are green; = M4b + `creeplift` re-based + `kturnarc`); base
arm `--nav-off=creeplift,kturnarc` on the same commit (both arms carry M4b); GDScript path. Two switches, ONE declared
change (the lift's legs end where the planner said only with the arc rule). **First run; a second on fresh seeds
would be the last.** Sized from CP-N where it has a row; the turn census has none ("Poisson floors"): it runs its
full grid and owes the A/A, with per-run rows (`census_table.py --jsonl`, sizing's request) so the next table can
size it.
- (a) open+static creep episodes (the turn census, `MANOEUVRE_TURN` kind open/static, cause creep) DOWN ≥ 50 % over
  fresh census seeds **14–19** (Terminus mixed+rigs, `--turn-log`) + sim **9–11**, paired per run; the paired se
  reported (round 29: 125 → 75, −40 %).
- (b) episodes over 3 legs not UP beyond 2 se paired; the friendly-kind creep not up > 10 % (reported with se).
- (c) Terminus census arrivals, rigs and mixed, **13 fresh seeds 49–61**: not down beyond 1 se (sequential.py
  `arrived:guard:0.10`, stop on SERIES PASS/FAIL, never before 6 seeds); wall contact-ticks REPORTED, and the rigs'
  wall-contact direction explained from the worst run's trace (round 29: the lift rolled rigs into street walls).
- (d) `kturnarc`: legs' driven ÷ planned metres reported both arms (1.03 → 1.00 expected), `kturn_aborted` not up.
- (e) bridge-pooled 18/18; ≤ 0.5 ms a tick (`m2_us` per tick + `sim-profile`); symmetric (the CPU drives the same
  code); net-smoke, combat-smoke, determinism; the thirteen re-recorded twice with the reason if they move; the arm's
  counters (`creep_lifts`, `creep_lift_why`) in the new arm.
- Partial rule: (a) missed with (c) met = the finding (the lift rolls long rigs into walls or does not) goes to the
  planner (C30.4) and nothing ships; (c) missed = nothing ships. `kturnarc` alone cannot ship under this bar (it is
  judged with the lift); if the lift fails, `kturnarc` is re-declared alone with (c), (d), (e).
- **Accepted by the orchestrator with:** (f) the base arm's switch list is ONE `--nav-off=` flag, printed by every run
  (the chain's `>> remote: make … NAV_FLAGS=…` line); (g) (a) has no sized row, so this census pair IS its A/A: both
  arms' per-run rows go to sizing's `probes.py` at the close whatever the verdict; (h) the rigs' wall contact-ticks
  under the lift, with and without each arm's two worst runs, beside (c) (round 29's M2 failed on exactly that);
  (i) merges only after M4b's pair, as M1b(1). **Process gate: if M4b's (b1) fails, stop before M1b's chain runs**
  (M1b/M2b re-base on main in that case).

### M4b, the SECOND and LAST attempt (DECLARED; to the orchestrator before any judged number)

**The orchestrator's ruling on run 1 (2026-10-14 ~14:15 PDT):** NOT PASSED: (b1) rigs −1.1 se, and the reported rigs'
contact-ticks +141 % are round 29's regression in a new form. One second run allowed, the last; its bar = the filed
lines PLUS the contact-ticks JUDGED; M1b/M2b held behind it; native's port waits.

**The narrow fix:** `UNSTICK_BLIND_MAX_LEN_M` = 10 m in `Movement._unstick` (`_blind_escape_ok()`, by
`hull_box(unit_id)[2]`): the honest stall reading and the momentum-sized escapes apply to hulls that can back out of
a street in one blind reverse (scouts, IFVs, lancers, artillery, the 8×8s); the War Rig (14 m) keeps round 29's
reading and 0.9 s escape BIT FOR BIT (its way out of a 20 m street is a planned turn: the planner's F2/F6, round 31).
`real_velocity` itself, the census line, the pinned probe and gunnery's leads are unchanged (all hulls).
Candidate `lab/manoeuvre-m4b2` (hash named when its tests are green); base arm `--tank-off=real_velocity
--nav-off=unstickback` on the same commit, GDScript path. **Fresh seeds:** Terminus **62–74** (13), hull-rest
**54–59** (4 factions × 6 tasks, drawn, 144 runs), fights **157–180** (24), bridge-pooled.
- (b1) Terminus arrivals, rigs and mixed apart: not down beyond 1.645 se paired (sequential.py `arrived:guard:0.10`
  as the early-stop rule, never before 6 seeds).
- (b1') JUDGED now: wall contact-ticks, rigs AND mixed apart, ≤ base + 1.645 se paired, with and without each arm's
  two worst runs. With the gate exact, a rig run is a deterministic replica of its base run (diff 0, se 0): any
  non-zero rig difference is a leak of the change into rigs and is reported as such; the mixed line carries the
  judgment (run 1: +17 %, 1.7 se).
- (b2) pinned crew-seconds (hull-rest, by command and real displacement) DOWN beyond 2 se paired at n = 144 (the
  table: decides −50 % at 90); the STUCK row and tracks apart REPORTED.
- (b3) bridge-pooled 18/18 (a 17/18 read by the cell's trace). (b4) tracks apart. (b5) brush speed reported with se.
- (f) escape ends counted (backed v capped) per arm; (g) ONE declared change (`real_velocity`, `unstickback`, the
  gate); (h) as filed. Fights guard at 24 seeds: kills, deaths within 2 se (decides a 5–6 % loss), hit rate within
  2 se (decides ~−3 pts), hit rate on touching targets reported. Smokes, determinism, the thirteen re-recorded twice
  with the reason if they move, ≤ 0.5 ms, a tracked row.
- Partial rule: (b1) and (b1') are the gate (rigs and mixed, all four lines); (b2) missed with the gate met = ship
  with the miss written down; any gate line missed = M4b parked with the finding, and `real_velocity` to the pinned
  PROBE only (no behaviour change) offered as a measurement commit.
- **Accepted by the orchestrator with:** (i) every rig run byte-identical to its paired base run is a PASS LINE (one
  leak = the gate missed); (j) (b2) read on the hulls the fix reaches (≤ 10 m) AND on rigs apart (rigs' pins must be
  unchanged, stated); (k) M4b's record chain stopped at once (done 14:20 PDT: the local chain and its builder0
  processes, cwd-verified `~/tank_squad/godot-manoeuvre`, killed; bridge/fights/hull-rest of run 1 not taken).
- **For round 31's planner hand-over (the findings):** (i) under the creep lift, M2b's rigs seed 51, Green_S0_3: 50 s
  grinding the plaza-crossing wall at throttle 0.8 / lock 0.44, plant speed 9.4, goal 24 m away throughout (the lift
  rolled an earlier turn and the rig met the wall at an angle: the planner's F1, a corner creep is one forward arc or
  one back-up chosen by geometry); (ii) under M4b's escapes, rigs seed 31, Green_S0_2, ticks 3120–5430: 77 s grinding the
  west street wall after a freed pin (plant speed 10.7, real 0.1–3 m/s jittering, throttle 0.9, goal 25–29 m away,
  neither the stall rule nor the press escape reads it as stuck); the log is `references/round30/manoeuvre/`'s
  `m4b_run1_rigs31_new.log` (copied at the close).

### The planner's P1, read (C30.4; `stream/planner` `e63a3099`, `references/round30/planner/{problem,design}.md`)

**What I would wire first, and where:** the wedge-between-hulls escape, at the stall rule's firing point in `_unstick`
(movement.gd ~3075, the line that today sets `_unstick_left` and reverses blind on `turn 1.0`). When the honest reader
says "pinned" and `_hull_within` finds no hull behind, call `Planner.plan` with a goal pose = the route carrot 10–15 m
ahead on the current heading, the two touching hulls as OBBs (`PlannerWorld` from `Manoeuvre._others` + the slide
colliders), `arrive_gear any`, budget 500, and drive the `legs` through `_kturn_start_leg` with the new
`Vector3(gear, steer, metres)` (steer replaces the one lock); `NO_PATH` = today's blind reverse (so nothing is lost),
and the escape's `_unstick_from` backoff ends the leg as now. Why there and not the face or the creep: it is the only
seam where today's rule has NO geometric answer at all (the planner's own §4.2 reading: "reverse on the lock that
swings the nose clear, then forward"), it fires on an EVENT (a pin) not per tick, and M4b already puts the trigger and
the counters in place, so round 31's A/B is `unstick_fires` → `planner_escapes` on the same Terminus census. The face
(F3) second, through `plan_face`'s leg list (same `Vector3` legs), only once the one-at-a-time ordering of a packed
line is settled (who goes first is formation geometry, brains' C30.8). I agree with every P0 finding; one addition
for the planner's F2: the pinned rig's throttle was 0.57, and the stall rule asks > 0.5, so a hull pinned on a HULL at
the pursuit law's hard-turn 0.35 is reached by neither rule today (the pressed-wall escape needs a wall); M4b's
census reports pins by command AND real displacement so that gap is counted, and I will widen the stall rule to
hull contacts if the tuning seeds show it (a line in `_unstick`, mine).

**The planner's four executor findings (P4, `stream/planner` `8f73e4cd`), read:** all four are in my k-turn / face
executor and I take them: (4) the leg measured by the ARC not the chord (`_planned_reverse` reads `backed` as the flat
distance from `_kturn_from`, 3 % short on a 10 m leg) is a plain bug fix: **folded into M2b's bar behind its own switch (`kturnarc`)**,
reported apart in M2b's census (legs per episode, driven metres), not DECLARED alone; (3) the discrete stopping
distance v²/2b − v·dt/2 goes with it (same switch: both are "a leg ends where the plan said"); (1) brake on the
leg's own lock with the opposite throttle and (2) never zero throttle with the lock on (the face executor's zero/zero
end IS the plant's creep) are M2b's design, the creep-as-legs item, where they are judged by the creep bar.

**M5, second case (brains, B5c-v4 judged PASS):** yard crossing seed 25 tick 1, rule on: B_4 overshot when the
squad's shape changed (seat 8 m behind it), no gate, its U-turn ran onto terrain ~8 s. Reproduce with brains'
`gate-series` on `lab/brains-r30-gate` (yard_open cross, seed 25, tick 1, rule on) when M5 opens; the Terminus s3
B_4 case stands first.

### M5 — PARKED with the finding (2026-10-14 ~14:24 PDT; `lab/manoeuvre-m5` keeps the trace tooling and the candidate)

Both of brains' cases reproduced on my path (lab worktree = `lab/brains-r30-gate` merged with the stream, builder0 light
lane, n = 1 each, `reseat-trace`): (1) **Terminus head-on seed 3 tick 11, B_4: no jam under B5c-v4** (all 10 arrive, B_4
at 41.2 s, no stall, no escape, no terrain block in 55 state rows; the 8 s jam was round 29's gate). (2) **Yard crossing
seed 25 tick 1, B_4 (a car): a 180° onto a slot 9 m behind it, re-tasked at 4.9 m/s with a facing that wants the nose**
(so round 26's reverse is refused, `facing_nose`): the pursuit law drives a full-lock forward loop 15 m out, the slot
lands inside the turning circle, and Steering's reactive circle rule shuffles it in: six cusps, 11 s (ticks 435–780),
`phase blocked terrain` the whole time though nothing blocks it. The planned circle (`_plan_circle`, one back-up then
the away arc) never runs for it: `_away_here()` gates every planned leg to hulls ≥ 10 m since round 26 (the mixed
squad took 14 % more contacts with it on), and it is gated to |speed| < 1.5 m/s besides. The candidate built
(`circlebrake`: a moving hull with its point inside its circle brakes on the lock with the opposite throttle, then plans
the one back-up; `tests/test_manoeuvre_circle_brake.gd`) is therefore unreached for cars, and enabling the planned
circle for cars re-opens round 26's measured harm. **The answer is the planner's F4 (a goal POSE 9 m away: 2–3 legs,
~15 m), round 31; not a rule in the k-turn block.** Nothing declared; nothing merges. For the lead: the car he would
see turning round in six goes is not stuck, it is turning badly.

### Design note for round 31 (traffic's T4 question, relayed by the orchestrator): a War Rig pressed against a FRIEND

Traffic's finding (T4 tuning on `77a1603f`, Terminus 21–23): with ORCA reading `real_velocity`, mixed stuck 198 → 86
crew-s and the mixed-21 IFV's loop gone, but a rig pressed against a squadmate sits 55 s (real 0, estimated 12,
`touch false`, stall clock 0) because M4b run 2 keeps a > 10 m hull's stall clock on `estimated_velocity`.
**Answer: yes, read `real_velocity` for the rig's stall clock when the blocker is a HULL (`touch false` with a slide
collision whose collider is a Tank: the planner's "colliders are Tanks" case), keep today's reading against walls —
but what fires must not be run 1's escape.** Run 1 punished a 14 m hull's blind reverse ON LOCK (turn 1.0) in a 20 m
street: it swung the tail across the street and re-approached the wall at an angle, then ground there. For a rig
against a friend the escape is: (1) ASK first (`_ask_behind` / traffic's give-way: the friend has the short hull and
the room; this is the planner's reading too, "an honest NO_PATH the layer above can act on"); (2) if the friend does
not clear within ~2 s, a STRAIGHT reverse (turn 0, no lock) of at most 3 m, only when the k-turn's outline sweep
(`_outline_ok` stepped along the straight reverse, the hull's own ten points) is clear for those 3 m, ended by the real
backoff; a straight reverse keeps a long hull parallel to the street and cannot produce run 1's angle; (3) if the
sweep refuses, report `blocked` by the friend's name (`_blocker`) so the brain re-tasks rather than press. Counters:
rig stall fires by blocker kind (hull/wall), asks, straight reverses, sweep refusals. Judged with T4 next round on the
same Terminus census: rigs' wall contact-ticks ≤ base + 1.645 se (run 2's line), rigs' pinned/stuck crew-seconds down,
arrivals not down, with the planner's F2 the long-run answer. The gate `UNSTICK_BLIND_MAX_LEN_M` then means "no reverse
on lock for a long hull", not "no stall clock".

### Progress log
- **M2b judged (`1f1c9835` on the reader base, builder0 GDScript path, 18:45 PDT): NOT MET, nothing ships as filed.**

  | line | base | new | reading |
  |---|---|---|---|
  | (a) open+static creep episodes (census 14–19 + sim 9–11, 15 runs) | 53 | 37 | −30 %, se 9.8: within 2 se; the line was −50 % — MISSED |
  | (b) episodes over 3 legs | 111 | 89 | not up; friendly episodes 90 → 100 (+11 %, se 19); creep flips 1646 → 1361 |
  | (c) Terminus rigs arrived / 208 (seeds 49–61) | 181 | 172 | −9, se 4.97: 1.8 se down, the 1.645 se line MISSED (the SPRT guard read PASS at the full grid: the two rules disagree at this n) |
  | (c) Terminus mixed arrived / 312 | 292 | 293 | PASS; SERIES PASS at run 6 of 13 |
  | rigs wall contact-ticks (reported) | 10400 | 13953 | +34 %, se 3034; rigs' k-turns 165 → 1028, kturn_multi 61 → 144 |
  | (d) kturn_aborted | 9 | 9 | not up |
  | (e) bridge-pooled; brush speed | | 18/18; +0.04 m/s se 0.47 | |
  | the lift's counters (new) | | 14727 lift unit-ticks; refused slowed 4983, no_arc 240, blocked 1765 | fired (lesson 300) |

  (h) the rigs' wall-contact direction, worst run (seed 51, Green_S0_3: 1765 of 1848 contact-ticks, 50 s on the
  plaza-crossing wall at throttle 0.8 / lock 0.44, plant speed 9.4, goal distance frozen at 24 m): the lift rolled an
  earlier turn instead of creeping it and the rig met the wall at an angle where the plant's phantom momentum grinds
  it: round 29's finding again, and M4b run 1's grind state. Per the filed partial rule the lift's finding goes to the
  planner (F1) and **`kturnarc` is re-declared alone** (base `--nav-off=creeplift,kturnarc` v new
  `--nav-off=creeplift`, Terminus fresh seeds 75–87, (c)(d)(e)); **GO ruled (18:50 PDT)**, its chain queued behind
  M1b's last arm; its merge is a pair (native knows `_kturn_arc_m`). Both arms' per-run
  census rows (`census_{base,new}.jsonl`) go to sizing's `probes.py` at the close (line (g)).
- **M1b(1) judged, Terminus (d), 13 fresh seeds 36–48, GDScript path, `55622870` on the reader base, builder0, 17:30
  PDT:** rigs arrivals 176 → 179 of 208 (+3, se 5.13, 1.645 se = 8.4: PASS), mixed 284 → 286 of 312 (+2, se 3.56:
  PASS). **The project's first early stop (line (g)):** `sequential.py --terminus … arrived:guard:0.10`, boundaries
  A +2.77 / B −1.56 (α 0.05, β 0.20), min 6 runs: rigs SERIES PASS at run 10 of 13 (seed 45, llr −1.71), mixed SERIES
  PASS at run 6 of 13 (seed 41, llr −5.60); the full 13 had been run before the read (the chain is not interactive),
  so the stop saved nothing this time and the rows are recorded for the rule's first use. Reported: wall contact-ticks
  rigs 8945 → 7662 (−14 %, se 2221), mixed 2475 → 1738 (−30 %, se 481); leg seconds rigs 1884 → 1659, mixed 1809 →
  1945; leg misses under a FACE order ("a face left the slot") rigs 19 → 21, mixed 14 → 9. **(e) bridge-pooled 18 of
  18.** Hull-rest four arms in ONE call hit builder0's 90-minute run cap (make exited 124, 18:30 PDT): `new_drawn`,
  `base_drawn`, `new_clicked` complete at 144 runs each, `base_clicked` cut at 61; the copy-back flagged 9 files
  corrupt (the runs the timeout killed mid-write). The seed-21 reruns were then refused by the wrapper's stale-run
  guard (the timed-out run's marker). Queued behind M2b's chain: `base_clicked` alone (one arm per call, ≤ 90 min;
  `REMOTE_FORCE=1` once, after a cwd-verified check that nothing of mine was alive in that folder) and the seed-21
  pair; the four-arm tables are read only once `base_clicked` is complete. Preliminary, drawn arms only (complete,
  not a verdict): at-rest medians per class × task move within noise (p 0.38–0.93), attack-move ALL 23.1 → 15.9°,
  wheels/fixed p90 61.1 → 9.2°; the clicked pair's p-values on the partial base arm are not read.
- **Brains' B6 case run on M1b (reported line):** `sbf-series` gang_ifv, seeds 1–6, drawn/none, on `55622870` +
  `stream/brains` (builder0, both arms, base `--nav-off=faceslot`): the arms' jsonl byte-identical; A_4 at arrival with
  a drawn facing 65.6–96.3° off, not moving, 2.3–3.2 m off its slot, both arms; face_slot's counters 0. A wheeled
  turret hull's drawn facing is declined by the brain until turn-hull ships, so no face runs for M1b(1) to anchor: the
  case is M1b(2)'s (turn-the-hull), not the face_slot fix.
- **M4b run 2's PAIR CHECK (native's `366b42bc`) RED on two tests, both reproduced on `77a1603f`'s GDScript path
  (builder0 light lane, 16:55 PDT; `references/round30/manoeuvre/m4b_run2_paircheck_traces.log`):**
  (2) `test_nav_wall_contact::test_a_hull_driven_at_a_wall_is_counted_as_steered_into_it`: 48 contact ticks = 32
  steer (driver drive, forward) + 16 plant (driver unstick, reverse: sweep 10, drift 6): the 9.7 m tracked tank backs
  off once the honest reading fires the stall rule after 1 s; the classification is correct, the test's "every tick is
  steer" encodes the old never-backs-off behaviour on a raw `drive` order. (1) `test_tactics_mixed_legs::
  test_four_tanks_attack_moved_across_the_sumps_arrive`: three of four 7.3 m wheeled 8×8s seat by 45 s; Green_M_3
  takes one stall escape at 48 s (v 0.01: a 0.9 s reverse on full lock) and from 57 s to the end sits 21.5 m from its
  slot at ORCA's pace (`cmd 0.07/−0.03`, plant 0.86, real 0.00, touching nothing) behind a seated squadmate, reseats 0:
  the escape's reverse on lock in single file put it at a pose the seating never recovers from (the re-seat's "slow"
  test reads `estimated_velocity`), and at 0.07 throttle no rule reads it as stuck. A real regression on a stage the
  series did not cover; the escape itself is the cause, so no fix in my paths leaves the judged rows byte-identical.
  **Recommended to the orchestrator: park the escapes for round 31 (with the design note), ship the READER as the
  measurement commit (`real_velocity`, the census line, the probe, gunnery's two leads).**
- **M4b run 2 (`77a1603f`), Terminus 13 fresh seeds 62–74, GDScript path, builder0, read 14:50 PDT — the gate PASSES:**

  | | base | new | line |
  |---|---|---|---|
  | rigs arrived / 208 | 178 | 178 | identical |
  | rigs wall contact-ticks | 13411 | 13411 | identical (two worst dropped 8286 = 8286) |
  | (i) rig runs line-for-line identical to base | | 13 of 13 | the state line's printed `real` and the summary's `off` list aside: no leak |
  | mixed arrived / 312 | 295 | 293 | −2, 1.645 se = 4.7: pass |
  | mixed wall contact-ticks | 2093 | 1915 | −8 %, 1.645 se = 423: pass (two worst dropped 1314 → 1350) |
  | mixed leg seconds | 1478 | 1534 | +4 % (reported) |
  | mixed stall fires (backed / capped), press | 11, 7 | 40 (21 / 19), 7 (6 / 1) | the cap binds for short hulls (f) |
  | brush speed while touching (n 26) | 5.37 | 5.43 | +0.07 se 0.09; touching crew-seconds 522 → 525 |

  (b3) bridge-pooled **18 of 18** on the new arm (builder0). **Fights guard (24 fresh seeds 157–180, 180 s, paired):**
  kills 967 → 971 (se 33.6), deaths 975 = 975, shots 30204 → 30252, hits 21442 → 21753 (se 1443), hit rate 0.710 =
  0.710 (se 0.018), hit rate on touching targets 0.645 → 0.670 (+2.5 pts, se 0.036: the honest lead, within 2 se); all
  within 2 se. **(b2) hull-rest fresh seeds 54–59, 4 factions × 6 tasks, drawn, n = 144 paired (16:39 PDT):**

  | pinned crew-seconds | base | new | |
  |---|---|---|---|
  | all | 2596 | 658 | −1938, se 422: DOWN beyond 2 se (−75 %) |
  | the hulls the fix reaches (≤ 10 m) | 2596 | 556 | DOWN beyond 2 se |
  | rigs apart | 0 | 102 | se 72, within 2 se: the rig's rule is unchanged (Terminus: identical); its squadmates now move differently round it |
  | scouts apart | 1179 | 268 | DOWN beyond 2 se |
  | tracks apart | 122 | 108 | within 2 se |
  | pinned crews | 65 | 14 | DOWN beyond 2 se |
  | STUCK (no 1 m of progress ≥ 10 s; reported) | 6631 | 4794 | −28 %, se 628 |

  Crews still moving at 75 s fewer on every task (screen 43 → 33, support by fire 26 → 21, move 28 → 22). **Every
  judged line of the filed bar is met.** `make check` on `77a1603f` running (the three native twin tests expected red).
- **Line (f), the cap-ended escapes traced (mixed, new arm, 13 seeds):** stall escapes by hull and ending: artillery
  3 backed / 11 capped, IFV 10 / 8, tank 2 / 0, lancer 1 / 0, scout 1 / 0. The artillery's capped ones are a FALSE
  POSITIVE of the stall rule, harmless in motion: a battery PACKING UP reads throttle 0.85 with zero motion (`Tank.
  _deploy_step` swallows the drive while the legs come up), the stall timer fills in 1 s, the escape fires (−1.0 / 1.0)
  and is swallowed the same way, the 0.9 s cap ends it (speed 0, nothing to shed), and the gun drives off normally
  once packed (mixed seed 62, Green_S0_5, ticks 810–870: `v 0.00 real 0.00 cmd 0.85/−0.61` → `cmd −1.00/1.00 esc 0.1`
  → 2.20 m/s and away at 870). A later refinement, not this run: the stall timer should not count while
  `deploy_ratio` > 0 (a gun packing or setting up is not stuck). The IFV's 8 capped escapes are the backoff-and-re-pin loop against a
  HULL (mixed seed 64, Green_S0_6, ticks 1080–1590: pinned at real 0.03 under throttle 0.8, `touch false`, the escape
  backs a little, the route drives it straight back in, again every ~7 s, goal 21–25 m away throughout): the planner's
  F2 pose, and traffic's avoidance reader (a pinned blocker is a 12 m/s ghost to ORCA), not a re-task.
- **M4b second attempt committed `lab/manoeuvre-m4b2` `77a1603f`** (wedge tests builder0 8/0); its judged chain
  started 14:25 PDT (Terminus 62–74 both arms, bridge, fights 157–180, hull-rest 54–59). Native holds its port.
- **M4b JUDGED, Terminus (b1), 13 fresh seeds 23–35, GDScript path, `e8bfef2e` (tree `1b3e2e56`), builder0, 2026-10-14
  ~14:12 PDT — the gate is NOT met; M1b's and M2b's chains held per the orchestrator's rule:**

  | | base | new | reading |
  |---|---|---|---|
  | rigs arrived / 208 | 185 | 181 | −4, se 3.72 (per-seed sd 1.03): down 1.1 se, UNDECIDED |
  | mixed arrived / 312 | 282 | 288 | +6, se 3.49 |
  | rigs wall contact-ticks (reported) | 7456 | 17970 | **+141 %, +3.1 se**; two worst dropped 4601 → 11966 |
  | rigs contacts by driver | route 6067, press 314, kturn 639 | route 15591, press 575, unstick 717 | forward-gear contacts ×2.7 |
  | mixed wall contact-ticks | 1403 | 1642 | +17 %, 1.7 se; leg time 1913 → 1646 s |
  | rigs stall fires / press escapes | 0 / 29 | 187 (185 backed, 2 capped) / 128 (127 backed) | |
  | brush speed while touching (b5) | 5.23 m/s | 5.62 | +0.39 se 0.30, within 2 se; touching crew-seconds 361 → 706 |

  Worst run (rigs seed 31: contacts 566 → 3218, arrived 15 → 13): Green_S0_2 GRINDS the west street wall for 77 s
  (ticks 3120–5430): plant speed 10.7, real 0.1–3 m/s jittering, throttle 0.9, goal distance oscillating 25–29 m,
  `touch true` throughout; the stall rule never fires (the real speed spikes above 0.8 m/s every other second and reset
  its 1 s timer) and the press escape fires every ~15 s (its 1 s window sees > 0.75 m of sideways motion). At base the
  same rig touched 10 s. Reading: the honest reader + sized escapes free PINS (the tuning held: 211 → 0 pinned
  crew-seconds), but an escape's reverse on lock and re-approach leaves a long hull at an angle to a street wall where
  the plant's phantom momentum GRINDS it (the plant's yaw fit is off: it yaws into the wall and slides), a state neither
  rule reads as stuck. Round 29's (A) regression in a new form; the three tuning seeds (contacts 1849 → 1370) were the
  +127 % MDE the table warned about. Mixed hulls (scouts, IFVs, lancers: short, fast braking) gain: arrivals +6, leg
  time −14 %.
- **M5, first reading (lab worktree `godot-manoeuvre-m5` = `lab/brains-r30-gate` merged with the stream, `15aa3f74`;
  builder0 light lane, n = 1):** brains' first case, Terminus head-on seed 3 tick 11 with the round-30 gate rule
  (`reseat-trace`, `--turn-states --turn-trace=Green_B_4`): all 10 crews arrive, B_4 at 41.2 s, no stall, no escape,
  no terrain block in its 55 state rows (it seats at 17 s, is re-tasked twice, drives its last 26 m at 0.16–0.83
  throttle on full lock, arrives at 43 s). The 8 s terrain jam was on round 29's gate (`lab/brains-r29-gate`, v3):
  B5c-v4's "no gate within the approach length" removes the gate that sent it there. Brains' second case (yard
  crossing seed 25 tick 1, the U-turn onto terrain) is being reproduced next; M5's escape is designed from that trace.
- **Candidates and the queue (2026-10-14 ~14:05 PDT, superseded by run 1's ruling below):** M4b `e8bfef2e` (judged tree `1b3e2e56`, tooling on top),
  M1b(1) `lab/manoeuvre-m1b` `37c47851` (+ `ec92bad0` tooling), M2b `lab/manoeuvre-m2b` `e94ca27e`. Judged chains on
  builder0 one at a time: M4b (running) → M1b → M2b, under the orchestrator's gate (M4b's (b1) failing stops the
  queue). Lab worktrees `godot-manoeuvre-m1`, `godot-manoeuvre-m2` (removed at the close with their builder0 folders).
- **M4b committed `e8bfef2e`** (on main `3f1713a5`, sizing merged; `tests/test_manoeuvre_wedge.gd` builder0 7/0); native has
  the hash and the final constants. **Tuning (Terminus seeds 20–22, n = 1 each, GDScript path, builder0, `e8bfef2e`):**

  | | base | new |
  |---|---|---|
  | rigs arrived / 48, leg s, wall contact-ticks | 45, 346, 1849 | 44, 251, 1370 |
  | mixed arrived / 72, leg s, contact-ticks | 63, 566, 420 | 64, 487, 485 |
  | pinned crew-seconds (goal distance still ≥ 10 s; 4 runs read) | 211 (74, 67, 70 on 3 runs) | 0 |
  | STUCK crew-seconds (no 1 m of progress over ≥ 10 s; new row) | 240 | 142 |
  | brush: rigs' speed while touching a wall (n 6 paired) | 5.30 m/s | 4.71 (−0.59, se 0.72, within 2 se) |
  | stall fires per run (rigs / mixed) | 0 / 1–3 | 2–4 / 2–23 |
  | escapes ended by backoff v cap (new, all runs) | — | unstick 48 v 7, press 5 v 1 |

  Caveat on the tuning hull-rest base arm (not the Terminus arms): `manoeuvre-hull-rest`'s base arm put its own
  `--nav-off=turnhull,faceslot` first on the line and `Movement._parse_off` honours only the first `--nav-off=`, so
  `unstickback` was NOT off there (the reader switch, `--tank-off`, was); fixed for the judged chain (`M1_BASE_OFF`).
  Worst runs read (lesson 302): rigs seed 21's lost arrival (`MANOEUVRE_STATE` Green_S0_3, ticks 1860–2490): the rig
  drove its move from 48 m to 8.6 m of its slot (tick 2070, arrived), then its face-at-rest legs (`from post`, 0.55
  throttle, up to 7 m/s) carried it to 16.8 m off (the leg's miss: `gap_m 16.8`, phase arrived, completed): **the
  face plan left the slot behind, M1b(1)'s `face_slot` case in the wild** (mine, not an arrival latch); mixed seed 21's IFV, pinned 74 s at
  base, now OSCILLATES 73 s: stall fires, 1.5 m back, the route drives it straight into the same (non-wall) blocker
  every 3 s. Reading: the honest reader + sized escape frees every pin; what it cannot do is plan round a hull, and
  ORCA steers crews back in because `avoidance.gd` reads the blocker's phantom `estimated_velocity` (traffic's line:
  requested through the orchestrator). The judged chain follows the tuning hull-rest arms.
- **Finding (M4b tests, builder0, `test_manoeuvre_wedge`, n = 1 each):** the plant's yaw fit (`Tank.yaw_fit_enabled`,
  round 10) is OFF by default, so a pinned hull yaws freely through whatever pins it and only its translation is
  blocked. Consequences: (1) a rig pinned on a squadmate is freed by the stall escape in ~0.5 s: the reverse on full
  lock swings the nose off and the phantom momentum carries it round the hull (stall fires at 1.80 s, free at 2.33 s);
  (2) a rig nose-on into a wall leaves its pin SIDEWAYS along the face, in both arms, and the press escape ends by
  its 1.5 m rule, not the cap; (3) a pocket (walls either side) is not a plant case: the hull yawed 50° through the
  side walls and physics ejected it 3 m sideways and 6 m below the floor (a one-tick jump the backoff rule read as
  "backed off"). So the momentum-sized cap (`unstickback`) binds only where the yaw cannot swing the hull free (two
  hulls on the flanks, the planner's F2): whether it binds at all in play is read from `unstick_capped` /
  `press_capped` in the census (line (f)); if both are ~0 the sizing is a harmless no-op and the reader carries M4b.

- Orientation done; design above. Tests next.
- **Sizing merged (main `9730193f`, the orchestrator 2026-10-14):** `git merge main` at the next clean point (after
  the M4b commit). Sizing's requests, to do with M2b/M5's bars: per-run rows (seed, tick, episodes, contact-ticks)
  from the census into a jsonl (the Terminus drive already has NAV_DRIVE per run; the turn census prints totals);
  the 75 s settle line dropped or widened (censored); the moving-at-judge guard as "base + 2 se" with M1_CLASS's se;
  permutation p on clicked medians; the early-stop hook (`tools/judge/sequential.py`) for M1b/M2b/M5's series.
