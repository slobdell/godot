# Stream: native (the game stays fast as rules ship; every ON rule has its C++ twin)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 351), `_agents/judging.md`, `_agents/workstreams.md` **Round 47**
> (C47.1-C47.11; C47.6 is yours; C47.4's reader is yours), your last brief `streams/archive/round46/native.md` (FINAL REPORT), R46.16.
> **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`,
> `tools/loaded.sh`, `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tools/builder_checks.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe, `mk/gcp.mk`, `_agents/judging.md`, `tests/replay_orders.gd`,
> `tools/recording_arrivals.py`, `tools/playtest_report*`, `tests/replay/**`; GRANT the C++ seams in `game/control/**`, `game/ai/tank_brain.gd`'s
> native call site, and the native call site of `ElementPlan.build` / `ElementSituation.build` (R46.16), each GDScript body kept as the
> fallback. **Model:** Opus. **Machine:** builder3; builder0 for perf-judge lines set there (quiet window). **Seeds:** the owner's.

## The lead's direction

Memory: native code is C++ (core components in C++ long-term, even without a gain); the laptop is the test bed (UHD 620). His asks
this round are the other streams'; native makes them fast and proves the C++ path plays the same game.

## Where things stand (main fccfaadea; code e306ce27f GREEN builder3 3518/0, 28 ALL JUDGED)

- **R46.16 (probe/native-elements 9145cc82a, builder3 light, his Terminus 149 s, native ON, n 1, tick 12.24 ms):** elements 2.67 ms;
  ElementPlan.build 1.06 ms a tick (0.46 a call; ~3 ms on his laptop), ElementSituation.build 0.55, grounding 0.32, take/issue 0.32,
  corridor/transit/crossing 0.25. Round 47: ElementPlan.build to C++, then build_situation.
- This round's rules that will need twins (C47.6): manoeuvre's no-progress watchdog (drive), route's cost change if the planner's cost
  runs in C++, engage's fire fix if it touches the brain's scoring, orders' if a seam moves.
- Recordings carry `sel` and the `rules` stamp; orders adds `inp` (C47.4) for you to read in `playtest_report`.

## Backlog (in order)

1. **N1 twins as bars are filed** (C47.6), in the order they arrive; EQUAL on the frozen bar tree, reported to the owner and the
   orchestrator the same hour. A twin is a bar's gate: it outranks everything below when a bar waits on it.
2. **N2 ElementPlan.build in C++** (R46.16): agree the seam with its owners through the orchestrator (element_plan's functions are
   engage's / manoeuvre's / route's by function); output-identical first (a decide-style twin proof over his four recordings), then
   judged on the box the line is set on.
3. **N3 `inp` rows in `playtest_report`** the hour orders' C47.4 lands: a "selection changed by" column; re-read Sumps 601-618.
4. **N4 ElementSituation.build in C++** (build_situation 1.51 ms with contacts), same method.
5. **N5 judging lines:** `lines_r47.py` as verdicts land; re-render the table at the close.
6. **N6 builders:** keep builder3 healthy (disk, cold-import watchdog, the full-check lock); seven streams share it this round, so
   watch the queue and tell the orchestrator if a check waits > 30 min.

## Don't touch

Every GDScript body behind your seams (the owner's), `game/camera/**`, `arenas/**`, `game/ui/**`, `tests/baselines/**`.

## How to verify

`make remote T=check` on builder3 (read `>> remote: make check exited <N>` and `N passed, M failed`, never an exit code through a
pipe); `make quick-remote` to iterate (`QUICK_BASE=<your last green>`); `make replay-match RECORDING=...` and `make playtest-report
RECORDING=...` on his four recordings; screenshots at desktop and phone aspect, looked at. Every number with its commit, machine,
workload and n. **No local Godot runs** except a lock-held laptop budget read (C47.1: seven sessions on a 7 GB laptop).

## Waiting on the lead

Nothing at launch. If a bar fails, write in player terms what he would see ON v OFF and message the orchestrator the same hour.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**REPORT (2026-10-31 ~02:30 PDT) — the yield-cycle flake (the orchestrator's ask; GRANT tests/test_manoeuvre_noprogress.gd).**
test_cpu_ambush_squad_does_not_sit_in_a_yield_cycle red in mapkit's check of 8dc9697b4 (shard 4/7), green elsewhere. **Not load,
not wall time, not native: the lab is deterministic per PROCESS HISTORY, and this case sits on a knife edge.** All builder3 light,
155a8fc0e's tree (main c9e6520b3), `make native-repeat` (new: FILTER x REPEAT_N, FILTERS=a;b;c one run each, REPEAT_JITTER=on):
- Alone, 10 / 10 identical (Hunters_2 leaves at tick 204-205 of the 300 allowed), native ON; the same with NATIVE=off.
- After the failing shard's 49 preceding files (taken from mapkit's build/check/logs/test.log): red 3 / 3, mapkit's numbers to the
  digit (Hunters_2 / Hunters_4 never within 8 m). Bisected: test_manoeuvre_face_settle (its 5 tests together, no one alone) is
  enough; other files move Hunters_2's tick 204-208. Start tick 1, nav wait 1-2 frames in every history (CYCLE_START), so not
  the lab's start. By tick 30 the same decisions sit a few cm apart: the physics, as roadmap's UNOWNED "a same-process rematch
  is not deterministic" (round 33: Jolt settles a hull differently after earlier matches; a fresh World3D does not reset it).
- Robustness, fresh processes, start poses moved <= 1 cm / 0.1 deg (CYCLE_JITTER=1..20): **19 / 20 green, seed 19 red** with the
  same signature; NATIVE=off run for run identical (same seed red, same ticks).
- So it is the GAME: the sliver fix holds for ~95 % of starts; a centimetre (or any history) puts Hunters_2 / 4 back on the sliver
  for the whole 15 s. Not fixed here (manoeuvre's rule). Next round: manoeuvre makes the leave robust, bar = CYCLE_JITTER 1..20
  all leave (`make native-repeat FILTER=test_manoeuvre_noprogress::test_cpu REPEAT_N=20 REPEAT_JITTER=on YIELD_CYCLE=on`); and the
  process-history physics state (netplay / replays in one process) stays UNOWNED in roadmap.md.
- **R47.47: the test is PENDING** (YIELD_CYCLE=on runs it; it prints the reason otherwise): it guards the watchdog, OFF in his
  game, and a shard-order red would gate every stream's check. The assertion is unchanged.

**FINAL REPORT (DRAFT, 2026-10-30 ~23:00 PDT; final once e5fa1f1be's check is named). On main: 6f19722ae (GREEN, 3523 / 0,
29 ALL JUDGED, sim-baseline unmoved) and 27ea82fa5 (merged as 8d37b9796 with route_doors.gd's stub-order fix 94646bf63). Candidate:
e5fa1f1be (full check queued, builder3): + test_match_shell_dropped_peer's flake fix, E3's pot_shot_halts line (02f308371, a no-op
until engage's GDScript), test_native_gun's E3 floor, lines_r47 (25 lines: Bars K, E7, M), main 8d37b9796.**
In his terms: his game plays the same bit for bit, with three more of its core pieces in C++ (formation seats, the squad's view
of its crews and contacts, the matchups); every rule the other streams shipped ON this round that touches the brain, the gun or the
drive runs the same in C++ (E7 his attack beats RETREAT, E3 snap shots, holdyield); blast doors and sight screens work on the C++
path too; his own garage fights can be replayed again, and his replays know which rules his build ran.
**Backlog:** N1 DONE as filed (E7 + Amendment 1, E3 + its halting guard, holdyield, E2a dropped by R47.17, Bar M none);
N2 DONE (place ON); N3 DONE (reader; the Sumps re-read waits on a recording with inp rows); N4 DONE (esit ON); N5 lines_r47 up to
date with every round-47 verdict filed; N6 DONE (seed, .remote-synced, Xorg DISPLAY, the queue watched).
Plus: N0 (R47.8) cause 1 fixed, the limit stated (R47.16); C47.8 doors and R47.36 the eye mask in C++; R47.27 (a) matchups ON / scan
OFF, (b) parked with a next-round note; R47.31 / 34 the fog split, dropped; the measured laptop ratio ~3.0x builder3.
**Next round:** contact_prototypes in C++; R47.18 the layout's bake timing; cause 2 of the replay parting with inp rows; E9's twin
(engage's fire-lane pre-check) when it files.

**REPORT (2026-10-30 ~22:00 PDT) — the round so far, in one place.**
**Green / merge:** 6f19722ae GREEN builder3 (`make check exited 0`, 3523 / 0, 29 ALL JUDGED, sim-baseline unmoved on all 13 maps;
named for merge). Next candidate: **27ea82fa5** (= + C47.8 door mask + R47.36 eye mask + main 79cea77e5), its check queued on
builder3; named when green.
**Done (every number: commit, machine, workload, n above in the dated reports):**
- N1 twins: E7 (+ Amendment 1) EQUAL, E3 pot shot EQUAL, holdyield EQUAL, E2a EQUAL then dropped (R47.17), Bar M needs none.
- N2 TacticsFormation.place in C++ ON; N4 ElementSituation.build's loops in C++ ON; both VERIFY-guarded in check.
- N3 the inp reader (playtest-report section (d)); N5 lines_r47 started (no round-47 verdict filed yet); N6 builders: the seed,
  .remote-synced, the Xorg DISPLAY, the queue watched.
- N0 (R47.8): cause 1 fixed (his ctrl+N groups), Sumps / Parade replay again (garage armies rebuilt), the rules stamp carries
  every rule; cause 2 = the limit (R47.16: exact to ~11 s), the laptop itself ruled out; R47.18 (the layout's bake timing) next round.
- R47.27: matchups ON (neutral), scan OFF (slower); (b) parked (no lump: shared memos + glue); R47.31 / 34: the fog field's
  split (sim small; the lever is ~2.1 ms of UI not in the granted readers) — dropped; the laptop ratio ~3.0x builder3 (measured).
- C47.8 the doors in the native drive's route query; R47.36 the eye mask in every C++ eye ray.
**Questions for the lead:** none open.
**Requests to other streams:** engage / manoeuvre: change ElementSituation.build's two loops, TacticsFormation.place's body, or
Lay / _obey / the pot shot / _holdyield_veto only through native (each is twin-frozen, and check's VERIFY or twin test goes red).
**Known issues:** replays of his round-46 matches part at ~11 s (cause 2: an unrecorded live input; orders' inp row widened);
place / esit prices were neutral, not faster, at this army size.
**What to playtest:** nothing new on screen from native. Re-read a match: `make playtest-report RECORDING=<his>.jsonl` (section
(d) shows what changed each selection once his recordings carry inp rows); `make replay-match RECORDING=... CREWS=all` (garage
fights replay too now).
**Next steps:** contact_prototypes' rebuild in C++ (~0.7 ms a frame on his laptop at the cost cap); R47.18 the layout's bake timing;
the Sumps 601-618 re-read with inp rows.
**Merge notes (shared files):** mk/core.mk (replay-pytest in check), game/tactics/tactics_formation.gd (place's seam line),
game/tactics/element_situation.gd (build -> _entries refactor + seam), game/ai/brain_switches.gd (native_place / native_esit /
native_matchups), game/match/match.gd + visibility_field.gd (eye mask; visfield_draw measurement flag), tests/replay_orders.gd +
tests/replay/** (loose squads, garage armies, rules), tests/test_match_recorder_replay_keys.gd.

**REPORT (2026-10-30 ~21:00 PDT). Merge candidate: 6f19722ae (still queued on builder3). Since (merged main 5eee3a06d: route's
RouteDoors, mapkit's doors / sight class):**
- **C47.8 doors in the native route queries DONE (11fb972a0):** Pathing's own find_path / query already step aside from native while
  RouteDoors.any(); the gap was the native drive's re-plan (drive_native path_query): with a door registered it hands the query
  to Pathing.query (RouteDoors.mask), no doors = the native query, byte-identical. test_native_doors (route's stand-in link on Locks,
  5 crossings x no door / open / shut / off) 20 / 0, 10 through the door; drive + pathing twins 19 / 0 (builder3 light). A static
  Ref<Script> there segfaulted every drive twin at exit (139): scripts are looked up by ObjectID now.
- **R47.36 the eye mask DONE (171aa75be):** eye_mask.h (Perception.eye_mask(), ArenaKit.sight_on read live) in perception_native's
  sight + gun-ready passes, the gun's line of sight, TankNative.line_of_sight; Match._clear_view and VisibilityField's rays ask
  Perception.eye_mask() (granted). test_native_eye_mask on mapkit's screen fixture 400 / 0, 139 blinded; 18 / 0 with perception,
  gun, scan, visibility, sight_screens. No shipped map has a screen.

**REPORT (2026-10-30 ~20:45 PDT). Merge candidate: 6f19722ae (full check queued on builder3). 46c3b2f3b was RED (two tests of
mine: the rules stamp's expected keys; test_native_place asking 'single' of two vehicles) and found a real place bug, fixed: the C++
laid echelon_left's slot 0 at -0.0 where GDScript lays +0.0 (test_native_place 4000 / 0 since; its message now names the field).**
- **holdyield twin EQUAL (R47.30, Bar H):** pair/native-holdyield 0d1bc6690 = manoeuvre df26c0d5f + cbc49c2d5 + the _chain_native
  gate without holdyield: builder3 light 40 / 0; MEASURE native_holdyield 6000 compared, 2918 vetoed, 0 mismatches.
- **E3 pot-shot twin EQUAL (R47.20):** pair/native-e3 3c4a3b576: 41 / 0, 8223 applies, 4 pot shots, 0 mismatches.
- **R47.27 (b) PARKED (the orchestrator's rule: callbacks < 0.2 ms a tick). NEXT-ROUND NOTE: no lump left in the brain's tick;
  the time is shared memos + GDScript glue.** Cost cap (gangs v syndicate 3500, Crossing, seed 3, builder3 light, n 1; probe
  probe/native-sitcb47, not merged): the think prologue is flat (t.poll 0.40 = squad 0.14 + order 0.11 + element 0.08 + station
  0.07, 29 polls a tick at 1-5 us; rate_progress 0.26; incoming 0.18): a C++ prologue would call the same GDScript back.
  build_situation 1.0-1.2 ms a tick at 5.6 calls: its s.contacts lap is ALREADY native (situation_core); its callbacks
  (AiTickCache.faced_by / _faces_someone_else) never fire here and CoverMap.clear_line_coarse is ~0.001 ms; the lap's GDScript
  prep is AiTickCache.contact_prototypes 0.156 ms (both teams' tables rebuilt each intel refresh), allies 0.086, intel_names 0.012;
  s.tactics / s.squad / s.cover_* / s.incoming are thin calls into shared code (SquadTactics, native_tq, native_incoming). The
  candidate for a next round: contact_prototypes' rebuild in C++ (~0.1 ms a tick builder3, ~0.7 ms a frame on his laptop).
- **R47.27 (a) DONE:** native_matchups ON (neutral, ABBA n 4 at ~46 crews); native_scan stays OFF (+0.5 ms a tick, both pairs).
  (b) the think prologue port: not started (after the readers, R47.34).
- **R47.31 / R47.34 the fog field:** sim side small (builder3 0.18 ms a tick, rays 0.155; laptop in-run 0.17 ms a tick); the
  laptop read (UHD 620, lock, his Crossing 101, orders' cost-cap code, n 2 a layer): no_visfield -9.29 ms a frame = -2.11 ms of UI
  + -0.17 ms a tick, x the amplifier; the fog sheet + shader hidden: nothing (+0.11). The C++ ray walk is HELD; the lever is the
  GDScript readers of the field (radar ~0.5, camera vision ~0.46, edge markers ~0.1 a frame), GRANTED to native (R47.34) after
  6f19722ae merges: an 8 s x 3 read per reader, then each cached / batched / C++, output-identical. Measurement-only switch
  `--sim-off=visfield_draw` (1591bb222).

**REPORT (2026-10-30 ~20:00 PDT). Merge candidate: 46c3b2f3b (full check queued on builder3, synced; a79fc79cb is VOID: it
carried two parse errors of my tests, its check cancelled).** After it: 7571efb20 (native_esit ON) rides on the next check.
- **N4 ElementSituation.build DONE, ON (7571efb20):** the member + intel-contact loops in C++ (esit_native.cpp, NativeEsit; the
  loops moved verbatim into ElementSituation._entries, the reference; R47.19: frozen by the twin, changes through native).
  EQUAL: test_native_esit 200 / 0 (111 with contacts); his four replays under TANK_NATIVE_ESIT_VERIFY=1 (builder3 light,
  46c3b2f3b): Crossing 6500+, Locks 5500+, Sumps 7500+, Parade 6000+ calls, 0 mismatches; check's native-verify-scenarios verifies
  it. Price: his Crossing 112 s, ABBA n 3, placed 0, builder3 light: elements ON 2.869 / 1.884 / 1.790 v OFF 2.962 / 2.992 / 1.692
  ms a tick: clean pairs -0.09 / +0.10, the middle pair confounded by the box's load (tick 10.9 -> 6.9): **neutral**, under my
  0.2-0.3 estimate. ON by the ruling (core components in C++).
- **E7 Amendment 1 twin EQUAL:** pair/native-e7 aa339ab80 = engage 43ed628f1 + c2ddd51fb (o.his_side): 9 / 0, 7521 decisions / 0,
  27 pressed. Engage freezes on it.
- **E3 pot-shot twin EQUAL (R47.20, his yes):** pair/native-e3 3c4a3b576 = engage d4a88c4a5 + e232fce63 (+ the test floor): gun_native's
  apply_weapon runs engage's block after engage() (POT_SHOT read live off the Gunnery script; NativeGun + NativeExec owned share it).
  builder3 light: 41 / 0; native gun 8223 applies, 4 pot shots fired, every off-aim compared, 0 mismatches.
- **R47.26/R47.27 the cost cap (his laptop 8-12 fps):** cost-cap Crossing profile (gangs v syndicate 3500, 34 v 12, seed 3, 90 s,
  builder3 light, n 1): tick 7.43 ms at ~46 crews; per-crew costs: brain/think 3.16 (situation 1.00, poll+rate+incoming 0.84),
  brain/execute 2.57, tank 0.76 (+ wall_contact 0.31). **Measured laptop ratio ~3.0x builder3** (his Crossing .perf tick_ms 17.0
  mean v builder3's replay 5.5-5.9). Frame model F = R / (1 - T/33.3) fits orders' read (79 ms, 2.4 ticks a frame); a cap of 2 ticks
  a frame -> ~71 ms, clock 0.94 (ruled: no change). **(a) prices, same workload, ABBA n 2:** native_scan ON +0.48 / +0.52 ms a tick:
  SLOWER, stays OFF; native_matchups: one pair confounded by the box's load, the clean one neutral (decide +0.003): second ABBA running.
  (b) t.poll's prologue port: next (it is TankBrain.think's whole prologue; a large twin).
- **Backlog:** N1 twins as filed (E7 + E3 done; route's door mask when doors reach an arena); N2 DONE; N3 reader DONE (the Sumps re-read
  waits on orders' inp rows); N4 DONE; N5 lines_r47 started (no verdict yet); N6 builders healthy (builder3 29 %; builder0 down
  since ~17:35, the orchestrator told the lead).

**REPORT (2026-10-30 ~19:15 PDT). Merge candidate: a79fc79cb (full check queued on builder3: mapkit / manoeuvre / route / me /
orders; nothing stale in the queue, N6).** Since: 00147f9a5 (remote.sh protects .remote-synced), 6fcf33ccd (native_place ON),
131823cff (lines_r47), the E7 twin commits (no-op on main), docs. The next candidate = the tip after a79fc79cb goes green.
- **N2 place twin DONE, ON (6fcf33ccd):** EQUAL on 4000 random elements x every switch and on every place() of his four recordings
  (TANK_NATIVE_PLACE_VERIFY=1, builder3 light, a79fc79cb: Crossing 11000+, Locks 7000+, Sumps 12000+, Parade 8000+, 0 mismatches);
  check's native-verify-scenarios verifies every AI scenario's place() both ways from now on. **Price:** his Crossing 112 s,
  --sim-profile, builder3 light, a79fc79cb, ABBA n 3 a side, every run REPLAY_SPAWN placed 0: elements ON 1.742 / 1.436 / 1.427 v OFF
  1.709 / 1.684 / 1.616 ms a tick (paired -0.14 ms, se 0.09, ~8 % of elements); tick -0.14 ms (se 0.33, the box loaded by other
  checks). Faster or neutral -> ON (the orchestrator's ruling; core components in C++). The one ON run that parted (placed 37/37)
  was a mis-start of the harness (R47.18), not place().
- **E7 twin EQUAL (engage's simplified spec):** pair/native-e7 19a38a505 = engage 087d1732a + stream/native 6c757c990 / 7c6ea847e /
  e4d00c6fb / d6d363ffe: decide_native's obey drops RETREAT for an attack_move under an `attack` element task when TankBrain.PRESS_ON
  (read live; absent = off). builder3 light, native ON: 46 / 0; native decide 7521 decisions / 0 mismatches, 30 RETREATs pressed.
- **E2a twin:** built and EQUAL (8189 gun applies, 29 carried, 0 mismatches) then DROPPED with E2a (R47.17); reverted (afab6fb7e).
- **Bar M:** no twin (confirmed: the station's goal is TankBrain._order_context, GDScript on every path).
- **R47.18 (army layout):** the live layout is bake-timing dependent at start (CP43.0); a next-round determinism item, not cause 2.

**REPORT (2026-10-30 ~18:30 PDT).** Merged: **dfb6a2567 GREEN builder3** (`make check exited 0`, 3518 / 0, 29 targets ALL JUDGED;
replay-pytest in check, the remote.sh seed, N3's reader) = main 3f9180d2f. Since: N0 candidate 2, the Xorg DISPLAY line, the place
twin (WIP), the replay A/B switches; full check of dce3e6a23 running.

**N0 (R47.8, his replays leave his match): cause 1 FIXED (candidate 2, 91f0d9900: tests/replay), cause 2 OPEN, written up (time-box).**
- Cause 1: his Crossing ctrl+4 over Spears + Wrenches is a control-group save, which writes no row. It left the Wrenches in no
  squad, so his click sent Spears as a squad task and the Wrenches DIRECT (their row: `source: player`). The replay sent both as
  squads and laid Spears 3.2 m off his spot (57.7, 25.1 v his 55.7, 22.6); the Wrenches parted at 1 s. Fix: ReplaySetup.merge_clicks
  marks a group click's direct rows `loose`, and the replay empties a control group whose WHOLE squad is loose before issuing (a
  partial squad sent direct keeps its group). `--replay-loose=off` = before. builder3 light, Crossing 112 s: the Wrenches 0.0 m to
  19 s (Wrenches_1-3 0.0 to 25 s), Spears' spot his, every crew exact to tick 330. **Orders: the `inp` row must cover ctrl+N / shift+N.**
- Cause 2 (open): between tick 330 and 360 several crews part at once (0.1-1 m; the give-way pair Spears_1 / Spears_5 flips who
  yields), as the syndicate's first lasers land (his first hit tick 382, the replay's 390); Rust's positions still equal at 360.
  Locks parts at the same tick (manoeuvre: exact to 330). Ruled OUT on builder3: headless v windowed (OpenGL) v frames at the
  display's rate (REPLAY_WINDOW=1, REPLAY_FREE_FPS=1: three byte-identical tables), the compiler and libm (gcc 13.3, glibc 2.39 on
  both boxes), wall-clock reads and _process-frame caches in the sim (grep: none), lane-clear (engage: identical on/off).
  Untested: his laptop itself (no local Godot this round, C47.1), the syndicate laser / shield path across CPUs.
  **The limit, stated:** a replay of his round-46 matches is his match to 0.0 m through 11 s; by 13 s the worst crew is 8.5 m off,
  by 15 s 20 m (Crossing, builder3 light, dce3e6a23's replay code). Reads past ~11 s are a staged read, not his match.
- Terminus (round 45) now parts at 12 s too, but it is no control: it predates round 46's rules (shortfwd, holdway, veto, dry_hop)
  and only lane_clear is stamped. **Request (mine, next):** stamp every ON rule in `rules`, so old recordings replay their build.

**N0 more (2026-10-30 ~19:30):** the laptop replay (ONE, lock-held, Crossing 14 s, n 1) = builder3's table to the decimal: cause 2 is
not machine float math; it is in his live session (an input with no row). ec6964f11: the rules stamp carries group_veto, shortfwd,
holdway with lane_clear (dated by the recording's name when unstamped). a79fc79cb: **his garage fights replay again** (Sumps,
Parade: `--player` / `--garage-army` / `--enemy` named user:// files only his laptop has; before, `REPLAY_DONE no RtsControls`):
both armies rebuilt from the header roster (REPLAY_ARMY_REBUILT). Sumps (builder3 light, 40 s): exact to 10 s (Delta parts at 11 s),
Bravo exact past 23 s.

**N2 place twin: EQUAL so far.** Randomized (test_native_place, 4000 elements x every switch); his replays under
TANK_NATIVE_PLACE_VERIFY=1 (builder3 light, every place() both ways): Crossing 11000+ calls / 0, Locks 7000+ / 0 (Sumps, Parade
running). native_place stays OFF (cf598c817) until the four are in and the full check is green; then the price read.

**Queue (twins):** engage E2a lay_carry (gun_native engage(), waits on engage's green hash); route's door mask in pathing_native /
drive_native path_query (after mapkit's doors reach an arena); manoeuvre's R47.11 transit grounding line if decide grounds natively.

**Plan (2026-10-30 evening, start; from main c789b55a6, code e306ce27f GREEN builder3 3518/0: no baseline check of mine).**
1. N1 twins: none filed yet (*Bars (round 47)* empty at start); each one jumps the queue when it arrives.
2. N2 ElementPlan.build: profile INSIDE it first (probe branch probe/native-plan47, wrappers on ~40 functions, not merged), so
   the port is the hot leaf functions with the GDScript kept as the fallback, not a 4000-line rewrite of code three streams edit
   this round. Reason: element_plan.gd is manoeuvre's / route's / engage's by function and all three change it in round 47; a
   whole-body twin would go stale with every merge.
3. N3 the `inp` reader: written ahead against C47.4's format (synthetic rows); the Sumps 601-618 re-read waits for a recording
   with real rows.
4. N4 build_situation: same method as N2, after it.
5. N5 lines_r47 as verdicts land; N6 builders every hour.

**N3 reader DONE ahead of orders (1702fbd2c, laptop: `make replay-pytest` 12/0).** `make playtest-report` gains section (d): every
`sel` row with the `inp` row that made it (key + action, matched by sel_after within 2 frames) or "no input (the game)", and the
summary line "selection: N changes, M by no key or click (first at ...)". A recording without inp rows says so. NEW target
`replay-pytest` (tests/replay's Python tests; rules + divergence + this); **request to the orchestrator: add it to `make check`'s
list in mk/core.mk** (those tests ran nowhere before).
