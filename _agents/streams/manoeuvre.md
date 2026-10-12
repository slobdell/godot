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

_Not started._
