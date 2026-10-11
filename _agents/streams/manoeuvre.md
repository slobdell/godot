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

_Updated 2026-10-11 ~12:00 by the manoeuvre worker (`godot-manoeuvre`, `stream/manoeuvre`)._

### The report (read this first)

- **Done:** M0a (the goal-behind probe), M0b (the turn census), **M1 + M1b = CP2, MERGED on main as `0845c3c7`**
  (`25f8cfa4`, check 2406/0 ALL JUDGED; bridge 18/18 = main; arrive 99/100 = main). His short move behind: War Rig
  10 m astern settled 43.1 -> 1.7 s, scout 5 m with a facing 6.07 -> 0.67 s, tank 10 m 3.67 -> 2.47 s; every cell
  faster or equal (sections below).
- **M2 = CP3, MERGED on main as `f193bcb8`** (`93a657b8`: check 2410/5 = the known army_cap leak, alone 13/0;
  bridge 18/18 = main; arrive 99/100 = main; sim baseline crossing + yard_open moved, declared, read twice): the planned AWAY leg (leg 3 of a
  three-point turn driven as a leg, not left to the pursuit law) and the inside-circle back-up, **for long hulls
  (>= 10 m: the War Rig) by default**: on all wheels it halved the rigs' wall contacts but cost the mixed squad 14 %
  more (Terminus drive A/B below), so it follows round 15's `kturnbrake` precedent. Not DECLARED-ready until its check
  and the paired series (bridge, arrive) are in.
- **Against M2's pre-registered line (>= 95 % of static turns in <= 3 legs, pooled):** NOT met as a clean pass. The
  pooled census reads 85.5 % at main, 93.3 % at main+CP1a, **95.6 % at CP2** (one run each; the Sumps fights move
  this +/- 3 points run to run); the Terminus drive alone, 8 seeds: 80.6 % -> 84.4 % with M2 on all wheels. What
  fails it: turns whose goal is re-issued mid-turn (`end: new_goal`, a CPU element re-seating), a rig boxed in a
  pocket where no back-up fits (the circle plan refuses; Steering's circle rule then shuffles against a carrot that
  flips sides — the route's corner under the hull, brains' route code), and reverse legs meeting walls the navmesh
  sweep passed. Written up rather than forced (time-box, contract item 9).
- **CP3's paired series** (M2 rigs-only at `6b545fca`, builder0, vs CP2 = main's game code at `25f8cfa4`): his bridge
  drill 18/18 (= main, same two excused deaths); the arrive series 99/100, every cell identical to main (its squads
  have no hull over 10 m, so M2 cannot act there). The orchestrator re-assigned the 95 % static line (C26.6): the
  remaining long turns are mostly the creep beside friends and the carrot flips, i.e. other streams' causes.
- **Handed on:** brains diagnosed the rig's carrot flip (a route corner under the hull's footprint passes the 1.5 m
  `WAYPOINT_MIN_M` skip; an `_on_hull` rule at n = 3 is a trade) and parks it for round 27; traffic takes the creep
  with its convention (census rows now name the hull in the way and whether it moved, `6b545fca`).
- **Requests to other streams:** traffic — the in-drive CREEP is the largest source of long turns (149 episodes in
  one census, 81 of them `friendly`): a wheeled hull at full lock whose throttle avoidance has paced under the
  plant's creep threshold (0.5 x |turn|) shuffles in 0.5 s legs beside a friend; brains — the route carrot that flips
  between a corner under/behind the hull and one ahead (Terminus rigs seed 2, Green_S0_3 at (-18.7, -21.3), 23 legs).
- **What to playtest:** `make native && make skirmish`; select one vehicle and right-click a point a few metres
  behind it (with and without a right-drag facing the way it already points): it reverses onto the point and does
  not turn round after. A War Rig told to face behind it at rest turns in three legs and stays on its spot.
- **M3 (the orchestrator's request: the creep line) — TIME-BOXED OUT, written up for round 27 (branch `manoeuvre-m3`,
  NOT for merge).** Rule: right after `cmd.throttle = drive_vector.x * speed_factor * pace` in drive(), a wheeled
  hull not in a planned leg whose |throttle| fell under the creep line (0.5 x |turn|) gets the line. All builder0,
  GDScript path, `--nav-off=creepline` the control, main+CP1a2+CP3:
  - Round 1 (`f46fae96`: lift above half pace, else HOLD STILL): census creep episodes 114 -> 1, <= 3-leg turns
    friendly 75.6 -> 85.3 %, open 75.5 -> 87.0 %; but **his bridge drill 9/18** (control 18/18) and the Terminus
    drive's mixed squad arrived 151/192 vs 180, leg time 1019 -> 2163 s: crews held still at the bridge mouth and in
    the streets.
  - Round 2 (`f8f142ab`: lift only): bridge 18/18; census creep 1, <= 3-leg friendly 82.9 %, open 85.9 %; but the
    Terminus drive is worse: mixed contacts 1047 -> 1662, press/unstick 63 -> 154; rigs arrivals 104 -> 98, leg time
    1160 -> 1623 s, contacts 4628 -> 7344. Rolling the arc at the line drives hulls into the walls the shuffle was
    nudging round.
  - What it says: the creep is a SYMPTOM of a turn that the street has no room for at pace; neither stopping nor
    rolling fixes it alone. Round 27: plan the turn (M2's planner for every hull, with the pocket and carrot cases
    fixed first), or let avoidance's pace hand the hull a planned give-way instead of a slowed arc. Perf's port
    (`9749c766` + `1024845a`, round 1's rule) is held, not queued.
- **Next steps:** M2's check + paired series -> declare CP3 (rigs only); then the creep (with traffic) and the
  pocket case (with brains).

### Plan (ordered, smallest foundation first)

1. **M0a** the goal-behind probe (`tests/manoeuvre/goal_behind_probe.gd`, `make manoeuvre-behind`): tank / scout / War
   Rig, 5/10/20 m astern and 10 m at 120/150 deg, +/- a drawn facing (= the start heading), start ticks
   {1,3,6,8,11,16} x seeds 1-3 (180 rows a hull). Through control's Orders with `source: player`, as a right-click.
2. **M0b** the turn census (`game/ai/manoeuvre_census.gd`, `--turn-census`/`--turn-log`, `make manoeuvre-census`):
   every turn EPISODE (first reversal on a forward order -> driving clear), its legs, its kind (static / friendly /
   enemy / open) and the rule that reversed it, over the Terminus drive (mixed, rigs x 3 seeds), the sim-baseline
   match (seeds 3,4,5) and Sumps 25 a side (3 seeds, 60 s). OFF by default (it reads every hull every tick).
3. **M1** (DECLARED, CP2) `game/ai/manoeuvre.gd`: per new goal behind, simulate today's forward drive and a reverse
   with the plant + steering law, clearance by `_outline_ok` and hull discs, take the cheaper; a drawn facing picks
   the end. Executed as `reverse: true` on the order (no `drive()` body change below the hook); the hook
   `order = _manoeuvre(order)` heads the GDScript drive and is a CALLBACK for the native drive (perf: one call).
4. **M2** (DECLARED, CP3) the planned three-point turn for static obstacles.
5. **M3** stretch: from the census (expected: the wheeled FACE turn, below).

Decisions (one line each): goal-behind executed as an order flag, not new leg code, because the reverse law exists on
both paths and is closed-loop (arrives within the arrive radius whatever the plant does); options simulated with the
plant rather than closed-form, because Steering's circle rule and the creep make closed forms wrong; census off by
default, because it is per-tick GDScript on every hull and the laptop tick is perf's budget.

### Pre-registered pass lines (before any M1/M2 number was seen)

- **M0a / M1:** every goal-behind case <= 2 legs (median per cell); per cell `done` never slower than main by more than
  0.5 s and the median over cells faster; `settled` reported beside it (it includes the post-arrival facing turn,
  which is ORDERS' heading, see Requests).
- **M0b / M2:** >= 95 % of `static` turn episodes <= 3 legs, pooled over the three workloads; no new wedges
  (`wedged_units`), `kturn_aborted` not up; friendly share reported apart (C26.5).

### M0a at main (b57838ed, builder0, light lane, 180 rows a hull; every cell identical over ticks and seeds)

| hull | case | facing | done s | settled s | legs | metres | heading deg turned | what it does |
|---|---|---|---|---|---|---|---|---|
| tank | astern5 | - | 2.27 | 2.50 | 1 | 2.5 | 178 | pivots 180, drives 2.5 m |
| tank | astern5 | drawn | 2.27 | 5.37 | 1 | 2.5 | 354 | pivots 180, drives, pivots back |
| tank | astern20 | drawn | 4.10 | 7.00 | 1 | 17.7 | 375 | same |
| scout | astern5 | - | 2.93 | 3.13 | 1 | 26.5 | 268 | a forward loop round its 5 m circle |
| scout | astern5 | drawn | 5.60 | 6.07 | 1 | 57.5 | 455 | a bigger loop for the arrival gate |
| scout | astern20 | drawn | 19.67 | 19.90 | 3 | 176.1 | 1478 | circles four times |
| rig | astern5 | - | (0) | never in 45 s | 89 | 43.8 | 176 | "arrived" at once (6 m settle radius), then CREEPS 0.5 s legs to face backwards for 45 s |
| rig | astern10 | - | 7.6 | 43.1 | 27 | 94.8 | 383 | drives round, then 35 s of creep to face backwards |
| rig | off150_10 | drawn | 21.6 | 33.8 | 11 | 105.5 | 424 | |

(The full 30-cell table: `streams/references/round26/manoeuvre/m0a_main_table.txt`.) **Finding: most of what he
called the N-point turn on a goal behind is the POST-ARRIVAL facing turn.** A plain move's Orders heading is the
direction of travel, so after a short move behind the post faces BACKWARDS and the brain turns the hull round; a
wheeled hull turns on a `face` order by the plant's creep (0.35 throttle at full lock < the 0.5 creep threshold:
alternating 0.5 s legs). Reversing onto the point fixes the arrival; the turn after it needs orders (Requests).

### M1 + M1b (CP2, DECLARED; GDScript path `--brains-off=native` until perf's callback; builder0, 540 rows)

What changed (`game/ai/manoeuvre.gd`, `movement.gd` `_manoeuvre` / `keeps_heading` / `face_turn`, the face branch of
`order_controller.gd` under the C26.9 grant):
- **M1:** per new goal behind (more than 100 deg off the nose, or inside a wheeled hull's forward circle, within 25 m),
  the forward drive and a reverse are SIMULATED with the plant and Steering's laws, cleared with `_outline_ok` and
  hull discs; the cheaper clear one is driven (`reverse: true` on the order); a drawn facing within 60 deg of the nose
  forces the reverse, any other forces the forward drive. A goal that replaces another within 2 s while the hull kept
  driving is a re-aimed steering point (brains' orbit): forward drive, never a reverse (`refused.reaimed`).
- **C26.9:** a post face that is the TRAVEL of a short move behind (post heading more than 100 deg off the nose and
  within 25 deg of start->post) is held: no turn after arriving. A drawn facing is not the travel, so it still wins.
  Covers the goal already inside the arrive radius (the War Rig 5 m astern never drives).
- **M1b:** a wheeled hull facing a new way at rest drives a planned turn: n equal legs alternating gear on one lock
  (each <= 60 deg of heading), the fewest n that is clear and ends within its settle radius (a half turn = 3 legs and
  back on its spot); else legs as long as the room allows; else the creep as before. The plan holds while the spot's
  bearing from where it began holds (a post's face spot is re-issued every think from wherever the hull is).

Settled seconds, main (`b57838ed`, native) -> M1 (GDScript), every cell identical over 6 start ticks x 3 seeds:

| hull | 5 m | 5 m drawn | 10 m | 10 m drawn | 20 m | 20 m drawn | 120 deg | 120 drawn | 150 deg | 150 drawn |
|---|---|---|---|---|---|---|---|---|---|---|
| tank | 2.50 -> 0.97 | 5.37 -> 0.97 | 3.67 -> 2.47 | 5.73 -> 2.47 | 4.37 -> 4.37 | 7.00 -> 4.97 | 2.90 -> 2.90 | 4.60 -> 4.10 | 3.30 -> 2.50 | 5.33 -> 3.47 |
| scout | 3.13 -> 0.67 | 6.07 -> 0.67 | 3.20 -> 1.57 | 6.53 -> 1.57 | 3.70 -> 3.00 | 19.90 -> 3.00 | 2.43 -> 2.20 | 2.63 -> 2.20 | 2.83 -> 1.77 | 3.10 -> 1.77 |
| War Rig | never -> 0 (stays: inside its 6 m settle radius) | never -> 0 | 43.1 -> 1.7 | 22.8 -> 1.7 | 36.4 -> 4.2 | 27.6 -> 4.2 | 31.6 -> 5.6 | 22.6 -> 9.2 | 36.7 -> 3.8 | 33.8 -> 6.1 |

Legs (median): 1 everywhere except the War Rig at 120/150 deg (2; with a drawn facing 4 and 3 = two to arrive plus
one planned face turn). Full table `references/round26/manoeuvre/m1_table.txt`. **Against the pre-registered lines:**
settled faster or equal in all 30 cells (equal where today's drive is still the cheaper: tank 20 m and 120 deg with no
facing); legs <= 2 + one planned face turn everywhere; `done` within +0.5 s of main in 29 of 30 cells, the exception
tank 20 m with a drawn facing (done 4.10 -> 4.87 s, +0.77: the reverse is forced by the facing; settled 7.00 -> 4.97).
Known and unchanged from main: the scout does not turn to a drawn facing at rest (it ends 84 / 40 deg off at
120 / 150 deg; main 171 / 166) — a fixed-gun scout's post facing is brains' S6 rule, not this path.

### ✅ CP2 READY (2026-10-11 ~08:00): `manoeuvre-cp2` at `25f8cfa4` is green — builder0 `make check exited 0`, 2406/0, 23 targets, ALL JUDGED

C26.1's paired series on `25f8cfa4` vs main `6434f968` (builder0): **his bridge drill** (8600d892's check form,
seeds 1-3 x ticks {1,8,15} x both sides): 18/18 both, crossed 70/72 both, arrival median 41.5 s both, deck jam
summed 32.7 s both. **The arrive series** (5 maps x 5 squads x 4 seeds, attack-move 150 m): 99/100 both; 24 of 25
cells identical; sumps law_ifv:law_ifv:law_suppressor:law_tank median 47.1 -> 50.4 s (4/4 both).

Census on the cp2 tip vs main+CP1a (`--nav-off=behind,faceturn` on the same tree; builder0; files
`references/round26/manoeuvre/census_{main_cp1a,cp2}.txt`): static 104 eps 93.3 % <= 3 legs -> 91 eps 95.6 %;
friendly (traffic's C26.5 input) 287, 69.3 % -> 329, 73.9 %; open 77.6 -> 79.4 %; face at rest on the Terminus
4/49 -> 31/47 within 3 legs.

### CP2 = branch `manoeuvre-cp2` (the orchestrator's recipe: my fixed CP2 + main + perf's port; M2 is NOT in it)

`613f665b` (M1 + M1b) -> `9cd4310e` (face turns bounded to their spot and refused when the world refuses them) ->
`c50765a4` (brains' creep-bound CONTROL arm also switches `faceturn` off: C26.6, granted; not a loosened line) ->
merge main `3701f398` (CP1a) -> merge perf `c892870c` (the native drive calls `_manoeuvre` back) -> `20182a58`
(test_manoeuvre_behind back on the native default path) -> `25f8cfa4` (sim baselines: 10 maps moved, read twice on
builder0 at `20182a58`, agreeing; yard, pit, crossing unmoved). The goal-behind probe on `20182a58` (native ON)
reproduces the GDScript table cell for cell, except the War Rig's drawn-facing cells after the face fixes:
120 deg 9.2 -> 9.6 s, 150 deg 5.8 -> 6.5 s (main 22.6 / 33.8). **Cost:** perf sized the callback at 0.04-0.08 ms a
tick at Sumps 25 a side (builder0, c892870c); the planner runs once per new goal (counter `behind_asked`).
**Hull facing at rest (orders' relay), `make nav-facing` (yard, 30 crews, 5 squads told to face 90 deg off their
travel), builder0 `20182a58`:** heading error at +10 s median 1.1 deg, 24/26 within 15 deg; its control
(`--nav-off=faceturn,behind`, main's creep) 1.7 deg, 23/26; shuffle median 0.84 vs 1.11 m. The two misses in both
arms are fixed-gun scouts on `stop` (brains' S6). So on this roster the hulls DO come round with or without CP2; the
35-100 deg of orders' gang-squad probe is not reproduced here (a turreted wheel under `wheelhold` is opt-in and off).

### M0b: the turn census (builder0; 3 Terminus drives x 2 squads, 3 sim-baseline matches, 3 Sumps 25 a side 60 s)

Episodes (first reversal on a forward order -> driving clear), share in <= 3 legs, by what was in the way. "main" is
this branch with `--nav-off=behind,faceturn` (main's behaviour on the GDScript path); `face` / `direct` reported apart.
Files: `references/round26/manoeuvre/census_{main,m1,m2}.txt`.

| kind | main | M1+M1b | M1+M1b+M2 |
|---|---|---|---|
| static | 124 eps, 85.5 % | 121, 87.6 % | 103, 91.3 % (a second run: 99, 92.9 %) |
| friendly (C26.5, traffic's) | 302, 75.8 % | 287, 74.2 % | 343, 83.7 % |
| enemy | 28, 100 % | 23, 100 % | 19, 100 % |
| open (nothing in the way: circle rule, creep) | 423, 79.9 % | 360, 75.0 % | 363, 83.7 % |
| face at rest (apart) | 27, 66 % | 60, 95 % | (planned turns) |

What drives the long turns at main (episodes over 3 legs): the in-drive CREEP (a wheeled hull at full lock with
throttle under the plant's creep threshold: 65 eps), Steering's CIRCLE rule (51), give-ways (30), then planned
singles (13). Static alone: kturn_single 6, kturn_fill 4, circle 4, creep 2, yield 2 (of 124).

### Requests to other streams

- ~~orders~~ (superseded by the orchestrator's C26.9 ruling, done in my granted path): a plain move with NO drawn facing whose destination is a short move behind the
  group (within `Manoeuvre.MAX_M` = 25 m of its centre and more than `Manoeuvre.BEHIND_DEG` = 100 deg off its mean
  forward) keeps `heading` = the group's mean forward (`Orders._resolve_group`, where `heading = travel.normalized()`),
  so the post faces where the crews faced and nobody turns round after reversing onto it. Measured cost today: the rig
  creeps 35-45 s after arriving. (Pending M1's numbers to attach.)

### Questions for the lead

- none yet.
