# Stream: rules (stop to be strong: sight, accuracy and suppression follow motion)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 37** (C37.1, CP37.1,
> C37.2) and `_agents/game_design.md` *OPEN QUESTIONS for him before round 37* (his answers to 1, 2, 8, 11) and *Summary of his
> answers*. **You own:** `game/tank/tank.gd` (sight, suppression's effects, the drive speed cap), `game/match/match.gd`'s
> intel/spotting pass and `shot_spread` (+ `MOVING_SPREAD_FACTOR`), `game/ai/fire_lanes.gd`'s spread line, `game/combat/**` except
> cover's damage seam (C37.3), `tests/rules/**`, `tests/test_rules*.gd`, `mk/rules.mk`. **Grant:** in `game/ai/gunnery.gd` /
> `game/ai/order_controller.gd` the "stop before a long shot" choice, one guarded seam, merge note. C++ twins are native's (you
> declare, native writes; 0 mismatches before a series).
> **Model:** Opus. **Machine:** builder2 for series (shared queue with native and cover: say in Status when you start/finish);
> light runs on either builder.

## The lead's direction (2026-10-20 / 21, verbatim in game_design.md)

"the problem is not the units, but the rules of the game." On sight, his own reframe: **"isn't a much more coherent version of this
idea simply that a unit's vision shrinks a little when moving / expands a little when stopped?"** (he rejected hiding a parked enemy
inside a range the player was shown: "the cognitive disconnect"). On accuracy: **"yes, firing on the move should be a lot less
accurate"**. On suppression: slow, never stop, and show it ("ok yeah, let's go with your recommendation"). The guard (11): a blob
frontal assault should lose AND a pure turtle must not always win.

What he will notice: a squad that halts at a crossroads sees a column coming before the column sees it, and shoots first and
straighter; a blob charging and firing on the move mostly hits dirt beyond mid-range; a charge into heavy machine-gun fire bogs down.

## Where things stand

- **Sight:** `Tank.sight_radius` from `Units.stat(unit, "sight_radius")` (60–110 m); team vision = inside radius AND line of sight
  (`Match` intel pass ~1215–1290, `Perception.has_line_of_sight`); fog hides unseen enemies in 3D (`rts_controls._apply_fog_of_war`).
  X5 already scales sight with suppression (`SUPPRESSION_SIGHT_PENALTY` 0.4, the `_calm_sight` block ~1119–1134): R1 extends that
  block, not a new mechanism.
- **Spread:** `Match.shot_spread` = spread_deg x (1 + `MOVING_SPREAD_FACTOR` x moving + suppression term) x range term;
  `MOVING_SPREAD_FACTOR := 1.5` (2.5x at full speed). `fire_lanes.gd:94` repeats the formula. Native: `gun_native` / `combat_native`.
- **Suppression:** rise 0.6/s, recover 0.3/s; shrinks sight, slows hull turn 50 %, widens spread; **never slows driving**.
  Native: `tank_drive_native`.

## Backlog (in order)

1. **R1 own-motion sight.** Switch `--rules-sight` (OFF). Driving: ~85 % of the calm radius; stopped for ~2 s (a dwell; brief halts
   don't count): ~110 %; blend smoothly, never flicker; composes with the suppression penalty. Lab test first (two tanks, one parked,
   one approaching: the parked one spots first by the stated metres, both paths). Declare the twin to native.
2. **R2 moving spread.** Switch `--rules-spread` (OFF): `MOVING_SPREAD_FACTOR` -> ~3.0 (4x at full speed), still scaled by speed; the
   fire_lanes copy follows. First MEASURE (light, today's main): what share of a blob charge's damage comes from movers; if it is
   small, say so before building (question 3 then matters more). The AI part: crews stop before a long shot when the shot is worth
   it (the grant); a lab case shows a CPU tank halting to fire at 120 m. A fast unit that becomes useless gets its own lower
   penalty (a stabilised gun), never a softer rule for all; report it, don't decide it alone.
3. **R3 suppression slows.** Switch `--rules-pin-slow` (OFF): the drive speed cap scales down to ~60 % at full suppression, never 0;
   an ordered move still completes. Feedback shows it (C37.6); you expose `Tank.pin_slow()` (0..1) for them.
4. **Bars and series (after CP37.1 merges):** one bar per rule in workstreams *Bars (round 37)*, shape C37.2, sized from native's
   noise. Rules may be judged one at a time or as a package if you argue it in the bar; each keeps its switch either way.
5. **Stretch:** the "stabilised gun" exception if R2's series names a victim; R1's numbers re-tuned only on the guard lines.

## How to verify

Lab tests both paths; `make quick-remote`; one full check per named hash; series on builder2 against CP37.1's lines; every number
with commit, machine, workload, n. Smoke like a player: `make skirmish ARENA=terminus`, halt a squad at a crossroads, send the CPU
in; then charge a parked CPU squad across open ground.

## Don't touch

Cover's damage seam and paths, feedback's presentation, orders'/manoeuvre's movement code, `native/**`, `tests/baselines/**`.
Don't push.

## Waiting on the lead

Nothing (his answers are recorded). His playtest at the round's close is the subjective check.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**Now (2026-10-21 ~10:15 PDT):** R1, R2 (spread + short halt, with ruling R37.2 (b)) and R3 are BUILT, all OFF, lab-green:
`test_rules_` 19/19 on builder0 at 51e5c6ff4. quick-remote passed at 12f410388 (builder0: 83 passed, 0 failed; lint 586
scripts). **GREEN: 2c85080fc** (full `make check` on builder0, synced at the tip after 51e5c6ff4, so it covers the code plus mk/docs: tests 2992 passed, 0 failed; scenarios 52 passed, 0 failed, 4 pending; `make check exited 0`). Later commits are Status-only. In that check sim-baseline stayed unmoved (13/13), but perf-judge was NOT JUDGED (refused 3 times on a busy box, ratios 1.49/1.93/1.55x); the orchestrator folds it into one perf-judge on main after CP37.1 and my merge, covering cover's and my OFF code together. scenario_scout_suppress::test_target_behind came back UNEXPECTED PASS; the orchestrator says this is known (it has passed since 2026-10-20) and native's N5 promotes it with CP37.1, so nothing to do here. Smoke: `make rules-shots`
(laptop, terminus, seed 3, --scripted, OFF v ON at 45/75 s, 1854x1011 and 1200x540): 8 frames, 0 engine errors, both arms
play normally; one fight each, so the shape, not a count. **Next: wait for CP37.1 (native's guard lines + noise), fill
bar R's k·se and n, cut the pair tree, native runs the lab tests under `make native test` with each switch ON (R37.4),
then the series on builder2.**

**Measured:** R2's question (does moving fire matter?): movers (>= 15 % of top speed) deal **52.5 %** of direct-fire
damage and 19.4 % from beyond 50 m (`make rules-moving`, 9d63f709a, builder0, CPU-v-CPU showmatch fights, terminus/locks/
sumps/gorge/parade x seeds 1-4, 180 s, n = 20 fights; direct damage 202 009, arc 95 182). So R2 is worth building.

**Plan (in order; reasons in one line each):**
1. R1 own-motion sight: DONE at 9d63f709a (lab 6/6, builder0 light, `test FILTER=test_rules_sight`).
2. R2 measure (`make rules-moving`: CPU-v-CPU showmatch fights, share of direct-fire damage by shooter motion x range): DONE, 52.5 %.
3. R2 spread switch + short halt; R3 pin slow; lab tests both paths: DONE (12f410388; ruling (b) at 51e5c6ff4).
4. quick-remote (PASSED 12f410388), then one full check on a named hash: GREEN 2c85080fc (builder0, 2992/0).
5. After CP37.1 merges: bar R filled from its noise, series on builder2.

**Machine lane (C37.1, the orchestrator's reminder):** every further full check and series of mine on **builder2** (`make
gcp-remote T=...`; `make gcp-start` first if stopped, under systemd-run with ~/projects/bin on PATH). builder0 only for light
runs. The check that went green on 2c85080fc ran on builder0 because builder2 was unreachable when it started. It was allowed to finish.

**Switches:** `game/combat/rule_switches.gd` (`RuleSwitches`): `--rules-on=sight,spread,pin_slow`, `--rules-off=...`, or the
brief's `--rules-sight` / `--rules-spread` / `--rules-pin-slow`. All OFF; sim-baseline is untouched with them OFF.

**Decisions:**
- R1 is applied by `Match._settle_motion_sight()` right after the suppression settle on BOTH its GDScript and native paths,
  writing `_shown_sight` so the next settle keeps the calm radius. **No C++ twin is needed** (a few multiplies per crew at
  15 Hz in GDScript); native's `threat_native` settle is untouched. Halted = slower than 1 m/s over the ground
  (`real_velocity`), dwell 2 s, blend 0.25/s (0.85 -> 1.10 in 1 s), a fresh crew starts at 1.0.
- R2's moving factor: `Match.moving_spread_factor()` (1.5 OFF, 3.0 ON); `fire_lanes.gd` reads it. `shot_spread` has no C++
  twin (checked: `native/src` never reads MOVING_SPREAD_FACTOR), so none to declare.
- R2's AI half is a SHORT HALT in the plant (`Tank._short_halt`), NOT in gunnery/order_controller: both of those have
  whole-tick C++ ports (`NativeController`, `NativeExec`, `NativeGun`) a GDScript hook would be bypassed by, and the plant
  already has the precedent (a battery digs in when told to fire). A crew whose trigger is held, gun loaded, rolling >= 15 %
  of top speed, shot >= 60 % of effective range, and whose halted hit chance beats its moving one by >= 0.15 (Matchups'
  model + `shot_spread`) holds the round, brakes, fires once nearly still, drives on; at most 1.5 s, cooldown 4 s; never
  while reversing. Same rule for both sides and for his crews. The grant in gunnery/order_controller is NOT used.
- R3: the tick's throttle is capped at `1 - 0.4 x pin_slow()` before the drive (GDScript and native plants alike);
  `Tank.pin_slow()` = suppression when ON, else 0 (C37.6, feedback's read).
- The brief's "a CPU tank halting to fire at 120 m": no direct-fire gun reaches 120 m (longest: railgun 110 m), so the lab
  case uses the Syndicate tank's railgun at > 80 m.

**Bar R (rules R1/R2/R3), RE-FILED 2026-10-21 with PAIRED thresholds, before any arm number. The base comes from the
orchestrator's CP37.1 base read (R37.14, recorded on main).** Base read: builder2, game tree main 9d325e291, the right-click
blob, 5 maps x seeds 2601-2608 + 2701-2708 x both sides = 160 fights per line, 0 % capped. Blob v tactics: blob wins 48 %
(± 11, 2 se unpaired), kill ratio 0.88 (± 0.07), median 112 s. Turtle v tactics: turtle wins 39 % (± 15), kill ratio 0.80
(± 0.17), median 194 s.
- **Workload (n):** the SAME 320 fights per arm (both lines, the same maps, seeds and sides), on builder2.
- **Base:** main after CP37.1 and the rules merge, every switch OFF. With all switches OFF it must replay
  `references/scoreboard/guards/9d325e291.fights.jsonl` fight for fight (native shows the replay). If it does not, the base is
  re-run on the new tree and the pairing uses that.
- **Arms:** one arm per rule on that tree, `--rules-on=sight`, `spread` and `pin_slow`. Package arm `--rules-on=sight,spread,pin_slow`
  only if two or more rules pass alone, or each sits inside its noise alone (argued in the verdict).
- **Judged PAIRED** with `python3 tools/scoreboard/guard.py --pair <base fights.jsonl> <arm raw>`: flips per fight, exact
  McNemar p, and paired differences with per-seed se. All se below are that paired per-seed se; none is the unpaired ± above.
- **Deciding (each arm):** blob v tactics. The blob's win rate must be DOWN v base by more than 2 x paired se, AND the exact
  McNemar p (blob win -> loss flips v loss -> win flips) must be < 0.05.
- **Second line:** the blob's kill ratio must not be UP by more than 2 x paired se. A falling win rate with a rising kill
  ratio is reported as a contradiction, not a pass.
- **Faction:** faction dominates any single seed (base: Syndicate wins 73 % as blob, 67 % as turtle; Gangs 30/17 %; Law 22/22 %).
  Every arm also reports the paired blob win-rate difference per faction. These per-faction differences are not judged
  (n per faction is 1/3), but a faction whose sign is opposite to the overall result is named in the verdict.
- **Guard 1:** turtle v tactics. The turtle's win rate must not be UP v base by more than 2 x paired se, and its McNemar p
  must not fall below 0.05 in the turtle's favour (the turtle must not start winning).
- **Guard 2:** kills per match and match length (median, both lines), per faction, within base ± 2 x paired se (no faction breaks: the stabilised-gun check
  in the brief; a faction outside is REPORTED with its units, not fixed here).
- **Guard 3 (R2 only, ruling R37.2 (c)):** contention: friendly contacts, all-in time, crews held behind a halted friend,
  and manoeuvre's wedge line, each no worse than base + 2 se on the scoreboard's moves/orders workload.
- **Guard 4:** perf-judge with the arm ON, on builder2 (the short halt and the motion-sight pass are per-crew GDScript). The OFF code is judged once on main by the orchestrator, after CP37.1 and my merge.
- **Equality:** sim-baseline maps unmoved with every switch OFF (attributed with the switch OFF, C37.2).
- **Reports (not judged):** the R2 measure's movers' share of direct damage (`make rules-moving`, base 52.5 % at 9d63f709a,
  builder0, n = 20 fights) per arm; first-spot distance by side in the blob line (R1).
- **Last attempt / partial rule:** one re-tune per rule only on the guard lines (brief's stretch), then judged as it stands.

**Series log (builder2, queue mine until done; M5a goes after):**
- PAIR TREE **75c3e74e0** (pair/rules-r37) = main 291318ece (0baf6e1ff + docs) merged into stream/rules; it differs from main only in this
  Status. Declared to native for the lab arms (each switch ON, `make native test`, both arms).
- 13:23 PDT start: OFF base-gate replay, `GUARD_TAG=base` (systemd unit rules-guard-base). Gate: 0 flips v 9d325e291.fights.jsonl.

**Arm recipe (from native, 2026-10-21; tooling in stream/native 420048f99 and pair/native-cp371 2bb41ef93):**
`GUARD_ARGS=--rules-on=<rule> GUARD_TAG=<rule> tools/scoreboard/guard.sh <pair commit>`. This runs on builder2, chunked
and resumable after preemptions; it uses one scratch folder (../godot-native-guard), so either one arm at a time or a separate
GUARD_WORKTREE. Then `python3 tools/scoreboard/guard.py --pair references/scoreboard/guards/9d325e291.fights.jsonl
../godot-native-guard-raw/<commit>-<rule>`. The builder2 queue is shared, so each arm's start is written here.
Base replay: native re-ran 20 of the 9d325e291 fights on today's main, byte-identical (builder2). Blocks 2601+ / 2701+:
blob 49 / 46 %, turtle 41 / 38 %. **Merged (2026-10-21):** CP37.1 is on main as d9545d381; rules 2c85080fc and native's guard tooling are on main as a10846307.
`git merge main` -> 922713a0a; on the merged tree `test_rules_` passes 20/20 (builder0 light, ccc903cfc, `make test exited 0`). **Waiting on:** the orchestrator's builder2 `make native check` of the batch. Then the pair
tree is cut from a10846307, native runs the lab arms, and the gate is checked: OFF must replay 9d325e291.fights.jsonl with 0 flips,
else the base is re-run on the new tree. My arms set `GUARD_WORKTREE=../godot-rules-guard` so they never share native's
scratch folder. Raw output goes to ../godot-native-guard-raw/<commit>-<rule>.

**Rulings received:** R37.2 (a) no twins provisional, (b) **no short halt under his plain MOVE** (attack-move, hold, parked,
CPU only; built: `ShortHalt.plain_player_move`, game/combat/short_halt.gd, lab cases in test_rules_spread), (c) R2's bar
carries contention guards (friendly contacts, all-in time, held behind a halted friend, manoeuvre's wedge line).
R37.3: the guard lines' blob is his right-click (plain move, drills:false), so the halt never fires on the blob.
R37.4: native confirmed in writing no C++ twin for R1-R3; condition: when the pair tree is cut, native runs these lab tests
under `make native test`, each switch ON, both arms, before the series. Declare the pair to native.

**Questions for the lead:** none yet.

**Requests to other streams:**
- native: no C++ twin is needed for R1 (see Decisions); R2's short halt and R3's cap act on the command in `tank.gd` before
  `NativeTank.drive`, so both drive paths see them. Please confirm nothing native reads `cmd.throttle` for the tick before
  `Tank._physics_process` runs (I found none).
- manoeuvre: R3 lowers top speed under fire to 60 %; R2's short halt stops a hull for <= 1.5 s with throttle 0 in the
  plant (`Tank.short_halting()`); a stall clock that reads commanded throttle v motion may want to know.

**Known issues:**
- builder0's desktop rendered no frame for `rules-shots` (four runs timed out at 300 s with game time stuck at ~15 s; the
  first try also lacked --scripted). The laptop rendered all 8. Not chased further: report it if another stream sees it.
- The short halt is in the plant, so the keyboard-driven tank of `make run` (legacy mode) would also halt for a long
  shot with the switch ON. Skirmish is unaffected beyond the rule itself.

**What to playtest (once a rule is ON, or with the flags):** `make rules-skirmish ARENA=terminus` (all three
rules ON; `RULES=sight` for one; `make skirmish` for the OFF feel). Halt a squad at a crossroads (hold), send the CPU in: the halted squad
should see the column first and shoot first. Then attack-move across open ground at a parked CPU squad: your crews make
short halts for long shots, while a plain right-click move never stops to shoot. Under machine-gun fire a charge visibly slows.

**Merge notes (shared files):** `game/match/match.gd` (one call after `_update_suppression` in `_physics_process`, a new
`_settle_motion_sight`, `RULES_MOVING_SPREAD_FACTOR` + `moving_spread_factor()`); `game/tank/tank.gd` (R1/R2/R3 blocks, two
lines in `_physics_process` before `_drive`, resets in `_set_alive`); `game/ai/fire_lanes.gd:94` reads
`Match.moving_spread_factor()`. New: `game/combat/rule_switches.gd`, `game/combat/short_halt.gd`, `mk/rules.mk`,
`tests/rules/**`. Nothing in gunnery.gd / order_controller.gd (the grant is unused).

