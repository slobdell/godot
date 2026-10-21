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

**Now (2026-10-21):** R1 built + lab-green; R2 (spread + short halt) and R3 (pin slow) built, lab tests written; R2's
first MEASURE running (builder0, light). Bars wait for CP37.1 (native's guard lines).

**Plan (in order; reasons in one line each):**
1. R1 own-motion sight: DONE at 9d63f709a (lab 6/6, builder0 light, `test FILTER=test_rules_sight`).
2. R2 measure (`make rules-moving`: CPU-v-CPU showmatch fights, share of direct-fire damage by shooter motion x range).
3. R2 spread switch + short halt; R3 pin slow; lab tests both paths.
4. quick-remote, then one full check on a named hash (pre-series gate).
5. After CP37.1 merges: bars in workstreams *Bars (round 37)*, series on builder2.

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

**Known issues:** none yet.

