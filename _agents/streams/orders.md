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

### REPORT (orders, round 36; 2026-10-20 ~15:40 PDT). Every number names its commit, machine, workload, n.
**Where each item stands**
1. **C36.1 carry-over:** done `a80bb28ab`; then X3b deleted by R36.2 (`4eff54d77`).
2. **O1 / X3b: CLOSED "no workload" (R36.2).** Lab stage `make herringbone-lab` (builder0 light, native, `61b6181e2`,
   32 cells x 3 arms): 0 jam cells of 32. DEPLOY_PASS deleted; the lab stays as tooling.
3. **O2 the deploy move: DEPLOY_COMPACT FAILED its bar; stays OFF.** Judged builder0 light, native, `1bcd704cd` (check
   green at `7a4226932`), 12 cells x fresh seeds 3681-3686, n 6 a cell, 576 squad rows,
   `references/round36/orders/o2-compact-judged-builder0-1bcd704cd/verdict.txt`. Counter: 72/72 runs differ. Gain (a) median
   worst deploy leg 13.4 -> 11.4 m, -14.9 % (needed 20 %). Gain (b) summed median twitch 168.7 -> 177.0 m, +4.9 % WORSE
   (needed -15 %). Guards: twitch over main + 3 m in Crossing 5 click (29.8 -> 34.1) and Terminus 5 route (18.6 -> 29.7);
   never-in 1 -> 2 in Crossing 5 route. **The own-spacing line can't be read as filed:** main itself has its closest own
   crews at 3.8-8.6 m centre to centre in EVERY cell (the minimum over squads and seeds: crews meet in traffic at the window's
   end, not in the halt), so ">= 9 m in every cell" fails the base. A future spacing guard should read the halt SEATS, not
   the end positions. **Reading:** a halt half as deep shortens the move (-15 %) but not the twitch: the twitch is mostly
   what happens after the move (traffic, engagement, crews stopped short), so the next lever is the "neither" group (item 7).
   Cause count before it (builder0 `f5aa89ecd`, 287 squads): of 57 twitchy squads, depth 23, seating 10, neither 27.
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

### REPORT (orders, round 36; 2026-10-20 ~15:40 PDT). Every number names its commit, machine, workload, n.
**Where each item stands**
1. **C36.1 carry-over:** done `a80bb28ab`; then X3b deleted by R36.2 (`4eff54d77`).
2. **O1 / X3b: CLOSED "no workload" (R36.2).** Lab stage `make herringbone-lab` (builder0 light, native, `61b6181e2`,
   32 cells x 3 arms): 0 jam cells of 32. DEPLOY_PASS deleted; the lab stays as tooling.
3. **O2 the deploy move: JUDGING.** Cause count (builder0 `f5aa89ecd`, 287 squads): of 57 twitchy squads, depth 23,
   seating 10, neither 27. DEPLOY_COMPACT (`cd1043de8`, OFF) built in the deploy carve-out. Bar filed 15:10 PDT before any
   compact number. The orchestrator's own-squad guard is read centre to centre (hull-to-hull 9 m fails main itself; ruling
   ruled, main 635987442). **GREEN: `7a4226932`** (= `1bcd704cd` + a Status-only commit): builder0 `make check exited 0`,
   2964 passed / 0 failed, sim-baseline 13/13 unmoved (glibc-2.43). Judged probe on 3681-3686 at `1bcd704cd` running
   (builder0 light, native); `python3 tests/control/compact_judge.py <rows.jsonl>` reads it.
4. **O3 the reached halt: FALSIFIED, no switch.** Builder0 `f5aa89ecd`: X3c's anchor test catches 1 of 57 twitchy squads;
   the loops are traffic between squads, not unreachable ground.
5. **O4 packing: PARKED (orchestrator).** What binds is the 9 m clearance between squads (the lead's spacing call, queued
   in HANDOFF), then ground; arrival overlap is 3-8 % of refusals.
6. **Stretch:** the bridge-mouth click is already covered by the deploy's halt lay (0 of 24); uncross on a queued screen was a
   real swap, not path planning.
7. **The "neither" twitch (R36.6, the main thread for his "squads don't look like they follow the order"): COUNTED and
   TRACED; design note filed, no code.** `references/round36/orders/neither-twitch-note.md`. Builder0 light, native,
   `55c973cd4`, 12 street cells x 3621-3626, 287 deployed squads, crews scored against their own element: of 55 twitchy
   squads, **LOOP 19** (a turn-around loop to a seat behind the crew: Locks 3 click s3624 Bravo_1, seat 7 m north, drove 30 m
   south over the lock and back), **ENGAGEMENT 16** (ADVANCE, then left short), **STOPPED SHORT 19** (mixed; trace first),
   **TRAFFIC 1**. 25 of 287 squads have a crew re-dealt to another squad by untangle; that read as twitch before
   `acd95603d` (Terminus 5 route s3624 Delta_2 drove with element Echo: a 69.8 m "twitch"). Recommendation: LOOP to
   manoeuvre (a short reverse into a goal < ~15 m behind the hull, with a lab stage, `away_m` deciding); orders' fallback
   facing-aware deploy seating. Two questions for the lead drafted in the note (parked squads chasing; vehicles going with
   a neighbouring squad).
   His concern (2026-10-20, verbatim): "My concern here is basically giving some squads an order and then feeling like
   they're not actually following it, making the game appear dumb".
**His O4 answer (2026-10-20): keep 9 m** (HALT_CLEAR_M, seat to seat); O4 stays parked.
**Questions for the lead:** two drafted for the orchestrator in the neither-twitch note (in his terms): a parked squad's
crew chasing an enemy, and a vehicle going with a neighbouring squad. Neither blocks anything of mine.
**Requests to other streams:** none. **Merge notes:** `element_plan.gd`: the deploy carve-out only (DEPLOY_COMPACT, OFF;
`_deploy_compact`); `game/control/selection_squads.gd`: `pack_refused` (measurement only); `game/tactics/element.gd` =
main's (the R35.74 hook removed).

### O1 VERDICT: X3b CLOSES "NO WORKLOAD" (bar as filed; builder0 light lane, native, `61b6181e2`, 96 runs, NATIVE on in all)
- `make native herringbone-lab`, 32 fixed cells x {off, on, nostep}, n 1 a cell a arm (the stage is deterministic):
  **jam cells (off >= nostep + 3 s): 0 of 32** (needed >= 3). The arrived herringbone at s1's corner does not jam the
  Sirens on builder0 in any of 32 geometries; the deploy step is FASTER than the old settle on mean (nostep - off +1.94 s;
  in 2 cells the settle never got the Sirens in within 40 s).
- PASS where it acts (pass_waits 1 in 26 of 32 cells): on - off **+1.53 s mean, 5 cells over +5 s, worst +15.6 s**: the held
  deploy fires ~12.5 s in, in the middle of the passing traffic, instead of ~6 s, before it. The lab guard fails too.
- Table: `references/round36/orders/x3b-lab-builder0-61b6181e2/` (+ the laptop design sweep's lines, seen before the bar).
- **Reading:** R35.17's +6.1 s was one chaotic draw of the body stage (1 seed of 12), not a property of the geometry.
  No series run; 5101-5124 stay unseen. test_tactics_body's line (off + 8.1 s) stays (brains' file; the line still holds).
- **R36.2 (orchestrator, main 070508ace): DEPLOY_PASS DELETED** on stream/orders `4eff54d77` (element.gd hook, deploy_passers,
  the ElementPlan branch, its test, probe column and make arms); `game/tactics/` = main's; brains' R35.74 grant lapsed. The
  lab stage stays as tooling (`make herringbone-lab`, arms off / nostep).

### O2 + O3 builder0 cause count (`f5aa89ecd`, builder0 light lane, native, main only, 12 street cells x seeds 3621-3626 =
D4's already-seen seeds, 287 deployed squads; `references/round36/orders/o2-causes-builder0-f5aa89ecd/`)
- **O2, squads twitching >= 15 m (n 57): depth 23, seating 10 (3 both), neither 27.** All deployed (n 287): depth 53,
  seating 13. Medians of the worst deploy leg: as seated 18.4, best seating 16.3, half depth 13.1 m (twitchy squads).
  Depth dominates seating, so DEPLOY_COMPACT (R36.2 follow-up: "if depth dominates, compact"). But 27 of 57 have neither
  cause (traffic between squads, as O3's trace showed), which caps what any deploy-shape change can win.
- **O3 FALSIFIED (no switch):** 28 crews in 287 squads drive >= 8 m over the straight line to their seat; X3c's anchor test
  catches 11; among the 57 twitchy squads, 8 have a detour and 1 is caught. The reached halt would fix about 1 twitch in
  57. The loops are traffic, not unreachable ground.

### O2 BAR: DEPLOY_COMPACT (FILED 2026-10-20 15:10 PDT, before any compact number; code `cd1043de8`, OFF)
- **Probe:** `make native orders-probe`, arms `main:` v `compact:--deploy-compact=on`, the 12 cells (locks, crossing,
  terminus x {3, 5} x {click, route}), FRESH seeds 3681-3686 (never run), n 6 a cell, medians; builder0 (light lane,
  ORDERS_PROBE_JOBS=1), native; on a hash whose full `make check` is green (the verdict stands only then).
- **Counter first:** median `halt_depth_m` lower on compact in every cell that deploys a herringbone, and the arms' rows
  differ.
- **Gain (both):** (a) the median worst deploy leg over all deployed squads (`deploy_move_causes.py`, as seated) >= 20 %
  lower on compact; (b) summed over the 12 cells, the median `twitch worst m` >= 15 % lower. 15 %, not D4's 20 %: on
  builder0, 27 of 57 twitchy squads have neither cause, so a shape change reaches at most about half the twitch.
- **Guards (each cell):** median all-in <= main x 1.2 + 3 s, no more never-in seeds; median `twitch worst m` <= main + 3 m;
  median end foreign min >= main - 3 m; deck no higher, far bank 0; `test_control_scale`'s 3-tick response. Spacing:
  test_control_deploy_compact (no pair under 0.75 spacing).
- **A pass ships ON** (symmetric; CPU elements seldom deploy, R35.5), with sim-baseline attributed with the switch off.

### O4 design note (laptop measurement): park, one player-terms question
`references/round36/orders/o4-packing-note.md`. `SelectionSquads.pack_refused` (`0409345d1`, measurement only) counts,
in the pack's last compaction pass, why each place nearer the click was refused. Laptop GDScript, seed 34, `--pack=on`,
6 click cells: halt-seat clearance between squads (9 m) and outlines dominate, ground is next, and arrival overlap (the
two travel tests) is only 3-8 % of refusals. "Treat arrival overlap as transient" frees almost nothing; the binding
constraint is the clearance itself, which is a spacing (survivability) choice for the lead.

### Stretch (both answered, no code)
1. **A click at a bridge mouth:** the deploy's halt lay (`_dry_halt_anchor`, B8b) already steps a plain click's halt back
   until no seat is on the deck or the far bank. Crossing west bridge, laptop GDScript: 0 bad seats in 24 geometries
   (3/4/5 crews x clicks (-92,33) (-92,36) (-92,40) (-88,36) x 2 approach headings). The cost: the anchor moves 5-21 m back
   from the click. Probe cells with clicks at (-92,36) and (-92,40), 3 and 5 squads: crossed 0. Evidence
   `references/round36/orders/stretch-bridge-mouth/`.
2. **`uncross_paths` on a queued screen:** traced on the merged tree (laptop, a temporary local patch, reverted). With
   uncross allowed on a screen, `test_control_queued_task` passes 12/0, and its several-squads screen case makes a REAL
   swap. Round 35's "changed behaviour through path planning alone" was a misreading: uncross acted. It stays limited to
   plain moves (no evidence a screen needs it).

### O3 first falsifier (X3c's note, "first, check every 20-30 m loop is a seat the anchor test fails")
- Probe columns (`f5aa89ecd`): each crew's navmesh drive to its halt seat minus the straight line, read 1 s after the
  deploy; `detours` = crews >= 8 m over; `detours_caught` = those whose seat fails X3c's anchor test (drive from the halt
  anchor > straight x 1.3 + 3 m, or over a deck).
- **Laptop GDScript, seed 34, main + joint (merged e45bb6632), 6 click cells, 24 squads: detours in 2 squads, caught 0.**
  The traced loop (Crossing 3 sq1, twitch 25.8 m) is NOT a navmesh detour (worst crew 2.0 m over straight): Alpha_1's seat
  is 8.7 m away in a straight drivable line; from t 18 to 36 it wanders round (-95, 33), where squads 2 and 3 arrive at
  the deck mouth, then ends 14 m short. It's traffic between squads, not unreachable ground.
- If builder0 agrees (the cause count below carries these columns), X3c's reached halt has no workload: write O3 up as
  falsified, no switch built.

### O2 trace (laptop GDScript, seed 34 = the dev seed, main + the probe's new deploy columns, the 6 click cells, 24 squads)
`references/round36/orders/o2-trace-laptop-s34/rows.txt`. Per squad: the deploy's worst leg as seated, the best possible
seating of the same seats (minmax), and the same halt with its depth along the heading halved (compact):
- The herringbone is 33-48 m deep for 4-5 crews ((n-1) x 0.8 x spacing); the travel wedge 27-39 m wide. Every twitch over
  20 m (Terminus 5 sq4 31.3, Locks 5 sq2 26.5, Crossing 3 sq1 25.2, Locks 5 sq4 21.3) is a squad with halt depth >= 33 m.
- Two different causes: **seating** (Terminus 5 sq4: leg 47.4 m as seated v 19.2 best seating: D4's minimax case) and
  **shape depth** (Locks 5 sq4: 37.1 / 30.8 best seating / 18.8 compact; Locks 5 sq2 16.4 -> 7.3 compact; Terminus 5 sq2
  18.6 -> 7.4). Legs rarely drive THROUGH a squadmate (2 of 24 within 4 m): the move is long, not crossed.
- Design note DRAFT: `references/round36/orders/o2-deploy-move-note.md` (DEPLOY_COMPACT, the deploy's herringbone half as
  deep, chosen tentatively). R36.2 asks for each cause COUNTED over the probe's street cells on builder0 before choosing:
  `tests/control/deploy_move_causes.py` over `make native orders-probe`, main only, seeds 3621-3626 (D4's, already seen;
  fresh seeds kept for the bar), builder0 light lane at `f5aa89ecd` (relaunched with O3's columns): running.

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
