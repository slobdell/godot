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

_Updated 2026-10-13 (traffic worker, session godot-traffic-e4). Every number names commit, machine, workload and n._

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

