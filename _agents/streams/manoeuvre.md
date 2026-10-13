# Stream: manoeuvre (wheeled turret vehicles turn to the facing you draw; no creeping shuffle in tight streets)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* and **Round 28
> direction** (his call 2), `_agents/workstreams.md` *Round 28* (C28.1–C28.6), round 26's manoeuvre report
> (`streams/archive/round26/manoeuvre.md`: M1, M1b, M2/CP3, **M3** the creep line) and orders' round 27 O3 table
> (`streams/references/round27/orders_hull_rest.txt`). **You own:** in `game/ai/movement.gd` the body of `drive()`,
> `_nose_stop`, `unstick`, `_pressing_escape`, the k-turn / planned-reverse / circle block (`kturn_on` through
> `_look_stop`), `_manoeuvre`; `game/ai/manoeuvre*.gd`, `game/ai/clothoid.gd`, `game/ai/wall_contact.gd`; in
> `game/ai/order_controller.gd` the face-at-rest path (`_same_face`, `face_giveup_on`, `_face_giving_up`, the face branch of
> `_apply_move`, the wheeled-turret "hull keeps its arrival heading" rule); `tests/test_manoeuvre*.gd`, `tests/test_kturn*.gd`,
> `tests/manoeuvre/**`, `tests/ai_scenarios/scenario_manoeuvre*.gd`, `mk/manoeuvre.mk`. **The C++ (C28.2):** the drive, the
> unstick and the per-crew execute have C++ twins (stage 1). Develop on the GDScript path; send native each settled diff
> before its commit; the pair merges back to back.

## The lead's direction

Round 26: a stuck vehicle should turn *"in three planned legs"*, and a short move behind is a reverse, not an N-point turn.
**Round 28, his call (2026-10-12): TURN THE WHOLE VEHICLE** — a wheeled vehicle with a turret, given a drawn facing, turns
its hull that way: "front armour faces where you pointed; a few seconds longer on arrival."

What he will notice: drag a facing for gang tanks/IFVs/artillery or Law tanks and they end nose-on to it, turning in a few
planned legs on their spot; War Rigs and wheeled hulls stop creeping in short jerks in tight streets.

## Where things stand (main `ecc0d6e0`, green)

- Orders' O3 (round 27, `9c6f3381`, builder0, foundry, 4 factions × 6 seeds, 313 crews a task an arm): hover, tracks and
  wheeled FIXED guns end 1.4–3.8° off a drawn facing; **wheeled turreted hulls are the whole 100–167° tail** (168/313 crews,
  median 60–68° drawn = clicked) because `order_controller` keeps their arrival heading and lets the turret take the
  facing (`wheel_holds`). Support by fire on wheeled turreted hulls is WORSE drawn (90.9° v 55.9°, p = 0.001).
- M1b (round 26): a wheeled hull facing a new way at rest drives a planned turn (n equal legs on one lock, fewest clear).
  It exists; the turreted hulls never ask for it.
- M3 (round 26, branch `manoeuvre-m3`): the creep is a symptom of a turn the street has no room for at pace; holding still
  broke his bridge, rolling drove rigs into walls. Plan the turn instead.

## Backlog (in order)

**M0 — base.** `make hull-rest-probe` (orders' tool, on main) at main, n ≥ 30 per hull class per task, drawn v clicked;
the census of creep episodes and ≤ 3-leg turns (round 26's numbers re-read at main).

**M1 — wheeled turreted hulls turn to a drawn facing** (his call). A drawn facing (move, attack-move, screen, support by
fire, ambush) makes the hull turn with M1b's planned turn; a clicked order keeps today's behaviour (the turret takes it).
The support-by-fire 91° case: trace first (the line's slot heading or the face path?); if it is the line's geometry it
is a request to brains through the orchestrator.
**Bar (to the orchestrator before the numbers):** drawn, wheeled turreted hulls median ≤ 15° and ≥ 70 % within 15° on each
task; arrival-to-settled time reported (his "a few seconds longer"), ≤ +6 s median; clicked unchanged; `bridge-pooled`
18/18, the arrive series = main, thirteen lines explained. DECLARED.

**M2 — the creep in tight streets (M3's heir).** Plan the turn: M1b's planner for a wheeled hull whose arc is blocked at
pace, with the pocket and carrot cases (`lab/brains-carrot`) as tests. Bar before numbers: census creep episodes down
≥ 50 %, his bridge 18/18, the Terminus drive arrivals ≥ base and contacts not up. DECLARED.

**M3 — stretch:** a stuck tracked hull's three-point turn (CP3 was rigs only) if the census shows the need.

## How to verify

`make remote T=check` (builder0 only); `make hull-rest-probe`, `make manoeuvre-behind`, the census, `bridge-pooled`;
screenshots of a drawn facing at rest per hull class (look at them); a short clip for him of gang tanks turning to a
drawn facing.

## Don't touch

Traffic's give-way / `_avoid` / avoidance; brains' `game/tactics/**` and elements; `native/**`.

## Waiting on the lead

Nothing: his call is made.

## Status

_Updated 2026-10-12 ~19:30 PDT by the manoeuvre worker (`godot-manoeuvre`, `stream/manoeuvre`; base `c6e32d03`)._

### Plan (ordered, smallest foundation first)

1. **M0** `make hull-rest-probe` at the base (builder0, 4 factions x 6 seeds x 6 tasks x drawn/clicked = O3's
   workload, n >= 30 per class per task), plus each run's `settled_after_s` for the arrival-to-settled line.
2. **M1** the rule (traced, below) + `tests/test_manoeuvre_turret_hull.gd` (fails at base, passes after) + the probe
   re-run on the change, `bridge-pooled`, the arrive series, check; the bar to the orchestrator BEFORE the numbers.
3. **M2** the creep: census at the base first, then M1b's planner for a wheeled hull whose arc is blocked at pace.
4. **M3** (stretch) only if the census shows tracked hulls needing it.

### Progress log

- **M1 test** `tests/test_manoeuvre_turret_hull.gd` (builder0 light lane): base 4 failed (drawn hulls 26-107 deg off:
  gang tank screen 26.3, law tank support by fire 92.7, gang IFV ambush worst 46.8, gang artillery attack-move 107.0);
  `f27c6f16` 5/0 (resting hulls within 7 deg of their own sector; the clicked screen's faces still declined, 301).
  First cut keyed on `_ordered_facing()` turned CLICKED screens too (the element's crews always carry a K1 facing):
  fixed by reading the element task's `facing` (`_drawn_facing`).
- **M1 bar** sent to the orchestrator before any numbers and ACCEPTED (incl. the partial rule for line tasks: where
  the line's +/-30 deg sectors decide, wheels/turret = hover/turret's error +/-5 deg). Granted: the 3 lines in
  `_order_move`.
- **M1 judged runs** from a frozen worktree `godot-manoeuvre-m1` at `748735c9` (one commit, both arms):
  `make manoeuvre-hull-rest` (4 arms), `squad-arrive-series` +/- `--nav-off=turnhull`, then `check`.
- **M2 found while testing M1:** the gang-tank screen (seed 61) leaves one truck shuffling 16 m beside its slot for a
  minute (base and M1 alike). Trace: it overruns a route corner; the next steering point is 120 deg off its nose inside
  the turning circle; `_plan_circle`'s back-up on the lock toward it is blocked 3 m behind, so nothing is planned and
  Steering's circle rule backs/drives reactively while the corner comes back ahead each time (~3 s legs). Not brains'
  under-hull carrot (the corner is 3-8 m off). M2 candidate: `_plan_circle_fill` (back-and-fill on that lock, the away
  arc required to line up: `_plan_fill(align=true)`), `--nav-off=circlefill`; test `tests/test_manoeuvre_creep.gd`.
  All in the `_planned_reverse` callback (the native drive calls it back for every circle case), so no C++ port.

- **M0 done:** `make hull-rest-probe` at `c6e32d03` (builder0) reproduces O3: wheels/turret DRAWN medians screen 39.1,
  ambush 78.5, attack-move 62.3, move 63.8, right-drag 73.8, support by fire 93.5 deg (168 crews each; table
  `references/round28/manoeuvre/m0_hull_rest_base.txt`). Turn census at the base tree (builder0 light lane, Terminus
  seeds 1-3 x mixed/rigs, sim 3-5, Sumps 25 a side 60 s x 3): 917 episodes; static 98 % <= 3 legs, open 79 %,
  friendly 72 %; cause "creep" 121 episodes (Sumps 53 % <= 3 legs, Terminus 31 %), mostly short wheeled hulls
  (scout 26, IFV 26, lancer 13); "circle" 216.
- **M2 candidate `1a13c548`** (two rules, two switches): (a) creep lift (`drive()` body -> native ports it: request
  relayed via the orchestrator, native's session had ended); (b) circle fill (callback, no port). Bar sent and ACCEPTED
  before numbers (orchestrator's condition: after the port, bridge-pooled + Terminus drive once on the ON path at the
  pair's commit). Judged runs from frozen worktree `godot-manoeuvre-m2` at `27b56521`: census seeds 4-7 and bridge-pooled,
  GDScript path, new v `--nav-off=creeplift,circlefill`.
- **M3 (stretch) NOT NEEDED:** in the base census tracked hulls (tank, law_ifv) had 9 of 917 episodes, none over 3 legs.

### M1 judged (two attempts; the second is the LAST this round, the orchestrator's ruling)

**Attempt 1** (`748735c9`, O3's seeds 3 5 8 11 13 21): line tasks pass the partial rule (wheels/turret 27.6-27.9 v hover
28.1-28.7; base 39-103); point tasks medians 6.5-7.5 (base 61-73) but 55-58 % within 15 deg (bar 70 %), crews still
moving at 75 s up. Trace: a crew arriving at the edge of its arrive radius ping-ponged face/move -> `faceslot` fix.
(Also: 576 runs outran slot.sh's 90-min cap; the probe now runs one arm per make call.)

**Attempt 2, LAST** (`140275af`, fresh seeds 2 4 7 9 15 19, base `--nav-off=turnhull,faceslot`; table
`references/round28/manoeuvre/m1_last_attempt_drawn.txt`), wheels/turret drawn, 155 crews a task:

| task | base median / <=15 | change median / <=15 | hover/turret | moving at 75 s (change - base, guard <= +5) |
|---|---|---|---|---|
| screen | 40.9 / 24 % | 27.5 / 33 % | 28.5 | +12 FAIL |
| ambush | 85.4 / 10 % | 26.8 / 33 % | 29.0 | +4 |
| support by fire | 113.1 / 7 % | 27.6 / 27 % | 28.1 | +8 FAIL |
| attack-move | 52.2 / 17 % | 5.5 / 70 % | 1.2 | +3 |
| move | 59.3 / 25 % | 5.2 / 69 % FAIL by 1 pt | 1.5 | +14 FAIL |
| right-drag | 60.3 / 26 % | 6.1 / 64 % FAIL | 1.6 | +25 FAIL |

**Against the bar: NOT MET** (line tasks pass; point-task medians pass; the 70 % line misses on move and right-drag;
the moving guard fails on 4 of 6). Sent to the orchestrator for the ruling (ship on the medians with the cost told to
him, or not shipped); no merge hash named until it rules and check is in.

### M1 smoke test like a player (2026-10-12 ~22:50, `38064858` = M1's code, builder0 light lane, windowed)

`make facing-shots FACING_ONLY=faced_move,faced_screen` (Gangs, seed 3, quiet enemy), change v `--nav-off=turnhull,faceslot`,
1854x1011 and 1200x540; looked at the drag and settled frames (the drag up-left; the gang artillery trucks end cab
toward it). Per-crew errors in those runs: **drawn move** change 7 of 10 within 6 deg, 3 still turning at 75 s; base
settled at 21.5 s with 5 of 8 wheeled turret hulls 65-170 deg off. **Drawn screen** change settled 44.5 s (base 56.5 s),
hulls within their +/-30 deg sectors but one IFV 130 deg (both arms). Phone layout unaffected.

### M2 judged (2026-10-12 ~21:40, `27b56521`, builder0, GDScript path both arms, census seeds 4-7 + sim 3-5)

Bar (sent and accepted before numbers): (1) creep episodes -50 % (30-50 % with a note, < 30 % no); (2) episodes over
3 legs not up, static/open <= 3-leg shares not down > 2 pts; (3) Terminus drive arrivals >= base, contacts not up
> 10 %, mixed and rigs apart; (4) bridge-pooled 18/18; (5) <= 0.5 ms a tick; (6) check, symmetric. (b) failing (3)
alone ships OFF and (a) is judged alone.

| both rules v `--nav-off=creeplift,circlefill` | base | new |
|---|---|---|
| creep episodes (all) | 148 | 123 (-17 %): **(1) FAILS** |
| creep, open kind / of them > 3 legs | 67 / 36 | 41 / 10 |
| creep, friendly kind (pace < 1, left alone by design) | 81 | 78 |
| static <= 3 legs (Terminus) | 93 % (83 %) | 88 % (68 %, a 39-leg episode): **(2) FAILS** |
| Terminus mixed: arrived of 96, leg time, wall contact-ticks | 89, 649 s, 628 | 87, 388 s, 327 |
| Terminus rigs: arrived of 64, leg time, wall contact-ticks | 55, 478 s, 1797 | 51, 629 s, 3261: **(b) fails (3) -> OFF** |
| bridge-pooled (GDScript path) | 18/18 | 18/18 |
| cost (m2_us, Sumps 25 a side, 1800 ticks) | - | ~0.09 ms a tick |

Read: (b) the circle fill hurts the long hulls it is for (a rig pinned on a barricade 1118 ticks) -> OFF. (a) the
creep lift does what it was built for (open-ground creep -39 %, its long episodes -72 %, mixed squad faster and half
the wall contacts) but the census's creep is mostly the FRIENDLY case (avoidance's pace < 1), which (a) leaves alone on
purpose: round 26 M3 lifted there and drove into squadmates.

**(a) alone** (`--nav-off=circlefill` v `--nav-off=circlefill,creeplift`, same commit and seeds): creep 148 -> 118
(-20 %: (1) FAILS); episodes over 3 legs 259 -> 213; static <= 3 legs 93.0 -> 90.8 % (-2.2 pts: (2) FAILS by a hair);
Terminus mixed arrived 89 -> 87 of 96 (leg time 649 -> 388 s, contacts 628 -> 327), rigs 55 -> 58 of 64 but wall
contact-ticks 1797 -> 4136 ((3) FAILS); bridge 18/18. **M2 is NOT shipped.** The arc check does not save the rigs:
rolling a 10 m hull's turn at the line in a street still puts it into the walls the creep was nudging round (round 26
M3 round 2's finding again, now with the clear-arc guard). What would: the creep for a LONG hull planned as legs (M1b's
face planner applied in the drive), and the friendly creep (52 % of what is left) through traffic's give-way, not a
throttle rule. Both are next-round items, not a third attempt tonight (time-box, worker contract 9).

**Branches:** `stream/manoeuvre` = M1 (`140275af`) + docs; **`manoeuvre-m2`** (kept, NOT for merge) = everything
including M2 at `1a13c548` (both rules, their switches, counters, `tests/test_manoeuvre_creep.gd`), for whoever takes
the creep next. Native's port of (a) is NOT needed.

### Known issues

- **Gang trucks screening into 6 m slots** (TacticsLab seed 61: four gang_tank, screen to `[LANE_X, 0]` facing east from
  50 m south): one 10 m truck must parallel-park into a slot between squadmates; at base it shuffles a minute, with M2's
  circle fill it gets round the route corner but still does not settle (and on the GDScript path a second truck joins
  it). A formation-spacing question (slots laid at hull width for 10 m hulls arriving side-on): relayed to brains by the
  orchestrator as a candidate.

### Requests to other streams

- **native** (relayed by the orchestrator 2026-10-12 ~21:30): port M2(a), commit `1a13c548`, `_creep_lift` (callback
  when throttle < line is enough); members `_creep_lift_until`, `_creep_lift_ok`. Flip `tests/test_manoeuvre_creep.gd`'s
  `BrainSwitches.native = false` pin to the default path in the pair commit.

### M1 trace (2026-10-12, base `c6e32d03`, read in code)

The arrival-heading rule is NOT in `order_controller.gd` (`_wheel_hold` there is opt-in and OFF). It is
`TankBrain._order_move` (round 8): any `face` order that is not `told` is turned into a `stop` for a wheeled turreted
hull (`turret_carries_aim`). A squad's drawn facing reaches its crews as the element's SECTOR watch (`HOLD` branch,
`from: _sector_source()` = "order") and that face is never `told`, so it is declined and the hull keeps its arrival
heading. Only a detached crew's `_face_intended_or` (told) was turning. **Change:** the decline skips a face whose
`from` is "order" when the crew's K1 order itself carries a facing (`_ordered_facing()`: drawn); a clicked order has
none, so it is still declined (the turret takes it). Switch `--nav-off=turnhull` (= base) in
`OrderController.hull_turn_on()`. **Merge note:** a 3-line edit in brains' `tank_brain.gd` `_order_move` (the rule the
brief assigned to manoeuvre lives there) and `turnhull` added to `Movement.OFF_NAMES`; no C++ (the think half is
GDScript; the face is executed by M1b's `face_turn`, already ported).
