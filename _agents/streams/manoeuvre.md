# Stream: manoeuvre (no crew sits against a building or container: a crew that makes no progress notices and gets out)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 345, 348, 352), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 47** (C47.1-C47.11; C47.3 is the seam with route), your last brief `streams/archive/round46/manoeuvre.md` (FINAL REPORT and
> leftovers), and `game_design.md` *His playtest after round 46's ships* and *His second match*. **You own:** movement's drive /
> unstick / side-step / avoidance / yield / backout and the new no-progress watchdog (`game/ai/movement.gd` but the planner seam),
> `game/ai/traffic.gd`, `game/ai/wall_contact.gd`, `game/ai/avoidance.gd`, `game/tactics/tactics_formation.gd`'s manoeuvre functions,
> `game/tactics/element_plan.gd`'s `grouped()` and converge, `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`,
> `tests/test_traffic*.gd`, `tests/test_formation*.gd`, `mk/manoeuvre.mk`. **Model:** Opus. **Machine:** builder3 (builder0 a light
> lane). **Seeds:** 12401-12448 (Bar M), 12449-12496 (reserve). Dev 7001-7012 (never a bar).

## The lead's direction (2026-10-30, verbatim)

Locks: "I had all my squads go directly west and then north to cross a bridge (2 squads of fire trucks). At least one them just drove
straight forward into a building and got stuck, which makes no sense, and it makes our units look dumb"

Crossing: "I had a squad of 4 IFVs traverse the bridge and they all got picked off one by one - I still feel like there's inefficient
navigation going on with vehicles getting stuck behind containers and so forth; in this case the vehicle obstructions would have been
gone for the rear vehicles because the ones in front of them already got destroyed."

Memory: units must look smart and under his control; contention first; smart AI on both sides.

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0, 28 ALL JUDGED)

- **Locks** (`references/round46/playtest/2026-10-30T15-49-20-locks.jsonl`): **Green_Burners2_4** reached (-21, 66) by tick 150 and stays at (-21..-19, 66..73)
  through tick 300 (5+ s), phase `driving`, `blocked` EMPTY, while its squad drove on. Green_Burners_2 stalled at (-81, 80) ticks 210-240.
  Nothing today notices a crew that is "driving" and not getting closer: that is the gap.
- **Crossing** (`references/round46/playtest/2026-10-30T15-41-59-crossing.jsonl`): Hunters (gang_ifv) ordered tick 3034 to (-68.7, -57.9). Hunters_3 at (-80, 78)
  and Hunters_4 at (-60, 64) "driving" without moving ticks 3060-3150 (3 s); after Hunters_1/5 died (3151, 3192) Hunters_3 dithered
  around (-77, 48) ticks 3240-3360 (4 s) with no progress. The dead squadmates' wrecks/stations may still be steering it: check.
- On main ON: backout (R45.26), shortfwd (R46.35), holdway (native only; web OFF, R46.34/35). OFF: S v6 (R47.3: stays off).
- Round-46 leftovers: S v6 start-zone give-way (dropped with S v6), holdway's web freeze (t ~11 s), the yield pushing a held crew toward
  the enemy (seed 12328), backout pose 10, holdway head-on.

## Backlog (in order)

1. **M1 the trace (Status first, then message the orchestrator):** per tick for Burners2_4 (Locks 120-320), Burners_2 (190-260),
   Hunters_3 / Hunters_4 (Crossing 3040-3370): goal, next station, speed, steering terms, contacts (buildings, containers, squadmates,
   wrecks), the unstick/backout state and why each did not fire. Name the cause per crew. Replays: `make replay-match`.
2. **M2 the no-progress watchdog, ON, `--traffic-off=noprogress` the escape:** a crew whose distance-to-goal along its route has not
   fallen by ~X m in ~Y s while "driving" (X, Y from M1's cases, not tuned to his seeds) first runs the existing unstick/backout, and if
   that fails asks route for a new route via `Pathing.reroute(crew, reason)` (C47.3: route owns the call; use its stub). A crew he
   HOLDs or one legitimately waiting (holdway, give-way) never trips it. Symmetric (C47.9). Tests first: a staged crew nose-in to a
   building corner (Burners2_4's geometry) that today sits > 5 s; a rear IFV whose blockers die (Hunters_3's) drives on within ~1 s.
3. **M3 Bar M**, filed BEFORE any number on 12401-12448: deciding = crew-seconds "driving with no progress" (the trace's measure) and
   his cases' stall seconds; guards = arrival all-in, contacts, wedged crew-s, the yield/holdway lines, engage's authority probe
   (a held crew never moves), orders' default probe rows. Native twin first (C47.6). Ships ON when it passes; name the green hash.
4. **M4 his acceptance read:** Locks and Crossing replays on the shipped tree: the stall seconds of the four crews before/after.
5. **M5 leftovers in order of what he'd notice:** the yield pushing a held crew toward the enemy (12328), holdway head-on, backout pose
   10, holdway's web freeze (low priority: memory *native game over browser*).

## Don't touch

`game/ai/pathing.gd` and `game/ai/planner/**` (route's: ask through C47.3), `game/control/**` (orders'), `element.gd` / gunnery (engage),
`native/**` (native twins it), `game/camera/**`, `arenas/**` and `game/arena/**` (mapkit), `tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### NOW (2026-10-30 ~19:15) — where this stream is

- **M1 done** (report below). **M2a `buried` built; Bar M's frozen tree 1aa41aeaf GREEN builder3 (3522 / 0, check exited 0).** From
  that check: **D1 PASS** (his staged Locks case, Burners2_4 0.0 s <= 1.0) and **G6 PASS** (Crossing guard 1.0 / 0 / 1.97 / 0 s < 2.5).
  The series is running on builder3 as ONE run from 4ab917680 (1aa41aeaf + the series make target + a staged test; no game code):
  W1 (12401-12424) then G8; then W2 (route-census 12425-12448, both sides) from a W2 tree = 4ab917680 + main (5f96c2d45; movement.gd
  and tank_brain.gd byte-identical to 1aa41aeaf; side worktree ../godot-manoeuvre-w2, removed when W2 ends). Raw rows:
  `~/overnight-manoeuvre/r47/barm/`.
- **M2b, the watchdog, committed (5cacac0af, OFF: `--traffic-on=noprogress`; merged with main 0e0837a76):** game/ai/noprogress_watch.gd,
  a GDScript sampler outside the drive. A crew driving or blocked by TERRAIN (never a hull jam: a dev read showed re-planning squad
  jams every 3 s made them worse, 618 -> 737 crew-s) with no progress for 3 s (1 s when `blocked: no_path`) asks route
  `Pathing.reroute(crew, &"noprogress")`. **Pathing.reroute (R47.25's grant, route ended):** a crew whose route is unreachable is
  routed from the nearest point (rings 2.5-8 m, clear of hulls) the goal is reachable from. The CPU's staged sliver case is GREEN with
  it (Hunters_4 / Hunters_2 within 8 m of their seats by ticks 124 / 205; today Hunters_2 never); his Locks case and the Crossing guard
  unchanged; route's + native's pathing tests 21 / 0 (light lane). **Decision:** the brief's "first unstick / backout" is not called
  from the watchdog: they live in the native execute and fire on their own triggers; the watchdog's job is what they cannot see.
  Known: with the sliver fixed, Hunters_2 then waits 4.3 m from its seat behind an arrived squadmate (a settle contention: reported,
  not asserted). Its own bar follows Bar M.
- **M5a `holdyield` built (df26c0d5f, OFF):** a crew holding his post (TankBrain._his_post) never takes a yield spot > 0.5 m closer
  to an enemy hull within 60 m, nor one > 8 m from his post; otherwise it gives way in place. Engage's lane probe, light lane,
  builder3: **12328 post drift 10.1 -> 0.0 m, and from its post the crew kills the gun (gun hp 0.5 -> 0.0)**; dev 7001-7012 identical
  in every line, both arms. Two steps of the build, said: the controller's `visible_enemy_names` is empty for a brain crew and the
  gun's target flickers between shots (both read in the trace), so the veto reads enemy hulls in range; with the near spots refused
  the yield took `spot(24,0)`, 24 m on, hence the 8 m bound. Native: _begin_yield is mirrored in C++, so ON runs the GDScript yield
  (native_yield off) until native twins `_holdyield_veto`. Bar H waits on seeds.
- **Requests to other streams (19:35, via the orchestrator):** seeds for Bar H (13001+); native: twin `Movement._holdyield_veto`;
  engage (FYI): HOLD's return to his post uses arrive 6.0, so any other displacement still parks him up to 6 m short.
  **Questions for the lead:** none.

### BAR H (FILED 2026-10-30 ~19:40, before any number; `holdyield`, M5a)

**The change:** `--traffic-on=holdyield` (Movement._holdyield_veto inside _begin_yield's two spot loops), as in df26c0d5f. **Frozen
tree:** the first commit after 3635507bd whose check is green. **Native:** ON runs the GDScript yield (native_yield off for the rule,
Traffic._chain_native) until native's twin lands (R47.30); BASE runs today's native yield, so the arms differ in the yield path too:
said, and G6 is the line that catches a cost from it. **Machine:** builder3, after Bar M / Bar W's series. **Seeds:** 13001-13024
(R47.30). **Arms:** BASE v HOLD (`--traffic-on=holdyield`).
**Workloads:** engage's lane probe (`engage-lane-probe`, 30 s; its seed picks the mode: cpu / attack / post) on 13001-13024;
orders' group-order probe (`manoeuvre-bar-m` with BARM_ARMS base / hold, `--noprogress-census`) on 13001-13006, four maps.

| Line | Statistic | Passes when |
|---|---|---|
| **D1 his case** | lane probe seed 12328 (named cell, engage's) post_m | HOLD <= 1.0 m (BASE 10.1) |
| **D2 deciding** | lane probe, post-mode cells: post_m (drift from his post) | HOLD <= BASE in every cell AND pooled HOLD < BASE, or all identical (then the bar reads "no case on fresh seeds", said) |
| G1 | lane probe, every cell: first_shot_s, enemy_hp, died | each pooled within +1.645 se (or identical) |
| G2 | lane probe, cpu / attack cells | identical in every line (the rule reads only his post) |
| G3 | group probe: noprog_s, all_in_s, blocked_s, yielding_s, contact_s | each <= +1.645 se |
| G4 | engage's authority probe (6 seeds 13019-13024) | rows identical |
| G5 | test_manoeuvre_noprogress (his staged cases) | green |
| G6 | check; SCRIPT ERROR | exited 0; none |

At most two amendments, before numbers.

### BAR W (FILED 2026-10-30 ~19:15, before any number; the watchdog `noprogress` + Pathing.reroute off a sliver)

**The change:** `--traffic-on=noprogress` (game/ai/noprogress_watch.gd) and Pathing.reroute's off-island route (R47.25), as committed
in 5cacac0af. **Frozen tree:** the first commit after 537fca5ee whose check is green (Bar M's rule as it then stands, both arms).
**Native:** no twin needed (C47.6): the watchdog is a GDScript sampler outside the execute step; reroute's write is a door that marks
the mover stale, and its queries are Pathing.query / closest_point (native's own). Both arms native ON. **Machine:** builder3, after
Bar M's series. **Arms:** BASE v WATCH (`--traffic-on=noprogress`), both `--noprogress-census`; Bar M's `buried` in both arms at
whatever Bar M decides (OFF if Bar M fails). **Seeds:** W1' = Bar M's W1 workload on **12449-12472**; W2' = route-census on
**12473-12496** (both sides).

| Line | Statistic | Passes when |
|---|---|---|
| **D1 the CPU's case** | staged sliver (test_cpu_ambush_squad_does_not_sit_in_a_yield_cycle) | every crew within 8 m of its seat by 10 s (BASE: Hunters_2 never) |
| **D2 deciding** | W1' + W2' cells / fights where the watchdog tripped: noprog_s (team 0, and team 1 in W2') paired diff | mean < 0, sooner-or-identical >= 50 % |
| D3 | W1' + W2' all: noprog_s each team | <= +1.645 se |
| G1-G4 | W1' all_in_s, never_in, contact_s, blocked_s / yielding_s | as Bar M's G1-G4 |
| G5 | untouched cells (0 trips) identical in every line | all |
| G6 | his staged Locks case and the Crossing guard | Bar M's D1 / G6 bounds |
| G7 | route's pathing tests (test_pathing_reroute, test_native_pathing, test_native_route) | green on the frozen tree |
| G8 | check; SCRIPT ERROR | exited 0; none |

Ties count as sooner-or-identical (lesson 344). At most two amendments, before numbers.

### BAR M (FILED 2026-10-30 ~17:50, before any number; frozen tree = the first commit after 482f5e2b3 whose check is named green)

**AMENDMENT 1 (2026-10-30 ~18:00, before any bar number; the lines are unchanged, the rule's trigger is corrected):** a pipeline dry
run on DEV seed 7001 (never a bar) showed the rule acting in every cell of his group click (764 swaps on Locks, 609 of them the
plain > 4 m trigger, median gap 6 m): in a five-squad click a station in a building on a narrow street is routine and today's
grounding slides it along the wall. His corner is PINNED (the grounded point stays put while the station travels on). So the > 4 m
trigger now also needs the grounding to have moved <= 1 m while the station moved >= 3 m since a snapshot >= 1 s old. His staged case
unchanged (Burners2_4 0.0 s, Crossing guard identical). Frozen tree = the commit carrying this amendment, once its check is green.
The dev read itself, said so it is never read as evidence: 4 cells, no-progress 2274 -> 1921 crew-s, all-in 565 -> 435 s, wall
contact 155 -> 196 s (G3 is the line at risk).

**The change:** `--traffic-on=buried` (Movement.buried_station, the one call in TankBrain's transit block, R47.11): a squad's
travelling station that the grounding moves > 4 m, or pulls back along the squad's way > 1 m while 6 m further on is > 1.5 m off the
navmesh, is taken on the squad's own route 8 m on (never behind the crew), sticky while the grounding stays pinned. **Native:** no
twin needed (C47.6 does not apply): the rule changes only the goal the brain hands the drive, in GDScript on every path (native's
feed passes the raw station; the drive is untouched). Both arms run native ON. **Machine:** builder3, one series at a time.
**Arms:** BASE (today) v BURIED; both `--noprogress-census` (game/ai/noprogress_census.gd: crew-seconds a crew with a move order
is > 15 m from its final seat by ROUTE and has not got 1 m closer in the last second; wall-contact seconds; the rule's swaps).
**Instrument's own check (lesson 350), done before filing:** his Locks match, replayed (his match to 0.1 m through tick 330, builder3):
BASE reads Burners2_4 4.0 s, the worst crew on his side (green 30.5 crew-s, contact 3.5 s); the staged lab reads 3.47 s.
**Workload W1 (deciding):** `make manoeuvre-bar-m` = orders' group-order probe (his group click: five full squads, one click across
the map, 180 s window), maps terminus crossing locks sumps, headings `crew`, seeds **12401-12424** (96 cells an arm).
**Workload W2 (both sides, C47.9):** route's `route-census` (CPU v CPU, 150 s) on **12425-12448** once it is on main, both arms,
my census in each log; if it has not landed when W1 ends, W2 is dropped and said (no substitute after numbers).

| Line | Statistic (tests/manoeuvre/barm_judge.py prints it) | Passes when |
|---|---|---|
| **D1 his case** | staged Locks (test_manoeuvre_noprogress), Burners2_4 no-progress s | BURIED <= 1.0 s (BASE 3.47) |
| **D2 deciding** | W1 TOUCHED cells (swaps > 0): noprog_s paired diff | mean < 0 AND buried sooner-or-identical >= 50 % of touched cells |
| D3 | W1 ALL cells: noprog_s paired diff | <= +1.645 se |
| G1 | W1 all_in_s (a never-in squad = the window) | <= +1.645 se |
| G2 | W1 never_in (squads never in) | BURIED total <= BASE total |
| G3 | W1 contact_s (wall / prop contact) | <= +1.645 se |
| G4 | W1 blocked_s and yielding_s, each | <= +1.645 se |
| G5 | W1 UNTOUCHED cells identical in every line | all of them (by construction; a miss = a leak) |
| G6 | staged Crossing guard (test_manoeuvre_noprogress), each Hunter | < 2.5 s |
| G7 | W2 team 0 and team 1 noprog_s, each (CPU both sides) | <= +1.645 se |
| G8 | engage's authority probe (`engage-authority-probe`, 6 seeds 12443-12448, both arms) | rows identical (a held crew has no transit) |
| G9 | the frozen tree's check; SCRIPT ERROR in any series log | exited 0; none |

Ties count as "sooner or identical" (lesson 344). If D1/D2 pass and a guard fails, I write what he would see ON v OFF and message the
orchestrator the same hour (lesson 339). Amendments: at most two, before numbers (lesson 345).

### M1 REPORT (2026-10-30 ~17:00): the trace, cause per crew

Tools: `tests/manoeuvre/stall_trace.gd` + `make manoeuvre-stall-trace` (his recording replayed as he played; one STALL_TRACE row a tick
per crew); `tests/test_manoeuvre_noprogress.gd` (his two cases staged in a lab; `NOPROGRESS_TRACE=on` prints a row a second). Raw rows:
`~/overnight-manoeuvre/r47/` (laptop). Every number: branch c789b55a6 + the trace files only, builder3, native ON.

**Locks replay = his match** (his census v the replay: 0.0-0.1 m for every Burners crew at every second, ticks 30-330). So:
- **Green_Burners2_4 (the crew he saw, ticks 105-300, ~5 s): A STATION BURIED IN A BUILDING.** Its squad's travelling station slid
  from (-21.7, 67.9) at tick 120 to (-27.6, 60.0) at tick 170: into the 2.8 m gap between the city block at (-30, 42) (north face
  ~z 62) and the container_40 at (-30, 66), and into the block. The brain grounds a station to the NEAREST STANDABLE point
  (`TankBrain`'s transit block, `SlotGround.standable_for`), which stayed pinned at the container's east end (-19.9, 66.1), up to
  9.9 m from the raw station. So the crew drove its nose into the block there (wall contact `Block_2`, ticks 150-155) and stood
  `arrived` at a "station" (ticks 165-190) while its four squadmates drove on 20-35 m west. When the element re-dealt its station
  (tick 190, (-40.1, 66.1)) it had to reverse out on full lock (the k-turn planner's 4.5 m leg, thr -0.7, ticks 190-265, 2.5 s),
  then crept at pace 0.3-0.5 behind Green_Hunters_1 (ticks 265-300). Unstick never fired and never should have: speed > 0.8 m/s
  throughout the reverse, and the crew was "arrived" at its goal before that. **Nothing in movement can see it**: from the drive's
  view the crew reached its goal. The waste is upstream of the drive: the goal it was handed.
- **Green_Burners_2 (ticks 200-240, ~1.3 s): no fault.** It reached his first click's spot at 10 m/s facing west; the queued
  click turned it 90 deg south; a fire truck cannot pivot, so Steering's circle rule backed it on full lock ~0.6 s and it turned
  forward. A car turning a corner from a stop.
- The staged lab reproduces Burners2_4 (`test_locks_burner_is_never_parked_at_the_block_while_its_squad_drives_on`: grounded
  station (-19.9, 66.1), `arrived` at tick 180, 3.4 s without progress toward its seat). RED today, as intended.

**Crossing replay is NOT his match**: Green_Wrenches parts by 4.3 m at tick 30 and every crew is 10-35 m off by tick 300; in the
replay Hunters_4 dies at tick 409 (his: 3243). Likely his merged Spears+Wrenches group click (REPLAY_CLICKS_MERGED 16 rows -> 13
orders). Reported to the orchestrator (native's replay). So the Hunters are read from his census + a staged lab:
- **Hunters_3 / Hunters_4 sitting at the order's start (ticks 3060-3150):** the staged lab (four gang IFVs at his tick-3030 spots and
  headings, his click, NO enemies) does NOT reproduce it: all four leave at once (Hunters_4 rolling at tick 30). In his game the
  Rust Battery and Lances (laser, 90 m) were on them; what held them needs the fire. Not yet a movement cause.
- **Hunters_3 dithering at (-77, 47), ticks 3240-3360, after Hunters_1/5 died:** this is the west bridge's mouth between the
  barricade (-78, 42) and the container_40 (-69, 36), under Lances' fire (it died there at 3361). Dead squadmates are NOT
  obstacles: `Tank._set_alive(false)` disables the collider, and avoidance / traffic skip dead hulls. Suspects to rule out by
  removal on a staged fire: the fire detour (`_around_fire`) and the brain's own reactions under fire. Open.
- Also seen: the CPU's Rust_Hunters_1-4 sat `yielding` / `blocked` at (-30, -8) for 6+ s (ticks 2850-3030+): the same class on
  the other side (C47.9).

**What this means for M2:** a watchdog on the drive alone would not have saved his Locks crew (the drive was doing what it was told).
The deciding measure stays the brief's (no progress toward the crew's FINAL seat, ROUTE distance, while its squad is under way), and
the first fix is the buried station: a station whose grounding moves it more than a few metres (inside a building) is replaced by
the squad's own route at that point (the anchor's track, standable by construction), so the crew follows its squad through instead
of parking at a corner. Its decision lives in my code (a static helper); its call site is ONE line in `tank_brain.gd`'s transit
block (no stream owns it this round): grant requested from the orchestrator. The watchdog (no progress for Y s -> unstick/backout ->
`Pathing.reroute`) follows as the general net.

### Plan (2026-10-30 evening, start c789b55a6; launch check = main's e306ce27f GREEN builder3 3518/0, inherited, not re-run)

1. **M1 the trace** — `tests/manoeuvre/stall_trace.gd` (a replay_orders subclass: one STALL_TRACE row a tick per named crew: goal,
   next station, steer, pace, remaining / best, stall clocks, unstick / escape / k-turn state, traffic hold / wait, yield, every
   body touched) + `make manoeuvre-stall-trace`. Run on builder3 for Locks 0-330 (Burners2_*, Burners_2) and Crossing 3000-3400
   (Hunters_1/3/4/5); check each trace against his census before reading it (a diverged replay is not his match). Cause per crew.
2. **M2 the watchdog** — tests first (a staged nose-in at a building corner; a rear IFV whose blockers die), then the rule behind
   `--traffic-off=noprogress`, calling `Pathing.reroute(crew, reason)` through an adapter until route's stub lands (C47.3).
3. **M3 Bar M** filed before any number; native twin first (C47.6) or native forced off for the rule, said in the bar.
4. **M4** his four crews' stall seconds before / after on the shipped tree.
5. **M5** leftovers: yield toward the enemy (12328), holdway head-on, backout pose 10, holdway web freeze.

Decision: the trace is its own script in my test folder (extends native's `tests/replay_orders.gd`, overrides `_trace()`), so
native's replay file is untouched.
