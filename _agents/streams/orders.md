# Stream: orders (a squad that has arrived isn't in the way; squads deploy without shuffling)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 36** (C36.1, CP36.1,
> C36.4, C36.6) and in *Round 35*: R35.17, R35.68, R35.72, R35.74, R35.77 (X3b and its bar lesson), the D3/D4 rulings. Then your
> round-35 brief `streams/archive/round35/orders.md` (its Status is the close-out, with eight traced round-36 candidates) and
> `game_design.md` *Round 34, his playtest words*, *Round 35: found during the round, for round 36*. Evidence on `round35/orders`:
> `references/round35/orders/` (x3b-pass-dev-a7cd0fbc3, x3b-body-builder0-c28901b14, x3c-crossing-halt-detours.md, d2-main-1a18dd278).
> **You own:** `game/control/**` (except manoeuvre's additive fields in `screen_playtest.gd`), `tests/test_control*.gd`,
> `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`; in `game/tactics/element_plan.gd` the deploy-step and halt-lay
> functions (merge note); `game/tactics/deploy_passers.gd`; the R35.74 hook in `game/tactics/element.gd` (one guarded line);
> test_tactics_body's arrival line (R35.68). Everything else in brains' paths needs a grant (C36.6).
> **Model:** Opus. **Machine:** builder0 (C36.1); light runs on either builder.

## The lead's direction

His round-34 words (verbatim, game_design.md): *"How can we get behavior closer to starcraft…"*: squads sent together arrive and
stand where he clicked. His round-34 answer: **"Yes, use the deploy step"**; his round-35 answer: **the gate deal ON** ("clearly
awesome"). For round 36 he chose "use the agents' list" (2026-10-20).

What he will notice: his second or third squad no longer stops behind a squad that has just set up across its street; a squad
deploys without its wing crews driving round their squadmates; nobody drives a 20–30 m loop to reach a seat 10 m away; several
squads clicked to one point end up around the click, not pushed away from it.

## Where things stand

- **On main:** D1 the deploy step ON, D6 every squad follows a shift-clicked route, D5 the gate deal ON. D3/D3b packing and D4
  minimax seating are on main OFF (parked, readings in the archive).
- **X3b DEPLOY_PASS** (`round35/orders` `a7cd0fbc3`, `--deploy-pass=on`, OFF, unmerged): the cause is pinned (body stage s1: an
  arrived Hunters2_3 herringbone seat 1.9 m into the Sirens' lane, Sirens_1 held 9+ s) and the remedy works where it jams (s1 24.0 ->
  18.1 s, builder0 dev seeds), but the body stage jams in 1 seed of 12, so no series line clears its noise (R35.77). Judged seeds
  5101–5124 are UNSEEN; keep them so.
- **X3c** (the Crossing's seats reached only by a detour): design note on `round35/orders`; the controls hand the deploy a reached
  `halt_at` (navmesh test at order time); ElementPlan unchanged.

## Backlog (in order)

1. **Carry over (C36.1):** merge `round35/orders`'s X3b code (OFF) and tooling onto your fresh branch (read `git diff
   main...round35/orders` first). After CP36.1, `git merge main` when told.
2. **O1 the lab stage (C36.4):** a stage under `tests/control/` that builds an arrived herringbone across another squad's lane
   deterministically (the s1 geometry, fixed, both paths), with the jam's own counter. It is X3b's DECIDING workload. File X3b's bar
   in workstreams *Bars (round 36)* before any number: deciding = the lab stage (base jams, ON doesn't, by a stated margin); guards =
   the body stage's PAIRED mean on non-jam seeds (≤ +1.0 s) with a +5 s per-seed cap, on 5101–5124; far bank 0 in every orders cell;
   `test_control_scale`'s 3-tick response. A pass ships ON (symmetric; the deploy step reaches CPU elements, so attribute any moved
   sim-baseline map with the switch off).
3. **O2 the deploy move across a street (the twitch, D4's trace):** a wedge wide across a street re-forms into a herringbone along
   it, so wing crews drive past their squadmates. Trace on the probe's street cells first, a design note to the orchestrator, then a
   bar (twitch worst and the deploy move's length, guards all-in and far bank).
4. **O3 the reached halt (X3c's note):** `REACHED_HALT` behind a switch, the bar shape from the note (Crossing cells + the probe's 24
   cells, fresh seeds), `test_control_scale` re-read.
5. **O4 packing toward the click (R35.43's new objective):** pack toward the click first; treat arrival overlap as transient (each
   squad deploys when ITS crews are in). Design note first.
6. **Stretch:** a click right at a bridge mouth can seat a crew past the deck (deck_clear covers shifted legs only); `uncross_paths`
   on a queued screen (untraced).

## How to verify

Tests and the lab stage first; `make quick-remote`; one full check at a time a builder; probes and series on fresh seeds; every
number with commit, machine, workload, n. `make orders-probe-shots` (arrival and +5 s, desktop and phone) looked at for every
5-squad click cell you change. Smoke: `make skirmish ARENA=locks`, three squads to one point, then two more down the same street.

## Don't touch

Manoeuvre's and traffic's paths, brains' paths beyond your grants (C36.6), `native/**`, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### O1 VERDICT: X3b CLOSES "NO WORKLOAD" (bar as filed; builder0 light lane, native, `61b6181e2`, 96 runs, NATIVE on in all)
- `make native herringbone-lab`, 32 fixed cells x {off, on, nostep}, n 1 a cell a arm (the stage is deterministic):
  **jam cells (off >= nostep + 3 s): 0 of 32** (needed >= 3). The arrived herringbone at s1's corner does not jam the
  Sirens on builder0 in any of 32 geometries; the deploy step is FASTER than the old settle on mean (nostep - off +1.94 s;
  in 2 cells the settle never got the Sirens in within 40 s).
- PASS where it acts (pass_waits 1 in 26 of 32 cells): on - off **+1.53 s mean, 5 cells over +5 s, worst +15.6 s**: the held
  deploy fires ~12.5 s in, in the middle of the passing traffic, instead of ~6 s, before it. The lab guard fails too.
- Table: `references/round36/orders/x3b-lab-builder0-61b6181e2/` (+ the laptop design sweep's lines, seen before the bar).
- **Reading:** R35.17's +6.1 s was one chaotic draw of the body stage (1 seed of 12), not a property of the geometry.
  DEPLOY_PASS stays OFF; recommend deleting it (code, hook in element.gd, test) at the round close. No series run;
  5101-5124 stay unseen. test_tactics_body's line (off + 8.1 s) stays as is (it is brains' file and the line still holds).

### O2 trace (laptop GDScript, seed 34 = the dev seed, main + the probe's new deploy columns, the 6 click cells, 24 squads)
`references/round36/orders/o2-trace-laptop-s34/rows.txt`. Per squad: the deploy's worst leg as seated, the best possible
seating of the same seats (minmax), and the same halt with its depth along the heading halved (compact):
- The herringbone is 33-48 m deep for 4-5 crews ((n-1) x 0.8 x spacing); the travel wedge 27-39 m wide. Every twitch over
  20 m (Terminus 5 sq4 31.3, Locks 5 sq2 26.5, Crossing 3 sq1 25.2, Locks 5 sq4 21.3) is a squad with halt depth >= 33 m.
- Two different causes: **seating** (Terminus 5 sq4: leg 47.4 m as seated v 19.2 best seating: D4's minimax case) and
  **shape depth** (Locks 5 sq4: 37.1 / 30.8 best seating / 18.8 compact; Locks 5 sq2 16.4 -> 7.3 compact; Terminus 5 sq2
  18.6 -> 7.4). Legs rarely drive THROUGH a squadmate (2 of 24 within 4 m): the move is long, not crossed.
- Design note to the orchestrator next.

### Plan (worker, 2026-10-20)
1. C36.1 carry-over: DONE `a80bb28ab` (round35/orders's X3b code OFF + tooling + evidence, paths checked out exactly; main had
   not touched them since the branch point d85e395d4).
2. O1 lab stage: built `61b6181e2` (`make herringbone-lab`, `tests/control/herringbone_lane_stage.gd`), bar FILED in
   workstreams *Bars (round 36)* before any builder0 number. builder0 light native run in flight.
3. O2 the deploy move across a street: trace on the probe's street cells, design note, bar.
4. O3 the reached halt (`REACHED_HALT`, X3c's note).
5. O4 packing toward the click: design note first.
6. Stretch: the bridge-mouth click; `uncross_paths` on a queued screen.
Choice recorded: the lab's cells are a GRID of fixed geometries (Sirens lead x Hunters2 goal offset), not one cell: one
deterministic cell is still one chaotic draw (R35.77's lesson), a grid shows whether the jam is a property of the geometry.

### O1 (2026-10-20)
- **Laptop GDScript design sweep** (stage uncommitted on `a80bb28ab`, 32 cells x {off, on, nostep}, n 1 a cell a arm; seen
  BEFORE the bar was filed and named in it): the herringbone jams the Sirens (off >= nostep + 3 s) in **1 cell of 32**; PASS
  on - off on the 31 non-jam cells **+1.17 s mean, 4 cells over +5 s (worst +13.2)**: a held deploy fires ~12.5 s in, in the
  middle of the passing traffic, instead of at ~6 s before it. In 3 cells the NO-STEP arm never got the Sirens in (the old
  settle jams too). Reading on the laptop: the arrived herringbone is rarely the jam, and PASS costs where it isn't.
