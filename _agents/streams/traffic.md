# Stream: traffic (two of your squads meeting in a street take turns: one waits beside the mouth, nobody locks up)

> Read `_agents/orchestration.md` (the worker contract; lessons 295–303), `_agents/game_design.md` *Round 26 direction*
> and *Round 28 direction* (his call 1), `_agents/workstreams.md` **Round 29** (C29.1–C29.8), and round 28's traffic report
> (`streams/archive/round28/traffic.md`: *FINAL REPORT*, *T1b*, **ROUND 29, ITEM 1**: your design). **You own:**
> `game/ai/avoidance.gd`, `game/ai/steering.gd`, `game/ai/traffic*.gd`, in `game/ai/movement.gd` the give-way block
> (`right_of_way` through `_blocker`), `_avoid`, `_around_friends`, `_ask_behind`, `_hull_within`; `tests/test_traffic*.gd`,
> `tests/traffic/**`, `tests/ai_scenarios/scenario_traffic*.gd`, `tests/test_avoidance.gd`, `mk/traffic.mk`. **Granted
> (C29.3):** one additive gate line each at brains' `_track_progress`, `_update_phase`, the element's make-room / re-seat
> clock, and manoeuvre's `unstick`, `_pressing_escape`, the k-turn entry. **The C++ (C29.2):** `right_of_way`, `_avoid`,
> `Avoidance.solve` have C++ twins; develop on the GDScript path, send native the settled diff before the commit.

## The lead's direction

Round 26: *"if I take 2 squads and have them move in opposing directions such that they have to cross each other … vehicles
will get stuck bumping into each other … people would just generally each turn to the right in order to deconflict. The
same case might not be said if we're charging toward an enemy."*
**Round 28, his call (2026-10-12): TAKE TURNS:** "fewer bumps; both squads arrive a little later." The pass line may
trade some arrival time for fewer bumps, and never crews that fail to arrive.

What he will notice: two of his squads meeting head-on in a street. One squad pulls aside short of the mouth and waits,
the other comes through, then the first goes. No hard bumps, and no lock-up at the mouth.

## Where things stand (main `bcef46a1`; its check is the launch check named in HANDOFF)

- **Nothing of round 28's traffic shipped.** `traffic-t1-v3` (squad-pair crossing verdicts + the one-lane street rule) and
  `traffic-t1b` (the street rule alone, judged at `474558f8`) are parked. T1b halved hard bumps on his Terminus head-on
  case (−48/−52/−50 % on three seed sets), but the waiting squad crept at 0.2 of its wish and once in 18 runs (seed 12,
  tick 16) both squads locked at the mouth: 4 crews never in, 305 crew-s stuck.
- T0's base (builder0 `c6e32d03`, GDScript path, n = 18 a case): fast friendly contacts 294 / 716 / 277 / 113 (Terminus
  crossing / Terminus head-on / yard crossing / yard head-on); his Terminus head-on: ~40 hard bumps a run, 8 runs in 18
  leave a crew out. Re-measure on today's main before the bar: native perception and projectiles changed since.
- Tooling on round 28's branch, now to bring to the stream: the traffic table's **all-in s** column and **between squads**
  line (`contacts_cross_fast`); `traffic-clip` that sees into Terminus' streets and takes `TRAFFIC_FLAGS`;
  `test_traffic_turns_live` (the live falsifier that the rule fires through its caller's gate).

## Backlog (in order)

**T0 — the base on today's main.** His four cases, n = 18 a case, start ticks {1,3,6,8,11,16}, GDScript path
(`--brains-off=native`), with between-squad and same-squad fast contacts counted apart (lesson 301) and the all-in time.

**T1 — the street meeting with a real waiting spot (round 29 item 1; DECLARED; CP-T).** From `traffic-t1b`
(`Traffic._street_meeting` / `_decide_street`): when the verdict is "wait", each crew of the waiting squad holds at a
SPOT short of the street mouth and off the passing squad's line (the right side of its own way, from the navmesh), until
the passing squad's last crew is behind it, with a cap (~20 s) after which it goes. `Traffic.holding(crew)` is true while
it holds; the C29.3 gates read it, so a holding crew is not stalled or "blocked", is not re-seated by its element, does not
unstick or k-turn, and makes no asks. The CPU on the same rule. `--traffic-off=hold`.
**Bar (send it before the numbers; name the last attempt):** on his Terminus head-on case: crews in ≥ base − 2; hard bumps
BETWEEN squads (`contacts_cross_fast`) down ≥ 25 %; last arrival ≤ +20 %; **no wedge** (no run with more than one crew never
in where its base run had none; read the worst run's trace first); the other three cases unchanged within 2 se; one CPU
case; `bridge-pooled` 18/18; tuned on seeds {1,2,3}, judged ONCE on fresh seeds (not 4–12); `test_traffic_turns_live`
shows the rule fired in the judged arm (lesson 300); ≤ 0.5 ms a tick (C29.5).

**T2 — the C++ twin.** The settled T1 diff to native before its commit (the hold as a record field, read by the drive);
equal answer; the pair merged back to back.

**T3 — the crossing (stretch).** Only after T1 ships: v3's squad-pair crossing verdict, judged on between-squad bumps only
(lesson 301), on fresh seeds. And the friendly half of the creep in tight streets (manoeuvre's census: half of creep
episodes are a squadmate in the way): a give-way that lets a creeping long hull through, agreed with manoeuvre through the
orchestrator.

## How to verify

`make remote T=check` (builder0 only, C29.7); `make traffic-series`, `traffic-trace`, `traffic-census`, `bridge-pooled`,
`native-verify-scenarios`; a `traffic-clip` of his Terminus head-on case before and after for him (watch it: does the
waiting squad look like it is waiting on purpose?).

## Don't touch

Manoeuvre's drive body, k-turn block, `manoeuvre*.gd`, `order_controller.gd`; brains' `game/tactics/**`, elements,
`tank_brain.gd` (except the granted gate lines); native's `native/**`; `game/control/**`.

## Waiting on the lead

Nothing: his call is made.

## Status

_Updated 2026-10-13 ~16:40 PDT (traffic worker, session godot-traffic-e4). Every number names commit, machine, workload and n._

### REPORT (traffic, round 29) — read this first

**The round's items:**
- **T0 done.** It equals round 28's base run for run.
- **T1 the street hold SHIPPED.** It passed its bar and was merged as a pair with native's port: main `1267ffb1` +
  `1113062c`.
- **T2 done** by native: an equal answer.
- **T1c FAILED** (brains' set-up hull request). Parked on `traffic-t1c`; the orchestrator moved it to round 30 with the
  question "repacks while still ordered to fire".
- **T3, the crossing: FAILED** its judged bar on time and crews. Parked on `traffic-t3`, with a round-30 lead.
- **T3's other half NOT STARTED:** a give-way that lets a creeping long hull through, among squadmates in tight streets.
  It needs manoeuvre's agreement through the orchestrator, and the round's time went to judging T1c and T3.

The stream's `game/` equals the shipped `3a94f38d`; only three python tools (verdict scripts, the table) and docs differ.
**Final check: GREEN at `306d6271`** (builder0, `make check exited 0`, 2550 passed / 0 failed, 24 targets judged; 2 NOT
JUDGED for load: `perf-judge` refused at 1.65–2.29× busy, and `scenario_perf`'s CPU budget defers to it by design).
The commits after it change only this Status. **Merge notes:** stream/traffic's `game/` equals the shipped `3a94f38d`
(already on main as `1267ffb1`). Merging the tip brings docs, data (`references/round29/traffic/`) and three python
tools: `tests/traffic/hold_verdict.py`, `turns_verdict.py` and the table's columns. Main was not merged back into the
branch. **Kept branches:** `traffic-t1c` (T1c, round 30) and `traffic-t3` (T3, round 30); round 28's `traffic-t1-v3`
and `traffic-t1b` are superseded by T1 and T3 (delete at close). **What to playtest:** `make native && make skirmish` on
the Terminus, two of your squads sent through each other along the west street. His clips are in
`/home/slobdell/projects/clips/traffic_round29/`.

**Lessons for the list:**
1. A copy-back of `build/` replaces it: anything kept for the lead goes outside the worktree
   (`~/projects/clips/...`). Round 29: the clips the orchestrator came to fetch were gone.
2. A rule's own gate list is part of its bar's text. T1c's "set-up give-ways = 0" counted give-ways the hull started
   itself, which the rule (an ask refusal) never touched. Write the counter for the path the rule actually closes, or
   close every path the counter counts.
3. Two rules on one table must say which owns a meeting. T3 v1's crossing fired inside every street hold.

**CP-T: T1 the street hold PASSED its pre-registered bar, judged once. Green: `3a94f38d`** (builder0, `make check exited 0`,
2550 passed / 0 failed; 24 targets judged + 2 refused by load: `perf-judge` then judged alone, PASS 1.17×;
`ai-scenarios-check` 52/0, its one refusal is `scenario_perf`'s CPU budget, which by design defers to `perf-judge` when
unpinned on builder0's hybrid CPU). The commit after it adds only the verdict script, data and this report.
**Native's T2 port is EQUAL** (native, builder0, proof tree stream/native + `3a94f38d` at `012c9335`:
`test_native_traffic_hold`, 0 mismatches; stream/native `4b982691` + `a23512ff` + `573ca520`). Merge the pair back to back.

**Judged run** (builder0, `3a94f38d` both arms, GDScript path, fresh seeds {13,14,15} x ticks {1,3,6,8,11,16}, n = 18 a
case, base `--traffic-off=hold`; `tests/traffic/hold_verdict.py`; data `references/round29/traffic/`):

| case | crews in | between-squad fast | all fast | all-in median s | wedges | the rule's counters |
|---|---|---|---|---|---|---|
| **Terminus head-on** | 176 → **177** ✓ | 475 → **91 (−81 %)** ✓ | 881 → 379 | 60.8 → **59.3** ✓ | none ✓ | 18 verdicts, 90 holds, 87 released as the tail passed, 3 at the cap, 0 no-spot |
| Terminus crossing | 173 → 173 ✓ | 112 → 112 | 236 → 236 ✓ | 45.9 → 45.9 ✓ | – | 1 verdict, 3 holds, 86 crew-ticks (no effect on any number) |
| yard_open crossing | 166 → 166 ✓ | 111 → 111 | 247 → 247 ✓ | 77.2 → 77.2 ✓ | – | 0 |
| yard_open head-on | 176 → 176 ✓ | 55 → 55 | 115 → 115 ✓ | 30.9 → 30.9 ✓ | – | 0 |
| CPU mirror (`--side=rust`) Terminus head-on | 176 → 178 ✓ | 475 → 58 (−88 %) ✓ | 881 → 382 | 60.8 → 59.1 ✓ | none ✓ | 18 / 90 / 85 / 2 |

Worst runs read (lesson 302): s13/t16 is the one run whose between-squad bumps did not fall (24 → 27); three runs lose a
single crew each, 19–21 m from its seat at the FAR end (B_4/B_5), the destination's seating, not the street (below).
**Also:** `bridge-pooled` on the GDScript path 18/18 (`BRIDGE_FLAGS=--brains-off=native`, builder0, `3a94f38d`);
`test_traffic_hold_live` fires on his case (the judged arm's counters above). **Cost (C29.5):** Traffic's own parts
(`sz.tr.refresh_gd` + `sz.tr.look_gd`) 0.10–0.20 ms a tick at Sumps 4600 (`ai-parts-match`, GDScript path, builder0
loaded ~20, `3a94f38d`, seeds 92721–3, n = 3): ≤ 0.5 ms. The whole `move.avoid` delta between arms is NOT READABLE under
that load (−0.86 to +0.26 ms; both arms ran identical ticks and calls, so the CPU fights themselves did not change).

**In his terms:** *When two of your squads meet head-on in a street, the one still outside now pulls over beside the
street's mouth, mostly to its right, and waits. The other comes straight through, then the first goes. Hard bumps
between the two squads drop by about four fifths. Nobody locks up, a crew more gets in, and the last one arrives at
about the same time as before.*

**What to playtest** (after the pair merges; the C++ path carries it then): `make native && make skirmish` on the
Terminus, two of your squads sent through each other along the west street. Before the merge, on this branch:
`make skirmish -- --brains-off=native`. **His clip** (seed 1, his case, 45 s, top-down over the street): base
`/home/slobdell/projects/clips/traffic_round29/terminus_head_base_3a94f38d.mp4` and hold `.../terminus_head_hold_3a94f38d.mp4` (outside the worktree: a normal-lane copy-back replaces `build/`)
(builder0 light lane, `make remote LIGHT=1 T="traffic-clip TRAFFIC_CLIP_CASES=terminus,head TRAFFIC_CLIP_ARMS='base:hold on:-' TRAFFIC_FLAGS=--brains-off=native"`).
I watched the frames at 12 s and 18 s. With the hold, A waits on both sides of the north mouth (the block corner leaves
room for three on the right) and B's column comes out between them. In the base at 18 s, crews of both squads are
tangled inside the street. Question for him: does the waiting squad look like it is waiting on purpose?

**Decisions:** the verdict is T1b's (the squad still in the open waits). Spots come from the navmesh: the mouth on the
waiting lead's route, then the street's centre line there, then spots 12–22 m right of it, clear of the passing squad's
run to its destination and of its formation there. The left side is used only when the right has no room. Release
per crew once the passing squad's tail is past, cap 20 s, then no new verdict for that pair for 30 s. A meeting needs
both squads travelling. No mouth within 80 m means no hold.

**Questions for the lead:** none blocking (the clip question above).

**Requests to other streams:**
- **brains:** the far-end seating. In both arms, every crew left out ends 16–25 m from its seat at the destination
  after the element re-seats it onto a seat beside a block that reads `no_path` (base 10 crews out on the tuning
  seeds, v4 9). With the hold, the rear crew of the waiting squad (B_5) arrives last into that shuffle, so it carries
  most of the misses (6 of 9 on the tuning seeds). Traced at seed 1 tick 11 (`make traffic-trace TRAFFIC_ARENA=terminus
  TRAFFIC_KIND=head TRAFFIC_SEED=1 TRAFFIC_FLAGS='--brains-off=native --lab-start-tick=11'`): B_1 was "arrived" at
  36 s, re-seated at ~54 s, and blocked `no_path` at (-73.7, 94.9).
- **native:** done (T2, equal). Tell native before changing `hold_of`'s return shape or `holding()`'s formula.

**Known issues:** in the crossing the rule fired once on the judged seeds (3 holds, 86 crew-ticks) with no change to any
number; a long squad can find no room on the right at a cramped mouth and splits across both sides (visible in the clip).

**T1c (brains' request: a hull set up to fire does not give way) FAILED its pre-registered bar; nothing ships.** The
candidate `761bd727` is parked on branch `traffic-t1c` and reverted off stream/traffic.
- The rule: `Movement.ask()` refuses while `deploy_ratio > 0`, and the asker treats the hull as parked and goes round.
  `--traffic-off=setup`, test `test_traffic_setup`.
- The judged census: builder0, `761bd727` both arms, GDScript path, `make traffic-census` (Sumps 1000, Parade 2000,
  Foundry 2000), fresh seeds {4,5,6}, n = 9 an arm. Data in `references/round29/traffic/t1c_census_*`.
- Line (1), set-up give-ways in the arm = 0: **FAIL, 25 → 9.** Line (2), friendly-stuck 299 → 295 crew-s: pass. Line (3),
  fast contacts 464 → 480 against a limit of 515: pass. Line (4), artillery shots 130 → 120 (paired diff −10, 2 se 26):
  pass. Repacks during a give-way fell 13 → 7; asks refused: 20.
- Why line (1) failed: `ask()` refused every ask while a hull was set up, so the 9 left are give-ways the set-up hull
  started ITSELF. In `_negotiate`, a battery with a new move and its legs still coming up decides it is the one to give way.
- The chain was stopped after the census (the four cases, `bridge-pooled` and check never ran on the failed candidate).
  The local wrapper and its builder0 run were stopped by PIDs verified to be in my own folder.
- For whoever takes it next (the orchestrator decides whether a new attempt is allowed): also skip the self-started
  give-way in `_negotiate` while `deploy_ratio > 0`. A hull packing to move gives way only once it is packed. Judge it
  on fresh census seeds, plus brains' ApproachStage drawn-artillery arm (the orchestrator's line 6).

**T3 (stretch, the crossing) — FAILED its judged bar, parked (below).** The bar was sent and accepted before any number (filed at main `bd5bd5a9`):
judged once on fresh seeds {22,23,24}, base `--traffic-off=turns` with the hold on in both arms, read by
`tests/traffic/turns_verdict.py`. The change is round 28's v3 squad-pair crossing verdict, ported beside the hold
(`Traffic.shape`, the crossing statics, and the `_avoid` hook shaping ORCA's preferred velocity; no keep-right, no
street creep). Tests `test_traffic_turns` (pure, v3's crossing tests) and `test_traffic_turns_live`. Native has the diff
(C29.2) and will port it after the verdict.
- **v1** (`fcddda26`; builder0, seeds {1,2,3}, n = 18 a case, against base = hold-on): between-squad fast at the
  crossings pooled 234 → 86 (−63 %): Terminus crossing 116 → 46, yard crossing 118 → 40. Crews 176 → 178 and 169 → 168.
  Same-squad fast 178 → 170 and 159 → 162. All-in median Terminus crossing 45.8 → 47.6, yard crossing 75.6 → 90.0
  (+19 %: the yard median sits near the 90 s cap, because in both arms about half the runs leave one crew out at the
  end). It FAILED on one line: the crossing rule fired once in every Terminus head-on run (the waiting squad pulling
  aside across the passing squad's way read as a crossing), and s2/t16 lost 2 crews (B_4/B_5, 16–21 m from their seats
  at the far end, the seating pattern again).
- **v2** (`31360e56`, DECLARED, the last attempt): the crossing rule stands aside for any squad pair under a street
  wait. Tuning: `turns_verdict` PASS on {1,2,3} (head-on back to base: 5 verdicts, 66 crew-ticks).
- **VERDICT: T3 FAILED its judged bar; nothing ships.** Judged on builder0, `d9b3339c` (= v2 + docs) both arms, GDScript
  path, fresh seeds {22,23,24}, n = 18 a case, base `--traffic-off=turns` with the hold on. Data and
  `t3_verdict_d9b3339c.txt` are in `references/round29/traffic/`.
  - Between-squad fast at the crossings, pooled: 206 → 95 (−54 %), pass. Terminus crossing 92 → 39, yard crossing
    114 → 56. Same-squad fast 134 → 145 and 180 → 130, pass. Head-on cases equal base within noise, pass.
  - FAIL, Terminus crossing all-in median: 39.4 → 48.3 s (+23 %, line +20 %). FAIL, yard crossing crews: 171 → 167 (line
    169). FAIL, a wedge at yard s22/t6 (2 out where the base had none).
  - CPU mirror not run (stopped after the verdict: the chain's PIDs were checked in my own folder, locally and on
    builder0).
  - **Worst runs read.** The yielding squad pays heavily in some Terminus crossing runs: B's last arrival 22.8 → 69.0,
    26.5 → 74.7 and 31.0 → 78.2 s while A gets in faster. The whole squad keeps 0.4 of its wish for as long as the
    verdict stands, which is too long a crawl. The yard crews left out (in both arms) are 16–25 m from far-end seats
    with almost no friendly-stuck time, mostly B_1's seat behind the containers. The rule only moves which run loses
    one.
  - Parked on branch `traffic-t3` (= `d9b3339c`); reverted off stream/traffic. **For round 30:** the crossing's bump
    cut is real and large (−54 % to −63 % on two seed sets). What it costs is time, in the yielding squad's crawl.
    Release a yielding crew's squad share as soon as the other squad's tail has cleared the crossing point (not
    VERDICT_KEEP_S after its crews stop meeting), or let only the crews short of the point within a squad length
    crawl. Judge on fresh seeds. And the far-end seats that read `no_path` (brains) sit under every case's crew line.

### The plan (ordered)

1. **T0**: the base, builder0, `3cd5596b` (= main's green `bcef46a1` + docs), `make traffic-series
   TRAFFIC_FLAGS=--brains-off=native`, seeds {1,2,3} x ticks {1,3,6,8,11,16}, n = 18 a case. The table now prints
   between-squad fast contacts (`xfast`) beside same-squad (`own`), and the runs with more than one crew never in.
2. **T1**: the street hold (`game/ai/traffic.gd`, a fresh file: T1b's head-on street verdict, none of v3's crossing or
   keep-right code). Decided: (a) the verdict is T1b's (the squad still in the open waits; that measured −50 % hard bumps);
   (b) the spots are found once per verdict from the navmesh: the mouth is the first street point on the waiting lead's
   ROUTE (its nav path, not a straight line), the street's centre line there, then a grid behind the mouth and 12–22 m to
   the right of the centre line (an 18–20 m street's whole half-width plus a hull), lead first, room for the hull, not on a
   squadmate's spot or a parked hull, the left only if the right has no room; (c) release per crew, when every crew of the
   passing squad still under way is behind it, cap 20 s from the verdict, then no new verdict for that pair for 30 s
   (the anti-wedge: a squad that waited once never waits twice in a row); (d) the hold steers in `Movement._avoid` (traffic's)
   and returns pace 0 at the spot, so the crew stops facing its way; (e) `Traffic.holding(crew)` is live only while the
   mover asked for its hold in the last 3 ticks. Gates (C29.3): one line each in `_track_progress`, `_update_phase`'s blocked
   branch, the element's re-seat loop, `unstick`, `_pressing_escape`, the k-turn entry in `_planned_reverse`, and
   traffic's own `_negotiate`. Switch: `--traffic-off=hold`. Tests: `test_traffic_hold` (pure), `test_traffic_hold_live`
   (lesson 300's falsifier on his case). Bar sent to the orchestrator before any T1 number (below).
3. **T2**: the settled diff to native.
4. **T3** (stretch): v3's crossing on between-squad bumps; the friendly creep give-way with manoeuvre.

### T0: the base (builder0, `3cd5596b`, `make traffic-series TRAFFIC_FLAGS=--brains-off=native`, seeds {1,2,3} x ticks {1,3,6,8,11,16}, n = 18 a case, 216 runs, 0 missing; 2026-10-13 ~11:40–11:58 PDT)

**Identical, run for run, to round 28's T0 at `c6e32d03`**: the GDScript path did not move with native's ports since.
Data: `references/round29/traffic/t0_3cd5596b_seeds123.jsonl`.

| case | crews in | fast (between squads / own) | all-in med / mean s | fstuck crew-s | runs with > 1 crew never in |
|---|---|---|---|---|---|
| Terminus head-on | 170/180 | 716 (398 / 318) | 64.3 / 65.4 | 489.1 | 0 |
| Terminus crossing | 176/180 | 294 (116 / 178) | 45.8 / 55.2 | 156.9 | 1 (s2/t3) |
| yard_open crossing | 169/180 | 277 (118 / 159) | 75.6 / 72.2 | 196.5 | 1 (s3/t11) |
| yard_open head-on | 179/180 | 113 (60 / 53) | 37.2 / 38.1 | 8.9 | 0 |

### T1 tuning (seeds {1,2,3} only, builder0, GDScript path, `TRAFFIC_WHICH=both`, against T0)

- **v0** (first trace, seed 1, Terminus head-on): the mouth was never found: a crew's nav path ends at its element's
  next LEG slot, so the march stopped short of the street and the "edge" fallback pulled crews aside on B's way out.
  Fixed: the march goes on straight along the squad's way past the path's end.
- **v1**: Terminus head-on xfast 398 → 148 (−63 %), crews 170 → 177, all-in median 64.3 → 68.5 (+6.5 %), no wedge, 18
  verdicts / 90 holds, 7 waits to the cap. But the rule fired 4 times in the Terminus CROSSING (a squad milling at its
  goal read as a head-on meeting 60 m from any street) and that case fell 176 → 173 crews (s1/t8 lost 2: chaotic
  divergence after a 1.7 s hold far from the other squad; still a crew-line fail).
- **v2**: a meeting needs both squads travelling (≥ 60 % of crews moving, and two), each crew of the pair heading with its
  squad (cos ≥ 0.7), and a mouth within 80 m of the waiting lead's route (else no hold). The other three cases now equal
  their base runs exactly (0 verdicts). Terminus head-on unchanged from v1. **Worst run (s2/t1: xfast 10 → 38, the cap):**
  B waited exactly where A's formation spreads out on ARRIVAL (A goes to B's start), so A drove into B's holders.
- **v3**: keep spots off the passing squad's way out, from each crew's order goal. A null (v3 = v2 run for run): a crew's
  order goal is its current leg's slot, which pointed north at the verdict.
- **v4 (DECLARED for judging; the last attempt)**: from the passing ELEMENT's task destination: spots kept off the run
  from the mouth's centre to it, and out of a disc round it as wide as its formation's current spread. Terminus head-on:
  xfast 398 → **71 (−82 %)**, own 318 → 270, all fast 716 → 341; crews 170 → 171; all-in median 64.3 → 61.2; fstuck
  489 → 393; 18 verdicts, 90 holds, 83 released by the tail passing, 4 waits to the cap, 2 crews with no spot. The other
  three cases equal their base runs exactly. **The worst run read (s1/t11, 2 crews never in v base 1):** B held 17 s,
  was released as A's tail passed, came through the street cleanly and was in by ~36 s; then B's own arrival re-seating
  sent B_1 and B_4 to seats beside the block that read `no_path`. Every crew left out in base and v4 alike ends 16–25 m
  from its seat at the far end (base 10 crews out, v4 9); v4 concentrates them on B_5 (6 of 9), the rear tank, which now
  arrives last into the seat shuffle. That is the element's arrival seating (brains, round 28's T3 finding), not the
  street.

### The bar for CP-T (sent to the orchestrator 2026-10-13 ~11:55 PDT, before any T1 number)

Judged ONCE: both arms at one commit, GDScript path, fresh seeds {13,14,15} x ticks {1,3,6,8,11,16}, n = 18 a case;
base arm `--traffic-off=hold`. Terminus head-on: crews in ≥ base − 2; `contacts_cross_fast` down ≥ 25 %; all-in median ≤
base + 20 %; NO WEDGE (no run with > 1 crew never in whose paired base run had none; the worst run's trace read first). The
other three cases: fast contacts and all-in median within 2 se of base, crews ≥ base − 2. CPU mirror (`--side=rust`) on
Terminus head-on reported, no worse on those four. `bridge-pooled` 18/18; the live test fires in the judged arm (counts in
the report); cost ≤ 0.5 ms a tick at Sumps 25 a side (GDScript path) or NOT READABLE. No partial gain. Tuning on {1,2,3}
only. **Last attempt:** the version declared for judging; a fail parks it with its trace.

