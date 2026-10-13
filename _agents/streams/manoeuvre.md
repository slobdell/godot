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
  less 0.75 m (or no further out than it starts), not only its end; `--nav-off=facekeep`. One run: no face legs left
  moving at the judge.
