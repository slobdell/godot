# Stream: manoeuvre (the honest reading's consumers: a wedged IFV or truck backs out instead of sitting at full throttle, a War Rig pinned on a friend asks then backs straight; k-turn legs measured by a gear-signed arc; wheeled turret vehicles turn their whole hull to his drawn facing)

> Read `_agents/orchestration.md` (the worker contract; lessons 306–311 — **307, 309, 310, 311 are yours**),
> `_agents/game_design.md` *Round 28 direction* (his call 2: turn the whole vehicle), `_agents/judging.md`,
> `_agents/workstreams.md` **Round 31** (C31.1–C31.11, especially **C31.4 CP-H**, **C31.5**, **C31.8**), and round 30's
> manoeuvre report (`streams/archive/round30/manoeuvre.md`: the FINAL report, M4b runs 1–2 and the pair-check traces, M1b,
> M2b, kturnarc's orbit trace, the round-31 design note, the planner hand-over items; tables and logs under
> `references/round30/manoeuvre/`). **You own:** in `game/ai/movement.gd` the body of `drive()`, `_nose_stop`, `unstick`,
> `_pressing_escape`, the k-turn / planned-reverse / circle block's EXECUTOR (`kturn_on` through `_look_stop`,
> `_kturn_start_leg`, `_planned_reverse`) — **NOT its plan source** (the planner's seam, C31.5: agree the line with the
> planner through the orchestrator); `game/ai/manoeuvre*.gd`, `game/ai/clothoid.gd`, `game/ai/wall_contact.gd`; in
> `order_controller.gd` the face-at-rest path; `tests/test_manoeuvre*.gd`, `tests/test_kturn*.gd`, `tests/manoeuvre/**`,
> `tests/ai_scenarios/scenario_manoeuvre*.gd`, `mk/manoeuvre.mk`. **Granted:** the two aim-lead lines in `game/ai/gunnery.gd`
> (`--gun-off=realspeed`; brains told); `TankBrain._order_move`'s decline for wheeled turret hulls becomes "turn the hull"
> under `turnhull` (C31.8, brains told). Traffic's gate lines at your `unstick`, `_pressing_escape`, k-turn entry stay first.
> **The C++ (C31.2):** the drive, unstick, the k-turn executor, gunnery's leads have C++ twins — each settled diff to native
> before its commit. **Model:** Opus (the designs are written; the risk this round is coverage and process).

## The lead's direction

Round 26: a stuck vehicle makes a planned three-point turn, not a shuffle. **Round 28, his call: TURN THE WHOLE VEHICLE**
(a wheeled vehicle with a turret turns its hull to a drawn facing, "a few seconds longer on arrival"). Round 31: no new
words; the round-30 findings are the direction.

What he will notice: an IFV or gun truck pinned on a wall or a squadmate backs out within a couple of seconds instead of
sitting at full throttle; a War Rig pinned on a friend asks it to move, then backs straight a few metres; gun trucks and IFVs
end nose-on to the facing he draws.

## Where things stand (main `cff4307e`)

- **On main from round 30:** `Tank.real_velocity` (the motion a hull really made this tick; `--tank-off=real_velocity`; read
  by nobody in play), `face_slot` (M1b(1): a face at rest keeps the slot; the docks baseline moved for it), the census's
  `real` column, `pinned_table.py`'s PINNED/STUCK rows, `M1_BASE_OFF`.
- **M4b's escapes PARKED** (`lab/manoeuvre-m4b2` 77a1603f: the honest stall reading + momentum-sized escapes for hulls
  ≤ 10 m). Run 2 passed every judged line (pinned crew-s 2596 → 658 at n = 144, fights within 2 se, rigs byte-identical) and
  the pair check found two regressions: a law_tank (7.3 m 8×8) took ONE 0.9 s reverse on full lock in single file on the
  Sumps causeway and sat 21.5 m from its slot for good (`test_tactics_mixed_legs`: the re-seat's "slow" test read
  estimated_velocity 0.86 as driving, no rule reads 0.07 throttle as stuck); a tracked tank driven at a wall backed off
  (`test_nav_wall_contact`). Run 1 (all hulls) made rigs grind walls +141 %: "the driving after the escapes" (seed 31's 77 s
  grind). **Your design note (round 30):** ask first (`_ask_behind` / traffic's give-way), then a STRAIGHT reverse ≤ 3 m
  only where the k-turn's outline sweep is clear, ended by the real backoff, else report "blocked by <name>" so the brain
  re-tasks; counters by blocker kind. The War Rig's stall against a FRIEND (touch false, a Tank collider) reads
  `real_velocity`; against walls today's reading.
- **kturnarc PARKED** (`lab/manoeuvre-kturnarc` e7a58262): every judged line passed; `scenario_cp2`'s scout orbit flipped
  (3 deck hits of 27 v 58 of 83): a hull under `KTURN_BRAKE_HULL_M` starts a leg still rolling FORWARD at 10 m/s under
  reverse throttle, the UNSIGNED arc counts the 1.2 m roll-out as progress and the leg ends 2.2 m short, nose 40° off.
  **Fix named:** the arc signed by gear (`real_velocity.dot(nose) · gear · dt`), or the rolling logic for every wheeled hull.
- **The creep lift FAILED a third time** (M2b: −30 % v −50 %; rigs +34 % contact-ticks: seed 51's 50 s grind): it is the
  planner's F1 now (C31.5). Do not re-judge the lift.
- **M1b(2) turn-the-hull NOT BUILT** this round: round 29's `manoeuvre-m1-r29` (turnhull + facekeep) is the design; the
  guard is now sized (hull-rest wheeled turret sd 1.63 a run; the +5 guard needs n ≈ 478 — write the guard as base + 2 se
  at the n you run, from `judging.md`). B6's trace: a gang_ifv under SBF with a drawn facing parks 88.6/65.6/96.3° off
  because `TankBrain._order_move` declines a drawn facing for a wheeled turret hull — turn-hull lifts that (C31.8).
- **M5 parked**: case 1 closed by brains' v4 gate; case 2 (the six-cusp car) is the planner's F4.
- Known: the hull-rest probe does not export the face_slot counters (C31.9, yours); one hull-rest arm per remote call
  (lesson 311); only the FIRST `--nav-off=` is honoured (309).

## Backlog (in order)

**H1 — the escapes redesigned, as a CP-H consumer (DECLARED inside C31.4; `--nav-off=unstickback`).** From the design
note: the honest stall reading (`real_velocity`) for hulls ≤ 10 m AND for a War Rig whose blocker is a hull; the escape =
(1) ask (`_ask_behind`/the give-way; the short hull has the room), (2) if not cleared in ~2 s, a STRAIGHT reverse ≤ 3 m
(no lock) where the outline sweep is clear, ended by the real backoff (cap 0.9 s + |speed|/braking; counters backed v
capped), (3) else `blocked_by = <name>` for the brain. Tests first: the wedge tests (an IFV pinned on a squadmate, a rig
pinned on a friend, a tank driven at a wall must NOT back off under a raw `drive` order — unstick only under a goal), the
Sumps single-file case from `test_tactics_mixed_legs` as a unit stage. **Pair-tree check first (C31.1)** — the whole suite
with the switch ON; native mirrors from `lab/native-m4b-escapes` 366b42bc. Deliver on main behind the switch; the judged
A/B is CP-H (below).

**H2 — kturnarc signed by gear (CP-H consumer; `--nav-off=kturnarc`).** The fix named in the orbit trace; test: a scout's
leg started rolling forward ends where the plan said (the orbit's 3 legs, not 8), the IFV's second leg drives its own 8 m,
a War Rig's 10 m reverse 10.03 m by the arc. `scenario_cp2` green on the pair tree before anything. Native's mirror from
`lab/native-kturnarc` 40b89dd1 (the arc sum takes the sign).

**H3 — the two aim leads read `real_velocity` (CP-H consumer; `--gun-off=realspeed`, granted lines in `gunnery.gd`).**
Round 30 measured them only together with the escapes (hit rate on touching targets +2.5 pts, se 0.036). Alone-arm
numbers come from CP-H's reported arms.

**CP-H — the honest reading's A/B (you RUN it; C31.4).** When the orchestrator says every consumer is on main (yours
H1–H3, traffic's T4, brains' `realslow`): bar BEFORE numbers citing `judging.md` rows — all ON v all OFF, GDScript path,
fresh seeds: Terminus census rigs + mixed 13 seeds (arrivals not down beyond 1.645 se EACH; contact-ticks ≤ base +
1.645 se each), hull-rest (one arm per call; pinned crew-s down beyond 2 se at n = 144, ≤ 10 m hulls and rigs apart;
crews still moving at 75 s per task ≤ base + 2 se), nav-terminus-drive's pinned/STUCK rows (down), bridge-pooled 18/18,
fights 24 seeds (kills/deaths/hit rate within 2 se; touching-target hit rate reported), `scenario_cp2`, `mixed_legs`, the
whole suite on the pair tree; each consumer ALONE reported (one arm each). Partial as C31.4. Early stop allowed. Native's
one pair.

**M1b(2) — turn the hull (DECLARED; `--nav-off=turnhull,facekeep` ONE flag).** Round 29's design on top of face_slot;
the decline in `_order_move` lifted for wheeled turret hulls (C31.8). Bar from `judging.md`: hull-rest fresh seeds, drawn
and clicked, one arm per call: point tasks at rest median ≤ 15° and ≥ 70 % within 15°, line tasks = hover/turret (permutation
p), the 75 s guard base + 2 se per task with the se quoted, settle censored (reported), bridge 18/18, B6's SBF probe for
gang_ifv as a reported row (the 88.6° ceiling should fall), Terminus arrivals not down beyond 1.645 se, the whole suite on
the pair tree first (the face path has C++ seams: native's statement). Last attempt named.

**M6 — tooling:** export `face_slot_kept/refused` and the turn-hull counters from the hull-rest probe (C31.9); the
early-stop hook copied from traffic's runner into `manoeuvre-census` / hull-rest; `CACHE=on` for base rows.

**For the planner (C31.5):** agree the seam line (where the k-turn block asks for a plan) and the leg shape
(`Vector3(gear, steer, metres)` v your `Vector2`) in writing through the orchestrator before either of you codes it; the
executor rules from the hand-over you did not take (brake on the leg's own lock; never zero throttle with lock on) are
yours to take or refuse with a reason in Status.

## How to verify

`make remote T=check` on the pair tree with the switch ON before any series (C31.1); `make manoeuvre-hull-rest` (one arm a
call), `manoeuvre-fights`, `manoeuvre-census`, `nav-terminus-drive` + `pinned_table.py`, `bridge-pooled`,
`native-verify-scenarios`, `scenario_cp2`, `test_tactics_mixed_legs`, `test_nav_wall_contact`. Clips of a wedged IFV and a
pinned rig before/after for him. Every number: commit, machine, workload, n, its table row.

## Don't touch

Traffic's give-way block, `_avoid`, `traffic*.gd`; the planner's `game/ai/planner/**` and its plan-source seam (agreed, not
yours to edit); brains' `_track_progress`, `_update_phase`, `_approach_gate`, the re-seat, elements, `game/tactics/**`,
`tank_brain.gd` beyond the granted decline, `gunnery.gd` beyond the two lead lines; native's `native/**`; `game/tank/**`;
`game/control/**`; `tools/judge/**`.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current; bars to the orchestrator before numbers; the report at the top)_
