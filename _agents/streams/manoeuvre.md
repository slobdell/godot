# Stream: manoeuvre (wheeled turret vehicles turn nose-on to the facing you draw, without a packed squad still turning a minute later; long trucks in tight streets turn in planned legs)

> Read `_agents/orchestration.md` (the worker contract; lessons 295–303), `_agents/game_design.md` *Round 28 direction*
> (his call 2), `_agents/workstreams.md` **Round 29** (C29.1–C29.8), and round 28's manoeuvre report
> (`streams/archive/round28/manoeuvre.md`: *The report*, *M1 judged*, *M2 judged*, *M1 trace*). **You own:** in
> `game/ai/movement.gd` the body of `drive()`, `_nose_stop`, `unstick`, `_pressing_escape`, `_manoeuvre`, the k-turn /
> planned-reverse / circle block (`kturn_on` through `_look_stop`); `game/ai/manoeuvre*.gd`, `game/ai/clothoid.gd`,
> `game/ai/wall_contact.gd`; in `game/ai/order_controller.gd` ONLY the face-at-rest path (`_same_face`, `face_giveup_on`,
> `_face_giving_up`, the face branch of `_apply_move`; native keeps its seams);
> `tests/test_manoeuvre*.gd`, `tests/test_kturn*.gd`, `tests/manoeuvre/**`, `tests/ai_scenarios/scenario_manoeuvre*.gd`,
> `mk/manoeuvre.mk`. **Granted:** round 28's three lines in `TankBrain._order_move` (the decline skips a face whose element
> task carries a drawn facing); traffic adds one gate line each at your `unstick`, `_pressing_escape` and k-turn entry
> (C29.3: no unstick or k-turn while a crew holds for traffic): keep those first lines stable. **The C++ (C29.2):** the
> drive and the unstick have C++ twins; develop on the GDScript path, send native each settled diff before the commit.

## The lead's direction

**Round 28, his call (2026-10-12): TURN THE WHOLE VEHICLE** (`turret-hull-facing` = turn-hull): a wheeled vehicle with a
turret turns its whole hull to a drawn facing, so its front armour faces where he pointed, "a few seconds longer on
arrival". Round 26, on three-point turns: a stuck vehicle should make a planned three-point turn, not shuffle back and
forth.

What he will notice: draw a facing for gun trucks or IFVs and they end nose-on to it a few seconds after they arrive.
In a tight street a long truck turns in two or three deliberate legs instead of creeping forward and back.

## Where things stand (main `bcef46a1`)

- **M1 (turn the hull) is built and parked** on `manoeuvre-m1` at `140275af` (`--nav-off=turnhull`, `faceslot`;
  `tests/test_manoeuvre_turret_hull.gd`; `make manoeuvre-hull-rest` / `manoeuvre-hull-one`, `tests/manoeuvre/hull_rest_ab.py`).
  Last attempt (fresh seeds 2 4 7 9 15 19, 155 crews a task): point-task medians 5–6° (base 52–60°) and line tasks at
  hover/turret's level, but **8–25 more crews per task are still turning 75 s after the order** (screen +12, support by fire
  +8, move +14, right-drag +25; the guard was ≤ +5), and move / right-drag 69 / 64 % within 15° against a 70 % bar.
  Cause: planned face legs among squadmates in a packed formation, each turning hull boxed in by its neighbours.
- **M2 (the creep) is built and parked** on `manoeuvre-m2` at `1a13c548` (creep lift `--nav-off=creeplift`, circle fill
  `--nav-off=circlefill`, `tests/test_manoeuvre_creep.gd`). Creep episodes −17 to −20 % against a 50 % bar. The lift fixes
  OPEN-ground creep (its long episodes −72 %) but rolling a 10 m rig's turn at the line in a street drives it into walls
  (wall contact-ticks 1797 → 4136). About half of the remaining creep is the FRIENDLY case (a squadmate in the way):
  that half is traffic's T3, not yours.
- Base turn census (`c6e32d03`): 917 episodes, creep 121 (mostly short wheeled hulls); tracked hulls never over 3 legs.

## Backlog (in order)

**M0 — re-base.** Bring `manoeuvre-m1`'s tooling and M1 onto the stream from main; re-run the hull-rest base on today's
main (native perception/projectiles changed since). Trace two of the "still turning at 75 s" crews on move and right-drag:
what boxes them in (a neighbour's disc, its slot, the face planner's legs)?

**M1 — turn room, then the whole hull (DECLARED; CP-M1).** Give the turn room before the face: plan each crew's face
against its squadmates' discs (they are known: slots and hull boxes), or turn in the order that frees room (outermost
first), or both; if a slot spread at the halt is what it needs, that is brains' formation geometry (C29.8): ask through
the orchestrator with the trace. **Bar (send it before the numbers; this is round 29's last attempt):** round 28's
(hull-rest-probe drawn wheels/turret: point tasks median ≤ 15° and ≥ 70 % within 15°; line tasks = hover/turret ±5°;
clicked within ±5° of base; settle +≤ 6 s median) **plus "still turning at 75 s" ≤ base + 5 on every task**; on fresh seeds
(not 2 4 7 9 15 19, not 3 5 8 11 13 21); bridge-pooled 18/18; arrive series; thirteen explained; ≤ 0.5 ms. Partial rule:
yours to propose with the bar. A `facing-shots` before/after for him (look at it: do they end nose-on and still?).

**M2 — the creep as legs (DECLARED; CP-M2; + native's port).** For a long hull (rigs, gang trucks) in a street, plan the
creep as planned legs in the drive (M1b's face planner / the k-turn planner applied where the creep starts), so the hull
stops creeping and makes a two- or three-leg turn with the walls known. Leave the friendly creep to traffic. Reuse the
creep lift only where the open-ground numbers held. **Bar (send it before the numbers):** round 28's M2 bar on the OPEN
and STATIC kinds (the friendly kind reported, not judged): creep episodes of those kinds down ≥ 50 %; > 3-leg episodes not
up; Terminus arrivals ≥ base with rigs and mixed apart, wall contact-ticks ≤ base + 10 %; bridge-pooled 18/18; ≤ 0.5 ms;
symmetric; fresh seeds. After native's port: bridge-pooled and the Terminus drive once on the ON path (orchestrator).
**Then tell the orchestrator whether `wall_contact.gd` is settled** (native's N7.4 waits for your word).

**M3 — stretch, conditional (C29.6): scout's fixed-gun SUPPRESS lay.** Only if CP-M2 ships. `scout-s1-suppresslay` (+6.3
pts gun on point in SUPPRESS, inside 2 se, ~60 % of SUPPRESS was a wheeled hull coming round in legs). Rebase on M2, judge
ONCE on fresh census seeds 85–108, kills a guard (round 28's pre-registered last attempt, `workstreams.md` *Round 28*
CP-S1 bar).

## How to verify

`make remote T=check` (builder0 only, C29.7); `make manoeuvre-hull-rest` (on `manoeuvre-m1`), `manoeuvre-census`, `bridge-pooled`,
`native-verify-scenarios`; `make facing-shots` at desktop and phone aspect (look at them).

## Don't touch

Traffic's give-way block, `_avoid`, `avoidance.gd`, `traffic*.gd`; brains' `game/tactics/**`, elements, the rest of
`tank_brain.gd`; native's `native/**` and its seams; `game/control/**`.

## Waiting on the lead

Nothing: his call is made.

## Status

_Updated 2026-10-13 ~12:10 PDT by the manoeuvre worker (`godot-manoeuvre`, `stream/manoeuvre`, from main `bcef46a1`)._

### Plan (ordered)

1. **M0** re-base M1 (`ef6d430a`: round 28's diff `c6e32d03..140275af` applied cleanly); hull-rest base + round-28 M1
   on TUNING seeds 1 6 10 12 14 16 (builder0); traces of crews still moving at 75 s; `--turn-states` +
   `tests/manoeuvre/hull_rest_moving.py` so every moving crew at the judge is classified (face legs, face creep,
   pinned, dressing, driving), not just two traces.
2. **M1** fix what the classes show (first find: `facekeep`, below), bar to the orchestrator BEFORE numbers, judged
   once on fresh seeds 22 23 24 25 26 27 (named now: not round 28's, not O3's, not the tuning seeds).
3. **M2** the creep as legs for long hulls in streets (census first).
4. **M3** stretch only if CP-M2 ships.

### Progress log

- **M0 traces (builder0, `76317480` tooling, gangs seed 1, drawn right-drag, M1 on):** of the crews moving at the
  judge, (a) gang catapults PING-PONG face <-> move every ~1 s: a crew ~5 m from its slot plans two 5.5 m face legs whose
  cusp is ~8 m out, past its arrive radius (5.4 m); the brain re-sends the move mid-plan, it drives back, faces again.
  round 28's `faceslot` checked only a plan's END. (b) Battery crews (a 14-crew gang battery) still DRIVING to slots
  10-15 m away (nosing a squadmate, circling at the slot). (c) a gang IFV at full reverse, pinned 30 s between
  squadmates (its unstick finds a hull the other way, so it only asks). The probe's "still" is velocity, so a pinned
  hull counts as moving. Same seed, same commit, different runs give different crews (the screen probe is real
  time): read classes over the arm, not single runs.
- **`facekeep` candidate** (`Manoeuvre.plan_face`): every pose of a face plan stays inside the crew's arrive radius
  less 0.75 m (or no further out than it starts), not only its end; `--nav-off=facekeep`.
- **The root cause: round 28's `faceslot` never ran.** `Movement.idle()` clears `mover._goal` every tick a face order
  runs (`_apply_move` calls it before the face branch), so `plan_face` always read INF and anchored nothing (and
  `facekeep` with it). Fix: `OrderController.face_slot` = the goal of the last move_to order (set in `set_orders`, the
  face path). Candidate **`d7385da2`**.
- **M0 numbers (builder0, tuning seeds 1 6 10 12 14 16, 144 runs an arm, drawn):** base on today's main reproduces
  O3 (wheels/turret medians 38-77 deg). Moving at the judge, base twice: 26/27, 46/56, 32/26, 34/31, 38/37, 28/24;
  round 28's M1 twice (once with the no-op facekeep): 27/40, 62/68, 52/35, 38/47, 42/56, 41/40: **a +5 guard on 24
  runs is inside the probe's own A/A swing** (the screen probe runs in real time). With states, most moving crews in
  BOTH arms are crews that never reached their slot (wheels/turret 18-28 a task at base), and 51-75 a arm are hulls
  WEDGED with phantom velocity (reported 6-12 m/s, no displacement; scouts most: unstick reads that velocity and never
  fires) -> M4.
- **`d7385da2` on the tuning seeds:** face legs still running at the judge 4-10 -> 0-2 a task; point medians 3.0-3.6 deg
  at rest (79-85 % within 15); line tasks at hover/turret's level; guard -3/+6/-12/-8/+13/-5; screen's wheels/turret
  moving +15 (> 2 se) and at-rest share -9 pts (the reason the partial rule matters).
- **M1 bar sent and ACCEPTED (godot-67)** before the judged run: `d7385da2`, fresh seeds 22-33 (12, for the noise),
  LAST attempt; point tasks median <= 15 and >= 70 % within 15 of crews AT REST; line tasks = hover/turret +/-5;
  clicked +/-5 of base; settle <= +6 s; guard <= base + 5 every task (a miss only among hulls M1 never commands passes
  only if each such class is within 2 se of base, paired); wheels/turret at-rest share not down > 5 pts; bridge-pooled
  18/18, arrive series, thirteen, <= 0.5 ms. **Partial (ruled, disclosed after tuning showed screen failing):** a
  wheels/turret guard or at-rest miss on a LINE task = that line task fails -> turnhull ships for POINT tasks only, on
  condition that line tasks provably take today's path (prepared: branch `manoeuvre-m1-pointonly`,
  `OrderController.line_task_keeps_turret`, `--nav-off=turnlines`, `test_line_tasks_take_the_base_path_exactly`: pose
  for pose against `--nav-off=turnhull,faceslot,facekeep`). A miss on a point task: nothing ships.
- **M1 JUDGED: NOT MET -> nothing ships (the last attempt).** `d7385da2`, builder0, seeds 22-33, 288 runs an arm
  (`references/round29/manoeuvre/m1_judged.txt`). PASS: point tasks at rest move 3.2 deg / 82 %, right-drag 3.3 / 80 %,
  attack-move 3.2 / 81 % within 15 (base 41-59 deg / 14-32 %); line tasks 27.6-28.0 v hover/turret 28.1-28.8; at-rest
  share within -3.9 pts; settle +0; non-M1 classes within 2 se. MISS: the 75 s guard on ATTACK-MOVE (a point task) +8,
  wheels/turret +12 (se 8.9: face legs +3, face creep +3, dressing +5, driving +4); support by fire +8; clicked medians
  > +/-5 on 4 tasks (3 lower error, screen +6.3 p 0.32). Context, not a plea: the clicked pair (faces declined both arms)
  moved the same class +10 on attack-move. Kept: `d7385da2` (face_slot root-cause fix + facekeep) and branch
  `manoeuvre-m1-pointonly` (line tasks provably on the base path, 6/0 builder0).
- **M2 (the creep): built, bar ACCEPTED before numbers, JUDGED: NOT MET -> nothing ships (last attempt).** Candidate
  `7b895eed` (branch `manoeuvre-m2-r29`): round 28's creep lift re-based (`--nav-off=creeplift`), refusal counters,
  `tests/test_manoeuvre_creep.gd` (paced IFV 14 gear changes / 7.8 s -> 0 / 2.8 s; gang catapult 23 / not round in 12 s
  -> 0 / 4.4 s; builder0 2/0). Tuning (seeds 1-3): open+static creep 78 -> 32. Judged (census 8-13 + sim 6-8, GDScript
  path): open+static creep 125 -> 75 (-40 %, bar -50); over-3 386 -> 308; Terminus mixed arrived 133 -> 132/144, rigs
  82 -> 75/96, rig wall contact-ticks 3938 -> 6494 (mixed 1533 -> 959); bridge 18/18; friendly 125 -> 113; ~0.04 ms.
  Rigs: one pinned rig a run carries the table (lesson 302), but without each arm's two worst runs still 1425 -> 2259:
  rolling a long rig's turn puts it into street walls more (round 28 again). The long pins themselves are M4's bug:
  traced (terminus rigs seed 9, deterministic, GDScript path) a rig reports 12 m/s at full throttle with zero
  displacement for seconds, in free space and against a wall; unstick reads that velocity and never fires
  (`references/round29/manoeuvre/m2_judged.txt`). wall_contact.gd untouched (told the orchestrator: settled for N7.4).
- **M3 (scout's SUPPRESS lay): not opened** (conditional on CP-M2 shipping, C29.6).
- **M1 judged run** ~13:20 PDT: `manoeuvre-hull-rest` arms new/base x drawn/clicked from `d7385da2` (two
  worktrees, same commit), `M1_FLAGS=--turn-states`.
