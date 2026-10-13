# Stream: traffic (two of your squads crossing take turns: fewer bumps, nobody left behind)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 26 direction* and **Round 28
> direction** (his call 1), `_agents/workstreams.md` *Round 28* (C28.1–C28.6), round 26's traffic report
> (`streams/archive/round26/traffic.md`: *CP1b's verdict*, *For round 27*: your starting point) and `_agents/native.md`
> *Stage 1* (what is C++ now). **You own:** `game/ai/avoidance.gd`, `game/ai/steering.gd`, `game/ai/traffic*.gd`, in
> `game/ai/movement.gd` the give-way block (`right_of_way` through `_blocker`), `_avoid`, `_around_friends`, `_ask_behind`,
> `_hull_within`; `tests/test_traffic*.gd`, `tests/traffic/**`, `tests/ai_scenarios/scenario_traffic*.gd`,
> `tests/test_avoidance.gd`, `mk/traffic.mk`. **The C++ (C28.2):** `right_of_way` (native E5c), `_avoid` and
> `Avoidance.solve` have C++ twins held equal by live-function proofs. Develop on the GDScript path; before the commit
> that changes one of them, send native the diff (SendMessage, orchestrator copied); the pair merges back to back.

## The lead's direction

Round 26: *"if I take 2 squads and have them move in opposing directions such that they have to cross each other … vehicles
will get stuck bumping into each other … people would just generally each turn to the right in order to deconflict. The
same case might not be said if we're charging toward an enemy."*
**Round 28, his call (2026-10-12): TAKE TURNS** — "fewer bumps; both squads arrive a little later." So the pass line may
trade some arrival time for fewer bumps; it may never trade crews that arrive.

What he will notice: two of his squads crossing (head-on or at an angle, street or open ground) slow and let one through,
instead of nosing into each other; enemies still blocked on purpose.

## Where things stand (main `ecc0d6e0`, green)

- Round 26's CP1a (the element's slot slide no longer resets every crew's stall clock) made his head-on case pass
  (180/180 open ground, 171/180 Terminus street); CP1a2: no giving way to a parked squadmate.
- CP1b (keep right + a crossing yield) failed three times (branch `traffic-cp1b-v4`): the yield's speed cap made crews
  crawl (friendly-stuck ×3) until v3's floor; keep-right helped in the Terminus street (177/180) and hurt on open ground
  where ORCA already passes; fast friendly contacts −30 to −38 % at crossings was its one clear gain.
- The clump census: in big CPU fights a friendly hull is in the way for ~25 % of stuck crew-time; ~75 % is static.
- `make traffic-series | traffic-trace | traffic-census | traffic-clip | traffic-parked` exist (tests/traffic/).

## Backlog (in order)

**T0 — his cases, re-measured on main (no change).** Head-on and 90° crossing, open ground and the Terminus street, the
traffic-series at n = 18 per case: crews arrived, all-in time, friendly-stuck crew-s, fast friendly contacts (the bumps he
sees), at main. This is the base every bar below is read against.

**T1 — a crossing rule that takes turns.** One meeting, one decision (C26.4's shape, kept: both crews compute the same
answer from the same facts, tie-break by unit id; friendlies only; a crew in a give-way or a k-turn is an input, not a
state you rewrite): at a crossing, the later squad yields with v3's floor; head-on in a street, keep right; on open
ground, ORCA as today. Reads the room (street v open, squadmates abeam) from facts, not a map name.
**Bar (send it to the orchestrator before the numbers, lesson 292):** on all four of his cases: crews arrived ≥ base − 2
(no crew left behind), fast friendly contacts down ≥ 25 % in at least 3 of 4 and up in none beyond 10 %, all-in time
may rise (his call) but ≤ +20 %, friendly-stuck ≤ base × 1.2 + 10; `bridge-pooled` 18/18; arrive series = main; cost
≤ 0.5 ms a tick at 25 a side Sumps (C28.4). DECLARED (C28.1), the CPU on the same rule.

**T2 — the C++ twin.** With native: the settled rule ported (reading the record, never a callback), equal answer, the
pair merged back to back.

**T3 — stretch:** the friendly share of stuck time in big fights (the census) after T1; a crew pressing a squadmate
parked on its leg station (brains' B2 fixed slots; legs may remain).

## How to verify

`make remote T=check` (builder0 only; C28.6); `make traffic-series`, `traffic-census`, `bridge-pooled`; a `traffic-clip`
of his head-on and crossing cases before/after for him (look at it). Pool timing-sensitive runs over start ticks
{1,3,6,8,11,16}; fresh seeds for any judged run after tuning (lesson 298).

## Don't touch

Manoeuvre's drive body, k-turn block, `manoeuvre.gd`, `order_controller.gd`'s face path; brains' `game/tactics/**`,
elements, `tank_brain.gd`; native's `native/**`.

## Waiting on the lead

Nothing: his call is made.

## Status

_Updated 2026-10-12 evening (traffic worker). Every number names commit, machine, workload and n._

### The plan (ordered)

1. **T0**: the base. `make traffic-series` at `c6e32d03` (= main's green `94b5fc0d` + docs), GDScript path
   (`--brains-off=native`: T1's arm can only run there until T2, so the base runs there too), seeds {1,2,3}, n = 18 a
   case. The table gained an **all-in s** column: per run, every crew's last arrival, with a crew that never arrived
   counted at the run's end (median, mean).
2. **T1**: the rule (`game/ai/traffic.gd`, called from `Movement._avoid` exactly where round 26's v4 was). Switches
   `--traffic-off=turns,streetright` give the base arm. It is tuned on seeds {1,2,3}. The JUDGED run is both arms on fresh
   seeds {4,5,6}, plus one CPU-side case (`--side=rust`, the orchestrator's C28.1 note). The bar was sent to the
   orchestrator before any numbers and accepted (2026-10-12). **v3 is the last attempt, named in advance.**
   Decided: the verdict is per SQUAD pair, not per crew pair. Round 26's v4 let crews of both squads yield to crews of
   the other at once, which is the opposite of taking turns. Keep-right applies only where the navmesh ends within
   16 m on both sides, because round 26 measured it helping in the street and hurting on open ground.
3. **T2**: send native the settled diff after `make native-verify-scenarios` with the rule ON; the pair merges back to
   back.
4. **T3** (stretch): the census after T1, and a crew pressing a squadmate parked on its leg station.
