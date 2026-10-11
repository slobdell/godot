# Stream: manoeuvre (three-point turns, and a short move behind a vehicle is a reverse, not a pirouette)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* (his words and
> readings (7)–(8)), `_agents/navigation.md` (the planned reverse and k-turn of rounds 11–14, the circle fit, the
> counters), `_agents/workstreams.md` *Round 26* (C26.1, C26.2, C26.5 are yours), lesson 286 and `_agents/native.md` *N7*
> (the k-turn planner priced at ~0.13 ms a tick: it stays GDScript). You own in `game/ai/movement.gd` the body of
> `drive()`, `_nose_stop`, `unstick`, `_pressing_escape`, the `press_on`/`inflate_on`/`nose_stop_on` switches and the
> k-turn / planned-reverse / circle block (`kturn_on` through `_look_stop`); `game/ai/clothoid.gd`,
> `game/ai/wall_contact.gd`; new `game/ai/manoeuvre*.gd`; new `tests/test_manoeuvre*.gd`, `tests/test_kturn*.gd`, new
> `tests/ai_scenarios/scenario_manoeuvre*.gd`; `mk/nav.mk`'s k-turn/reverse targets and a new `mk/manoeuvre.mk`.
> **C26.2:** `drive()`'s body and the k-turn leg's execution (`_kturn_start_leg`, `_kturn_stopping`, `kturn_brake_on`)
> are mirrored in `native/src/drive_native.cpp`; `_outline_ok`, `_arc_hit`, `_chord_compute` have an OFF port with a live
> proof. `_planned_reverse` and `_kturn_end` are CALLED BACK from the native drive: change those freely. Anything
> mirrored: send perf the diff.

## The lead's direction (2026-10-10)

> *"I notice that when vehicles get stuck, they do an N point turn where N is however many iterations it take to go
> back and forth to clear the obstacle. Generally speaking, a vehicle should be able to do a 3 point turn such that
> they drive forward the max amount to make most room, then back up enough such that their next turn will be able to
> clear whatever obstacle they're facing"*

> *"if I have a unit selected and I select a point to move to that's immediately behind it, the vehicle will do this N
> point turn to clumsily rotate in place and then eventually drive the very short distance to the point. A smart
> vehicle would have just reversed onto the point or did other 3 point turn maneuver (back up so that the target point
> becomes within its turning radius as it drives forward)"*

The readings (not his words): (7) a stuck vehicle turns in three PLANNED legs: forward as far as it is clear (making
room), reverse exactly far enough that leg 3's arc clears, then away. (8) For a goal close behind or beside (inside the
turning circle), pick the cheapest manoeuvre by planned time: reverse straight onto the point, or back up until the
point is outside the turning circle and drive forward onto it; never an in-place shuffle. A facing given with the order
(right-drag) decides which end arrives first; without one, the cheaper.

## Where things stand (VERIFY at main)

- The planner exists: `_planned_reverse` (the native drive's callback), `_plan_fill` / `_best_fill` / `_single_backup`,
  `_arc_hit`, `_outline_ok`, the circle fit (`circle_fit_on`, `_circle_gate`), counters in `Movement.route_arms()`
  (`kturns`, `kturn_multi`, `kturn_multi_legs`, `kturn_none`, `kturn_aborted`, `kturn_looked`, `kturn_eased`) and switches
  (`kturn`, `kturnbrake`, `kturnfill`, `kturnlook`, `kturnrollout`, `kturnslide`, `--nav-off=…`).
- Tools: `make nav-terminus-drive`, `nav-kturn-buckets`, `nav-reverse-buckets`, `nav-sim-legs`, `nav-wall-clip` (a
  before/after clip at his pose), `nav-rig-clip`.
- In play he sees many short legs; nobody has counted legs per turn on HIS cases, nor the goal-behind case at all.

## Backlog (in order)

**M0 — count first (no fix).** (a) The goal-behind scenarios: one vehicle of each hull class (a tank, a wheeled scout,
a War Rig) given a plain move to a goal 5 / 10 / 20 m dead astern and at 120° / 150° off the nose, with and without a
drawn facing; per case: time to arrive, legs, total heading change, metres driven. (b) The stuck census: every k-turn
in the Terminus drive, `nav-sim-legs`' match and Sumps 25 a side, with legs per turn and the obstacle kind (C26.5:
static / friendly / enemy). Pool over pre-registered start ticks and 3 seeds. Pre-register both pass lines in Status
(suggested: (a) ≤ 2 legs in every goal-behind case, never slower than main by more than 0.5 s, and faster on the median;
(b) ≥ 95 % of static-obstacle turns ≤ 3 legs, no new wedges or `kturn_aborted`, the friendly share reported apart).
A his-pose clip of the 10 m-astern case at main, looked at.

**M1 — the short move behind (DECLARED; CP2).** Before the route starts: if the goal lies inside the turning circle or
behind the axle line within a short range, plan by time between (i) reverse straight onto the point (a reverse gear
leg, clear by `_outline_ok` along it), (ii) back up until the point is outside the turning circle, then forward, (iii)
today's route, and take the cheapest that is clear; a drawn facing picks which end arrives. Prefer the callback layer
(`_planned_reverse`) or a new `manoeuvre.gd`; send perf any `drive()` diff (C26.2). Pass: M0(a)'s line; the thirteen
lines as declared; the clip looked at. Both sides (the CPU's crews take the same path).

**M1b — the face at rest (C26.9, added 2026-10-10 ~23:40 from your M0).** A short move behind with no drawn facing
arrives keeping the hull's heading at the order (no face turn); a drawn facing still wins. A wheeled hull that must
face a new way at rest does a planned three-point turn (M2's planner) instead of the creep's 0.5 s legs. Granted:
the face-at-rest path in `order_controller.gd`. Pass: M0(a)'s cases settled (not only arrived) in ≤ 2 legs plus at most
one planned face turn, faster than main; part of CP2.

**M2 — the three-point turn (DECLARED; CP3).** When stuck against a static obstacle: leg 1 forward as far as is clear
(not a fixed short leg), leg 2 reverse exactly far enough that leg 3's full-lock arc clears (computed by `_arc_hit`
over the obstacle, not by trial), leg 3 away; re-plan only when the world changed (a friendly moved in), counted. Pass:
M0(b)'s line; `make nav-terminus-drive` and `bridge-pooled` not worse; his-pose clip looked at.

**M3 — stretch:** whatever M0's census shows next (a hull class that still needs > 3 legs; turns started against a
friendly that traffic's convention should have prevented — report those to traffic through the orchestrator).

## How to verify

`make remote T=check` (read the wrapper's line), scenarios and censuses on builder0, the clips on the laptop through the
orchestrator (C26.7). Every number: commit, machine, workload, n.

## Don't touch

Traffic's `movement.gd` give-way block, `_avoid`, `_around_friends`, `avoidance.gd`, `steering.gd`; the rest of
`movement.gd` (routes, gates, chord, station-keeping: brains'); `native/**` (perf's); `game/control/**` (orders').

## Waiting on the lead

Nothing. Questions go in Status; take the most reversible option.

## Status

_Not started._
