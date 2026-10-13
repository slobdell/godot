> **ARCHIVED (round 28 closed 2026-10-13; native continues).** Kept as the stream left it; current state is in `HANDOFF.md`.
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

Nothing: his call is made. (Both builds of it failed their bars; round 29 item 1 is the next try.)

## Status

_Updated 2026-10-12 evening (traffic worker). Every number names commit, machine, workload and n._

### FINAL REPORT (round 28, traffic) — read this first

_2026-10-13 ~00:00 PDT. Every number names commit, machine, workload and n._

**Shipped: nothing.** His call was TAKE TURNS. Two versions of it each failed a bar written before their numbers. Both are
parked on branches, and stream/traffic's `game/` is its round-start state (= main `94b5fc0d`'s).
- **T1 v3** (`traffic-t1-v3`, judged at `672eb785`, seeds {4,5,6}). Squad-pair crossing verdicts, plus a one-lane bridge for
  a head-on meeting in a street. Fast friendly contacts fell ≥ 25 % in only 2 of 4 cases (Terminus head-on −52 %, yard
  crossing −34 %); at the Terminus crossing, bumps between squads fell 29 % but squadmates' bumps rose.
- **T1b** (`traffic-t1b`, judged at `474558f8`, seeds {10,11,12}; the orchestrator's one new last attempt). The street
  rule alone. Hard bumps −50 %, but crews 173 → 170, the last arrival +26 % and friendly-stuck +33 % on his Terminus
  head-on case: one run in 18 wedged at the street mouth. (A first T1b run on {7,8,9} was VOID: the rule never ran.)
- **T2** (native's port): nothing to port.
- **T3**: the census after T1 is moot (`game/` unchanged). The "crew pressing a parked squadmate" cell is gone on main.
  What remains there is the element's seat swap (to brains, below).

**Measured and kept** (`references/round28/traffic/`, README): T0's base on his four cases at main (builder0
`c6e32d03`, GDScript path, n = 18 a case): fast friendly contacts 294 / 716 / 277 / 113 (Terminus crossing / head-on /
yard crossing / head-on). In his Terminus head-on case, about 40 hard bumps a run, and 8 runs in 18 leave a crew out.

**Tooling for whoever comes next (on this branch):**
- The traffic table's **all-in s** column (every crew's last arrival, a never counted at the run's end) and **between
  squads** line (fast contacts between the two squads, and a rule's counters when the branch has them).
- `traffic-clip` now sees into Terminus' streets (the old pose put the camera inside a block) and takes `TRAFFIC_FLAGS`
  (it ran the C++ path before, so a GDScript-only rule never showed).

**In his terms:** *Your squads still bump when they cross or meet in a street. Two "take turns" rules were tried. Both
halve the hard bumps when two squads meet head-on in a street, because one waits at the mouth while the other comes
through. But the waiting squad waited too long, and once in 18 tries the two locked up at the mouth, so neither is in the
game. The next try gives the waiting squad a real place to wait (item 1 below).*

**Questions for the lead:** none blocking.

**Requests to other streams** (through the orchestrator):
- **brains:** (1) round 29 item 1's hold: the stall clock, the "blocked" phase and the element's make-room clock must
  pause for a crew holding for traffic. (2) T3's finding: in the Sumps arrive cell (law_scout:law_ifv:law_tank:law_tank,
  seed 1, `make traffic-settle-trace`, builder0, `b33b6723` GDScript path, n = 1, a lead, not a result), the squad is in
  at 41 s but the last crew only at 82.6 s. From 48 s to 84 s the element re-seats crews 3 and 4 back and forth (seats
  2310 ↔ 2301), and whichever holds the slot at (11.1, −73.4) reads `blocked/no_path` toward it.
- **manoeuvre:** no unstick or k-turn while a crew holds for traffic (item 1).

**What to playtest:** nothing new from traffic. `make skirmish`, two squads through each other on the Terminus street,
is still the case to watch. To see the parked rule: `git checkout traffic-t1b && make skirmish -- --brains-off=native`
(the C++ path does not run it).

**Lessons for the list:**
1. An A/B whose arm equals its base run for run is a null until the arm's own counter says the rule fired. A pure test
   of a rule cannot see its caller's gate (T1b's void run; the live falsifier `test_traffic_turns_live` on the branch).
2. A bar on ALL friendly contacts mixes the rule's effect (between squads) with squadmates' noise. Count what he sees.
3. Killing a local chain leaves its remote run alive on builder0: stop it by the box's cwd-verified PID (lesson 15,
   again: it blocked this stream's final check for a minute).

**Merge notes:** stream/traffic carries docs, references and traffic tooling only (`tests/traffic/*`, `mk/traffic.mk`).
`game/` equals the round start. **Green: `b33b6723`** (builder0, `make check exited 0`, 2520 passed / 0 failed, 25
targets ALL JUDGED, thirteen sim-baselines unmoved, determinism 2875411ff4ec6be7 = main's). The commit after it records
only this report (docs). Merge there or at the tip. Branches `traffic-t1-v3` and `traffic-t1b` are NOT for main.

### ROUND 29, ITEM 1 (the orchestrator, 2026-10-13): the one-lane bridge with a real waiting spot

His Terminus head-on case is the worst friendly jam measured (base 716–872 fast contacts in 18 runs), and taking turns
halves it (−48 % / −52 % / −50 % on three seed sets). It failed only on how the waiting squad waits: it creeps toward
the meeting at 0.2 of its wish, and once in 18 runs the squads lock at the street mouth (seed 12, tick 16: 4 crews never
in, 305 crew-s stuck). The build:
1. **Traffic (owner):** when the verdict is "wait", each crew of the waiting squad holds at a SPOT: short of the street
   mouth, off the passing squad's line (the right side of its own way). It holds until the passing squad's last crew is
   behind it, with a cap (e.g. 20 s) after which it goes. `Traffic._street_meeting` / `_decide_street` on `traffic-t1b`.
2. **brains (owner of `_track_progress`, `_update_phase`, the element's make-room clock):** a crew holding for traffic
   is not stalled: the stall clock and the "blocked" phase pause while it holds (a read of `Traffic.holding(name)`),
   and the element does not re-seat it.
3. **manoeuvre (owner of `unstick`, `_pressing_escape`, the k-turn):** no unstick or k-turn while holding for traffic.
4. **traffic (owner of `_negotiate` / `_blocker`):** no asks while holding.
5. **native:** the port reads the hold from the record (C28.2's pair).
Bar (to be set before numbers): his three things on the Terminus head-on case: crews in (≥ base − 2), hard bumps
BETWEEN squads (the probe's `contacts_cross_fast`, down ≥ 25 %), the last arrival (≤ +20 %); no wedge (no run with more
than one crew never in where its base had none); the other cases unchanged; fresh seeds.

### T1b: the street head-on rule ALONE (the orchestrator's one new last attempt, 2026-10-12 ~22:00 PDT)

`fc31d0c4`: v3's one-lane bridge for a head-on meeting in a street; the crossing verdicts and keep-right in the tree OFF
by default (`--traffic-on=turns,streetright`). **Bar (the orchestrator's, set before any T1b number):** judged once,
fresh seeds {7,8,9}, both arms at one commit, GDScript path, base `--traffic-off=streetturns`: Terminus head-on fast
friendly contacts down ≥ 25 %, crews ≥ base − 2, all-in median ≤ +20 %; the other three cases not worse beyond noise
(fast ≤ +10 %, crews ≥ base − 2; the rule should not fire there, reported if it does); friendly-stuck ≤ base × 1.2 + 10;
the CPU mirror on Terminus head-on reported; bridge-pooled, the arrive series, cost, native-verify-scenarios. No tuning on
7–9; the last attempt.

**The {7,8,9} run is VOID** (`fc31d0c4`, builder0, 2026-10-12 21:49–22:38 PDT): the rule never ran: 0 verdicts in every
case, the arm equal to its base run for run. `Movement._avoid` called Traffic only when `turns` or `streetright` was on,
both off by default in T1b; the pure tests call `Traffic.shape` directly and passed (lessons 23/35). Fixed at `474558f8`
(no parameter changed) with a live falsifier, `tests/test_traffic_turns_live.gd` (his Terminus head-on on the GDScript
path must make a verdict: 0 on the old gate, > 0 on the fix). The orchestrator accepted the re-run on FRESH seeds
{10,11,12} as the same last attempt, same bar, with the verdict count per case in the report.
**Lesson for the list:** an A/B whose arm equals its base run for run is a null until the arm's own counter says the
rule fired; a pure test of the rule cannot see its caller's gate. The probe's verdict counter caught it in one read.

**T1b's VERDICT (2026-10-12 ~23:59 PDT): FAILED — nothing ships.** Judged run: builder0, `474558f8` both arms, GDScript
path, seeds {10,11,12} x start ticks {1,3,6,8,11,16}, n = 18 a case, base `--traffic-off=streetturns`.

| case | fast contacts | crews (≥ base − 2) | all-in median (≤ +20 %) | friendly-stuck (≤ base × 1.2 + 10) | verdicts / crew-ticks slowed |
|---|---|---|---|---|---|
| Terminus head-on | 872 → **440 (−50 %)** ✓ | 173 → **170** ✗ | 56.5 → **71.0 (+26 %)** ✗ | 629 → **839** ✗ (limit 764) | 19 / 54 219 |
| Terminus crossing | 246 → 244 ✓ | 177 → 178 ✓ | 50.2 → 50.2 ✓ | 185 → 170 ✓ | 7 / 63 (fired briefly) |
| yard_open crossing | 232 → 232 ✓ | 163 → 163 ✓ | identical | identical | 0 |
| yard_open head-on | 97 → 97 ✓ | 180 → 180 ✓ | identical | identical | 0 |
| CPU mirror (`--side=rust`) Terminus head-on | 763 → 392 | 170 → 173 | 59.4 → 64.5 | 622 → 678 | 20 / 52 089 |

Why, per run (18 Terminus head-on runs): the take-turns does what it says. The waiting squad, mostly B, gets in 15–30 s
later while the other often gets in faster. But **one run (seed 12, tick 16) wedged**: the waiting squad still creeps
toward the meeting at 0.2 of its wish, and the two squads lock at the street mouth: 4 crews never in, 305 crew-s stuck
(base 20). That run is most of the stuck-time excess and every lost crew. The all-in time rises because one squad waits
by design; on these seeds that wait is longer than the bar allows (+26 %, against +20 %).
**In his terms:** *a "wait at the mouth of the street" rule halves the hard bumps when two of your squads meet head-on in
a street, but the waiting squad waits too long, and now and then the two lock up at the mouth, so it is not in the game.*
**For round 29:** the one-lane bridge needs a real waiting spot (hold outside the mouth, off the passing squad's line,
until its tail is past), not a creep toward the meeting. That is a stop, so the stall clock, asks and unstick must
honour it (manoeuvre's/brains' code: a request). Write the bar on his three things (crews, bumps between squads, the
last arrival) before any number. The rule lives on branch `traffic-t1b` (= `474558f8` + this write-up), with its live falsifier.

### FINAL VERDICT ON T1 (2026-10-12 ~21:50 PDT): v3 FAILED the pre-registered bar on the judged seeds; nothing ships

Judged run (builder0, `672eb785` both arms, GDScript path, seeds {4,5,6} x start ticks {1,3,6,8,11,16}, n = 18 a case;
base = `--traffic-off=turns,streetright,streetturns`, = main's path):

| case | fast contacts (bar: ≥ −25 % in 3 of 4, none > +10 %) | between squads | crews (≥ base − 2) | all-in median (≤ +20 %) | friendly-stuck |
|---|---|---|---|---|---|
| Terminus crossing | 183 → 199 (**+8.7 %**) | 82 → 58 | 176 → 179 | 35.6 → 42.7 (+19.9 %) | 100 → 37 |
| Terminus head-on | 871 → **419 (−52 %)** | 474 → 190 | 170 → 172 | 56.9 → 64.0 | 700 → 572 |
| yard_open crossing | 309 → **205 (−34 %)** | 108 → 84 | 165 → 163 (at the line) | 90.0 → 88.5 | 228 → 99 |
| yard_open head-on | 122 → 118 (−3 %) | 63 → 60 | 179 → 179 | 39.4 → 41.8 | 6.1 → 5.8 |
| CPU side (`--side=rust`) Terminus crossing | 183 → 171 | 82 → 59 | 177 → 178 | 35.6 → 33.5 | 100 → 26 |
| CPU side Terminus head-on | 868 → 431 | 474 → 191 | 169 → 174 | 56.9 → 64.3 | 703 → 583 |

Down ≥ 25 % in **2 of 4** (the bar needs 3): **FAILED**. Every other line held (no crew left behind, no case slower than
+20 %, friendly-stuck down in all four, the CPU side the same rule). The miss: at the Terminus crossing the bumps BETWEEN
squads fell 29 % but squadmates' own bumps rose 101 → 141; the bar counts all friendly contacts, and on these seeds that
case's base was low (183, against 294 on the tuning seeds). v3 was named the last attempt before it ran: no v4.
Data: `references/round28/traffic/` (README). Cost (not judged after the fail; builder0 loaded): shape 0.376 + refresh
0.139 = 0.515 ms a tick at Sumps 25 a side, n = 3, at a tick of 46.5 ms (load-scaled; NOT READABLE against 0.5 ms).

**In his terms:** *When two of your squads meet head-on in a street, one now waits at the mouth and the other comes
through — hard bumps halved, a few more crews in, about 7 s later for the last one.* *Squads crossing do take turns,
and bump each other less, but their own squadmates bump each other a little more while they slow, so in the street
crossing the total bumps did not drop.* It is not in the game: it missed the line set before it was measured.

**Where it lives:** branch `traffic-t1-v3` (= the tip at the verdict); stream/traffic's `game/` is main's again.

**For round 29 (what the measurements say):** (1) the head-on street rule (one-lane bridge: `_street_meeting`) is the
strongest single gain this stream has measured (−48 % tuning, −52 % judged, more crews in); judged alone, against a bar
on the cases it acts on, it would likely pass; (2) squad-level verdicts at crossings cut between-squad bumps 22–63 %; the
total is dominated by squadmates' bumps (a solo squad alone makes ~6 fast contacts a run on the Terminus crossing), which
the formation's own spacing (brains) owns; (3) a bar on what he sees ("nosing into each other" = between-squad contacts)
would separate the rule from its squadmates' noise; set before any numbers.

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

### T0: the base (builder0, `c6e32d03` = main's green `94b5fc0d` + docs, `make traffic-series TRAFFIC_FLAGS=--brains-off=native`, n = 18 a case = seeds {1,2,3} x start ticks {1,3,6,8,11,16}; 216 runs, 0 missing; 2026-10-12 19:09–19:23 PDT)

His two cases, two friendly squads of five mixed Law hulls. fstuck = friendly-stuck crew-s (total over 18 runs);
fast = friendly contacts closing > 2 m/s (total); all-in = every crew's last arrival, a never counted at the run's end
(median / mean, s); ratio = a squad's last arrival over its solo time (median / worst).

| case | all crews in | crews arrived | fstuck | contacts/run | fast | all-in med / mean | ratio | never |
|---|---|---|---|---|---|---|---|---|
| Terminus crossing | 15/18 | 176/180 | 156.9 | 32.9 | 294 | 45.8 / 55.2 | 1.11 / 2.52 | 1 |
| Terminus head-on | 10/18 | 170/180 | 489.1 | 66.3 | 716 | 64.3 / 65.4 | 1.39 / 2.83 | 5 |
| yard_open crossing | 8/18 | 169/180 | 196.5 | 27.8 | 277 | 75.6 / 72.2 | 1.25 / 2.56 | 4 |
| yard_open head-on | 17/18 | 179/180 | 8.9 | 11.4 | 113 | 37.2 / 38.1 | 1.04 / 2.45 | 0 |

**What a player sees at main:** on open ground head-on, almost every crew passes cleanly (ORCA). At the crossings and
in the street there are hard bumps (716 fast contacts in 18 runs head-on in the Terminus street, about 40 a run), and
in roughly 1 run in 4 a crew is still not in when its squad would have finished alone. **T1's bar against this base** (the
tuning seeds; the judged run re-bases on fresh seeds {4,5,6}): crews ≥ 174 / 168 / 167 / 177; fast ≤ 220 / 537 /
208 (−25 %) in three cases and ≤ 124 on yard head-on (+10 %); all-in median ≤ 55.0 / 77.2 / 90.7 / 44.6;
fstuck ≤ 198 / 597 / 246 / 20.7.

### T1 tuning (seeds {1,2,3} only; the JUDGED run is one run on fresh seeds {4,5,6})

Tuning arms are named v1, v2, v2b, …, and the version sent to the judged run is "the last attempt" the bar names
(there is exactly one judged run). Every arm: builder0, GDScript path, `TRAFFIC_WHICH=both`, n = 18 a case; the ratio
uses T0's solo runs. A base arm with every switch off (`--traffic-off=turns,streetright`) reproduced T0 row for row
(the off path is main's).

| arm (commit) | Terminus cross fast (between) | Terminus head fast (between) | yard cross fast (between) | yard head fast | crews (TC/TH/YC/YH) | all-in med (TC/TH/YC/YH) |
|---|---|---|---|---|---|---|
| base (T0) | 294 (116) | 716 (398) | 277 (118) | 113 (60) | 176/170/169/179 | 45.8/64.3/75.6/37.2 |
| v1 `32a91a71` turns + streetright | 278 | **990** | 241 | 114 | 176/175/**166**/179 | 39.7/66.0/89.5/37.8 |
| v2 `32a91a71` turns only | 290 (83) | 852 (451) | 244 (57) | 114 (60) | 176/174/165/179 | 39.7/65.8/89.3/37.8 |
| **v2b** `e85c92cc` + squadheading, wholesquad | **198 (43)** | 699 (370) | **162 (45)** | 113 (60) | 178/171/170/179 | 45.6/64.8/67.6/37.2 |
| v2c `c5b91937` + streetturns (wait at 0.4) | 198 (43) | 551 (302) | 164 (45) | 113 (60) | 178/175/171/179 | 45.6/56.8/70.9/37.2 |
| **v2d = v3** `672eb785` street wait at 0.2 | **198 (43)** | **374 (179)** | **160 (45)** | 113 (60) | 178/**177**/169/179 | 45.6/62.2/66.5/37.2 |

Read: (1) **keep-right in the street made his head-on case worse** (fast +38 %, friendly-stuck 489 → 844); off from v2.
(2) Most fast contacts are squadmates: the solo runs alone account for ~110 of Terminus cross's 294. The per-crew
verdict cut contacts between squads but not the totals. (3) v2b's squad-level reading of the crossing (the squads' mean
headings, the whole yielding squad slowing together) passes the bar at both crossings with margin, and arrivals are
no later (yard crossing all-in 75.6 → 67.6 s). (4) **What is left is the head-on meeting in the street** (−2 %), where the
bar's "3 of 4" needs −25 % (ORCA owns yard head-on, unchanged by design).
(5) v2b's clip of his Terminus head-on case (seed 1, fixed camera: `traffic-clip` now looks down Terminus' streets and
takes TRAFFIC_FLAGS) showed why: both squads wedge into ONE clump of ten in the 18 m street between the blocks. Keep-right
cannot help where a squad fills the street; taking turns can. **v2c/v2d: a head-on squad pair whose middle is a street
takes turns like a one-lane bridge.** The squad whose lead crew is still in the open waits; if both or neither are in
the open, the later one waits, then the greater id. The waiting squad slows as a whole, at 0.2 of its wish (still about
1.6 m/s, over the stall line), and the meeting is seen 8 s / 100 m ahead. v2c's clip: squad B comes down the street, A waits
at the mouth; 10/10 arrived (base 7/10), between-squad fast bumps 14 → 8.
(6) Friendly-stuck and pace: the waiting squad is not "stuck" in the probe's sense (it moves); friendly-stuck fell or held
in every case.

**v3 FROZEN = `672eb785`** (v2d's code; the orchestrator accepted the naming 2026-10-12: v1–v2d were tuning arms on seeds
1–3 only, v3 is the one judged version). Judged run launched: seeds {4,5,6}, both arms, all four cases, plus the CPU side
(`--side=rust`) on both Terminus cases.

### T2: what native ports (the settled rule, v3 = `672eb785`; `game/ai/traffic.gd` is the reference)

- **Seat:** `Movement._avoid`, between the route's wish and `Avoidance.solve`: `preferred = Traffic.shape(name,
  route_preferred)` when any of turns/streetright/streetturns is on, and the "no deflection" test still compares ORCA's
  answer with `route_preferred` (not the shaped wish). Nothing else in Movement changes; Traffic writes NO Movement
  member (no `native_stale` door: the state is Traffic's statics).
- **The table** (`Traffic.refresh`, every `TABLE_TICKS` = 3 physics frames, per match root): per team, per living
  hull: name, x, z, direction (velocity / |v| when |v| ≥ 1 m/s, else the hull's flat forward), |v|, `Avoidance.radius_of`,
  moving (= `is_under_way() and yield_to == "" and not in_kturn()`), group (`"e:" + brain.element.id`, or `"u:" + name`),
  and per group the normalized sum of its MOVING crews' directions (`gdir`). Verdicts older than their expiry frame are
  dropped at refresh. A new root clears answers, verdicts, street reads and shares.
- **Per crew** (`shape`): a crew re-solves when its answer is ≥ `SOLVE_TICKS` (6) old or `(frame + (name.hash() &
  0xffff)) % 6 == 0`, else reuses it. **Order matters**: a squad pair's verdict is made by whichever crew meets first and
  then kept, and `_shares` is filled by solves, so the C++ must solve crews in the same order and on the same frames as
  GDScript, reading the same statics (verdicts, shares, street cache) as shared state.
- **_solve:** for every other MOVING crew j of my team: skip if behind my line (`ahead < -clearance`); a head-on
  street case (`streetturns` on, crew facing ≤ cos 140°, other group, ahead > 0) reaches 100 m, everything else 45 m.
  Street case → `_street_meeting` (squad headings head-on, |lateral| ≤ 14 m, meet ≤ 8 s, the middle a street on first
  sight → one verdict per squad pair, `_decide_street`; the waiting squad's crews get cap 0 with floor `STREET_FLOOR`
  0.2 and a squad share 0.2). Else the real-meeting test (closest approach within clearance inside 4.5 s), then
  keep-right (only with streetturns OFF) or the crossing (`_crossing_kind`: squad headings between cos 140° and cos 30°;
  `_crossing` → `_decide` per squad pair; a yielding crew within 1 m of the zone edge does not yield; cap = entry /
  clear_at; squad share max(cap / v_me, 0.4) at the crossing point).
- **shape's output:** speed kept = min(max(cap, floor × wish), squad share × wish) where the squad share applies to a
  crew whose group noted one within SOLVE_TICKS and which is still short of the share's point (along − radius − 1.5 >
  1 m); the wish's direction is kept (keep-right, when on, rotates it first).
- **The street read** (`_street`): Pathing.closest_point (native nav already has it) probes every 4 m out to 16 m on
  each side; a probe > 1 m off the mesh walls that side; a street = both sides walled. Cached per key for 30 frames
  (keys: crew names, "@" + pair key, "@lead:" + group).
- **Switches** (the A/B): `--traffic-off=turns,streetright,streetturns` = main's path exactly (T0's 72 "both" runs on
  seeds 1–3 re-run with them off at `e85c92cc`: 72/72 identical in every crew's arrival, contacts, stuck time, end); `squadheading`, `wholesquad`, `streetfloor` select the tuning arms.
- **Counters** (measurement only): `Traffic.verdicts`, `crossing_yields`, `kept_right`.
