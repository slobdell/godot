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

_Not started (round 29 launch, 2026-10-13)._
