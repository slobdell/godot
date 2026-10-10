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
**The gap: ≈ 5.7 ms a tick (17.7 % of the scripts), or ≈ 17 ms a frame of R, or a mix (3 ms of R = 1 ms of tick).**

| lever | what he would notice | most it could buy (ms a tick) | confidence |
|---|---|---|---|
| think rate (P1/P2: the genuinely quiet crews) | a crew at the back reacts a little later | **≈ 0.5** (+0.014 speed, measured upper bound) | high: it is small |
| the remaining equal-answer C++ ports (situation, poll, act, weapon/scan) | nothing | native's optimistic ≈ 8–9 instrumented; realistic **3–5** windowed (round 24: windowed gains ran ½ to ⅓ of headless, lesson 279) | low–medium |
| the elements in C++ (ElementPlan.build ≈ 25 % of 5.7, grounding ≈ 37 %) | nothing | **≈ 1.5–3** | medium (native prices `native_el` now, N5b) |
| the HUD's per-frame cost halved (5–7 ms a frame) | nothing, if done well | **≈ 1** (3 ms of R) | medium |
| a lower render preset in the clash | less eye candy | **≤ 1** (the CPU render submit is ~2.3 ms a frame; the GPU overlaps) | low: needs its own arm |
| 20 a side instead of 25 (or 4 squads) | a smaller army | **≈ 8** (the tick scales ~n^1.3: 25 → 30 measured ×1.26) | high |

**Reading.** No single "nothing he'd notice" lever reaches 5.7 ms; ports + elements + the HUD together reach it only on
the optimistic side (≈ 5.5–9). Think rate is not one of the levers. The one sure lever is fewer vehicles. **The question
for him, in his terms:** *"The opening clash at 25 a side runs at about 83 % speed on your laptop. To reach full speed
we can (a) keep porting to C++ for another round or two, with nothing you'd see but no guarantee it gets all the way;
(b) cap the laptop at 20 a side (4 squads), which gets there for sure; or (c) accept ~85–90 % in the first 10 seconds of
the big clash. Recommended: (a) with (b) as the fallback if a round of porting leaves it short."*

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

