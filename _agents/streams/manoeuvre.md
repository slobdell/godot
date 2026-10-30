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
