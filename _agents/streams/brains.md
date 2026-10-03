# Stream: brains (the tick's last big line: decision levers, each priced for his page, none shipped on our call)

> Read `_agents/orchestration.md` (the worker contract), `_agents/streams/archive/round16/brains.md` (your predecessor's
> final report: the split, the per-part profile, the instruments it built, the lever write-up), `_agents/unit_ai.md` §8,
> `_agents/sim_tick_rate.md`, `_agents/navigation.md`, `_agents/workstreams.md` *Round 17*. You own `game/ai/**`,
> `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`, `mk/ai.mk` **minus
> its `ai-perf*` / `scenario_perf` targets (ship's this round)**, `mk/nav.mk`, `mk/tactics.mk`, `tools/ai_*.py`,
> `tools/tactics_ladder.py`.

## The lead's direction

His question in round 16 (2026-10-02), which this stream answers with prices: *"lowering the frequency of thinking
combined with sharding"*. And the rule his round-16 words set, which still binds: *"before sacrificing any of the
existing graphics or gameplay let's find (or profile our code) where we can just get better performance"* — so **a
lever that changes a decision is PRICED and put on a page, OFF by default; his tap ships it, not ours** (C16.1, kept
as C17.4). On 2026-10-03 he put this stream in round 17 (*"I want all 5"*).

## Where things stand (round 16's close; every number with its source)

- **What he feels** (the laptop, his path, `make perf-play`, CPU idle, `301bac8b`): at ~30 vehicles the **tick is
  25 ms** on the main thread, ~85–90 % of it brains, 1.4–1.7 ticks a frame; at ~39, 27.5–28 ms and 84–92 % of frames
  over 34 ms. Round 5's budget is a tick ≤ 5 ms at 60 vehicles. A locked 30 at 30 vehicles needs the tick near 12 ms on
  this laptop. Equal-answer optimisation is spent (round 16 took 9.4 % with every decision identical).
- **Where the brains' time goes** (builder0, loaded, `791c3001`, 50 vehicles, Sumps seed 92721 Law v Condemned): execute
  (every unit, every tick) 6.67 ms — move 4.60, weapon 1.62; think 4.76 ms on 7.7 thinks a tick (situation 2.17, decide
  0.86, act 0.59); nav.chord 1.13 (24.6 calls), nav.closest 1.07 (114 calls), nav.is_ready 0.46; steer 1.21, avoid 0.92,
  path 0.91, guard 0.69; weapon.scan 0.77. So **thinking is the smaller half**: halving every think buys at most ~2.4 ms
  of ~13; execution is where the time is, and striding execution changes motion.
- **Cadence and sharding already exist**: 10 / 5 / 3.3 thinks a second by LOD (`tank_brain.gd` `_think_rate`; near =
  within `LOD_RADIUS` 130 m of a known enemy), staggered by `think_offset`; elements on `(tick + id) % UPDATE_TICKS`; a
  new order or an incoming round forces a think on its tick. Round 5 priced global rates (`x6t5` −15 % of the brains,
  `x6t4` −29 %). The controller stride (`brain_stride`) exists as a variant and is not the default because it changes motion.
- **Instruments, all on `main`**: `make ai-perf DETAIL=1` (parts and calls a tick), `make remote T=sim-profile`
  (`brain/*`, `nav.*`, `los.*`, `avoid.*` sections; `BUDGET≈4600–5200` is his army size, the default 1000 is 10
  vehicles), `make ai-ab-match` / `ai-ab-play` and `--brains-off=<names>` / `--brains-ab-run` (cost by removal inside
  one run), `make ai-parity` (decision equality: it WILL differ for a lever, by design), `make ai-script-profile-play`,
  `make ai-ladder`, `make tactics-drills`, `make ai-scenarios-check`, `make nav-scenario-arms`, the K1 response test,
  and play's `make perf-play` (his path on the laptop — the orchestrator's quiet-window runs are the record).
- **Known red**: `scenario_cover::test_peeking_while_the_enemy_reloads_takes_fewer_hits` has failed since round 15 (the
  count file carries it). `scenario_perf` refuses to judge under builder0 load — ship has that this round.

## Backlog (in order)

- **T1. The price list's frame: one harness, one table shape.** For any switch: **cost** = tick ms removed, by
  alternation inside one run (`ai-ab-*`), on builder0 with the load stated AND the projected laptop figure checked by
  one `perf-play` arm you hand the orchestrator to run in a quiet window; at his army size, split **early match
  (everyone travelling)** / **in the fight**. **Behaviour** = `ai-ladder` against the champion with identical-md5
  controls (seeds named BEFORE the first run; acceptance on seeds the design never saw — lesson 224), drills and scenario
  counts, arrivals and stuck events (`nav-scenario-arms`), order-response latency (K1: a new order is taken up on the
  tick it arrives — this one must not move at all), and first-contact and first-shot seconds from `MATCH_RESULT` over
  16 seeds. One row per lever, the same columns. Ask the sample size of your own numbers before you write them down.
- **T2. The far-and-idle think rate** (the predecessor's write-up, `archive/round16/brains.md` *Round-17 candidate*):
  a rate below idle (start at 1/s; price 2/s and 1/s) for a unit with no known enemy within `LOD_RADIUS`, no order in
  flight and no element call pending; wakes at once on the existing triggers; **never applies to the player's own
  units**. OFF by default behind a variant/switch; the default path's baseline UNMOVED and `ai-parity` identical with it
  off — prove both. **"Off camera" is expressed in simulation state or not at all**: a decision that reads the render
  camera makes the fight depend on where he looks, breaks recordings, replays and lockstep, and is exactly the class of
  input sim is hunting on the Sumps this round. If only the camera can say it, drop the condition and price the lever
  without it.
- **T3. The three execution-side levers the predecessor named**, each its own switch, OFF by default, priced on T1's
  table: the planned-reverse (k-turn) check every 12 ticks instead of 6 (~28 of ~86 navmesh queries a tick); chord
  checks at one sample instead of two; ORCA against four neighbours instead of six. Then anything the profile shows
  bigger that they missed: `execute.move` is 4.6 ms — what in it must run every tick for a unit that is stationary,
  holding, or following a straight leg with nothing near? An execution lever for **stationary** units may be an
  equality (nothing to move is nothing to compute): prove equality with the baseline over 8 seeds × 3 maps and it ships
  on your call; anything short of equality is a lever for the page.
- **T4. The combination.** Levers interact (a slower think with a slower reverse check is not the sum). Price the two
  or three bundles you would actually recommend, on the same table, and say what each buys **in his frame**: tick ms at
  30 and at his ~51 vehicles on the laptop, and the vehicle count at which a locked 30 holds (10 at round 16's launch).
- **T5. The decision page.** One Artifact page (load `artifact-design`, `artifact-capabilities`; `db` for his taps;
  C15.2): per lever and per bundle — what it does in one plain sentence, the ms it buys on his laptop at his army size,
  what he could notice (in his terms: "a CPU squad far from the fight reacts up to 0.7 s later to something new"), the
  measured behaviour columns, your recommendation, a tap (ship / keep off). Send the link to the orchestrator. Nothing
  flips to ON without his tap.
- **T6. Equal-answer leftovers** (each ≤ ~1 %, ship on your call with the baseline UNMOVED): `AiTickCache._refresh`'s
  per-tick allies dictionaries, `build_situation`'s per-contact `duplicate()`, `WallContact.observe`, the nav repeats
  the profile counted (15.6 of 114 `nav.closest` calls ask a point already asked this frame; `nav.is_ready` gives the
  same answer between two nav syncs).
- **Stretch.** `scenario_cover`'s peeking-reload failure: find whether the scenario or the behaviour is wrong (red
  since round 15); a fix that changes a decision is declared and goes to the orchestrator as a baseline question
  (C17.1: yard is the round's one mover — yours would wait for its own slot). The native route: which of the
  profile's top lines is a pure function over plain arrays that a GDExtension could take (write it up with the µs; do
  not build it — the toolchain decision is the lead's and round 17 holds the HUD's native move for its own round).

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe). **The default path's baseline is UNMOVED by every commit** (`05df1d55ba49cde1`
until yard's CP1 is merged and announced, then the new line — merge `main` only when the orchestrator says so, and
never compare two arms across that merge: an A/B's two arms are always one tree, C17.2). `make determinism`. Every
number: commit, machine, load, workload, seeds, sample.

## Don't touch

`game/match/**`, `game/tank/**`, `game/combat/**`, `game/units/**` (sim) · `game/arena/**`, `arenas/**` (yard) ·
`game/theme/**`, `game/audio/**` (guns for audio; nobody else) · `mk/core.mk`, `mk/web.mk`, the `ai-perf*` /
`scenario_perf` targets of `mk/ai.mk`, `tests/ai_scenarios/perf_nominal.json` (ship) · `game/theme/fx/bench/**` and
`mk/fx.mk`'s perf targets (nobody: request a `perf-play` arm through the orchestrator). No balance table changes (C12.6).

## Waiting on the lead

- His taps on the T5 page.

## Status

_Updated 2026-10-03 by the brains worker (round 17). Branch `stream/brains`, launch tree `3713fdaa`._

### Plan (the order taken, and why)

1. **T1 + the levers' plumbing together** (one foundation): `BrainLevers` (`game/ai/brain_levers.gd`): every lever is
   a FEATURE of a brain variant, so the ladder can play it against the champion and any run picks it with
   `--green-brain=<id> --rust-brain=<id>`; the champion (`x5p`) has none, so the default path reads the defaults and
   runs the code it ran before. `l17i2` / `l17i1` (far-and-idle 2/s, 1/s), `l17k` (k-turn check every 12), `l17c`
   (chord midpoint only), `l17o` (ORCA against 4): each the champion plus ONE lever (`tests/test_ai_levers.gd` pins
   that). Reason for variants rather than a new `--brains-lever=` flag: the ladder already speaks variants, and a
   lever must be priced against the champion there.
2. **The harness:** `make ai-lever-ab LEVER=<id>` (cost: `BrainLevers.gate` flipped in 300-tick blocks inside one
   Sumps match, the first 30 of each block charged to neither arm; band + whole tick; early = before the first shot,
   fight = after; the think-LOD census `BRAINS_LOD`), `make ai-lever-behaviour` (`tools/ai_lever_price.py`: first
   fight-rate second, first shot, first kill, kills, shots, hits, thinks per bucket, per arm, over pre-named seeds),
   `make ai-ladder AI_VARIANTS=<id>`, `tactics-drills` / `ai-scenarios-check` / `nav-scenario-arms` with the lever on
   both sides, the K1 test. 300-tick blocks because a 1/s think is booked up to 30 ticks ahead: 30-tick blocks would
   charge one arm's bookings to the other.
3. T2, T3 priced on that table; T4 bundles; T5 the page; T6 equalities; stretch.

### Pre-registered (named BEFORE the first lever run; lesson 224)

- **Cost** (`ai-lever-ab`): his Sumps workload, Law v Condemned, BUDGET 4600 (~50 vehicles), 180 s, seeds **92721**
  (the round-16 workload) **and 4242, 5151** (unseen by any lever design).
- **Behaviour** (`ai-lever-behaviour`): Sumps, BUDGET 4600, 120 s, seeds **1701-1716** (16), every arm on the same
  seeds, the champion's arm run twice as the identical-md5 control.
- **Ladder** (`ai-ladder`): each lever variant against the champion `x5p`, `FIRST_SEED=1801`, the ladder's default
  armies and runs; acceptance = does not lose (a loss beyond the ladder's own noise is a behaviour cost on the page).
- **Default-path proof on every commit**: sim baseline `05df1d55ba49cde1` UNMOVED, `make ai-parity` digest identical
  to round 16's `cf50ef2bbf8a422fe00150d382e5a956`. **The baseline runs on foundry only** (no containers; the
  orchestrator, 2026-10-03: yard's CP1 leaves it unmoved too, so the line is `05df1d55ba49cde1` all round), so every
  equality claim (levers OFF, T3's stationary equality, T6) is ALSO proven by `make ai-parity PARITY_MAPS=sumps` (the
  map he plays) against the launch tree's digest.
- **Machine:** builder0 is a hybrid i5-1345U (0-3 P-cores, 4-11 E-cores; ship's lead, not yet measured). Cost is by
  alternation inside one process; ms meant for his page are taken pinned (`LEVER_PIN=0-3`), each run's load stated.

### Done

**Green commits** (`make remote T=check`, the wrapper's own line):

| commit | check | tests | sim baseline | determinism | ai-parity |
|---|---|---|---|---|---|
| launch `3713fdaa` | exited 0 | 1915/0 | `05df1d55ba49cde1` | `762a0576f944f5b7` | yard+terminus `0095f2cf…`; + Sumps `d461fb2f9180e5a5a8012b7d01fa6dac` (24) |
| `29f7578d` (levers, census, lazy_allies) | exited 0 | 1920/0 | unmoved | `762a0576f944f5b7` | `0095f2cf…` = launch, 16/16 rows identical |
| `b9a0d90e` (split A/B) | exited 0 | 1921/0 | unmoved | `762a0576f944f5b7` | **`d461fb2f…` = launch, 24/24 incl. the Sumps** |

scenario_perf NOT JUDGED on all three (loaded, 1.81-1.85x): ship's this round.

**The parity reference moved before this round, not on this branch:** round 16's `cf50ef2b` is not what the launch
tree gives (`0095f2cf` on the same yard+terminus matches). `git diff 1af40b4b 3713fdaa` touches no ai/sim path
(game/ui, game/theme, game/control only), so the cause is unnamed; `ai-parity` at `1af40b4b` is queued to name it.
Every equality on this branch is judged against the LAUNCH tree's `d461fb2f`.

**T1, the harness: two lessons from the first runs.**
1. *Whole-block alternation cannot price a decision lever.* `LEVER_MODE=levers` (300-tick blocks of the whole army,
   `29f7578d`, builder0 pinned 0-3, Sumps 92721, 50 vehicles) read l17i1 **+15.9 %**, l17i2 +3.8 %, l17c +8.7 %, l17k
   **−12.9 %**, l17o **−16.4 %**, for levers that touch ~2 % of the work (the census: far-idle is 257 of 18 600 thinks).
   The fight ends by elimination in ~80 s, so each arm got ~4 blocks, and the cost falls as units die: the trend
   between blocks swamped the levers.
2. *The split A/B* (`LEVER_MODE=levers-split`, the default): the lever ON for half the units (by a hash of the unit's
   name) and OFF for the other half in the SAME ticks, halves swapped every 300-tick block, the first 30 ticks of
   each block uncharged, each controller's wall time charged to its half (BRAINS_AB_SPLIT, µs per unit-tick). A
   null control (the champion through the same split) is queued to give the noise floor.

**First split prices** (`b9a0d90e`, builder0 pinned 0-3, load 0.6-2.9, Sumps seed 92721, Law v Condemned, BUDGET
4600 = 50 vehicles; N = 1 seed, so NOT yet a price; the "early" phase is ~145 ticks of spawning, too short to read):

| lever | in the fight: µs per unit-tick ON / OFF | saved | at 50 units |
|---|---|---|---|
| l17i2 far-and-idle 2/s | 207.6 / 206.8 | −0.4 % | −0.04 ms |
| l17i1 far-and-idle 1/s | 193.9 / 195.0 | 0.6 % | 0.06 ms |
| l17k k-turn every 12 | 191.3 / 194.8 | 1.8 % | 0.18 ms |
| l17c chord midpoint | 176.4 / 176.8 | 0.3 % | 0.02 ms |
| l17o ORCA against 4 | 147.0 / 136.8 | **−7.4 %** (costs more) | −0.51 ms |

**What the census says about T2 on his Sumps workload** (`ai-lever-ab`, BRAINS_LOD, 50 vehicles, 180 s): the first
unit reaches the fight rate at tick ~114-126 (≈ 4 s), the first shot at 5.6-6.2 s, and of ~90 000 unit-ticks ~80 %
are at the fight rate, ~12 % near, ~8 % idle. **There is almost no "everyone travelling" phase on the Sumps CPU v CPU**
— the armies meet within seconds — so a far-and-idle rate has little to act on there. His skirmish is different (his
own units hold until ordered and are exempt); that is priced on his path next (`ai-ab-play LEVER=`).

**The parity drift, closed** (orchestrator accepted): `1af40b4b` gives `0095f2cf` on today's builder0 with the same
tool, arguments and 16 matches, so no tree change moved round 16's `cf50ef2b`. A READING (not re-run): `cf50ef2b` was
recorded on another machine (the laptop's glibc 2.39; MATCH_RESULT's state hash is glibc-dependent, trip-up 63). A
parity digest is a per-machine reference; `tools/ai_parity.py` now prints the host and glibc on the DIGEST line.

**T1's estimator, third version: BRAINS_AB_PAIRED** (`127e8f66`). The unpaired split read a NULL control (the champion
through the same split) at +1.5 % and −0.7 % on two seeds, and the levers at ±2–3 %: which units fell in which half
moved more than the levers. The paired estimate charges each unit against ITSELF (its own OFF minus ON cost per
unit-tick, weighted by the fewer of its two counts), with the standard error from the spread across units.

**The parts on the Sumps, by order type** (`127e8f66`, builder0 pinned 0-3, seed 92721, 3102 ticks, ~31 controllers a
tick; ms a tick): move 3.75 (of which `move_to` moving 3.34 on 21.4 units = **156 µs a unit**, `move_to` standing 0.44
on 3.3 = 133 µs, `stop`/`face` 0.05 on ~6 units = **6-12 µs**), situation 1.97, weapon 1.38, nav.closest 0.85 (64
calls), path 0.82, avoid 0.81, decide 0.81, chord 0.75 (15.8 calls), act 0.50.
- **T3's "stationary units" question, answered: there is nothing to buy.** A parked unit (`stop`, `face`) already
  costs 6-12 µs a tick, because Movement skips driving it. The expensive "still" units are `move_to` orders not
  moving (blocked, arriving): they run the whole route follower, and an equality cannot skip that.
- **The chord lever was aimed at the wrong sample.** The midpoint refused **0 of ~49 000** chords; every refusal
  (0.3 a tick) was the END sample. "Midpoint only" (the first `l17c`) meant "never refuse a chord". `l17c` now probes
  the end only (`ec31e419`): on this workload its answers would be the same as both samples, and it saves one query
  per chord.
- **A lever the profile shows bigger than the four named: `l17s`** (`far_exec_stride` = 2): a CPU unit with nothing in
  reach runs its whole controller every other tick (the hull keeps its last command and still moves every tick; a new
  order or element call runs it at once; never the player's units). The round-5 `brain_stride` machinery, per unit.

**His skirmish path is a different workload** (`ai-ab-play LEVER=l17i1`, builder0 with a display, perf-play's flags,
~51 units, 6138 ticks, the measured window ends long before the match does so the kill cam never enters it): the CPU
side spends ~2/3 of its unit-ticks idle or far (far_idle 53 728 + idle 54 741 vs fight 48 561), his own units mostly
in the fight or holding. **l17i1 there: 4.28 % ± 1.83 % of the brains (paired, 51 units), ~0.40 ms a tick on
builder0.** On the Sumps CPU v CPU the armies meet within ~4 s and far-idle has little to act on.

**T1's table, cost on the Sumps** (BRAINS_AB_PAIRED, fight phase; `ec31e419` code for every arm, builder0 pinned to
P-cores 0-3, Law v Condemned, BUDGET 4600 ≈ 50 vehicles, 180 s, 90-tick blocks, first 30 uncharged; % of the brains'
controller time per unit-tick; mean of 3 pre-registered seeds 92721/4242/5151 ± its pooled s.e.):

| arm | 92721 | 4242 | 5151 | **mean ± s.e.** |
|---|---|---|---|---|
| x5p (NULL control) | −0.77 ± 1.36 | −0.27 ± 1.58 | +0.27 ± 1.42 | **−0.26 ± 0.84** |
| l17i2 far-idle 2/s | −0.73 | −1.77 | −1.53 | **−1.34 ± 0.65** |
| l17i1 far-idle 1/s | +0.07 | +2.52 | −0.59 | **+0.67 ± 0.71** |
| l17k k-turn every 12 | +1.24 | +0.76 | −0.51 | **+0.50 ± 0.80** |
| l17c chord end only | +1.65 | +2.08 | +1.88 | **+1.87 ± 0.82** |
| l17o ORCA against 4 | +0.07 | −0.01 | −0.94 | **−0.29 ± 0.65** |

Reading: on the Sumps CPU v CPU, only the chord lever is clearly above the null; the rest are within one or two
standard errors of zero. The armies meet in ~4 s, so the far-idle levers have ~8 % of unit-ticks to act on.

**Stretch 1, `scenario_cover::test_peeking_while_the_enemy_reloads_takes_fewer_hits` (red since round 15): the
BEHAVIOUR is wrong, not the scenario.** A tick trace of the duel (laptop, `ec31e419`, a temporary probe, not
committed): x3 and x4 both take 4 hits from the gun's 4 shots in 30 s. x4's bait goes `out` while the gun is LOADED
(`sync_reload` 1.00), the gun turns onto it and fires ~35 ticks later, x4 switches to `back` on that tick, and the
shell lands **14 ticks** later with x4 still in its sight; x4 is out of sight only ~60 ticks after the shot. Every
bait is a hit, and x4 never shoots inside the reload window it baited for (its 4 shots = x3's 4). The bait assumes
the duck beats the shell; at ~45 m it cannot. The fix is a decision change (peek only while the enemy gun reloads,
which AiTickCache already estimates, or bait only when the shell's flight time exceeds the time to break line of
sight). The champion `x5p` has `reload_windows`, so it moves parity and very likely the foundry baseline: **a declared
behaviour change for its own slot (round 18 or after CP1 by the orchestrator's word), not done here** (C17.1).

**Stretch 2, the native route (a write-up, nothing built; the toolchain is the lead's call).** From the Sumps parts
profile (`127e8f66`, builder0 pinned, 50 vehicles, ms a tick and µs a call), the lines that are pure functions over
plain numbers and could move to a GDExtension with the same answers:

| line | ms/tick | µs/call | pure over plain arrays? | note |
|---|---|---|---|---|
| ORCA `Avoidance.solve` (+ `neighbours`) | 0.37 (+0.21 refresh) | ~23 | **yes**: positions, velocities, radii as floats; a 2-D linear program | the cleanest candidate; the neighbour grid is packed arrays already |
| `Steering.drive_toward*` + the k-turn arc sweep | 0.51 (`steer.drive`) | ~22 | the math yes; the k-turn sweep calls the navmesh per sample (already native) | most of `steer.drive` is the navmesh queries, so native buys the arithmetic only |
| `CoverMap` line walks (`los.cover_computed`) | 0.22 | ~7 | yes: a grid walk over a packed occupancy array | |
| `TankBrain.decide` | 0.81 | ~130 per think | **no**: pure, but over Dictionaries (the situation) | a native port needs a typed situation first; the biggest single think line |
| `build_situation` (`situation`) | 1.97 | ~320 per think | no: physics and navmesh queries, Dictionaries | |
| `nav.closest`, `nav.chord` | 0.85 + 0.75 | 13 / 48 | already native (NavigationServer3D); the GDScript is the call overhead | |

Reading: the pure-and-plain lines add up to ~1.1 ms of ~9 ms of brains a tick on builder0; a 10-30x native speed-up on
them is ~1 ms, about the same as the best lever on his path, with no decision changed. The big lines (situation,
decide, the route follower) are Dictionary-shaped and would need a data-layout change first.

### Questions for the lead

- None yet.

### Requests to other streams

- None yet.
