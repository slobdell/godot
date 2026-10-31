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
2b. **E7 his direct order beats RETREAT (R47.6, orchestrator 2026-10-30 ~17:40; ahead of E3).** Route's R1 trace (Locks, builder3,
   staged from his census at tick 1170): Hunters_4's drive north and 230 m detour were TankBrain RETREAT (hull 15/220 under
   CRITICAL_HP, threats visible: RETREAT 0.99 beats his attack; `withdraw_point` keeps handing it a move_to ~20 m from the threats,
   north, away from his target), not the route (<= 1.036x shortest). Ruling: his direct order to a crew beats RETREAT, ON, `=off`
   escape; a hurt crew pressing on may say so through one additive feed line kind (C47.5); the CPU only for orders its commander
   gives as direct (C47.9). Bar on 12601-12648 or the reserve, filed before numbers.
3. **E3 pot shots (his second question) as a design read, not a default:** what a crew does when it has a target in range but a poor
   fix (moving, partly hidden): today's rule, and a proposal ("fire at reduced accuracy after N s held") with what he'd see. Build it
   behind a switch only if E1 shows held-fix time is a real share of the silence; the default flip is his call (orchestrator asks).
4. **E4 Bar E**, filed BEFORE any number on 12601-12648: deciding = seconds a crew with an enemy inside its own range and a clear line
   holds fire; guards = friendly hits (L1c's), the lane rule's lines, engage's authority probe, the fight probe. Native twin first
   (C47.6). Ships ON; name the green hash.
5. **E5 his acceptance read:** Crossing replay: green's shots and Guns_3's 2160-2457 window on the shipped tree.
6. **E6 the army_cost read** (report only).
7. **Leftover:** the touch map's feed line (round 46).
8. **E8 his post, tighter (R47.30, from manoeuvre; after E7 / E3):** HOLD's way back to HIS post uses arrive 6.0 m, so a crew
   displaced from where he put it (manoeuvre's holdyield fixes the yield's push, 12328: 10.1 -> 0.0 m) still parks up to 6 m short.
   A tighter return for his own post (player-authority code, engage's), measured on E2's authority probe.

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

**Plan (2026-10-30 evening, the brief's order):** E1 trace first (a measurement-only `--gun-trace` in gunnery.gd: every gate per
run of the gun, plus `make engage-e1`, his Crossing replay in both lane arms on builder3) -> E2 the fix ON from what E1 names, a
staged Guns_3 test first -> E3 the pot-shot design read (switch only if held-fix time is a real share) -> E4 Bar E filed before
any number -> E5 his replay on the shipped tree -> E6 army_cost read -> the touch map's feed line.

| Item | State |
|---|---|
| E1 the trace | **DONE (STAGED)**: cause named (E1 REPORT below); the full replay is not his match (native's N0) |
| E2a the lay carry-over | code + tests GREEN at **a61b0f302** (builder3 `native test` combat_envelope / native_gun / native_exec_state, 42 passed; the 1 failure was E2b's stage test). `--lay-carry`, **OFF** until native's twin (spec + hash sent; native's N0 first). Dev read running |
| E2b a line under his attack | code in; `--attack-line`, **OFF** until Bar E. Its hand-built one-crew stage does NOT reach the rule (the element's contact drill hands the lone rig a slot with a line: both arms fire at 6.6 s); a dev read on the six staged windows decides whether the rule fires at all before a new test |
| E2 dev reads | **no measurable effect from either switch** (below) -> **E2a + E2b DROPPED (R47.17), code removed** (game files byte-identical to e306ce27f; native's twin reverted) |
| E7 his order beats RETREAT | code + tests GREEN at **14ccc9b91** (builder3 `native test` press_on / native_decide / combat_envelope / native_gun / native_exec_state: 45 passed, 0 failed). `--press-on`, **OFF** until native's `_obey` twin (spec + hash sent). Dev read on route's Locks case (staged 1440) running |
| E7 Bar E7 | **FAILED on G1** (friendly hits 1 -> 6, 1-4 hp each, no kills); D1 / D2 / G2-G6 PASS (verdict below); the orchestrator rules. Was: **FILED** + **Amendment 1** (his side only; G6 the CPU side untouched), both before any number on 12601-12648. native's re-twin EQUAL (pair/native-e7 aa339ab80, merged). **FROZEN at d4a88c4a5** (+ the touch-map feed line); full check then the series (D, G4 authority, G6 no player team) running on builder3 |
| Leftover: touch map feed line | **DONE**: `HudMessages.selected_units` reads the touch map's `selected()` squad; test green (builder3 `native test` lane_line / hud_messages: 13 passed, 0 failed) |
| E6 army_cost read | **DONE (report only)**: the laptop preset's 20-vehicle cap halves a swarm faction's skirmish army (below); he answered (cap by vehicle cost, skirmish = 1000 credits): orders builds it (R47.22) |
| E3 pot shots | **HIS YES (R47.20).** Bar E3 **FILED** before any number on 12649-12696; native twin spec sent; then freeze, check, series. Code behind `--pot-shot` (default OFF until the bar); test green at 087d1732a (first round 12 v 28 ticks); dev reads below; **his question sent to the orchestrator** (recommended: yes) |
| (E3, old row) | in progress: switch (default OFF) + the dev read that gives the orchestrator his question in player terms (R47.17) |

**His "is something broken with our targeting?" — the honest answer (staged, E1 + the gates split):** no. A gang crew is SLOW to its
first aim at range by design: the fix time grows with the target's distance over the crew's OWN sight (`Engagement.acquire_seconds`:
0.3 s at the muzzle to 1.6 s at the edge of sight, x the crossing penalty), and the War Rig sees only 60 m, so a target at 40 m costs
it ~1.2 s where a syndicate crew (sight 90-135 m, designators x0.25) pays a fraction. Median fix needed his 1.69 s v CPU 1.10 s; 87 of
his 145 acquiring seconds were first fixes. Nothing in the gate is broken; the gap is sight and range (balance, which waits).

**Bar E7's frozen tree and E3 (for the verdict, the orchestrator's check):** on d4a88c4a5 `--pot-shot` is default OFF and inert:
`Gunnery.POT_SHOT` is true only with `--pot-shot=on`, is read by ONE branch (`gunnery.gd:212`, its first conjunct, so nothing in the
branch runs while it is off), no native code and no make target reads or sets it, and E7's arms pass only `--hurt`, `--press-on`,
`--his-side` (`git grep POT_SHOT d4a88c4a5 -- game native mk`).

### Bar E3 (FILED 2026-10-30 ~20:00, before any number on 12649-12696) — the text is in workstreams.md *Bars (round 47)*

**Bar E3 SNAP SHOTS (engage; filed 2026-10-30 ~20:00 PDT in streams/engage.md and here, BEFORE any number on 12649-12696;
  his YES, R47.20).**

  **The rule:** `--pot-shot` (Gunnery): a crew whose only held gate is the acquisition fix, laid >= POT_SHOT_AFTER_S 0.4 s, its
  target inside the weapon's effective band, fires with its aim off by up to POT_SHOT_WANDER_M 2.5 m at the target (the
  deterministic wander pattern), shrinking to nothing as the fix completes; the round flies where the barrel points. Both
  sides (C47.9). Native's NativeGun / NativeExec twin merged before the freeze (C47.6); arms native ON.
  **Workload (his case: "my tanks took forever to pick their target and get a shot off"):** round 42's attack-shot probe with
  `--hull=gang_tank` (War Rigs ordered to attack a target behind cover, the target shooting back), `ENGAGE_ARM=on`, seeds
  **12649-12696** (48, paired by seed), builder3, native ON, the frozen tree named when frozen after its full check. Arms:
  `--pot-shot=off` v `--pot-shot=on`.

  **Deciding (what he asked for: a shot off sooner):** D1 `first_shot` (mean over a run's crews of seconds from his order to the
  crew's first round; never = the window) paired mean ON - OFF < 0 by at least 1.645 se (one-sided). D2 `first_shot` ON sooner or
  identical in >= 60 % of runs (strictly sooner reported).

  **Guards (what it could break):** G1 friendly hits: total ON <= OFF + max(1, 1.645 sqrt(OFF)). G2 his crews' deaths: total ON <=
  OFF + max(1, 1.645 sqrt(OFF)). G3 no fewer hits: `hits_per_min` paired mean ON - OFF >= -1.645 se. G4 the lane rule's lines
  (round 46's lane probe, seeds 12649-12672, LANE_ARM=on): friendly-fire hits total ON <= OFF + max(1, 1.645 sqrt(OFF)) and
  `held_s` paired mean ON - OFF <= +1.645 se. G5 native EQUAL on the frozen hash (NativeGun / NativeExec with POT_SHOT both ways).

  **Reported (part of what he said yes to):** accuracy (his crews' hits / rounds), shots, the CPU's hit share in his six staged
  fights on the frozen tree (dev: 83 % -> 69 %). **Dev reads (never a bar):** War Rigs, 7001-7012 (102a18395, gun C++ off, n = 12):
  first round median 1.45 -> 0.90 s, accuracy 76 -> 79 %, hits a minute 29 -> 38, friendly hits 0.08 -> 0.08 a run.

### Bar E7 (FILED 2026-10-30 ~19:10, before any number on 12601-12648) — the text is in workstreams.md *Bars (round 47)*

- **Bar E7 VERDICT (2026-10-30 ~20:05 PDT): FAILS on G1 (friendly hits 1 -> 6, limit 2.6); every other line passes.** Code
  frozen at **d4a88c4a5**, its full check GREEN (builder3 `make check exited 0`, 3526 passed / 0 failed, 28 ALL JUDGED,
  sim-baseline unmoved); the runs stamped 04dd39092 (= d4a88c4a5 + `_agents/` docs only, `git diff --stat`). builder3, native ON,
  12601-12648, 48 paired, 0 errors. The OFF deciding arm was refused once (a check helper still live in the folder; nothing ran,
  no number read) and rerun verbatim. `--pot-shot` inert on that tree (default OFF, one branch, first conjunct; no native / mk
  reader). D1 PASS: metres driven away from his target 94.2 -> 30.4 a run (-63.9, se 16.3, z -3.93). D2 PASS: first hit sooner or
  identical 41/48 = 85 % (30 strictly). **G1 FAIL: friendly hits 1 -> 6** (limit 2.6). G2 PASS: crew deaths 102 -> 93. G3 PASS: the
  target dies sooner, 44.1 -> 37.0 s (-7.1, se 2.5). G4 PASS: authority probe 24/24 identical. G6 PASS: the CPU side 48/48
  identical. Reported: first hit 23.6 -> 13.0 s (se 2.4), hits a minute 308 -> 419, never-hit 1.23 -> 0.73 crews a run, accuracy 73 %
  both. **The 6 (traced, `--trace=on`, seeds 12612 / 12621 / 12642, 4 on 12642's five gang IFVs on Locks):** 1-4 hp each, no kill;
  the hurt crews that today retreat stay in the fight circling and assaulting through by the target, and machine-gun rounds
  graze a squadmate (4 under ENGAGE "assault through ... circling", 1 under CLEAR_LANE "E_3 in the line of fire", 1 under SUPPRESS).
  Evidence `~/overnight-engage/r47/barE7/`, `~/overnight-engage/r47/ff_on/` (laptop).

**Bar E7 HIS ATTACK BEATS RETREAT (engage; filed 2026-10-30 ~19:10 PDT in streams/engage.md and here, BEFORE any number on
  12601-12648; R47.6).**

  **The rule:** `--press-on` (TankBrain._obey): an attack-move from an element whose task is `attack` (his click, or a CPU
  commander's attack: C47.9) leaves RETREAT off the menu even when the crew is critical; every other order keeps today's survival
  rule. Native's `_obey` twin is merged (pair/native-e7 19a38a505, EQUAL: 7521 decisions, 0 mismatches), so the arms run native ON.
  **Workload:** round 42's attack-shot probe (`tests/engage/attack_shot_probe.gd`: 2-5 crews ordered to attack a target behind a
  piece of cover on locks / terminus / crossing by seed, the target shooting back) with `--hurt=0.07` (every crew starts below the
  critical line for every doctrine, so RETREAT is on the table), `ENGAGE_ARM=on` (today's attack-shot default), seeds
  **12601-12648** (48, paired by seed), builder3, native ON, the frozen tree named when frozen after its full check. Arms:
  `--press-on=off` v `--press-on=on`.

  **Deciding (what he asked for: his hurt crew keeps at the target he named):** D1 `away` (metres a run's crews drive AWAY from his
  target under the order) paired mean ON - OFF < 0 by at least 1.645 se (one-sided). D2 `first_hit` (mean a run) ON sooner or
  identical in >= 60 % of runs (strictly sooner reported).

  **Guards (what it could break):** G1 friendly hits: total ON <= OFF + max(1, 1.645 sqrt(OFF)). G2 crew deaths (a crew thrown
  away): total ON <= OFF + max(1, 1.645 sqrt(OFF)). G3 the target lives no longer: `target_dead` paired mean ON - OFF <= +1.645 se.
  G4 his other orders untouched: E2's authority probe (move / hold / stop, seeds 12601-12624, AUTH_ARM=on) `--press-on` off v on:
  24/24 rows identical. G5 native EQUAL on the frozen hash (native's `test_native_decide` with PRESS_ON both ways).

  **Reported:** hits a minute, shots, accuracy, never_hit, no_shot. **Dev read (7001-7012, never a bar; 102a18395, n = 12):** away
  63.9 -> 20.9 m, first hit 22.5 -> 17.6 s, deaths 30 -> 27, friendly hits 0 -> 0.08 a run.

  **Amendment 1 (2026-10-30 ~19:40, before any number; the orchestrator's scope question):** the CPU commander DOES issue element
  `attack` tasks (`element_commander.gd` :454, :850, :1024), so the rule as filed reached every CPU attack, not only orders given
  as direct (R47.6). **Narrowed (the smaller honest change, chosen over a full-fight guard):** RETREAT drops only for a crew on HIS
  side (the order context's `his_side`, `tank.team == OrderFeed.player_team`); every CPU crew keeps today's survival rule. The
  native twin re-proves on the narrowed rule before the freeze. **Added guard G6, the CPU side untouched:** the same probe with
  `--his-side=off` (no player team: every crew is the CPU's), seeds 12601-12648, `--press-on` off v on: 48/48 ENGAGE_PROBE rows
  identical. Deciding lines, workload and the other guards as filed. (Amendment 1 of at most 2.)

**E6 the army_cost read (his four recordings' headers, Units costs):** `make skirmish` with a faction budgets BOTH sides at
Units.BASELINE_BUDGET (1000 credits = 5000 points, `skirmish_mode.lineup_plan`), then the laptop preset cuts each side to
squad_cap 4 x 5 = 20 vehicles (C25.6, largest squad first). Gangs are cheap: ~40 vehicles of budget, 20 kept = **2490 points**
(Crossing: 6 War Rigs, 7 IFVs, 4 scouts, 3 support) v the syndicate's whole 17 = 5000. Condemned (Locks): 20 = 4000 v 5170. In the
garage he picks within the cap: Sumps 3430 v 3385, Parade 3430 v 3320 (level). Not intended balance; the owner is Army / skirmish
or balance (not engage): trim the CPU to the capped player's cost, or value a capped swarm's vehicles. Balance waits (brief).

**E3 pot shots, dev reads (never a bar; the gun's C++ paths off in both arms):**
- *War Rigs only* (`--hull=gang_tank`, attack-shot probe, dev seeds 7001-7012, builder3, 102a18395, n = 12 paired): first round
  after a target appears median **1.45 -> 0.90 s** (n 28 / 29); accuracy 76 % -> 79 % (+4 pts, se 14); hits a minute 29 -> 38 (+9, se
  10.5); friendly hits 0.08 -> 0.08 a run; mean first shot 9.3 -> 4.0 s (se 3.6).
- *His six staged fights* (889aa86b0-era tree + E3, n = 1 a window): his hits a minute 24 -> 27, accuracy 20 % -> 19 %, friendly 0 -> 0;
  the CPU (it snaps too, C47.9): hits 362 -> 283, accuracy 83 % -> 69 %, friendly 0 -> 1.
- *All crews, attack-shot probe 7001-7012* (mostly scouts, which already acquire at 0.55x): first shot 3.32 -> 3.14 s, accuracy 78 ->
  77 %, hits a minute 590 -> 529 (se 85): nothing beyond noise.
- **His question (sent, player terms):** "your War Rigs fire their first shot about half a second sooner at about the same accuracy;
  the CPU snaps too and its long guns get less accurate. Turn snap shots on? Recommended: yes." A yes needs the gun's C++ twin
  and its own bar before ON.

**E2 dev reads (2026-10-30 ~18:30, builder3, the gun's C++ paths off in EVERY arm (`--brains-off=native_exec,native_gun`: the carry
has no twin yet), never a bar):**
- *Six staged windows, four arms* (889aa86b0-era tree, n = 1 a window): his shots 2616 today / 2619 carry / 2685 line / 2599 both;
  held while loaded 330 / 349 / 341 / 333 s; never-fired crews 23/58, 26/62, 21/56, 21/58. Each staged fight diverges between arms
  within seconds: six 14 s windows cannot see a few-percent effect. Counters: `--attack-line` searched in 4 of 6 windows (31 on
  Crossing 2070, 16 Sumps); the carry cut acquisition-held ticks ~8 % summed (9134 -> 8434).
- *Round 42's attack-shot probe, dev seeds 7001-7012* (n = 12 paired; new deciding-shaped metric `held_line_s` = loaded, in reach,
  a real line, the team seeing it, not firing): today 23.41 s a run, carry 23.29 (-0.12, se 0.12), line 23.32 (-0.08, se 0.08);
  first hit 3.51 s in all three; deaths 10 / 10 / 11. The probe's clean one-box case rarely reaches either rule.
- *Why the carry is small:* of his side's swaps with a lay in progress (staged gates windows), **only 18 of 62 had the new target
  within 10 deg of the barrel** (median swing 20.7 deg, p75 56 deg; CPU 7 of 61, median 23.8 deg); and 87 of his 145 laying s are
  FIRST fixes (`acquire_seconds` by design: distance over the crew's own sight, gang War Rig 60 m). A wider carry keeps a fix through a
  real swing: that is the pot-shot dial (E3), his call.
- *The rest of his held time, split (staged, 889aa86b0, native on):* no line 18 %, acquiring 44 %, **fire discipline 7 %** (past the
  weapon's effective range, no long shot), aim 5 %, lane 23 %, unseen 3 %. Discipline is not the silence.

**E1 REPORT (2026-10-30 ~17:45; every number STAGED from his census, builder3, 8e51344cc = e306ce27f's game code + measurement-only
traces, native on, lane rule ON = his default game, n = 1 a window; `make engage-e1-windows`, tables `tests/engage/gun_trace_table.py`):**
- **Not the lane rule** (Crossing 2070, ON v `--lane-clear=off`: identical, 0.0 s held by a lane). The lane HOLD (a friend in the
  line, fire held) is 23 % of his held time pooled, mostly Locks 390 (53 s); that is the friendly-fire discipline, not round 46's step.
- **Six windows** (Crossing 600 + 2070, Locks 390, Sumps 450, Parade 330 + 2820, 14 s each), seconds a crew was LOADED with an
  enemy inside its weapon range and did not fire:
  | side | in range | firing + reload | held, loaded | no own line | acquiring the fix | friend in lane | unseen | other |
  |---|---|---|---|---|---|---|---|---|
  | his (gangs / condemned) | 552 s | 222 s | 330 s | 59 s (18 %) | **145 s (44 %)** | 74 s (23 %) | 11 s (3 %) | 41 s (12 %) |
  | CPU (syndicate / law) | 698 s | 331 s | 367 s | 136 s (37 %) | 75 s (20 %) | 73 s (20 %) | 4 s (1 %) | 79 s (21 %) |
- **The class count:** crews with an enemy inside their range > 2 s of a window that never fired in it: **his 23 of 58 (40 %)**,
  the CPU's 12 of 62 (19 %).
- **The acquisition fix is his side's biggest share.** Median fix needed 1.69 s (his) v 1.10 s (CPU): `Engagement.acquire_seconds`
  scales with distance over the crew's OWN sight, and gang sight is short (War Rig 60 m); the syndicate's designators cut it to
  0.25x (30 designations v 0 in his Crossing match). Both are the design (N5, X5). Suppression is not it (median 0). **The part
  that is a fault: 58 of his 145 s (40 %) is a fix RESTARTED after the gun swapped targets** (`Lay.engage` zeroes progress on any
  new name, even a squadmate of the old target on the same bearing); CPU 37 of 75 s. -> **E2a.**
- **His Guns_3 (Crossing 2070):** no own line behind Container20_21 ~2 s after his attack, fix 1.4 s, fired 2208 (his hit on
  Hunters_2 at 2212), reload 4 s, then his named target fell out of TEAM sight at 2327 with its own line clear at 37.9 m: the gun
  swapped to Hunters_3 and restarted the fix (3 s under suppression 0.78). **No own line on that window** (56 % there) is a drive
  into the cover: ENGAGE's "no line of fire: going round" / "it is running: after it" ask for the TARGET'S OWN SPOT; Guns_4 wedged
  on Block_1 k-turning ~2.5 s, Guns_1 circling 48-58 m out. -> **E2b** (a nearby spot with a line); the stall itself is manoeuvre's.
- Evidence: `~/overnight-engage/r47/` (laptop): e1s_logs/, e1w_logs/, gun_trace_table.py.

**E1 so far (2026-10-30 ~17:15, builder3, native on, n = 1 an arm):**
- **`--gun-trace=<crew|all>`** (gunnery.gd + two call sites in order_controller.gd, measurement only, default off): one GUN_TRACE
  line per run of the gun, after it runs on whichever path (GDScript `Gunnery.apply`, `NativeGun`, or the whole C++ execute step
  `NativeExec`; most of a brain crew's ticks are the last): weapon order, pick, lay, lane, loaded, fired, and for the order's
  named target and the nearest enemy in reach their distance, team sight, own line of sight, aim error and acquisition time.
  The lay/lane fields may be stale under NativeExec (not yet confirmed that it writes them back); the probed fields are live.
- **The full replay is not his match** (`make engage-e1`, 8edebac1e = e306ce27f's code + the trace): `tests/replay/divergence.py
  --crews=all --seconds=84` FAIL: Wrenches_1 4.3 m off at 1 s, every crew over 3 m by 19 s; Guns_3 dies before tick 1800 in the
  replay (his: 2457). Identical in both lane arms (the same 6 hits on Rust at the same ticks) and with `--brains-off=native_gun`.
  `REPLAY_SPAWN {"placed":0,"recorded":37}`. Reported to the orchestrator (native's harness); not engage's code.
- **E1b read (STAGED from his Crossing census at tick 2070; builder3, 0e3575b1c = e306ce27f's code + traces, native on, n = 1 an
  arm): the lane rule is NOT the cause** (ON and `--lane-clear=off` identical; 0.0 s held by a lane). The staged Guns_3 tracks his
  (-67.3, -10.0 v his -68.4, -10.1) but dies at 2330 (his 2457). The four War Rigs had 29.5 crew-seconds with an enemy inside
  their 50 m range: **16.5 s (56 %) no own line** (real cover, the muzzle's line blocked too: Block_1 between Guns_4 and
  Rust_Hunters_2 at 26-46 m for ~5.5 s; Container20_21 in front of Guns_3 ~2 s), **8.5 s (29 %) the acquisition lay** (~1.4-2 s
  each, reset to 0 on every pick swap; ~3 s under suppression 0.8), **4.0 s (13 %) reload** (4 s). Guns_3 fired once (2208; his hit
  on Hunters_2 at 2212). **Why no line lasts (`--crew-trace`):** under his attack, ENGAGE's "no line of fire: going round" and
  "it is running: after it" both drive to the TARGET'S OWN SPOT, straight into the cover between: Guns_4 `wedged` on Block_1 and
  k-turning in reverse ~2.5 s, Guns_1 circling / k-turning 48-58 m out. E2 per the orchestrator (2026-10-30): two separate
  switches, each with its own Bar E line: **E2a the lay** (no reset on a swap to a target on nearly the same bearing / carry part
  of it) and **E2b a line under his attack** (go round to a nearby spot WITH a line, `firing_position.gd`, not the target's spot);
  E3 reads what is left. Before sizing: the same split over more staged windows (`make engage-e1-windows`: Crossing 600 (CPU side)
  and 2070, Locks 390, Sumps 450, Parade 330 and 2820, both sides).
- **Hence E1b:** `make engage-e1-stage` stands every living unit at the census of tick 2070, forms the elements with their tasks,
  plays his attack task (Guns on Rust_Hunters_2, tick 2093) and the CPU's later tasks at their ticks, both lane arms.
