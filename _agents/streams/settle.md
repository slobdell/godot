# Stream: settle (a squad that stops counts its crews in, and never parks on a road a friend still drives)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 40** (C40.1, C40.2,
> CP40.1) and *Rulings (round 39)*. Your round-39 brief and its traces: `streams/archive/round39/settle.md` (Status: *Round-40 input:
> why route-clear lost three squads* and *What round 40 should try*), evidence under `references/round39/settle/`. **You own:** in
> `game/tactics/element_plan.gd` the deploy-step, halt-lay and seat-deal functions (DEPLOY_CAP_S and the all-in test included);
> `game/tactics/element_situation.gd`; `game/tactics/deploy_passers.gd`; the PARKED_HOLD seam in `tank_brain.gd`; `tests/settle/**`,
> `tests/test_settle*.gd`, `mk/settle.mk`; you may run orders' probe (`make native orders-probe`) and judge (`orders_judge.py`).
> **Model:** Fable (the lingering problem: S1 failed in six versions over two rounds). **Machine:** builder0 light lane (J<=4).
> **Seeds:** 8001-8024 (registered, C40.1); round 38/39 dev blocks for dev reads only.

## The lead's direction

His standing bar: "the feel of the game needs to have the user perceive that the units are smart and under their control". Parked
squads: "Stay put and shoot". What he'd see today: (1) on his 5-squad click at terminus, one squad sits for ten seconds and then
reshuffles its tanks (the twitch), because one tank stopped 3.8 m from its spot and the squad waits for it; (2) on a 5-squad click or
route, a squad that stops first can still park a tank where the last squad has to drive, and that squad never gets in.

## Where things stand (main at launch: see HANDOFF)

- **ON since round 39:** DEPLOY_HOLD (a squad that loses a tank keeps its seats; `--deploy-hold=off` is round 38's re-lay). Latch at the
  anchor (round 38). Fog, rules R1-R3 ON.
- **The deploy trigger (orders' trace, `references/round39/orders/bar-traces-builder0-e7c896c8f/README.md`):** a deploy waits until every
  living crew is within max(TankBrain.ORDER_ARRIVE 3.5 m, its settle radius) of its travel seat, or DEPLOY_CAP_S (10 s) after arrival.
  On terminus his-5 click, Bravo_2 holds 3.83 m off its seat on all 12 seeds; the halt waits out the cap and re-deals: a 28.4 m twitch.
  G1 v5's whole guard failure is this.
- **S1 route-clear v2 FAILED (never-in 1 -> 3)**, stays OFF (`--seat-route-clear`). Traced in time (your archived Status): **cause A**,
  the corridor is one centre line from the squad's centre, but crews drive their own paths (terminus click s6003, route s6003); **cause
  B**, a cleared seat's own leg crosses a live route head-on while the passer drives it (crossing route s6009). Main got in on all three.

## Backlog (in order)

1. **T1 the deploy trigger (`--deploy-arrive=near`, new switch; small, FIRST).** A crew that is HOLDING (speed ~0, not driving to its
   seat, a few ticks running) within ~5 m of its travel seat counts as in. Pure test first (the 3.83 m Bravo_2 case and a crew still
   rolling at 4 m must not count). Lab: terminus his-5 click s6201-6212 (the 12 deterministic runs), twitch 28.4 -> ~0. Then a bar on
   8001-8012 (deciding: his-5 click twitch; guards: never-in, all-in time, places outside, first shape, contacts, the fights). A pass
   ships ON with one full check = **CP40.1**; tell the orchestrator the minute it's green (orders re-reads G1 on it).
2. **S1 v3 per-crew corridors (`--seat-route-clear`, v3).** (a) the corridor from each passing CREW's own path to its own slot and its
   queued legs' slots, not one centre line; (b) move a seat only if the crew's leg to it is short (<= ~one spacing) or crosses no live
   corridor, else keep main's seat; (c) failing both, a seat on a live corridor waits where the crew stands until the passer is past.
   Lab FIRST on the three traced never-ins (terminus click s6003, terminus route s6003, crossing route s6009) plus s4505/s3958/s3806:
   every squad in on every one. Then a bar on 8013-8024 (deciding as round 39's: never-in on 5-squad cells clear <= main - 1, main >= 2,
   no run never-in that main gets in; report deploy legs >= 25 m, which v2 raised 64 -> 100). Name manoeuvre's switch state (C40.2).
3. **Stretch:** if T1 ships and S1 v3 fails, file what the trace says next (no re-run on the same seeds).

## How to verify

Pure tests; `make settle-lab` / `make quick-remote`; one full check of every hash you name before a judged series; probe series on
your fresh seeds with `settle_judge.py`. Smoke like a player: `make skirmish ARENA=terminus SKIRMISH_FLAGS="--deploy-arrive=near"`,
box five squads, click once, watch no squad reshuffle; then five squads down one route with `--seat-route-clear`.

## Don't touch

orders' group lay (`game/control/**`), manoeuvre's movement and traffic blocks, balance's brains beyond the parked-hold seam, `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Report (2026-10-25, running)
- **Bar T1 PASS** (afd436ca3's code, builder0 light J4, `settle-t1`, seeds 8001-8012, re-run in full after builder0's crash;
  every part complete: 576 squads, fights 36/36 both reads, 0 unstarted; `references/round40/settle/t1-bar-builder0/`
  at 8ca1b1e31): cap deploys 265 -> 83; arrival to deploy mean 6.26 -> 4.42 s (median 7.1 -> 3.4); never-in 3 -> 1 runs;
  all-in mean 28.6 -> 29.0 s (<= 32.4); twitch >= 15 m 113 -> 110; places outside (gate read) 80 -> 80; flips 0 -> 0; first
  shape 6/576; contacts 13576 -> 13394; fights 3sq kills 4.69 -> 5.11, losses 7.06 -> 6.72; 5sq kills 10.00 -> 9.56,
  losses 12.86 -> 12.97 (all inside). Per-cell twitch medians reported in verdict.txt (orders owns the his-5 twitch).
- **GREEN: cab85debf = CP40.1, T1 SHIPPED ON** (`--deploy-arrive=settled` default, `=off` escape). builder2, `>> remote:
  make native check exited 0`, 3,188 passed / 0 failed, 24 + 3 NOT JUDGED (non-judging machine: perf-judge, ai-scenarios'
  CPU budget, the quiet-window guard). **sim-baseline unmoved** ("13 maps unmoved (glibc-2.43)", 53/0): no maps to record or
  adopt. `settle-t1`'s main arm and both arms of `settle-s1v3r40` pin `--deploy-arrive=off` so the filed bars reproduce.
- **Bar S1 v3 FAIL** (afd436ca3's code frozen at 8ca1b1e31, T1 OFF both arms, builder0 light J4, seeds 8013-8024, every
  part complete: 576 squads, fights 36/36 both reads; `references/round40/settle/s1v3-bar-builder0/`). DECIDING PASSED:
  never-in runs on the 5-squad cells 4 -> 0, none new; never-in all cells 5 -> 0; all-in 25.7 -> 24.8 s; flips 0 -> 0;
  first shape 6/576; contacts 12235 -> 11418; fights all inside. **FAILED guard twitch: squads >= 15 m 88 -> 99.** Reported:
  deploy leg >= 25 m 58 -> 85; place+twitch >= 25 m 162 -> 168. Not shipped (stays `--seat-route-clear=v3`, OFF).
- **The twitch split** (bar rows joined to v3's DEPLOY_TRACE; net +11 = 56 up, 45 down): WAITED squads (n 79) 31 -> 37 (+6)
  with legs barely moved (>= 25 m 5 -> 10; 4 of 16 ups long-legged): the waiting crew released and driving after the 8 s
  place window. CLEARED squads (n 239) 42 -> 47 (+5) carry the long legs (>= 25 m 18 -> 42; 9 of 30 ups' legs grew > 5 m).
  UNTOUCHED (n 258) 15 -> 15. Cells: crossing 5 click +4, crossing 3 click +3, terminus 5 click +3, crossing 3 route +2,
  terminus 5 route +2; locks clicks and crossing 5 route went down. Next for round 41 (v4 ideas, not built): release a wait
  inside the place window or keep the waiting crew's stand as its seat once the window closes; cap a cleared seat's leg
  (e.g. no clear seat farther than the original seat + a spacing: wait instead).
- **Dev pair with T1 ON** (builder2, frozen side worktree `../godot-settle-dev9d` = main 9d5907ddd + measurement-only trace
  commits, tip 4f1ed2eca; crossing + terminus x 3/5 x click/route, dev seeds 6301-6306, n 48 runs an arm, J12;
  `references/round40/settle/dev-v3t1-builder2/`): **with T1 ON, v3's twitch cost reverses**: squads >= 15 m 42 -> 33,
  worst twitch a run median 17.2 -> 15.1 m, all-in median 21.0 -> 18.7 s, cap deploys 42 -> 33. But **one new never-in**:
  terminus 5 click s6306, Alpha (the last squad; main in at 42.1 s) ends 19.4 m off its spot. Bravo had 3 seats cleared and a
  crew waiting, Delta 1 cleared. Dev, n 6 a cell. From the log (no per-crew positions in it): Bravo_2 WAITED where it stood,
  (-24.3, 85.9), ~7 m off the head of Alpha's live route ((-31.4, 86.7) west then south to its spot (-29.9, 22.2)), and was
  released at tick 503 (REDEAL_TRACE, 9.6 m). Whether that wait held Alpha up needs a position trace of Alpha's crews (not
  run). First thing for a v3-on-T1 bar: that trace, and a "never wait within ROUTE_CLEAR_M of a live route's head" rule.
- **Dry deal read** (same run, main 9d5907ddd T1 ON, terminus 5 route 8203/8205/8206/8208, 20 deploys, 4 on the cap; 8205 had
  none): drives to the grounded seats, [worst, total] m. Cap deploys: main worst median 36.5 (>= 25 m: 4 of 4), total mean
  73.9; least-total on the ordered heading 21.6 (2 of 4), 60.3; **least-total laid on the street axis 22.5 (0 of 4), 51.4**.
  Every deploy: >= 25 m 6 -> 4 (ordered) -> 0 (street). s8206 Delta: main [38.4, 83.7], ordered [41.9, 82.5], street
  [24.3, 65.9]. **The lay matters more than the deal**, as guessed: on the ordered heading the deal alone left Delta's
  worst at 41.9 m. The cap deploys here were NOT bunched (spread 20-30 m), so a flag should be scoped to cap deploys, not to
  bunched ones. Proposal (round 41 bar, not built): `--cap-deal=street`, a cap deploy laid on the street axis (S1 v5's street
  read) and dealt least-total from where the crews stand; judged on deploy leg >= 25 m and twitch >= 15 m, with never-in,
  all-in, places outside and fights as guards.
- **v3's never-in traced** (builder2 light, `settle-dev-s6306`, main 9d5907ddd + v3, `--probe-trace=1`): reproduced. Alpha_3
  drove the lane at x 4..7 holding its travel place, 8.6 m east of its modelled corridor (its navmesh path to its slot ran
  the centre line, over ROUTE_CLEAR_M 7); Bravo's v3 seat cleared to (4.4, 68.0) on that line (main's Bravo_1 seat was
  (-17.5, 65.8)), and Alpha_3 stopped at (4.1, 71.9) from t36 to the end. **A v3 flaw: the corridor model ignores the
  formation's travel width.** Fix: **S1 v3b** (`--seat-route-clear=v3b`, OFF, 0eec2ccdc): each driving squad's SWEPT BAND
  (its centre route shifted out to its travel half-width, slots' widest offset across the first leg, at most 15 m, in 7 m
  steps), added to v3's crew corridors. Pure test `tests/test_settle_route_clear_v3b.gd` 3/0 (laptop): (8.6, 68) reads
  clear to v3 and blocked to v3b. Branch merged with main 9d5907ddd at c973a456e.

### Bar S1 v3b swept band (filed 2026-10-25 before any number on 8701-8724; R40.14)
What he'd see: the same as S1 v3 (no squad parks on a street the squads behind still drive), now with T1 ON in both arms.
Arms: `main:--deploy-trace` v `v3b:--seat-route-clear=v3b,--deploy-trace`, both on main 9d5907ddd + this branch (T1
`--deploy-arrive=settled` ON, everything else of the branch OFF), frozen at the hash whose full check went green (the gate).
Manoeuvre's `--giveway-chain` OFF in both. Workload and judge: s1c's as filed for S1 v3 (12 no-fight cells x 3 maps x 3/5
squads x click/route; fights 3-squad budget 1500 and 5-squad budget 3000 click cells), **no-fight seeds 8701-8712, fight
seeds 8713-8724**, `make settle-s1v3b` on builder2. A different base from Bar S1 v3: a new bar, not a re-run.
**AMENDED at the orchestrator's ruling R40.15 (main 968226fb4), before any number on 8701-8724** (as filed at 46b72a3fc the
judge was s1c unamended, whose deciding line needs main's 5-squad never-in >= 2; with T1 ON main's dev never-in was 0 of 48).
Judge `settle_judge.py s1v3b` (s1c's lines with these changes):
- **Deciding:** squads with twitch >= 15 m, v3b <= 0.85 x main, with main >= 20 (else undecidable = no ship).
- **Never-in is a GUARD:** v3b <= main over every cell, and NONE NEW on any cell (s6306's kind).
- Every other s1c guard as filed (counter seats cleared > 0; all-in mean <= base x 1.10 + 1; first shape <= 3 %; flips
  <= base + 3; friend contacts and foreign <= 110 % + 5; fights 3- and 5-squad, 0 unstarted). Deploy legs >= 25 m and
  place+twitch >= 25 m reported.
- Gate: the merged branch's full check green on builder2, and the dev lab (6301-6306) showing v3b keeps v3's T1-ON gain
  (twitch down, no new never-in); if it loses it, stop and tell the orchestrator before the series.
- **Orders' question (via orchestrator, G1 v6 trace, laptop, terminus 5 route s8206): when a cap deploy lays its halt with
  crews bunched, should seats be dealt nearest-first from where they stand?** Answer (code read, no run): **yes, as the
  least TOTAL drive, not greedy nearest-first.** Greedy nearest-first leaves the last crew the leftover far seat. On main the
  halt keeps each crew's TRAVEL seat index (`fixed` seating) and lays on the ordered heading, so a bunched squad's crews get
  whatever seat its index names. Round 38's `_fit_deal` (element_plan.gd) already deals by least total from each crew's
  position to its GROUNDED seat (Hungarian), but only when DEPLOY_FIT turns the lay (`--deploy-fit`, OFF). R38.17 restricted
  it to turns because dealing every deploy diverged runs with no turn. Caveat: a deal can't shorten a leg past the
  shape's own extent (a herringbone runs ~47 m deep), and Delta_2's 36 m / Delta_4's 29 m are probably mostly seats laid
  across the street (ordered heading) rather than the index swap. Next step (a candidate for the stretch item, not run):
  a dry read at that deploy comparing main's fixed deal, `_fit_deal` on the ordered heading, and `_fit_deal` on the street
  axis (S1 v5's street cap), worst and total legs. Then, if it pays, a flag scoped to cap deploys with a bunched squad
  (crew spread under one spacing), filed as its own bar.
- **Dry deal read (orchestrator: after S1 v3's series, dev only):** built at 3be6f1aa7 + 978c98d88. DEPLOY_TRACE now
  carries `cause` and `deals` (main / `_fit_deal` on the ordered heading / on the street axis: [worst, total] m to the
  grounded seats, plus the crews' spread); pure test `tests/test_settle_deal_read.gd` 1/0 (laptop); reader
  `tests/settle/settle_deals.py DIR`. Plan: terminus 5 route seeds 8203, 8205, 8206, 8208 on (a) this tree (T1 ON) and (b) a
  frozen side worktree merging stream/orders' G1 v6 bar commit with the trace commits (Delta's case reproduces only under
  G1 v6's column). If least-total on the street axis cuts the bunched cap deploys' worst legs well below main's, file a
  scoped flag + bar (round 41 or end of round 40, whichever the clock allows; S1 v3 first if it passes).
- Previous green: **afd436ca3** (builder2, 3,188 passed / 0 failed, 24 + 3 NOT JUDGED), everything of round 40 OFF.
- **T1 built** (1327f85ef, OFF: `--deploy-arrive=near`): pure test `tests/test_settle_deploy_arrive.gd` 5/0 (laptop): the
  3.83 m holding tracked crew counts as in (main waits for the cap), a crew rolling at 4 m and one holding at 6 m don't, a hold
  under 0.5 s doesn't yet.
- **T1 lab: near changes NOTHING on his-5 click** (1327f85ef, builder0 light J4, terminus his click 5 squads, seeds 6201-6212,
  n 12 an arm, dev; `references/round40/settle/t1-lab-dev/`, reader `tests/settle/settle_t1.py`): worst twitch a run main 13.8
  / near 13.8 m; column (G1 v5's arm) 28.4 / column+near 28.4 m, identical on every seed; never-in 0; all-in median 28.2 / 16.8 s.
- **Why (traced, column+near s6201, `--probe-trace=2`, ARRIVE_TRACE at the cap, tick 332):** the crew keeping Bravo out at the
  cap is **Bravo_1, holding 7.94 m off** (it WAS in at t 3, 3.4 m, then an ADVANCE brain option walked it off its station);
  Bravo_2 was still DRIVING 7-8 m off from t 1 to t 9 and held at 3.86 m only from t 10 (15 ticks at the cap). And the 28.4 m
  "twitch" is not the wait: it is Bravo_2's 24 m deploy leg to the herringbone's far seat (-53.7, 75.1), blocked t 11-15, then
  driven t 18-22, after the probe's 8 s place window. An earlier trigger cannot remove it on this cell. Orders' trace read
  "3.83 m v 3.5 m" correctly, but that is the last crew in, not the cause of the twitch.
- **The wider read (round 39's judged G1 v5 / G3 v6 rows, e7c896c8f, builder0, no new run): main deploys on the CAP for 311 of
  768 street squads (40 %) and 48 of 96 his-click squads.** That is the "sits 10 s" he sees. Orchestrator R40.4: orders owns
  the his-5 twitch (the column's far-seat leg); T1's target is the cap deploys, judged on cap deploys / time to deploy.
- **The cap trace** (1327f85ef + ARRIVE_TRACE, builder0 light J4, main, dev seeds 6001-6002 x 12 street cells, 96 squads;
  `references/round40/settle/cap-trace-dev/`, `settle_t1.py DIR caps`): 41 cap deploys (43 %), arrival to deploy median 7.0 s.
  The crews keeping a squad out (a squad can have several): a crew that WAS in and is now off (3.6-16.7 m, most 4-9 m) in 25 of
  40; a crew still driving, never in, in 18; one holding 5-25 m, never in, in 14; one holding within 5 m in 8. Scored at the
  cap moment, "near" (holding <= 5 m) would let 6 of 40 in; + once-in within 10 m 12; holding <= 7.5 m + once-in 20. The rest
  have a crew genuinely still driving.
- **T1 v2 `--deploy-arrive=settled`** (754fee377, OFF; pure tests 7/0 laptop): settled = in, or once in and <= 10 m, or
  holding 0.5 s <= 7.5 m; all settled = all in; and when at least half the squad is settled and the count stands 2 s, the
  halt is laid (cause "settled") and the stragglers drive straight to their halt seats instead of the squad sitting out the
  10 s. Lab 2 running (main / near / settled, 12 street cells x dev 6003-6004).

### Bar T1 the deploy trigger (filed 2026-10-24 before any number on 8001-8012; code = c074db72e's; judge = this commit's)
What he'd see: a squad that stops lays its halt within a few seconds instead of sitting ~10 s and then shuffling, and every
squad still gets in. Arms: `main:--deploy-trace` v `settled:--deploy-arrive=settled,--deploy-trace`. Base: main as on
c074db72e (DEPLOY_HOLD ON, latch ON, R1-R3 ON). **Manoeuvre's `--giveway-chain`: OFF in both arms** (main's state; C40.2);
`--seat-route-clear` OFF in both. **Seeds 8001-8012 (registered, C40.1):** the no-fight probe's 12 street cells (locks /
crossing / terminus x 3 / 5 squads x click / route, n 12 a cell, 576 squads an arm) and the fight probe's click cells, 3-squad
budget 1500 and 5-squad budget 3000 (36 + 36 fights an arm). `tools/remote.sh --light native settle-t1
TANK_SQUAD_SLOT_TIMEOUT=14400`, builder0 light, J 4, after a green full check of the named hash. Judge `settle_judge.py t1`.
Places outside are the probe's own read on this branch (main's gate read; orders' R40.5 corridor read is not on main).
- Counter: squads deployed by the new rule where main capped, or on "settled", > 0.
- **Deciding:** cap deploys over the no-fight probe <= 50 % of main's, with main >= 20.
- Guards (judged): never-in runs over every cell <= main; per cell: all-in median <= main x 1.2 + 3 s, never-in <= main, end
  foreign median >= main - 3 m, crossed <= main; all-in time (mean over runs in on both) <= main x 1.10 + 1 s; arrival to
  deploy mean <= main's; squads twitching >= 15 m <= main x 1.1 + 2; first shape differs <= 3 %; shape flips <= main + 3;
  places outside <= main + 2; friend and foreign contacts <= 110 % + 5; the fights (his kills, his losses, CPU losses within
  1.645 se; 0 runs that never started).
- Reported: per-cell twitch medians, place+twitch >= 25 m, deploy legs >= 25 m, all-in median per run. **Why not judged
  (from the dev labs, before this bar):** an early halt moves a straggler's last approach after the deploy, into the probe's
  place and twitch windows; main drives the same metres before its deploy, uncounted (lab 3, n 2 a cell: crossing twitch
  medians 6.4 -> 14.1, 20.3 -> 26.9, 20.0 -> 29.7 m while squads twitching >= 15 m 20 -> 22). The reshuffle he'd see is the
  >= 15 m count, which is judged.
- Known risk: terminus 5 route s6003 (dev) lost Echo on settled in both labs; main got Echo in at 81.6 s (all-in median 25 s),
  a marginal cell. Lab 3 (c074db72e, dev 6003-6004 x 12 cells, n 2): caps 47 -> 19, arrival to deploy 6.8 -> 5.1 s mean,
  all-in 26.7 -> 26.8 s (runs in on both), never-in 0 -> 1.
- A pass ships `--deploy-arrive=settled` ON on a new hash with one full check = **CP40.1**.
- **Series tree (R40, the orchestrator's condition):** the series runs on afd436ca3. `git diff c074db72e afd436ca3 -- game/` is ONE
  line: `_trace_deploy` adds a `"waited"` field to the printed DEPLOY_TRACE line (measurement only, under `--deploy-trace`,
  which both T1 arms pass; it reads the deploy and decides nothing). No other game path differs; S1 v3's code was already in
  c074db72e behind `--seat-route-clear=v3`, OFF in both T1 arms. Main's decision path is unchanged.

### S1 v3 lab (afd436ca3's tree, builder0 light J4, n 1 a run, dev; `references/round40/settle/s1v3-lab-dev/`, `settle_lab.py`)
| run | main all-in | v2 (`--seat-route-clear`) | v3 (`=v3`) | v3 seats cleared / crews waited |
|---|---|---|---|---|
| crossing 5 route s3806 | 41.7 s | 44.5 | 32.1 | 11 / 1 |
| crossing 5 route s3958 (bridge mouth) | NEVER (squad 4) | 47.5 | 51.5 | 9 / 2 |
| crossing 5 route s6009 (cause B) | 34.8 | NEVER | 42.9 | 10 / 3 |
| terminus 5 click s6003 (cause A) | 32.9 | NEVER | 33.8 | 5 / 1 |
| terminus 5 route s4505 | 42.2 | 42.2 | 39.6 | 8 / 2 |
| terminus 5 route s6003 (cause A+B) | 81.6 | NEVER | 56.8 | 7 / 1 |
Every squad in on all six on v3 (main 5 of 6, v2 3 of 6). Cost seen: s6009 +8.1 s, s3958 +4 s v v2.

### Bar S1 v3 per-crew route-clear (filed 2026-10-24 before any number on 8013-8024; code = afd436ca3's)
What he'd see: on a 5-squad click or route, a squad that stops first never parks a tank on the street the squads behind still
drive, nor drives one across it while they come, and every squad gets in. Arms: `main:--deploy-trace` v
`v3:--seat-route-clear=v3,--deploy-trace`. Base: main as on afd436ca3 (DEPLOY_HOLD ON, latch ON, R1-R3 ON;
`--deploy-arrive` OFF, T1 not shipped). **Manoeuvre's `--giveway-chain`: OFF in both arms** (main's state; C40.2). **Seeds
8013-8024 (registered, C40.1):** round 39's S1 workloads: no-fight 12 cells (576 squads an arm), fights 3-squad (b1500) and
5-squad (b3000) click cells. `tools/remote.sh --light native settle-s1v3r40 TANK_SQUAD_SLOT_TIMEOUT=14400`, builder0 light J 4,
after a green full check of afd436ca3 (and after Bar T1's series: one judged series per builder). Judge `settle_judge.py s1c`,
round 39's lines unamended:
- Counter: seats cleared > 0.
- **Deciding:** never-in runs on the 5-squad cells (route and click) v3 <= main - 1, with main >= 2, and NO run never-in on v3
  that main gets in. (Main < 2 = not decidable: no ship.)
- Guards: never-in over every cell not up; all-in time (mean over runs in on both) <= main x 1.10 + 1 s; twitch >= 15 m squads
  not up; first shape differs <= 3 %; shape flips <= main + 3; friend and foreign contacts <= 110 % + 5; the fights (both reads,
  within 1.645 se, 0 unstarted).
- Reported: place+twitch and deploy legs >= 25 m (v2 raised them 64 -> 100), seats cleared, crews waited.
- A pass ships `--seat-route-clear=v3` ON on a new hash with one full check.

### Player's look (builder0 light, `make settle-shots`, afd436ca3's tree, crossing 3 click s6003; frames looked at)
- main and settled frames are byte-identical, as expected: the probe shoots when the last squad arrives and 5 s later, and
  settled's early halts on this run fire at 17.7 s and 25.4 s (main caps at 24.7 / 26.1 s), after both shots. The probe's shot
  times (orders' file) can't show T1; the deploy-time numbers are its evidence. Playtest: `make skirmish ARENA=crossing
  SKIRMISH_FLAGS="--deploy-arrive=settled"`, three squads, one click past the bridge, and watch the third squad lay its halt
  ~2 s after it stops instead of ~10 s.
- v3: the three squads stand along the street south of the bridge mouth, none on the deck or across its mouth.

### Plan (ordered)
1. T1: pure test (done) -> lab on orders' traced cell (his-5 click 6201-6212, main and G1 v5's column arm, each +/- near) ->
   bar filed here before numbers -> full check of the named hash -> series on 8001-8012 -> ship ON + full check = CP40.1.
2. S1 v3 per-crew corridors: pure test -> lab on the six traced runs -> bar -> series 8013-8024.
3. Stretch per the brief.

### Decisions (T1)
- **Holding** = no throttle asked (|throttle| < 0.05) and real flat speed < 0.3 m/s (Tank.DEPLOY_MAX_SPEED's stop), read in
  ElementSituation from `tank.command` and `tank.real_velocity`. Throttle, not intent: a crew queued behind a friend with its
  throttle open is still driving to its seat and must not count; one pivoting in place within 5 m may (it is in by any eye).
- **"A few ticks running"** = DEPLOY_NEAR_HOLD_TICKS 15 (0.5 s, five element updates) without a break, clock per crew kept in
  the deploy (`deploy["still"]`, dropped at the deploy). Short enough to beat the cap by ~9 s, long enough that a crew braking
  through 5 m on its way in is not caught.
- **Radius** DEPLOY_NEAR_M 5.0 (the brief's ~5 m; orders' trace 3.83 m), max'd with the unit's settle radius as main's test.
- **Trace:** `deploy["near"]` = crews counted near at the deploy (0 on the cap).
- **Settled v near (after the cap trace):** near alone answers a fifth of the caps. "Was in" is per crew since the arrival,
  against the seat it was sent to then (travel seats drift with the squad; 10 m keeps a drift of one spacing). The half-squad
  rule keeps B8's idea (lay the halt once the squad stands) without waiting on one crew stuck behind traffic: its drive to the
  halt seat is the same drive it was making. Risk the bar must guard: twitch / place+twitch and deploy legs (a straggler's
  halt seat can be farther than its travel seat), never-in, contacts.
