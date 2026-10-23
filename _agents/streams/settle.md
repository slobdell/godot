# Stream: settle (a squad that has stopped stays settled: right shape, own spots, no tank crossing the squad)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 38** (C38.1, C38.3) and
> in *Round 37*: R37.13, R37.17, R37.28, R37.37, R37.40, R37.42 (and the O1 / O1-LATCH / O2 bars). Orders' round-37 close notes:
> `streams/archive/round37/orders.md` (its traces are yours now). **You own:** in `game/tactics/element_plan.gd` the deploy-step,
> halt-lay and seat-deal functions; `game/tactics/element_situation.gd`; `game/tactics/deploy_passers.gd`; the PARKED_HOLD seam in
> `tank_brain.gd` (one guarded function, merge note to doctrine); `tests/settle/**`, `tests/test_settle*.gd`, `mk/settle.mk`; you may
> run orders' probe (`make native orders-probe`) and judge (`orders_judge.py`). **Model:** Opus. **Machine:** builder0.

## The lead's direction

His standing bar: "the feel of the game needs to have the user perceive that the units are smart and under their control". Parked
squads: "Stay put and shoot"; a nearly dead parked crew pulls back and returns (round 37). The defects below are things he'd see.

## Where things stand (switches on main, OFF)

- **The deploy deal crossing (R37.37):** at the deploy, the seat deal can send a stopped tank 47 m across its own squad to the far seat
  (terminus 5-squad click, squad 4, Delta_2). On main today.
- **Latch (`--halt-terrain=latch`, R37.40/R37.42):** removes shape flips and relays (143 -> 2), but its full check caught a wrong FIRST
  shape: crossing an `open` pocket at t=11 then arriving in a lane latched a coil (test_tactics_scenarios_2::test_a_move_ends_formed_up_
  on_the_spot_and_stops_issuing). Fix candidates: latch the read the deploy decides on (at all-in), or a read held ~2 s.
- **Parked hold (`--parked-hold=on`, R37.28):** passed its bar (off-seat 172.6 -> 20.0 s a fight) but doubles real parked re-deals (50 ->
  105); hypothesis: the halt is re-planned when a pulled-back crew returns, re-dealing crews that never moved. Untraced.

## Backlog (in order)

1. **S1 the deploy deal:** seats dealt nearest-first without crossing the squad; lab of the traced case; bar (deciding: a stopped crew's
   longest post-arrival drive; guards: all-in, contacts, the first shape, fights). Symmetric: a pass ships ON.
2. **S2 latch v2:** lab of the failing test's geometry FIRST (it must form herringbone), then the arm and a bar whose guards include the
   first shape (C38.1); fresh seeds.
3. **S3 O2's re-deals:** trace one (the returning crew hypothesis), fix, then O2 (+ latch v2 if it passed) on fresh seeds.
4. **Stretch:** a parked crew re-dealt after a loss (bursts after deaths).

## How to verify

Lab both paths; `make quick-remote`; one full check per named hash (this stream's last red came from the full check: run it before any
"ships ON"); probe series on fresh seeds. Smoke: `make skirmish ARENA=terminus`, park 5 squads and watch them settle.

## Don't touch

orders' group lay, doctrine's brains paths beyond the parked-hold seam, manoeuvre's movement blocks, `native/**`, `tests/baselines/**`.
Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Final report (2026-10-23, round 38's end state)

| Item | State | Read |
|---|---|---|
| S1 deploy deal (`DEPLOY_FIT`) | **BLOCKED** (R38.40), OFF | v1, v2, v4, v5 each fail one marginal never-in. v3 passed only on the latch-OFF main; v4 and v5 stack on the latch-ON main |
| S2 latch v2 (`DEPLOY_LATCH` + anchor) | **SHIPPED ON**: b3ad7baa4, main e1f602fbf (R38.38) | S2 v4 passed every line on builder2 at fac47b5d2; main's full check is all judged, perf 1.01x |
| S3 O2 on the settled halt (`PARKED_HOLD`) | **FAILS** Bar S3, OFF | builder0 light, b3ad7baa4 |
| Stretch: re-deals after a loss (`DEPLOY_HOLD`) | **FAILS** Bar H (narrowly), OFF | builder0 light, b3ad7baa4 |

- **Bars H/S3** (builder0 light lane, J4, b3ad7baa4 = the shipped latch, the amended arms (all `--deploy-latch=anchor`), fight
  probe locks/crossing/terminus x 3 squads x click x seeds 3891-3902, 36 fights an arm, n 36/36 started;
  references/round38/settle/hs3-judged-builder0-b3ad7baa4/):
  - **Bar H, held v latch: FAIL.** Parked re-deals 85 -> 54, line <= 51.0 (60 % of 85): it misses by 3, about 64 %.
    Reseats 114 -> 0. Counter >= 10 passes. Fight guards pass: his kills 5.22 -> 5.00, his losses 8.00 -> 7.94, CPU losses
    5.33 -> 5.08 (se 0.33-0.38).
    Per cell: crossing 48 -> 35, locks 12 -> 4, terminus 25 -> 15.
  - **Bar S3, o2 v held: FAIL.** Deciding PASSES: off_idle_s a fight 102.2 -> 31.0 (line <= 51.1; drop 71.3 > 1.645 se 26.7).
    Re-deals FAIL: 54 -> 67 (line <= 62.4; latch alone 85). By cell: crossing 35 -> 45, locks 4 -> 10, terminus 15 -> 12.
    Guard FAIL: his losses 7.94 -> 7.03 (se 0.34), outside the band. The guard as filed is two-sided ("within +/- 1.645 se"), so
    the drop fails it although it means fewer of his tanks lost; failed guards aren't waived. Kills and CPU losses pass.
    Counter parked_returns 38,948.
  - Reading: on the latch, the hold removes the reseats outright and cuts re-deals by 36 %. O2 still adds re-deals on top
    (+13, mostly crossing and locks), so R37.28's "the hold doubles re-deals" shrinks but isn't gone. Round 39 could re-file
    Bar H at the observed size (both are fresh-seed reads, so it needs NEW seeds) or trace o2's crossing re-deals first. That's
    the lead's / orchestrator's call; nothing ships.
- **Merge notes:**
  - What stream/settle adds to main beyond e1f602fbf is OFF-by-default code and its lab tests:
    - `--deploy-fit=street` (`ElementPlan.DEPLOY_FIT_STREET`) and `ElementSituation.street_axis`
    - `--deploy-hold`
    - `tests/test_settle_deploy_fit_v5.gd`
    - the settle-s1v4 and settle-s1v5 targets in mk/settle.mk
    - tests/settle/settle_judge.py's street report and `SETTLE_S1_DECIDING_JUDGED`
    - the references
  - sim-baseline doesn't guard settle's paths: the latch left all 13 maps unmoved. Don't read "unmoved" as settle's check.
  - `ground_seat` is a Callable seam.
  - A light-lane series at J4 needs `TANK_SQUAD_SLOT_TIMEOUT=14400`, passed as a make argument to `tools/remote.sh`.
- **Playtest:**
  - `make skirmish ARENA=terminus`: park 5 squads and watch them settle (the latch is on by default).
  - `--deploy-latch=off` gives round 38's start.
  - `--deploy-fit=street` shows S1's blocked fit. On terminus with a route order, watch the herringbone's tail seat at a
    junction.
- **Questions for the lead:** none blocking. The lane-mouth screenshots stay the lead's call.

### Report (2026-10-22 evening; superseded by the final report above)

**Verdicts (builder2 native, e42ff30eb GREEN; `make native settle-series`, the no-fight probe 12 cells x 3861-3872 = 576 squads
an arm, the fight probe 18 of the re-filed 36 fights, the census; `references/round38/settle/s1s2-judged-builder2-e42ff30eb/`):**
- **S1 DEPLOY_FIT FAILS as filed.** Deciding: squads with a crew moved >= 25 m after the deploy 166 -> 125 (-25 %, line <= 83);
  summed place + twitch 12,022 -> 10,228 m (-15 %); counter 78 of 567 deploys turned. Guard FAIL never-in locks 3 route (1 v 2:
  s3871 squad 1). Guards pass: first shape 8/576, contacts 13,167 -> 13,263 / foreign 6,995 -> 7,427, fights (n 18). Stays OFF;
  the trace of the never-in and of the residual >= 25 m movers comes before any new arm (fresh seeds).
- **S2 DEPLOY_LATCH: deciding PASSES, ONE GUARD FAILS.** Shape flips no-fight 58 -> 0, fight 37 -> 0; reseats 124 -> 0; relays
  206 -> 127 (reported); first shape differs 12/576 (<= 3 %); contacts pass; fights pass (his kills 5.83 -> 6.06, losses 8.11 ->
  7.94, CPU losses 5.83 -> 6.06, n 18). Guard FAIL never-in crossing 5 click (0 v 1: s3866 squad 4 never arrives; it does on
  main). Not waived (R37.17's rule): traced next (builder0 light, `~/settle-keep/neverin/`).
- **S2's re-read (R38.10) FAILS ONE GUARD: first shape.** builder2 native, cbb2ece52 (game code = e42ff30eb's GREEN),
  `make native settle-s2-reread`, chain 17:10-18:07, `references/round38/settle/s2-reread-judged-builder2-cbb2ece52/`.
  Deciding PASSES: shape flips no-fight 56 -> 0, fight (3-squad, n 36) 107 -> 0; reseats 133 -> 0. Never-in (the ruled
  text) PASSES: fresh main 9 v latch 8; pooled 15 v 15. Fights pass, 3-squad and 5-squad (budget 3000, n 36 each); contacts and
  census pass. **Guard FAIL first shape: 18 of 576 differ (line <= 17.3; the first read had 12).** Not waived. What the 18
  are (read after the verdict): 14 coil on main -> herringbone latched (locks and terminus, 4 of them main's flipping
  coil -> herringbone squads: the R37.42 shape the lab test locks); 1 herringbone -> coil (terminus 5 route s3908 squad 4);
  3 are a squad with no halt on one side ('', the never-in rows the never-in guard already counts). S2 stays OFF; the
  orchestrator's call whether the bar stands as filed.
- **S1 v2 (R38.11) FAILS ONE GUARD: never-in 1 -> 2 runs.** builder2 native, cbb2ece52 (game code = e42ff30eb's GREEN),
  `make native settle-s1v2`, 18:07-19:04, `references/round38/settle/s1v2-judged-builder2-cbb2ece52/`. Deciding PASSES:
  squads with a deploy leg >= 25 m 56 -> 10 (line <= 28). Counter 70 of 573 deploys turned. Guards pass: twitch >= 15 m
  95 -> 71, first shape 7/576, contacts 12,183 -> 11,526 / foreign 6,301 -> 6,188, fights 3-squad and 5-squad (n 36 each).
  Reported: place+twitch >= 25 m 153 -> 110. **FAIL never-in:** fit adds crossing 5 route s3931 squad 4. Read after the
  verdict: no deploy in that run turned. Fit still deals every deploy's seats by its own grounded Hungarian, so the
  rows diverge from Charlie's deploy (tick 1090 main, 1120 fit). Squad 4 is a late jam on main too (all-in at 60.5 s,
  the slowest squad of the run); on fit it never gets in. Not waived; S1 stays OFF.
- **S2 v3 (R38.15): the bar's reference chosen, the bar itself waits on its context run.** The re-read's first-shape FAIL stands
  (R38.15). S2 v3 = the same arm, seeds 4001-4012 (no-fight), 4013-4024 (fight3/fight5), census 4001-4003, judged by
  `settle_judge.py s2v3` (`make native settle-s2v3`). The first-shape guard is "first shape WRONG for the terrain at the
  squad's first deploy ANCHOR" (DEPLOY_TRACE anchor_terrain; lanes/dense -> herringbone, open -> coil; no-halt / no-trace
  rows reported, not counted; PASS iff wrong(latch) <= wrong(main)). The orchestrator first proposed the crews' standing
  centroid: rejected because it is main's own centre read (main right by construction). Context run (`settle-s2v3-context`,
  the re-read's seeds, both references) goes on builder2 after S1 v2. Then the bar is committed, then the series runs.
  **For the lead (subjective, later):** the lane-mouth shots
  `references/round38/settle/s2v3-lane-mouth-shots-laptop/` (laptop, 57feb5e17 tree, top-down at arrival + 5 s,
  `locks-3-click-{main,latch}` s3906 squad 3 and `terminus-5-click-{main,latch}` s3912 squad 4; green and blue markers).
  In both a squad stands where a lane opens out: the latch's herringbone hugs the lane edge, main's coil spreads into the
  open. Which one looks right is his call.
- **S1, what the rows say (judged rows, read after the verdict; not a re-judging):** the thing S1 changes, the deploy's own seat
  drive, fell hard: squads whose deploy leg (the longest seat drive at the deploy) is >= 25 m 73 -> 20 (-73 %; latch alone 71).
  The deciding line also counted the crews' movement after the 8 s place window, which S1 does not target: twitch >= 15 m in
  98 squads on main, 79 fit, 105 latch. Its sources (main's 12 worst): GIVEWAY (parked crews stepping aside for others:
  manoeuvre's M5) and long deploy drives still running after 8 s (a 34-55 m leg on the cap). Of fit's 125 long movers 102
  are long on main too; terminus 5 click (the traced cell) has 2. A re-try needs a new bar on fresh seeds (the orchestrator's
  call: deciding = the deploy leg, guards as filed), not a re-reading of these numbers.
- **S2's never-in, traced (b013518a6, `references/round38/settle/s2-neverin-trace-builder0/`):** squad 4's place has a seat 0.4
  m from squad 3's parked back tank (orders' lay, both arms); a 1.5 m seat difference (squad 3 not re-spaced after it parked)
  flips which parked tank gives way: a squad-1 tank steps 20 m aside into the lane and squad 4 never gets within 12 m in 90 s
  (main: in at 33.9 s). The first shape and every other seat are identical. Asked the orchestrator: re-read S2 on fresh seeds,
  or hold for G1. S1's never-in (locks 3 route s3871 squad 1): stuck in both arms (main 82.7 s of 90), never deploys; a
  window-edge flip.
- **The fight probe's 5-squad stop:** `--probe-budget` caps both armies; his 5-squad army costs 2970 ("army costs 2970, over
  the 1500 budget"), so the skirmish never starts. 5-squad fight cells need `--probe-budget=3000` (no code).
- **Two workload defects (re-filed before any fight number):** the fight probe is 3-squad only (54 five-squad fight runs
  stopped at start), so 18 of 36 fights are in and 3879-3884 are owed (`make native settle-fight-topup`); and the CPU census
  is IDENTICAL to the unit in all three arms (contacts 956 / 956 / 956): the deploy step never fires in CPU v CPU fights, so
  the CPU guard is vacuous and these switches act on his crews only.

**S1 the deploy deal (history):**
- **Trace (laptop GDScript e5c436f46, `make settle-trace` / `--deploy-trace`, terminus 5 click s3767, n 1; same seats as
  builder0's c14ec0d80 trace):** the defect is not the deal's cost alone. (1) The deploy lays its halt (a 5-crew herringbone,
  47 m deep at spacing 10) on the click's heading (0.05, -1.0), i.e. ACROSS the east-west street the squad stopped strung
  along, so its end seats stand in the blocks; Element.ground then moves Delta_2's seat from (28.1, 61.1) to (3.3, 63.2), 25 m
  into the next street. (2) The deploy's `_group` runs `fixed` and the early halt-shape seats are the same shape and size, so
  each crew KEEPS ITS SEAT INDEX from the early halt (laid on another heading and anchor) whatever it costs: Delta_2, at the
  east end, keeps the index that is now the far west end. Greedy nearest-first would deal the same seat (the seat is far
  from everyone), so the fix is where the halt is laid and what the deal pays.
- **The change (ac36add58, OFF):** at the deploy (ElementPlan._deploy_fit), the halt is tried on the ordered heading and on
  the squad's own axis (its crews' principal axis when they stand strung along one: spread ratio >= 1.5), each laid as the
  deploy lays it (stepped dry), each dealt by the least total of the drives the crews will make to their GROUNDED seats
  (ElementSituation hands the plan `ground_seat`, Element.ground's grounding); the ordered heading stands unless the axis
  shortens the longest drive by 8 m. The deal seats the deploy's update (in place of the early halt's indices); fixed after.
  Symmetric (CPU deploys too). GDScript only (element_plan has no native twin).
- **Laptop dev read (GDScript, ac36add58 tree, terminus 5 click s3767, n 1; not a judged number):** squad 4 (Delta)
  place + twitch 27.2 + 24.0 = 51.2 m -> 8.8 + 0 m (deploy leg 47.9 -> 12.5 m; ordered lay's grounded worst 34.0 -> 12.6 m
  turned onto the street); squad 1 20.4 -> 8.6 m (turned); squads 2, 3, 5 identical (not turned).
- Lab: `tests/test_settle_deploy_fit.gd` 5/0 (laptop): the traced crews have an east-west axis; across the street the
  nominal deal's worst drive 31.7 m; the fit turns the halt along the street, worst 13.3 m; a squad that fits keeps its
  heading; the deal pays the grounded drive.

- **Checks:** builder0 `make native check` on 39f57e7d6 exited 2 on INFRASTRUCTURE, not code: builder0 load ~20-37; the run
  was `Terminated` at ~82 min (the slot's run cap) with 15 passed, 2 FAILED (test: shards 0/3/4 cut off mid-file, no
  summary; web-smoke terminated mid-export), 8 NOT RUN, perf-judge NOT JUDGED (refused 3x at 2.3-2.5x); every shard that
  finished was 0 failed, sim-baseline 13/13 unmoved. Per R38.2 the next full check (4870d8ebc: S1 + S2 + the hold, all
  OFF) runs on builder2; the series follow on builder0 (`settle-chain2`).
- **Smoke (builder0 light, orders-probe-shots, terminus 5 click seed 34, arrival, desktop; looked at):** main v fit+latch
  identical but the blue squad (bottom), which with the fit stands strung along the east-west street below the blocks
  instead of a north-south clump between them; no hull in a block either way. Frames: ~/settle-keep/shots/.

- **e42ff30eb is GREEN (the orchestrator's ruling, R38.1's rule):** builder2 `make native check exited 2`, 24 passed / 1
  FAILED / 0 NOT RUN / 2 NOT JUDGED (perf-judge: builder2 not a judging machine; scenario_perf: loaded, ref 4.74x); the one
  fail was web-match-smoke's load timing ("first sound 30.6 s after READY (bound 30 s)", load ~30, page 2 fps); re-run
  alone on the same hash: builder2 `make web-smoke exited 0` ("first sound 17.3 s after READY (bound 30 s)", WEB MATCH
  SMOKE PASSED). The diff cannot reach audio or the web path. S1+S2's series runs on it (builder2, J 14).

- **Orders' G1 case (his click, terminus 3 squads s3801, `--group-lay=column`; laptop GDScript, orders 6d72c4dff + this
  branch merged in a scratch worktree, n 1):** squad 2's 11.4 m twitch is a deployed halt flipping herringbone -> coil at
  t=9.4 (terrain read after the deploy), every crew re-dealt 16-20 m. With fit + latch: one deal, herringbone, twitch 0.0 m
  (squad 1 place 27.8 -> 14.6 m). Told orders.

### Plan (ordered; smallest foundation first)
1. S1 + S2 (one series, one base): bars (filed below) -> quick-remote -> one builder0 full check on the named hash -> `make native settle-series` -> verdict;
   a pass flips DEPLOY_FIT ON (symmetric, his and the CPU's) on a new hash with its own full check.
2. S2 latch v2: lab of test_tactics_scenarios_2's geometry first (must form herringbone); arm = the deploy latches the
   terrain its shape was decided on (at all-in) inside the deploy state (element_plan, mine: no element.gd edit); bar with the
   first-shape guard (C38.1); fresh seeds.
3. S3 O2's re-deals: TRACED (below): terrain re-spacing (S2) + losses (the stretch's hold, built). `make native settle-s3`
   after S2's verdict: Bar H and Bar S3.
4. Stretch: re-deals after a loss: DEPLOY_HOLD built OFF, judged as Bar H in settle-s3.
Decisions: the axis candidate (not a search over many headings): the squad already stands along the ground it fits on, and
two candidates keep the deploy cheap and its choice explainable; 8 m gain so a squad that fits keeps the heading he gave.

### Bar S1 DEPLOY_FIT (filed 2026-10-22 before any judged number; code ac36add58 + the series tooling)
What he would see: when a squad stops, every tank settles into a spot near where it stopped; no tank drives across or out of
its own squad to reach a seat. **Arms:** `main:--deploy-trace` v `fit:--deploy-fit=on,--deploy-trace`, one tree, builder0
native, on a hash whose builder0 full check is green; `make native settle-series` (mk/settle.mk), judge
`tests/settle/settle_judge.py s1`. **Workloads, FRESH seeds:** the no-fight probe, 12 cells (locks/crossing/terminus x 3/5
squads x click/route) x 3861-3872; the fight probe (`--probe-fight=on --probe-budget=1500`, the 3 maps x 3/5 squads x click)
x 3873-3878 (36 fights an arm); the CPU census (traffic-census' 3 default cases) x 3861-3863. **Counter:** deploys turned > 0
on the arm (DEPLOY_TRACE) and rows differ. **Deciding (a stopped crew's longest post-arrival drive):** per squad place_m +
twitch_m (the most any crew moved after the deploy began); squads with >= 25 m, summed over the no-fight probe: arm <= 50 %
of base, base >= 10 (else "no workload"), and the summed place + twitch lower. **Guards:** per cell (orders' probe_guards,
settle mode): all-in median <= base x 1.2 + 3 s, never-in no more, place + twitch median <= base + 3 m, end foreign min >=
base - 3 m, crossed no higher; **the first shape:** squads whose halt shape differs from base's <= 2 % (the shape choice is
not touched); friend_contacts and friend_contacts_foreign summed <= base x 1.1 + 5; fights: his kills, his losses, the CPU's
losses a fight each within base +/- 1.645 se (base sd, n 36); CPU: friendly contacts <= base x 1.1 + 5, stuck s <= base x
1.2 + 10. **Reported:** relays, shape flips, parked re-deals, redealt; the fight probe's >= 25 m squads. **A pass ships ON**
(symmetric); `--deploy-fit=off` keeps today's. sim-baseline maps that move are attributed with the switch OFF.

### Bar S2 DEPLOY_LATCH (latch v2; filed 2026-10-22 before any judged number; code 44505a21c)
What he would see: a squad he parked keeps one shape and its spots; it never opens into a ring that doesn't fit the lane it
stopped in. **The change:** the deploy records the live terrain read at its all-in (or cap), where it decides the halt's
shape, and every later update of that deployed halt plans with it (shape and spacing); before the deploy the live read
stands (main's). Plain AUTO moves (the deploy step's scope), every side. Lab `tests/test_settle_deploy_latch.gd` 3/0 (R37.42's
geometry: round-37 latch coil + 4 late orders, deploy latch herringbone + 0; creep lab: centre 2 flips, latched 0).
**Arms:** `main:--deploy-trace` v `latch:--deploy-latch=on,--deploy-trace`, run in the SAME `make native settle-series` as
S1 (one base for both arms, the same fresh seeds and workloads as Bar S1). **Counter:** rows differ and base shape flips
(no-fight + fight probe) >= 10. **Deciding:** shape flips after the place window summed, no-fight probe arm <= 25 % of base
(+1) AND fight probe arm <= 25 % of base (+1); reseats no more than base. **Guards:** Bar S1's, the first-shape line read on
each squad's FIRST halt shape (the property latch v1 broke: differs from main's in <= 3 % of squads), plus the full check
(test_tactics_scenarios_2 runs in it) on the hash. Note: the probe's `relays` read ElementSituation's terrain, which this arm
does not change, so relays are reported, not judged. **A pass ships ON** (`--deploy-latch=off` keeps today's).

### S3 trace: O2's re-deals (builder0 light, native, 44505a21c tree, all switches OFF but --parked-hold=on; crossing 3 click
s3747 and s3748, the fight probe, n 1 each; `make settle-trace` with `--arrive-trace --element-trace=Alpha`;
`references/round38/settle/o2-redeal-trace-builder0/`). s3747 reproduces orders' run (the same NATIVE_EXEC count).
- **Not the returning crew.** Alpha's re-deals are of two kinds: (a) `drift` goal moves on the same anchor and seat index
  at t=79, 101, 106, 109, 111 with no loss, beside 4 relays: the terrain read flips as crews move in the fight (parked hold
  keeps them on posts, so the centroid creeps across a feature line) and the deployed halt is re-SPACED, moving seats 7-14 m:
  what S2's deploy latch removes; (b) a LOSS (t=117, Alpha_2): the halt is laid again at the smaller size and three
  survivors are re-seated 11-18 m: what the stretch's DEPLOY_HOLD removes. Laptop GDScript, the same cell: the re-deals
  came at the two losses (t=77, 102). Why parked hold doubles them: with crews held on their posts, more of them are
  "parked" (>= 2 s on the station) when a re-lay lands, so the probe counts them; without it, they were off fighting.
- **With both (`--deploy-latch=on --deploy-hold=on`, same tree, builder0 light, n 1 each; the fights diverge):** parked
  re-deals s3747 7 -> 3, s3748 2 -> 0; Alpha's reseat moves 3 -> 0; one 14.3 m drift remains after a loss (residual, untraced).
- **DEPLOY_HOLD (8bd480f96, OFF):** while every crew of a deployed halt is one the deploy dealt, a smaller squad (a loss)
  stands on its own dealt seats (seat, sector, order kept) and the shape keeps its name; a crew joining re-lays as before.
  Lab `tests/test_settle_deploy_hold.gd` 1/0 (laptop): one of five lost, survivors' worst seat move 16.7 m -> 0.0.
- native (godot-native-fb, written audit on 8bd480f96): no twin needed for S1, S2 or the hold.

### Bar H DEPLOY_HOLD and Bar S3 O2-ON-SETTLE (filed 2026-10-22 before any judged number; code 8bd480f96)
`make native settle-s3`, judge `settle_judge.py s3`: the fight probe only (locks/crossing/terminus x 3/5 squads x click),
FRESH seeds 3891-3896 (36 fights an arm), builder0, a green-checked hash, run AFTER S2's verdict. Arms: `latch`
(--deploy-latch=on), `held` (+ --deploy-hold=on), `o2` (+ --parked-hold=on). If S2 fails, the arms drop the latch and the
bars are re-read on the same seeds with the base `main` (said in the verdict, before the run).
- **Bar H (held v latch).** What he would see: when a parked tank is killed, the rest of the squad stays where it is.
  Counter: latch's parked re-deals >= 10. Deciding: parked re-deals summed held <= 60 % of latch AND reseat goal moves no
  more. Guards: his kills, his losses, the CPU's losses a fight within latch +/- 1.645 se. A pass ships ON.
- **Bar S3 (o2 v held).** What he would see: a squad he parked stays where he put it and shoots from there, and nobody in
  it gets sent to a new spot. Deciding: R37.13's line (off_idle_s a fight o2 <= 50 % of held AND the drop > 1.645 se) AND
  parked re-deals o2 <= held x 1.1 + 3 (R37.28's "no higher beyond noise", now against the settled halt). Counter:
  parked_returns > 0. Guards: the kills / losses lines v held. A pass ships O2 ON with latch v2 and the hold (his crews only:
  PARKED_HOLD is player-only), the seam in tank_brain.gd unchanged (orders' code; merge note to doctrine).

**Amended 2026-10-23 before any S3 number (S2 passed as v4, R38.33):** every arm's latch is the shipped anchor latch
(`--deploy-latch=anchor`; since b3ad7baa4 `=on` means v2's centroid read, which did not ship). The "if S2 fails" clause is
moot. Bar S3's ship line reads "with the anchor latch and the hold". Seeds, cells, lines and the judge are unchanged. It
runs on the latch-ON hash once that hash's full check is green.

### Re-filed before any fight number (2026-10-22): the fight workloads
The fight probe runs only the 3-squad army: every 5-squad fight run of the S1+S2 series (e42ff30eb, builder2) stopped at
start ("no RtsControls (TacticalMap)", 54 of 108). Orders' own fight bars used 3 squads only; mine was mis-filed. Re-filed
BEFORE reading any fight number: Bar S1 / S2's fight read = locks/crossing/terminus x 3 squads x click x seeds 3873-3884 (36
fights an arm; 3873-3878 already ran, 3879-3884 run as a top-up on the same hash, the two halves read together); Bar H / S3
= the same 3 cells x 3891-3902 (36 fights an arm). The no-fight probe and the census are read as filed.

### R38.10: S2's re-read, once (filed by the orchestrator before numbers)
Same arm (`latch:--deploy-latch=on`), same bar, FRESH seeds: the no-fight probe 12 cells x 3903-3914; the fight read = the
3-squad cells' top-up 3879-3884 (read with the first read's 3873-3878: 36 fights) + the 5-squad cells at --probe-budget=3000 x
3873-3884 (36 fights); the census x 3903-3905. **The never-in guard (the orchestrator's text):** latch <= main on the fresh
seeds AND latch <= main + 1 pooled over both reads (s3866 stays counted). Every other line as filed. If the overlap never-in
repeats, S2 fails until orders' lay stops placing spots on parked tanks. `make native settle-s2-reread` (mk/settle.mk), queued
on builder2 behind doctrine's D2 series (builder0 full: feedback's check, orders' G1, manoeuvre's jam census).

### Bar S1 v2 DEPLOY_FIT (R38.11; filed 2026-10-22 before any number on its seeds; code = ac36add58's, unchanged)
What he would see: when a squad stops, no tank is sent across or out of its squad to reach its seat. **Why a v2:** the line was
chosen after seeing e42ff30eb's rows (the deploy leg fell 73 -> 20 there), so those rows count for nothing; judged only on seeds
never read for S1. **Arms:** `main:--deploy-trace` v `fit:--deploy-fit=on,--deploy-trace`, one tree, a green-checked hash.
`make native settle-s1v2`, judge `settle_judge.py s1v2`. **Workloads, FRESH:** the no-fight probe 12 cells x 3921-3932; the
fight probe 3-squad cells (budget 1500) and 5-squad cells (`--probe-budget=3000`) x 3933-3944 (36 fights an arm each).
**Counter:** deploys turned > 0. **Deciding:** squads with a deploy leg (the longest drive from where a crew stood when the
deploy began to its seat) >= 25 m: arm <= 50 % of base, base >= 10. **Guards:** squads with twitch >= 15 m not up (arm <=
base); never-in runs arm <= base (R38.10's form, fresh seeds only); first shape differs in <= 3 % of squads; friend_contacts
and friend_contacts_foreign <= base x 1.1 + 5; fights: his kills, his losses, the CPU's losses a fight within base +/- 1.645 se
in each fight read, and no fight run that never starts. **Reported:** place + twitch >= 25 m squads. No CPU census (vacuous:
the deploy step never fires in CPU v CPU fights, R38.9). Queued on builder2 behind S2's re-read. **A pass ships ON.**

### Bar S1 v3 DEPLOY_FIT (R38.17; filed 2026-10-22 before any number on its seeds; code = this commit)
The fit keeps main's deploy byte for byte unless it turns (only the `fit` measurement is added), so only turned squads can
differ. Pinned by `tests/test_settle_deploy_fit_v3.gd` (a deploy not turned: every plan identical to main's; the traced
squad still turns and keeps its deal). Laptop dev (not judged): crossing 5 route s3931, S1 v2's never-in run, rows
main v fit identical, 5 of 5 squads, 0 deploys turned. Arms `main:--deploy-trace` v `fit:--deploy-fit=on,--deploy-trace`.
Seeds never read for S1 (the workstreams registry): no-fight probe 12 cells x 4201-4212; fight probe 3-squad (budget 1500)
and 5-squad (budget 3000) click cells x 4213-4224. **Lines exactly as S1 v2** (`settle_judge.py s1v2`): counter = deploys
turned > 0; deciding = squads with a deploy leg >= 25 m, base >= 10 and arm <= 50 % of base; guards: twitch >= 15 m squads
not up, never-in runs arm <= base, first shape differs <= 3 %, friend contacts and foreign <= 110 % + 5, fights (his kills,
his losses, CPU losses within 1.645 se, 0 runs that never started) in both fight reads. `make native settle-s1v3`, builder2,
queued after doctrine's D2b (R38.17's order).

### Bar S2 v3 DEPLOY_LATCH (R38.15; filed 2026-10-22 after its context run, before any number on its seeds)
Arms `main:--deploy-trace` v `latch:--deploy-latch=on,--deploy-trace` (latch code unchanged since 44505a21c; the tree adds
only S1 v3's fit change, OFF in both arms, and the trace lines). Seeds never read for S2: no-fight probe 12 cells x
4001-4012; fight probe 3-squad (budget 1500) and 5-squad (budget 3000) click cells x 4013-4024; census x 4001-4003.
`make native settle-s2v3`, judge `settle_judge.py s2v3` (SETTLE_V3_REFERENCE=anchor, the default).
- Counter, deciding: as filed for S2 (rows differ and base flips >= 10; flips no-fight and in the 3-squad fight <= 25 % of
  base + 1; reseats no more).
- **Guard first shape (R38.15):** wrong = the squad's first standing shape (row shapes[0]) is not the table's shape on the
  terrain at its first deploy ANCHOR (DEPLOY_TRACE anchor_terrain; lanes/dense -> herringbone, open -> coil). No-halt and
  no-trace rows reported, not counted. PASS iff wrong(latch) <= wrong(main).
- Never-in: latch <= main, total over the fresh seeds. Every other per-cell probe guard, contacts, fights (both reads, 0
  runs that never started), census: as filed.
**Context (NOT on the v3 seeds; the re-read's seeds 3903-3914 again, builder2 91a681712,
`references/round38/settle/s2v3-context-builder2-91a681712/`):** reproduces the re-read (first shape differs 18/576, same
shape counts). Anchor reference: main 13 wrong, latch 16 (the latch's: 10 herringbone where the anchor is open, all on locks; 6 coil where it is lanes, 3 locks, 3
terminus). Stand reference: main 0 (its own read), latch 13.

**S2 v3 WITHDRAWN before numbers (R38.19).** The series started on builder2 at 19:33 (79a9f83bf) and was stopped at the
orchestrator's word before any row on 4001-4024 was read (the local copy deleted unread). Its context (anchor: main 13 v
latch 16) showed the latch's own read, the crews' all-in centroid, is the weakness. Next: S2 v4 (the latch holds the
terrain at the deploy anchor), lab first, a new bar on fresh seeds, queued after doctrine's D2b and before S1 v3.

### Bar S2 v4 DEPLOY_LATCH at the anchor (R38.19; filed 2026-10-22 before any number on its seeds; code = this commit)
The latch holds the terrain AT THE HALT'S ANCHOR (`--deploy-latch=anchor`, ElementPlan.DEPLOY_LATCH_ANCHOR). At the deploy
the anchor is laid on the live read's shape; if the ground at it reads otherwise, shape and anchor are laid again on that
read (at most DEPLOY_LATCH_LAYS = 3). The deploy's own update and every later one plan with it. Lab
`tests/test_settle_deploy_latch_anchor.gd`: locks 3 click s3906 squad 3, the centroid latch holds lanes and a herringbone
at an open anchor (the counter), the anchor latch holds open and stands a coil; R37.42's lane still a herringbone (quiet, in
its slots). Laptop dev, not judged: locks + terminus x 3/5 squads click x s3906-3907, wrong for the anchor's terrain main 2,
centroid latch 5, anchor latch 0 (laptop glibc 2.39 v builders' 2.43 round atan2f etc. differently, R38.25: in jams the
laptop's rows are not comparable to builder rows; nothing judged here came from the laptop).
Arms `main:--deploy-trace` v `anchor:--deploy-latch=anchor,--deploy-trace`. Seeds never read for S2: no-fight 12 cells x
4301-4312; fight 3-squad (budget 1500) and 5-squad (budget 3000) click cells x 4313-4324; census x 4301-4303.
`make native settle-s2v4`, judge `settle_judge.py s2v3` with SETTLE_SHAPE_JUDGED=0. **Lines (R38.20, amended before any
number):** counter and deciding as S2; never-in total arm <= base; every other per-cell probe guard (all-in, place+twitch,
end foreign, crossed); contacts; fights (both reads, 0 runs that never started); census; and R37.42's tests
(test_settle_deploy_latch, test_settle_deploy_latch_anchor) green in the full check. **First shape against the anchor's terrain
is REPORTED for both arms, not judged** (R38.20: the arm latches the read it would be judged by). Also reported: the
deploy re-lays (DEPLOY_TRACE latch_lays) and every deploy that hits the 3-lay cap (latch_capped). Queued on builder2 after
doctrine's D2b, before S1 v3 (R38.19).
**Caveat, said before numbers (why R38.20 reports it):** v4 latches the very read the first-shape guard judges by. Its own wrong count is ~0 by
construction, except a shape that changes after the deploy or a re-lay whose anchor never settles. So that guard can hardly
fail v4. Whether herringbone or coil looks right at a lane's mouth stays the lead's eye
(`references/round38/settle/s2v3-lane-mouth-shots-laptop/`).

### S2 v4 verdict: PASSES every series line; R37.42's tests in the full check still to come (builder2 native, fac47b5d2)
`make native settle-s2v4`, builder2 (e2-highcpu-32), jobs 14, beside main's native check; the no-fight probe 12 cells x
4301-4312 = 576 squads an arm, fight 3-squad x 4313-4324 (n 36 an arm) and 5-squad budget 3000 (n 36), census 4301-4303 (9
fights). Arms main:--deploy-trace v anchor:--deploy-latch=anchor,--deploy-trace. `references/round38/settle/s2v4-judged-builder2-fac47b5d2/`.
- Counter PASS: base shape flips 84 (no-fight + fight). **Deciding PASS:** shape flips no-fight 51 -> 0 (line <= 13.8), fight
  33 -> 0 (<= 9.2); reseats 89 -> 0.
- Guards PASS: never-in 5 -> 5 runs; every other per-cell probe guard (12 cells); friend contacts 12,435 -> 11,762, foreign
  6,702 -> 6,302; fights 3-squad (his kills 5.53 -> 5.42, his losses 6.97 -> 7.00, CPU losses 5.58 -> 5.47 a fight) and 5-squad
  (9.14 -> 9.31, 13.31 -> 12.53, 9.28 -> 9.44), 0 runs that never started; census friendly contacts 701 -> 701, stuck 1452.3 ->
  1452.3 s.
- Reported (R38.20): first shape wrong for the anchor's ground 10 -> 0 (main: 6 coil-on-lanes, 4 herringbone-on-open; locks
  and terminus 5-squad); relays 178 -> 94; parked re-deals 411 -> 405; deploy re-lays 93 over 571 deploys, 2 at the 3-lay cap
  (crossing 3 route s4305 Charlie, crossing 5 route s4306 Charlie).
- **ON hash b3ad7baa4** (DEPLOY_LATCH + DEPLOY_LATCH_ANCHOR default ON; `--deploy-latch=off` = round 38's main, `=on` =
  v2's centroid read). Full `make native check` on builder0 (glibc 2.43), 3804 s, beside other streams' series: 25 passed,
  2 NOT JUDGED (perf-judge refused 3 times on a busy box, ratios 2.47x/1.93x/2.14x; ai-scenarios-check's scenario_perf,
  unpinned hybrid). test 3070 passed, 0 failed, including test_settle_deploy_latch (3), test_settle_deploy_latch_anchor
  (2) and test_tactics_scenarios_2::test_a_move_ends_formed_up_on_the_spot_and_stops_issuing (R37.42). sim-baseline:
  all 13 maps unmoved. The 2 NOT JUDGED are not passes: perf-judge needs a run on a quiet box.
- **Shipped (R38.38):** merged as main e1f602fbf; main's full check on builder0 is green and ALL JUDGED: 27 targets,
  3104 passed / 0 failed, perf-judge PASS 7,077 us/tick (ratio 1.01x; 7,060 before the latch), sim-baseline unmoved.

### S1 v3 verdict: PASSES as filed (builder2 native, 4ec06dd97 = fac47b5d2's code; latch OFF on both arms)
`make native settle-s1v3`, builder2 (e2-highcpu-32), jobs 14; no-fight probe 12 cells x 4201-4212 = 576 squads an arm, fight
3-squad and 5-squad (budget 3000) x 4213-4224 (n 36 each). `references/round38/settle/s1v3-judged-builder2-4ec06dd97/`.
- Counter PASS: 70 of 570 deploys turned. **Deciding PASS:** squads with a deploy leg >= 25 m 57 -> 18 (line <= 28.5).
- Guards PASS: twitch >= 15 m squads 111 -> 79; never-in 5 -> 4 runs; first shape differs 10 of 576 (<= 3 %); contacts
  12,652 -> 12,025, foreign 6,874 -> 6,647; fights 3-squad (his kills 5.22 -> 5.28, his losses 8.44 -> 8.25, CPU losses
  5.33 -> 5.39) and 5-squad (8.83 -> 8.81, 15.83 -> 16.08, 9.08 -> 9.00), 0 runs that never started.
- Reported: place+twitch >= 25 m squads 163 -> 116.
- Not yet: the full check of an ON commit. Note for the ON: it was judged with the latch OFF; on a latch-ON main the fit
  lays on the anchor-latched read (`_deploy_state`: re-lay first, then the fit), a combination no judged number covers.

### Bar S1 v4 DEPLOY_FIT on the latch (R38.34; filed 2026-10-23 before any number on its seeds; code = this commit)
The fit (S1 v3, passed) stacked on the shipped anchor latch: arms `main:--deploy-trace` v `fit:--deploy-fit=on,--deploy-trace`,
BOTH latch-ON (DEPLOY_LATCH + DEPLOY_LATCH_ANCHOR, the default since b3ad7baa4; this tree's code = b3ad7baa4's). Seeds
never read (registered by the orchestrator): no-fight probe 12 cells x 4401-4412, fight 3-squad (budget 1500) and 5-squad
(budget 3000) click cells x 4413-4424. `make native settle-s1v4`, builder2, judge `settle_judge.py s1v2` with
SETTLE_S1_DECIDING_JUDGED=0. **Judged, as filed for S1 v2:** the counter (deploys turned > 0: without a turn the run says
nothing); twitch >= 15 m squads not up; never-in runs arm <= base; first shape differs <= 3 %; friend contacts and foreign
<= 110 % + 5; fights (his kills, his losses, CPU losses within 1.645 se, 0 runs that never started) in both fight reads.
**Reported, not judged:** the deciding line (deploy leg >= 25 m squads) and place+twitch >= 25 m. A pass ships S1 ON on a
new hash, with one full check (R38.34).

### S1 v4 verdict: FAILS on the never-in guard (builder2 native, fdeb18ce6 = b3ad7baa4's code; both arms latch-ON)
`make native settle-s1v4`, builder2, jobs 14; no-fight 12 cells x 4401-4412 = 576 squads an arm, fights 3-squad and 5-squad
x 4413-4424 (n 36 each). `references/round38/settle/s1v4-judged-builder2-fdeb18ce6/`. S1 stays OFF.
- Counter PASS: 71 of 573 deploys turned. Reported deciding: deploy leg >= 25 m squads 62 -> 29 (S1 v3's line <= 31.0).
- **Guard FAIL never-in: 3 -> 4 runs.** The three of main's are shared by both arms (crossing 5 route s4412 squad 4, locks
  3 route s4406 squad 1, terminus 5 route s4401 squad 5). The new one: **terminus 5 route s4410 squad 5 (Echo)**, in at
  67.8 s on main, never in on fit. Its deploy trace: Delta's deploy (tick 1359, the cap) turned on fit (leg 42.8 -> 15.9 m)
  and Charlie's crews twitched 0 -> 11.2 m; Echo (anchor 53.1, 43.0) never deploys.
- Guards PASS: twitch >= 15 m 98 -> 91; first shape differs 1 of 576; contacts 12,995 -> 12,438, foreign 7,289 -> 6,961;
  fights 3-squad (his kills 5.44 -> 5.31, his losses 6.50 -> 6.61, CPU losses 5.50 -> 5.33) and 5-squad (10.36 -> 10.39,
  12.61 -> 13.00, 10.50 -> 10.56), 0 runs that never started.
- Reported: place+twitch >= 25 m 165 -> 143.
- **Trace (builder0 light, native, b3ad7baa4 tree = the run's code, n 1 per arm; reproduces the judged rows exactly;
  `references/round38/settle/s1v4-neverin-trace-builder0/`): it is the FIT, not a chained give-way.** No give-way at all
  (NATIVE_EXEC yielding 0); Echo's four crews hold live move goals and stand still from 50 s to 70 s at x 0-10, y 69-85.
  Delta's capped deploy (45.3 s) turned from (0.98,-0.19) to (0.48,0.88), 72 degrees, and its crews settle by 50 s (fit's
  gain: leg 42.8 -> 15.9 m) on seats D1 (4.2,60.4), D2 (13.3,88.0), D3 (27.8,87.1), D4 (36-42,87-90), across the lane
  mouth Echo still has to drive through. On main the same Delta is still re-forming there until ~60 s and Echo is through
  by 55-60 s (in at 67.8 s). Echo_3 never moves again; the run ends with Echo never in.
- Across the series (fit arm, 576 squads): of the 71 turned deploys, 66 are herringbones (52 in lanes, 14 dense) and 5
  coils. The turned herringbones' angle from main's heading has median 71 degrees (54 of 64 turned >= 45 degrees): the fit
  mostly lays a lane herringbone ACROSS its ordered axis. That is the S1 v5 candidate (orchestrator's call): a herringbone
  turns at most ~30 degrees off main's heading (the lane's axis), or the turned seats are priced against the passage.


### Bar S1 v5 DEPLOY_FIT with the street cap (R38.37; filed 2026-10-23 before any number on its seeds; code = this commit)
A herringbone's turn must land within 30 degrees of the street's axis (ElementSituation.street_axis at the deploy's anchor:
the heading of the longest clear run, null where none is 1.3x the shortest); no street, no limit; coils turn freely
(`--deploy-fit=street`, ElementPlan.DEPLOY_FIT_STREET). Lab `tests/test_settle_deploy_fit_v5.gd` (laptop, pure, terminus):
the street at (23.5, 85.65) runs east-west; s4410's Delta turns without the cap (the counter) and keeps main's heading
with it; the R37.37 across-the-street squad still turns (worst drive 31.7 -> 13.2 m), along the street, and keeps its
deal; open ground has no street. Base = the latch-ON main (e1f602fbf merged). Arms `main:--deploy-trace` v
`fit:--deploy-fit=street,--deploy-trace`. **Seeds 4501-4524 (registered, R38.37):** no-fight 12 cells x 4501-4512, fight
3-squad (budget 1500) and 5-squad (budget 3000) click cells x 4513-4524. `make remote LIGHT=1 T="native settle-s1v5"`,
builder0 light lane, J 4. Judge `settle_judge.py s1v2`, SETTLE_S1_DECIDING_JUDGED=0. **Lines exactly S1 v4's:** judged:
counter (turned > 0), twitch >= 15 m not up, never-in arm <= base, first shape differs <= 3 %, contacts and foreign
<= 110 % + 5, fights (both reads, 1.645 se, 0 runs that never started). Reported: deciding (deploy leg >= 25 m),
place+twitch, and (R38.37) the street axis set v null and the turns refused, per cell. A pass ships S1 ON (both switches)
on a new hash with one full check.
`make quick-remote` on e81b57579 (builder0): 100 scripts lint-parse, 122 passed, 0 failed (the diff's tests, settle's and tactics').
Series run 1 (builder0 light J4, e81b57579, 2026-10-23 03:23-04:53): NO VERDICT. slot.sh's default 5400 s limit killed it in the
5-squad fight (probe and fight3 were complete; nothing was judged or read). It is rerunning unchanged, with
`TANK_SQUAD_SLOT_TIMEOUT=14400`, at 6c3112193 (a docs-only change from e81b57579). The J4 series runs past 90 min, so any light-lane
series needs that knob.

### S1 v5 verdict: FAIL (builder0 light J4, 6c3112193 = e81b57579's code, n 576 squads/arm; references/round38/settle/s1v5-judged-builder0-6c3112193/)
FAILS the never-in guard 3 -> 4, the same guard and the same cell class as S1 v4: S1 stays OFF. Every other judged line passes:
the counter (51 of 572 deploys turned), twitch >= 15 m 96 -> 78, first shape 1 of 576, friend_contacts 11,996 -> 11,715 and
foreign 6,622 -> 6,370, and both fight reads (n 36/36). Reported: deploy legs >= 25 m 63 -> 33; place+twitch >= 25 m 169 -> 141.
The street axis was set on all 504 herringbone deploys (null 0), and the cap refused 23 turns.
- Never-ins (the no-fight probe, which the guard judges): main and fit share three at crossing 5 (click s4505 squad 4, route s4507
  squad 4, route s4508 squad 5). The fit adds **terminus 5 route s4505, Echo**: main's Echo is in at 42.2 s (window 90 s), the
  fit's never is (driven 120 m, ends 30.9 m off its anchor). The fit turned Delta's lane herringbone (anchor 21.5,84.5) to
  heading (0.93, 0.38), along the street and inside the cap (not refused), ordered worst 38.0 -> 14.7 m. So the street cap
  does not cover this case. A trace (both arms, builder0 light) is under way before H/S3.
- Orders' R38.39 note (main's never-ins pile up at crossing's west bridge mouth): the three shared ones are crossing. The fit's
  extra never-in is terminus, and main gets that squad in on this seed, so the note doesn't explain it.
- **The s4505 trace** (builder0 light, 6c3112193, n 1 per arm, `--element-trace=all --arrive-trace --probe-trace=5`; it
  reproduces: the fit arm has 4 deploys and Echo is never in; references/round38/settle/s1v5-s4505-trace-builder0/). Echo's
  route runs west along the E-W street past Delta's halt (anchor 21.5,84.5), then turns south into the N-S lane at x≈2
  ((2.8,72.1) -> (2.3,51.3), 26-32 m wide).
  - **Fit:** Delta's turned herringbone lies along the street, so its tail seat Delta_1 lands 23.7 m west of the anchor at
    (-2.3,79.9), on the junction. Delta_3 is in its seat at (5.9,61.5), inside the lane mouth. That seat is slot (3.7,67.8),
    asked (17.3,69.8) and relaid onto the ground. From t=36 to the end at 90 s, Echo_1 is stuck at (5.6,70.3), Echo_3 at
    (0.9,76.3) and Echo_2 at (-5.4,80.0), between those two Delta crews. Nothing gives way.
  - **Main:** Delta's herringbone runs north-south, so no tail seat lands on the junction. Delta_3 gets the same relaid
    lane-mouth slot (3.7,67.8), but at t=40 it is 26.9 m off it, down the lane at (-5.4,42.5). Echo gets past and is in at
    42.2 s.
  - **Cause:** S1 v4's failure was a deploy turned across the street. This one is turned along it, inside the cap. In both, a
    halt seat lands on the route the next squad of the same order still has to drive. Here it's the junction and lane mouth,
    which a seat main already relays there helps close. So the shape's angle isn't the variable; the route still to be
    driven is.

### S1: BLOCKED for round 38 (R38.40)
No S1 v6 this round. S1 failed v1, v2, v4 and v5, each by one marginal never-in, and three of them were a following squad that
couldn't pass a squad deploying ahead of it on terminus 5 route. Another tweak would be fitting to the guard. `DEPLOY_FIT` and
`DEPLOY_FIT_STREET` stay OFF and in the code (`--deploy-fit=on|street`). `ElementSituation.street_axis` and its tests stay; they
cost nothing while it's OFF.
**Round-39 candidate (the orchestrator's framing, corrected by the s4505 trace):** no seat of a deploying squad may land on the
route that a following squad of the same order still has to drive, at any shape and any angle. "Across a lane" is too narrow:
s4505's blocking seats are along the street, at the junction and lane mouth. The rule must also cover main's own relaid seats
(s4505's Delta_3 slot at (3.7,67.8) is main's). Pair it with manoeuvre's chain-aware give-way, then re-read S1 on top.

### Requests / cross-stream notes (round 38)
- orders (godot-orders-93, 4a765e6e2, laptop GDScript): s3866's overlap is today's body (main's 6.3 m pair, squads 3/4); under G1's
  column all five places are >= 22 m apart and all in by 9.6 s. Orders owns "a place never lands on another squad's halt" as
  G3, after G1's verdict. The probe's budget-refusal print lands after orders' series.
- manoeuvre via the orchestrator (stream/manoeuvre e55cba940, builder0 light native, n 1 per arm,
  references/round38/manoeuvre/s3866-giveway/README.md): crossing 5 click s3866, seatstep OFF, squad 4 is in at 33.9 s on main
  and NEVER in under both --deploy-latch=on and =anchor (identical rows). Cause: a chained give-way (Alpha_3 gives way four
  times in 10 s to squad-4 crews, seat distance 2.9 -> ~20 m), not the latch's pick; seatstep ON gets squad 4 in on every arm.
  s3866 is outside S2 v4's seeds, so the bar is unchanged. **If v4's never-in fails, check the failing run for this chained
  give-way first** (manoeuvre proposes a chain-aware give-way next round).

### Questions for the lead
None.

### Requests to other streams
None yet. Merge note (C38.3): `ElementSituation.build` adds a `ground_seat` Callable to every element situation (orders and
doctrine read situations; nothing iterates its keys).
Round-close note (R38.33's merge, main e1f602fbf): **sim-baseline is not a guard for settle's paths.** With the latch ON, all 13
maps were unmoved (b3ad7baa4, builder0): the baseline maps never reach a deploy halt that the latch changes. Settle's changes
are guarded by its own series (orders-probe, fight probe, census) and the tests.
