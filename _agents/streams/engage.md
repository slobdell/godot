# Stream: engage (a crew under his attack-move keeps going for the enemy; the 20 s drive back to his own edge, found and fixed)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 43** (C43.1, C43.3, CP43.0), your round-42
> brief `streams/archive/round42/engage.md` (Status: E1's replay probe, the trace rows, the launching trip-up with quoted seed lists,
> Known issues), and `game_design.md` *His playtest after round 42*. **You own:** `game/tactics/element_plan.gd`'s engagement functions
> (`_engage`, `_hold`'s and the orbit drill's in-range tests, `ENGAGE_RANGE_FACTOR`, the crew-reach read; NOT settle's deploy-step,
> halt-lay, seat-deal), `game/tactics/element_situation.gd` (additive), `game/tactics/drills.gd`, `game/tactics/firing_position.gd`,
> `game/control/order_executor.gd`'s `attack` / `attack_move` branches, `game/ai/order_controller.gd` (trace lines; behaviour only on
> the orchestrator's ruling), trace-only lines (flag-gated, default off) anywhere on the crew's order path including
> `game/ai/planner/planner_seam.gd` (merge note), `tests/tactics/test_engage*.gd`, `tests/engage/**`, `mk/engage.mk`.
> **Model:** Fable. **Machine:** builder0 light lane (J<=4); builder2 for a series over 24 fights. **Seeds:** 10301-10324 (bar),
> 10325-10348 (fight guards); his 56416 and dev 7001-7012 never a bar.

## The lead's direction (2026-10-27 ~20:00, verbatim)

"I was paying attention to the camera, but I didn't get far before seeing that my units all seemed incapable of moving to the west
side of the map. ... My first squad of tanks was never even able to settle for a simple target destination. I don't know if this is a
regression"

On the orchestrator's read of the recording: "I want you to track that as something to investigate in the next round. I'm not sure if
it's a bug per se, but it warrants investigation and improvement."

(The arrival half of "never able to settle" is manoeuvre's this round; yours is the War Rig that drove away under attack-move.)

## Where things stand (main at launch: see HANDOFF)

- **His recording:** `_agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz` (Locks, seed 56416, Gangs v
  Syndicate, round-42 main b12b17ac7 + docs, laptop 26-31 fps, 49 s). Census rows every 1 s (`MatchRecorder.CENSUS_S`), order rows
  with refusals, task rows. Read it with `python3 tools/recording_arrivals.py <file>`.
- **The anomaly (orchestrator's read):** under his attack-move to the far quay (-100, -15), the lead War Rig reached the west bank at
  (-105, 46), 46 m short of the west swing bridge, then turned and drove 100 m back to the north-east edge over 20 s (ticks 660-1320),
  fired nothing, met nothing (every enemy was south of the canal), ended `blocked terrain` at (-9, 95). His attack order on it at
  tick 806 showed on the crew only at tick 1380 (19 s). The planner seam refused every ask that match (18 asks, all k-turns:
  START_BLOCKED 8, GOAL_BLOCKED 1, NO_PATH 1, 0 plans).
- **Hypotheses to kill first (cheapest first, none shown):** (a) the route to the far quay was re-planned via another crossing (the
  west swing bridge's state, its "far" twin `arenas/locks.json` "west swing bridge (far)", or a lane cost) and the north-east drive is
  the path to the lock; (b) the element's leader / task moved (a squad task row re-aimed the crew); (c) `--attack-shot`'s firing-spot
  search picked a spot behind (its spot is "toward the enemy", but on a team-seen contact far south?); (d) an unstick / k-turn chain
  after START_BLOCKED drove it off; (e) the order latency (806 -> 1380) is the order queue or the executor holding a stale order.
- **The replay probe** (`tests/replay_orders.gd`, the orchestrator's; native owns it this round) re-issues his orders headless with the
  same seed / army / cap but diverges inside 2 s (his Guns jam at the start, the replay's drive off) and did not reproduce the
  turnaround with attack-shot on or off. Native's CP43.0 is making it faithful; don't wait for it.
- Shipped from round 42 that touch this crew: `--attack-shot` ON (firing positions), `--camera-danger` ON (camera only), the counter-
  lineup (the enemy's deal). Round 42's Known issues: SUPPRESS can stand in band with no line; the flank side pick is a knife-edge.

## Backlog (in order)

1. **A1 the turnaround, traced on his seed (report first, C43.3).** Rebuild his War Rig's situation without the replay: from the
   census at tick ~630 (positions, hp, orders of every unit), place the armies on Locks 56416 (your E1 probe's census-places method),
   issue his attack-move to (-100, -15) and his tick-806 attack, and trace per tick: the order the crew holds, the element task, the
   brain's choice, the route (its waypoints and which crossing), the planner asks and refusals, the mover's phase, the attack-shot spot.
   Reproduce the drive north-east or show it doesn't reproduce from that state. Then kill hypotheses (a)-(e) one by one, each by
   REMOVING the suspect (a switch off, a route pinned), never by a ratio. Send the trace table and your cause to the orchestrator
   before building anything.
2. **A2 the order latency.** Why his attack order at tick 806 reached the crew at tick 1380: trace the command from `RtsControls`
   through `order_controller` / `order_executor` to the element. If it is a queue that holds while a plan runs, say so with the ticks.
3. **A3 the fix, OFF behind a switch (ON when its bar passes; `=off` = round 42).** Whichever cause A1 shows, in your paths; if it is in
   the mover or the planner, the orchestrator rules (C43.3). Symmetric for the CPU. A test on the traced case first (it fails on today's
   main, passes with the fix).
4. **A4 Bar A, filed before any number on 10301-10324.** Workload: an attack-move across a canal on Locks (and one other arena with a
   crossing: crossing or docks), mixed squads, the CPU enemy dug in beyond; 24 seeds, BASE off v ARM on, one commit. Deciding (name it
   before the numbers, e.g.): crew-seconds driving AWAY from the order's point (distance to it rising for > 5 s with no contact) ARM <
   BASE by >= 2 se. Guards (filed first, unamended): Bar E1's lines at their round-42 levels (stuck crew-seconds, first hit, deaths),
   fight length, perf (us/tick within 1.05x), no SCRIPT ERROR; fight guards 10325-10348 on builder2 if over 24 fights.
5. **A5 after CP43.0:** read his turnaround on the faithful replay, ON and OFF; the clip for him if the fix ships (laptop, one Godot
   run under the lock; film outside `build/`).
6. **A6 (R43.13, after Bar A, its own bar; the R43.8 grant extended to the verdict's way in `traffic.gd`):** the street-hold
   VERDICT binds only the crews whose own routes run through the street (the route walk of A3 applied to every crew, not only
   the far ones), and the squad's way is its ORDERED heading, not the momentary mean of its crews' noses (his Guns read "east"
   with two crews slow and nose-east while their orders ran south-west).
7. **Stretch:** E2, the SUPPRESS stand on a STAGED draw (your round-42 proposal in the archived Status: a workload that exercises it,
   since 1 of 48 seeds did); the flank side latch.

## How to verify

`tests/tactics/test_engage*.gd`, `tests/engage/**`; `make quick-remote` (QUICK_BASE=your last green); `make remote T=check` only for a
hash you name. Smoke like a player: `make skirmish ARENA=locks SEED=56416`, his Gangs v Syndicate, attack-move a War Rig squad to the
far quay past the west swing bridge; does it keep going? Look at your screenshots.

## Don't touch

Settle's functions in `element_plan.gd`, `game/ai/movement.gd` and `game/ai/traffic.gd` (manoeuvre), `game/camera/**` (camera),
`native/**`, `tests/replay_orders.gd` (native), `game/match/**`, `game/ui/**`, `arenas/**`, `tests/baselines/**`. Don't push main.

## Waiting on the lead

Nothing. The clip, when A5 has one.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**2026-10-28 ~06:30 PDT (Fable). SHIPPED (pending the one combined check): A7, the across-water rule, ON** (`--engage-water=off`
/ env ENGAGE_WATER=off = round 42): a crew keeps its gun on a target across water but never moves for it. **Bar A7 PASSED every
line** (below: hops across water 34.8 -> 0.7 s a run, z -12; the drift off the crew's own order 21.5 -> 10.6 m, z -2.5; deaths
fewer, kills more, arrival sooner, damage and first hit unchanged, the named-attack cost within, Bar E1's lines byte-identical,
the suite ON green but for the three water maps' baseline rows, adopted: crossing, locks, gorge, read twice on builder0 at the
combined tree). **Merge candidate: 1c20cc1c2** = the flip cbf1eb935 + native's twin (pair/native-a7 457effa1a, the obey skip
natively, bit-identical) + main 36eacb71f + the three rows; its ONE full check (native path, perf-judge inside) is running on
builder0; the hash is named green or not when it reads. **A1 DONE** (the turnaround reproduced bit-exact on native's replay,
its cause shown by removal: Traffic's street hold at tick 478 dealt his lead War Rig a spot behind a corridor mouth 76 m away,
for a verdict his lead crew's nose, not its orders, made; `--traffic-off=hold` -> the crew arrives on the far quay at tick 810).
**A2 DONE** (no queue). **A3 built OFF** (`holdfar`, R43.8): Bar A FAILED (z -1.73; R43.18). **A6 built OFF** (`holdway`,
`holdroute`; R43.13/R43.18/R43.20): Bar A6 FAILED guard 2b; Bar A6 v2 FAILED line 1 in both arms (R43.21: the street-hold item
stops for the round; the round-44 candidate: side jam 352 -> 45 / 41 (z -5.2), side holds 705 -> 96 / 54, every guard passed).
**21dbaf662's code GREEN** on builder0 (3362/0, 28 targets ALL JUDGED: the tools and the OFF rules; on main since 36eacb71f).
Tools on the branch: the rebuild probe, the path probe, CREW_TRACE, `engage-replay-trace`, the hold probe + tables, the
across-water probe + table. **What he will notice:** on Locks / Crossing / Gorge a crew under attack-move across the canal no
longer hops along the bank for a target on the far side; it drives for the crossing with its gun firing across, and a crew told
to attack a target across the water goes round by the bridge.**

### A3 (R43.8): the street hold's far crew, built OFF at 724ccb5ce (`holdfar`)

`game/ai/traffic.gd` `_begin_wait` (the only behaviour hunk; `_spot_behind` / `hold_of` unchanged): a crew of the waiting squad
standing farther behind the street's mouth than the spot grid reaches (HOLD_BACK_M's last row, 43 m, + 2 x its radius) is not
dealt a spot. Its own route is walked with `_mouth` (its mover's path, then straight on along the squad's way, 80 m): if that
route meets THIS street's mouth (within FAR_THROUGH_M 20 m) the crew holds where it stands (`spot = here`, round 29's
"nowhere to pull aside" spot: `_live` written, `holding()` true on both paths; counter `tr_far_held`); otherwise it is
released from the wait (no spot, no `_live` entry, `holding()` false; counter `tr_far_released`). A wait left with no spots
ends at once. Symmetric (Traffic serves both teams). **Switch:** `holdfar` in `Traffic.DEFAULT_OFF` (OFF; `--traffic-on=holdfar`
is the arm); a pass removes it from the list and `--traffic-off=holdfar` is round 29's rule. **C43.4:** no C++ twin exists for
the spot dealing (native, 21:50: the only native read of the hold is `holding()` over `_live`, which this keeps); native_drive
stays ON under the rule. **Tests** (laptop, 724ccb5ce): `tests/engage/test_engage_far_hold.gd` 6/0 (the control dealt a spot at
the mouth to a crew 100 m back, the far crew released and the near crews still held, the grid's edge still held, a far crew
whose route runs into the street holds where it stands, symmetric for team 1, the switch listed OFF) and
`tests/test_traffic_hold.gd` 18/0 unchanged.

### Bar A (FILED 9e8313f8d, 2026-10-27 ~23:40 PDT, before any number on 10301-10324; R43.12: line (1) alone, the side-street
stage could not be planted in its time-box, below)

**Switch:** `holdfar` (Traffic.DEFAULT_OFF at filing; `--traffic-on=holdfar` is the ARM; a pass ships ON by removing it from the
list, `--traffic-off=holdfar` the escape). **Tree:** the filing hash's code frozen for both arms (Status-only commits after it are
not the tree). **Native:** the library ON on builder2 (`native engage-bar-a`), both arms on the native path (C43.4: no twin
exists for the spot dealing; native confirmed `holding()` reads only `_live`, which the rule keeps). **Workload:**
`tests/engage/hold_probe.gd` via `make engage-bar-a` (`hold_table.py --pair`): two friendly squads of one side meet head-on in a
street, squad A (five crews; by seed one of four hull sets, his three War Rigs first) coming out of the open with its rear rank
55-95 m behind its front (the arena clamp can pull it in; the actual gap is `far_m`), squad B (five) committed to the street from
the other side; A waits (round 29 T1's verdict), B passes. Stages by seed (seed / 2 mod 3): Terminus's west street, its east
street, the Locks' lock (the 16 m deck over the canal, walled by water: an attack-move across the canal), 8 seeds each. 75 s
windows, seeds 10301-10324, n 24 paired by seed, builder2 J14. **R43.12's second workload (a side-street stage with his AWAY
geometry as its own deciding line) was time-boxed and failed to plant** (four plantings on dev 7007-7013, laptop; the record in
`hold_probe.gd`'s SIDE_STAGE comment: his corridor's 6 m containers make the verdict's "lead in the open" and the meeting's
street test a knife-edge, a lead west of the corridor finds the bridge as its mouth, and on Terminus the mouth lands on the
squad's own way or at the far crews' feet when their noses make them the squad's "lead"); his seed stays the dev evidence for
that geometry, shown by removal (A1) and by the rule (below). **What it could break:** round 29 T1's purpose (a far crew released drives into the street while the passer is
in it: contacts and jam-seconds at the mouth); a far crew held where it stands arrives later (A's last arrival); the squad's
cohesion (the leg gate waits on a crew held far back); the CPU's squads take the same holds (fight lines).

**Deciding (paired by seed, pooled):**
1. **far_arrive_s**: the mean arrival (s) of A's far crews at the squad's destination (within 20 m; the window, 75 s, when never):
   ARM < BASE by >= 2 se (the paired mean). The far crews are the crews the rule is about, and their arrival is what the player
   sees of them. (The dev seeds showed the stage cannot plant his AWAY geometry: a staged head-on meeting puts the mouth ON the
   waiting squad's way, so a far crew's mouth spot is always roughly toward its own seat and `away_s` reads the same in both
   arms, 9 = 9 over 7001-7006; his drive came from a mis-aimed verdict in a side street off the squad's route. His seed is the
   dev case for that, shown by removal, below.)
**Exercised floor:** at least 16 of 24 seeds with a verdict in BASE AND the rule acting in ARM (`far_released + far_held >= 1`);
fewer -> NOT EXERCISED: extend with 10325-10348 pooled as one n 48 series on the same lines (the fight guards move to 10349-10372);
still fewer than 16 of 48 -> INCONCLUSIVE, no ship.
**Guards (filed first; paired se):**
2. **contacts_mouth** (friendly hull touches within 25 m of the street's middle, sum): ARM <= BASE + 1.645 se (T1's purpose).
3. **contacts_far** (a touch at the mouth involving one of A's far crews while B is still coming through, sum): ARM <= BASE +
   max(1.645 se, 2 touches) (the floor because BASE may read 0: a 0 se is no guard). The orchestrator's released-crew line.
4. **jam_s** (crew-seconds under 0.5 m/s within 25 m of the middle before arriving, sum): ARM <= BASE + 1.645 se.
5. **last_a_s** (A's last arrival within 20 m of its destination; the window when never; mean a run): ARM <= BASE + 1.645 se.
6. **Bar E1's lines** (`make engage-bar` on 10325-10348, ARM = `ENGAGE_FLAGS=--traffic-on=holdfar` v BASE, builder2 light):
   stuck crew-seconds, first hit, deaths each ARM within BASE +/- 1.645 se (the rule does not touch them: a null read expected).
7. **Fight lines G1-G5** (`native guard-run GUARD_KINDS=none GUARD_SIDES=green GUARD_AT=locks GUARD_SEEDS=10349..10372`, 600 s,
   CPU v CPU, 24 fights an arm, builder2 J14, `tools/scoreboard/guard.py --pair`): G1 green kills, G2 losses, G3 length (the
   paired mean, R42.13's form), G4 kill ratio each within BASE +/- 1.645 paired se; G5 no SCRIPT ERROR / missing GUARD_RESULT.
8. **Perf:** the merge candidate's (ON) full check on builder0, perf-judge PASS on its own line (ratio <= 1.05x); builder2 never
   judges perf (R37.20).
9. **Suite ON (C31.1):** the merge candidate = the filing tree with `holdfar` removed from DEFAULT_OFF: `make remote T=check`
   green (sim-baseline rows that move listed with the reason, adopted at the ship).
**Reported:** away_s and away_m (his geometry), held_s, far_released / far_held, verdicts, contacts / contacts_fast / contacts_cross, stuck_s, last_b_s;
his seed (dev, never a bar): `make engage-replay-trace ENGAGE_TAG=x ENGAGE_FLAGS=--traffic-on=holdfar`: OFF AWAY 82 m, ON best
17 m and no drive away, the match identical to his for 17 s (laptop, f920ba34d).
**A pass ships ON** (line 1 decided, 2-9 within).

### A6 (R43.13 / R43.18): the verdict reads ordered ways and binds only crews on the street, built OFF (`holdway`)

`game/ai/traffic.gd`: (1) `refresh` writes each crew's ORDERED way into its row (Movement._travel_direction toward its route's
next point; ZERO without a goal) and `_load` reads it as the crew's direction when present (a test's row[12..13]): the meeting
test, the squad's mean way (`gdir`), the lead and the hold's heading are then about where crews are GOING; a crew yielding
sideways is not "coming the other way". (2) `_begin_wait`: every crew of the waiting squad whose own route (its path, then
straight on its own way, 140 m: A3's `_route_passes`) never comes within 20 m of the mouth is released at the verdict (counter
`tr_way_released`); the others are dealt spots as round 29 says (and A3's far rule applies to them when `holdfar` is on too).
Symmetric. **Switch:** `holdway` in DEFAULT_OFF (`--traffic-on=holdway` the arm; a pass removes it from the list,
`--traffic-off=holdway` the escape). **Native:** nothing twinned reads the table's rows but through Traffic's GDScript
(`holding()` over `_live`, unchanged). **On his seed** (laptop, this tree, `engage-replay-trace ENGAGE_TAG=holdway
ENGAGE_FLAGS=--traffic-on=holdway`): the match leaves his at 14 s (the table's ways change every verdict from the start) and
Guns_1 reads best 38 m / no AWAY (OFF: AWAY 82 m). **Tests:** `tests/engage/test_engage_hold_way.gd` (7: the control reads
velocities, the ring-road squad is not held for a squad leaving the street, a yielding crew still meets head-on by its order,
a near crew whose route misses the street is released, its control, symmetric, the switch OFF).

### Bar A6 (FILED 98739047a, 2026-10-28 ~00:40 PDT, before any number on 10373-10396)

**Switch:** `holdway` (OFF at filing). **Tree:** the filing hash's code frozen for both arms. **Native:** ON on builder2
(`native engage-bar-a ENGAGE_HOLD_SWITCH=holdway`), both arms on the native path. **Workload:** `tests/engage/hold_probe.gd`,
seeds 10373-10396, n 24 paired by seed, 75 s, builder2 J10: **odd seeds (12)** the side-street planting `terminus_side` (his
mis-aimed case: squad A ordered EAST along Terminus's north ring road, its lead crew at the west street's north mouth nose-south,
two squadmates beside it, two far crews 65-75 m east on routes that never enter the street; squad B comes north through the
street: round 29 reads a head-on and holds all five A crews, two of them at their feet); **even seeds (12)** the three head-on
stages (terminus west / east, the Locks' lock; 4 each). **What it could break:** a real head-on no longer waited for (the
verdict now needs ordered ways within 40 deg of opposite); a crew on the street released by a route walk that missed it;
the hold's purpose at the mouth (contacts, jam).
**Deciding (the side-street seeds, paired, pooled):**
1. **off_arrive_s**: the mean arrival (s) of the stage's two off-street crews (A4, A5: the set is the stage's, so both arms
   count the same crews) at the squad's destination (within 20 m; the window, 75 s, when never): ARM < BASE by >= 2 se.
**Exercised floor (side seeds):** at least 8 of 12 with a verdict in BASE; fewer -> extend with 10397-10400 + 10573-10592 run
as `--stage=terminus_side` (pooled as one series, same lines); fewer than 8 of the pooled -> INCONCLUSIVE, no ship.
**Guards (filed first; paired se):**
2. **The hold's purpose, the mechanism (the head-on seeds):** verdicts ARM within BASE +/- 2 se, and held_on_s (crew-seconds
   holding of A's crews whose routes DO cross the street: all of A on these stages) ARM within BASE +/- 2 se. Real head-ons
   must still wait.
3. **contacts_mouth** (all 24): ARM <= BASE + 1.645 se. 4. **contacts_far** (all 24): ARM <= BASE + max(1.645 se, 2).
5. **jam_s** (all 24): ARM <= BASE + 1.645 se. 6. **last_a_s** (all 24): ARM <= BASE + 1.645 se.
7. **Bar E1's lines** (`make engage-bar` on 10397-10400 + 10573-10592, ARM = `ENGAGE_FLAGS=--traffic-on=holdway`): stuck
   crew-seconds, first hit, deaths each ARM within BASE +/- 1.645 se (a null read expected). 8. **Perf:** the merge
   candidate's full check on builder0, perf-judge PASS on its own line (<= 1.05x). 9. **Suite ON (C31.1):** the merge candidate
   (holdway out of DEFAULT_OFF) `make remote T=check` green; sim-baseline rows that move listed, adopted at the ship.
**Reported:** held_off_s (the off-street crews' holding: ~0 in ARM by construction, R43.18's note), way_released, away_s /
away_m, held_s / a_held_s, last_b_s, verdicts on the side seeds (expected 0 in ARM: no head-on by orders), far_arrive_s;
his seed by removal (dev, above). **Dev (laptop, 7007 / 7009 side, 7008 / 7010 head-on, not a number):** side: verdicts 1 -> 0
both, off_arrive 88.5 -> 71.5 (two runs), jam 40 -> 2, contacts_mouth 84 -> 24; head-on: verdicts 1 -> 1, held_on 114 -> 93.
**A pass ships ON** (line 1 decided, 2-9 within).

### Bar A6 v2 (FILED 13fbe1a5d, 2026-10-28 ~01:40 PDT, before any number on 10601-10648; R43.20: the LAST re-file of this item this round)

**Two arms against one BASE, each judged on the same lines independently:** **ARM-W** = `--traffic-on=holdway` (the ordered-way
read alone: no release); **ARM-WR** = `--traffic-on=holdway,holdroute` (the read + the release judged on the crew's navmesh route
to its SQUAD'S destination at the verdict: `_route_reaches`, one `Pathing.find_path` a crew; the straight line without a map;
its current leg and way when the squad has no destination). Bar A6's first cut (98739047a) judged the crew's current leg
(FAILED 2b, above). **Tree:** this hash's code for all three arms. **Native:** ON on builder2 (`native engage-bar-a6`), every
arm on the native path. **Workload and seeds:** as Bar A6 (odd seeds the side-street planting, even the three head-on stages),
**10601-10624**, n 24 paired by seed, 75 s, J10. **Lines, unchanged from Bar A6:** 1 off_arrive_s (side 12) ARM < BASE by >= 2 se;
2a verdicts and 2b held_on_s (head-on 12) within BASE +/- 2 se; 3 contacts_mouth, 4 contacts_far (+2 floor), 5 jam_s,
6 last_a_s (all 24) within 1.645 se; 7 Bar E1's lines on **10625-10648** (ARM = the shipping arm's switches); 8 perf: the ON
check's perf-judge <= 1.05x on builder0; 9 suite ON. **10 (new, R43.20): the route test's cost**, `route_ms_per_verdict` (Traffic's
route_usec over its verdicts, ARM-WR) reported with its queries a verdict; the ON check's perf-judge is the line. **Exercised floor**
as Bar A6 (8 of 12 side seeds with a verdict in BASE; the extension pool is none: a shortfall is INCONCLUSIVE). **Ships:** the arm
that passes every line; both -> the better line 1; neither -> both stay OFF with their reads and the item stops for the round.
**Tests** (laptop, 13fbe1a5d): `test_engage_hold_way.gd` 9/0 (adds: a crew whose route to the destination runs by another street is
released; a crew whose leg lies beside the street but whose route crosses it is HELD, Bar A6's miss; the way read alone releases
nobody), `test_engage_far_hold.gd` 6/0, `test_traffic_hold.gd` 18/0.

### Bar A6 v2 READ (builder2, native ON in all 72 logs, 13fbe1a5d, `native engage-bar-a6` 10601-10624, J10, 75 s, n 24 paired = 12 side + 12 head-on, one arm at a time, 2026-10-28 ~01:50-02:20 PDT, box load 4-42 (camera's work beside); tables `scratchpad/bar-a6v2/pair_w.txt`, `pair_wr.txt`)

| line | BASE | ARM-W | mean / se / z | ARM-WR | mean / se / z | reading |
|---|---|---|---|---|---|---|
| exercised (side) | 12 verdicts of 12 | | | | | floor 8 met |
| 1 off_arrive_s (deciding, side 12) | 717.5 (59.8 s a run) | 641.5 (53.5) | -6.33 / 5.16 / **-1.23** | 664.0 (55.3) | -4.46 / 4.96 / **-0.90** | the right way, short of 2 se: **FAIL, both arms** |
| 2a verdicts (head-on 12) | 13 | 13 | 0 / 0 | 13 | 0 / 0 | PASS both |
| 2b held_on_s (head-on 12) | 652 | 577 | -6.25 / 7.70 / -0.81 | 406 | -20.5 / 11.85 / -1.73 | within 2 se: PASS both (v2's route test fixed Bar A6's miss: z -3.07 -> -1.73) |
| 3 contacts_mouth (24) | 861 | 624 | -9.88 / 7.08 | 617 | -10.17 / 7.13 | PASS both (fewer) |
| 4 contacts_far (24) | 59 | 44 | -0.62 / 1.70 | 46 | -0.54 / 1.69 | PASS both |
| 5 jam_s (24) | 591 | 385 | -8.58 / 5.97 | 405 | -7.75 / 6.48 | PASS both |
| 6 last_a_s (24) | 1702 | 1628 | -3.08 / 2.99 | 1628 | -3.08 / 2.99 | PASS both |
| 10 route cost (WR) | | | | 0.59 ms a verdict a run (3.3 find_path queries); head-on 0.98 ms, side 0.20 ms | | reported |
| reported | side verdicts 12 -> 4 (both arms: the way read), side held 705 -> 96 (W) / 54 (WR), side jam 352 -> 45 / 41 (z -5.2), head-on way_released 13 crews (WR), far_arrive_s -3.3 / -2.4 (se 3.2), away_s 71 -> 36 / 28 | | | | | |

**Verdict: Bar A6 v2 FAILS its deciding line in both arms** (W z -1.23, WR z -0.90; every guard passes in both; the mechanism
guard that failed Bar A6 passes for WR at z -1.73). The effect on the side stage is real but smaller and noisier than Bar A6's
read on 10373-10396 (-11.6 s, se 4.1 there; -6.3 / -4.5 s, se 5 here: the seeds' hull sets and jitter), and at n 24 neither arm
clears 2 se. **R43.20: both stay OFF with their reads; the item stops for the round. Not amended; lines 7-9 not run.**
For the record (not a ship): on the side stage the way read alone removes two thirds of the mis-aimed verdicts (12 -> 4), 86 %
of the waiting squad's holding seconds and 87 % of its jam-seconds at the mouth, at no cost on any guard; the route release adds
little on top and costs 0.6 ms a verdict.

### Bar A6 READ (builder2, native ON in all 48 logs, 98739047a, `native engage-bar-a ENGAGE_HOLD_SWITCH=holdway` 10373-10396, J10, 75 s, n 24 paired = 12 side + 12 head-on, 2026-10-28 ~00:45-01:05 PDT, the box at load 23-37 with camera's work; table `scratchpad/bar-a6/pair_table.txt`)

| line | BASE | ARM | paired mean | se | z | reading |
|---|---|---|---|---|---|---|
| exercised (side) | 12 verdicts of 12 | | | | | floor 8 met |
| 1 off_arrive_s (deciding, side 12) | 593.5 (49.5 s a run) | 454.5 (37.9) | **-11.58** | 4.07 | **-2.84** | **PASS** |
| 2a verdicts (mechanism, head-on 12) | 14 | 11 | -0.25 | 0.18 | -1.39 | within +/- 2 se: PASS |
| 2b held_on_s (mechanism, head-on 12) | 829 | 339 | **-40.8** | 13.3 | **-3.07** | **outside +/- 2 se: FAIL** |
| 3 contacts_mouth (24) | 607 | 644 | +1.54 | 8.40 | 0.18 | PASS |
| 4 contacts_far (24) | 50 | 52 | +0.08 | 1.83 | 0.05 | PASS |
| 5 jam_s (24) | 552 | 329 | -9.29 | 7.67 | -1.21 | PASS (better) |
| 6 last_a_s (24) | 1578 | 1458 | -5.00 | 3.42 | -1.46 | PASS |
| reported | side: verdicts 12 -> 2, held 433 -> 10, jam 112 -> 27 (z -2.84), away_s 7 -> 0; head-on: way_released 13 crews, away 24 -> 11, last_b_s 805 -> 861 (se 6.4); all: far_arrive_s -6.9 (se 3.2), stuck -19 (se 15) | | | | | |

**Verdict: Bar A6 FAILS guard 2b as filed** (line 1 passes; the outcome guards pass). The cause is in the release test, not the
ordered-way read: on the head-on stages 13 crews whose squads WERE going through the street were released (`way_released`),
because `_route_passes` walks the crew's CURRENT mover path (to its seat, often a short leg laid beside the street) and then a
straight line on its own way: a seat laid 20 m off the mouth's line misses the 20 m test and the crew is released although
the squad's destination lies beyond the street. Real head-ons must still wait: that is what 2b guards. **Not amended; nothing
ships.** Lines 7-9 not run. **A6 v2 (proposed):** judge "the route runs through the street" on the crew's navmesh route to its
SQUAD'S DESTINATION (`Pathing.find_path` at the verdict, one query a crew), not on its current leg; the ordered-way read (1)
stays as built (it is what killed the mis-aimed verdict on the side seeds: 12 -> 2). Needs a fresh seed block from the
orchestrator (the registered 10397-10400 + 10573-10592 are the Bar E1 guard seeds).

### Bar A READ (builder2, native ON in every log, 9e8313f8d, `native engage-bar-a` 10301-10324, J14, 75 s, n 24 paired, 2026-10-27 22:05-22:28 PDT; 24 of 24 results an arm, no timeout, the box also carrying camera's full check; table `scratchpad/bar-a/pair_table.txt`)

| line | BASE | ARM | paired mean | se | z | reading |
|---|---|---|---|---|---|---|
| exercised floor | 23 verdicts | the rule acted on 16 seeds (far_released 18 + far_held 15 crews) | | | | 16 of 24: the floor (16) met exactly |
| 1 far_arrive_s (deciding) | 1294.0 (53.9 s a run) | 1236.5 (51.5) | **-2.40** | 1.38 | **-1.73** | the right way, **short of 2 se: FAIL as filed** |
| 2 contacts_mouth | 622 | 626 | +0.17 | 1.39 | 0.12 | PASS |
| 3 contacts_far | 141 | 145 | +0.17 | 0.21 | 0.78 | PASS (<= BASE + 2) |
| 4 jam_s | 620 | 560 | -2.50 | 1.17 | -2.14 | PASS (better) |
| 5 last_a_s | 1517 | 1490 | -1.12 | 2.07 | -0.54 | PASS |
| reported | away_s 74 -> 71, away_m 100.7 -> 100.0 (the head-on stage, as expected: no AWAY geometry), held_s 2005 -> 1686 (-13.3 a run, z -3.65), a_held_s 1162 -> 860 (z -3.41), stuck_s 4118 -> 4041, contacts 1015 -> 1031, last_b_s 1626 -> 1602 | | | | | |

**Verdict: Bar A FAILS its deciding line as filed** (z -1.73; the guards all pass; the rule acts where it should and takes 13 s
of holding a run off the squad). Lines 6-9 (Bar E1's probe, the fight guards, perf, the suite ON) were not run: a failed deciding
line ships nothing. Where the arm gained: 10323 (A's last arrival 75 -> 34 s), 10324 (63 -> 51), 10305 away 11 -> 7; lost: 10317
(51 -> 75: a far crew held in place, `far_held`, arrived late). The eight seeds the rule never touched (10303 no verdict; 10308-11,
10313, 10315, 10322: B waited, A's far crews unheld) are identical in both arms, as they must be. **Not amended.** Proposed to the
orchestrator: a second filing (Bar A v2) on fresh 10325-10348, same workload and lines, read pooled with these as n 48 (a declared
extension, R42.19's form), OR the rule stays OFF and his seed's removal evidence stands as A1's finding until A6 (the verdict
fix) gives the head-on stage something to measure.

### Report for the close (round 43, engage)

**Done:** A1 (the cause, shown by removal on his exact match), A2 (no queue), A3 (`holdfar`, OFF), A4 (Bar A, Bar A6, Bar A6 v2:
all FAILED their deciding lines; every guard passed in every bar), A5 (his replay by removal in each bar: AWAY 82 m -> best 17 m
under holdfar / 38 m under holdway; the GDScript-v-native caveat is native's, now a shim), A6 (`holdway`, `holdroute`, OFF),
**A7 (the across-water rule, ON: Bar A7 PASSED every line; merge candidate 1c20cc1c2)**.
**Not done:** the stretch (E2's staged draw, the flank latch): no time after three bars.
**Decisions:** the far rule measures the crew's straight distance to the mouth (the squad's mean way lied on his seed); the
route-bound release walks the crew's navmesh route to its SQUAD'S destination (its current leg lied on the head-on stages);
the side-street stage is the terminus planting that fires a verdict every seed (his corridor's 6 m containers made every other
planting a knife-edge). **Questions for the lead:** none; the item is his "investigate and improve": investigated (the cause is
a traffic rule, not his units' will), improved only on the branch behind switches (nothing passed its bar).
**Known issues (left):** (1) the street hold's verdict reads crews' noses and binds the whole squad (A6 removes it on the
side stage: verdicts 12 -> 4, holding -86 %, jam -87 %; it did not clear a 2-se arrival line at n 24 twice); (2) the ENGAGE-across-
water hops (R43.5 grant, unbuilt: a crew under attack-move engages a team-seen contact across the canal within range + 15 m and
hops direct, swinging a 14 m hull round); (3) the container_20 stall (manoeuvre's, R43.8); (4) round 42's: the SUPPRESS stand,
the flank side knife-edge. **What to playtest:** `make skirmish ARENA=locks SEED=56416` (Gangs v Syndicate): attack-move a War Rig
squad from the north bank to the far quay past the west swing bridge; the crews should drive for the bridge with their guns
firing across the canal, no hopping back and forth along the bank, no reverse; `SKIRMISH_FLAGS="--engage-water=off"` is
round 42. His recording's drive-away itself was the street hold (OFF rules on the branch). To see the cause: `make engage-replay-trace ENGAGE_TAG=x`
(his match, the War Rig's drive) v `ENGAGE_FLAGS=--traffic-off=hold` (it arrives); `--traffic-on=holdway` is A6's arm.
**Next steps (a later round):** A6 with a deciding line the head-on stage moves at n 24 (the side stage's arrival is noisy:
se 4-5 s; a verdict-count or holding line would decide at n 12, but is mechanism), or his geometry in the natural draw (CPU v
CPU censuses of mis-aimed verdicts: a verdict whose waiting crews' routes never cross the street); the across-water hops.
**Merge notes (shared files):** `game/ai/tank_brain.gd` (R43.5 grant, A7): `ENGAGE_WATER` (static, ON; `--engage-water=off`),
`water_between` (test seam), `_across_water`; `_obey`'s in_reach skips a contact across water; `_act` ENGAGE: the across-water
branch before `_combat_move` (a named attack routes to it; else face and fire); the gun order unchanged. Twinned: pair/native-a7
(decide_native.cpp's obey skip, native_decide.gd's two config keys, test_native_decide_water). `tests/baselines/sim_state_hash.txt`:
crossing, locks, gorge (read twice at 396bf3b0e). `game/ai/traffic.gd` (R43.8 / R43.13 / R43.20 grants): DEFAULT_OFF += holdfar, holdway,
holdroute; counters far_released / far_held / way_released / route_usec / route_queries in report() and reset_counters();
`refresh` rows carry [12..13] the ordered way (ZERO unless holdway); `_load` reads it under holdway; `_begin_wait`: the holdroute
release, the holdfar far rule (`_spot_behind` only for the rest), a wait with no spots ends; new `_route_reaches`, `_route_passes`,
FAR_THROUGH_M / FAR_ROUTE_M; a TRAFFIC_FAR line under log_waits. All dead at the defaults (every switch in DEFAULT_OFF); the
hold tests unchanged (18/0). `game/ai/tank_brain.gd`: CREW_TRACE (static, `_crew_trace`, one call after `_act`; default off).
`mk/engage.mk`: the round-43 targets. New files all engage's (tests/engage/*, .uid beside each .gd). No baseline moves expected
(nothing ON). The full check of the tip: below when it reads.

### A7 (R43.5 / R43.21): the across-water census (laptop, e996756d0 + the probe, `make engage-water`, dev 7001-7012, 60 s, n 12, native on; NOT a number)

The stage (`tests/engage/water_probe.gd`): a squad of five under attack-move to the far-bank objective (Locks on even seeds, Crossing
on odd), five Syndicate defenders (3 Limousines, a Railgun, a Skimmer) dug in on the far bank beside the crossing's exit. Per crew-tick
under an attack / attack-move order, the brain in ENGAGE / SUPPRESS on a contact whose straight leg crosses water:

| line (a run, mean of 12) | value | se | reading |
|---|---|---|---|
| water_s: crew-seconds in the state | 27.1 (4.5 of 5 crews) | 3.9 | every seed |
| water_far_s: of those, the contact beyond the gun's range (cannot hit) | 4.0 (3.2 crews) | 1.3 | every seed, small |
| fire_s: the gun on that contact | 23.0 | 4.2 | the guns DO fire across: fine |
| hop_s: direct combat hops while in the state (hop_rev_s reverse; hop_far_s while far) | 19.2 (5.2 reverse; 2.1 far) | 3.1 | **the dumb part: 70 % of the state is spent moving for a shot across water** |
| damage_water / hits / first hit (the squad's guns on the defenders while the whole squad is across water) | 372 / 11.8 / 10.2 s | 105 / 3.3 / 2.5 | the guard: must not get worse |
| off_order_m: the largest rise of a crew's distance to its own order goal while in the state | 22.6 (max 74.5, seed 7001) | 6.3 | his drift, in miniature, every seed |
| last_a_s / deaths / kills | 60 (never) / 4.75 / 1.75 | | the stage is too lethal for an arrival line (the bar's stage: three Limousines) |

**So:** the crew brain engages across water in every seed, mostly on contacts it CAN hit (the guns fire, 372 damage a run), and
the harm is the combat move: 19 s a run of direct hops along the bank, a quarter of them in reverse, 22 m (up to 75 m) off the
crew's own order. **The rule (A7, OFF behind `--engage-water=on` until its bar; `=off` the escape after):** keep the gun on a
hittable target across water, never move for it: (1) under attack-move a contact across water (SlotGround.leg_wet from the crew)
is not "met on the way" (`_obey`'s in_reach), so MOVE keeps the route and the gun fires at will; (2) under a named attack or an
ENGAGE already chosen, a contact across water takes the not-visible branch (`_move_to(contact.position)`, routed: the way round
is the bridge) with the gun on it, never `_combat_move`. Symmetric. Bar A7 to be filed before any number on 10649-10672 (Bar E1's
lines on 10673-10696): deciding hop_s (across water) ARM < BASE by >= 2 se and off_order_m ARM < BASE by >= 2 se; guards
damage_water, first_hit_water_s, deaths, kills, last_a_s no worse (1.645 se), Bar E1's lines, perf, suite ON.

### A7 built OFF (`--engage-water=on` / env ENGAGE_WATER=on the arm; a pass ships ON with `=off`): a54e1bf52

`game/ai/tank_brain.gd`: `ENGAGE_WATER` (static) + `_across_water` (SlotGround.leg_wet; `water_between` a static test seam);
(1) `_obey`: a visible contact across water is not in `in_reach` (not "met on the way" under an attack-move: MOVE keeps the
route, the gun fires at will); (2) `_act` ENGAGE: a contact across water never reaches `_combat_move`: a named attack on it
drives to it by the route ("water between: going round by the road"), anything else stands and fires across ("water between:
firing across"); the gun order is set before the branch, unchanged. Symmetric (the CPU's crews run the same brain). OFF:
byte-identical. Tests `tests/engage/test_engage_water.gd` (5: the control fights across water as today, under the rule a
contact across water is not met on the way and a dry one still is, the act step stands and fires across and never hops, OFF
unchanged, the flag).

### Bar A7 (FILED a54e1bf52, 2026-10-28 ~03:30 PDT, before any number on 10649-10696)

**Switch:** `--engage-water=on` (OFF at filing). **Tree:** the filing hash's code for both arms. **Native (C43.4):** `decide_native.cpp` twins `_obey`'s in_reach
(line ~258), so the rule's half (1) does not act on the native decide; `_act` is GDScript on both paths. **Both arms run with
`--brains-off=native_decide`** (the drive and the rest native; the decide on GDScript for both), said here before the series;
native is asked to twin the across-water in_reach test before any ship ON. **Workload:** `tests/engage/water_probe.gd` via `make engage-water` (ENGAGE_FLAGS=--engage-water=on the
ARM), seeds 10649-10672 (Locks even, Crossing odd), 60 s, n 24 paired, builder2 J10: a squad of five (his hull sets) under
attack-move to the far-bank objective, three Limousines dug in on the far bank by the crossing's exit. **What it could break:**
a crew that no longer closes on a target across water may shoot it less (damage, first hit) or arrive later; a crew that
drives round by the bridge under a named attack may die on the dug-in bank; the CPU's crews change the same way (fight lines).
**Deciding (paired by seed, pooled):** 1. **hop_s** (crew-seconds of direct combat hops while in ENGAGE/SUPPRESS on a contact
across water under an attack / attack-move order): ARM < BASE by >= 2 se. 2. **off_order_m** (the largest rise of a crew's
distance to its own order goal while in that state, a run): ARM < BASE by >= 2 se. **Both.**
**Guards (filed first; paired se):** 3. **damage_total** (every hit on the defenders, from any bank; sum a run) ARM >= BASE -
1.645 se; 4. **first_hit_s** (the squad's first hit on a defender, any bank) ARM <= BASE + 1.645 se; 5. deaths ARM <= BASE +
1.645 se; (3 and 4 AMENDED before any bar number, at the dev run on 7001-7012 below: `damage_water` and `first_hit_water_s` count
only while the WHOLE squad is still across water from the victim, so a squad that crosses sooner reads as "shooting less across
water" (5796 -> 1215 at equal kills and fewer deaths); the outcome a player sees is the damage done and the first hit, whichever
bank. damage_water, hits_water and first_hit_water_s stay reported); 6. kills ARM >= BASE - 1.645 se; 7. last_a_s ARM <= BASE + 1.645 se; 8. **the named-attack
cost** (the orchestrator's): the probe's named-attack arm (`--named=on`: the squad's order is `attack` on the nearest defender
instead of the attack-move; a second 24-seed pair on the same seeds, BASE-named v ARM-named): deaths ARM <= BASE + 2 se,
hop_s reported; 9. Bar E1's lines (`make engage-bar` on 10673-10696, ARM = `ENGAGE_FLAGS=--engage-water=on`): stuck crew-
seconds, first hit, deaths within 1.645 se; 10. perf: the ON check's perf-judge <= 1.05x (builder0); 11. suite ON (C31.1):
`make remote T="check ENGAGE_WATER=on"` green, sim-baseline rows that move listed and adopted at the ship.
**Reported:** water_s, water_far_s, fire_s, hop_rev_s, hop_far_s, crews_water / crews_far, hits_water, damage_water,
first_hit_water_s. **Tree, re-filed:** 8ac00d19b (the probe's damage_total lines and the `engage-bar-a7` target; the rule's code
unchanged since de626d7e1). **A pass ships ON** (1-2 decided, 3-11 within).
**Dev (laptop, a54e1bf52's code, both arms `--brains-off=native_decide`, 7001-7012, 60 s, n 12 paired, NOT a number):** hop_s 459 ->
10 (z -8.0), off_order_m 352 -> 60 (z -4.1), water_s 759 -> 147, deaths 28 -> 20 (z -2.4), kills 26 = 26, last_a 720 -> 668
(se 3.0), damage_water 5796 -> 1215 (the attribution artefact above), first_hit_water 96.6 -> 42.5.

### Bar A7 READ, lines 1-8 (builder2, 8ac00d19b's probe + de626d7e1's rule (the Status commit 7b873d365 on top), `native engage-bar-a7` 10649-10672, J10, 60 s, both pairs with `--brains-off=native_decide` (the library present: the wrapper's `native on`; the exec report line is absent from every log, so the arms are read as "the same path in both", not "native"), 2026-10-28 ~03:40-04:10 PDT, the box at load 30-54 with camera's work; tables `scratchpad/bar-a7/pair_move.txt`, `pair_named.txt`; 24 results an arm, no timeout)

| line | BASE | ARM | paired mean | se | z | reading |
|---|---|---|---|---|---|---|
| 1 hop_s (deciding) | 835.2 (34.8 s a run) | 16.1 (0.7) | **-34.1** | 2.85 | **-12.0** | **PASS** |
| 2 off_order_m (deciding) | 515.8 (21.5 m a run) | 254.4 (10.6) | **-10.9** | 4.33 | **-2.52** | **PASS** |
| 3 damage_total | 32341 | 35273 | +122 | 108 | +1.13 | PASS (>= BASE - 1.645 se) |
| 4 first_hit_s | 104.0 (4.3 s a run) | 114.8 (4.8) | +0.45 | 0.68 | +0.66 | PASS (<= BASE + 1.12) |
| 5 deaths | 64 | 48 | -0.67 | 0.23 | -2.89 | PASS (fewer) |
| 6 kills | 49 | 57 | +0.33 | 0.20 | +1.70 | PASS (more) |
| 7 last_a_s | 1374.6 | 1239.6 | -5.63 | 3.11 | -1.81 | PASS (sooner) |
| 8 the named-attack pair: deaths | 60 | 57 | -0.12 | 0.31 | -0.40 | PASS (<= BASE + 2 se); hop_s 656 -> 12, off_order_m 781 -> 405 (z -1.9), damage_total 32576 -> 30929 (se 109), kills 54 -> 53, first_hit 151.9 -> 107.8 |
| reported | water_s 1353 -> 467, water_far_s 161 -> 50, fire_s 1171 -> 401, hop_rev_s 267 -> 4, hop_far_s 75 -> 2, damage_water 12415 -> 2875 (the across-water attribution, above), hits_water 400 -> 58, first_hit_water_s 138.8 -> 171.7 (se 3.2), crews_far 68 -> 44 | | | | | |

**His seed on the shipped tree** (laptop, 5e6bed8c3's code = 1c20cc1c2, `engage-replay-trace`, native library, shimmed):
ON (the default) Guns_1 best 43 m from his click and NO drive away (the match leaves his at 15 s: the crews no longer hop
for the Syndicate line across the canal, so the street hold's mis-aimed verdict at 478 never forms as it did); OFF
(`--engage-water=off`) his match exactly: AWAY 82 m. **Lines 10-11 PASS** (builder0, `make remote T="check ENGAGE_WATER=on"` on 5f22f82cc's tree = 8ac00d19b's code with the
rule forced ON, 2845 s, 2026-10-28 ~05:35 PDT: `27 passed, 1 FAILED` where the one FAILED is sim-baseline, as a default-ON
flip must before its rows are adopted: **crossing, locks and gorge MOVED** (the maps with water between the lines; foundry, yard,
pit, terminus, sumps, parade, archipelago, cut, docks, yard_open unmoved); every test passed; perf-judge JUDGED on its own line
(scenario_perf refused by ai-scenarios-check as always: perf-judge judges it). **Bar A7 PASSES every line: the rule ships ON.**
**Lines 1-8 PASS. Line 9 PASS** (builder2 light lane, native off in that folder, `engage-probe` ENGAGE_ARM=on on 10673-10696,
ewoff = `--brains-off=native_decide` v ewon = + `--engage-water=on`, n 24 paired, 04:15-04:30 PDT: BYTE-IDENTICAL on every
seed: stuck 128.5 = 128.5, first hit 7.02 = 7.02, deaths 25 = 25, hits 3094 = 3094; the E1 stage has no water between a crew
and its target, so the rule never fires there: the null read expected). Lines 10 (perf-judge on the ON check) and 11 (the
suite ON, `make remote T="check ENGAGE_WATER=on"` on builder0) follow the tip's own check (21dbaf662's code), still on builder0.
**R43.23:** the flip ships WITH native's twin of the in_reach skip (native is on it, off de626d7e1); the merge candidate = the
flip (ENGAGE_WATER default ON, `--engage-water=off`) + the twin, ONE full check on the combined tree (native path, its
perf-judge inside it).

### A1: the turnaround on his seed (laptop, native library ON, `make engage-replay-trace ENGAGE_TAG=on`, 2d43b1e88, his recording, 50 s, n 1, deterministic)

The replay (native's CP43.0, `tests/replay_orders.gd`) puts Green_Guns_1 **0.0 m off his census at every second for 48 s**
(`tests/replay/divergence.py --crews=Green_Guns_1,Green_Guns_3`: both crews 0.0, PASS) and `tools/recording_arrivals.py` reads the
replay's own recording exactly as his: `Guns_1:best61m/no-arr/AWAY82m`. The trace (`--crew-trace=Green_Guns_1`, a new
measurement-only TankBrain line: the K1 order, the choice and why, the move asked, the mover's goal / steering point / path / driver,
the planner's last refusal, the street hold) and `--element-trace=Guns`, ticks 445-1400:

| ticks | the crew holds (K1) | the element (task, slot for Guns_1) | the brain chose | the mover drove at | what happened |
|---|---|---|---|---|---|
| 445-550 | `attack_move` to its vee seat (-85, 18.5) then react-to-contact's (-95, 38) / (-102, 36), paced 0.35-1.0 | task move+drills to (-100, -15); anchor (-89.5, 8.8); crossing = the west bridge (-88, 12)->(-98, -11) | MOVE | the seat, then **from tick 478 the hold spot (-29.7, 100.0)** (`steer`), driver `route` | Traffic verdict at 478: squad e:5 (Guns) WAITS for e:6 (his Hunters, moving west at z 50-65 across the Guns' way); spots dealt to Guns_3, Guns_4 AND Guns_1 |
| 556-694 | `attack_move` (react to contact: 15 m toward the contact / the seat across the bridge) | task move+drills; drill react_to_contact; swarm/vee flapping | **ENGAGE Rust_Hunters_3 / _4 across the canal, 58-61 m** ("going for its side, weaving" / "no line of fire: going round") | direct REVERSE hops to (-69, 64) and (-71, 61); a direct forward hop to (-112, 81); routed moves to the contact's spot (-112, -12) | the hops swing the 14 m hull from yaw 110 deg to -178 deg (nose north) at 9 m/s; no shot (the gun's range 50, effective 36) |
| 700-1005 | `attack_move` to the seat (-80.6, 20.6), then (-77.0, 24.4): on the NORTH bank, 45 m south-east of the crew, steady | task move+drills, then his attack on Rust_Hunters_4 (tick 807: the task is `attack` from t 27.0); slot (-77, 24.4) stands t 27-35 | MOVE ("attack-move") | **steering point (-29.7, 100.0) for 15 s** (driver `route`, throttle 0.75-0.99, no k-turn, no unstick, no planner refusal, no fire detour) | **the drive away: (-103, 55) -> (-24, 98), 90 m north-east at 8-12 m/s, 47 -> 90 m off its own seat** |
| 1023-1060 | same | same | MOVE | the seat (-77, 24.4): the hold released at ~1023 (18.2 s after the verdict; HOLD_CAP_S is 20) | the hull starts its turn back (yaw -117 -> -67) |
| 1063-1108 | react-to-contact `attack_move` naming Rust_Hunters_4, (-24, 87) / (-11, 85) / (-11, 75) | task attack; drill react_to_contact | MOVE | those points | 10 s more at the north edge |
| 1124-1320 | `attack_move` to the seat (-60, 41) | task attack; slot (-60, 41) | MOVE | the planner seam LIVE (a lattice plan pending), the circle rule reversing at 2.8 m/s, phase `blocked terrain` 1248-1320 | **the container stall: 6.5 s against the container_20 at (-20, 80), the 14 m hull turning round in the gap by the arena edge** (its own line, manoeuvre's: k-turn / circle-fit) |
| 1336-1449 | `attack_move` to (-96.5, -30.8) then `attack` Rust_Hunters_4 | task attack, pursuing | MOVE, then ENGAGE / PURSUE | the far quay, routed | drives south-west at 12 m/s, as his did from tick 1380 |

**Killed by REMOVAL (C43.3): the street hold.** `make engage-replay-trace ENGAGE_TAG=nohold ENGAGE_FLAGS=--traffic-off=hold`
(same tree, native ON, the match identical to his for 17 s and then only this crew's drive differs): **Guns_1 best 29.8 m, ARRIVED
on the far quay at tick 810 (12 s after his order), drive-away seconds 1 v 19, farthest north-east (-91.6, 55.3) v (-8.6, 95.4).**
(It then died at ~28 s in the five Hunters' line, alone: the crew obeyed; the squad was already dead or held.) The hold's own
read, from Traffic's tables in the trace: `{"group": "e:5", "passer": "e:6", "since": frame 511 (tick 478), "spot": [-29.7, 100.0],
"spots": [Guns_3, Guns_4, Guns_1]}`; the mover's steering point equals the spot from tick 478 until 1023 whenever the driver is
`route`. In code: `Traffic._begin_wait` deals a spot to every moving crew of the waiting squad; a crew behind the centre line gets
`_spot_behind(centre, ...)` (HOLD_BACK_M 8-43 m behind the MOUTH, HOLD_SIDE_M to the right), whatever its own distance to the mouth;
`hold_of` returns pace `approach` = 1.0 beyond HOLD_SLOW_M (16 m), so a far crew drives to the mouth at full speed for up to HOLD_CAP_S
(20 s) or until the passer is past. His War Rig stood 80 m from the mouth.

**The other hypotheses, each killed:** (a) a route via the lock: the navmesh (`tests/engage/path_probe.gd`, `make engage-paths`)
routes every leg from (-105, 46) to the far quay / a far-bank seat over the west bridge (63-67 m); the lock is 108 m to (-14, 84)
alone; and the crew's K1 goal was never across the canal to the east (the trace: its seats were (-85, 18), (-80, 21), (-77, 24),
(-60, 41), (-96, -31)). (b) the element re-aimed it: the element trace shows the slot standing at (-80.6, 20.6) -> (-77.0, 24.4)
through t 25-35 while the hull drove 90 m the other way; the task changed once (his attack, 807). (c) attack-shot's firing spot:
no `move`-to-spot order on this crew in 50 s (every K1 order was `attack_move` / `attack`); the `--attack-shot=off` arm
(ENGAGE_TAG=asoff) is a different match from 14 s (the rule changes the fight before the hold) and has no drive away either, so it
neither shows nor rules out, and the trace does the ruling out. (d) an unstick / k-turn chain after START_BLOCKED: `kturn_m` 0,
`unstick` false, `refusal` [] and the planner not live for the whole drive 700-1005; the planner goes live only at the container
stall (1124+). (e) the order latency (A2): below. **The combat hops (556-694, ENGAGE on a target across the canal) are real and
turned the hull north, but they are not the drive: with the hold off the same hops happen and the crew still arrives in 12 s.**
They remain a known issue (below).

**Why a rebuild from the census could not show it** (`tests/engage/turnaround_probe.gd`, `make engage-rebuild ENGAGE_FROM=420|540|600|630|660`,
laptop, 0e7664821): a task assigned fresh forms the elements fresh, so Traffic's verdict (made at 478 between two squads moving
through each other) never recurs, and every rebuild went for the bridge (from 660: on the deck by 790, 16 m from his click at 30 s).
The rebuild probe stays as a tool (any census tick, both sides' task rows replayed, the crew traced).

### A2: his attack at tick 806 "reached the crew at 1380": no queue

The order reached the ELEMENT the next tick (task row 807: `attack Rust_Hunters_4`; the element trace: task `attack` from t 27.0).
What the census' `order` column shows is the crew's K1 verb, which the element chooses: out of reach of the target (131 m, across the
canal) `ElementPlan._engage` and react_to_contact issue `attack_move` legs toward it (naming the target from 1063), and the K1 verb
becomes `attack` only when the element's pursuit (`_plan_pursuit`) or in-reach `attack` takes over (1372 in the replay, 1380 in his
census). Nothing held the order; the HUD's "carrying out" reads the named attack-move the same way (round 42's `_moving_round`).

### Known issues found (not built on)

- **ENGAGE across water (mine, R43.5 GRANT if the orchestrator confirms):** under attack-move the crew brain engages a team-seen
  contact across the canal when within range + 15 m: `_own_line_to` (the cover map) ignores water, and `_combat_move` answers direct
  hops (one of them reverse, 36 m) that swing a 14 m hull round and away. No shot results (effective range 36 m). Measured on his seed
  only (556-694); it did not cause the drive, but it costs 5 s and a 180 deg turn. A rule: no ENGAGE hop toward a contact the hull
  cannot reach without a crossing (SlotGround.leg_wet on the hop), or "water between: firing across" (the existing hold) applied to
  the choice, not only the hop. Symmetric for the CPU.
- **The container stall (manoeuvre's):** 1124-1320, the rig turning round beside the container_20 at (-20, 80) with the planner live
  and the circle rule reversing; 6.5 s `blocked terrain`. Same family as round 42's rust s2 t15.
- The vee/swarm flap on this element (t 17-23 and 36) re-seated the crew each time (the orchestrator's note); not the drive either.

### Requests to the orchestrator

- **Ruling (C43.3): the cause is in `game/ai/traffic.gd` (`_begin_wait`, `_spot_behind`), manoeuvre's path.** Proposed rule, symmetric
  (the CPU's squads take the same holds), behind a switch (`--traffic-on/off`): a crew of the waiting squad farther from the street's
  mouth than the spot grid reaches (HOLD_BACK_M's last row, 43 m, plus its hull) is not sent to the mouth: it is released from the hold
  (ORCA keeps it clear as always), or holds where it is (`spot = here`, the existing "nowhere to pull aside" branch) if its route runs
  through the street. A test: a two-squad head-on meeting with one crew of the waiting squad 80 m back; today it is dealt a spot at
  the mouth and drives there; with the rule it keeps its route. If granted to me I build it (A3) and file Bar A; if manoeuvre's, the
  trace and the replay recipe above are theirs (`make engage-replay-trace ENGAGE_TAG=<x> ENGAGE_FLAGS=...`, `--crew-trace=<name>`).

### Tools (all engage's)

- `tests/engage/turnaround_probe.gd` (`make engage-rebuild`): a census-places rebuild of a recorded match from any tick, both sides'
  task rows replayed at their ticks, one ENGAGE_TA row per change / sample for one crew, ENGAGE_TA_SUMMARY (drive-away, nearest, the
  farthest north-east, the bridge tick, the planner's report).
- `tests/engage/path_probe.gd` (`make engage-paths ENGAGE_LEGS="x,z>x,z;..."`): the navmesh's route and crossing per leg.
- `TankBrain.CREW_TRACE` (`--crew-trace=<name|all>`, default off, no behaviour): CREW_TRACE per think change / 15 ticks.
- `make engage-replay-trace ENGAGE_TAG=<arm> ENGAGE_FLAGS=<switches>`: native's replay of his match with the traces on, its recording
  under `build/engage/rec/<arm>/` for `tools/recording_arrivals.py` and `tests/replay/divergence.py`; `make engage-his` unpacks the gz.
- Merge note: `game/ai/tank_brain.gd` gains `CREW_TRACE` (static), `_crew_trace()` and one call after `_act` (3 hunks, trace only).

