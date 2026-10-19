> **ARCHIVED (round 34, closed 2026-10-19).** The round-34 brief as the stream left it (its Status is the record). Round 35 briefs are in `streams/`.

# Stream: brains (a scout stands and trades when it can win and leaves when it can't; the flicker's seam; B11b once CP-F lands)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/doctrine.md`,
> `_agents/workstreams.md` **Round 34** (C34.4, C34.5, C34.9; R33.31 and R33.24 in *Round 33*), `_agents/game_design.md`
> (C33.9, his scout report, verbatim), `_agents/roadmap.md` *Round 34 candidates*, and your round-33 brief
> `streams/archive/round33/brains.md` (*ROUND 33 CLOSE*: what round 34 should carry). Evidence:
> `streams/references/round33/brains/`.
> **You own:** `game/ai/**` EXCEPT traffic's, manoeuvre's, native's and planner's carve-outs (*Round 33* ownership),
> `game/tactics/**`, `tests/ai_scenarios/**` (others add their own `scenario_<stream>*.gd`), `tests/tactics/**`,
> `tests/nav/**`, `tests/test_ai*.gd`, `tests/test_tactics*.gd`, `tests/test_nav*.gd`, `tests/test_form_up.gd`,
> `tests/test_wheeled_arrival.gd`, `mk/ai.mk`, `mk/tactics.mk`, `mk/nav.mk`, `doctrines/doctrine_*.json`.
> **The C++ (C31.2):** `decide`, `build_situation`, TacticalQuery and `_approach_gate` run in C++. Every change there
> ships with native's mirror. **Model:** Opus.

## The lead's direction

His scout report (C33.9, verbatim in `game_design.md`): a scout being circled was "repeatedly driving forward and
backward trying to yaw right... The obvious correct behavior... drive straight forward and to the right... and also some
sort of evasive manoeuvre." Manoeuvre's turn-in (C33.9) did NOT ship at round 33's close (R33.39). It's manoeuvre's first
round-34 item (C34.10). **His answer (2026-10-18, "go
with both of your recommendations"), read as: a scout that can win the duel stands and trades; one that is outgunned
leaves.** Standing rule: smart AI on both sides, and symmetric improvements ship without asking.

## Where things stand (main at the round-34 docs commit)

- **Round 33 shipped from brains:** R1 respawns, R33.9 arrive latch, R33.6 coordinated groups, R4 approach gate, battery
  seat (a), rejoin, War Rig edge inset (4-of-5), herringbone halt fix.
- **Scout fights back, try 1 PARKED (R33.31):** at SPOT 0.15, ENGAGE won 90 % of firing ticks and shots rose ×1.62, but
  damage rose, and 3 close-orbit cells against the faster, longer-ranged syn_scout were > 20 % worse. Base:
  `lab/brains-scout` `0565d1a89` (GDScript + native pair).
- **B11b** waits on CP-F (manoeuvre's M3). **B10b** parked twice (R33.18, R33.22); its code is on `round33/brains`
  `78e9b59af` (`--ground-latch`). Not for main as written.
- `lab/brains-r33-battery` `ee18403b9` holds battery (c), parked. `lab/brains-r32-swap` `f2cc956d3` holds the inert
  swap seam (R5). Neither is this round's work unless named.

## Backlog (in order)

1. **B1 Scout try 2: stand when it can win, leave when it can't (C34.5).** Rebase `lab/brains-scout` on main (C33.9's
   turn-in is OFF there; agree with manoeuvre which arms report it ON). ENGAGE beats SPOT only with duel advantage ≥ 1.0 AND the contact in reach over the next 1–2 s;
   otherwise SPOT 0.88 and open distance. A pure test for each side of the rule. The bar is filed before any number: orbit
   seeds 73–79 (fresh), the shots ratio, damage taken (no cell worse by > 20 % on cells with base hits ≥ 10), scout survival,
   and team enemy-seen seconds ≥ base − 1.645 se. Native's mirror before the pair's check. One machine.
2. **B2 The flicker's seam (C34.4 (2)), with manoeuvre.** You own `_act`'s arrived branch and `_order_move`'s held-post
   refusal. Agree the seam with manoeuvre through the orchestrator before either side writes code. Review
   `lab/cpf-arriveleg` `7e0953f9d`'s one condition.
3. **B3 War Rig trace: log the inset's engage distance** (small; round 33's (1b) was reported only).
4. **B4 B11b (C33.3 stands) once CP-F merges:** HOLD's return honours the post's facing for `mount == "turret"` wheeled
   hulls only. Pass case s66 Green_Guns_5 ≤ 90° in ≥ 2 of 3; no class worse at p < 0.05; on a base with CP-F ON.
5. **B5 T4's body stage, on traffic's request** (C34.3): an order-free body stage if traffic's trace needs one.
6. **Stretch:** B10b's new form (re-ground with hysteresis, not the hold), with a fresh bar on fresh seeds.

## How to verify

`make quick-remote`; `make native check` on the pair tree (switch ON) before any series. `make scout-census`, the orbit
cells target (manoeuvre's `mk/manoeuvre.mk` c339 cells), `ground-series`, the fights guard. Long runs under `systemd-run
--user`. Every number: commit, machine, workload, n.

## Don't touch

Traffic's give-way block; manoeuvre's drive body, executor, the turn-in in `order_controller.gd`; planner's
`game/ai/planner/**`; native's `native/**`; `game/match/**`; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

- **B8b deploy step** (R34.7): his feel test, `DEPLOY_STEP=on make skirmish ARENA=locks`. Does a squad that arrives
  and then steps once into a tidy halt read better than today's settle twitch? Yes ships it ON; no keeps it parked.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### DEPLOY STEP ON (the lead's answer, round 34 close): WIP, NO CHECK YET
- **Done** (WIP commit on stream/brains, after merging main c46f66dc2 as 7c017cc13): `ElementPlan.DEPLOY_STEP` now
  defaults ON; `--deploy-step=off` / env `DEPLOY_STEP=off` is the off arm. test_tactics_deploy_step: teardown restores
  the default, `test_on_by_default` added, and the off test sets the switch itself.
- **It reaches CPU elements:** `_deploy_state` applies to any element on a plain `move` task with no chosen formation
  and no told facing, and ElementCommander gives `{"verb": "move"}` (element_commander.gd ~390/405/831/838/854). So
  sim-baseline WILL move on maps where the CPU moves.
- **Left:** (1) a full `make remote T=check` on **builder0** (builder2 is off). No remote check started; a laptop
  `--filter=test_tactics` run was in flight and unread when the session ended. (2) Attribute every moved sim-baseline
  with `DEPLOY_STEP=off` on the same tree, report which maps, and get the orchestrator's ruling for the new hashes.
  (3) Name the green hash and ask planner for one probe pass (24 cells, main v deploy-off). Tight packing on top (O2's
  (B)) is round 35's headline. **Don't start it before the flip is green.**

### ROUND 34 CLOSE-OUT (2026-10-19; brains idle, available for the deploy-step answer and merge fallout)
**Merged, in player terms** (green hashes; builder2 unless said):
- **Scouts trade when they're winning** (B1, `0b8fbd3f6`): a scout under fire that wins the duel by its own estimate
  stands and fights instead of always running.
- **Clicked moves land on your side of the canal** (Locks bank fixes `42401f95f`, `a1896dc07`): no squad drives over a
  bridge to park on the far bank of a spot you clicked on the near one.
- **Multi-squad clicks: smaller, sensible footprints** (O1 ground cap `43d81ec13`, O3 halt price `9260089f5`): squads
  pack into the ground you clicked, not across blocks. **Ranks never fall behind their own squad** (`2d6955367`), and
  the back rank stays near the click (`771586b2c`).
- **No squad sits "almost there" forever** (stall net `771586b2c`): a route leg whose crews all settled 12 s without
  progress counts as arrived, so queued legs move on. **Terminus route squad 3 arrives** (8.9 s, was never).
- **Queued routes through one gate don't jam** (gate order `f1034b904`, 2877/0, 13 unmoved): the squad reaching the
  gate first takes the farthest place. Locks 3 route all in at 18.5 s v never (planner, builder0).
- Perf test no longer fails on a loaded machine (`4bdc736fb`, `1fc467258`). The B3 inset trace and B2's arrival seam
  are on main (measurement / inert adapters).

**Parked, and why:**
- **B6 halt shape early**: failed its bar. B7 found the cause: a stale goal, not the slot tolerance.
- **O2 order-time heading** (`wip/brains-o2`): no tighter than O3, and it missed the response window. It waits on the
  deploy-step answer.
- **B9 lane spread**: failed its bar (below). The switch stays, off.
- **B4** waits on CP-F (parked R34.18). **B5** waits on traffic.

**Round-35 candidates:** (1) the attack-move step not waiting on a sector face (B11b's brains half); (2) untangling a
queued leg by its drive paths (the Locks 5 route's junction jam). Details in the sections below.

### REPORT (2026-10-18; every number builder2 unless said)
- **B1 scout try 2: PASS, merge here: `0b8fbd3f6`** (its check: builder2 `make check exited 2`, 2809 passed / 0 failed,
  26 of 27 targets; the one red is sim-baseline's docks move, ruled R34.3 and attributed by `SCOUT_FIGHT=off`, which
  left 13 unmoved on builder0). Later commits are docs and a Python table only. **What he'd notice:** a scout under
  fire that wins the duel by the brain's own estimate stands and trades. A law scout circled at 15 m by a syn_lancer
  fires 1032 shots against 175 over 7 runs. One that is outgunned (syn_scout, gang_ifv) keeps its distance as today,
  shots unchanged. In fights (scout-census, n 8, native) scout deaths are 134 v 140 and team scouting is unchanged.
  **Known cost:** a FIXED-gun scout held at a post shuffles when it stands (the lead's C33.9 shuffle). In its worst cell
  it takes about 1 more hit in 25 for no shots. Manoeuvre's turn-in (C34.10) is the fix for that.
  Rows: `references/round34/brains/scout2_*`. The verdict is in workstreams *Bars (round 34)*.
- **B3 DONE**, inside `0b8fbd3f6`.
- **B2 brains side DONE** (`984896b8f`, `e7275ee79`, inside `0b8fbd3f6`). Inert until manoeuvre's function lands.

- **B1 MERGED** (main `9c0f4dfce` = stream/brains `79d9f26eb`; stream/brains fast-forwarded to it). Smoke: skirmish
  screenshots on the laptop (builder0 down), desktop and phone. A live Foundry fight, with HUD, order marks and minimap
  correct. Looked at both.
- **Stretch B10b: NO CASE ON MAIN, not built** (time-boxed; rows `references/round34/brains/b10b_drift_diag_*`). A REPORTED
  diagnostic: main `9c0f4dfce`, builder2, dev seeds 40–41, 26 runs, main's rules, `--drift-trace`. 130 of the 137 drift
  moves happen after arrival, and all are herringbone. Each element's are ONE burst at one tick (every seat re-laid
  once), 2–6 a run, median 7.8 m. No crew flips (line > 10). The asked seat itself moves, so neither the 0.5 m latch nor a
  hysteresis re-ground would act. That matches R33.22 (ON = OFF on 28 runs). **Reported, not a defect claim:** an
  arrived herringbone squad re-lays its seats once, 8–20 m, after "arrived". If he sees a squad arrive and then shuffle
  into its halt shape, this is it (planner/manoeuvre may want it; no item filed).
- **Waiting:** B4 on CP-F's merge hash (manoeuvre); B5 on traffic's request. **Done** otherwise.

- **B6 (new, from the orchestrator): an arrived herringbone re-lays once. CAUSE WRITTEN, fix proposed, no code yet.**
  Trace (laptop, main `9c0f4dfce`, Sumps seed 41 tick 3, n 1, matches builder2's row): the element travels in a WEDGE
  and its final slots are wedge seats (±9.3 m along). The tick its CENTRE comes inside the arrival radius (t ≈ 26),
  ElementPlan switches to the halt, and `_halt` asks the table for the hold shape (herringbone). Every seat is re-laid
  at ±16–17 m along, on the same anchor and heading. The crews are still 15–20 m from their wedge seats, so they swerve
  4–10 m onto the new shape. Not the latch, not the herringbone drill (no HERRING_LAY). Rows:
  `references/round34/brains/b6_relay_trace_*`. **Proposal:** on the final approach (anchor = destination, within the
  final-approach distance, no shape chosen by him), lay the move's destination seats in the HALT's shape (the table's
  hold pick), with the technique still travelling. Then arrival changes nothing. A shape he chose (G) is untouched.
  Waiting on the orchestrator's go.

- **B6 BUILT, series RUNNING** (stream/brains `619eff0e1`; check `a2add1d0f` builder2 2812/0. B6 moves no map: docks
  was B1's move, now adopted on main. native-verify-scenarios' perf red was load: alone it's 53/0, 0 mismatches,
  18045 µs). Bar approved and recorded on main; ground block moved to fresh 610–613 (50–53 overlap squad-arrive's
  settle seeds); crossing 4–7 × {1,8,15}, shape auto, drills on. Table: tests/tactics/b6_table.py.
- **scenario_perf (orchestrator's side item):** under a check's load, scenario_perf's CPU budget false-fails or is NOT
  JUDGED: 4 of 6 ai-scenarios-check runs refused at 1.51–1.53×. builder2's nominal (0.898 ms) reads 1.41–1.46× even
  ALONE. Why is OPEN (stale nominal, or the box changed). Normalising by the reference was proposed and REJECTED by
  measurement: per_ref is not flat (plain +33 %, verify 2× at the same ratio; `references/round34/brains/
  scenario_perf_per_ref_builder2.txt`). Next, the orchestrator's call: three idle readings on builder2 as measurement,
  then decide verify's NOT_JUDGED.

- **B6 PARKED (R34.7)**, switch OFF (`a539188fe`). Series (builder2 `a2add1d0f`, fresh): drift 121 v 104 (limit 52) FAIL;
  Sumps hollow 9 v 0 FAIL; crossing guard ON = OFF (the early lay never engaged). **Causes (tuning traces, laptop, seeds
  40–41, `references/round34/brains/b6_tuning_traces_laptop.txt`):** (1) the early lay doesn't remove the swerve, it
  moves it 60 m out: wedge → herringbone at t=20 sends a seat about 35 m sideways. (2) Leftover re-lays come from the
  HEADING. The early lay uses the per-update bearing to the destination, which swings close in ((0.42,−0.91) one tick,
  (−0.04,−1.00) at the arrival), and a ±17 m herringbone turned 27° moves seats 5–8 m. (3) Hollow (CORRECTED by B7's trace, `references/round34/brains/b7_hollow_trace_laptop.txt`): NOT
  SLOT_TOLERANCE. The crew's move goal (−9.5,−44.1) was 1.8 m from its halt slot (−10.0,−45.8). It arrived at the goal and
  went HOLD/face, and the element never re-sent it, so it sits 3.7 m off the slot the judge reads. B6-specific: main
  goes hollow in 0 of 24 Sumps runs. (4) The worst run (s611 t16) brings back B10's round-32
  grounding flip. **Recommendation: no try 2 of the early lay** (it needs three fixes to only move the swerve). See the
  orchestrator's call.

- **B7 (SLOT_TOLERANCE 4.0 v ORDER_ARRIVE 3.5): NO CASE, premise withdrawn.** My B6 cause (3) was wrong. The arrival
  line and the brain's move arrival both use max(ORDER_ARRIVE, settle_radius); SLOT_TOLERANCE is only read by decide's
  old squad-context KEEP_SLOT (and _bounding_slot). The hollow was a stale goal under B6 (above).

- **O1 (C34.11, granted R34.8): the ground cap BUILT** (`43d81ec13`; decision and reasons in orders.md's O1 entry). No
  anchor of a several-squad order stands where the click reaches it only over a bridge deck, or by a drive > 1.5 x
  straight + 8 m. Tests: tests/test_control_ground_cap.gd (the Crossing's own navmesh and deck: today ≥ 1 of 3 anchors
  over the bridge, after none). Laptop test_control_* 411/0. Full check running on builder2. Next: O3.

- **O1 MERGED** (main `a5a6d0e95` = `473fbf22f`, green at `43d81ec13`: builder2 2818/0, sim-baseline 13 unmoved).
- **O3 BUILT** (`9260089f5`, check running): AUTO squads priced at their halt footprint (orders.md O3 entry has the
  numbers). **Merge note (grant):** one assertion in `tests/test_control_two_squads.gd` (round 22's "priced a line
  wide") follows O3 (orchestrator-approved); `--halt-price=off` keeps round 22's pricing.
- **scenario_perf under verify: NOT JUDGED** (orchestrator's ruling), `refusal()` factored pure, tests/test_ai_perf_refusal.gd
  4/0; laptop plain run still judged (PASS), verify run NOT JUDGED (21760 µs). The idle-nominal item (a) was DROPPED (the
  poll never found an idle builder2; removed). perf-judge judges the shipped budget in check (4 of 5 checks that night).

### Round 34, orders work (R34.8, R34.12; granted control paths), 2026-10-19
- **O1 MERGED** (green `43d81ec13`), **O3 MERGED** (green `9260089f5`), **scenario_perf under verify MERGED**
  (`4bdc736fb`).
- **His Locks bridge case CLOSED, named `42401f95f`** (builder2 2829/0, sim-baseline 13 unmoved). Cause: transit
  STATIONS over the canal were grounded on the nearest bank (`standable_for`), the far one. Fix:
  `SlotGround.station_on_goal_side` (only a station over water; it goes to its crew's final-seat bank). Planner's
  probe (laptop, Locks 5 click s34): crossed 1→0, all-in 21.5→13.8 s, worst shuffle 78.5→33.0 m.
- **R34.12 rank fix MERGED** (main `5fbb830ff`, green `2d6955367` (builder2 2833/0, unmoved): no rank's anchor stands behind its own squad
  along the approach. Planner runs the O5 before/after (`--rank-forward=off`).
- **scenario_perf LOADED_RATIO 1.5→1.2 GREEN** at `1fc467258` (= main ≥ `5fbb830ff` + `5ea102e1e`; builder2 2847/0,
  sim-baseline 13 unmoved). Loaded runs are now refused (1.50×) and perf-judge judges; the 8-run table is in the commit.
- **O2 PARKED** (R34.12; record on `wip/brains-o2` `da7524908`): (C) wasn't tighter than O3 (136 v 78.8 m: B6's
  travel wedge binds), the box order missed its response window, and five squads still mixed. It waits on (B)+B6, which
  is the lead's deploy-step question.
- **Traffic's O4** may edit Element._next_queued + passed_waypoint + relay_queued (agreed with two counters).

### Round 34, later items (2026-10-19), all green at `771586b2c` (builder2 2865/0, sim-baseline 13 unmoved)
- **Second Locks leak** `c3cdbd6c4` (merged via `a1896dc07`): an ORDER goal laid dry on the far bank came back as a slot
  but went out as an order. Element.ground's order path takes on_anchor_side. Locks 3 crossed 1→0.
- **B8 / B8b deploy step, PROTOTYPE, OFF** (`DEPLOY_STEP=on make skirmish ARENA=locks` to feel it). B8b: the halt is
  centred where the squad stands, stepped inland off water, seated by least driving; the halt re-seat is held while a
  deploy waits. The twitch after arrival drops sharply (Locks 5: 33 → 0; Terminus 5: 21 → 2); the deploy move is
  16–30 m. Known: a squad squeezed between the canal and a building still clusters. The lead decides (R34.7). Rows:
  `references/round34/brains/b8_*`.
- **R34.12b rank depth**: AUTO ranks step by the travel shape, widened only for 9 m halt-seat clearance (back rank 49 m
  v ~69 m behind the click).
- **Terminus route stall** (planner's bisect: O4 a5a362737; my arms: O3's spacing): an anchor on a block is grounded
  from the squad's side (`SelectionSquads.ground_anchors`). Squad 3 now in at 8.9 s (was never).
- **Stall safety net**: a player's route leg, every crew settled and no progress for 12 s → arrived (Element.track_stall).
- **B2 test** now asserts manoeuvre's leg_holds_arrival outright (it's on main, ON).
- **O2 stays parked** (`wip/brains-o2`); a fixed order-time heading makes the HALT seats exact (cheap packing), but the
  travel seats before all-in still aren't.

### B9 lane spread: FAILED its bar, stays OFF (series a82615a2b, builder2, 3 arenas x seeds 1400–1439, n 120 per arm)
- **A/A** (both off, ruled labels by seed parity): E +0.254, se 0.292. Clean (crossing +0.13, locks +0.17,
  terminus +0.47, each within ~1 se); all guards pass.
- **Ruled** (`LANE_SPREAD=green` on even seeds, `rust` on odd): E **+0.157**, se 0.310, needed > +0.511 → **FAIL**. Per
  arena: crossing +0.26, locks −0.03, terminus +0.24. Guards all pass: jam deaths R−B −0.30, stuck +0.18, first contact
  −0.35 s, contact spread +4.57 s (limit 7.41), fight length −1.2 s v aa.
- **The mechanism works, the outcome doesn't follow:** the ruled side's stacked picks fall from 64 % to 49 % (347/543 v
  250/512), with 241 via picks. So the census's stack ↔ deaths link was a correlation, not a cause we can buy back by
  spreading. 61 % of via picks go out as pairs to the same other lane in the same think (by design, "fewer of its
  squads": 2+1 → 2+2). Those still count as stacked.
- **Worst ruled fight**, locks-1404 (green ruled): squads 10 and 11 (support_by_fire) sent together via x+92 while 8
  and 9 stay central. 24 v 2 deaths (aa 0.36 E). The split force fed in piecemeal: contact spread 92 s, stuck deaths 6.
  It's one fight in a series that runs to 24–2 blowouts both ways, so it's a shape, not a proof.
- No re-tune this round (the bar was filed before the numbers). The switch stays (`--lane-spread`, default off).
  Rows: `references/round34/brains/b9_lane_series/` (aa.txt, ruled.txt, bar.txt).

### Gate order (`f1034b904`; check running on builder2)
- A queued multi-squad leg whose squads' paths share a gate deals its places FIRST THROUGH, FARTHEST ALONG
  (`SelectionSquads.gate_order`; `--gate-order=off` = round 33). Planner's builder0 probe (native, seed 34, main v off;
  stream/planner 8f736fa7e, references/round34/orders/gate-order-f1034b904/): **Locks 3 route FIXED** (all in 18.5 s v
  never; asks_refused 0 v 55, parked_refusals 5 v 91, unstick_fires 0 v 21). **Locks 5 route unchanged**, byte-identical
  (no shared gate). Its 22.7 m shortfall is a different shape: squad 3 (north to ~(0, 18)) and squad 5's Echo 2/3 (east
  to (54, 29–35)) cross at the junction near (5, 65) from t≈25 to ≈85 s. The final anchors don't cross in a straight
  line, but the drives off the second waypoint do. Candidate fix: untangle a queued leg by its PATHS (from each
  squad's previous leg end), not by the straight anchor lines (today's untangle skips queued legs).

### Round-35 candidates (noted, nothing now)
- **B11b's brains mechanism** (from CP-F attempt 4, parked R34.18): an attack-move element steps to its next leg ~30 s
  late when its arrived crews sit on a `face from sector` (tank_brain.gd ~2960, the sector watch) rather than a stop.
  law/faced_attack_move-614 stepped at t 60 v t 32 with the same laggard crew; 7 of 26 pairs stepped >= 10 s later.
  Candidate: the element's step should not wait on a sector face.

### Plan (2026-10-18)
B1 scout try 2 → B3 War Rig inset trace (small, done while B1's runs ran) → B2 the flicker seam (agree first) → B4
B11b (on CP-F's merge) → B5 (on traffic's request) → stretch B10b.

### Progress
- **B1 (scout try 2):** rule on stream/brains `86c8d7f68`. Main + try 1's GDScript and native pair cherry-picked, then
  try 2: fight only a duel at advantage >= 1 whose shooter stays in reach at 0/1/2 s, both sides on their velocities.
  Try 1's can't-outrun clause is dropped. Otherwise today's SPOT 0.88/0.7. **Decision:** I read "otherwise SPOT 0.88" as
  today's SPOT scoring unchanged. It is the narrowest change, and R33.31's harm was ENGAGE in lost duels, not SPOT.
  **Tuning finding (builder0, lab/brains-scout2, seeds 50–52, n 3 a cell):** the arms were identical (799 v 799 shots,
  ENGAGE 0). Cause: the champion x18m has `matchups: false`, so decide's table is empty. Try 1 only ever fired through
  its speed clause. Fix `834562ab1`: decide computes matchups_for for a scout under fire, only when the switch is ON.
  There's a decide-level test under the champion's features (laptop 9/0; with the fix reverted, 8/1). **Second finding (laptop
  probe, seed 50):** the stage's cells hold only duels the scouts lose (advantage >= 1 on 207 of 5320 rule ticks, none
  in reach). New duel cells, `tests/test_ai_scout_duel_cells.gd`, drive manoeuvre's `_orbit_stage` unchanged against
  syn_lancer and law_tank. Tuning, seed 50, laptop, n 1: law_scout v syn_lancer at 15 m, free: 218 v 23 shots, damage
  765 v 799. Bar FILED, then AMENDED before any judged number (orchestrator-approved; workstreams *Bars (round 34)*).
  Native mirror: pair/native-scout2 (native; lazy-matchups change sent). Next: the pair check, then the series on fresh
  73–79 and the census on 29–36.
- **quick-remote `66df97de3`** (builder0, QUICK_BASE main): 241 passed, 1 failed. The failure is
  test_native_decide::test_decide_is_the_gdscript, expected until native's mirror of try 2 and the lazy duel lands.
- **B3 DONE (no check yet; it rides B1's pair check):** `2aa657577` ELEMENT_TRACE prints `inset X m engaged at Y m`.
  Measurement only. Laptop anchor_inset 8/0.
- **B2 brains side DONE** (`984896b8f`, `e7275ee79`; seam acked by manoeuvre via the orchestrator). The `_act` MOVE
  arrived branch asks Manoeuvre.leg_holds_arrival through an adapter: false until manoeuvre's function is on the tree, so
  it's inert on main. tests/test_ai_arrive_leg.gd: mid k-turn leg, inside its radius, switch on → keeps move_to,
  held_moves_refused 0; switch off → today's arrival. If manoeuvre's const or switch name is present, the function must
  be too. Verified with 7e0953f9d's function pasted in on a scratch tree (laptop 1/0). `_act` has no C++ mirror. **At
  merge after manoeuvre:** drop the existence guard and assert outright.

### Requests to other streams
- native: scout try 2 mirror (taken: pair/native-scout2).
- manoeuvre (via orchestrator): agree the B2 seam; tell brains if C34.10 changes the orbit stage's rows or switch default.

### Questions for the lead
None.
