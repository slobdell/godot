# Stream: native (the per-vehicle tick in C++: N3, the execute step as one native call per tank, then think)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (ALL of it: the hazards, the proof, *The
> plan from here*), `_agents/determinism.md`, `_agents/workstreams.md` *Round 24* (C24.1 the freeze, C24.2 declared
> ports, C24.4 the cap), and round 23's native report (`streams/archive/round23/native.md` Status: the sizing table,
> the prices, known issues). You own `native/**`, `game/ai/native/**`, `mk/native.mk`, `game/ai/avoidance.gd`,
> `steering.gd`, `cover_map.gd`, `combat_motion.gd`, `brain_switches.gd` (additive), `incoming_fire.gd`'s seam,
> `tests/test_native*.gd`, `tests/native/**`, `_agents/native.md`, the C23.1a seam in `pathing.gd`; and **after CP1**
> the C24.1 freeze set (seams and the ported code paths in `movement.gd`, `tank_brain.gd`, `gunnery.gd`,
> `perception.gd`, `ai_tick_cache.gd`, `bot_controller.gd`, `wall_contact.gd`, `pid.gd`, `clothoid.gd`).
> **Before CP1 you do not edit `movement.gd` or `tank_brain.gd`** (brains is fixing the bridge there).

## The lead's direction

> *"ok yes let's plan on re-writing the whole per-tick loop in C++"* (2026-10-08; he asked whether it meant Rust;
> answered: C++ through godot-cpp kept, `game_design.md` *Round 23, the afternoon*.)

What he will notice: **big fights stop going into slow motion on his laptop, and the army goes back to ten squads /
50 vehicles when the laptop table says so** (C24.4). The laptop is the fact (lesson 271; memory *Laptop is the test
bed*: Intel UHD 620).

## Where things stand (read at `fc56bd64` = round 23's close; verify)

- **Ported and ON:** `would_be_hit`, ORCA `Avoidance.solve`, `CoverMap.clear_line`/`_coarse`/`path_blocked`, the
  navmesh closest point (`NavNative`, N2a). **Ported, proven equal, OFF:** movement's geometry (N2b, `native_move`,
  ~1 %). The brains' cost: −20 % his Sumps / −22 % 25 v 25 / −22 % 50 v 50 (builder0 pinned, n = 3, hashes equal);
  laptop headless 25 v 25 band 24.3 → 18.1 ms.
- **The sizing** (50 v 50 leaders, builder0 pinned, n = 3, `3c61ecbe`): EXECUTE 56.6 % of the brains' work (engine calls
  27.5 % of it, now smaller after N2a), THINK 43.4 % (`situation` 507 µs a think; `decide` 191 µs). Inside execute:
  `move` (`nav.chord`, `move.path`, `steer.drive` k-turn planning, `move.avoid`, `move.guard`, `t.poll`), `weapon`
  (`weapon.scan`). Full table: `streams/archive/round23/native.md` *The band sized*.
- **The bar** (C24.4): the laptop, 50 v 50 leaders in contact ≤ 25 ms a tick → the cap goes to 10 squads. Today 25 a
  side in contact was ~40 ms before native, ~30 ms by proportion after. The orchestrator measures the laptop table
  with native ON at the launch and after each of your steps that lands on main.
- **The rules that cost round 23 a day:** a dynamic native call costs ~0.24 µs (lesson 276): a seam must replace
  tens of µs; the shipping `.so` is built on the laptop (glibc 2.39), never builder0; one machine's `build/` per
  worktree at a time (lesson 275).

## Backlog (in order)

**N3a — the data the C++ owns (before CP1; no `movement.gd` / `tank_brain.gd` edits).** The per-tank native record
(position, heading, speed, hull, the last command, the route, the neighbour set, the cover-map handle) and a per-team
contacts table, filled ONCE a tick from GDScript in one call each (the marshalling priced), read back field for field
in a test (equal). `TankCommand` built natively. Write in `native.md`, before coding the port, the execute step's call
graph (`compute_command` → `Movement.drive` → …) with each function's share from `--brains-parts`, and for each:
**equal-answer** (bit-exact, the live-function proof as N2b) or **DECLARED** (C24.2: why it cannot be, e.g.
Dictionary-ordered tie-breaks). The orchestrator reads the map before N3b starts on main's frozen code.

**N3b — the execute step's leaves (after CP1: `git merge main` when told).** Bottom-up, each its own sub-switch under
`native`, each equal against the LIVE GDScript (the N2b proof pattern, so any later brains edit the C++ does not follow
fails the check), each priced (`make ai-ab-match AB_SWITCH=<name>`, builder0 `taskset -c 0-3`, n = 3: his Sumps, 25 v 25,
50 v 50). Suggested order by size: `steer.drive` (the k-turn planning), `move.path` (path following), `move.guard`,
`t.poll`, then `weapon.scan` (rays through godot-cpp's physics server). A seam that does not pay ≥ 2 % at 50 v 50
outside 2 se ships OFF (round 23's rule).

**N3c — `Movement.drive` as ONE native call per tank per tick** over the N3a record: the leaves joined, the GDScript
kept as the reference path (`--brains-off=native`). The proof: `make native-proof` (hashes equal), the full suite both
ways, `ai-parity`, `element-digest`. Where it cannot be equal, C24.2.

**N3d — think's `situation`** (`build_situation`: contacts, select, cover_fire, cover_spots, allies, tactics; ~18 %
of the brains' work) over the contacts table, then `decide` if the round has time.

After each step that lands: report the builder0 band (three sizes) and message the orchestrator, who re-runs the laptop
table. **Report what was measured, with the commit, machine and n.**

**Stretch:** (a) `native_move` (N2b) re-priced on the laptop; ON if ≥ 2 %. (b) The Android arm64 cross-compile target in
`mk/native.mk` and the trig hazard's proof there (no device needed for the build; note what is left).

## How to verify

`native.md` *The proof* table, every step: `make test FILTER=native`, `make native-proof` (laptop AND builder0, each
equal to itself), `make remote T=check` AND `make remote T="check NATIVE=off"` green (read `>> remote: make check
exited <N>` and `N passed, M failed`, never a pipe; ALL JUDGED; thirteen lines + determinism UNMOVED unless DECLARED),
`make ai-parity`, `make element-digest`. Smoke test like a player: `make native && make skirmish` on the laptop after
the orchestrator's table is done; the fight looks the same, the tick lighter. Every number: commit, machine, workload,
n (C16.3). A `.uid` for every new test (lesson 273).

## Don't touch

**Before CP1: `movement.gd`, `tank_brain.gd`** (brains' bridge fix) · `game/tactics/**`, `squad.gd`,
`order_controller.gd`, `formations.gd`, `cpu_commander.gd`, `pathing.gd` beyond the C23.1a seam (brains) ·
`game/control/**`, `game/ui/**`, `game/match/**`, `game/tank/**`, `game/units/**` (`MAX_SQUADS` is the orchestrator's,
C24.4), `arenas/**` · `tests/baselines/**` except declared lines · `tools/remote.sh` (a request). **The laptop is the
orchestrator's** for its native-ON table at the launch: run on builder0 until told it is done.

## Waiting on the lead

- Nothing blocks you. A DECLARED port (C24.2) ships behind its switch with its paired series; the orchestrator rules ON
  or OFF and takes it to him. Decide, record the reason in Status, keep going.

## Status

_(the worker keeps this current; started 2026-10-08 ~20:40 PDT from `bfc00f53`; this report written 2026-10-09 ~06:30)_

### The report (read this first)

**Where the backlog stands.** N3a DONE (the record + contacts gathered by the C++; the execute-step map, every row
EQUAL, accepted). N3b DONE (`weapon.scan` and `move.path` proven equal; scan priced OFF, path superseded by the native
drive). N3c DONE (`Movement.drive` in C++ on the mover's own members, callbacks for the rare branches; proven on
3600 drives in two scenarios; **ON: −9 to −12 % of the band headless, −4.6 % of the tick in contact**). N3d DONE as far
as my paths reach: `decide` **ON** (−4.3 % of the tick in contact); the situation core, `matchups_for` and C24.6's
TacticalQuery built, proven equal, and **OFF by their prices** (the rules below). Stretch (a) done (`native_move` stays
OFF on the laptop too). Stretch (b) (Android arm64) not started: no NDK on either machine, and the round's time went
to N3c/N3d.

**The finding that changes the plan** (the orchestrator has it for the lead): in the opening contact on his laptop the
brains are 72–74 % of the tick's scripts and think is 60 % of the brains; 25 a side is 34.5 ms of scripts (30 a side
43.6), so 50 a side in contact is ~80 ms against the 25 ms bar. Equal-answer ports could still take ~8–9 ms at 25 a
side this round, optimistically; even deleting every brain's cost leaves ~23 ms at 50 a side. The cap cannot reach 10
squads by porting; the lever is a think-rate / level-of-detail policy (brains' design, his taste).

**Green shas:** `b94e9767` (decide ON; main `59a161f2` merged): builder0 `make check exited 0`, 2326 passed, 0 failed,
23 ALL JUDGED; its `NATIVE=off` check: see the last entry under Done. Earlier greens: `d0bc1517` (merged as
`c4f4a50c`), `26009842`, `b339f5fb` (merged as `62f528d0`).

**What to playtest** (the laptop): `make native && make skirmish` — his usual fight; nothing should look different
(every port is equal-answer), fights a little lighter. `--brains-off=native` on the command line runs the GDScript
for an A/B by eye. `make native-tick-profile` re-takes the in-contact table.


### Plan (in order)

1. **N3a** (before CP1; no `movement.gd` / `tank_brain.gd` edits): the per-tank record + the contacts table + `TankCommand`
   written natively (`native/src/tank_record.*`, `game/ai/native/native_record.gd`), proven field for field
   (`tests/test_native_record.gd`), priced by `AB_SWITCH=native_record`; the execute step's map in `native.md`
   (*N3a*), with fresh `--brains-parts` shares. → message the orchestrator to read the map.
2. **Wait for CP1** (brains' bridge on main) → `git merge main` when told.
3. **N3b** leaves, each its own sub-switch, each equal against the LIVE GDScript, each priced at three sizes.
   Order by the fresh shares: `weapon.scan` (6.4 %; C++ + test ready, `native_scan`), `move.path` (6.2 %; ready,
   `native_path`), `steer.drive` (3.0 %), `move.guard` (2.4 %). `t.poll` dropped (Dictionary glue; a brains request).
4. **N3c** `Movement.drive` as one native call per tank: design (a) (the C++ on the mover's own members; callbacks for
   what is not yet ported). First cut proven equal (2160 drives); next: the seam (after CP1), the match price, then
   port the callbacks by their measured share (`drive_profile`).
5. **N3d** think's `situation`.
6. Stretch: `native_move` re-priced on the laptop (when the orchestrator releases it); the Android arm64 target.

### Decisions (reversible; one line each)

- **The record is filled from `Avoidance.refresh`** (mine; the one place that walks every hull once a tick) ; the
  neighbour set is asked of N1's table on demand (`record_neighbours`), never by refreshing Avoidance from the fill:
  `Avoidance.refresh`'s `_still` column reads other movers mid-phase, so WHEN it is built is part of its answer
  (caught in review before the first check of it).
- **Contacts from `match.intel` directly, sorted in the fill** — not through `AiTickCache.contact_prototypes`, whose
  memo a fill must not build at a different tick than the brains do (its live suppression/gun-ready reads would move).
- **`native_record` OFF by default**: nothing reads the record until N3b/N3c; ON only to price the marshalling.
- **`.uid` files written by hand** (Godot's base-34 form) for the two new scripts: the laptop is the orchestrator's
  tonight, so no local `make import`.

### Baseline

- `bfc00f53` builder0 `make remote T=check`: exited 0, **2295 passed, 0 failed**, 23 targets ALL JUDGED, thirteen unmoved, determinism `762a0576f944f5b7`.

### Done (each with commit, machine, workload, n)

- **N3a the data** (`5db5f558` → `29a98e28`): `TankNative.record_gather` (the per-tank record: position, forward,
  velocity, the last command, turret, speed, hull numbers, team, health, the route snapshot, the cover handle) and
  `contacts_gather` (each team's intel in name order), both gathered BY THE C++ (it reads members at 0.03 µs each);
  `command_into` writes a TankCommand natively; the neighbour set asked on demand of N1's table. Proof:
  `test_native_record` (every field == its live value, neighbours == Avoidance.neighbours, 200 commands, the contacts
  == the intel). **The marshalling's price** (`ai-ab-match`-style in-run A/B of `native_record`, builder0 light lane,
  `taskset -c 0-3`, 50 v 50 with leaders, 120 s, hashes equal `c40ecc587db72630` in every run): GDScript-packed
  columns (`46fd0596`) **+3.5 / +5.4 / +2.5 %** of the band; gathered natively (`29a98e28`) **+2.1 / −1.0 / −1.9 %**
  (noise; ~0.3 % mean). Logs `streams/references/round24/native/price-record-*`.
- **N3a the map** (`native.md` *N3a*): every execute-step row EQUAL by plan, no DECLARED row; fresh 50 v 50 shares
  (`bfc00f53`, builder0, n = 2): controllers 30.1 ms, execute 50.6 % (engine 3.4 % of it), think 49.4 %.
- **`native-bench`'s state-sync rows** (`c8da555e`, builder0 pinned): a GDScript member read from C++ 0.030 µs, read +
  write 0.054 µs (GDScript's own `get(name)` 0.106): N3c works on the mover's members in place (design (a)).
- **N3b prepared, proven, seams wait for CP1:** `weapon.scan` (`TankNative.scan_nearest`, `NativeScan`): 300 poses, 0
  mismatches against the live `_nearest_shootable` (three "seen" modes, sectors); `move.path` (`follow_route`,
  `NativeRoute`): 463 poses, 0 mismatches against the live `_next_waypoint` on re-plan-free poses (226 facing away,
  99 computing a chord). Both in `46fd0596`'s check (builder0, exited 0, 2300/0, ALL JUDGED).

- **N3c first cut, proven equal before its seam exists** (`5e814b3c` → `338b0435`): `Movement.drive` in C++
  (`native/src/drive_native.cpp`) working on the mover's own members, with callbacks into the live GDScript for what
  is not ported (`_approach_gate` with a facing, `Pathing.query`/`_inflate_corners` on re-plans, `_around_fire`,
  `_planned_reverse`, `_kturn_end`, `_keep_station`, `_repair`, `_blocker`, `_negotiate`); ported: drive's control
  flow, `_track_goal`, the re-plan decision + counters + route tail, `_remaining_path_distance`, `_avoid` (ORCA's
  native solve in place), `_guard_steer` with the chord memo, Steering, `_note_wedge`, `_track_progress`,
  `_update_phase`. **Proof** (`test_native_drive`, builder0 light lane): twelve hulls of seven units on the Sumps,
  every input drive reads, 180 frames; each drive asked of the live GDScript and natively from ONE snapshot of every
  mover: **2160 drives, 0 mismatches** in the command and in every member and static of every mover (899 re-plans,
  146 station-keeping, 369 deflected, 248 reversing, 3 that changed another mover). First price in that test's mix
  (re-plans on 42 % of drives, a match ~13 %): live 469 µs v native 359 µs a drive (−23 %) with the callbacks
  included; a match's price waits for the seam (CP1). The seam: `if NativeDrive.usable(self): return
  NativeDrive.drive(self, cmd, order, delta)` at the top of `Movement.drive`.

- **CP1 merged** (`e6286ca6` = main `b6bd539a`), the seams landed (`d0bc1517`): `Movement.drive` → NativeDrive
  (`native_drive`), `_next_waypoint`'s tail → NativeRoute (`native_path`), `Gunnery._nearest_shootable` → NativeScan
  (`native_scan`). **GREEN, merge here: `d0bc1517`** (builder0, `make check exited 0`, 2315 passed, 0 failed, 23 ALL
  JUDGED, sim lines as main declares them; log `references/round24/native/native-check-d0bc1517.log`).
  `native-proof` at `d0bc1517`, builder0: EQUAL `e155255c75dd2e2a` (his Sumps; every port −18.4 % of the band, n = 1)
  and EQUAL `f07b7b3e16d6b37f` with leaders (−29.5 %, n = 1).
- **N3c `native_drive` priced** (`d0bc1517`, builder0 light lane, `taskset -c 0-3`, leaders both sides, n = 3, load
  3–5.6, every run's hash equal to its plain run): his Sumps **8.0 / 10.2 / 10.0 %** (mean 9.4, se 0.7); 25 v 25
  **12.7 / 11.5 / 11.9 %** (12.0, se 0.35); 50 v 50 **8.6 / 10.0 / 9.5 %** (9.4, se 0.41). Clears ≥ 2 % outside 2 se at
  every size: ON. Logs `references/round24/native/price-drive-d0bc1517/`.
- **N3b `native_scan` priced** (same setup, load 5–17): his −3.4 / +1.0 / −1.4 %, 25 v 25 +2.1 / +1.3 / +1.9 %, 50 v 50
  +1.9 / −0.1 / +1.4 % (mean 1.1, se 0.6): under the bar, **OFF** (`00bb82dc`); code and proof stay. Why little: the
  sight ray stays an engine call and the scan needs the per-tick record. `native_path` is reached only with the drive
  seam off (the native drive has the route tail inside it): not priced on its own; kept as the drive-off path's leaf.
- **N3d first piece** (`00bb82dc`): `build_situation`'s allies + contact selection + contact entries (`s.allies` +
  `s.select` + `s.contacts`, ~190 µs a think at 50 v 50) as one native call (`situation_native.cpp`), the team-shared
  memos (`AiTickCache.faced_by`, `CoverMap.clear_line_coarse`) still asked of the GDScript. Proof
  (`test_native_situation`, builder0): **2353 situations built on real brains in a 10 v 10 fight (1833 with contacts,
  189 with more than MAX_CONTACTS), 0 mismatches** (`==` on the whole Dictionary, key order included).

- **`native_situation` priced** (`00bb82dc`, builder0 light lane pinned, leaders, n = 3, loads 3–11, hashes equal):
  his 1.6 / 2.7 / 2.2 %, 25 v 25 2.7 / 6.9 / 2.1 %, 50 v 50 2.5 / 0.0 / 2.7 % (mean 1.7, se 0.9): **OFF** by the rule
  (`3d509f2d`); code and proof stay.
- **Stretch (a) `native_move` re-priced on the laptop** (`d8a7541a`, flightdeck, 25 v 25 leaders, n = 3, quiet load
  0.4–1.3, hashes equal): +0.2 / +0.3 / −0.3 %: stays OFF (the native drive left it nothing to save).
- **Laptop, every port** (`7ebdc122`, flightdeck, 25 v 25 leaders, n = 2, load 1.3): −34.6 / −34.3 % of the band (ON
  12.5 ms v OFF 19.0–19.3 ms a tick). Logs `references/round24/native/laptop-price-7ebdc122/`.
- **decide's split** (throwaway probe, builder0, 1175 real situations): `decide` 121 µs, `matchups_for` 85 µs of it.
- **N3d `matchups_for`** (`4a8fbf20`): natively with Matchups' math and `Armor.facing` (`matchups_native.cpp`,
  `native_matchups`). Proof (`test_native_matchups`, builder0): **2393 situations, 12 918 matchup entries, 10 868
  orbit entries (synthetic orbit cases), 0 mismatches**, `decide` equal both ways, constants held to the live scripts.
  Price at three sizes: running.

- **The windowed in-contact breakdown** (the orchestrator's ask; `26009842`, laptop, n = 6 per arm): the brains are
  74 % of the tick's scripts in the opening contact, and think-heavy there (think 16.1 ms v execute 8.8); the drive
  is −4.6 % of the tick in contact, all native −18 %; situation core −0.45 ms (1.3 %), matchups 0 (the shipped brain
  has matchups OFF: my earlier "70 % of decide" was a probe error, corrected in `native.md`), scan +2.05 (worse).
  New rule (orchestrator): think ports are ruled by this table (`make native-tick-profile`, the laptop). Instruments
  committed with tests (`TickProfile`, `--brains-on`, `test_native_tick_profile`).
- **GREEN, merge here: `26009842`** (builder0, `make check exited 0`, 2321 passed, 0 failed, 23 ALL JUDGED; with main
  `c4f4a50c` merged).
- **N3d `decide`** (`2b761799` → `5d9d3cec`): `TankBrain.decide` as one native call (default arm), proven on 6990
  decisions (real + mutated situations, 21 options chosen), 0 mismatches. **Priced ON by the think rule:** in contact
  (laptop, his preset, 25 a side, foundry + parade × 3 seeds, n = 6 per arm, window 8–20 s) the tick's scripts
  35.03 → 33.53 ms (−1.50, se 0.50 = −4.3 %), `brain/decide` 3.08 → 1.95 ms; headless second reading (`bcd4d699`,
  builder0 pinned, leaders, n = 3, hashes equal): his +2.5 %, 25 v 25 +5.3 %, 50 v 50 +2.3 % (se 0.25). The
  orchestrator ruled it ON. Then each contact read once into a C++ row: native 62 → 50 µs a decide (live ~96).
- **The situation core re-priced in contact** after moving `faced_by` and the coarse sight line native (`211b5375`,
  paired by seed, n = 6): `brain/situation` −0.92 ms (se 0.09), the tick −0.66 ms (se 0.26) = −1.97 %: under the
  2 % bar (written before the table): **OFF** (the orchestrator's ruling, lesson 278).
- **`b339f5fb` `NATIVE=off`**: 2325 passed, 0 failed, wrapper exited 0, but perf-judge NOT JUDGED (builder0 at ~2×):
  not a full green; the decide sha's `NATIVE=off` check is the one to read.

- **C24.6 TacticalQuery** (`ec5d4a1d`-tree → `2489b7ea`): `find_cover` / `find_cover_fire` natively, the two
  granted seams; proof 830 requests (634 cover, 182 hide/peek), 0 mismatches; brains' `test_ai_tactical_query`
  passes through the seam. In contact (laptop, paired, n = 6): tick −0.72 ms (se 0.39), not outside 2 se: **OFF**.
- **The in-contact breakdown for the lead's decision** (`2489b7ea`, laptop, n = 6 per size; `references/round24/
  native/tick-profile-breakdown-2489b7ea/`): see the report above.

### Questions for the lead

- None.

### Known issues

- **Instrumented numbers.** TickProfile turns OrderController's profile parts on (their laps cost ~10 %); compare
  arms only with arms, as every table here does.
- **`set_all(true)` turns every OFF-shipping native switch on** (`native_move`, `native_record`, `native_scan`,
  `native_situation`, `native_matchups`, `native_tq`): harmless (each is proven equal) but an `all` A/B's ON arm
  includes them.
- **The native drive skips some measurement-only profile parts** (`move.*`, `nav.chord`, `steer.*` inside drive):
  sizing runs with native ON read the drive as one part; `--native-drive-profile` splits it.
- **A local laptop run during a remote check of the same worktree** must write outside `build/` (the copy-back
  mirrors it): `make native-tick-profile BUILD_DIR=.laptop-tp`.
- **matchups_for's native twin** is held to `matchups.gd` / `armor.gd` by its test: an edit there fails it until the
  C++ follows (Requests).

### Next steps

1. The think-rate / LOD policy is the lever (brains' design); native supports it with the instrument.
2. If more ports are wanted: `act` (~1 ms at 25 a side), decide's remaining Dictionary building (~0.6), the drive's
   `_around_fire` check ticks (`Match.threat_along`, match's: a grant), `weapon.lanes`/`aim` (combat's FireLanes,
   Ballistics: grants). Each is under the 2 % bar alone; together ~3 ms.
3. Stretch (b): Android arm64 cross-compile (needs an NDK download on builder0).

### Merge notes (shared files, additive)

- `game/ai/movement.gd`: the drive seam (top of `drive`), the route seam (in `_next_waypoint`).
- `game/ai/tank_brain.gd`: seams at the top of `decide`, `matchups_for`, the situation core's block in
  `build_situation`; `t.poll` split into measurement-only sub-parts (the total kept).
- `game/ai/gunnery.gd`: the scan seam (top of `_nearest_shootable`).
- `game/ai/tactical_query.gd`: the two C24.6 seams only.
- `game/ai/avoidance.gd`: the native gather, lazy GDScript columns, `TickProfile.ensure` hook, the record fill.
- `game/ai/brain_switches.gd`: `native_record`, `native_scan`, `native_path`, `native_drive`, `native_situation`,
  `native_matchups`, `native_decide`, `native_tq`; `apply_args` with `--brains-on=`.
- `mk/native.mk`: `native-tick-profile`. `.gitignore`: `/.laptop-tp/`.

### Requests to other streams

- **brains and combat (notice, through the orchestrator):** `game/ai/matchups.gd` and `game/combat/armor.gd`'s `facing`
  now have a native twin (`matchups_native.cpp`) held to them by `test_native_matchups` on every check. An edit to
  those functions fails that test until the C++ follows: tell native, or set `native_matchups` off in the same commit.
- **brains (not blocking, a lever, its call):** `t.poll` is 7.9 % of the brains' work at 50 v 50 (2 431 µs a tick,
  36 µs a call; `bfc00f53`, builder0, n = 2): `_poll_element` rebuilds `ElementFeed.context` on every think tick even
  when no `element_changed` signal came. Not a native target (Dictionary glue; `native.md` *N3a*).
