# Stream: engage (his side fires when it is close enough to hit)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 344, 345, 352), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 47** (C47.1-C47.11), your last brief `streams/archive/round46/engage.md` (FINAL REPORT: L1c, the lane rule, the feed line),
> `game_design.md` *His playtest after round 46's ships*. **You own:** `game/ai/gunnery.gd`, `game/ai/fire_lanes.gd`, `game/ai/tank_brain.gd`'s
> CLEAR_LANE option, target choice and their constants, `game/ai/native/native_decide.gd`'s constant table (additive),
> `game/ai/perception.gd`'s target-fix / sight timing ONLY (mapkit edits the eye ray for the `sight` class, C47.7), `game/tactics/drills.gd`,
> `game/tactics/element.gd`'s player-authority code, `game/tactics/element_plan.gd`'s engagement functions, `game/tactics/firing_position.gd`,
> `game/ai/order_controller.gd` (trace lines), GRANT `game/control/order_executor.gd`'s crew branches, GRANT `game/ui/hud_messages.gd`
> (additive), `tests/tactics/test_engage*.gd`, `tests/engage/**`, `tests/test_authority*.gd`, `tests/test_gunnery*.gd`,
> `tests/test_fire_lanes*.gd`, `mk/engage.mk`, `game/garage/**`, `mk/garage.mk`. **Model:** Opus. **Machine:** builder3.
> **Seeds:** 12601-12648 (Bar E), 12649-12696 (reserve). Dev 7001-7012 (never a bar).

## The lead's direction (2026-10-30 ~15:42, Crossing, gangs v syndicate, verbatim)

"I played as the gang, and when I had my tanks engage some target, it looks like they took forever to actually pick their target and
get a shot off - this makes me wonder first if something is broken with our targetting to begin with, but second if vehicles should
just go ahead and take pot shots even if they can't get a good targetting fix."

Memory: smart AI on both sides; units must look smart and under his control.

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0, 28 ALL JUDGED)

- **His Crossing match** (`references/round46/playtest/2026-10-30T15-41-59-crossing.jsonl`, seed 101, lost 0-20 in 112 s): green fired **6 shots v 358**; hits 3
  v 277; damage 196 v 4901; `gun_ready_samples` 37 all idle. Engagements at a median 79 m (syndicate laser 90 m, railgun 110 m; gang
  twin_mg ~35 m, scrap_cannon 50 m, gang_tank sight 60 m): much of it is outranging.
- **But not all:** after his attack order on Rust_Hunters_2 (tick 2092) **Green_Guns_3 sat 16-26 m from its target ticks 2160-2457
  (~10 s)**, inside scrap_cannon range 50, phase `driving`/`arrived`, and the side's shot total stayed at 6. That looks broken.
- **First suspect by removal:** round 46's lane rule (`rules.lane_clear: true` in this recording): replay with `--lane-clear=off`.
- Also: army_cost green 2490 v rust 5000 in that match. Find whether it is intended (faction budgets, the skirmish recipe); you own
  none of that code: report, the orchestrator rules.

## Backlog (in order)

1. **E1 the trace (Status first, then message the orchestrator):** Guns_3 ticks 2092-2460, ON v `--lane-clear=off`: target, fix /
   sight state, gun ready, lane blocked by whom, why each tick did not fire. Name the cause. Same for every green crew with an enemy
   inside its own weapon range for > 2 s that did not fire (the match-wide count is the class).
2. **E2 the fix, ON, smallest change (C47.2):** whatever E1 names. A crew with a target inside its range and a clear line fires within
   ~1 s. Symmetric (C47.9). Tests first: Guns_3's geometry staged.
3. **E3 pot shots (his second question) as a design read, not a default:** what a crew does when it has a target in range but a poor
   fix (moving, partly hidden): today's rule, and a proposal ("fire at reduced accuracy after N s held") with what he'd see. Build it
   behind a switch only if E1 shows held-fix time is a real share of the silence; the default flip is his call (orchestrator asks).
4. **E4 Bar E**, filed BEFORE any number on 12601-12648: deciding = seconds a crew with an enemy inside its own range and a clear line
   holds fire; guards = friendly hits (L1c's), the lane rule's lines, engage's authority probe, the fight probe. Native twin first
   (C47.6). Ships ON; name the green hash.
5. **E5 his acceptance read:** Crossing replay: green's shots and Guns_3's 2160-2457 window on the shipped tree.
6. **E6 the army_cost read** (report only).
7. **Leftover:** the touch map's feed line (round 46).

## Don't touch

movement / traffic (manoeuvre), `game/ai/pathing.gd` / planner (route), `game/control/**` but your grant, `native/**`, `game/camera/**`,
`game/ui/**` but `hud_messages.gd`, `arenas/**`, `game/match/**`, `game/units/**` (unit ranges are not a fix here: balance waits),
`tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
