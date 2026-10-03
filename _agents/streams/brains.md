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
  to round 16's `cf50ef2bbf8a422fe00150d382e5a956`.

### Done

_(nothing reported yet: the launch check is queued on builder0 behind four other streams' checks)_

### Questions for the lead

- None yet.

### Requests to other streams

- None yet.
