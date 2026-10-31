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

### M1 REPORT (2026-10-30 ~18:10): the trace, cause per crew

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
