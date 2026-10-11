> **ARCHIVED (round 25 closed 2026-10-10).** Kept as the stream left it; current state is in `HANDOFF.md`.
# Stream: pace (no slow motion at 25 a side on his laptop: a smarter "quiet" think rate)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *his pick of the think-rate setting*
> (and its amendments) and *Round 25: the launch*, `_agents/workstreams.md` *Round 25* (C25.1–C25.4, and C24.7: the bar
> and your hunk), round 24's brains report on L1 (`streams/archive/round24/brains.md`, section *L1 (phase 2, C24.7)*:
> every setting, what it bought, what it broke), `_agents/native.md` (the laptop instrument), and lessons 279–282 in
> `orchestration.md`. You own the think-scheduling hunk of `game/ai/tank_brain.gd` (the `*_THINK_*` constants,
> `_think_hz`, the rate choice around `t.rate_progress`, `brain_stride`), a new file of your own for the quiet read
> (e.g. `game/ai/think_quiet.gd`), `tests/test_ai_think_lod.gd`, `tests/tactics/l1_speed_table.py`, new
> `tests/test_pace*.gd`, a new `mk/pace.mk` (the Makefile include line is a merge note). Pass-line changes in existing
> scenarios go through C25.3.

## The lead's direction

- **The bar (C24.7, his decision, 2026-10-09):** 25 a side, no slow motion in the opening clash on his laptop: game speed
  in the 8–20 s window ≥ 0.97 (`make native-tick-profile`, his preset, foundry + parade × 3 seeds, n = 6 paired). Shipped
  today: ≈ 0.82–0.83 (round 24's close).
- **His view, kept:** *"I don't see why we would really need micro-fast decision loops."* A crew that is doing nothing
  that needs a fast decision may think slower. What he would notice is the only test: his bridge, the pursuit, a crew
  finding cover, his line forming on the way.
- Symmetric: both sides on the same rate rule, decided from simulation state only (never the camera, the selection or
  the machine).

## Where things stand (round 24's close; VERIFY)

- L1's knobs are on main, OFF: `--l1=<quiet hz>:<stride>:<settled hz>:<engaged hz>:<element replan ticks>:<stride quiet
  crews in reach 0|1>` and `--think-quiet=`, `--quiet-stride=`, `--think-settled=`, `--think-engaged=`; the window census
  (`--census-window=a,b`, `BRAINS_LOD` split :engaged/:quiet, `BRAINS_KEPT`); the series hooks (`PURSUIT_EXTRA`,
  `BODY_EXTRA`, `ARMY_EXTRA`, `AI_SCEN_FLAGS`).
- What each setting bought (laptop flightdeck, native on, n = 6 paired): quiet 2 Hz alone +0.048 (se 0.008) and broke
  his bridge (a crew 4 s at the rim, 3 of 4 crossed) and the pursuit (range opened 6.9 m); the full "B" bundle +0.162
  (0.007), +0.097 with the stride guards, and broke 15 tests + 6 scenarios. Two thirds of the fight rate's crew-ticks in
  the opening clash are quiet; 76–85 % of thinks keep their choice. **A slower clock re-rolls timing-sensitive fights**
  (2 Hz passed scenarios that 3.33 Hz fails; lesson 281).
- Round 24's finding: the lever is a smarter "quiet": not near water, not chasing or chased by something fast, not
  fighting from cover. Your job is to make that precise, measure what it can buy, and ship it only if it passes.
- Brains is changing seats and the crossing this round (F1, F2): a slower think near a bridge is exactly what broke
  last time. CP2 (brains' F2 on main) is your re-verification point.

## Backlog (in order)

**P0 — the pass lines (C25.3).** For each scenario and test L1's settings broke (the list is in round 24's report and
its logs under `streams/references/round24/brains/`), read the trace at the failing rate and write one line: the crews
did something a player would see as wrong (a BEHAVIOUR failure: keep the line), or the outcome moved inside noise a
player would not see and the line is a threshold (BRITTLE: propose a line that measures the behaviour, e.g. over seeds
or as a rate). Table in Status; the orchestrator rules each proposal before you commit it.

**P1 — the census of a smarter quiet.** Define the quiet read (simulation state only: no contact in reach, not within
N m of water or a bridge deck, no enemy/ally closing faster than X, not in or seeking cover, not in a give-way, not on
a fresh order). On the laptop window (8–20 s, foundry + parade, and his Crossing), count the crew-ticks it marks quiet
against round 24's blunt quiet, and compute **the most it can buy** in game speed from round 24's measured price per
quiet share. Pre-register (lesson 280/281) before P2: the rule, the rate, the pass ("ships only if `make check`, the 44
scenarios and his series are green and the gain is outside 2 se"), and the kill line (if the most it can buy is under
+0.03, write it up and stop: the bar is not reached by think rate).

**P2 — the smarter quiet, DECLARED (C25.1).** One commit behind its knob, then the default flipped in a commit of its
own if and only if the pre-registered rule passes; both sides; the paired series (arrive, his bridge on every crossing
map both sides, the beaten zone, the pursuit, his recordings' cases) and the laptop price (C25.4: ask the orchestrator
for the laptop first). After CP2, merge main and re-run the series on brains' new crossing before you call it green.

**Stretch:** (a) a per-crew rate for the ENGAGED crews that keeps their choice (76–85 % of thinks keep it): price a
"re-think only on a changed input" check, equal-answer first; (b) report to the orchestrator what is left between the
shipped speed and 0.97, by component, from `make native-tick-profile`'s breakdown.

## How to verify

`make remote T=check` (read the wrapper's own exit line and the runner's counts, never through a pipe); the AI
scenarios; the census and `make native-tick-profile` on the laptop (C25.4: serialized through the orchestrator, quiet
window, paired by seed, ABBA, cooldown, void a hot session). Every number with commit, machine, workload, n and se.
`decide` runs in C++: a rate change is upstream of it (no port needed); if you change anything inside a ported
function, C25.2.

## Don't touch

Everything in `tank_brain.gd` outside your hunk (brains' behaviour, native's seams), `movement.gd`, `game/tactics/**`,
native's files, and the *Nobody this round* list in `workstreams.md` *Round 25*.

## Waiting on the lead

Nothing. If P1's kill line triggers, the orchestrator takes "the bar is not reachable by think rate; here is what is
left" to him in player terms.

## Status

_(the worker keeps this current; newest first inside each section)_

### FINAL (2026-10-10): merge `4fa6297c` (= main 18cadfda + pace; code as judged at `d44fb459`)
make check on `2f721a5e` (builder0): exited 0, 2343 passed / 0 failed; perf-judge NOT JUDGED (the box busy, ratios 2.0-2.5×),
re-run on `4fa6297c` when the load dropped: **JUDGED, PASS**. scenario_perf's brain-budget case is NOT JUDGED here
(unpinned on the hybrid box; judged by perf-judge). Commits after `2f721a5e`: Status only.

### FOR ROUND 26 — what to keep (pace's round is done, 2026-10-10)

- **The determinism tools** (`mk/pace.mk`, outside check):
  - `make pace-determinism`: a lab drill alone under engine clocks free/30/60. It must print byte-equal MEASURE lines; it fails on main until START_TICK is pinned.
  - `make pace-div`: two clocks traced; the first tick and field that differ (`tests/pace/first_divergence.py`).
  - `make pace-repro`: one drill N times, with `PACE_REPRO_ENGINE` for engine flags.
- **The phase tools:**
  - `make pace-sweep` (`tests/pace/start_sweep.sh`, needs `references/round25/pace/lab-start-tick-trial.patch` applied until brains' START_TICK pin takes an override): his bridge at start ticks 1-18.
  - `tests/pace/sweep_tally.py`: pass counts and the pooled line over the **pre-registered set {1, 3, 6, 8, 11, 16}**.
  - `--think-phase=` with `make pace-p0`: any scenario or drill at think phases 0-5.
  - Any pass line that flips with phase is luck, not a measurement.
- **The leak checks:** `make pace-leak` (scenario runner, the target alone v after others) and `make pace-leak-tests` (drill runner).
- **The gap table:** `tests/pace/gap_table.py` on `make native-tick-profile` logs gives frame, ticks a frame, R, tick scripts by segment, and the tick target for 0.97. Re-run it after each port: the gap was 9.0 ms a tick instrumented (49e2bdcd, laptop, n = 6), ports ≈ 5.3 (2.7-8).
- **The census:** `make pace-census` (BRAINS_LOD shares in the 8-20 s window). The think rate is spent: the genuinely quiet crews are ≈ 1/6 of crew-ticks, worth ≈ +0.014.
- **Open, owned elsewhere:**
  - brains: START_TICK pin; the bridge's pooled line (F3 870e3fe7 meets 2/6); cp2's phase-2 miss; the overwatch stall.
  - native: ports toward 0.97, with 20 a side on the laptop as the lead's fallback.

### DETERMINISM (2026-10-10, after the report; orchestrator-ranked above cp2) — his bridge drill's nondeterminism FOUND

**Layer:** `tests/tactics/tactics_lab.gd:83-87`, `TacticsLab.start()`. It waits physics frames until
`navigation_is_this_arenas()`, but the navigation map syncs once a **rendered** frame, not once a physics tick. So the drill
starts on a tick that depends on the engine clock: `--fixed-fps 30` and `15` start on tick 1; `--fixed-fps 60`, and the free
clock `make test` uses, start on tick 0. Every think and element cycle shifts with it. A loaded machine changes the free
clock's frames a tick: 21.0 / 12.6 / 21.0. The sim baseline is stable because it always runs `--fixed-fps` and does not
use this wait. First divergence (`make pace-div`, 30 v 60 fps traced): the element's first order, issued_tick 3 v 4;
nothing earlier. Each clock alone repeats (builder0: free 21.0 ×5, 30 fps 12.6 ×5, 15 fps 12.6 ×3).
**Failing test:** `make pace-determinism` (the drill alone under clocks free/30/60; MEASURE lines must be byte-equal):
FAILS on `f3b84ee2` (free 21.0, 30 12.6, 60 21.0). With the trial fix (pad to a fixed tick after the nav wait,
`references/round25/pace/lab-start-tick-trial.patch`, on no branch) it PASSES under free/30/60/15, whole line equal: the
start tick is the only layer for this drill. **Ruled:** START_TICK pinned at 1 in `TacticsLab.start()`; brains applies
it (their file).

**The bigger finding: one start tick is not a measurement.** `make pace-sweep` (ticks 1-18, 30 fps, builder0, trial patch;
`tests/pace/sweep_tally.py`; `references/round25/pace/bridge-start-sweep-*.txt`). C25.3 ruling: the bridge line becomes,
at EVERY tick in the pre-registered set **{1, 3, 6, 8, 11, 16}** (t = 1 + 5k mod 18, fixed by rule before 870e3fe7's
results), both sides, all 4 crews across and rim_crews 0.

| commit | his side passes | CPU passes | strict (both) | pre-registered set |
|---|---|---|---|---|
| main `f3b84ee2` | 7/18 | 14/18 | 4/18 | **0/6** |
| brains CP2 `c7b20c9f` (F2: plain moves only; this is a drill) | byte-identical to main | | | 0/6 |
| brains F3 (old) `567dca69` | 11/18 | 15/18 | 8/18 | 3/6 (1, 6, 8) |
| brains F3 `870e3fe7` | 9/18 | 13/18 | 7/18 | **2/6** (1, 6) |

On main, 9 of 11 failing starts of his side have a crew pressed at the water ≥ 3 s, his reported bug; the suite's green
(tick 0) and brains' series (tick 1) both sit on passing phases. Sent to the orchestrator: F3 does not meet the line.

### REPORT (2026-10-10) — GREEN, merge here: `d44fb459` (builder0, `make check exited 0`, 2343 passed / 0 failed, 44/44 scenarios, 23 targets ALL JUDGED; log `build/pace-check-d44fb459.log`). Baseline at launch: `fccc520c`, 2338/0.

**Done.** P0 (the pass lines: table and rulings below); P1 (the census, pre-registration, kill line); P2 (S failed its
bar; S2 was killed by its kill line; **nothing ships, the think rate is unchanged**); stretch (b) (the gap to 0.97 by
component, with native). Stretch (a), a per-crew "re-think only on a changed input" for engaged crews, was **not done**:
P1/P2 showed that in the opening clash the crews in reach are under a gun or retargeted every few seconds, so a
keep-the-choice skip has the same ≈ 0.5 ms ceiling or less (the gap is 9 ms). Recorded, not attempted. Found on the way:
**the scenario runner's frame-phase leak** (fixed on main `00b91730` by the orchestrator from pace's line; `make
pace-leak` is the check) and **his bridge drill is not reproducible run to run** (below).

**What merges (equal answer, all OFF):** `game/ai/think_quiet.gd` (ThinkQuiet: the quiet read, census only unless
`--think-smart=` > 0); in `tank_brain.gd`, pace's hunk only: `--think-smart=` (`SMART_QUIET_HZ`, `PACE_SMART_HZ` = 0), the
census split in `_count_lod` (only under `--brains-census`), `--think-phase=` (`THINK_PHASE`, 0); tests
`tests/test_pace_quiet.gd` (5); `mk/pace.mk` (pace-p0, pace-p0-tests, pace-census, pace-census-quick, pace-leak,
pace-leak-tests, pace-repro; auto-included by `include mk/*.mk`, no Makefile line); `tests/pace/` (p0_summary.py,
census.py, gap_table.py: a new folder, pace's); evidence `references/round25/pace/`. Thirteen lines and determinism
unmoved (check green).

**Decisions (each with its reason):** census on builder0, not the laptop (simulation counts; read shares, perf-drive is on
wall time); the order guard dropped (92 % of order changes are element retargets, each already waking the crew); FAST =
own target opening ≥ 3 m/s (closing marked 97 %); 2 Hz kept (round 24's evidence base; neighbouring rates flip
outcomes, lesson 281); cp2's pooled line not committed (the leak); stretch (a) not attempted (ceiling below the gap).

**Questions for the lead:** answered (2026-10-10, via the orchestrator): more C++, 20 a side on the laptop as the
fallback. Stretch (b)'s table carries native's corrected port estimate (≈ 5.3 ms, 2.7–8).

**Requests to other streams:** brains: the overwatch bound stalls on main at one think timing in three
(`--think-phase=1`, commander z −13 v −60; routed by the orchestrator); brains: his bridge drill's run-to-run
difference is the lab's start tick (DETERMINISM above); pin START_TICK and judge the bridge line over the pre-registered set.

**Known issues:** cp2's engine-deck line is phase-brittle at today's rate. On the fixed runner, alone (`7df8cb69`,
builder0), the same numbers as in the suite: phases 0/1 deck 41 of 43 hits (pass), phase 2 deck 4 of 22 (fail). The pooled
line was re-proposed and **DECLINED** (orchestrator, 2026-10-10): the line stays as on main; a scout that never reaches
the deck at one timing in three is a behaviour a player could see, filed with brains as a known weakness (beside the
overwatch stall). **Leak mutation proof:** `make pace-leak` passes on the fixed runner (41/43 alone and after all 6) and
FAILS with `00b91730`'s runner fix reverted (7 hits alone v 43 after); `make pace-leak-tests` passes (bridge 21.0 alone
and after). pace-leak, pace-determinism, pace-div and pace-sweep merge as tools, outside check (ruled).

**What to playtest:** nothing changes in play (every knob OFF). To see the rejected arm: `make native && make skirmish`
with `--think-smart=2` added to the skirmish flags (S; it will lose a tank fighting from a wall corner) or with
`--think-smart=2 --quiet-watched=1` (S2: behaves, saves almost nothing).

**Next steps:** brains pins START_TICK = 1 and works toward the pooled
bridge line over {1, 3, 6, 8, 11, 16} (`make pace-sweep` with the trial patch measures any commit). If the lead's
fallback (20 a side on the laptop) is taken, that is `Units`/garage work, not pace's paths.

**Merge notes:** `tank_brain.gd`: pace's hunk only (C24.7): `_think_rate`'s smart-quiet branch, `_count_lod`'s census
lines, `_due_to_think`'s phase, the `SMART_QUIET_HZ`/`THINK_PHASE` statics. No ported function changed (C25.2: `decide`,
`build_situation` untouched; `_think_rate` is not ported).

**Plan (2026-10-10, pace):**
1. Baseline `make remote T=check` on `fccc520c` (builder0).
2. **P0 tooling:** `--think-phase=<n>` (test-only, default 0 = equal answer: every brain's first think shifted n ticks,
   the rate unchanged) and `make pace-p0` (each scenario L1 broke × each L1 setting × phases 0–5, one log per arm ×
   phase, `tests/pace/p0_summary.py`). **Why phases:** a pass line that flips on the think phase alone at TODAY's rate
   measures timing luck (BRITTLE); one that holds at every phase today and fails at every phase under the slower rate,
   with a trace showing a crew doing something a player would see, is BEHAVIOUR.
3. **P0 table** (below) → the orchestrator rules each proposal (C25.3) before any pass line changes.
4. **P1:** `ThinkQuiet.why_not` (`game/ai/think_quiet.gd`): quiet only with no fresh order (2 s) or element call, not
   in/going for cover (COVER_FIRE, TAKE_COVER), not giving way, no contact ≥ 8 m/s within 130 m, not within 20 m of
   water/pit/deck. Census by `make remote T=pace-census` (perf-fight size 25, foundry + parade + crossing × 3 seeds,
   8–20 s, BRAINS_LOD split by reason). Most-it-can-buy = smart share × round 24's +0.048 for quiet 2 Hz on all quiet
   crews (scaled by thinks removed if the rate differs). Pre-registration written here before P2.
5. **P2** only if P1 clears the kill line (+0.03).

**P1 — the census of a smarter quiet: DONE (2026-10-10).** builder0, `make remote T=pace-census` at `37b91c04` (and
`3a8d185b` for the verb guard alone): perf-fight size 25 (his preset's workload: player side attack-moving a group every
12 s), foundry + parade + the Crossing × seeds 92721 31337 5988, window 8–20 s, **n = 9 runs, 145 128 crew-ticks**.
Files: `references/round25/pace/census-*.txt`. (perf-drive orders on wall time, so builder0's orders land slightly
differently from the laptop's: read shares, not counts.)

- Round 24's blunt quiet is **60 %** of every crew-tick in the opening clash (70 % of the fight-rate crew-ticks).
- The read, rule by rule (share of round 24's quiet each marks NOT quiet, all maps): the verb guard 52 %, the intent
  guard 64 %, water 12 % (Crossing only: 33 % there), fast (own target opening ≥ 3 m/s) 9 %, give-way 6 %, cover 1 %.
- **Why the order guards cost so much:** the order changes quiet crews see are **92 % target changes** (element leaders
  reassign focus targets every few seconds), 6 % a new destination, 2 % a move/attack-move flip on the same leg. Every
  such change already wakes the crew for an immediate think (`order_changed` → `_order_dirty`); the guard would add 2 s
  at the fight rate after each, and in the opening clash that is most of the time.
- Smart share of round 24's quiet on the bar's maps (foundry + parade), and the most it can buy at 2 Hz
  (= share × round 24's +0.048, se 0.008, for quiet 2 Hz on ALL quiet crews, laptop `4f8664ce`, n = 6; an upper
  bound: the read itself costs a little per re-rate):

  | rule | foundry | parade | most it can buy |
  |---|---|---|---|
  | every rule + verb guard | 39.1 % | 41.5 % | +0.019 |
  | every rule + intent guard | 26.6 % | 30.1 % | +0.014 |
  | **every rule, no order guard** (cover, give-way, fast target, water) | **85.6 %** | **86.4 %** | **+0.041** |

  With either order guard the kill line (+0.03) is hit; without one it is cleared.

**PRE-REGISTERED (2026-10-10, before any P2 run; lessons 278/280/281):**
- **The rule (one arm, "S"):** a crew in reach of a known enemy and not in the shooting (round 24's quiet:
  `_engaged()` false) thinks at **2 Hz** when `ThinkQuiet.why_not` is "" with **no order guard**: not holding
  COVER_FIRE / TAKE_COVER, not giving way (Movement `yield_to` / give-way), its own target (order's, else choice's) not
  opening the range at ≥ 3 m/s, not within 20 m of water, a pit or a bridge deck. Otherwise today's rate. Both sides,
  simulation state only. No stride, no settled/engaged knob, element re-plan unchanged. A new order or element call
  still wakes the crew at once (unchanged); the next re-rate (0.1 s) lifts it the moment any reason appears.
- **Ships (default flipped in its own commit) only if ALL hold:** `make check` green on builder0 (pass lines as ruled
  under C25.3, none loosened for S); the 44 scenarios at think phases 0, 1, 2 with no scenario that passes all three
  at base failing any under S; his series both sides with S v base, paired: the arrive series, his bridge on every map
  with a crossing (Locks, Crossing; Sumps' decks), the beaten zone, the pursuit, his recordings' cases (the Crossing
  2026-10-10, the Locks 2026-10-08); and the laptop's paired gain (`make native-tick-profile`, his preset, foundry +
  parade × 3 seeds, n = 6, ABBA, cooldown) **positive and outside 2 se**.
- **Kill line:** cleared for S (+0.041 most it can buy ≥ +0.03); hit for either order guard (≤ +0.019), so neither is
  an arm. If S's laptop gain comes in under +0.03 or inside 2 se, S does not ship and the gap to 0.97 is reported by
  component (stretch b).
- **What it will not do, said in advance:** at best ≈ +0.04 on ≈ 0.82–0.83, so ≈ 0.86–0.87: **the 0.97 bar is not
  reachable by think rate**; the rest is the tick's other components (stretch b).

**Stretch (b) — what stands between today and 0.97, by component (2026-10-10).** Data: native's laptop session
(flightdeck UHD 620, his preset, 25 a side, foundry + parade × 3 seeds, window 8–20 s, arm "on" = main's game code
`fccc520c` + native as on main; native's branch `49e2bdcd`), **n = 6**, files `references/round25/pace/laptop-tp-native-49e2bdcd/`,
table `tests/pace/gap_table.py` (and native's own `tests/native/tick_profile_budget.py`, the same model, the same answer).

*The model.* In the opening clash the laptop runs at its catch-up cap, 3 ticks a frame (2.98 measured). A frame costs
R + 3·S: S = one tick (scripts + the engine's physics step), R = everything else in the frame (render, the HUD, effects,
audio, engine). Game speed = 3 × 33.3 / (R + 3·S). **0.97 needs R + 3·S ≤ 103 ms.**

| measured (instrumented, mean of 6, se) | ms |
|---|---|
| frame | 130.0 (2.6) |
| ticks a frame | 2.98 (0.02) |
| R, the frame outside the ticks | **22.9** (0.6) |
| S: tick scripts / physics step | **35.4** (0.6) / 0.57 |
| of which: think 15.5 (situation 5.2, poll 2.7, act 2.5, decide 1.8, rate 1.4, incoming 0.7) · execute 9.0 (weapon 4.4, move 3.3) · elements 5.7 · tank 1.8 · match 1.2 · visfield 0.5 | |
| R's known parts (whole-run perf-play summary, shares): HUD `_process` 5.3–7.3 · effects ~1.0 · CPU render submit ~2.3 · GPU 11–20 (mostly overlapped) · the rest ~13 (engine, sync) | |

Instrumented game speed 0.77; uninstrumented (the C24.7 reading) ≈ 0.83 (native: 0.831 model v 0.827 measured).
**The gap: 9.0–9.2 ms a tick in these instrumented units (25.6 % of the scripts; native's budget model predicts 0.768
v 0.769 measured), ≈ 5.7 ms on the uninstrumented scale; or 27 ms a frame if it all came from R (3 ms of R = 1 ms of
tick).** The lever estimates below are in the same instrumented units as the 9 ms.

| lever | what he would notice | most it could buy (ms a tick) | confidence |
|---|---|---|---|
| think rate (P1/P2: the genuinely quiet crews) | a crew at the back reacts a little later | **≈ 0.5** (+0.014 speed, measured upper bound) | high: it is small |
| the remaining equal-answer C++ ports: ElementPlan.build, act, the k-turn callback, `native_el` (−2.1 ms of elements on water; ON after native's water re-run), scan, and the items that need a grant | nothing | **≈ 5.3, range 2.7–8** (native's ranked estimate, corrected 2026-10-10; my earlier 2–3 counted only its no-grant items) | medium |
| an ALGORITHMIC cut in think (situation 5.2, poll 2.7: fewer/cheaper reads per think, not fewer thinks) | nothing, if equal answer | unknown; the largest untouched block (7.9 ms) | low (not designed) |
| the HUD's per-frame cost halved (5–7 ms a frame) | nothing, if done well | **≈ 1** (3 ms of R) | medium |
| a lower render preset in the clash | less eye candy | **≤ 1** (the CPU render submit is ~2.3 ms a frame; the GPU overlaps) | low: needs its own arm |
| 20 a side instead of 25 (or 4 squads) | a smaller army | **≈ 8** (the tick scales ~n^1.3: 25 → 30 measured ×1.26) | high |

**Reading (corrected 2026-10-10 on native's ranked estimate).** The "nothing he'd notice" levers together: ports ≈ 5.3
(2.7–8), HUD ≈ 1, think rate ≈ 0.5, ≈ 6.8 of 9 (range 4.2–9.5): about three quarters of the gap centrally, all of it
only at the top of native's range. What surely closes it: fewer vehicles (≈ 8), a lighter preset (R; needs its own arm),
or an algorithmic cut in think's situation/poll (unknown, a design task). **The lead chose (2026-10-10, via the
orchestrator): more C++, with 20 a side on the laptop as the fallback.** That matches the corrected numbers: porting is
likely to get most of the way, and 20 a side is the sure backstop if the measured ports land low in their range.

**P2 — OUTCOME (2026-10-10): NOTHING SHIPS; the kill line ends it. The think rate cannot buy the bar.**
- **Arm S failed its pre-registered bar** (builder0, `f16f9ab1`, old runner, 44 scenarios × phases 0–2, base v S): S fails
  cover-by-a-wall at ALL three timings (returns to cover 2 → 0, hidden 88 → 59 %) and clear-the-lane at one (1 shot).
  Base fails only the two phase-luck lines (overwatch p1, cp2 p2). Trace: the tank fighting from behind the wall holds
  **ENGAGE**, not COVER_FIRE, between shots; 2 s after its shot it reads quiet, drops to 2 Hz, and stays in the open.
  The "cover" reason keyed on the option name; the right signal is "a gun is laid on me". **S does not ship** (ruled).
- **Arm S2 = S + "watched"** (approved by the orchestrator as the one last arm): a known enemy gun laid on the crew
  (turret within `TankBrain.COS_WATCHING` ≈ 20° of the line to it, the crew inside its reach + 5 m), `--quiet-watched=1`.
  **Pre-registered:** the rule above; the bar unchanged from S; the decisive runs on the fixed runner; the kill line
  from a fresh census. **Census** (builder0, `6e9fa947`, n = 9, `references/round25/pace/census-s2.txt`): "watched" marks
  **66–68 %** of the quiet crew-ticks on foundry/parade (53 % overall). S2's smart share: foundry **29.0 %**, parade
  **28.7 %** (Crossing pulls ALL to 35.8 %). **Most it can buy: 0.29 × 0.048 ≈ +0.014 < +0.03 → KILLED** before its
  decisive runs. (Exploratory, old runner: S2 passes cover-by-a-wall and clear-the-lane at all three timings, so the
  defect was named correctly; it just leaves almost nothing to slow.)
- **The finding, in player terms:** in the opening clash at 25 a side almost nobody is really idle. Of the crews that
  are in reach and not firing at this instant, two thirds have an enemy gun pointed at them, and most of the rest have
  just been given a new target. A crew like that has to react within a tenth of a second or he sees it stand in the
  open. Thinking less often can only save the ~1/6 of crew-ticks that are genuinely quiet: ≈ +0.014 game speed, not the
  +0.15 the bar needs. **The 0.97 bar is not reachable by think rate**; what is left is stretch (b).
- The knobs stay on the branch OFF (`--think-smart=`, `--quiet-watched=`, `--quiet-guard=`), equal answer.

**P0 — the pass lines (C25.3), DRAFT for the orchestrator's ruling** (builder0, light lane, code `53fdee00` = main
`fccc520c` + the measurement-only `--think-phase`; `make remote T=pace-p0` → `build/light/build/pace/p0/`, summary
`tests/pace/p0_summary.py`; each arm × think phases 0–5. Phases repeat with period 3 at today's 10 Hz fight rate, so
p0/p3, p1/p4, p2/p5 are the same fight: **n = 3 distinct timings per arm**). Arms: base (today), q2 / q333 (quiet 2 /
3.33 Hz), settled 3.33, engaged 7.5, stride4 (`--l1=2:4`), B (`--l1=2:4:3.333:7.5:6`).

| scenario (line) | today, 3 timings | what broke it | trace (what a player would see) | verdict | proposal |
|---|---|---|---|---|---|
| cover: a healthy tank near a wall fights from cover (hidden ≥ 50 %, shots ≥ 2, back into cover ≥ 2) | 3/3 pass, but ON the line: shots 2, returns 2, hidden 88 % at every timing | q2, q333: 1 timing of 3; settled, stride4, B: 3/3 | the tank stops ducking back: hidden 88 → 59 %, returns to cover 2 → 0, it trades shots in the open | **BEHAVIOUR** | keep. (Today's margin is zero on two counts: worth a note to brains, not a looser line.) The smarter quiet never slows a crew holding COVER_FIRE / TAKE_COVER. |
| cp2: a scout works onto a tank's engine deck (≥ 20 hits, deck share ≥ 0.5) | **fails 1 timing of 3 at today's rate** (deck 4 of 22 hits; else 41 of 43) | q333: 3/3 (7 hits: the scout barely fights); q2 passes 3/3 | at today's rate one timing in three the scout never gets onto the deck | **BRITTLE** (flips on think phase alone, no rate change) | measure over the three timings: run phases 0, 1, 2 and pass on pooled deck share ≥ 0.5 and every timing ≥ 20 hits (today: 86/108 = 0.80, min 22 hits → pass; q333 still fails on hits: the behaviour break stays caught) |
| elements: a unit fighting from a formation slot stays in it | 3/3 | settled, stride4, B: 3/3 | (slot drift: the crew leaves its slot) | **BEHAVIOUR** | keep (not a knob the smarter quiet uses) |
| suppression: holding a crew down lets a teammate work on it | 3/3 | B only (every knob alone passes 3/3) | the bundle's interaction (lesson 281) | **BEHAVIOUR** of the bundle | keep |
| elements: the base of fire keeps firing while the others move | 3/3 | nothing today (B passes 3/3; round 24's failure no longer reproduces on `fccc520c`) | — | moot | keep |
| squad: the overwatch element covers from cover (+ the bound makes progress) | **fails 1 timing of 3 at today's rate**, identically under every arm (commander z −13 v −60) | none: every arm fails the same timing | one timing in three the bound stalls; the think rate does not move it | **BRITTLE for pace's purpose** (phase-luck, not rate); a real stall for brains | keep the line; report to brains: the bound stalls at one think timing in three on main (`--think-phase=1`). Proposal if the orchestrator wants it phase-robust: the same pooled form as cp2 |
| motion: two tanks duel on the move, front armour first ("they still fight": shots ≥ 6) | 3/3, ON the line: x3 shots [3, 3] = 6 at every timing | engaged 7.5: 2 timings of 3 ([3, 2] = 5) | one shot fewer in 20 s; moving, front-armour shares unchanged (80–100 %) | **BRITTLE** (the threshold is today's exact value; a 1-shot move in 20 s) | "they still fight": pooled over phases 0–2, ≥ 15 shots (today 18; engaged 7.5 → 17 still passes: one fewer shot per duel is not a behaviour a player sees; a duel that stops firing, ≤ 4 a timing, still fails) |
| cover: with a teammate drawing fire it takes no more hits than x3 and fewer than the bait brain | 3/3 | stride4: 1 timing of 3 (the relative line) | under stride4 at EVERY timing the cover brain takes 4× the hits (3 → 12), peeks 15 → 5: the relative line misses it because x3 degrades too | **BEHAVIOUR** (the line under-reads it) | keep; the smarter quiet never strides |

Round 24's quiet-2 Hz drill failures, the same way (builder0 light lane, `make pace-p0-tests`, code `3a8d185b`,
phases 0–2): **today's rate 10/10 at every timing; quiet 2 Hz fails the same 3 at every timing** → **BEHAVIOUR**, keep:
his bridge, green (Green_S_4 4.2 s at the rim, 3 of 4 crossed) and rust (Rust_S_3 4.0 s at the rim); the pursuit (a
crew opened the range +6.9 m on the 18 m/s runner). These are the two cases S's water and running-target reasons exist for.

**Rulings (the orchestrator, 2026-10-10, `workstreams.md` on main `33023ab3`):** (1) cp2 pooled line APPROVED, then
**HELD**: run alone, cp2 fails at phase 0 too (7 hits) while after other scenarios it passes (43) — scenario order leaks
state (being diagnosed, below); the line stays as on main. (2) duel pooled ≥ 15 DECLINED (holds identically at every
timing today; S does not use the engaged rate; re-propose only with a trace if S fails it). (3) overwatch STAYS (a
bound stalling at one timing in three is a bug a player sees; sent to brains). (4) cover-by-a-wall, slot,
suppression, teammate-draws-fire: kept. Arm S accepted as pre-registered. Tests that pin knobs (`test_ai_levers`, `test_ai_think_lod`) are spec, not behaviour: they move with
an intended knob change by design. The B bundle's element re-plan 6 failures (his line forming, two squads, settle,
make-room) are brains' `Elements.REPLAN_TICKS`, not a lever pace will use: not re-run.

**Decisions:** a new `tests/pace/` folder for pace's scripts (p0_summary.py, census.py): `tests/tactics/**` is brains',
and the brief lists only `l1_speed_table.py` there. `mk/pace.mk` needs no Makefile line (`include mk/*.mk`).

