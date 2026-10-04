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

- His taps on the T5 page: **https://claude.ai/artifact/To29gP1bdc8Xextr6P6UWV** ("Brains Lever Prices"; `db`
  collection `taps`, one document per lever id: `{lever, choice: ship|keep_off, at}`). Published 2026-10-03 19:32 PDT on
  LAUNCH-TREE numbers with builder0-derived laptop projections (laptop arms pending, the orchestrator's). `db` last
  read: 2026-10-03 19:32 PDT, empty. Private until shared from the page's Share menu.

## Status

_Updated 2026-10-04 03:19 PDT by the brains worker (round 17). Branch `stream/brains`; **merged to main as `af244ec0` from green
`2657db11`** (every lever OFF; parity = main's own digest). Everything after it on the branch is docs._

### REPORT (read this first; the evidence is the log under *Done*)

| item | state | the answer |
|---|---|---|
| **T1** the price list's frame | DONE | `BrainLevers` (levers as `l17*` variant features, OFF for the champion); cost by the **paired split A/B** (`ai-lever-ab`, `ai-ab-play LEVER=`) with a NULL control; behaviour (`ai-lever-behaviour`, incl. his asymmetric shape), driving (`ai-lever-drive`), scenarios + drills (`ai-lever-scenarios`, both sides and CPU-only), ladders at his size beside a twin NULL ladder; the think-LOD census. Method in `unit_ai.md` §8. |
| **T2** far-and-idle think rate | PRICED | 1/s: +4.3 ± 1.8 % of the brains on his skirmish (1 run), +0.7 ± 0.7 on the Sumps; pace unchanged; ladder 9-7 at his size. 2/s: inside the noise. Never his units; wakes on every trigger; no camera input. |
| **T3** execution levers | PRICED | chord at the END sample (the midpoint never refused 1 of ~49k): +4.5 / +1.9 %; k-turn every 12 and ORCA 4: inside the noise. **Stationary units: nothing to buy** (6-12 µs a tick already). Found bigger: **`l17s`, a far CPU unit's controller every other tick**: 12-20 % on his skirmish, nothing when the CPU is in contact from the start; two defects found by the scenario counts and fixed (`572e55a6`, `1e15dfb0`). |
| **T4** bundles | PRICED | **`l17b2`** (far-idle 1/s + chord end + k-turn 12 + l17s): his skirmish 3.5 / 23.5 / 26.6 % (launch tree, 3 seeds) and 23.3 % on the turned Sumps (1 run); Sumps 8.5 ± 1.2 %. Projected **0-6 ms off his 25 ms tick at 30 vehicles, ~4 ms on average; a locked 30 to ~13 vehicles from ~11**. Laptop arms: the orchestrator's (running at `984b5c38`). |
| **T5** the decision page | PUBLISHED, WAITING ON HIS TAPS | https://claude.ai/artifact/To29gP1bdc8Xextr6P6UWV (v11): 7 cards with taps open, `l17b1` closed (round 18); recommendation: **ship the bundle**. v1-v9 never rendered (a generator defect, fixed and disclosed). `taps` last read 2026-10-04 03:19 PDT: empty. |
| **T6** equal-answer leftovers | DONE | `lazy_allies` shipped (3.6 % of the brains, an equality: the A/B's state hash = the plain run's; parity unmoved). `WallContact.observe` measured at ~3 % and NOT an equality (yard's and nav's counters read it): round 18. The per-contact `duplicate()` is not worth a layout change; the nav repeats were round 16's. |
| **Stretch 1** `scenario_cover` reload red | DIAGNOSED, ROUND 18 | the behaviour is wrong (the bait shows itself to a LOADED gun and cannot duck the shell); rules A/B below; the orchestrator decided round 18. |
| **Stretch 2** the native route | WRITTEN UP | ~1.1 ms of ~9 ms of brains is pure maths over plain arrays (ORCA, steering arithmetic, cover-line walks); the big lines are Dictionary-shaped. |

**Decisions (mine, with the reason):** levers as variant features, not a flag (the ladder speaks variants); the split
A/B with a paired estimate (whole-block alternation cannot price a decision lever); the chord lever re-aimed at the
end sample (the midpoint never refused); a far stride never for an ordered or unrated unit, and a re-rate on every
intel tick (the two defects); finishing T5's launch-tree series before merging main (C17.2); `l17t` (stride only on
straight legs) not offered (it gave back most of the saving).

**Questions for the lead:** only his taps on the page. If he ships a lever, its default flips in a one-line commit
(the champion profile gains the feature), with its own check and parity, and the lever-ON digest becomes the
declared reference.

**Requests to other streams:** none open (sim's windowed fork was the kill cam, not the brains; yard's k-turn outline
item and the reload-window fix are round 18 by the orchestrator's word).

**Known issues:** `scenario_cover::test_peeking_while_the_enemy_reloads_takes_fewer_hits` (red since round 15: the
behaviour, round 18). The three skirmish seeds before the turn disagree beyond one run's ± (the saving depends on the
fight); the turned-Sumps rows are one run each.

**What to playtest (the lead):** nothing changes until a tap. To feel the bundle before tapping:
`make skirmish` from a checkout of main with `--green-brain=l17b2 --rust-brain=l17b2` added to the skirmish's flags
(his own units are exempt from the far-unit parts; the CPU's far units steer at half rate).

**Next steps (round 18):** a correct "is this unit really idle" predicate if the stride is shipped and extended; the
reload-window fix (rule A first); the k-turn outline side samples (sketched below); counting wall contacts without
allocating; the small bundle `l17b1` at his army size.

**Merge notes:** all edits in brains' paths (`game/ai/**`, `tests/test_ai_levers.gd`, `tests/nav/lever_drive_probe.gd`,
`mk/ai.mk` minus the perf targets, `tools/ai_lever_price.py`, `tools/ai_lever_drive.py`, `tools/ai_parity.py`) plus
docs (this brief, `unit_ai.md` §8, `streams/references/round17/brains/`). New scripts with their `.gd.uid`:
`game/ai/brain_levers.gd`, `tests/test_ai_levers.gd`, `tests/nav/lever_drive_probe.gd`. New flags (no effect unless
given): `--brains-census`, `--brains-ab-run=levers|levers-split`, `--brains-ab-block=`, `--brains-ab-skip=`. Lent files
(`scenario_perf.gd`, the `ai-perf*` targets, `mk/tactics.mk:64`) are main's, untouched here.


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
| **`6a926d4b`** (levers incl. both stride fixes, l17t, bundles, drive probe) | exited 0 | 1924/0 | unmoved | `762a0576f944f5b7` | **`d461fb2f…` = launch, 24/24** (builder0, glibc 2.43) |
| **`2657db11`** = the above + `main-checked` `9a377eaf` merged (CP2, guns' sound, ship's check) | exited 0, **23 targets ALL JUDGED** | 2002/0 | unmoved | `762a0576f944f5b7` | **`55fba4d6…` = 9a377eaf's own, 24/24, same session** |

**MERGED to main as `af244ec0` (2026-10-04 ~02:18 PDT, the orchestrator) from green `2657db11`** (every lever OFF: the default path is byte-identical to `main`). His
tap later flips one default in a one-line commit (the champion `BrainVariants.CHAMPION`, or a new champion profile
carrying the tapped lever's feature).

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
  **Decided: round 18** (the orchestrator, 2026-10-03). Ready to pick up:
  - *Why it broke in round 15:* N5 (CP4) made a gunner lay before firing (up to ~1.6 s), so a bait that ducked on being
    seen never drew the shot; the rule became "stay out until the round is on its way, then duck"
    (`TankBrain._act` COVER_FIRE, `shot_at`). At duel ranges a cannon shell lands ~14 ticks after leaving, and a hull
    needs ~60 to break sight: "duck when it's on its way" is a guaranteed hit.
  - *Rule A (try first): no bait; peek only while the enemy gun is reloading* (`contact.gun_ready_in`, AiTickCache's
    estimate, already computed) *or after it fired at someone else.* Smallest change (the bait branch off). Expected on
    the scenario: x4 ≈ x3 (~4 hits / 4 shots in 30 s, because this lone gun only fires at x4, so its window only opens
    after it has hit x4). The test as written (`timed < plain`) would STILL fail; it should then assert "no more hits
    than x3, and every peek it takes starts inside a window", plus a second stage with TWO targets (a teammate draws
    the shot), where rule A should show fewer hits.
  - *Rule B: bait only when the shell's flight time exceeds the time to break line of sight* (flight = distance /
    `Shell.speed`, break = the hide spot's distance / PEEK_SPEED). At 45 m against a cannon it never baits, so it reduces
    to rule A there; it keeps the bait against slow or arcing guns at range. Second, if A loses a ladder.
  - *His side of it:* the bait applies to ANY visible contact, and the champion `x5p` carries `reload_windows`, so
    **CPU units bait themselves into free hits from his units in a skirmish** (and his own units' brains do the same
    when they fight from cover). That is a difficulty question as well as a bug: fixing it makes the CPU harder.

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

**T1's table, behaviour on the Sumps** (`ai-lever-behaviour`, 16 pre-registered seeds 1701-1716, both sides on the
arm, Law v Condemned, BUDGET 4600, 120 s; `127e8f66`/`ec31e419` code, builder0; mean ± s.e. over the 16 matches;
first fight-rate second 4.3 in every arm). **Control: the champion's arm, run in two separate batches, is
byte-identical (digest `396f95bfd1abeb1bcae709887949bd51` both times).**

| arm | first shot s | first kill s | kills | shots | thinks (16 matches) |
|---|---|---|---|---|---|
| x5p champion | 6.8 ± 0.3 | 14.2 ± 0.8 | 28.1 ± 1.3 | 683 ± 56 | 399 532 |
| l17i1 far-idle 1/s | 6.7 | 14.9 | 29.6 | 765 | 386 186 (−3.3 %) |
| l17i2 far-idle 2/s | 6.7 | 13.8 | 27.8 | 713 | 391 135 (−2.1 %) |
| l17k k-turn 12 | 6.7 ± 0.3 | 14.2 ± 0.8 | 30.2 ± 1.8 | 780 ± 67 | 405 620 |
| l17c chord end | 6.5 ± 0.2 | 13.5 ± 0.8 | 27.8 ± 1.3 | 731 ± 54 | 408 300 |
| l17o ORCA 4 | 6.9 ± 0.4 | 14.1 ± 1.0 | 27.4 ± 1.7 | 760 ± 75 | 407 976 |

Reading: no lever moves the pace or the outcome of the Sumps fight beyond ~1 s.e. over 16 seeds (a mirror match
forks at the first changed decision, so "shots" swings ±60 per arm by itself).

**Which tree every row is on (C17.2):** every cost, behaviour, ladder, parity and parts row above was taken on this
branch, which has NOT merged `main` since the launch (`3713fdaa` + brains commits only), so all of them are the
LAUNCH tree's fights: yard's CP1 (`9314a2db`, merged to main 2026-10-03) is in none of them. After the orchestrator
announces the merge, the reference digest is re-taken and no row is compared across it. Yard's k-turn outline
question: decided round 18 (its count: turned containers raise no planned-leg contacts beyond the seeds' spread;
long hulls plant 16-58 a minute and scrape 300-500 a minute on BOTH layouts).

**Ladders, first pass: a NULL WORKLOAD for three of five levers** (`ai-ladder AI_VARIANTS=x5p,<lever>`, FIRST_SEED=1801,
the default `individuals` armies of 5-8 units, 16 matches each, builder0, `127e8f66`+). l17i2, l17k and l17o came back
**byte-identical to the champion** (both arms: 174 shots, 153 hits, 29 789 damage, 51 kills; 8-8): with a handful of
units, nothing is far and idle at 2/s, no wheeled hull k-turns, and no hull has more than four neighbours. Those 8-8s
carry no information (lesson 1: an arm that never selects its treatment is not a null result). l17i1 went 7-9
(different stats, so it acted), l17c 8-8 (178 vs 175 shots, so it acted barely). **Re-run at his size**: `cpu:balanced`
at BUDGET 4600 on the Sumps, same FIRST_SEED (`LADDER_BUDGET` / `LADDER_ARENA`, added for this), queued.

**The merge of `main` (announced 2026-10-03 16:46 PDT: merge `ddf710b2`, checked green): DEFERRED until T5's series
are complete, by choice.** Every queued cost, behaviour, ladder, scenario and skirmish-path job is a launch-tree
series; merging mid-series would split them across two trees (C17.2). Order: finish the series → publish T5 on
launch-tree numbers (every row says so) → `git merge ddf710b2` (taking ship's `scenario_perf.gd` and `mk/ai.mk` perf
targets) → check + re-take the reference parity digest on the merged tree. **Update 21:13 PDT: the announced hash is now
`90c289f2` (CP2, containers at strength B); merge that instead, after the orchestrator's laptop arms. (21:40 PDT: `main-checked` = `0cd42ebe`, CP2 + guns' sound +
ship's perf-refusal fix: the newest target. `mk/tactics.mk:64` is lent to ship; untouched here.) Then one arm of
the surviving stride lever on the CP2 Sumps (route scraping is already 449 → 583 a minute there at B, yard).**

**Yard's outline question, sketched so it can come forward in ~1 hour (NOT built; round 18 unless yard's
square/A/B count shows plant×kturn rising at B, then last, after T5, by the orchestrator's word).** The defect: the
k-turn outline (`Movement.KTURN_OUTLINE`, 10 samples in hull units) puts its side samples at ±0.5 and ±1 of the
half-length, i.e. **3.5 m apart on a 14 m rig**, so a turned box's CORNER can poke into the hull side between two
samples that both read clear (two samples 1.75 m either side read ~0.25 m off the mesh against a 1.6 m reach; the
point between reads ~2.0). The sketch, all in `game/ai/movement.gd`:
1. `_outline_for(frame) -> PackedVector2Array`: corners and end-centres as now, plus side samples at
   `x = -1 + 2k/n` for `n = ceili(2 * frame[1] / KTURN_SIDE_SPACING_M)`, `KTURN_SIDE_SPACING_M := 1.5` (14 m rig:
   10 side points a side instead of 2; a 6 m tank: 4), cached per `frame` (hull type), replacing the constant's use
   in `_outline_ok`, `_outline_offs` and `_lazy_start_at` (the lazy start array is indexed by sample, so it is sized
   from the same list).
2. The start tolerance (`off > from_start + 0.05`) is kept for a TRAILING sample only. A sample on the leg's leading
   end (`sample.x * _kturn_gear > 0`) must be within the clear reach, because "no deeper than it started" lets a
   leg begun against a box keep driving into it.
3. Cost: k-turn is ~53 of ~115 navmesh queries a tick on his path (round 16); with the cap and the lazy start
   (round 16) only the poses actually swept pay, and each costs (n_side − 2) × 2 more queries: about +60 % on a
   rig's sweep, +0 % on a tank's. A cheaper variant asks the extra side samples ONLY when the two neighbouring
   coarse samples are both within ~1.0 m of the reach (the only case a corner can hide between them): price both.
4. Proof: yard's turned-kerb rig drive (`test_nav_back_and_fill` on the Terminus with the avenue boxes turned) as the
   regression test, `make container-contacts` plant×kturn square/A/B before and after, `nav-scenario-arms`, parity
   moves (declared), the foundry baseline expected unmoved (no rig k-turns there; to be confirmed by the check).

**T1's table, cost: his skirmish path and the new rows** (launch tree; `ai-ab-play LEVER=` = perf-play's flags, his
window, builder0 with a display, unpinned (a display run), ~51 units, ~6 100 ticks, the measured window ends long
before the match; `ai-lever-ab` = the Sumps, pinned 0-3, 3 seeds; BRAINS_AB_PAIRED, % of the brains' controller time
per unit-tick ± s.e.):

| arm | his skirmish (1 run) | the Sumps (3 seeds) |
|---|---|---|
| x5p NULL control | +2.26 ± 2.51 | −0.26 ± 0.84 / −0.14 ± 0.92 (two batches) |
| l17i1 far-idle 1/s | **+4.28 ± 1.83** | +0.67 ± 0.71 |
| l17i2 far-idle 2/s | +0.88 ± 2.02 | −1.34 ± 0.65 |
| l17k k-turn every 12 | +0.87 ± 2.22 | +0.50 ± 0.80 |
| l17c chord end only | +4.52 ± 2.57 | **+1.87 ± 0.82** |
| l17o ORCA against 4 | +2.36 ± 2.62 | −0.29 ± 0.65 |
| **l17s far CPU unit every other tick** | **+19.99 ± 4.94** | **+4.18 ± 0.81** |
| l17b1 = i1 + k + c | +5.44 ± 2.74 | +4.28 ± 0.76 |
| **l17b2 = b1 + s** | **+28.88 ± 5.12** | **+8.79 ± 1.27** |

**T6 `lazy_allies`, an equality, priced:** `make ai-ab-match AB_SWITCH=lazy_allies` (launch tree + `2744ea33`,
builder0, Sumps 92721, 50 vehicles, 30-tick blocks): controller band 14 954 vs 15 516 µs a tick, **3.6 % saved**,
whole tick 3.7 %; the A/B run's state hash `c298b9ae42722210` = the plain run's. Shipped (it is in every check and
parity above).

**l17s behaviour** (the same 16 seeds, both sides on it): first shot 6.4 ± 0.2 s (champion 6.8 ± 0.3), first kill
14.9 ± 1.1 (14.2 ± 0.8), **kills 32.2 ± 1.0 (28.1 ± 1.3)**, shots 825 ± 68 (683 ± 56), thinks 368 077 (−7.9 %). The
pace is the same; the fights are somewhat bloodier (~+4 kills in 120 s, ~2.5 s.e.). Small-army ladder: **l17s beat
the champion 10-6** (it acted: 257 vs 222 shots). Big-army ladder queued.

**T6, the wall-contact instrument, measured and NOT built:** `c.wall_contact` 0.46 ms a tick over 50 calls (~9 µs a
hull a tick, ~3 % of the brains; `2744ea33`, Sumps, pinned). It walks `get_slide_collision_count()` and allocates a
`KinematicCollision3D` per contact every tick, for every hull. Skipping it is not an equality: yard's
`make container-contacts` and nav's probes read its counters (`Movement.state()`), and the k-turn leg reads
`touching`. A round-18 candidate: count the same contacts without allocating (PhysicsServer3D's motion result), proven
by the counters being identical.
**T6, the other leftovers:** `build_situation`'s per-contact `duplicate()` sits inside `s.contacts` (0.5-0.9 ms a tick
on 6.2 thinks, mostly the per-contact sight lines, not the copy): not worth a layout change at ≤ ~0.5 %. The nav
repeats the brief lists were round 16's (`closest_memo` answers 2.8 a tick now; `nav.is_ready` 0.04-0.07 ms a tick
since `ready_memo`): done.

**T5 page v2 (the orchestrator's review, 2026-10-03 ~19:40 PDT): every tap is CLOSED until its card's rows are in.**
(1) The recommended card had no behaviour price; now every card with a pending row has disabled Ship / Keep off and
says "Not ready to choose: its behaviour is still being measured". (2) The headline rested on ONE skirmish run (the ±
is across 51 units in one fight, not across fights): two more pre-registered seeds, 31337 and 4242, queued for x5p,
l17s and l17b2; the strip reads "~6 ms?" until they land. (3) Driving was not measured: `make ai-lever-drive`
(tests/nav/lever_drive_probe.gd) counts wall contacts by cause x driver, wedges, unsticks and k-turn legs per arm on
the same seeds; a 20 s local smoke (n=1, not a result) already shows l17s long-hull plant×kturn 201/min vs 55 and steer
scrapes 842 vs 540. **The kills that moved:** with both sides on l17s, all the extra kills are Law's (9.7 → 15.1 a
match; Law wins 6 of 16 vs 3; Condemned's kills 18.4 → 17.1): a faction-balance shift. His exact shape (Law on the
champion, Condemned on the lever) is queued as asymmetric arms (`PRICE_ARMS=x5p,x5p/l17s,x5p/l17b2`). (4) The bundle
card says which parts touch his units.

**T1's driving columns** (`make ai-lever-drive`, launch tree, `8ad0b7b1`+ code, builder0; Gangs War Rigs v Condemned
tanks, BUDGET 5200, elimination, 180 s cap, seeds 1-6, both sides on the arm; yard's units: long-hull wall-contact
ticks per minute; median/mean, and the paired median against the champion on the same seed):

| map | arm | plant × kturn | route scrapes (steer) | wedged units | k-turn legs |
|---|---|---|---|---|---|
| Sumps | x5p | 47.3 / 57.5 | 393 / 469 | 189 | 109 |
| Sumps | l17s | 51.0 / 47.8 (−1.4) | 663 / 596 (**+82**) | 127 (−51) | 107 |
| Sumps | l17b2 | 48.9 / 88.1 (0) | 586 / 618 (**+41**) | 128 (−83) | 84 |
| Terminus | x5p | 31.9 / 40.6 | 369 / 342 | 250 | 101 |
| Terminus | l17s | 13.0 / 39.4 (0) | 294 / 283 (**−43**) | 176 (−78) | 91 |
| Terminus | l17b2 | 48.8 / 46.8 (0) | 453 / 438 (−2) | 199 (−62) | 95 |

Reading: the 20 s smoke's alarm (plant×kturn 201/min) was noise; planned-leg contacts do not rise on either map.
Route scraping rises on the Sumps (+40..+80 a minute, about the size of CP2's own 449 → 583 there) and falls or holds
on the Terminus; fewer units wedge on both. **The stride survives the driving test, with the Sumps scrape rise on its
card.** The straight-leg variant `l17t` (+ bundle `l17b3`, `91d9c007`) is priced next to see whether it keeps the saving
without the rise.

**The straight-leg variant does not pay** (launch tree, `91d9c007`, builder0): on the Sumps driving series (seeds 1-6,
paired against the champion) `l17t` scrapes −23 a minute and `l17b3` −13 (the rise is gone), but on his skirmish path
`l17t` saves only **2.3 ± 2.7 %** of the brains (`l17s`: 20.0 ± 4.9) and `l17b3` **11.1 ± 2.6 %** (`l17b2`: 28.9 ± 5.1),
1 run each, 51 units paired. Far CPU units are rarely on a plain straight leg that nothing touches or deflects, so
gating the stride there gives most of it back. **The plain stride survives; its price is the Sumps scrape rise.** The
ladders at his size are spent on `l17s` and `l17b2`.

**His skirmish path, 3 pre-registered seeds** (launch tree, builder0 with a display, `ai-ab-play LEVER=`, ~49-51 units
paired each; load printed from the 31337/4242 runs on: 4.8-9.6 one-minute, 18-26 Godot processes on the box; the 92721
runs carry no load line): null x5p +2.26 / −1.66 / −0.43 %; **l17s +19.99 / +15.14 / +4.36 (mean 13.2)**; **l17b2
+28.88 / +18.83 / +18.41 (mean 22.0)**; each ± 2-7. The seeds disagree beyond one run's ±, so the page gives ranges:
the bundle 18-29 % of the brains, projected 4-6 ms off his 25 ms tick at 30 vehicles (mean ~4.8 ms).
**His setup, asymmetric** (16 seeds 1701-1716, his Law on the champion v the CPU's Condemned on the lever; Law wins of
16 / kills by Law / kills by Condemned a match): x5p 3 / 9.7 / 18.4; **x5p/l17s 2 / 9.7 / 19.6; x5p/l17b2 4 / 11.5 /
16.9**; x5p/l17t 5 / 11.1 / 18.1. His side does not die measurably more with the CPU on the lever. The Law-favouring shift
with BOTH sides on it came from Law's own units striding, which never happens to his.

**The scenario counts caught a defect in l17s (fixed at `572e55a6`; every earlier l17s / l17b2 row is the OLD
version).** `ai-lever-scenarios` (launch tree, both sides on the lever): drills `failures=0` for x5p, l17s and l17b2;
scenarios x5p 42 passed / 1 failed (the known reload-window red) / 3 pending; l17s 41/2/3 and l17b2 42/2/3, each adding
`scenario_cover::test_a_healthy_tank_near_a_wall_fights_from_cover` (hidden 0 % of 20 s vs 61 %, 0 returns to cover vs
2). Traced tick by tick (local probe, not committed): an unrated brain counted as "idle" and strided from tick 1; a
stride lasted until the next think after contact; and a strided unit skipped the intel tick where contact arrives, so
it noticed ONE tick late (tick 5 vs 4), which lost the cover fight. Control: the champion with its think phase shifted
by 1, 2 or 3 ticks keeps cover every time, so the lever caused it, not a knife-edge scenario. **Fix:** no stride before
the first rating; full rate on the tick the rating rises; a strided unit re-rates on every intel tick (a few distance
checks) and runs at once if the rate rose. The cover scenario with l17s now reads the champion's exact numbers (61 %, 3
shots, 2 returns). **Big ladders on the old version** (his size: `cpu:balanced` BUDGET 4600, Sumps, FIRST_SEED 1801,
16 games): l17s beat the champion **11-5** (379 kills v 301), l17b2 **13-3** (386 v 288): the lever made the CPU
STRONGER (a difficulty point for his card). Everything l17s / l17b2 is being re-taken on `572e55a6`.

**A second stride defect, caught by the re-run's scenario counts (fixed at `1e15dfb0`; the `572e55a6` rows are VOID).**
With `572e55a6` the cover scenario passed, but `scenario_elements::test_a_unit_fighting_from_a_formation_slot_stays_in_it`
failed for l17s and l17b2: an element member ended 88.3 m from its slot (champion 15.0 m). Traced: the unit carried an
attack ORDER, sat in the "idle_ordered" bucket for ticks 1-3, was strided there, and its shifted timeline chose FLANK
at tick 150 and drove 70 m out. **Fix: never stride a unit carrying out an order** (far-and-idle thinking had that rule
already). It costs nothing where the saving is: the censuses show CPU units carry no K1 order in his skirmish or on the
Sumps (only HIS units are in the ordered bucket). With l17s locally: elements 15.0 m (the champion's exact number),
cover 61 % / 3 shots / 2 returns (exact). For the record, the void `572e55a6` skirmish seeds: l17s 16.2 / 24.6 / −3.2,
l17b2 24.0 / 25.6 / 3.1. **Round r3 of the re-price runs on `1e15dfb0`:** check + three-map parity first, then
scenarios, 3 skirmish seeds, Sumps driving, behaviour (asymmetric + symmetric), ladders at his size with a
champion-vs-twin null ladder, the Sumps cost.

**r3's STOP RULE (set with the orchestrator before the results, 2026-10-03 night):** if r3's counts (scenarios,
drills, elements, cover; both sides on the lever AND only the CPU side on it) show a THIRD behaviour difference from
the champion, stop patching: write the stride up as a round-18 item with its three traces and what a correct "is this
unit really idle" predicate must cover; publish T5 with the stride marked "not offered: three defects found in
testing"; offer only what survives (far-idle 1/s, the shortcut check) at their honest, smaller price. And the strip
gives the saving's range INCLUDING its low end (on seed 4242 the stride bought ~nothing on both earlier versions),
names what differs about that fight, and projects ms from the range, not the mean. Each priced row says what ran
beside it (ship's closing list has the heavy slots tonight; one heavy job of mine at a time).

**r3's scenario counts PASS the stop rule** (`6a926d4b` lever code, builder0, 2026-10-04 00:06-00:26 PDT;
`ai-lever-scenarios`, all AI scenarios + battle drills): l17s both sides 43 passed / 1 failed / 3 pending; l17b2 both
sides 43/1/3; l17s CPU-only (`LEVER_GREEN=x5p`) 43/1/3; l17b2 CPU-only 42/1/3 + `scenario_perf` NOT JUDGED (loaded
1.80x). The one failure in every arm is `scenario_cover`'s reload-window test (red since round 15). Drills
`failures=0` in all four. No behaviour difference from the champion bar the known red.

**r3, his skirmish path, 3 seeds** (`6a926d4b` lever code; builder0 with a display; ~49-51 units paired; load at
start 2.5-10.9 one-minute, 2-30 Godot processes on the box, printed per run):

| seed | l17s | l17b2 | the CPU side's unit-ticks in contact (fight / all) |
|---|---|---|---|
| 92721 | +12.29 ± 3.96 | +26.56 ± 5.25 | ~47 % |
| 31337 | +19.29 ± 4.65 | +23.49 ± 5.52 | ~28 % |
| 4242 | **−1.75 ± 2.41** | **+3.52 ± 3.39** | **~85 %** |

**The saving tracks how long the CPU spends away from the fight.** On seed 4242 the CPU army is in contact almost from
the start and stays there (fight 33 208 v idle 4 031 unit-ticks), so there is no far, idle unit to act on. The page's
strip gives the range: from nothing to about a quarter of the brains, depending on the fight (bundle 3.5-26.6 %, mean
17.9; l17s −1.8-19.3, mean 9.9).

**r3 complete; T5 v5 published 2026-10-04 01:46 PDT with the two stride cards' taps OPEN** (every row in, after both fixes;
`6a926d4b` lever code, launch tree, builder0). Ladders at his size (`cpu:balanced` 4600, Sumps, FIRST_SEED 1801, 16
games, each seed four ways): **null control x5p v x5p_twin 8-8**; l17s v champion **10-6**; l17b2 **6-10**: both
within ~1 s.d. of even (binomial s.d. 2 wins in 16), so **the old version's 11-5 / 13-3 was the defect**. Sumps driving
(6 seeds, paired): l17s route scrapes **−2/min** (the old version's +82 is gone), plant×kturn −8; l17b2 scrapes +40,
plant 0; fewer wedged with both. Behaviour, his setup (16 seeds, Law champion v Condemned lever): Law wins 3 / 4
(champion 3); Condemned kills 17.8 / 17.6 a match (18.4). Both sides on it: kills 30.4 / 29.7 (28.1), first shot
6.5 / 6.7 s (6.8), thinks −3.9 % / −6.8 %. Sumps cost (3 seeds, paired, pinned 0-3): null −0.32 ± 0.87; **l17s +6.61 ±
1.11; l17b2 +8.50 ± 1.16**. The page recommends the bundle: 0 to ~6 ms off his 25 ms tick depending on the fight
(mean ~4 ms, projected; laptop arms pending). The other cards' taps stay closed until their scenario counts and
ladders at his size land (queued: never run, since the first chain was cut short). `taps` read 2026-10-04 01:46 PDT: empty.

**On the CP2 tree (the turned Sumps he plays; `9c34d49e` = `2657db11` + docs; builder0, load 6-8, 17-22 Godot
processes):** skirmish seed 92721 (1 run, 51 units paired): **l17s +20.44 ± 4.86 %, l17b2 +23.27 ± 4.86 %**. Sumps
driving (6 seeds, paired against the champion; champion route scrapes 514 / 549 a minute, cf. yard's ~583): l17s
scrapes **+37 (~7 %)**, plant×kturn −1.3; l17b2 scrapes **+11 (~2 %)**, plant −17.5; fewer wedged with both. The saving
holds on the map he plays (one run each; the three-seed range is still the launch tree's). The rubbing goes OPPOSITE
ways: the stride alone rubs MORE on the turned containers (+37, ~7 %, where the launch tree read −2), the bundle LESS
(+11, ~2 %, where it read +40). Each card says its own direction (page v8; the orchestrator's correction).

**The five other cards, on the CP2 tree** (`9c34d49e` code = `2657db11`; builder0; ladders at his size: `cpu:balanced`
4600, Sumps, FIRST_SEED 1801, 16 games): scenarios + drills clean bar the known red for l17i1, l17c, l17k, l17o, l17i2
(42/1/3, drills 0). Ladders v the champion: **null x5p v x5p_twin 7-7-2**; l17i1 9-7, l17c 8-8, l17k 10-6, l17o 9-7,
l17i2 7-9. Every one acted (its stats differ from the champion's), and none differs from even beyond the null's spread.

**A DEFECT IN THE T5 PAGE, versions 1-9: the cards most likely never rendered.** `tools`-side generator
(`brains_page_data.py`, scratch) spliced the data into the page with Python's `re.sub`, which turns the JSON's `\n`
escapes into real line breaks inside a JavaScript string: a syntax error, so the script never ran and a viewer saw the
headings only. No tap was possible on any earlier version (no buttons existed). Fixed in v10/v11 (a function
replacement; `node --check` passes; a run against a stub DOM renders all 8 cards with the right taps open). Lesson for
`orchestration.md`: execute a page's script once before the first publish; reading its source is not running it.

**T5 v11, 2026-10-04 03:18 PDT:** all seven measured cards' taps OPEN; `l17b1` closed (not measured at his size: round 18). The method
says which map each row is on. `taps` read 2026-10-04 03:18 PDT: empty.

### Questions for the lead

- None yet.

### Requests to other streams

- None yet.
