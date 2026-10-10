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

_(the worker keeps this current)_
