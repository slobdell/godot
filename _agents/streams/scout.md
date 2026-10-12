# Stream: scout (a scout attacks with room to turn, and reverses to keep a moving target)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 27 direction* (his words and the
> orchestrator's readings (1)–(3)), `_agents/workstreams.md` *Round 27* (C27.1, C27.2, C27.4–C27.6), and round 26's
> archived briefs for the history: `streams/archive/round26/brains.md` *B3* (the scout's orbit k-turn loop, traced) and
> `streams/archive/round26/manoeuvre.md` *M1 + M1b* (the planned reverse, and its `refused.reaimed` rule).
> **You own:** `game/ai/combat_motion.gd`; in `game/ai/tank_brain.gd` the fight-motion hunk — `_combat_move`,
> `_hold_motion_plan`, the ORBIT controller and its constants (`ORBIT_*`, the "orbit controller" block ~107–140, ~288);
> in `game/ai/movement.gd` ONLY the `reaimed` rule in `_manoeuvre`'s M1 gate (~1110–1140: which goals may be answered
> with a planned reverse); `game/ai/manoeuvre.gd` (the M1 simulator, read and extend for a moving target);
> `tests/test_ai_combat_motion.gd`, new `tests/test_scout*.gd`, new `tests/ai_scenarios/scenario_scout*.gd` (one
> registration line in `run_scenarios.gd`: merge note), new `mk/scout.mk` (one include line: merge note).
> **The C++ freeze (C27.2):** native's stage 1 is moving the drive and gunnery into C++ this round. `combat_motion.gd`
> and the think-side hunks above are NOT frozen. `_manoeuvre` and `_planned_reverse` are still GDScript callbacks from
> the native drive, so a change there needs no port — but `decide` (the ORBIT option's scoring, ~1366–1404) runs in C++:
> if you change it, send native the diff before the commit (SendMessage, orchestrator copied) and the pair merges back to
> back. Anything in the drive body, `gunnery.gd`, `steering.gd`, `avoidance.gd` is native's: a request, not an edit.

## The lead's direction (2026-10-11, watching `make showmatch`)

> Mostly - the scouts absolutely suck at attacking targets. Similar to how we were talking about inefficient turning
> previously (N point turns versus 3 point turns) the scouts seem to drive super close to their target, leaving no room
> for them to turn and maintain their target, and they don't seem to drive backwards when they have that option to turn
> and maintain their target (i.e. if they're right up against a vehicle, and the vehicle moves east, the car seems to
> only move forward, so it seems to not consider the option of driving in reverse and to the west so that they can
> maintain the target)

What he will notice: a scout fights from a distance it can still turn in, and when the target slides past its nose it
backs up the other way and keeps shooting, instead of driving into the target and looping round.

## Where things stand (verify at main `04845af7`; check green at `090b345d`, builder0, 2464/0)

- **The scout is a fixed gun** — its hull must point at the target to fire. `CombatMotion.fixed_style` is `standoff`
  (`--nav-off=standoff` restores round 3's `run`); the `standoff` band holds 17.5–35 m for a scout
  (`STANDOFF_HOLD_SHARE`). The `run` style's weights carry `"reverse": -1.0` (never reverse) and `"range": 0.0`.
- **A5's ORBIT** (`tank_brain.gd`): a fixed gun that out-turns a slow turret circles it and bursts in while it reloads.
  The orbit controller steers at a point ~13 m ahead, 50–130° off the hull, re-aimed every think. Round 26 (brains B3,
  builder0 `63adfedd`, `pace-p0 ORBIT_PROBE=1`, engine deck): phase 2 deck 4/22 — Movement answered the re-aimed point
  with a planned single k-turn nearly every think; every back-up carried the scout further out (18–22 m), it never got
  inside the 11 m orbit or started its run. Traces: `streams/references/round26/brains/f5_engine_deck_phase{1,2}.txt`.
- **Manoeuvre's M1 (round 26, CP2):** a goal behind is answered by simulating forward v reverse and driving the cheaper
  — but a goal that replaces another within 2 s while the hull kept driving is treated as a re-aimed steering point and
  ALWAYS driven forward (`refused.reaimed`). That is the "it only moves forward" in his words for a target that moves.
- **Which path a fight move takes (read at `04845af7`, `movement.gd` `_manoeuvre` ~1107):** `_manoeuvre` returns at once
  for an order that is `direct` (CombatMotion's short hops) or already carries `reverse` — so in a duel the forward/
  reverse choice is CombatMotion's own (its ring scores reversing candidates; `run` forbids them); M1 only ever sees the
  orbit's routed steering point, and refuses it a reverse. Two places to look, not one.
- **His case in one picture:** scout nose-to-nose with a tank; the tank drives east; the scout's best answer is to
  reverse west-ish so the target stays in its cone, but nothing in the fight path ever plans that.

## Backlog (in order)

**S0 — reproduce his case, scenario first (no fix).** `scenario_scout_cross`: a scout v a tank that crosses its nose at
5 m and 10 m, left-to-right and right-to-left, plus "tank drives away east from contact" (his exact case); the scout's
fixed gun, both on the default path (`make native` built). Measure per run: **gun-on-target seconds** (share of the
fight the target is inside the scout's fire cone), **re-acquire time** after the cross (seconds until back in cone),
**contacts** (hull touches with the target), shots/hits, who dies. Pool over pre-registered start ticks {1,3,6,8,11,16}
and ≥ 3 seeds (C27.5). Also record one `make showmatch` seed where a scout attack goes wrong (the trace and an mp4 clip:
`make showmatch SEED=<n> MOVIE=build/scout_before.mp4`), the "before" he will compare with. Trace one scout (lesson 294:
the root cause can be a bug, not a missing rule) before designing anything.

**S1 — keep turning room (standoff).** The attack/orbit never closes inside the distance at which the scout can still
bring its nose round on a target that moves: its turning circle plus a margin (from its own profile, per hull — never a
scout-only constant). Likely places: the orbit's inner radius and burst-in, `standoff`'s range term, `_combat_move`'s
point. Acceptance: contacts down, gun-on-target up in S0; the engine deck (`scenario_cp2`) and A5's orbit tests still
pass.

**S2 — forward OR reverse, by gun-on-target time.** When the target crosses or moves off, choose between forward and
reverse by which puts the gun back on the target soonest (M1's idea — simulate both with the plant, take the cheaper —
applied to a moving target: predict its pose over the horizon). This is where `refused.reaimed` must change: a fight's
re-aimed point is exactly when reverse can be right. Keep M1's reasons for the rule for non-fight moves (round 26's
steering-point caution). Acceptance: his case — target moves east, scout backs west and keeps it in cone — in S0 at
both distances and both directions.

**S3 — DECLARE and merge (C27.1).** S1+S2 as one declared change (or two, each alone): S0's table base v new (n stated),
the guards below, the thirteen lines' movements explained, the cost line at 25 a side on Sumps (C27.4, ≤ 0.5 ms a tick
GDScript path), the CPU on the same behaviour (symmetric: the lead's rule). **Pre-register the bar before the numbers**
(lesson 292): write in Status and message the orchestrator what the gain must show to ship BEFORE running the comparison.
Then the "after" clip from the same showmatch seed (`MOVIE=build/scout_after.mp4`) for him.

**S4 — stretch.** The scout at the engine deck's phase 2 (round 26's F5): with S2 in, does it reach the deck? Other fixed
guns (any hull with a fixed gun uses the same path: list them and run S0 for each).

## How to verify

- `make remote T=check` (builder0; every Godot run goes there, C27.6); read `>> remote: make check exited <N>` and
  `N passed, M failed`, never an exit code through a pipe.
- The guards: `scenario_cp2` (engine deck), `test_ai_combat_motion`, A5's orbit tests, `make bridge-pooled`, the thirteen
  lines and determinism, `make manoeuvre-behind` (round 26's short move behind must not regress).
- Watch it like a player: the S0 stage rendered, and the before/after showmatch clips. **The lead judges by watching**:
  a clip of the same seed before and after is the deliverable he'll look at.

## Don't touch

Native's frozen execute files (C27.2): the drive body and everything in `movement.gd` outside the M1 `reaimed` rule,
`gunnery.gd`, `order_controller.gd`, `steering.gd`, `avoidance.gd`, `traffic.gd`, `wall_contact.gd`, `clothoid.gd`,
`native/**`. Brains' `game/tactics/**`, elements and the rest of `tank_brain.gd`. Orders' `game/control/**`.

## Waiting on the lead

Nothing. He judges the clips.

## Status

_Not started._
