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

### Report (2026-10-22 evening; still working: S2's never-in trace, then H/S3)

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

### Requests / cross-stream notes (round 38)
- orders (godot-orders-93, 4a765e6e2, laptop GDScript): s3866's overlap is today's body (main's 6.3 m pair, squads 3/4); under G1's
  column all five places are >= 22 m apart and all in by 9.6 s. Orders owns "a place never lands on another squad's halt" as
  G3, after G1's verdict. The probe's budget-refusal print lands after orders' series.

### Questions for the lead
None.

### Requests to other streams
None yet. Merge note (C38.3): `ElementSituation.build` adds a `ground_seat` Callable to every element situation (orders and
doctrine read situations; nothing iterates its keys).
