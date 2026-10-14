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

### Progress log
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
