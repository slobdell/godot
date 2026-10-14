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

_(the worker keeps this current: every number names commit, machine, workload and n; bars go to the orchestrator before
numbers; the report at the top)_
