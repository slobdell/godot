# Stream: brains (an arrival means every crew arrived; a crew blocked by a parked squadmate gets a seat; flank attacks)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* and *Round 27
> direction*, `_agents/doctrine.md`, `_agents/workstreams.md` *Round 27* (C27.1–C27.6), and round 26's brains report
> (`streams/archive/round26/brains.md`, **FINAL REPORT** and its round-27 rows: your backlog's source). You own
> `game/ai/**` EXCEPT scout's, orders' and native's carve-outs (C27 ownership list: notably `combat_motion.gd` and the
> fight-motion hunk of `tank_brain.gd` are scout's this round), `game/tactics/**`, `tests/ai_scenarios/**` (others add
> their own `scenario_<stream>*.gd` and one registration line each), `tests/tactics/**`, `tests/nav/**`,
> `tests/test_ai*.gd` (except `test_ai_combat_motion.gd`), `tests/test_tactics*.gd`, `tests/test_nav*.gd`,
> `tests/test_form_up.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`.
> **The C++ freeze (C27.2):** native is moving the execute step into C++. Think-side code (elements, tactics, `tank_brain`'s
> situation/decide/act, squads) is NOT frozen; the drive (`movement.gd`'s drive and its callbacks), `gunnery.gd`,
> `order_controller.gd`'s execute path, `steering.gd`, `avoidance.gd` are. `decide` and `build_situation`'s core run in
> C++: a change there goes to native as a diff before your commit, merged as a pair.

## The lead's direction

Round 26's (still his): squads that arrive together and fight as squads; his bridge drill (passes now: keep it).
Round 27 adds no new words for you; your items are round 26's carry-overs, which are his round-26 complaints not yet
fully fixed, plus the flank attack that makes his armed-order gesture complete (orders, C27.3).

## Where things stand (main `04845af7`; check green at `090b345d`, builder0, 2464/0)

- **The Sumps arrive cell:** a TRACKED law_ifv presses a squadmate parked on its station; make-room never fires because
  `Element._watch_progress` resets its 4 s not-closing clock on every sub-1 m/s dip. The clock pause (lab branch
  `lab/brains-mr2`, `26b94aa6`) turns "never" into 52 s — but HOLLOW: the re-seat hands the parked crew a far seat and
  it ends 19–26 m off while the element reads arrived (lesson 293).
- **The arrive line counts the element, not every crew** — two of round 26's "arrivals" were hollow.
- **Make-room has no falsifier on main** (traffic's CP1a freed the corner it was tested on): price it by removal.
- **B2 drill seats by nearest** (paired at `fe45a510`): nearest 4/3 fight tests v pinned 7/0 — pursuit lets go at 7.5 s,
  the bay ambush springs early (x 55.7 at 12.1 s v 64.6 at 15.5 s), the Sumps two-scout squad 26.1 v 20.4 s.
- **Ambush's guns sit at a flat 30° off the drawn facing** in every run (orders' facing probe, round 26).
- The rig carrot (`lab/brains-carrot`, `f082af36`) is a drive-side rule: frozen this round; leave it parked.

## Backlog (in order)

**B0 — CP0: an attack task honours a drawn approach (C27.3), small, first.** When `task["approach"]` is present (a
normalised `[x, z]`: the direction the squad comes FROM, toward the target), the attack's plan sets up on that side of
the target and goes in from it; absent = today's code path, byte-identical (thirteen lines and determinism unmoved).
A unit test per verb, a TacticsLab stage showing the approach side honoured (n stated). Merge as CP0 (not declared: the
default path is unchanged); the orchestrator tells orders to merge main.

**B1 — the arrive line counts every crew.** An arrival = every living crew inside its settle radius of its own slot
(tooling first, with a mutation check: a crew 20 m off must fail it). Re-run the arrive series and the Sumps cell under
it on main; report which existing passes were hollow. This is the instrument for B2–B4.

**B2 — the crew pressing a parked squadmate gets a seat around it.** Start from `lab/brains-mr2`'s clock pause; the
re-seat seats the blocked crew around the parked one (the parked crew keeps its seat). Acceptance: the Sumps cell
arrives under B1's line; the bridge 108 and `bridge-pooled` unmoved. DECLARED (C27.1).

**B3 — make-room priced by removal** under B1's line (lesson: attribute a cost to a behaviour only by removing it): with
and without, the arrive series and the Sumps cell, n stated. Keep it, retire it, or give it a stage that needs it.

**B4 — drill seats by nearest that keep the lead crew's role.** Nearest seats, but the crew with the role (the lead in
a pursuit, the ambush's trigger, the two-scout squad's pair) keeps it. Guards: round 26's paired table (pursuit, bay
ambush, Sumps two-scout) must pass in both arms; his bridge drill. DECLARED.

**B5 — ambush guns on the drawn facing**, not 30° off: trace where the offset comes from (lay, slot, or the line's
geometry) and fix it on the think side; if it is gunnery's lay, it is a request to native (frozen).

**B6 — stretch:** the street-funnel trade stays his call (held); F6 only with a new reason.

## How to verify

`make remote T=check` (builder0 only, C27.6); `make bridge-pooled` (in check) and the 108 for declared changes; the
arrive series; TacticsLab stages pooled over start ticks {1,3,6,8,11,16} (C27.5); the thirteen lines and determinism.
A pass line changes only with its reason written and the orchestrator's approval (C27.5).

## Don't touch

Scout's `combat_motion.gd` and `tank_brain.gd`'s fight-motion hunk (`_combat_move`, `_hold_motion_plan`, the ORBIT
controller); native's frozen execute files (C27.2) and `native/**`; orders' `game/control/**`.

## Waiting on the lead

Nothing.

## Status

**Plan (2026-10-11, in order):** B0 (attack honours `approach`; CP0 → orders) → B1 (the every-crew arrive line, tooling
+ mutation check, re-read the arrive series and the Sumps cell) → B2 (re-seat round the parked crew, from
`lab/brains-mr2`; DECLARED) → B3 (make-room priced by removal under B1's line) → B4 (drill seats by nearest keeping the
lead's role; DECLARED) → B5 (ambush guns 30° off: trace first) → B6 held.

**B0 — DONE. CP0 GREEN, merge here: `9603c1d7`** (builder0, `make check exited 0`, 2475 passed / 0 failed = main's
2464 + B0's 11; thirteen UNMOVED; determinism `2875411ff4ec6be7` unchanged; 2 NOT JUDGED for the busy box only:
perf-judge refused ×3 at ratio ~2.4, scenario_perf unpinned). Told the orchestrator 2026-10-11 ~19:50; orders confirmed
the sign (approach = enemy − release point, the run in). `task["approach"] = [x, z]` (attack only; validated; the
direction of the run IN, toward the target, as orders' brief reads it). Design (decided, one line each): the attack
drives ROUND the target at its crews' longest reach (`range`, 70 m for a tank; at 45 m effective it drove inside the
target's guns) in 45° notches, each at least 15° ahead (fixed points, so crews are not re-sent every update; a notch
it had to land on exactly stalled the squad 6° short for 25 s), until its centre is within 30° of the drawn side; then
it is "in" for the life of the task and attacks as before. The way round is the shorter one, kept once chosen. On the
way the crews are on a NAMED MOVE (guns laid on the target, shooting on the move); react to contact, far ambush and a
near ambush on the target itself yield until it is round (each sends crews straight in from the wrong side). A running
target is a pursuit and has no side. Absent = today's path (the plan writes `approach_round` only when the key is there;
`Drills.rounding_to_approach` reads false for every other task).
- Tests: `tests/test_tactics_approach.gd` (9, plan level: validation per verb, on-side identical to no approach, far
  side goes round at reach, notches, kept way, latched in, line in reach, pursuit unchanged),
  `tests/test_tactics_approach_live.gd` (2, a real match, both arms). builder0: 11 passed / 0.
- Stage `make approach-series` (`ApproachStage`: his four tanks 100 m south of two enemy tanks on yard_open, a hold-fire
  scout spotting; attack one from the EAST v no approach), builder0, tree `c37605f0` + B0, n = 18 per arm (seeds 1–3 ×
  start ticks {1,3,6,8,11,16}): **east 18/18 closed in from within 35° of the east side** (median 27°, worst 30°),
  control 0/18 (median 88°: straight up from the south). Cost of the drive round: target killed 18.9 s v 14.5 s
  (medians), his crews alive 3.61 v 3.11 (mean).
- CP0 is NOT declared (default path unchanged). Merge note: touches `element_task.gd`, `element_plan.gd`,
  `element.gd`, `drills.gd` (all mine), `mk/tactics.mk` (+ approach-series), new tests and `tools/tactics/approach_table.py`.

**B1 — the line is built; the series re-read is running.** `tests/tactics/arrival_line.gd` (`ArrivalLine`): every
living crew within max(3.5 m, its hull's settle radius) of its OWN slot, held 1 s. `settle_probe` reports `all_in_s`,
`hollow` (the element said arrived, the line never held), `worst_off_m`/`worst_crew`; a stopped squad with a crew off
its slot now runs on (the digest run keeps its old end). Mutation check `--arrive-mutate=on` (the first crew's slot
read 20 m off). builder0, `3aa67b17`: unit tests 6/0; yard four tanks seed 1 — element arrived 22.3 s, line NEVER
(hollow: two crews 5.8 / 8.4 m off); with the mutation also never (worst 20.8 m). The Sumps cell (seed 1) never arrives
on main (S_2, the IFV, 11.3 m off), as round 26 traced.
- **Finding for the orchestrator's ruling (C27.5):** the yard's hollowness is DESIGNED tolerance, not a stuck crew. The
  halt re-seated at 24 s (seats 0321 → 0231) and two crews' seats moved under 8 m, which the element does not re-send
  (`Element.REISSUE_M` 8 m; it calls a crew in position within `ElementPlan.IN_POSITION_M` 8 m). So the strict 3.5 m line
  fails ragged halts the element itself calls done. The probe now ALSO reports `all_in8_s` (the same line with an 8 m
  floor, `ArrivalLine.ELEMENT_TOLERANCE_M`); lesson 293's stuck crews (19–26 m) fail both. Both are reported; the
  strict one stays the line until ruled.

**B2 (DECLARED) — SHIPPED: v5 GREEN at `2dccf781`, merged by the orchestrator as `2dccf781` (2026-10-12 ~01:40).**
builder0 `make check exited 0`, 2497 passed / 0 failed, 24 targets ALL JUDGED, thirteen unmoved, determinism
`2875411ff4ec6be7`. Rule sheet (all at v5 `3e54110e`): (1) PASS Sumps seed 1 tick 1 arrives 82.6 s, seed 1 6/6;
(2) PASS fresh seeds 9–12, 8 m line 95 v 88, 1 lost, median +0.0 % (strict 74 v 67); (3) PASS his 108 106 v 106
(identical failures: the candidate below), bridge-pooled 18/18; (4) PASS; (5) cost NOT READABLE (pinned 0–7, 25 a
side Sumps, GDScript path, n = 3 × 2 repeats: tick scripts 62.9 v 62.2 then 80.6 v 74.1 ms; elements segment +0.12 ms
in the quieter repeat; identical survivors); (6) CPU side seeds 9–10 45 v 43 (2 lost, +0.0 %); (7) 15 v 13 of 18;
(8) fresh 9–12 24 v 23 of 24; fight guards 39/0; resends 25 in 19 cells, max 3 in a cell, none twice.
**B5 rode inside that merge (the orchestrator's ruling, accepted after the fact):** `TankBrain.AMBUSH_LAY_ENABLED`
applies to EVERY unsprung ambush (the CPU's and undrawn ones too), a default-path behaviour change; `--ambush-lay=off`
is the old bare hold. Guards (bay ambush, fights) 39/0 and the thirteen unmoved at that hash. Lesson for me: a
default-path change gets its own commit and a message to the orchestrator first.
History (v1–v5, the version table below):
Mechanism (v5, `3e54110e`, on main `f4c5f7c9` merged as `5877710e`): (1) the stuck clock PAUSES on a slow tick only while
the crew presses a squadmate parked on its own slot (`Element._pressing_parked`), else resets as before; (2) a re-seat
keeps every squadmate parked on its own slot in its seat (`_parked_seats` → `plan.reseat_keep` →
`TacticsFormation.seat` `keep`); (3) after arrival the watch acts only on a crew pressing a parked squadmate (guards: no
drill, not on attack, not hit in 5 s); (4) after arrival an idle crew more than 8 m off its seat is sent on ONCE per seat
(`_should_issue`, the mouth rule's once; same guards). Off: `--stuck-pause=off --reseat-keep=off --watch-arrived=off
--resend-short=off` (settle_probe `--b2=off`). Judged line: `all_in8_s` (C27.5 ruling), the strict line beside it.

| version | rule (1) Sumps s1 t1 | Sumps s1–4 (8 m) | judged series (8 m line) | verdict |
|---|---|---|---|---|
| v1 pause everywhere + keep | — | strict 12 → 14/24, seed 2 6/6 → 3/6 | not run | tuning: re-seats 4 → 47 |
| v2 narrowed pause + keep | fails | 14 → 17/24 | not run | tuning |
| v3 + post-arrival watch (all crews), `787cd2e4` | passes | 14 → 21/24 | seeds 1–4: 89 v 86, **4 lost**, **+13.4 %** | FAILS (2): 89 re-seats in 61 cells |
| v4 watch only the pressing crew, `5877710e` | **fails** (scout idle 11.4 m short) | 14 → 21/24 | fresh 5–8: 85 v 83, **2 lost**, −0.4 % | FAILS (1), (2) |
| v5 + one resend of an idle short crew, `3e54110e` | running | running | fresh 9–12 running | — |

Also at v4: fight guards 39/0; Sumps fresh seeds 5–8 18/24 v 18/24; his 108 106/108 (control at the same hash stopped:
v4 does not ship). Every builder0 number above is the commit named in its row.

**B3 — make-room priced by removal** under B1's line (lesson: attribute a cost to a behaviour only by removing it): with
and without, the arrive series and the Sumps cell, n stated. Keep it, retire it, or give it a stage that needs it.

**B4 — drill seats by nearest that keep the lead crew's role.** Nearest seats, but the crew with the role (the lead in
a pursuit, the ambush's trigger, the two-scout squad's pair) keeps it. Guards: round 26's paired table (pursuit, bay
ambush, Sumps two-scout) must pass in both arms; his bridge drill. DECLARED.

**B5 — ambush guns on the drawn facing**, not 30° off: trace where the offset comes from (lay, slot, or the line's
geometry) and fix it on the think side; if it is gunnery's lay, it is a request to native (frozen).

**B6 — stretch:** the street-funnel trade stays his call (held); F6 only with a new reason.

## How to verify

`make remote T=check` (builder0 only, C27.6); `make bridge-pooled` (in check) and the 108 for declared changes; the
arrive series; TacticsLab stages pooled over start ticks {1,3,6,8,11,16} (C27.5); the thirteen lines and determinism.
A pass line changes only with its reason written and the orchestrator's approval (C27.5).

## Don't touch

Scout's `combat_motion.gd` and `tank_brain.gd`'s fight-motion hunk (`_combat_move`, `_hold_motion_plan`, the ORBIT
controller); native's frozen execute files (C27.2) and `native/**`; orders' `game/control/**`.

## Waiting on the lead

Nothing.

## Status

**Plan (2026-10-11, in order):** B0 (attack honours `approach`; CP0 → orders) → B1 (the every-crew arrive line, tooling
+ mutation check, re-read the arrive series and the Sumps cell) → B2 (re-seat round the parked crew, from
`lab/brains-mr2`; DECLARED) → B3 (make-room priced by removal under B1's line) → B4 (drill seats by nearest keeping the
lead's role; DECLARED) → B5 (ambush guns 30° off: trace first) → B6 held.

**B0 — DONE. CP0 GREEN, merge here: `9603c1d7`** (builder0, `make check exited 0`, 2475 passed / 0 failed = main's
2464 + B0's 11; thirteen UNMOVED; determinism `2875411ff4ec6be7` unchanged; 2 NOT JUDGED for the busy box only:
perf-judge refused ×3 at ratio ~2.4, scenario_perf unpinned). Told the orchestrator 2026-10-11 ~19:50; orders confirmed
the sign (approach = enemy − release point, the run in). `task["approach"] = [x, z]` (attack only; validated; the
direction of the run IN, toward the target, as orders' brief reads it). Design (decided, one line each): the attack
drives ROUND the target at its crews' longest reach (`range`, 70 m for a tank; at 45 m effective it drove inside the
target's guns) in 45° notches, each at least 15° ahead (fixed points, so crews are not re-sent every update; a notch
it had to land on exactly stalled the squad 6° short for 25 s), until its centre is within 30° of the drawn side; then
it is "in" for the life of the task and attacks as before. The way round is the shorter one, kept once chosen. On the
way the crews are on a NAMED MOVE (guns laid on the target, shooting on the move); react to contact, far ambush and a
near ambush on the target itself yield until it is round (each sends crews straight in from the wrong side). A running
target is a pursuit and has no side. Absent = today's path (the plan writes `approach_round` only when the key is there;
`Drills.rounding_to_approach` reads false for every other task).
- Tests: `tests/test_tactics_approach.gd` (9, plan level: validation per verb, on-side identical to no approach, far
  side goes round at reach, notches, kept way, latched in, line in reach, pursuit unchanged),
  `tests/test_tactics_approach_live.gd` (2, a real match, both arms). builder0: 11 passed / 0.
- Stage `make approach-series` (`ApproachStage`: his four tanks 100 m south of two enemy tanks on yard_open, a hold-fire
  scout spotting; attack one from the EAST v no approach), builder0, tree `c37605f0` + B0, n = 18 per arm (seeds 1–3 ×
  start ticks {1,3,6,8,11,16}): **east 18/18 closed in from within 35° of the east side** (median 27°, worst 30°),
  control 0/18 (median 88°: straight up from the south). Cost of the drive round: target killed 18.9 s v 14.5 s
  (medians), his crews alive 3.61 v 3.11 (mean).
- CP0 is NOT declared (default path unchanged). Merge note: touches `element_task.gd`, `element_plan.gd`,
  `element.gd`, `drills.gd` (all mine), `mk/tactics.mk` (+ approach-series), new tests and `tools/tactics/approach_table.py`.

**B1 — the line is built; the series re-read is running.** `tests/tactics/arrival_line.gd` (`ArrivalLine`): every
living crew within max(3.5 m, its hull's settle radius) of its OWN slot, held 1 s. `settle_probe` reports `all_in_s`,
`hollow` (the element said arrived, the line never held), `worst_off_m`/`worst_crew`; a stopped squad with a crew off
its slot now runs on (the digest run keeps its old end). Mutation check `--arrive-mutate=on` (the first crew's slot
read 20 m off). builder0, `3aa67b17`: unit tests 6/0; yard four tanks seed 1 — element arrived 22.3 s, line NEVER
(hollow: two crews 5.8 / 8.4 m off); with the mutation also never (worst 20.8 m). The Sumps cell (seed 1) never arrives
on main (S_2, the IFV, 11.3 m off), as round 26 traced.
- **Finding for the orchestrator's ruling (C27.5):** the yard's hollowness is DESIGNED tolerance, not a stuck crew. The
  halt re-seated at 24 s (seats 0321 → 0231) and two crews' seats moved under 8 m, which the element does not re-send
  (`Element.REISSUE_M` 8 m; it calls a crew in position within `ElementPlan.IN_POSITION_M` 8 m). So the strict 3.5 m line
  fails ragged halts the element itself calls done. The probe now ALSO reports `all_in8_s` (the same line with an 8 m
  floor, `ArrivalLine.ELEMENT_TOLERANCE_M`); lesson 293's stuck crews (19–26 m) fail both. Both are reported; the
  strict one stays the line until ruled.

**B2 (DECLARED) — built at `787cd2e4` (+ `1468b21b`: `--b2=off`, the probe's control flag); judged runs in flight.**
Three parts, one change: (1) the stuck clock PAUSES on a slow tick only while the crew presses a squadmate parked on its
own slot (`Element._pressing_parked`), else resets as before; (2) a re-seat keeps every squadmate parked on its own slot
in its seat (`_parked_seats` → `plan.reseat_keep` → `TacticsFormation.seat` `keep`); (3) the stuck watch runs on after
the element says arrived (8 of the arrive series' 10 crews left 13–29 m off had 0 re-seats), guarded per the
orchestrator: it rests while a drill runs and skips a crew on an attack order or hit in the last 5 s
(`reseats_after_arrival` counted). Switches `--stuck-pause=off`, `--reseat-keep=off`, `--watch-arrived=off`.
- Ship rule registered before numbers, accepted with (6) the CPU's side per side, (7) Sumps seeds 2–4 reported, (8)
  Sumps at fresh seeds 5–8 reported. **The judged line is `all_in8_s` (C27.5 ruling)**; the strict line beside it.
- **Tuning history (disclosed to the orchestrator; Sumps seeds 1–4 are tuning data now):** v1 (pause everywhere + keep),
  strict line: control 12/24, B2 14/24, seed 2 6/6 at 24.8 s → 3/6 at 57.1 s, re-seats 4 → 47 → the pause narrowed.
  v2 (narrowed pause + keep): 8 m line control 14/24 → 17/24, seed 2 back to 6/6. v3 = + the watch after arrival
  (unguarded, tuning only).
- **Fight guards at `787cd2e4`** (builder0, light lane; pursuit incl. the let-go guard, cpu_hold, mixed_legs,
  make_room, elements, facing live, reseat_keep, arrival_line): **39 passed / 0 failed**; Sumps two scouts 20.4 s
  (main 20.4); four tanks 53.0 s.
- In flight: the 100-cell arrive series `ARRIVE_ARM_FLAG=b2` (seeds 1–4, both arms in one run), the CPU's side
  (`--side=cpu`, seeds 1–2), the Sumps cell seeds 1–4 and 5–8 (both arms), his bridge 108 (scratch worktree
  `godot-brains-lab` at `1468b21b`).

**B3 — make-room priced by removal: NO measured gain on main.** Arrive series (round 18's five squads × yard /
terminus / pit / sumps / cut × seeds 1–4 = 100 cells per arm), builder0, `3aa67b17`, B1's strict line: make-room on
68/100, off 68/100, identical cell for cell except the Sumps four-tank row (1 swap in 100 runs, no extra arrival; the
element's own flag said 99 v 98). Decision (the orchestrator's ruling): NOT retired inside B2; after B2 merges, the same
series with and without make-room under B2 decides it (retire if still ~0; it stays the swap budget's only user).

**B5 — DONE on the branch (`417863c7`); merges after B2 (it rides the same checks).** B5 measured at `787cd2e4`
(builder0, `test_tactics_facing_tasks_live`): the ambush's mean GUN 0.2° off the drawn facing (round 26: a flat 30°),
hulls 1.4° mean. Cause and fix: An unsprung ambush's weapon order is a bare `hold_fire`
(`TankBrain._order_weapon`), and Gunnery leaves a hold-fire turret where it was ("keep the turret where it is"), so the
sector the line gave each crew never reached its gun; every other line task lays an idle gun on its sector (Gunnery's
round-18 D1 rule). Think-side fix: an unsprung ambush crew with a sector gets `aim` at a point 60 m out on it (aim never
fires; the ambush still holds). `--ambush-lay=off` = the old bare hold. Test: the ambush case of
`test_tactics_facing_tasks_live` now also holds the squad's mean GUN within 15° of the drawn facing.

**lab/brains-close — PARKED (the orchestrator, 2026-10-12): no ship.** (a) did not reproduce for direct fire: tanks in
the quiet stage (target holds fire, cannot die) close to 22 m in both arms; orders' seeds 3/13 stall was the player's
group 1 being ARTILLERY ("Battery", wrecker catapults) holding its standoff against a target that could not die.
(b)'s rework (a still target lost from sight while going round is not a pursuit) is unproven alone; it is folded into
the live-flank follow-up below. Candidate for the lead (the orchestrator takes it): should artillery honour a drawn
approach (bombard from that side) or ignore it? Today it partly honours it. The `8de99ab8` runs are void.
Original write-up: Orders' flank-probe (main + CP0,
real input path): seeds 3 and 13 the attack never closes in either arm. Traced to two causes: (a) PRE-B0 — an attack
goes in (line + `attack`) only once its centre is within the crews' shortest EFFECTIVE range (45 m); below that its crews
are on attack-moves, which stop to fight at full range (70 m): with a target that never fires back nothing sends them
in (they parked 50–75 m off for 90 s). Fix: go in within the crews' longest reach (`--attack-close=effective`).
(b) B0 drove round at 70 m, beyond a tank's 62 m sight; out of sight the attack becomes a pursuit, which has no side
(it stopped 40–54° off). Fix: round at the crews' shortest sight (`--approach-sight=off`); not declared alone. Branch
`lab/brains-close` (worktree `godot-brains-lab2`) = main + the stage tooling + the fix. Bar registered before numbers
(accepted, + 6 fresh flank-probe seeds as its blind part of (1)); blind runs in flight.

**Candidates noted (not preempting B0–B4):** his bridge 108 reads 106/108 at round 27's base in BOTH of B2's arms
(`3e54110e`, builder0): seed 2, his side tick 5 and the CPU's tick 9, one law_tank hesitating 3.5–6.8 s at the rim, all
crews crossing. Bisected by scout for the orchestrator: identical at `090b345d` (round 26's close) and at `f4c5f7c9` with
and without CP-S, so it came in between `eb987e87` (108/108) and `090b345d`. Not taken on yet.
 scout's census (main `c37605f0`, builder0, 12 showmatch seeds): 254 of 365
enemy hull contacts came while the crew was on an ordered MOVE (squads, the CPU's included, moved into the enemy outside
CombatMotion): an arrive point inside the enemy, or an attack-move that does not stand off. Seeds/ticks in scout's Status.
