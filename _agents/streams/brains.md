# Stream: brains (the squad forms up on the way: the fast crew slows, the anchor paces to the slowest seat)

> Read `_agents/orchestration.md` (the worker contract), `_agents/game_design.md` *Round 23 direction, first item*
> (his words and the orchestrator's reading) and *Round 23 direction: the launch*, `_agents/doctrine.md` *A plain move
> travels AS a formation* (round 12: the anchor, the lag rule, the two reverted pacing attempts) and *Form up on the
> move* (round 20 M1), `_agents/workstreams.md` *Round 23* (C23.1, C23.2), and your round-22 final report
> (`streams/archive/round22/brains.md` Status: B1's stage table and known issues; B3's verdict). You own `game/ai/**`
> EXCEPT what native takes this round (C23.1: `game/ai/avoidance.gd`, `steering.gd`, `cover_map.gd`,
> `combat_motion.gd`, `brain_switches.gd`, `game/ai/native/**`; and `movement.gd`'s pure-geometry seams, see C23.1),
> `game/tactics/**`, `tests/ai_scenarios/**`, `tests/tactics/**`, `tests/nav/**`, `tests/test_ai*.gd`,
> `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`, `mk/ai.mk`, `mk/nav.mk`, `mk/tactics.mk`,
> `doctrines/doctrine_*.json`, the baseline lines you declare.

## The lead's direction (2026-10-08, ~00:30 PDT his clock, playing round 22's main)

> *"units getting into formation is getting better, but there seems to be an obvious optimization we can do - when I
> had tanks in line abreast and had them move somewhere, they never got into formation until the very end - because
> the lead vehicle was already closed to the target point at the start, the other vehicles never caught up to it until
> it stopped. It seems that we could more easily get info formations if some vehicles slowed down to et back
> information formation with the rest of the squad"*

Standing: a chase is not a parade (round 21's P2: pursuits at road speed, keep it); a direct order of his still wins
(lesson 264); *"Yes make the CPU smarter, this would apply to all units… our friendly players are just as smart"*:
whatever you build paces the CPU's squads too (symmetric, C22.6 carried).

## Where things stand (read at `68b97663`, main-checked; the orchestrator's reading, VERIFY it first)

**The mechanism as built (round 12 + round 20 M1), and why his line never closed:**

- **In an element transit no crew's speed is ever limited.** `game/tactics/element.gd:342-366`: `FormUp.paces`
  (co-arrival, `form_up.gd:66-78`) is computed at :348, then forced to 1.0 for a pursuit (:349–353, keep) AND for
  every transit (:354–365, *"the ANCHOR is the pace"*). The brain's transit branch hard-codes it again:
  `game/ai/tank_brain.gd:2184` `_move_to(goal, false, 1.0, TRANSIT_ARRIVE_M)` discards `o["speed"]` (the non-transit
  path at :2190 uses it). `Movement._keep_station` (`movement.gd:994-997`, `:1156-1175`) ignores `speed_factor` too
  when it engages (goal sliding ≥ 0.5 m/s, within 14 m, avoidance pace ≥ 0.99).
- **The only pacing that exists is on the anchor, and only for crews BEHIND:** `Element._transit_pace`
  (`element.gd:688-701`) takes the worst `(station − position)·heading` over the crews and slows the anchor by
  `1 − (worst − TRANSIT_LAG_SLACK_M 8) / TRANSIT_LAG_FALLOFF_M 30`, floor `TRANSIT_MIN_PACE 0.35`; it never slows a
  crew that is AHEAD of its seat. A crew whose station is > `TRANSIT_WAIT_M` 3 m behind it gets `transit_wait` and
  STOPS (`tank_brain.gd:842-846`, `:2175-2178`): stop-go, not a pace. Constants `element_plan.gd:403-432`
  (`TRANSIT_CRUISE 0.85` of the slowest member's top speed, `TRANSIT_HANDOFF_M 12`, `TRANSIT_MIN_M 25`).
  `ElementPlan.transit_speed(cruise, pace, remaining)` at :423 is documented as *the one place to change* for the
  next attempt at shaping arrival.
- **Stations:** `ElementPlan.build` move branch (`element_plan.gd:339-352`): `stations_along` (:478–504) lays slot i at
  `route_pose(route, s − offset.y)` pushed `offset.x` across the tangent; `transit_starts` (:538–556) records each
  crew's own (lateral, along) place in the route frame and `converge_m` = max(30, shape depth, 1.5 × the furthest
  fall-back + 5), capped at the hand-off; `converge` (:562–584) smoothsteps from the carried place to the seat by
  `s − start_s`. What reaches the brain: `element_feed.gd:115-130` (`context["pace"]`, `station`, `station_velocity`);
  `tank_brain.gd:809-867` `_order_context` (the goal led by the anchor's velocity, :851; speed = min(order,
  element.pace) at :864–867).
- **Two attempts recorded as reverted** (`element.gd:355-363`, `doctrine.md` *A plain move travels AS a formation*):
  co-arrival pacing after the hand-off slowed the FRONT crew into a crate (default arena forward seed 1: stopped 20.8 s
  v 10.1); one uniform pace 0.6 after the hand-off: forward median 16.6 → 22.2 s. And a brake of the anchor into the
  click (`element_plan.gd:415-420`): worse everywhere. Read them before designing; neither is what he asked for.
- **His case, read against this:** a line abreast ordered to a point off the line's end must rotate 90° into a line
  across the new heading; the crew at the near end starts ON its seat and drives at 1.0 (never limited); the anchor's
  cruise is 0.85 × the slowest top speed, so a same-type squad closes the shape at a 15 % speed margin only, and the
  lag rule starts 8 m behind. Whether the anchor's lag rule even engaged in his match is the first thing to MEASURE:
  reproduce it before changing anything (lesson 274).
- **Instruments:** `tests/test_tactics_form_on_move.gd` (five crews abreast 8 m apart on the yard, seed 3, 100 m; both
  arms via `ElementPlan.CONVERGE_ENABLED`; `away_m`, `off_line_m` in the first 5 s, `arrived_s`; a `MEASURE` line) is
  the template for his scenario. `make squad-arrive-series` (`mk/tactics.mk:211-234`; `ARRIVE_ARM_FLAG`,
  `ARRIVE_DRILLS=off` is the plain move where the transit lives; `SETTLE_PROBE` lines: `ordered_s`, `arrived_s`,
  `in_slot_s`, `stopped_s`, worst slot distance, closest pair; `tools/tactics/squad_arrive_table.py`): no baseline
  file, the numbers live in Status (round 20 M1 builder0 `efc3682d`: plain move 150 m 100/100 both arms, median 21.1 v
  21.75 s; round 22: 50/50 both arms). `make element-digest` (tactics.mk:190–208) hashes every element decision,
  stations and anchor included: the equal-answer proof for an OFF arm. `make converge-probe` (orders' two-squad probe:
  worst away / off-line in 5 s). `make ai-ab-match` prices CPU only (it fails unless the hashes are equal; a pacing
  change is behavioural: use it only to price extra `Movement.eta` calls, with the new switch OFF).
- **The thirteen lines:** the match runner forms no elements, so an element-transit change leaves all thirteen and
  determinism UNMOVED (B1 and P2 said so and were right); `tank_brain.gd:2184` is behind `context["transit"]`, which
  only an element sets. Still a DECLARED change (C21.2 / C22.2 carried): one commit, merged alone, scenario + paired
  series, the arrive series part of green.
- **B1's grace** (`game/tactics/unanswered_fire.gd`): `GRACE_TICKS` 1.5 s (:32), a crew on post hit with no seen enemy
  inside its range closes (leash 20 m) / covers (25 m) / falls back; three Lancers take 440 in ~3 s so the crew dies
  inside the grace (round 22 known issue, stage table at brains.md:198–204: one Lancer → cover 4/4 alive, two →
  cover, 44 lost, three → dies). *"A shorter grace would make one stray hit move a crew; left as is."*
- **The held crew's readout:** `plan["why"]` → `Element.reason` (`element.gd:874`) is element-level; a crew he holds
  with H leaves its element (orders' direct path) and nothing reports its fire. Orders builds the readout this round;
  you provide the per-crew read (C23.2, below).

## Backlog (in order)

**B0. Reproduce his case, measure, publish the number.** A scenario in `tests/tactics/` from `test_tactics_form_on_move`:
five same-type crews (Law tanks; then a mixed squad) in LINE abreast across x, ordered to a point ~150 m along the
line's own axis (so one crew starts nearest and on its seat, the rest must rotate into a line across the heading);
also the yard case 100 m forward. Measure per tick: the shape's formation error (RMS of crews' distance to their
SHAPE stations, not the converging ones), the first metre of the anchor's route at which every crew is within 3 m of
its seat (`formed_m`), the lead crew's speed over the first 10 s, whether `_transit_pace` ever dropped below 1 and
when, `arrived_s`. Print a `MEASURE` line. The number before anything changes, builder0, 3 seeds, in Status. If the
shape forms early already and his case was something else (several squads, orders' places, a terrain route), say so
with the trace, message the orchestrator, and keep going on the design below only where the measurement supports it.

**B1. The squad paces itself on the way (his item; DECLARED, merged ALONE, CP1).** Design (decide the details like a
good engineer and write the reason):
- A crew AHEAD of its seat along the heading slows to a pace that lets the shape close over the first leg (a pace < 1,
  never a stop unless it is far past its seat; `transit_wait`'s stop stays for the far case only). A crew behind
  drives at 1.0. The pace is per crew, from the element (`paces` in `element.gd:342-366`: compute it in transit
  instead of forcing 1.0), carried through `_order_context` and HONOURED by `tank_brain.gd:2184` and by
  `Movement._keep_station` (so the PID does not override it).
- The anchor paces to the slowest-to-seat crew: generalise `_transit_pace` from "worst behind along the heading" to
  the crew whose ETA to its seat (route-frame, `Movement.eta` or the straight distance at cruise) is longest, so the
  shape is formed by `converge_m` (or by a fraction of the route, your call) instead of at the hand-off.
- Keep: the pursuit override at `element.gd:349-353` (a chase is not a parade), the hand-off, the front rank on the
  click, the ahead start. Do NOT revive the two reverted attempts as they were (co-arrival after the hand-off; a
  uniform pace): the first slowed the front crew into a crate, the second cost 5.6 s on every forward move.
- A switch (`ElementPlan.PACE_ENABLED`, `--pace=off`) for the A/B and the series; OFF arm must be `element-digest`-
  identical to main.
- Acceptance: B0's scenario asserts `formed_m` within the first third of the route (or a number you justify) in the
  ON arm and NOT in the OFF arm; `arrived_s` no more than 1 s slower than OFF (the slowest crew already sets the
  pace); `make squad-arrive-series ARRIVE_DRILLS=off ARRIVE_ARM_FLAG=pace` on the five maps × 4 seeds × both arms:
  arrived k of n equal, `in_slot_s` earlier, `stopped_s` not later than OFF + 1 s median, no re-seat/swap increase;
  `converge-probe` worst away not worse; `make ai-ab-match AB_FLAGS="--green-elements --rust-elements"` with the
  switch as the lever: the CPU cost of the new ETAs (state it; if > 2 % of the controller band, cache per
  `ETA_REFRESH_TICKS`). Thirteen lines + determinism UNMOVED (pre-register; say why: no elements in the runner).
  Scenario from his case + the paired series = the declaration. Then CP1: tell the orchestrator "GREEN, merge here:
  <sha>" the moment it is green; native merges main after it.
- Playtest it like him: `make skirmish ARENA=yard` (or the garage path), pick a squad, L for line, order it along its
  own axis 150 m: the line swings into shape on the way, nobody stops dead, the squad arrives about when it did
  before. Record it (`--record`), look at the trace.

**B2. The per-crew "fire I cannot answer" read (C23.2, for orders' readout).** A static query, name agreed in
`workstreams.md` C23.2: `UnansweredFire.crew_reason(game_match: Match, unit_name: String) -> String`, returning
`WHY_HELD`'s text (the same constant) when the crew is being hit by something it cannot return (the B1 test:
`IncomingFire` says hit, no seen enemy inside its effective range, for at least the grace), "" otherwise; it must work
for a crew OUTSIDE any element (his direct hold) and cost nothing when not asked (orders calls it for the selected
crew only). A pure test in `tests/test_ai*.gd`. Small; do it right after B1's declaration goes to the orchestrator
so orders is unblocked early (message the orchestrator when it is on your branch; it merges as part of CP1 if ready,
else as its own equal-answer merge).

**B3. Under three guns, act inside the grace (candidate 5's first half; DECLARED, alone).** When the incoming damage
rate over the last N ticks would kill the crew before `GRACE_TICKS` end (e.g. hits ≥ 2 shooters or damage ≥ 25 % of
hp inside the grace), decide at once; one stray hit still waits. The stage table from round 22's B1 (one / two /
three Lancers, builder0, 4 runs each) re-run: three Lancers → cover or fall-back and alive at least sometimes; one
Lancer unchanged. The paired series (hold stage, parade, foundry, 8 then 24 seeds) as for B1: points and alive both
reported; if it costs points like B1 did (−5.83 se 1.90), say so and let the orchestrator decide (recorded, reversible).

**Stretch (a).** Round 20 M1's stray (yard wedge 100 m forward: an IFV backs round once, away 1.4 → 3.2 m): the
brain's aim point kept outside a wheeled hull's turning circle. **(b)** The in-line seat swap (two crews one behind
the other swap seats under "travel" seating; orders' known issue 3): a tie-break that keeps a column's order. **(c)**
`doctrine.md` *A plain move travels AS a formation* and *Form up on the move* updated with B1's rule (part of B1's
merge, not a stretch: do it).

## How to verify

- `make remote T=check` green on every commit (builder0; read `>> remote: make check exited <N>` and `N passed, M
  failed`, never a pipe). 23 targets ALL JUDGED; thirteen lines + determinism UNMOVED unless declared.
- The arrive series is part of green for a movement change (lesson 261): five maps × 4 seeds × both arms, builder0,
  tabled with commit and machine. `make element-digest` identical on the OFF arm.
- His scenario's `MEASURE` lines before/after, builder0, 3 seeds; one recording looked at.
- Every number: commit, machine, workload, sample size (C16.3). A `.uid` for every new test committed with it (lesson 273).

## Don't touch

`game/ai/avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `brain_switches.gd`, `game/ai/native/**`,
`native/**`, `mk/native.mk` (native; and in `movement.gd` the pure-geometry functions `_chord_compute`, `_arc_hit`,
`_outline_ok`, `_avoid`'s call into Avoidance: native's seams, C23.1; your hunks there are `speed_factor`,
`_keep_station` and the station PID) · `game/control/**`, `game/ui/**` (orders) · `game/garage/**`, `game/units/**`
(army, resting) · `game/match/**`, `game/tank/**`, `game/modes/**` (nobody: a request) · `tests/baselines/**` except
lines you declare · `mk/core.mk`.

## Waiting on the lead

- Nothing blocks you. He is asleep (2026-10-07 night); no gate tonight; decide, record the reason in Status, keep going.

## Status

_Updated 2026-10-08 ~00:15 PDT (round 23, brains worker). Working on B1._

### Plan (in order)

1. **B0** his case as a stage (`tests/tactics/pace_stage.gd`, shared by `pace_probe.gd` and `tests/test_tactics_pace.gd`;
   `make pace-series` / `make pace-trace`, `tools/tactics/pace_table.py`): reproduce, trace, publish the number. **Done
   (below): reproduced at seed 1.**
2. **B1** the pacing rules (`ElementPlan.form_pace`, `crew_paces`, `PACE_ENABLED` / `--pace=off`), the brain and the
   station PID honouring them; the acceptance test; the pace series (5 cases x 3 seeds x both arms); the arrive series
   (`ARRIVE_ARM_FLAG=pace ARRIVE_DRILLS=off`); `element-digest` OFF = main; `ai-ab-match` for the cost; then CP1.
3. **B2** `UnansweredFire.crew_reason` (right after B1's declaration goes out).
4. **B3** the grace under three guns.
5. Stretch (c) doctrine.md with B1 (part of B1's merge); (a), (b) if time.

### Baseline

Main `46764993` (the launch; `main-checked` `68b97663`). No local Godot before 00:30 (the orchestrator's laptop
measurement): everything below ran on builder0 through `make remote`.

### B0 — his case, reproduced (builder0, uncommitted over `46764993`, `make pace-trace PACE_ARM=off PACE_SEED=1`)

The stage: five Law tanks in a LINE whose own axis points at the click (down x = 0 from z = +64 to +32 on the parade
ground's open middle, hulls facing across the line as a line abreast does, 1.5 m / 6 deg jitter per seed), a plain
move to z = -100 (150 m), formation `line`. Every tick against the SHAPE's own stations (`ElementPlan.stations_along`:
NOT `Element.shape_stations`, which is the converged set).

**Seed 1, OFF (= main):** route 150 m; `formed_m` -1 (never all five within 3 m of their seats while in transit; the
closest is 15.5 s of a 17.6 s transit, errors 2/7/1/2/5 m); RMS error 14.7 m over the transit, 19.3 m in the first 10
s; the lead crew (the one nearest the click) at 0.48 of its top speed over the first 10 s with an element pace of 1.0
(never limited); the anchor's lag rule drops to its floor 0.35 at 0.8 s and holds it until 5.5 s; arrived 17.9 s,
in slot 19.1 s, stopped 19.5 s. **The trace, read:** the two crews BEHIND the anchor start facing across the line,
pivot 90 degrees for ~3 s (0.3-2.5 m/s) and fall 20-30 m behind their stations -> the lag rule puts the anchor at 0.35
(3.6 m/s) -> the lead crew reaches its (converging) station, is overtaken by it, and STOPS (0.0 m/s at 5.5 s: the
brain's `transit_wait`), the next crew too (0.0 m/s at 6.0 s: the station PID's brake) -> from 6 s the laggards are
within 8 m and the anchor runs back up to cruise (10.2 m/s = 0.85 x 12) -> the rearmost crew, at its top speed 12,
closes its last 8 m at the 15 % margin: 7-8 m behind from 11 s to 15 s. That is his sentence: the shape is there only
when the anchor stops. The brief's reading verified: the lag rule DID engage (hard, at once), the lead crew was never
limited (pace 1.0) and then stood still, and the shape closed at 15 % speed margin.

(Scenario note: the suite (real-time physics, hundreds of process frames a tick) and the probe (`--fixed-fps 30`, one
frame a tick, nearer the game's two) simulate the same seed differently: deterministic each, not across. Arms are
compared within one mode; the series is the probe's.)

**B0 is committed as `b60054e0`** (the orchestrator's ask: the measurement stands on its own).

### B1 — the squad paces itself on the way (DECLARED; the commit after B0)

**The rule** (doctrine.md *The squad paces itself on the way* has the full text): (1) the anchor paces to the
slowest-to-seat crew (`ElementPlan.form_pace`: the pace at which every crew, at the cruise share of its top speed,
reaches its grounded SHAPE seat within the next `span` = max(converge_m, 45) m of anchor travel; min'd with the lag
rule); (2) a crew ahead of its seat slows, never stops (`ElementPlan.crew_paces`: `(u/v)(1 - ahead/span)`, floor 0.25,
eased in over 3 m, 0 only beyond `span`); honoured by the brain's transit move (`paced`) and the station PID's cap, and
a paced crew never aims behind itself; (3) the give-way (`Movement`, paced moves only: 0.75 s of ORCA shaving -> 0.5
pace for 1 s). `PACE_ENABLED` / `--pace=off`; `--pace-span=<M>` the tuning arm.

**Decisions (recorded, reversible):** span floor 45 m, not converge_m's 30 (30: his line formed at 117 m for +0.6 s,
the wedge +1.3 s; 45: -0.2 s and +0.4 s); the ahead pace eased in over the 3 m slack rather than a cliff (the cliff
formed his line at 86 / 78 m on two seeds but pulsed the lead crew between 5 and 10 m/s every 2 s); the formed bar
kept at 3 m (it sits on the PID's 1.5-2 m standing offset, so it reads late; the RMS is the robust number); the
forming gain is the series' number, not one suite seed (the suite's mode dresses both arms alike on seed 1).

**Measured** (`make pace-series`, builder0, uncommitted tip over `b60054e0`, 3 seeds, probe mode; ON = the declared
arm, OFF = main's transit): his case RMS 13.4 v 15.0 m (per seed -0.7, -1.4, -2.8), first 10 s 17.1 v 19.4, the lead
crew's pace 0.69 (paced) v 1.00, nobody stood in either arm, arrived 17.2 v 17.9 s median (per seed -0.7, -0.6,
+0.5); formed-within-3 m 2/3 both arms (122 v 121 m). The wedge along its axis: RMS 15.4 v 16.6, arrived 16.3 v 15.5
(+0.8). The mixed line: RMS 12.5 v 11.7 (+0.8, worse), arrived 18.6 v 17.8, stood 0 v 1 run. The yard (across, 100 m):
the law line RMS 14.3 v 14.1, arrived 17.2 v 19.2, stood 0 v 2 runs; round 20's wedge unchanged (14.4 v 14.1, 16.0 v
16.0, 3 v 3). **Plainly: on his case the shape is tighter by a tenth and nobody stands; it is not formed by the first
third, and the mixed line pays 0.8 m / 0.8 s.** The arrive series decides (below).

**Commits:** B1 `59e52adb` (one commit, DECLARED), B2 `7d5b9257` on top of it (C23.2; the check runs on the tip).

### B2 — `UnansweredFire.crew_reason(game_match, unit_name)` (C23.2; `7d5b9257`)

Static, read-only; WHY_HELD while the named crew has been hit (within QUIET_TICKS) with no seen enemy inside its
effective range for at least GRACE_TICKS, by B1's own test (`ElementSituation.build` for the one crew +
`answerable`), in or out of an element; "" otherwise; the clock for a crew outside an element is a static map of
crews asked about (the element's `ducks` clock when it has one), cleared when the fire stops. Orders: call it for the
selected crew(s) under a direct hold, each frame or each think; the first WHY_HELD comes 1.5 s after the first ask
that finds the crew under unanswered fire (or at once if its element already noticed). Test
`tests/test_ai_crew_reason.gd` (three cases, DuckStage's geometry).
