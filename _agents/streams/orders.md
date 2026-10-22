# Stream: orders (squads look smart and under his control: no flicker, parked squads stay put, squads arrive whole)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 37** (C37.1, C37.4,
> C37.5) and in *Round 36*: R36.11, R36.24, R36.26 and the O2/O4 rulings. Then your round-36 brief
> `streams/archive/round36/orders.md` (its Status is the close-out) and `game_design.md` *Round 36: his answer on parked squads*,
> *Round 36: his answer on mixed squads, and the bar behind every movement change*. **You own:** `game/control/**`,
> `tests/test_control*.gd`, `tests/control/**`, `tests/orders_probe*.gd`, `mk/command.mk`; in `game/tactics/element_plan.gd` the
> deploy-step and halt-lay functions; `game/tactics/deploy_passers.gd`. **Grants (C37.5), one guarded seam each, merge note:**
> `ElementSituation.terrain_at` and the halt-shape choice (O1); the ADVANCE from a parked seat in brains' engagement code (O2);
> `cpu_commander.gd`'s screen / support_by_fire seat placement (O5).
> **Model:** FABLE (the lingering "looks dumb" problems). **Machine:** builder0 (C37.1); light runs on either builder.

## The lead's direction (verbatim in game_design.md)

**"the feel of the game needs to have the user perceive that the units are smart and under their control"**; he recalls a scathing
RTS review because the units seemed dumb. **"the general priority is to mitigate vehicle contention with one another."** Parked
squads: **"Stay put and shoot"** (he decides when it moves; if it ever moves to fight, it drives all the way back). Mixed squads:
every vehicle with its own squad, PROVIDED contention is not worse. Packing: keep 9 m between squads.

What he will notice: a squad he has just parked stops switching between two shapes (a crew driving to a point ~15 m off and back);
a squad he parked fights from where it stands; squads he sends together arrive with their own vehicles; CPU squads set up off the
streets other squads use.

## Where things stand

- **The flicker (R36.24, traced R36.26):** the halt shape flips herringbone <-> coil on `ElementSituation.terrain_at(center)` of the
  crews' centroid at a 45 m radius with no hysteresis; as crews move the centroid moves and the shape flips, re-seating the crews.
  Fix options: latch the shape per arrival, read terrain at the anchor (the click), or hysteresis. Size the flicker's base rate first.
- **away_m** (orders' metric) counts goal flips; it should be read against a fixed seat (R36.24).
- **Parked ADVANCE:** 16 of 55 twitchy squads (round 36's probe) were a parked crew advancing to fight (orders' "neither"
  ENGAGEMENT kind).
- **CPU seats (R36.11):** 9 of 11 jam:yielding-to-another-squad deaths were at CPU screen / support_by_fire seats placed on others' paths.
- Tooling on main: the herringbone lab (`make herringbone-lab`), the orders probe and its shots.

## Backlog (in order)

1. **O1 the flicker.** Base rate first (how many arrived squads flip shape, how often, on the probe's cells); then the fix behind a
   switch, a deterministic lab case (a squad straddling a terrain edge), a bar (deciding: flips per arrival; guards: all-in time,
   friendly contacts, far bank, `test_control_scale`'s 3-tick response). Symmetric: a pass ships ON.
2. **O2 parked squads stay put and shoot.** The parked crew fires from its seat; if a rule ever moves it, it returns all the way.
   Bar: advances from parked seats (deciding), kills/deaths of parked squads (guard: not worse beyond noise).
3. **O3 squads arrive whole.** Every vehicle with its own squad unless contention worsens: bar with contention (friendly contacts,
   crossings, all-in time) as the guard at no-worse-than-today, squads arriving short as the deciding line.
4. **O4 away_m against a fixed seat** (tooling; re-read round 36's numbers with it).
5. **O5 CPU seats off paths** (the grant): a seat on another element's route moves aside; bar from R36.11's deaths.
6. **O6 the cover seat call (C37.4)** once cover's `low_cover_seat` is on main: called once when laying a halt seat, behind its own
   switch; until then a stub.
7. **Stretch:** a click right at a bridge mouth seating a crew past the deck; `uncross_paths` on a queued screen.

## How to verify

Tests and lab cases first; `make quick-remote`; one full check per named hash; `make orders-probe-shots` LOOKED at for every cell you
change; series on fresh seeds; every number with commit, machine, workload, n. Smoke like a player: `make skirmish ARENA=locks`,
three squads to one point, then two more down the same street; park a squad and let the CPU come to it. Write in every bar "what he
would see".

## Don't touch

Manoeuvre's paths (movement.gd's drive / traffic blocks), rules' and cover's paths, brains' paths beyond your grants, `native/**`,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### REPORT (orders, round 37; updated 2026-10-21 ~19:00 PDT). Every number names its commit, machine, workload, n.
- **State of the branch:** main c76469184 merged (52c15e0e1). The series hash is c14ec0d80 = 52c15e0e1 + the probe's
  `parked_redeals`; **its full check is GREEN (builder0 native: exited 0, 3040 passed / 0 failed, 25 passed + 2 NOT JUDGED for perf on a busy box (load 22), sim-baseline 13 unmoved)**. 52c15e0e1's check was stopped at 15 min for it. The check
  before, 42a26a17c (builder0 native, 3022 passed / 0 failed), FAILED on the engine-log gate only: `test_control_parked_hold`
  overrode the runner's sealed `_teardown()`, and the lab<->case reference cycle leaked 14 objects at exit. Fixed (teardown()
  hook, cycle dropped; local run clean). Last green hash: **c14ec0d80**. The judged series (scratchpad `r37_series.sh`, side worktree
  `~/projects/godot-orders-o1` at c14ec0d80) runs on that green: O2, O3, O5, O1-latch no-fight + census, O1-latch fight. Verdicts
  go to `references/round37/orders/*-judged-builder0-c14ec0d80/verdict.txt`.
- **Parked re-deals (orchestrator, after R37.17's traces; reported in every verdict):** `parked_redeals` = crews parked
  2 s or more on their seat with no order, then sent more than 6 m off it (the squad re-dealing seats; he sees a parked tank pull
  out). It falls before the place window ends, so twitch_m never saw it. Laptop GDScript locks 5 route s3703 (n 1): main 4,
  anchor 6.
- **PRIORITY (the lead's playtest 2026-10-21, archipelago s44214): parked rocket trucks ignored his moves. CAUSE FOUND,
  fix candidate 716c61310 (not merged; orchestrator's call).** A squad of nothing but Gas Rocket Trucks: parked trucks set up
  by themselves (~3 s still), and round 33's battery seat ("a set-up crew keeps its place where it stands") seated them where
  they stood on every NEW move: an order to their own spot, done at once, so they never drove and never packed. Lab
  `test_control_artillery_move` (laptop GDScript): parked set-up trucks moved 0.0 m (1 and 2 trucks); `--battery-seat=off` 58.1 m.
  Fix `--battery-seat-task` (ON): held only while standing on the seat last sent to (6 m). Lab 58.1 / 56.1 m;
  `test_tactics_battery_seat` 7/0 (+1 case). Symmetric (CPU batteries too): needs a full check; sim-baseline may move.
- **O1 the flicker: the judged no-fight read FAILED as filed** (builder0 native f4365153f, seeds 3701-3712, census 3701-3706;
  `references/round37/orders/o1-judged-builder0-f4365153f/`). The deciding line passed (relays 298 -> 0, shape flips
  114 -> 0). Two guards failed: twitch in locks 5 route (3.9 -> 10.6 m), and CPU friendly contacts (1665 -> 1933, line
  1836.5). R37.17: it doesn't ship. Cause (traced): the anchor read changes which shape the deploy picks at halt (locks
  coil 60 -> 52, terminus 6 -> 0), so more long herringbones crowd their neighbours. New arm `--halt-terrain=latch`
  (ca251254a): read the centroid's terrain at arrival and keep that read while arrived (same first shape as main, no
  flicker; lab `test_control_halt_terrain`: centre 2 flips, anchor 0, latch 0). R37.17's traces are done (edec107e0, sent in player terms):
  latch == main at locks 5, and parade's excess contacts are moving drill crews in a longer fight. Latch bar re-filed
  (849fced87, recorded on main): fresh seeds 3761-3784, same guards.
- **O2 parked squads: BUILT OFF, final bar filed (052f30eea).** `--parked-hold=on` (tank_brain.gd seam `_parked_move`):
  a move of his parked crew's own that ends more than 4 m off its post becomes hold-and-face (RETREAT kept). Off its post
  with nothing to do, it drives all the way back (arrive 1.5 m). Deciding metric off_idle_s. Base (builder0 3e5944657,
  fight probe, 18 fights): 94.2 s a fight (sd 111.0, se 26.2). Judged read queued after the check.
- **O3 squads whole: BUILT OFF, bar recorded on main.** `--untangle=whole`. Judged read (3713-3724) queued after the check.
- **O4 away_m v a fixed seat: DONE (tooling).** `away_held_m` / `away_seat_m` (20005d611, 285 squads: away 820.2 m, held
  813.8 m, seat 2411.9 m).
- **O5 CPU seats: BUILT OFF, bar recorded on main (78c06ab1f).** `--seat-aside=on`. Sizing (builder0 baf3dbd8e, 18 fights): 542
  seat give-ways (499 screen), 21 deaths. **Judged: FAIL** (builder0 native c14ec0d80, seat-yield-census 1811-1822, 36 fights
  a side; `references/round37/orders/o5-judged-builder0-c14ec0d80/`): CPU screen give-ways 1277 -> 988 (-23 %, the bar asked
  <= 50 %); seats moved aside 5456; deaths in give-ways 49 -> 45 (noise); team deaths guards pass. In player terms: the CPU's
  screening tanks get in each other's way less (screen yielding to screen 742 -> 438) but just as often in the way of a
  support-by-fire seat (251 -> 255); the aside step does not see a support-by-fire route. Stays OFF; no retry filed.
- **O6 cover seat: SEAM DONE, OFF and unjudged this round** (agreed with the orchestrator; it fires once in 3 probe cells).
- **Stretch: both answered, no code.** (1) Bridge-mouth click: re-checked on this round's tree (laptop GDScript 9de8a7d4f,
  Crossing west deck, clicks 3 / 6 / 9 m short, 3 and 5 squads, 24 squads): crossed 0, goals across 0. Round 36's halt lay
  covers it (`references/round37/orders/stretch-bridge-mouth-r37/`). (2) `uncross_paths` on a queued screen: round 36's
  trace stands (a real swap, not path planning). It stays limited to plain moves; no new evidence a screen needs it.
- **Answered by the lead (game_design.md on main, relayed by the orchestrator):** a nearly dead parked crew PULLS BACK,
  then returns to its spot. That is O2's arm as built (RETREAT kept; the drive-back brings it home). He also kept the parked
  scouts' circling turn-in, so O2's drive-back is what returns them. No change.

### Bars (filed here; the orchestrator records them on main)
- **O1 HALT_TERRAIN=anchor (orders, C37.5; filed 2026-10-21 ~09:10 PDT before any arm number).** What he would see: a squad he
  has parked keeps one shape; no crew drives to a point ~15 m off and back while the squad sits. The fix: an ARRIVED element
  reads `ElementSituation.terrain_at` at its anchor (fixed), not its crews' centroid (`--halt-terrain=centre|anchor`; GDScript
  only, terrain_at has no native twin). **Base rate (sizing, seen; builder0 native, 20005d611, orders-probe 12 street cells x
  seeds 3621-3626, 285 placed squads):** 4 squads flip halt shape after the place window (18 flips, 50 reseats; locks 3 x 3,
  terminus 5 x 1), centroid terrain changes 38 (shape flips + lanes <-> dense re-spacings), anchor terrain changes 0. Lab:
  `test_control_halt_terrain` (locks, open spot 4 m off a lanes edge, the squad nudged across 6 times: centre 2 flips, anchor 0;
  laptop GDScript). **Judged probe:** `make native orders-probe`, arms `main:` v `anchor:--halt-terrain=anchor`, the 12 cells,
  FRESH seeds 3701-3712 (n 12 a cell), builder0, on a hash whose full check is green. **Counter:** base relays >= 10 (else
  "no workload") and the arms' rows differ somewhere. **Deciding:** `relays` (an update where the halt's shape or the terrain
  the element reads changed, after the place window, within one task) summed over all placed squads: arm <= 25 % of base, and
  shape flips arm <= 1. **Guards (each cell, medians as R36.6's):** all-in <= base x 1.2 + 3 s and no more never-in seeds;
  twitch worst <= base + 3 m; end foreign min >= base - 3 m; crossed (far bank) no higher; `test_control_scale`'s 3-tick
  response (in check). **CPU guard (the read is symmetric: CPU elements halt too):** `make native traffic-census`, its 3
  default cases x seeds 3701-3706 (18 CPU v CPU fights an arm), `TRAFFIC_FLAGS=--halt-terrain=anchor` v none: friendly
  contacts arm <= base x 1.1 + 5, stuck s arm <= base x 1.2 + 10, outcomes reported. **A pass ships ON** (default "anchor",
  `--halt-terrain=centre` keeps main's), sim-baseline maps that move attributed with the switch OFF.
  (Recorded on main 441d8951d by the orchestrator.)
- **O1 addendum (R37.9; filed 2026-10-21 before any judged O1 number): a SECOND deciding workload, the fight probe.**
  Sizing (seen; builder0 native light, 3e43c4a24, `--probe-fight=on --probe-budget=1500`, locks/crossing/terminus x 3
  squads x click x 3621-3626, 18 fights, 51 placed squads): 175 halt-shape flips, 446 re-lays, 27 squads re-laying.
  **Judged fight read:** arms `fight:--probe-fight=on,--probe-budget=1500` v `fightanchor:--probe-fight=on,--probe-budget=1500,
  --halt-terrain=anchor`, the same 9 cells, FRESH seeds 3731-3742 (36 fights an arm), builder0, on a green-checked hash
  that has the fight mode (>= 092cb34b7; f4365153f does not). **Deciding:** relays summed arm <= 25 % of base and shape
  flips arm <= 25 % of base. **Guards (fights are not deterministic across arms once seats differ: read as per-fight
  totals):** his kills a fight and his losses a fight each within base +/- 1.645 se (se from the base arm's per-fight sd,
  n 36), the CPU's losses likewise. The no-fight read (f4365153f, seeds 3701-3712, + the census) stands as filed. O1
  ships only when BOTH pass.
- **O1 RE-FILED for the latch arm (R37.17; filed 2026-10-21 ~17:30 PDT, before any latch number).** Anchor failed as filed
  (f4365153f) and does not ship. New arm `--halt-terrain=latch` (ca251254a): an element reads the centroid's terrain on
  the update it arrives (the same read main makes, so it picks the same first shape and spacing) and keeps that read while
  it stays arrived. A new task or leaving arrival takes a fresh read. What he would see: the same as main at the moment a
  squad stops, then no flicker while it sits. Traces (edec107e0, builder0 light 52c15e0e1): locks 5 route s3703 sq2 latch
  rows == main's (twitch 0); parade s3704 latch 238 contacts v main 136, with contacts at arrived elements flat
  (44 / 44 / 45). The excess there is moving drill crews in a longer fight. **The same bar as filed, arm `latch:`, on
  FRESH seeds, on a green-checked hash containing ca251254a (52c15e0e1 or later):**
  (a) no-fight probe, arms `main:` v `latch:--halt-terrain=latch`, the 12 cells, seeds 3761-3772; counter, deciding
  (relays arm <= 25 % of base, shape flips arm <= 1) and probe guards exactly as the O1 bar above.
  (b) CPU guard, traffic-census 3 cases x seeds 3761-3766, `TRAFFIC_FLAGS=--halt-terrain=latch` v none: friendly contacts
  <= base x 1.1 + 5, stuck s <= base x 1.2 + 10. **I am NOT re-arguing the contacts line.** Reported beside it, not judged:
  contacts touching an arrived element, and contacts per fight-second.
  (c) fight read, arms `fight:` v `fightlatch:--probe-fight=on,--probe-budget=1500,--halt-terrain=latch`, the 9 cells,
  seeds 3773-3784 (36 fights an arm); deciding and guards as the O1 addendum. This replaces the anchor fight read (3731-3742),
  which is not run.
  Ships ON (default "latch") only when (a), (b) and (c) all pass.
- **GROUP-LAY=COLUMN (R37.29; filed 2026-10-22 ~00:30 PDT, before any judged number; code badfe25c0 + probe 6bff818f3, OFF).**
  What he would see: select all, click one point, and his squads line up one behind the other along the way they came, as wide
  as the street there, the nearest squad in front, each with its own vehicles; on open ground they spread as today. Design:
  `references/round37/orders/group-click-column-note.md` (approved). Lab `test_control_group_click` (his Terminus click:
  today spread 128.8 m with 2 of 4 anchors outside the corridor; column all inside, nearest squad in front, farthest at the back).
  **Workload:** orders probe, arms `main:` v `column:--group-lay=column`, FRESH seeds 3801-3812 (n 12 a cell), builder0, on a
  green-checked hash, cells: the 12 street cells (locks / crossing / terminus x 3 / 5 squads x click / route) PLUS his click as
  its own cells, `terminus --probe-click=-29.3,85.8` x 3 / 5 squads x click (laptop dev read s3790, 5 squads: anchors outside
  3 -> 0, metres outside 189 -> 27, re-dealt 4 -> 0). (The probe's own clicks often read as open ground, where the column does
  not engage and the rows must be identical.)
  **Counter:** `columns_laid` > 0 and the his-click rows differ.
  **Deciding (both, summed over all cells):** (1) squads' places outside the click's corridor (`anchor_outside`), arm <= 25 %
  of base; (2) "drove through other streets": driven metres outside the click's corridor (`route_out_m`), arm <= 50 % of base;
  and crews re-dealt across squads (`redealt`) arm 0.
  **Guards (R36.6's, per cell, medians):** all-in <= base x 1.2 + 3 s, no more never-in, twitch worst <= base + 3 m, end
  foreign min >= base - 3 m, crossed no higher; friendly contacts (probe) <= base x 1.1 + 5. **No-change cell:** yard_open
  (3 / 5 squads x click, the same seeds): rows identical to main's.
  **Shots, for him (R37.29 (2)):** paired top-down shots of his click (terminus, -29.3, 85.8, 5 squads), main v column, at the
  click, at arrival and 5 s after, LOOKED at; the recording carries no camera pose, so top-down over the click. He judges "I kept
  control".
  A pass ships ON (his control only: the CPU issues no multi-squad click).
- **O2 ON TOP OF LATCH (R37.29's thought; filed 2026-10-21 ~23:00 PDT, before any number; runs ONLY if O1-latch passes).**
  Why: O2's judged read (c14ec0d80) passed, but its reported parked re-deals rose 50 -> 105 alongside halt re-lays 187 -> 352
  (O1's flicker). If crews now sit on seats the squad keeps re-laying, the latch should take the extra re-deals away.
  **Read:** the fight probe, arms `latch:--probe-fight=on,--probe-budget=1500,--halt-terrain=latch` v
  `latchparked:--probe-fight=on,--probe-budget=1500,--halt-terrain=latch,--parked-hold=on`, the 9 cells (locks / crossing /
  terminus x 3 squads x click), FRESH seeds 3785-3796 (36 fights an arm), builder0, on a green-checked hash.
  **Deciding: O2's line**: off_idle_s a fight, arm <= 50 % of base, drop > 1.645 se (unpaired); counter parked_returns > 0.
  **Guards:** his kills, his losses and the CPU's losses a fight, each within base +/- 1.645 se (O2's). **Reported, judged by
  the orchestrator, not by a line:** parked re-deals arm v latch alone (and v O2's 105 / base 50), halt re-lays, reseats.
  A pass + re-deals no higher than latch alone's beyond noise -> O2 + latch ship together (both ON for every side's halts;
  parked-hold for his crews only).
- **O2 PARKED_HOLD, FINAL BAR (orders, R37.13; filed 2026-10-21 before any judged number; supersedes the 8dc98b5f4
  text; code ef6b17ea9 + probe f4437d26a, OFF).** What he would see: a squad he parked stays where he put it and shoots
  from there; a crew that is pushed, drifts or pulls back drives all the way back onto its spot. The change
  (tank_brain.gd `_order_move`, his idle crews at their post only): a move of its own option ending > 4 m from its post
  is refused (it holds and faces the threat), RETREAT kept (his question is open); a crew > 3 m off its post with nothing
  else to do drives back onto it (1.5 m). **Sizing (seen; builder0 native light, 3e5944657 = f4437d26a + evidence only, the fight probe, locks /
  crossing / terminus x 3 squads x click x 3621-3626, 18 fights):** `off_idle_s` (an idle crew's seconds > 6 m off its
  station, the seat his order left it on, whatever moved it) 1696.4 s, 94.2 a fight (sd 111.0, se 26.2); by what was
  happening: face_drift 956.2 (56 %, M6's), still 579.4 (34 %), giveway 79.9 (M5's: yielding now or within 3 s),
  brain 81.2 (moving under its own move_to). **Judged probe:** arms `fight:--probe-fight=on,--probe-budget=1500` v
  `parked:` the same + `--parked-hold=on`, the same 9 cells, FRESH seeds 3743-3754 (36 fights an arm), builder0, on a
  green-checked hash. **Counter:** `parked_returns` > 0 on the arm. **Deciding:** `off_idle_s` a fight, arm <= 50 % of base
  AND base - arm > 1.645 x the unpaired se of the difference (fights diverge between arms). **Reported:** the split
  (giveway apart for M5, face_drift apart for M6), brain-move leaves (`left_by` without +drift), RETREAT leaves.
  **Guards (per-fight totals):** his kills, his losses, the CPU's losses a fight each within base +/- 1.645 se (se from
  the base arm's per-fight sd, n 36). **A pass ships ON** (`--parked-hold=off` keeps today's), his crews only.
- **O5 SEAT_ASIDE (orders, R37.5; filed 2026-10-21 before any builder0 arm number; code 8f5a8b08f, OFF).** What he would
  see: CPU squads set up their screens off the streets other squads use, so CPU crews stop stepping aside (and dying) for
  their own side's traffic. The change (element_commander.gd): a CPU screen point within 10 m of another living element's
  way (its centre to its task destination, straight) steps across its own approach, 5 m steps alternating sides, up to
  4, to the first clear point. **Sizing (seen; builder0 native light, baf3dbd8e, `make seat-yield-census`, locks / gorge /
  terminus x 1801-1806, 18 CPU v CPU fights):** 542 give-ways by crews holding a CPU seat to another element's crew (499
  screen, 43 hold, 0 support_by_fire), 21 deaths in them (19 screen), 705 deaths in all. Laptop dev read (locks s1801,
  one fight): 15 -> 2. **Judged:** `make native seat-yield-census`, arms none v `SY_FLAGS=--seat-aside=on`, the same 3
  maps x FRESH seeds 1811-1822 (36 fights an arm), builder0, on a green-checked hash. **Counter:** `seats_aside` > 0.
  **Deciding:** screen give-ways (episodes) summed, arm <= 50 % of base. **Reported:** deaths in seat give-ways (base ~42
  expected: too few to decide; must not rise beyond Poisson noise, arm <= base + 1.645 sqrt(base)).
  **Guards (per-fight totals, both sides are CPU):** deaths a fight per team each within base +/- 1.645 se (se from the
  base arm's per-fight sd, n 36). **A pass ships ON** (symmetric: every CPU commander), `--seat-aside=off` keeps today's.
- **O3 UNTANGLE_WHOLE (orders, C37.5; filed 2026-10-21 ~10:10 PDT before any O3 number; code 092cb34b7, OFF).** What he
  would see: squads he sends together arrive each with its own vehicles (no squad one vehicle short, no stranger in it),
  and they do not bump each other more than today. The change: where today's untangle re-deals vehicles between squads
  whose drives cross, the crossing squads swap whole PLACES (fewest crossing drive pairs, then least driving); each keeps
  its element. **Base rate (seen):** 25 of 287 squads had a crew re-dealt (builder0 native, 55c973cd4, round 36's 12 cells x
  3621-3626). **Judged probe:** `make native orders-probe`, arms `main:` v `whole:--untangle=whole`, the 12 cells, FRESH
  seeds 3713-3724 (n 12 a cell), builder0, on a hash whose full check is green. **Counter:** `swapped_whole` > 0 on the
  whole arm and the arms' rows differ. **Deciding:** squads arriving short (`redealt` > 0) summed: arm 0 and base >= 10
  (else "no workload"). **Guards (his priority, contention, at no-worse-than-today):** friendly contacts summed over all
  runs (`friend_contacts`, physics hull touches between his vehicles) arm <= base x 1.1 + 5, and the same for
  `friend_contacts_foreign` (different squads); per cell medians: all-in <= base x 1.2 + 3 s and no more never-in seeds,
  twitch worst <= base + 3 m, end foreign min >= base - 3 m, crossed (far bank) no higher; `whole_still_crossed` reported.
  `test_control_untangle*` and `test_control_scale` in check. **A pass ships ON** (default whole, `--untangle=deal` keeps
  today's); the player's path only (CPU elements are not untangled), so no CPU guard. If contacts fail, re-dealing stays
  (his answer).

### Plan (worker, 2026-10-21; start: main 9d325e291, green by the launch check named in HANDOFF)
1. O1: probe columns first (per squad after arrival: halt-shape flips, terrain flips of the crews' centroid, reseats),
   base rate on builder0 (native, light lane) over the 12 street cells x seeds 3621-3626 (already seen); then the fix.
   **Choice: read the terrain at the element's fixed ANCHOR once arrived** (not the moving centroid). Stateless (no new
   Element/Movement field, no native twin needed: terrain_at has none), and in player terms the shape belongs to the spot
   he parked it on. Latch and hysteresis kept as fallbacks if the anchor read still flips. Switch `--halt-terrain=centre`
   = main's rule. Bar filed before any arm number; fresh seeds for the judged read.
2. O2 parked ADVANCE (brains' engagement grant), 3. O3 squads whole, 4. O4 away_m v a fixed seat (tooling; may land with
   O1's columns since both are probe reads), 5. O5 CPU seats off paths, 6. O6 cover seat stub, 7. stretch.
