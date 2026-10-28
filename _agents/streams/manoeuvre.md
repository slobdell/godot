# Stream: manoeuvre (his first squad settles where he clicks: no 20 s jam in the start zone, no seat 29 m off, no crew lost on the way)

> Read `_agents/orchestration.md` (the worker contract), `_agents/workstreams.md` **Round 43** (C43.1, C43.4, C43.5, CP43.0), your
> round-42 brief `streams/archive/round42/manoeuvre.md` (Status: Q5 OFF and R42.11's framing "clear the stalled head", Q6's deckwait
> and why it failed, Known issues, the drill recipes), and `game_design.md` *His playtest after round 42*. **You own:** movement's drive
> / unstick / side-step / avoidance / yield in `game/ai/movement.gd` (not the planner seam), `game/ai/traffic.gd`; GRANT (C43.5) the
> formation's spacing and seat: `game/tactics/tactics_formation.gd` (`pitch`, `hull_floor`, `turning_pitch`, `offsets_at`,
> `fit_to_corridor`) and `game/control/group_formation.gd`; `tests/manoeuvre/**`, `tests/traffic/**`, `tests/test_manoeuvre*.gd`,
> `tests/test_traffic*.gd`, `tests/test_*formation*.gd`, `mk/manoeuvre.mk`. **Model:** Fable. **Machine:** builder0 light lane
> (J<=4); builder2 for a series over 24 fights. **Seeds:** 10401-10424 (bar S), 10425-10448 (guards), 10449-10472 (S5 bridge,
> BRIDGE_POOLED_SEEDS); his 56416 and dev blocks never a bar.

## The lead's direction (2026-10-27 ~20:00, verbatim)

"I was paying attention to the camera, but I didn't get far before seeing that my units all seemed incapable of moving to the west
side of the map. ... My first squad of tanks was never even able to settle for a simple target destination. I don't know if this is a
regression" ... "I want you to track that as something to investigate in the next round. I'm not sure if it's a bug per se, but it
warrants investigation and improvement."

Standing bar (memory, *units must look smart*): he must perceive his units as smart and under his control; contention first.

## Where things stand (main at launch: see HANDOFF)

- **His recording:** `_agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz` (Locks 56416, Gangs v Syndicate,
  laptop, 49 s); `python3 tools/recording_arrivals.py <file>`. His first squad (Guns: three War Rigs, a Gun Truck, a Tanker) ordered to
  (-69, 51) at tick 0: three of five arrived in 6-9 s; **the wedge seats the lead War Rig 29 m west of the click** (formation spacing
  for 14 m hulls; the same spread is in his round-41 recording); **War Rig 3 spent 20 s yielding to his Hunters in the deploy zone**
  (the same start-zone jam is in the round-41 recording, `references/round42/engage/2026-10-26T14-15-45-locks.jsonl`); **the Tanker
  routed east round the warehouses and never arrived in 14 s.** (The lead War Rig's later drive back north-east under attack-move is
  engage's A1; tell the orchestrator if your trace lands on it.)
- R42.11: the never-in squads are columns behind a STALLED HEAD (at the Crossing's street mouths); the next rule must clear the head
  (why it stands: the deploy / seat / mouth it waits on), not only ease the follower. R42.15: deckwait's fresh-seed bridge had nothing
  to fix OFF; the next shape fires only on the carried-past case.
- The headless replay (`tests/replay_orders.gd`, native's this round) diverges from his match in 2 s: his Guns jam at the start, the
  replay's drive off. That divergence IS your jam: until CP43.0 makes the replay faithful, rebuild the start from his census (tick 0-60).
- ON for `deckwait` / `nopush` / `wait` / `holdlane` forces `native_drive` off until twinned (Known issues, round 42).

## Backlog (in order)

1. **S1 the arrival census of his first order (report first).** From his census (ticks 0-60), rebuild Locks 56416's start with his
   whole army and his first order; trace per crew per tick: seat, distance to seat, the mover's phase, who it yields to and why (the
   yield / ask / wait chain), the route (which way round the warehouses and why the Tanker's goes east). Name, with ticks: why War Rig 3
   yields 20 s to the Hunters (who is the stalled head and what it waits on), why the wedge seat is 29 m from the click (the pitch
   numbers), why the Tanker never arrives. Do the same on the round-41 recording's start. Send the table to the orchestrator first.
2. **S2 the seat (C43.5).** His click is where the squad goes: the formation centred on the click, its farthest seat within a bound you
   name from the hulls (e.g. <= 1.5 hull lengths + the hull floor for a five-crew wedge), spacing by real hull extents (C38's floors
   kept), the G1 v9 group column unchanged for a group of squads (test). OFF behind a switch; a test on his click first.
3. **S3 the start-zone jam.** The rule S1's cause asks for (clear the head: e.g. a crew already at its seat or parked in the deploy zone
   steps aside for a crew whose route runs through it; a yield that times out with nobody moving re-plans), speed-only where it can be
   (C43.4), OFF behind `--traffic-on=<name>`, a test on his start first.
4. **S4 Bar S, filed before any number on 10401-10424.** Workload: his first order shape (a five-crew mixed squad to a point on its own
   bank, the rest of the army deployed beside it, then a second squad's order through the same zone) on Locks + two arenas with a cramped
   deploy (terminus, crossing), 24 seeds, BASE off v ARM on, one commit. Deciding (name before numbers, e.g.): crews seated within the
   bound by 15 s ARM > BASE by >= 2 se, AND start-zone yield-seconds ARM < BASE by >= 2 se. Guards (filed first, unamended): his 5-squad
   order's jam / contact lines at round 42's levels, Bar G1 v9's corridor lines, fight length, perf (us/tick within 1.05x), no SCRIPT
   ERROR; 10425-10448. Native twins before ON, or the bar says native_drive is forced off for it (C43.4).
5. **S5 the bridge crew (balance's gate, R42.15 / R42.23).** The drill crew rust s2 t15 that Bar B2s v2's bridge depends on: the
   carried-past case only (your round-42 next-round shape), on fresh 10449-10472. If it passes, balance's stat change can be re-read next
   round.
6. **Stretch:** the `_wait` timer artefact fix with a test; `q3_judge.py`'s counters line under `--arm=deckwait` (one-line fix).

## How to verify

`tests/test_traffic*.gd`, `tests/test_manoeuvre*.gd`, `tests/manoeuvre/**`; `make quick-remote`; `make remote T=check` only for a hash
you name. Smoke like a player on the laptop: `make skirmish ARENA=locks SEED=56416`, Gangs: send his Guns squad to (-69, 51) and his
Hunters next to it; do all five crews sit near the click within seconds, does anyone wait 20 s? Screenshots at desktop and phone aspect.

## Don't touch

`game/tactics/element_plan.gd`, `drills.gd`, `firing_position.gd` (engage), `game/ai/planner/**`, `game/ai/order_controller.gd`,
`game/camera/**`, `native/**`, `tests/replay_orders.gd` (native), `game/match/**`, `arenas/**`, `tests/baselines/**`. Don't push main.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### CLOSE REPORT (round 43, manoeuvre; 2026-10-28 ~05:40 PDT, the v2 guards and the scoping proof still landing: appended below as they do)

**Ship candidate (R43.42): d61f98cbc** = stream/manoeuvre with every round-43 rule OFF by default (the latch flipped, dc2da5cd2) +
`wip/manoeuvre-bars-v2` (parkaside) + native's pairs `pair/native-parkaside` 5b5a2c365 and `pair/native-kturngoal` b2dea555a (the
GDScript-drive gate keeps neither: both twinned) + deckwait v5 and the q3_judge fix cherry-picked from `wip/manoeuvre-s5` + main
e1a1c2ad7 (DEFAULT_OFF keeps engage's holdfar / holdway / holdroute and my kturngoal / parkaside). **Its ONE full check is running on
builder2** (unit `manoeuvre-r43-checkship`, `~/overnight-manoeuvre/r43/check_ship/check.log`); its wrapper line names the green
hash. Before it: **fed356a8b** green (builder2, 3367 / 0) and 04ddbcabb green (3370 / 0). **Nothing ships ON this round:** Bar S (four arms) and Bar S v2 (its one re-file) and Bar S5 all FAIL as filed;
the seat bound, the converge fix, kturngoal, parkaside and deckwait v5 are on the branch (or its side branches) OFF behind their
switches with their tests. **The shape latch is ON by default per R43.6 ("switch with =off") but was judged only inside Bar S's
`seats` arm: the orchestrator decides at the merge whether it stays ON.**

1. **S1 (done, reported):** his first order's three failures are one cause: the Gangs' swarm at the War Rig's hull-floored pitch
   is 112 m wide (seats 72 m and 63 m east of his click), `inset_anchor` slid the centre 15 m off the click for that reach, and the
   shape flipped swarm / vee four times on the threat reading; War Rig 3 held across the Hunters' lane for a seat on the wrong side
   of the map; the 29 m lead seat is the hull floor. Rebuilt to 0.1 m of his census for 10 s (`make manoeuvre-start-trace`).
2. **S2 (built, OFF):** the seat bound (`--seat-bound=on`; 37 m for War Rigs, 18 m for Gun Trucks; the transit's stations and start
   bounded too, R43.7) and the shape latch (R43.6). His start re-read: all five Guns at his click in 5-10 s.
3. **S3 (built, OFF):** the first-tick k-turn for a station a hull's length off the crew (the converge rebuild behind a bent first
   leg): `--converge-on-crew=on` (R43.14) and `--traffic-on=kturngoal` (the reverse leg ends when its goal has moved out of the
   circle; native twin b2dea555a); `--traffic-on=parkaside` (a seat under a parked friend of another squad is taken beside it;
   twin 5b5a2c365).
4. **S4 Bar S (FAIL as filed, R43.31) and Bar S v2 (FAIL as filed on Locks' per-arena guard, +2.4 se, and on the group-order guard
   G5, +3.8 s a run; D1 +13.8 se, D2 -2.4 se, never-arrived -37 %; fights and the G1 v9 lines still running on builder0 light).** The
   tables are below; the round-44 shape is named there.
5. **S5 Bar S5 (FAIL as filed):** deckwait v5 rescues the drill's own crew (17/18 -> 18/18) and costs rim seconds on the fresh
   seeds; deckwait stays OFF; balance's bridge re-read not reached.
6. **Stretch:** the `_wait` timer artefact was fixed in round 42; `q3_judge.py`'s counters line under `--arm=deckwait` fixed (on
   `wip/manoeuvre-s5` 55d6344c1: cherry-pick with the ship). **R43.34 candidate (round 44):** `wip/manoeuvre-scope-g1` 4132802e7, a
   squad under one order to many squads (the pack's `group` key, or `halt_at`) keeps today's seats / stations / transit start / shape
   pick / converge / kturngoal / parkaside; its tests (21/0 laptop) and the G1 v9 byte-identical proof (take 3 queued behind the ship
   check): below, under "R43.34 candidate".

**Decisions (mine, one line each):** the bound = max(18 m, 1.5 hull lengths + the hull floor along) (the wedge of War Rigs at 29 m
is physics, the swarm's 58 m is not); the latch stores the formation only (the technique follows the table); kturngoal ends the
circle plan's leg and the seam's plan alike, by the same geometry; parkaside memoises only once a seat is moved (the other squad
parks after the first look); v2 = one arm (R43.31), the Locks line judged per arena as ruled; nothing amended after a number.

**Questions for the lead:** none that block. **For the orchestrator:** the latch's default at the merge (above); the round-44
candidates (the Locks convergence fix; the G1 scoping) are design work, not bars yet.

**Requests to other streams:** native: the kturngoal and parkaside pairs merge with any ship of those switches (both proved);
nothing else. Engage: none (Traffic's street hold untouched, R43.8).

**Known issues:** ON for `kturngoal` / `parkaside` / `deckwait` / `nopush` / `wait` / `holdlane` forces `native_drive` off until the
pairs merge; parkaside's per-tick look costs ~0.45 ms a tick ON (native's measure: ~6 % of the AI tick; a look every few ticks on
the approach's last stretch is the cheap form); the bounded shapes reach a G1 group click's drive (R43.34; the scoping candidate);
a hand-run laptop Godot drifts from his match after ~13 s without the trig preload (go through `make`).

**What to playtest (laptop, every switch OFF by default):** `make skirmish ARENA=locks SEED=56416 SKIRMISH_FLAGS="--seat-bound=on
--converge-on-crew=on --traffic-on=kturngoal --traffic-on=parkaside"` v without: Gangs, send squad 1 (the War Rigs) to (-69, 51) in
the planning pause, squad 2 next to it two seconds later: do all five rigs sit at the click within ten seconds, does anyone back
into the edge, do the two squads jostle? Headless: `make manoeuvre-start-trace ST_RECORDING=build/his.jsonl ST_ARENA=locks
ST_SEED=56416 'ST_FLAGS=--seat-bound=on --converge-on-crew=on --traffic-on=kturngoal'` (zcat his recording into build/ first).

**Merge notes:** branch off 2f1620a77; main 84f914f78 merged at f6b930a3d (CP43.0). Game changes: `game/tactics/tactics_formation.gd`
(SEAT_BOUND, seat_bound / reach_of / bounded / shape_at, the bound in place), `game/tactics/element_plan.gd` (latch_shape + the
pick's latch line, inset_anchor untouched, route_seats / stations_along bounded, transit_start_m's bounded depth, converge /
transit_starts `worlds`), `game/tactics/element.gd` (shape_latch field + state + readback; the transit's `worlds`; the stations'
members; transit_start_m's arg on the scope branch only), `game/control/group_formation.gd` untouched, `game/ai/movement.gd`
(kturngoal: `_planned_reverse`'s goal-moved end, `_kturn_goal_moved_out`, the note; on the v2 branch parkaside in `_manoeuvre`),
`game/ai/manoeuvre.gd` (the kturn-goal and aside statics), `game/ai/traffic.gd` (DEFAULT_OFF += kturngoal [+ parkaside on v2];
`_chain_native`). Tests: `tests/test_formation_seat_bound.gd`, `test_formation_shape_latch.gd`, `test_formation_converge_start.gd`,
`test_manoeuvre_kturn_goal.gd` (+ `test_manoeuvre_parkaside.gd` on v2, `test_formation_group_scope.gd` on scope-g1); probes and
judges `tests/manoeuvre/start_trace.gd`, `start_table.py`, `s_judge.py`; `mk/manoeuvre.mk` (manoeuvre-start-trace, manoeuvre-bar-s).
`_agents/orientation.md` trip-up 87 (the full disk). Side branches: `wip/manoeuvre-bars-v2` (04ddbcabb, green on builder2 3370/0),
`wip/manoeuvre-s5` (55d6344c1), `wip/manoeuvre-s5-main` (64b547192), `wip/manoeuvre-scope-g1` (5b23227e0); worktrees
`../godot-manoeuvre-v2` and `../godot-manoeuvre-s5m` (on scope-g1) come down when their runs end. Evidence
`references/round43/manoeuvre/` (Bar S, S5, v2 judges) and `~/overnight-manoeuvre/r43/`.


**Session start 2026-10-27 ~20:40 PDT (Fable). Starting commit 2f1620a77 = main at launch (code b12b17ac7 GREEN builder0, 3343/0; no
baseline check re-run, per the contract). CP43.0 taken at f6b930a3d (main 84f914f78 merged). Orchestrator session: `godot-b8`.**

### v2 GATE GREEN on builder2 (2026-10-28 03:34 PDT): 04ddbcabb `make check exited 0`, 3370 passed / 0 failed; the v2 series starts when Bar S5's ends

`~/overnight-manoeuvre/r43/check_v2/check.log`: the wrapper line, `3370 passed, 0 failed` (Bar S's 3367 + parkaside's 3), 26 targets
passed + the usual NOT JUDGED pair (perf-judge: not a judging machine; scenario_perf loaded). **This commit is green: 04ddbcabb**
(`wip/manoeuvre-bars-v2`).

### R43.34 and the disk (2026-10-28 ~04:05 PDT): v2 runs AS FILED; the G1 group-click scoping is a round-44 candidate

- **R43.34 (the orchestrator):** C43.5's "G1 v9 group column unchanged" was moved by Bar S's `all` (grouped squads travel as elements,
  so the bound, the latch's stations and parkaside reach the group click's drive: metres outside after +12 m, the Locks twitch).
  Scope them OFF for squads under one G1 group click (a task with `halt_at` = a grouped squad; single-squad orders only) and prove
  the G1 v9 probe byte-identical v base. **Correction (same hour): v2 cannot be re-filed after its numbers (R43.31: the last re-file);
  if v2's G1 v9 lines move, v2 FAILS as filed; the scoping is built and proved as a ROUND-44 candidate.** v2 runs as filed; if it
  passes every line incl. G1 v9 it ships as is.
- **The laptop's disk filled (~03:40 PDT, 0 MB free on /):** my session's temp outputs, the copy-back folders of my worktrees, Bar S's
  raw guard logs (judges in references) and the void dev reads freed ~3.6 GB; worktrees `godot-manoeuvre-b0` and `-v2b0` removed
  (s5 / s5m stay for Bar S5's series, v2 for its gate and series; each goes as its series ends). The full disk also emptied this
  brief on one edit (commit 20e9874d3, reset away) and `after_s5.sh` (the chain unit died on exec): both rewritten; the chain unit is
  `manoeuvre-r43-barsv2c`; the v2 gate check runs on builder2 (unit `manoeuvre-r43-checkv2`, `~/overnight-manoeuvre/r43/check_v2/
  check.log`); the v2 series runs the fights and the orders probe from the v2 tree in sequence after builder2's parts (one worktree).

### Bar S v2: FILED 2026-10-28 ~03:35 PDT, BEFORE any number on 10701-10748 (R43.31: the one re-file, ONE arm; the dev read below)

- **The arm judged:** `v2` = `--seat-bound=on --converge-on-crew=on --traffic-on=kturngoal --traffic-on=parkaside` (+ the latch ON) on the
  FROZEN tree **04ddbcabb** (`wip/manoeuvre-bars-v2` = fed356a8b + parkaside; no game/ or tests/ commit until the series' end line) v `base`
  = `--shape-latch=off` on the same tree. **parkaside** (`Traffic.DEFAULT_OFF`): in the drive's callback layer (`Movement._manoeuvre`), a
  move goal within 30 m that lies inside the clearance disc (both radii + 1 m) of a friend that is PARKED (arrived, under 0.3 m/s) and
  not of my element is taken on the nearest free point of that disc's rim (12 looks, the seat's side first, on the navmesh, clear of
  every other parked friend), remembered per goal only once moved (a Manoeuvre static by instance id; no exec field); the drive, the
  asks and ORCA untouched (C43.4). ON runs the GDScript drive (`Traffic._chain_native`: the C++ drive calls `_manoeuvre` back only after
  its cheap look; native's twin before ON). Test `tests/test_manoeuvre_parkaside.gd` (3; the drive twins beside it, 16/0 on builder2).
- **Why (Bar S's read):** with the bound the first squad sits compactly at its click and the second squad, clicked 17 m past it, was
  dealt seats ON its parked hulls (the slot grounding reads the navmesh only); the two then asked each other to give way (Locks
  yield + blocked +6.9 s a run, +3.4 se). Not squadmates (their seats keep the hull floor).
- **What it could break (named first):** the same as Bar S's, plus: a crew taken beside a parked friend standing farther from the
  click (D1), a rim point on a street's wall (never-in), two crews taken to the same rim point (contacts); the G1 v9 group click's
  drive (Bar S's read: the bounded stations and the latch reach it: metres outside after +12 m, twitch locks 16.9 -> 20.6 m).
- **Gate:** the frozen tree's full check green FIRST (on builder2, unit `manoeuvre-r43-checkv2`, `~/overnight-manoeuvre/r43/check_v2/
  check.log`; `after_s5.sh` refuses a red gate). **Workload, deciding, per-arena guards:** exactly Bar S's, unamended, on fresh
  **10701-10724** (72 paired cells): D1 crews within the bound at 15 s ARM > BASE by >= 2 se AND pooled; D2 start-zone yield +
  blocked s ARM < BASE by >= 2 se AND pooled; per arena yield + blocked s and k-turn s ARM <= BASE + 2 se. **Guards:** group-order
  (q3_judge G5 / G6 / G7) crossing / locks / sumps / terminus x 10725-10736 x crew; G1 v9 lines (`orders_judge.py g1v8`: places outside,
  metres outside after, re-dealt, each ARM <= BASE; the judge's own twitch guard reported) locks / crossing / terminus x 5 squads x
  click x 10725-10736; fights (wedge trace locks / terminus / sumps x 10737-10742, G1-G4); perf on builder0 quiet (the check's
  perf-judge stage + `sim-profile` base v v2 us/tick <= 1.05 x for the native-drive arms; the GDScript-drive rules (kturngoal,
  parkaside) perf-judged after native's twins); no SCRIPT ERROR. **Ships ON only if D1, D2, every per-arena guard and every guard
  pass; no re-file (R43.31).**
- **Machine:** `~/overnight-manoeuvre/r43/bars_v2.sh` from unit `manoeuvre-r43-barsv2c` (after Bar S5's series ends and the gate is
  green): deciding + group on builder2 (J 12), then the fights + the orders probe on builder0 light, all from `../godot-manoeuvre-v2`;
  evidence `~/overnight-manoeuvre/r43/bars_v2/`, filed under `references/round43/manoeuvre/barsv2-<machine>-04ddbcabb/`.
- **Dev history (C42.1; dev seeds only; nothing on 10701+ read):** dev reads v2-1 and v2-2 were void: parkaside never fired (a memo
  written before the other squad had parked; then the arm list's commas split `--traffic-on=kturngoal,parkaside`, so the name was a
  bare argument: `all` and `v2` byte-identical). **Dev read v2-3 (`~/overnight-manoeuvre/r43/bars-dev/v2dev3`; 7001-7012 + 9501-9512 x
  locks / terminus / crossing = 72 paired cells, builder2 light, base v all v v2):** all: D1 221 -> 372 (+9.5 se), D2 -2.96 s a run
  (-1.9 se) FAIL, locks yield+blocked +3.7 s (+2.5 se) FAIL (Bar S's picture again); **v2: D1 221 -> 363 (+1.97 a run, +10.0 se)
  PASS, D2 1473 -> 1214 s (-3.60 s a run, -2.5 se) PASS, per arena: crossing +0.86 s (+0.4 se) PASS, locks +3.0 s (+1.8 se) PASS,
  terminus -14.7 s PASS, every k-turn line PASS; never-arrived 249 -> 163, arrival -1.01 s a crew, k-turn -9.0 s a run: VERDICT PASS.**
  Locks is the line at risk (+1.8 se on dev); the bar decides it, unamended.

### Bar S: THE DECIDING READ (series 01:21-01:38 PDT, builder2, J 12, native library ON (kturngoal on the GDScript drive by its switch), frozen fed356a8b; 72 paired cells an arm = locks / terminus / crossing x 10401-10424; 0 SCRIPT ERROR in 360 logs; the guards still running)

Evidence `references/round43/manoeuvre/bars-builder2-fed356a8b/judge-deciding-<arm>.txt` (per-cell rows inside); raw logs
`~/overnight-manoeuvre/r43/bars/deciding/`. The bar as filed; no line amended; nothing re-run.

| line (each arm v base, paired per cell) | seats | converge | kturngoal | all |
|---|---|---|---|---|
| D1 crews within the bound at 15 s (pooled, of 720) | 197 -> 329, +1.83 a run, se 0.20 (+9.2 se) **PASS** | 197 -> 170 (-2.7 se) FAIL | 197 -> 175 (-2.7 se) FAIL | 197 -> 338 (+8.9 se) **PASS** |
| D2 start-zone yield + blocked s (pooled) | 1422 -> 1295, -1.76 s a run, se 1.46 (-1.2 se) FAIL | 1422 -> 1033, -5.40 s (-4.5 se) **PASS** | 1422 -> 1127, -4.10 s (-3.4 se) **PASS** | 1422 -> 1328, -1.30 s (-0.9 se) FAIL |
| G crossing yield+blocked <= +2 se | +2.28 s a run, se 1.16 (+2.0 se) PASS | -3.74 (-1.8 se) PASS | -1.56 (-1.1 se) PASS | +2.95 (+1.3 se) PASS |
| G crossing k-turn s | -6.09 (-5.4 se) PASS | -3.54 (-2.7 se) PASS | -5.65 (-7.8 se) PASS | -7.23 (-6.8 se) PASS |
| G locks yield+blocked | **+6.90 s a run, se 2.0 (+3.4 se) FAIL** | -0.13 (-0.3 se) PASS | +0.83 (+0.9 se) PASS | **+7.50 (+5.4 se) FAIL** |
| G locks k-turn s | -3.04 (-2.0 se) PASS | +0.32 (+1.8 se) PASS | -0.45 (-1.0 se) PASS | -1.35 (-0.9 se) PASS |
| G terminus yield+blocked | -14.45 (-7.9 se) PASS | -12.33 (-5.3 se) PASS | -11.57 (-4.4 se) PASS | -14.35 (-9.0 se) PASS |
| G terminus k-turn s | -10.70 (-7.6 se) PASS | -7.08 (-4.8 se) PASS | -11.12 (-4.8 se) PASS | -17.26 (-7.0 se) PASS |
| reported: never-arrived crews (of 720) | 253 -> 226 | 253 -> 247 | 253 -> 214 | 253 -> 227 |
| reported: mean arrival s a crew (never = 15) | -0.95 a run (se 0.14) | -0.15 | -0.35 (se 0.10) | -0.77 |
| reported: k-turn s a run | -6.6 | -3.4 | -5.7 | -8.6 |
| reported: seat moves a run | -29.1 | +0.3 | -1.5 | -30.0 |
| **verdict as filed (D1 AND D2 AND every guard)** | **FAIL** (D2; locks guard) | **FAIL** (D1) | **FAIL** (D1) | **FAIL** (D2; locks guard) |

**R43.31 (the orchestrator, ~02:05 PDT): nothing from Bar S ships, as filed** (converge and kturngoal lose D1 at -2.7 se each: a measured
loss on a deciding line; D1 is the line nearest his words). One re-file, Bar S v2, on fresh 10701-10724 (guards 10725-10748): ONE arm
= all + a fix for the converging give-way, same lines, same workload, perf on builder0 quiet; time-box ~2 h on the dev blocks
7001-7012 and 9501-9512, else all OFF with this read. **Group-order guards (for the record, base v all, 10425-10436 x 4 maps x crew,
48 paired runs, builder2, `judge-group-all.txt`): G5 all-in 74.5 -> 73.6 s PASS, G6 never-in squads a run 0.94 -> 1.08 (line 1.14)
PASS, G7 contacts 663,350 -> 656,229 PASS; jam-seconds -0.2 %.** **Fight guards (base v all, locks / terminus / sumps x
10437-10442, 18 paired fights, builder0 light, `judge-fights-all.txt`): G1 give-way deaths 41 -> 56 (line +16.5) PASS, G2 stuck
deaths 143 -> 120 PASS, G3 contacts 380,442 -> 351,514 PASS, G4 kill share worst move 0.008 / deaths 701 -> 713 PASS; the judge's own
D line (moving-stuck seconds) 500 -> 208 s (-58 %, -2.2 se).** **G1 v9 corridor lines (base v all, locks / crossing / terminus x 5
squads x click x 10425-10436, `judge-g1v9-all.txt`, `orders_judge.py g1v8`): places outside the corridor 5 -> 5 PASS (<= base),
re-dealt 0 -> 0 PASS, **metres driven outside after being in 168 -> 180 FAIL** (<= base; all of it crossing's cells), and the probe's
own twitch guard **FAIL on locks (16.9 -> 20.6 m, line base + 3)**: the group's squads travel as elements, so the bounded stations
and the latch do reach the group click's drive (the halts themselves are untouched: columns laid 12, bodies kept 24).** Perf: not
run (nothing ships, R43.31). Series ended 02:47 PDT; Bar S5's started 02:48.

**The read (after the numbers):** the two lines pull apart by construction. D1 measures the distance from his click, and without the
bound a squad's seats stay the doctrine's (the swarm's 58 m), so the two mover-side arms cannot move it (they lose it slightly: a
crew that now reaches its far seat is farther from the click than one stuck half-way); only the bound moves D1, and it moves it
hugely (+9 se, 197 -> 329 of 720 crews within the bound at 15 s; seat moves -29 a run; arrival -0.95 s a crew). The bound's cost
is on Locks: five crews converging on seats within 37 m of each other give way to each other on the way in (yield + blocked
+6.9 s a run, +3.4 se; most Locks cells 7-24 -> 25-34 s; never-arrived there 29 -> 32 of 240, arrival still better), while
terminus and crossing improve. The mover-side arms pass D2 and every per-arena guard (converge -4.5 se, kturngoal -3.4 se on
D2; kturngoal never-arrived 253 -> 214, k-turn -5.7 s a run) and cost nothing anywhere. No arm passes the bar as filed; the
orchestrator rules (R43.14's own rule: an arm without seats that passes everything ships; these pass everything but D1).
### GATE GREEN on builder2 (2026-10-28 01:20 PDT): fed356a8b's code (the b0 worktree at that hash) `make check exited 0`, 3367 passed / 0 failed, 26 targets passed + 2 NOT JUDGED; Bar S's series started 01:21

- `~/overnight-manoeuvre/r43/check1/check.log`: the wrapper line `>> remote: make check exited 0 (build/ copied back)`; `3367
  passed, 0 failed` (11 shards); `check passed: 27 targets`; sim-baseline unmoved on every map (builder2, glibc 2.43); NOT JUDGED:
  perf-judge (builder2 is not a judging machine: judged on builder0 in a quiet window after the series, as the bar's perf line
  says) and ai-scenarios-check's scenario_perf (loaded, ref 4.70x). Two earlier tries: builder0 segfaulted in `make import` (a
  font reimport in the fresh folder), then queued 55 min behind native's and engage's checks; moved to builder2 on the
  orchestrator's word (my builder0 waiter killed by its folder).
- **This commit is green: fed356a8b** (the stream branch's later commits are `_agents/streams/manoeuvre.md` only).
- The series (`bars.sh`) started 01:21 PDT on builder2 (deciding + group guards, J 12) and builder0 light (fights + the G1 v9
  probe, from `../godot-manoeuvre-b0`); Bar S5's series is chained behind it (unit `manoeuvre-r43-bars5`).

### Native's twin of kturngoal is GREEN (2026-10-28 ~03:50 PDT): `pair/native-kturngoal` a907a541e off fed356a8b

builder2 light: native-proof EQUAL with kturngoal ON (on / off / ab the same state hash), 12/0; a C++-driven backing leg whose goal
moved out calls back into `_planned_reverse` (ends it the GDScript way) and the cheap look writes `Manoeuvre.kturn_goal_note`; no
new exec field; OFF byte-identical. Files are native's (native/src/drive_native.{cpp,h}, tank_native.cpp, native_drive.gd,
tests/native/drive_twin_case.gd, tests/test_native_drive_kturn_goal.gd). Bar S runs as filed on the frozen tree (kturngoal on the
GDScript drive by its own switch); the pair merges at ship, and with it kturngoal can ship ON with native_drive ON (C43.4).
The player-view frames (`make remote T=orders-probe-shots`, locks, 5 squads, base v all, desktop 1280x720 and phone 1560x720, at
arrival and 5 s later): `~/overnight-manoeuvre/r43/shots/frames/`; the group click's column stands alike in both arms (the halts
are laid as today), no pile-up.

### Bar S v2: VERDICT FAIL as filed (series 05:14-05:43 PDT, builder2 light, J 12, frozen 04ddbcabb (its full check green: `check_v2/check.log`, 3370 / 0); 72 paired cells = locks / terminus / crossing x 10701-10724; the fights and the G1 v9 lines on builder0 light after it)

Evidence `references/round43/manoeuvre/barsv2-builder2-04ddbcabb/judge-deciding-v2.txt` (per-cell rows inside) and `judge-group-v2.txt`;
raw logs `~/overnight-manoeuvre/r43/bars_v2/`. The bar as filed; no line amended; nothing re-run.

| line (v2 v base, paired per cell) | v2 = all + parkaside |
|---|---|
| D1 crews within the bound at 15 s (pooled, of 720) | 199 -> 362, +2.26 a run, se 0.16 (**+13.8 se**) PASS |
| D2 start-zone yield + blocked s (pooled) | 1486 -> 1226, -3.62 s a run, se 1.52 (**-2.4 se**) PASS |
| G crossing yield+blocked <= +2 se / k-turn s | +0.31 s (+0.1 se) PASS / -7.63 (-4.4 se) PASS |
| G locks yield+blocked / k-turn s | **+4.12 s a run, se 1.72 (+2.4 se) FAIL** (Bar S's all: +7.50, +5.4 se) / -4.23 (-2.5 se) PASS |
| G terminus yield+blocked / k-turn s | -15.3 (-8.1 se) PASS / -14.6 (-6.5 se) PASS |
| reported: never-arrived crews (of 720) / arrival s a crew / k-turn s a run / seat moves a run | 226 -> 142 / -0.96 / -8.8 / -32.6 |
| group-order guards (10725-10736 x 4 maps x crew, 48 paired runs, `judge-group-v2.txt`) | **G5 all-in 74.0 -> 77.8 s (line 77.0) FAIL**; G6 never-in 0.96 -> 1.04 (line 1.13) PASS; G7 contacts 657,611 -> 679,824 (line 690,492) PASS; jam-seconds +2.0 % |
| fights (10737-10742, G1-G4) and the G1 v9 lines (10725-10736) | running on builder0 light from `../godot-manoeuvre-v2`; recorded below when they end |
| **verdict as filed (D1 AND D2 AND every guard)** | **FAIL** (the Locks per-arena guard; G5) |

**The read (after the numbers):** v2 does what he asked everywhere it is measured against his own first order (both deciding lines, by
a wide margin on D1; a third fewer crews never arrive; seat moves a third of base's), and its cost is the one Bar S named, halved but
not gone: on Locks five crews converging on seats within 37 m of each other still give way to each other on the way in (+4.1 s a run
v +7.5). On his 5-squad order (the group guards) v2 also slows the last squad in by 3.8 s a run (G5; Bar S's `all` had passed it
74.5 -> 73.6): parkaside's seats-beside on a group click is a second thing the round-44 scoping must settle (the candidate below
leaves a grouped squad's crews to drive as today). **Nothing ships (R43.42)**; the round-44 filing is: the bound + converge + kturngoal
+ parkaside scoped to a squad on its own order (the candidate), with Locks' give-way line and G5 as its two named risks.

### Bar S5: VERDICT FAIL on the deciding lines (series 02:48-04:12 PDT, builder2 light, GDScript drive both arms, trees 55d6344c1 (overrides) / 64b547192 (main); the group guards and fights running for the record)

Evidence `references/round43/manoeuvre/bars5-builder2-55d6344c1/` (the two `--q6` tables and the bridge rows). The bar as filed; no
line amended; no re-run on 10449-10460.

| line | overrides tree (OFF -> ON, 72 runs an arm) | main tree (OFF -> ON) |
|---|---|---|
| Deciding 1 (the hard line, seeds 1-3 under the overrides, ON 18/18) | dev read 1: 18/18 (the series re-ran the fresh seeds only) | n/a |
| Deciding 2a: pooled rim-seconds ON <= OFF | 32.0 -> 40.3 s (+26 %); per-run +0.12 s, se 0.07 (+1.7 se) **FAIL** | 32.9 -> 38.6 s (+17 %); +0.08 s, se 0.06 (+1.3 se) **FAIL** |
| Deciding 2b: every surviving crew crosses ON | 72/72 PASS | 72/72 PASS |
| Deciding 2c: the worst crew's rim ON <= 3 s | 3.9 s (green s10450 t8, Green_S_1) **FAIL** | 2.5 s PASS |
| Arrival guard (R42.7): paired per-run arrival ON <= OFF + 1.645 se | +0.87 s a run (line +1.05) PASS | +0.99 s a run (line +0.69) **FAIL** |
| reported: deck-jam seconds | 60.3 -> 73.3 | 62.0 -> 65.4 |

**The read (after the numbers):** as with v4, the fresh seeds have no rim failure to fix OFF (72/72 both trees, worst crew 1.8 s), so
a wait that fires only on a fast follower behind a slow leader still fires often enough (deck-jam seconds +22 % on the overrides tree)
to cost rim seconds and arrivals, and once rode the rim itself (3.9 s). The drill's own crew (rust s2 t15) is rescued every time;
the fresh seeds say the price of rescuing it is paid on every other crossing. **`deckwait` stays OFF** (v5 on `wip/manoeuvre-s5` as a
ref; v4 on main OFF); balance's Bar B2s v2 stays on today's bridge (R42.23 not reached). The next shape, if any, must fire on the
rim crew's own signature (ORCA's steer point carried PAST the deck's edge while the leader turns), not on the approach speed.
**Group-order guards (for the record, main v deckwait, 10461-10472 x 4 maps x crew, 48 paired runs, builder2,
`judge-group-deckwait.txt`): G5 all-in 72.0 -> 73.9 s (line 73.4) FAIL, G6 never-in 0.90 -> 0.90 PASS, G7 contacts 648,939 -> 673,640
(line 681,386) PASS; jam-seconds +2.1 %; the rule's counters a run: 24 waits, 606 queued crew-ticks, 1 time-out, longest 10.3 s
(the round-42 counters-line slip fixed on the side branch: `q3_judge.py --arm=deckwait` reads deckwait_*).** **Fight guards (for the
record, main v deckwait, locks / terminus / sumps x 10461-10466, 18 paired fights, builder0 light, `judge-fights-deckwait.txt`): G1
give-way deaths 55 -> 55 PASS, G2 stuck deaths 133 -> 127 PASS, G3 contacts 525,790 -> 553,692 (line 578,369) PASS, G4 kill share
worst move 0.004 / deaths 796 -> 785 PASS.** Series ended 05:13 PDT; the s5 worktree removed, s5m repointed at the round-44 scoping
candidate; raw group / fight logs removed (judges filed). **Bar S5 is closed: FAIL on the deciding lines, deckwait OFF.**

### Bar S5: FILED 2026-10-28 ~03:40 PDT, BEFORE any number on 10449-10472 (Bar Q6's lines, R42.7, unamended; the dev read of the drill's own seeds below)

- **The rule judged:** `--traffic-on=deckwait` **v5** as at 5a5e7b434 (on `wip/manoeuvre-s5` = fed356a8b + balance's v2 overrides
  8e257f3bc + d385cd308 + v5, and `wip/manoeuvre-s5-main` = fed356a8b + v5): v4's rule (a WHEELED crew with a friend ahead in its
  lane that is in a deck's mouth and not beyond the water lowers its speed wish to a following speed, never under 0.4 x top speed,
  5 s per friend then 6 s refused) that BEGINS a wait only on the carried-past case: me at >= 0.6 x top speed, the leader's speed
  away from me under 4 m/s. Both arms `--brains-off=native_drive` (the rule is inside the drive's mirror: GDScript both, as Bar Q6).
  No game/ or tests/ commit on the side branches until the series' end line.
- **What it could break (named first):** the same as Q6's: a slower approach at a mouth (the arrival guard; his 5-squad order on the
  two maps with decks: G5 / G6); a crew easing in a fight (G1-G4); contacts (G7); a fast follower refused its wait that then rides
  the rim (the fresh seeds' worst crew).
- **Deciding 1 (the hard line):** bridge-pooled 18/18 under the overrides ON (seeds 1-3 x ticks {1,8,15} x both sides): READ in dev
  read 1 below (18/18), re-run as part of the series on the frozen side tree.
- **Deciding 2 (`bridge_lab_table.py --q6`, each tree, main AND overrides):** pooled rim-seconds on fresh **10449-10460** x ticks
  {1,8,15} x both sides (72 runs an arm a tree) ON <= OFF; every surviving crew crosses ON; the worst crew's rim ON <= 3 s.
- **Arrival guard (R42.7), each tree:** paired per-run arrival ON <= OFF + 1.645 se over the 72 runs.
- **Group-order guards (R41.6's lines, `q3_judge.py --arm=deckwait`), 10461-10472 x crew, the overrides tree:** G5 all-in mean ARM <=
  BASE + 1.645 se; G6 never-in squads a run ARM <= BASE + 1.645 se; G7 friendly contact ticks ARM <= 1.05 x BASE.
- **Fight guards:** `manoeuvre-wedge-trace` locks / terminus / sumps x 10461-10466 (18 fights an arm), `follow_judge.py
  --on-arm=deckwait` G1-G4 (give-way deaths and stuck deaths ON - OFF <= max(2 paired se x n, 3); friendly contact ticks <= 1.10 x;
  kill share within 0.03 and deaths within 5 %).
- **Reported:** deck-jam seconds, mean arrival per tree, the rule's counters (deckwait_waits / _queued / _timeouts / _skipped).
- **Gate:** the side trees carry fed356a8b's code + v5 (one rule, 7 + 1 tests green with the drive twins on builder2); the frozen
  stream tree's full check (Bar S's gate) covers everything but v5's own lines, which its tests do. **Machine:** builder2 light for
  the drills and the group guards, builder0 light for the fights; `~/overnight-manoeuvre/r43/bars5.sh`, started by unit
  `manoeuvre-r43-bars5` after Bar S's series ends; evidence `~/overnight-manoeuvre/r43/bars5/`. A pass = R42.23's bridge re-read for
  balance next round (the orchestrator's call); a fail: OFF, no re-run on these seeds.
- **Dev read 1 (the drill's own seeds 1-3 under the overrides, builder2 light, GDScript, n 18 a cell, 5a5e7b434;
  `~/overnight-manoeuvre/r43/s5dev1/table.txt`):** OFF 17/18 (rust s2 t15 Rust_S_3 rim 5.1 s: R40.21's crew), **ON 18/18**, pooled
  rim 14.2 -> 7.8 s (-45 %), worst crew 0.9 s, **arrival 34.9 -> 34.8 s (paired -0.14 s a run, se 1.50)**: v4 cost +1.3 s a run
  here and capped every follower; v5's gate leaves the orderly ones alone. Deck jam 17.1 -> 21.4 s (reported). Every Q6 tree line
  PASS on the drill's seeds. Nothing on 10449+ read.

### S5 (the bridge crew, R42.15 / R42.23): deckwait v5 built on a SIDE branch while the stream is frozen (2026-10-28 ~03:00 PDT)

- `wip/manoeuvre-s5` (`../godot-manoeuvre-s5`) = fed356a8b + balance's v2 overrides (8e257f3bc, d385cd308 cherry-picked) + 5a5e7b434:
  **`--traffic-on=deckwait` v5 begins a wait ONLY on the carried-past case**: a follower arriving at >= DECKWAIT_FAST_SHARE (0.6) of
  its top speed behind a leader in the mouth whose speed away from it is under DECKWAIT_LEADER_SLOW_MPS (4 m/s); an orderly
  approach (a crew at a pace, or a leader through at speed) is left alone (`deckwait_skipped` counts the looks). Once begun, v4's
  cap, floor and 5 s cap stand. Test `test_v5_a_slow_arrival_behind_a_slow_leader_is_left_alone` + v4's 7; the deckwait, drive-twin
  and exec-state filters 19/0 on builder2 (native library ON). Dev read 1 (running): the drill's own seeds 1-3 x ticks {1,8,15} x
  both sides under the overrides, v5 ON v OFF (the OFF read is R40.21's 17/18: rust s2 t15 Rust_S_3 rim 5.1 s), builder2 light,
  `~/overnight-manoeuvre/r43/s5dev1/`. A Bar S5 (the hard line 18/18 ON + Bar Q6's fresh-seed lines on 10449-10460 x ticks x both
  sides, main and overrides trees, ON <= OFF and the worst crew <= 3 s; the arrival guard) is filed before any number on 10449+,
  after Bar S's series has the builders.

### FROZEN fed356a8b (2026-10-28 ~02:20 PDT): Bar S's tree; the gate check running on builder0; the series queued behind it

- **The tree:** fed356a8b = main 84f914f78 (CP43.0) + S2 (cf70440ac, c2e03f40e, bbca98093) + S3 / Bar S (fed356a8b). No game/ or
  tests/ commit until the series' end line (R40.13); docs on top.
- **The gate:** `make remote T=check` from `../godot-manoeuvre-b0` (a detached worktree at the hash; its own builder0 folder),
  systemd unit `manoeuvre-r43-check1`, log `~/overnight-manoeuvre/r43/check1/check.log` (read the `>> remote: make check exited N`
  line). **The series** (`~/overnight-manoeuvre/r43/bars.sh`) starts by itself from unit `manoeuvre-r43-bars`
  (`after_check.sh`: waits for the wrapper line, refuses a red gate, waits for builder2 to be free of full checks, then runs);
  progress in `~/overnight-manoeuvre/r43/launcher.txt` and `bars/meta.txt`; the judges land in `bars/judge-*.txt`.
- **Laptop runs by hand (native's note, 2026-10-28):** a Godot started by hand on the laptop runs the system atan2f, 1 ulp off the
  CORE-MATH `make` preloads, so my hand-run rebuilds (traceC / F / G) drift from his match after ~13 s; through `make` (the
  manoeuvre-start-trace target) or with `LD_PRELOAD` from `make -s trig-info` they would not. Builder runs are unaffected.

### Bar S: FILED 2026-10-28 ~01:30 PDT, BEFORE any number on 10401-10448 (C43.1, C43.4, C43.5, R43.6, R43.7, R43.14)

- **The rules judged, as four arms each removable alone, every switch on ONE frozen commit (named at the series' launch; R40.13:
  no game/ or tests/ commit until the end line), BASE = that commit with every round-43 rule off:**
  - **base** `--shape-latch=off` (today's main: the seat bound, the converge fix and kturngoal are off by default; the latch is on by
    default and is switched off here);
  - **seats** `--seat-bound=on` (+ the latch ON): C43.5's pair: a platoon's farthest seat within max(18 m, 1.5 hull lengths + the
    hull floor along) of its anchor, the shape scaled as a whole, never below the hull floor between two seats, halts and groups
    past a platoon as today; the transit's stations and its start the same (R43.7); a move keeps the shape it started with until it
    arrives or its task changes, one re-pick on the element's own contact after 1 s (R43.6);
  - **converge** `--shape-latch=off,--converge-on-crew=on`: a converging station starts ON its crew (its world point carried by the
    anchor's progress; today's rebuild from the route frame lands a hull's length off a crew behind a bent first leg) (R43.14);
  - **kturngoal** `--shape-latch=off,--traffic-on=kturngoal`: a reverse leg (the circle k-turn's, or the lattice planner's) ends when
    the goal it was planned for has moved 10 m or more to a point outside the forward turning circle and within 100 degrees of the
    nose; the forward drive takes the tick (S3; the GDScript drive while ON, as deckwait: C43.4, native twins before ON);
  - **all** `--seat-bound=on,--converge-on-crew=on,--traffic-on=kturngoal` (+ the latch): the shipping candidate.
  Every other switch at main's defaults; the native library ON for every arm (the drive is twinned; kturngoal's own switch runs the
  GDScript drive).
- **What each could break (named first):** the bound packs five crews' first turns into a tighter space (yield / blocked and k-turn
  seconds UP on a cramped deploy: crossing in the dev read); a kept shape that no longer fits the ground (never-in); a station on
  the crew that the shape's hand-off then has to pull back; a reverse leg ended early that then needs a second plan (k-turn count
  up, a crew driving at a goal inside its circle); the G1 v9 group column (his group click) must be untouched; contacts in fights.
- **Gate:** the frozen tree's full check green FIRST (C31.1), read from the wrapper line, on builder0 (or builder2 once camera's
  check is out: R43's machine note).
- **Workload (deciding), `make manoeuvre-bar-s`:** his first-order shape synthesised from the deploy (`tests/manoeuvre/start_trace.gd`
  header: the roster's first squad clicked, in the planning pause, 45 m toward the arena's centre + 25 m away from the army, the
  second squad at t56 to a point 23 m back toward the deploy and at t141 to one 17 m past the click; every click on the navmesh;
  `--squad-cap=4`, Gangs v Syndicate) on locks / terminus / crossing x seeds **10401-10424** = 72 cells an arm, 20 s each, the ten
  crews of squads 1-2 traced; one START_RUN row a run; `tests/manoeuvre/s_judge.py` paired per cell.
- **Deciding (each arm v base; the brief's lines):** **D1** crews seated within the bound 15 s after their order (the bound =
  `TacticsFormation.seat_bound` of their squad, a pure function of the hulls: the same yardstick in every arm) ARM mean > BASE by
  >= 2 se (paired per-run difference) AND pooled ARM > BASE; **D2** start-zone yield + blocked seconds (the ten crews, the 15 s after
  their order) ARM mean < BASE by >= 2 se AND pooled ARM < BASE. An arm SHIPS ON only if it passes both and every guard; the `all`
  arm is read first; an arm that passes alone while `all` fails ships alone (the orchestrator's ask: see which one does the work).
- **Per-arena guards (R43.14; each arena of the three, paired over its 24 seeds):** yield + blocked seconds ARM <= BASE + 2 se AND
  k-turn seconds ARM <= BASE + 2 se, for every arm that ships. Reported beside them: never-arrived crews, mean arrival (never = 15 s),
  wedged seconds, seat moves, per-cell rows.
- **Group-order guards (R41.6's lines, `q3_judge.py --base=base --arm=all`), 10425-10436:** orders' O1 probe crossing / locks / sumps /
  terminus x crew headings (48 paired runs): G5 all-in mean ARM <= BASE + 1.645 se, G6 never-in squads a run ARM <= BASE + 1.645 se,
  G7 friendly contact ticks ARM <= 1.05 x BASE.
- **G1 v9 corridor lines (C43.5), 10425-10436:** `make orders-probe` locks / crossing / terminus x 5 squads x click, base v all,
  `tests/control/orders_judge.py g1v8`: places outside the corridor, metres outside after, re-dealt places each ARM <= BASE (the
  g1v8 lines unamended) -- the group column is laid by halts, which the bound leaves alone (a test pins it).
- **Fight guards (`manoeuvre-wedge-trace` locks / terminus / sumps x 10437-10442, 18 fights an arm, `follow_judge.py --on-arm=all`):**
  G1-G4: give-way deaths and stuck deaths ON - OFF <= max(2 paired se x n, 3); friendly contact ticks <= 1.10 x; kill share within
  0.03 and deaths within 5 %.
- **Perf:** the frozen tree's check perf-judge stage PASS (the latch is the one rule ON there); for the switches, `make sim-profile`
  base v all on builder0 in a quiet window (`make remote-quiet`), us/tick ALL <= 1.05 x BASE for the arms that keep the native drive
  (seats, converge); kturngoal runs the GDScript drive by construction and is perf-judged after native's twin. No SCRIPT ERROR in
  any log of any part (s_judge counts them; a run with one fails the bar).
- **Dev history (C42.1; dev seeds 7001-7002 only; nothing on 10401+ read):** dev read 1 (7001, base v seats, before the converge fix
  and kturngoal): crews in bound 9 -> 16 of 30, yield+blocked 74 -> 95 s (crossing / terminus worse), k-turn 72 -> 90 s. Dev read 4
  (7001-7002 x 3 arenas, builder2, native ON, 6 paired cells an arm; `~/overnight-manoeuvre/r43/bars-dev/dev4`): **seats** D1 16 ->
  32 (+2.1 se), D2 162 -> 131 s (-1.2 se), k-turn 160 -> 78 s, never 13 -> 11; **converge** D1 16 -> 16, D2 162 -> 171 (+0.7 se),
  k-turn 160 -> 157 (alone it changes little: the stations still run to the unbounded seats); **kturngoal** D1 16 -> 21 (+1.5 se),
  D2 162 -> 96 s (-3.3 se), never 13 -> 4, k-turn 160 -> 97; **all** D1 16 -> 34 (+3.1 se), D2 162 -> 168 (+0.2 se: crossing 27 ->
  47 s a run, locks / terminus better), never 13 -> 8, k-turn 160 -> 66. The dev read says kturngoal passes D2 and the bound is the
  arm at risk on crossing (five War Rigs from one deploy row to seats within 37 m of each other give way to each other); the bar
  decides it per arena, unamended.
- **Machine:** the deciding runs and the group guards on builder2 (`REMOTE_HOST=slobdell@builder2 tools/remote.sh --light native
  manoeuvre-bar-s ...`, after camera's check is out), the fights and the G1 v9 probe on builder0's light lane from a second worktree
  at the frozen hash (`../godot-manoeuvre-b0`); `~/overnight-manoeuvre/r43/bars.sh` runs it; evidence `~/overnight-manoeuvre/r43/bars/`,
  filed under `references/round43/manoeuvre/bars-<machine>-<hash>/`. A fail on an arm: that arm stays OFF, no re-run on these seeds.

### WHERE IT STANDS (2026-10-28 ~00:30 PDT): S1 read, S2 built (seat bound + shape latch, R43.6 / R43.7), S3's cause found and its rule built, Bar S's workload built; nothing on bar seeds read

**Rulings taken:** R43.6 (the shape latch, GRANT: `ElementPlan.latch_shape` beside `chosen_formation`, `inset_anchor`; symmetric;
`--shape-latch=off`), R43.7 (the bounded centred shape at `route_seats` / `stations_along` / `Element._rank_file` under the same
`--seat-bound` switch; the latch lines in `element.gd`), R43.8 (engage owns Traffic's street hold: `_begin_wait`, `_spot_behind`,
`hold_of`; my traffic.gd hunks stay out of them). CP43.0 merged (f6b930a3d).

**S2 (C43.5), on the branch:** `--seat-bound=on` (TacticsFormation.SEAT_BOUND, OFF): a platoon's farthest seat within
max(18 m, 1.5 hull lengths + the hull floor along) of its anchor, the centred shape scaled as a whole, never below the hull floor
between two seats; halts (the G1 v9 column's squads), groups past a platoon and `"seat_bound": false` callers as today; the
transit's stations the same (R43.7). War Rigs' swarm 58 -> 37 m, Gun Trucks' 55 -> 18 m, the wedge / vee of War Rigs 29.3 m
untouched. **The shape latch** (ON, `--shape-latch=off`): a move keeps the shape it started with until it arrives or its task
changes; the element's own contact re-picks it once after 1 s; the CPU's elements too. Tests: `tests/test_formation_seat_bound.gd`
(8), `tests/test_formation_shape_latch.gd` (6); the tactics plan / formation / settle / converge filters 78/0 and 64/0 (laptop,
NATIVE=off). Commits cf70440ac, c2e03f40e, bbca98093.

**S2 re-read of his start (laptop, GDScript, `make manoeuvre-start-trace ST_RECORDING=<his> ST_FLAGS=--seat-bound=on`, bbca98093,
n 1 deterministic; `~/overnight-manoeuvre/r43/s1/traceG.log`):** the Guns' anchor is exactly his click (-69.1, 50.7) (the
inset shift is gone with the 37 m reach), no shape flip in 20 s (swarm throughout), every seat within 32 m of the click, ONE seat
move per crew (the station -> the seat): **all five arrive: Guns_4 5.2 s, Guns_5 (the Tanker) 6.7 s, Guns_2 7.7 s, Guns_1 7.8 s,
Guns_3 9.5 s** (his match: three of five in 5.5-8.4 s, two never); the Hunters' second click all five in 10.8-17.1 s (his: three).
Before R43.7 (the stations unbounded, traceF): War Rig 3's goal at 2 s was a station 70 m east, then a 150-degree k-turn in the
container alley with the Tanker backing up behind it; the lead War Rig stood 4 s "blocked terrain" at the wreck prop (-96, 62).
With the stations bounded the lead War Rig still k-turns 5.3 s near its seat (S3's family) but arrives.

**S3: the start-zone jam's remaining head is the War Rig's FIRST-TICK K-TURN** (`~/overnight-manoeuvre/r43/s1/kturn1.log`, terminus
7001, `--turn-trace=Green_Guns_1`, builder2): at a move's first tick the crew's goal is the transit's converging STATION, which on
terminus / crossing sits 7.5 m from the hull at 110 degrees off its nose (inside the 12 m turning circle; on Locks the first
station is ON the crew, as `ElementPlan.converge` intends; on terminus / crossing it lands right-behind, the first route leg bent,
I think: ElementPlan's, not granted, reported), so `_planned_reverse` plans a circle k-turn (back 7.5 m, away 4.5 m) and commits;
at f50 the station is 30 m away, at f55 45 m (a forward arc reaches it), and the leg backs its 7.5 m at 2.8 m/s into the arena's
north edge regardless ("blocked terrain"), the squadmates asking it to give way meanwhile. His Guns_2's 3.6 s "crept north" on
Locks is the same. **The rule (built, OFF: `--traffic-on=kturngoal`, Traffic.DEFAULT_OFF; the GDScript drive while ON, as
deckwait, C43.4): a REVERSE leg ends when its planned goal has moved KTURN_GOAL_MOVED_M (10 m) or more to a point outside the
forward turning circle and within 100 degrees of the nose; the forward drive takes the tick.** The planned goal lives in a
`Manoeuvre` static keyed by the mover's instance id (trip-up 84: no exec field); counter `kturn_goal_moved`. Test
`tests/test_manoeuvre_kturn_goal.gd` (3; running on builder2 with the drive twins as this is written).

**Bar S (S4): the workload and judge are built, nothing on bar seeds read.** `make manoeuvre-bar-s` = `tests/manoeuvre/start_trace.gd`
with no recording: his first-order shape synthesised from the deploy (squad 1 clicked 45 m toward the arena's centre + 25 m
away from the rest of the army, in the planning pause; squad 2 at t56 to a point 23 m back toward the deploy, at t141 to one
17 m past the click; `--squad-cap=4`, Gangs v Syndicate), one START_RUN row a run, `tests/manoeuvre/s_judge.py` (the brief's D1 /
D2, paired per cell). **Dev read 1 (builder2 light, GDScript, 7001 x locks / terminus / crossing, base v bound+latch, n 3 cells,
`~/overnight-manoeuvre/r43/bars-dev/dev1-7001`):** crews within the bound by 15 s 9 -> 16 (of 30), seat moves 117 -> 45, mean
arrival 35.8 -> 33.0 s pooled, BUT yield+blocked s 73.8 -> 95.0 (locks 21 -> 12, crossing 15 -> 32, terminus 37 -> 50) and k-turn s
72 -> 90: the bound packs five first-tick k-turns (above) into a tighter space. The bar is filed only once the kturngoal arm has
been read on the same dev cells (the brief's order: S3 before S4); its arms will be base / seats (bound+latch) / kturngoal / all,
each removable alone (the orchestrator's ask), on 10401-10424 x locks / terminus / crossing; guards on 10425-10448.

**Requests / notes for other streams:** (a) ElementPlan.converge's first station off the crew on terminus / crossing (above):
numbers on request. (b) engage's R43.8 street hold is the same Guns-waits-for-Hunters interaction as his start jam; nothing of
mine touches `_begin_wait` / `_spot_behind` / `hold_of`. (c) native: `kturngoal` needs a twin before ON (the k-turn leg end in
`_planned_reverse`); the seat bound and the latch are planner-side (no Movement member) and run with native_drive ON.

### S1 REPORT: the arrival census of his first order (2026-10-27 ~22:30 PDT; laptop, 847e569cf, the rebuild of his Locks 56416 start)

**How it was read.** `tests/manoeuvre/start_trace.gd` (`make manoeuvre-start-trace`) restarts his match (seed 56416, Locks, Gangs v
Syndicate, `--squad-cap=4`: his laptop's four squads of five; the arena and seed on the REAL command line, R43.1), issues his orders
at their ticks (the tick-0 one inside the planning pause) and prints every traced crew's mover and seat per tick. **Fidelity (START_GAP,
laptop, GDScript drive): all ten Guns / Hunters crews within 0.1 m of his census for the first 10 s, within 2 m to 13 s, the same phases
at the same seconds (Guns_3 yielding to Hunters_1 at 7-8 s, to Hunters_4 at 13-14 s as in his census).** Before R43.1 the replay ran on
the default map with 46 units; that, not the mover, was "his Guns jam, the replay's drive off". Logs: `~/overnight-manoeuvre/r43/s1/`
(traceC = the rebuild; traceE = `--anchor-inset=off`; trace41 = the round-41 recording on today's code, which diverges at 3-4 s there).

**The three answers, with the mechanism (every seat below is the element's issued order `to`, read off START_SEAT / START_ROW):**

1. **Why the lead War Rig seats 29 m from his click, and two crews 60-70 m from it: the squad's travel shape is the Gangs doctrine's
   SWARM, laid round a point 15 m off his click.** `doctrines/doctrine_gangs.json` "movement": every row but `threat: likely` (a VEE)
   is a swarm ("hunting, in no particular order" is its default row), and `TacticsFormation.offset("swarm")` lays rank 1 at
   +-SWARM_SPREAD (1.9) x pitch across the heading and rank 2 at twice that, staggered +-0.8 / 1.6 pitch along. The Guns' pitch is
   (14.7, 16.0): the War Rig's 14.0 x 3.32 m hull floors both axes (across = the dressing diagonal 14.39 + 0.3; along = 14 + 2), so
   the swarm is **112 m wide**: slots at (0, -25.6), (-27.9, 0), (+27.9, +25.6), (-55.8, -12.8), (+55.8, +12.8) m; farthest seat 58 m.
   Then `ElementPlan.inset_anchor` (overnight item 3, `--anchor-inset=off`) moves the destination inland until the shape's 58 m reach
   disc fits the arena's clamp polygon: his click (-69.1, 50.7) became the anchor **(-56.1, 43.2)** (traceE with the inset off: the
   anchor is exactly his click). Seats as issued at tick 1 (click (-69.1, 50.7)): **Guns_1 War Rig #3 (-97.4, 50.4) = 28.3 m W** (his
   "29 m"), Guns_2 War Rig #0 (-68.8, 21.0) = 29.7 m S, **Guns_3 War Rig #4 (-1.3, 26.7) = 72 m E**, Guns_4 Gun Truck #1 (-80.4, 57.1)
   = 13 m W, **Guns_5 Tanker #2 (-6.2, 51.6) = 63 m E**. The VEE the squad flips to (below) at the hull-floored pitch has its rear
   corners at 2 x 13.2 across + 12.8 along = **29.3 m** from the click (Guns_1's vee seat (-98.4, 52.7)): with a 14 m hull a five-crew
   wedge / vee cannot be tighter than that without the hulls clipping as they turn (C38's floors), so 29 m is the War Rig's physics;
   the 60-70 m seats and the 15 m anchor shift are the swarm's.
2. **Why War Rig 3 yields 20 s to the Hunters: its seat was 72 m EAST, through the Hunters' deploy row, and the squad's shape flipped
   swarm / vee / swarm / vee / swarm (t251, 278, 350, 437) as the planner's threat reading changed, moving its seat 50-95 m each
   time; it never left a 5 m circle at (-32, 74) in 16 s.** Trace: t30-90 drives SE at 7 m/s toward (-1.3, 26.7) through the Hunters
   (Hunters_1-5 parked at x -21..-8, z 89-95, then ordered west at t56); t105-180 ORCA-deflected by Hunters_1 driving west across its
   nose, speed 1.7 -> -1.0 -> 0.6 m/s, stall 1.6 s; **t184 Hunters_1 (pinned behind it, seat (-69.8, 60.8) west) asks it via "pinned";
   its answer is a HOLD (no spot fits a 14 m hull: room_ahead 0, room_behind 40 on START_YIELD), so it stands across Hunters_1's lane
   for the full 6 s (YIELD_MAX_SECONDS, t184-250) while Hunters_1 stands at (-31.7, 79.1) t142-300 pushing at it**; t251 seat ->
   vee #0 (-59.6, 67.4) WEST; t278 -> swarm #2 (1.9, 51.6) EAST (drives east at 10-11 m/s t300-330); t350 -> vee #0 (-56.5, 66.5)
   WEST (pace 0.35); t368-405 yields to Hunters_4 (pinned, short:back(10), reverses 2 m); t407 seat (-60.3, 39.5), t437 (-45.9, 69.5),
   t446 his attack-move (-83.6, -18.4); wedged from t420. **The stalled head is War Rig 3 itself, across the Hunters' lane; what it
   waits on is a seat that moves 50 m every few seconds and a give-way that can only hold.** Hunters_4 (seat (-27.2, 14.5): 67 m S of
   its click; then (-45.8, 19.1)) k-turns at (-20, 64) t204-268, wedged from t300, stands at (-22, 68) t330-480 behind War Rig 3 (his
   census: `blocked Guns_3`). Hunters_1 arrives only at t415 (12 s after its second click).
3. **Why the Tanker never arrives: its seat was 63 m EAST of his click (swarm #2), and stayed east.** It drives east along z 83-85
   (the warehouses' north side) at 5-9 m/s t120-250 toward (-6.2, 51.6); t251 seat -> vee #4 (-53.4, 26.5) west (82 m of route);
   t278 -> swarm #4 (-1.3, 26.7) east again; t330-350 at (-6, 55) 11 m/s; t350 seat -> (-53.3, 40.9) west: k-turn at (-6, 51)
   t350-390. It was never routed "round the warehouses" to the click: every seat it had but two was on the far side of them. Killed
   t404 (his recording's `dead` row: Rust_Guns_2).

Guns_2 (seat 30 m S of the click, toward the canal) k-turned in place 3.6 s (t20-127, reversing north 3.5 m: his census's "crept
north"), arrived t251 and was the first loss (t348, Rust_Guns_3). Guns_1 and Guns_4 drove straight to their west seats (8.2 s / 5.5 s).

| crew (his first order, Locks 56416, click (-69.1, 50.7)) | first seat | from click | seat moves (max) | arrived | nearest to click | yielding s | k-turn s |
|---|---|---|---|---|---|---|---|
| Guns_1 War Rig | swarm #3 (-97.4, 50.4) | 28.3 m W | 3 (50 m) | 8.2 s | 15.4 m | 0 | 0 |
| Guns_2 War Rig | swarm #0 (-68.8, 21.0) | 29.7 m S | 2 (29 m) | 8.4 s | 10.1 m | 0 | 3.6 |
| Guns_3 War Rig | swarm #4 (-1.3, 26.7) | 71.9 m E | 6 (96 m) | never | 41.3 m | 3.5 (+ 1.2 hold) | 0 |
| Guns_4 Gun Truck | swarm #1 (-80.4, 57.1) | 13.0 m W | 3 (36 m) | 5.5 s | 7.6 m | 1.1 | 0 |
| Guns_5 Tanker | swarm #2 (-6.2, 51.6) | 62.9 m E | 3 (54 m) | never | 48.6 m | 0 | 1.8 |
| Hunters (t56 click (-60.7, 72.5); t141 (-86.1, 55.6)) | swarm: _1 15 m, _2 61 m E, _3 43 m N, _4 67 m S, _5 20 m | | 4-9 each | _5 11 s, _1 12 s, _3 arrived; _2 / _4 never | | | _4 2.1 |

(laptop, 847e569cf on main 2f1620a77, GDScript drive, one run each: the rebuild is deterministic, and his census agrees with it.)

**Round 41's recording (Locks 49326; his four squads ordered at tick 0, the Guns with a queued SCREEN):** on today's code the rebuild
diverges at 3-4 s (native: it was played on 21b20bdce; native replays it on that tree), so only the tick-1 seats are a read: EVERY
squad's first move is a swarm, Hunters_2's seat (-52.0, 37.3) is 65 m S of a click on the north edge (-58.4, 102.2), Hunters_3's
(-63.8, 117.2) 15 m N of it, Spears_4's (-25.9, 20.0) 75 m S of (-44.8, 95.4), Spears2_4 / _5 east: four swarms 100 m wide laid
over each other across the deploy zone is the round-41 start jam (his census: Hunters_2 yielding Hunters_3 2-5 s, Hunters_3 yielding
Guns_3, Guns_2 blocked by Hunters_1 at 4 s).

**What this says for the backlog (my reading, the orchestrator rules on the owners):**
- **S2 (C43.5, mine):** a bound on the farthest seat in `TacticsFormation.place` caps the swarm (58 -> ~37 m for War Rigs, ~18 m
  for Gun Trucks) and with it `inset_anchor`'s shift (a 37 m reach disc at his click clamps nothing: the anchor stays on the click).
  The wedge / vee of five War Rigs stays at 29 m: the hull floor. Building it OFF behind `--seat-bound=on`, test first.
- **Not mine, ruling asked (R43.x):** (a) the travel shape of a PLAYER's move order flapping between the doctrine's swarm and vee on
  the threat reading (`ElementPlan` + `doctrine_gangs.json`'s movement rows): every flip re-seats the squad 50 m; a latch (keep the
  shape a move started with until it arrives or he re-orders) would end the E/W/E/W of Guns_3 and the Tanker. (b) Whether a swarm is
  the right travel shape under his move at all (the doctrine's "they spread wider than anyone"): the bound keeps its raggedness at a
  reach he can read as "at my click".
- **S3:** the jam's head is a crew sent through another squad's deploy row to a seat 70 m past the click, holding in place when asked
  (no spot fits a 14 m hull). After S2 the start is re-read on the same recording; what remains names the rule.

