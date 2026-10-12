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

_Final report, 2026-10-12 (scout worker). Stopped at the orchestrator's request (builder0 freed for native)._

### Report (the short version)
- **Done: S0, S1+S2 (one mechanism), S3 declared.** CP-S = `CombatMotion.plan_lay`, the gun-lay planner for fixed guns,
  ON by default, `--scout-off=gunlay` the A/B. It passed its pre-registered v2 bar on a blind census (below). Merge
  hash: named in *CP-S merge* once `make check` is green.
- **What he will see** (seed 13 clips): a scout whose target slides past its nose backs up the other way with the gun
  held on it, instead of driving on and looping round; scouts bump into enemies less. **Honest limit:** kills, damage
  dealt and deaths by fixed guns are unchanged within noise over 22 showmatch seeds — the gun is on target more, the
  fights are not measurably won more. Next trace item: does the planner need a range term (backing up opens range)?
- **Not mine, filed by the orchestrator for brains:** 45 % of a fixed gun's fight time is SUPPRESS / FLANK /
  CLEAR_LANE / ENGAGE out of reach; most enemy contacts happen under ordered MOVEs (squads ordered into the enemy).
- **S4:** law_scout 4/5 bars, gang_scout 3/5. The gang scout's traced touch (the short halt) got a declared fix that
  did NOT ship by its pre-registered bar (below; branch `scout-s4-halt`). The range question: no range term warranted.
- **Backlog state:** S0 ✔, S1+S2 ✔ (CP-S, merged on main as f4c5f7c9), S3 ✔ (declared, clips made), S4 written up
  (one fix measured and not shipped). Nothing waits on the lead except watching the clips.

### CP-S merge
**`ae0a50a4` is green, merge here** (builder0, `make check exited 0`, **2471 passed, 0 failed**, 24 targets ALL JUDGED;
sim-baseline as declared in 36d67c08 (all thirteen read "unmoved" against it); determinism `2875411ff4ec6be7`, the same
as main's 090b345d). Commits after it on this branch are Status/tooling only (no game file).

### After CP-S: the range trace (the orchestrator's question: does backing up open range, so damage stays flat?)
Census seeds 13–36, ENGAGE only, builder0, tree 16e9fd89 (CP-S + range columns), off → new: seconds in reach 1448 →
1138; **seconds bearing 455 → 526 (+16 %)**; mean range while bearing **21.1 → 26.4 m**; while in reach 21.2 → 23.9 m.
The planner does open the range ~5 m, but it bears MORE seconds and stays well inside the machine gun's 35 m
fire-discipline edge (Engagement holds fire past `effective_range`); acquisition (the other gate) does not reset on
aim. **Reading: no range term is warranted by this evidence.** The flat damage (−142 a seed, se 191) is most likely
fire outside ENGAGE (SUPPRESS is 20 % of fixed-gun fight time and fires at ground/targets the brain-target measure does
not count) plus per-seed noise; not traced further (the damage per option would need a per-shot attribution).

### S4 declared change: the short halt (pre-registered with the orchestrator before any number; tree `0b4c2879`)
Change: `_combat_move`'s short halt (slow-reload guns) no longer stops a fixed gun on the planner unless its gun bears
and it stands outside its turning room (`CombatMotion.halt_allowed`); `--scout-off=halt` = CP-S.
- PRIMARY (tuning data, traced): `scenario_scout_cross SCOUT_UNIT=gang_scout` pooled n = 18: his case 9 contacts in 9
  of 18 runs → 0, and all five bars pass (CP-S: 3 of 5).
- BLIND (orchestrator's addition): census FRESH seeds 37–60, new v `--scout-off=halt`: gang_scout fight-option enemy
  contacts per seed, paired, over seeds fielding gang scouts in both arms (≥ 12, else extend the seeds): down, or not up
  beyond 2 se.
- GUARDS: scout 5/5 and law_scout 4/5 bars kept; census all-fixed-gun on-target-in-reach during ENGAGE not down beyond
  2 se and fight-option contacts not up beyond 2 se; check green; thirteen lines declared if they move; cost MEASURED
  (`make scout-cost`, new v halt-off; the planner now runs where the halt used to cut it short).
- Partial: gang his case contacts ≥ 50 % fewer runs (not 0) with guards holding → ships with a note.

**S4 result: DOES NOT SHIP (by its pre-registered rule).** Tree `0b4c2879`, builder0. Kept on branch `scout-s4-halt`;
reverted on `stream/scout` (game/ equals main's CP-S again; the census's per-unit line is kept).
- PRIMARY (scenario, n = 18, gang_scout, halt-off → new): his case contacts **9 runs → 0**, re-acquire 0.6 → 1.5 s,
  passes; cross 5 m L→R on target 0.52 → 0.46 (still fails, now on that bar), cross 10 m L→R **0.63 → 0.50** (now
  fails at the bar); the two R→L crosses pass. **3 of 5 → 3 of 5: the "all five" primary fails.**
- BLIND census seeds 37–60 (13 seeds field gang scouts): gang_scout fight-option contacts **+0.08 a seed, se 0.66** —
  not up, and not down either: no real-fight effect.
- Guards held: scout 5/5 and law_scout 4/5 byte-identical (the machine gun never short-halts); census on target in
  reach +0.68 pts se 1.67, all-fight +0.50 se 0.71, in-reach share −1.31 se 0.81, contacts −3.1 a seed se 2.3;
  outcomes unchanged (kills 44 → 41, damage −44 a seed se 53, deaths 356 → 357). Cost 0.024 v 0.023 ms a tick.
- Reading: the halt gate fixes the traced touch but costs the spear gun its standing shots on a crossing target (a
  3 s reload gun fires ~4 rounds in 12 s; a halt with the gun near-on is worth more to it than continuous laying).
  Not tuned further on the same data. If wanted later: a gate on the turning room only (no bearing condition) is the
  untested candidate — a new bar on fresh seeds.

### Final check
**`2cc98d8d` is green** (builder0, `make check exited 0`, **2486 passed, 0 failed**, 24 targets ALL JUDGED, the
thirteen lines unmoved against main's adopted lines). game/ == main f4c5f7c9; the commit after it is this Status only.

### What to playtest (exact commands)
- `make showmatch SEED=13` (Parade, Gangs v Law) — watch the Law's police-car scouts; `CONTROL_FLAGS=--scout-off=gunlay`
  for the old behaviour. Clips (1080p, rendered on builder0 at `90413868`/`ae0a50a4` tree):
  `/tmp/claude-1000/-home-slobdell-projects-godot-scout/7cba1883-a101-4c5c-89cd-c1f8c9cf9a81/scratchpad/clips/`
  `scout_before.mp4` (110 s, off) and `scout_after.mp4` (100 s, on); also `before_seed1.mp4` (Locks).
- `make scout-cross` (his case, pooled) · `make scout-census SCOUT_SEEDS=13,14,…` · `make scout-cost`.

### Merge notes (shared-file edits)
- `game/ai/tank_brain.gd`: inside my hunks (`_combat_move`: the request's plan_lay fields, the "outranging it" stop
  skipped for a fixed gun on the planner, the `why` text) **plus one member line** `var _motion_prev_lay := -1` next
  to `_motion_prev_reverse` (~line 553, outside the listed hunk: the planner's commitment memory).
- `decide` NOT touched (no native port needed); `movement.gd` NOT touched (M1's `reaimed` rule unchanged: fight hops
  are `direct`, `_manoeuvre` never sees them); `manoeuvre.gd` NOT touched.
- New: `mk/scout.mk` (auto-included by `include mk/*.mk`, no Makefile line), `tests/scout/` (census, cost probe, paired
  analysis — a new folder, not in anyone's list), `tests/test_scout_lay.gd`, `tests/ai_scenarios/scenario_scout_cross.gd`
  (auto-discovered, no `run_scenarios.gd` line needed). Baselines: `sim_state_hash.txt` 7 lines (36d67c08),
  `ai_scenarios_count.txt` 46 → 51 (ae0a50a4), both declared.
- Guards: `manoeuvre-behind` byte-identical to round 26's M1 table (builder0 light lane, ae0a50a4).

### Plan (ordered)
1. **S0** scenario `scenario_scout_cross` (5 cases, PENDING bars written before any number) + `make scout-cross` (pooled
   {1,3,6,8,11,16} x 3 seeds) + `make scout-census` (the showmatch's own match headless, every fixed gun) → trace → the
   "before" showmatch seed and clip.
2. **S1 + S2 as ONE mechanism** (decided: the two readings are one question for a fixed gun, *which way puts the gun
   back on the target soonest, and keeps it there, without closing inside my turning room*): `CombatMotion.plan_lay`,
   a receding-horizon rollout over the hull's own plant against the target's predicted pose; forward and reverse scored
   alike; the turning room (2 turning radii + both hulls + 1 m, per hull from its profile) a cost, the target's hull a
   wall. Behind `--scout-off=gunlay` (my own switch in combat_motion.gd; no shared switch file touched).
3. Unit tests `tests/test_scout_lay.gd`; guards (cp2 engine deck, combat_motion, bridge-pooled, manoeuvre-behind,
   thirteen lines, determinism); cost line (C27.4); pre-registered bar → orchestrator; S3 declared; after clip.
4. S4 stretch: engine deck phase 2; other fixed guns.

### S0 findings (main `c37605f0`, builder0)
- **A lone scout with no order SPOTs** (backs off to watch), so the scenario orders the attack, as a squad/CPU does.
- **His case traced** (`away_east`, start tick 1, seed 1): CombatMotion's standoff ring scores RANGE, not the gun. From
  3.4 m it took the forward candidate that opens range fastest — tail to the tank, 149–168° off — out to 27 m, then
  "held at standoff" 127° off: a wheeled hull cannot turn at rest (Gunnery's turn on a `stop` order), so the gun bore
  again 9.7 s after the tank moved. Gun on target 4 % of 12 s. Crosses: 0–29 % (0.12 / 0.00 / 0.29 / 0.68 one run each).
  Root cause is the scoring, not a bug: nothing in the fixed-gun path measures where the gun points over time.
- **The census** (`make scout-census`, 12 showmatch seeds, 207 fixed-gun crews, 1537 fight-seconds): **gun on target
  18.4 %** of fight time, 9.1 % inside turning room, reversing 15.5 %, 365 enemy hull contacts — **254 of them under an
  ordered MOVE** (squads ordered into/through the enemy: brains'/orders' path, not the fight path; most in one Parade
  match, seed 5, 286 contacts), 86 on HOLD, ~100 in ENGAGE/FLANK "moving to a firing position"/"swinging wide".
- `PURSUE` (an ordered target out of sight) and ENGAGE's chase ("it is running: after it") drive AT the target's
  position with a 2 m arrive radius — brains' hunks of `act`, outside mine; noted as a request if the census still
  shows contacts there after S1/S2.

### CP-S ship rule (pre-registered 2026-10-11 ~19:30, before the paired comparison; sent to the orchestrator)
Seen before writing it (disclosed): the scenario's pooled NEW arm (n = 18 a case, all five bars pass) and its one-run
base. NOT seen: the pooled base arm, and the census new arm. The rule:
1. **His case and the crosses:** `scenario_scout_cross` pooled n = 18 a case passes all five bars (no contact; gun on
   target ≥ 50 %; median re-acquire ≤ 2.0 s; his case backs west, dx over 3 s < −0.5 m), and the base arm
   (`--scout-off=gunlay`, same commit) fails at least his case — else the change is not what fixes it.
2. **Real fights:** `make scout-census` over the same 12 showmatch seeds, new v `--scout-off=gunlay` on one commit:
   fixed-gun gun-on-target share up ≥ 5 points absolute; enemy contacts under a fight option (not MOVE/HOLD) not up;
   share of fight time inside the turning room not up by more than 1 point.
   **Partial-gain rule:** +2 to +5 points with (1) passing ships with the note (his case is the spec); under +2 points
   or down: does not ship, back to the trace.
3. **Guards:** `make check` green (cp2's engine deck, test_ai_combat_motion, scenario_motion's scout tests, the scenario
   counts moving only by the five promoted scenarios), `make bridge-pooled` in check, `make manoeuvre-behind` unchanged
   (M1 untouched), determinism repeatable; the thirteen lines MOVE (every map fields fixed guns) — declared and
   re-recorded with the reason.
4. **Cost (C27.4):** ≤ 0.5 ms a tick at 25 a side on Sumps, GDScript path.
5. Symmetric: one code path for both sides (CombatMotion has no team).
**Orchestrator's addition (accepted 2026-10-11):** (2)'s gain is judged on the PAIRED per-seed difference (new − off,
same seed): the +2 floor must also be outside 2 se of the 12 paired differences, else noise, no ship. Per-seed table
reported. (2) is the blind test that decides (1)'s pool was seen first.

### CP-S results (commit under test: working tree on `e6862e5e`, builder0)
**(1) scenario_scout_cross, pooled n = 18 a case** (start ticks {1,3,6,8,11,16} x seeds {1,2,3}):

| case | gun on target off → new | median re-acquire s | contacts (runs) | dx 3 s | bars off / new |
|---|---|---|---|---|---|
| cross 5 m L→R | 0.39 → 0.64 | 7.0 → 0.8 | 0 → 0 | +6.8 → +4.8 | FAIL / pass |
| cross 5 m R→L | 0.47 → 0.69 | 3.6 → 0.9 | 0 → 0 | +5.1 → −0.1 | FAIL / pass |
| cross 10 m L→R | 0.34 → 0.58 | 0.7 → 0.7 | 0 → 0 | +9.5 → +4.0 | FAIL / pass |
| cross 10 m R→L | 0.75 → 0.77 | 1.4 → 0.7 | 0 → 0 | +1.3 → +0.1 | pass / pass |
| **his case: away east** | **0.20 → 0.75** | **8.4 → 0.5** | **18 (18) → 0** | −13.1 → −5.3 | FAIL / **pass** |

(The base's −13.1 m "west" in his case is the scout driving forward away tail-first, not backing; the new arm backs
up with the gun within 0–2° — the SCOUT_PROBE trace.) **(1) PASSES.**

**(2) the census, blind, 12 showmatch seeds, new v `--scout-off=gunlay` on one tree (e6862e5e + the planner), builder0:
FAILS.** Gun-on-target paired diff **+1.34 pts, se 3.06** (2 se 6.1); pooled off 18.4 % → new 18.8 % of fight time;
inside the turning room +1.4 pts (se 1.6). Contacts under a fight option 121 → 52, under an ordered MOVE 225 → 47
(most of both in seed 5, the Parade). Per seed (on target off → new): 1 locks 28.7 → 58.4, 2 terminus 19.5 → 24.9,
3 pit 18.3 → 22.4, 4 terminus 18.2 → 13.0, 5 parade 18.7 → 22.6, 6 sumps 3.4 → 5.0, 7 cut 31.4 → 17.8, 8 archipelago
18.6 → 23.1, 9 gorge 14.8 → 13.5, 10 archipelago 19.2 → 18.0, 11 cut 21.8 → 14.8, 12 gorge 31.8 → 26.8.
**By the rule: did not ship; back to the trace** (where real-fight time goes: which option, in reach or
not, whether the planner ran — the census now breaks fight time down by option x motion).

### v1 → v2: the trace (2026-10-11 night)
- **(a) the MOVE-contact drop (225 → 47) is divergence**, not an effect: in every seed checked the arms differ before
  their first contact (seed 5: 14.1 v 14.3 s; seeds 8, 10 earlier). Per-seed contact deltas are noise.
- **(b) the denominator:** of 1537 fight-s (off arm, seeds 1–12) 24 % is ENGAGE with the target out of reach/sight,
  20 % SUPPRESS, 9 % FLANK, 4 % CLEAR_LANE (brains' motion: SUPPRESS lays a wheeled fixed gun with a `face` order,
  FLANK "swinging wide" drives past the target; filed by the orchestrator). In the planner's domain (ENGAGE
  lay/hold/ring, in reach) the gun bore 29.8 % → 38 %; v1's lay segments alone 30 %.
- **Two defects of mine found by `SCOUT_TRACE` (seed 9):** (1) with no control bearing inside the 2.1 s horizon (a
  turn of more than ~135°), every candidate tied on "never bears" and the hold won on commitment — a scout held 134°
  off a moving target for a second; fixed with LAY_AIM (the aim error left at the horizon's end). (2)
  `_combat_move`'s "outranging it" stop fired with the gun 140–155° off; a fixed gun on the planner now skips it (the
  planner's own hold is that stop when the gun bears).
- v2 scenario pool (n = 18 a case): gun on target 0.57 / 0.69 / 0.71 / 0.76 / 0.67 (his case), median re-acquire
  0.6–0.9 s, 0 contacts: all five bars pass.

### CP-S v2 rule (pre-registered with the orchestrator 2026-10-11 night, before its census)
- **PRIMARY:** gun on target WITHIN REACH (range + line of sight) during ENGAGE — the planner's domain — paired per
  seed, new − `--scout-off=gunlay`, **fresh seeds 13–36** (24; seeds 1–12 were traced, reported not judged):
  mean ≥ +5 pts AND outside 2 se ships; +2..+5 outside 2 se ships with a note; else no ship.
- **GUARDS** (paired, not worse beyond 2 se): the original measure (on target / all fight-s); the in-reach ENGAGE
  share of fight time (the primary must not rise by the scout simply spending less time in reach; absolute
  in-reach seconds per arm reported); fight-option enemy contacts per seed.
- And: scenario (1) all five bars at n = 18 (v2: passes); `make check` green; thirteen lines declared; cost ≤ 0.5 ms.
- Seeds 1–12 under v2 (traced, not judged; v1 numbers): primary +7.98 pts se 5.61; all-fight +1.34 se 3.06.

### CP-S v2 result: PASSES (blind census, tree `90413868`, builder0, seeds 13–36, new v `--scout-off=gunlay`)
```
seed  arena        factions             |   rOFF   rNEW   bOFF   bNEW   diff | allOFF allNEW
13    parade       gangs/law            |    91s    93s  18.2%  48.6% +30.4 |   9.3%  23.9%
14    pit          law/syndicate        |     5s    12s   9.3%  79.9% +70.7 |  20.8%  31.9%
15    no ENGAGE in reach (off 0 s, new 0 s): not paired
16    pit          condemned/law        |   185s   118s  37.4%  69.6% +32.2 |  18.9%  24.6%
17    yard         gangs/syndicate      |    25s    21s  31.4%  14.9% -16.5 |   5.3%   2.1%
18    gorge        law/condemned        |     8s    10s  85.3%  89.8%  +4.5 |  34.7%  46.3%
19    yard         syndicate/gangs      |     6s     2s  39.4%  56.9% +17.5 |   3.3%   1.6%
20    cut          syndicate/gangs      |    51s    68s  13.6%  15.1%  +1.5 |  10.0%  10.7%
21    parade       condemned/syndicate  |     6s     7s  33.9%  46.9% +13.0 |  18.9%  12.1%
22    terminus     gangs/condemned      |   129s    91s  37.0%  63.6% +26.6 |  18.0%  26.9%
23    yard         law/gangs            |    17s    70s  16.3%  39.2% +22.9 |   7.8%  23.6%
24    yard         syndicate/law        |     3s     7s  39.8%  73.2% +33.5 |  13.9%  28.7%
25    crossing     condemned/gangs      |    11s    23s  39.9%  76.3% +36.4 |  21.8%  39.1%
26    cut          gangs/law            |   362s   224s  34.6%  44.6% +10.0 |  17.3%  22.4%
27    no ENGAGE in reach (off 0 s, new 0 s): not paired
28    yard_open    syndicate/condemned  |    77s    74s  11.4%  47.6% +36.2 |  21.1%  30.6%
29    terminus     condemned/law        |    38s    16s  15.5%  17.6%  +2.1 |  17.6%  24.1%
30    yard         condemned/law        |     8s     9s  48.5%  63.8% +15.3 |  38.4%  43.1%
31    archipelago  gangs/syndicate      |    25s     8s  69.4%  19.5% -49.9 |  13.5%   1.1%
32    docks        law/condemned        |    64s   106s  17.3%  43.5% +26.2 |  20.2%  26.4%
33    locks        syndicate/gangs      |    17s    11s  25.5%  46.2% +20.7 |  17.6%  26.1%
34    no ENGAGE in reach (off 0 s, new 0 s): not paired
35    pit          gangs/condemned      |   234s   112s  42.9%  44.6%  +1.7 |  24.1%  21.8%
36    archipelago  law/gangs            |    85s    57s  11.8%  15.6%  +3.8 |   6.3%   6.1%
PRIMARY n=21 engage_in_reach_on_target diff mean +16.14 pts, se 5.16 (2 se 10.33)
GUARD   n=21 all_fight_on_target diff mean +5.46 pts, se 1.72 (2 se 3.43)
GUARD   n=21 engage_in_reach_share diff mean -3.42 pts, se 2.01 (2 se 4.03)
GUARD   n=21 fight_option_contacts diff mean -6.57 a seed, se 3.63 (2 se 7.26)
SECONDS off engage_in_reach=1448 fight=4229
SECONDS new engage_in_reach=1138 fight=4023
```
(b = gun on target within reach during ENGAGE; r = those in-reach seconds; all = on target / all fight-s.)
- PRIMARY **+16.1 pts, se 5.16** (outside 2 se, ≥ +5): ships. GUARDS: all fight-s **+5.5 pts, se 1.7** (up);
  in-reach share −3.4 pts, se 2.0 (inside 2 se: passes, closest of the guards; the scout spends ~20 % fewer seconds
  with its target in reach — the turning room and the backing up); fight-option contacts −6.6 a seed, se 3.6 (not up).
- **Cost (C27.4):** `make scout-cost` (Sumps, 2000 credits ≈ 16–25 a side, 3 faction pairs, seed 1, 8–90 s, builder0
  light lane while loaded): plan_lay **0.035 ms a tick mean, 0.062 max**, ~400 µs a plan, 0.01–0.13 plans a tick.
- Unit tests: `tests/test_scout_lay.gd` 7/7 and `test_ai_combat_motion` 15/15 (builder0 light lane, `90413868`).

### S4 (stretch): the other fixed guns (all wheeled; the Syndicate fields none), scenario pool n = 18 a case
| hull | case | on target off → new | re-acquire s off → new | contacts (runs) off → new |
|---|---|---|---|---|
| law_scout (R 5.5) | cross5 L→R / R→L | 0.40→0.66 / 0.50→0.77 | 6.8→1.0 / 2.6→1.1 | 0 / 0 |
| | cross10 L→R / R→L | 0.41→0.67 / 0.70→0.78 | 0.7→0.8 / 1.2→1.0 | 0 / 0 |
| | **his case** | 0.54→0.74 | 3.8→**2.3** (bar 2.0) | 18 (18) → 0 |
| gang_scout (R 4.5, spear gun) | cross5 L→R / R→L | 0.42→0.52 / 0.83→0.65 | 0.7→**2.1** / 0.9→1.0 | 39 (18) → 0 / 0 |
| | cross10 L→R / R→L | 0.43→0.63 / 0.88→0.83 | 0.6→0.4 / 0.7→0.6 | 0 / 0 |
| | **his case** | 0.61→0.64 | 3.2→0.6 | 24 (18) → **9 (9)** |
Law scout: 4 of 5 bars (his case's re-acquire 2.3 s). Gang scout: 3 of 5 (cross5 L→R re-acquire 2.1 s; his case still
touches in half the runs). **Traced** (SCOUT_PROBE, start ticks 1/6/11, seed 1, builder0 light lane, 16e9fd89): the
touch is in the first 0.5 s and the planner never ran: (a) the first think is PURSUE ("ordered, closing in": an ordered
target not yet seen drives at its position, 2 m arrive — brains' `act`), then (b) `_combat_move`'s **short halt**
(slow-reload guns: the spear gun reloads long enough) returns "stop" at 3.1 m before the planner is asked — a halt
that knows neither the aim nor the turning room. (b) is mine: candidate for the next declared change (a fixed gun on
the planner short-halts only when its gun bears and it stands outside its turning room).

### Questions for the lead
None: he judges the seed 13 before/after clips (`build/scout_clips/` in the main checkout, copied by the orchestrator).

### Requests to other streams (relayed by the orchestrator, filed for brains)
- **ENGAGE out of reach is 24 % of a fixed gun's fight time; SUPPRESS 20 %, FLANK 9 %, CLEAR_LANE 4 %** (census,
  seeds 1–12): the lay planner never runs there. SUPPRESS lays a wheeled fixed gun with a `face` order (it cannot
  turn at rest); FLANK's "swinging wide" drives past the target. Brains' `act`.
- **Ordered MOVEs drive squads into the enemy:** 254 of 365 fixed-gun enemy contacts at main c37605f0 were under an
  ordered MOVE (seed 5, `make showmatch SEED=5`, Parade, Law v Condemned, t ≈ 14–30 s: Rust_Eyes5/Eyes6 scouts into
  Green_Sirens/Hunters around (0, 0); per-event lines: `make scout-census SCOUT_SEEDS=5`, `SCOUT_EVENT` lines).
- **PURSUE's first think** (an ordered target not yet seen) drives at its position with a 2 m arrive: the gang scout's
  contact in his case starts there.

### The bridge 106/108 bisect (orchestrator's request, 2026-10-12)
Brains found his bridge 108 at 106/108 on main f4c5f7c9 (seed 2: green tick 5, rust tick 9). At `2cc98d8d` (game/ ==
f4c5f7c9), builder0 light lane: both cells reproduce — green tick 5 rim crew **Green_S_3 (law_tank) 3.5 s**, rust tick
9 rim crew **Rust_S_1 (law_tank) 5.1 s**, all four crossed in both — and the records are **byte-identical with
`--scout-off=gunlay`**: CP-S is cleared (the drill fields no fixed gun; every CP-S path is gated on `standoff`). The
(a) arm at 090b345d was not run (a second old checkout through remote.sh; builder0 was to be freed) — the invocation is
in the message to the orchestrator.

### Next steps / candidates for later (for whoever picks this up)
- The untested S4 candidate: gate the short halt on the turning room only (no bearing condition), on fresh seeds.
- Fixed guns under SUPPRESS (20 % of their fight time, outside the planner: a wheeled hull laid by a `face` order).
- The other fixed guns' bars still failing at CP-S: law_scout his case re-acquire 2.3 s (bar 2.0); gang_scout cross
  5 m L→R (on target / re-acquire) and his case's touch (from PURSUE + the short halt).
- Kept branch: `scout-s4-halt` (0b4c2879, the measured-and-not-shipped halt gate).
- The damage question: per-shot attribution by option (why +16 % bearing seconds give flat damage).
- Native: `plan_lay` is GDScript (0.02–0.06 ms a tick measured); nothing to port unless stage 1 moves `_combat_move`.

