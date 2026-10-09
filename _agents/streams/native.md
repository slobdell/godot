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

_(the worker keeps this current; started 2026-10-08 ~20:40 PDT from `bfc00f53` = main `fc56bd64` + the launch docs)_

### Plan (in order)

1. **N3a** (before CP1; no `movement.gd` / `tank_brain.gd` edits): the per-tank record + the contacts table + `TankCommand`
   written natively (`native/src/tank_record.*`, `game/ai/native/native_record.gd`), proven field for field
   (`tests/test_native_record.gd`), priced by `AB_SWITCH=native_record`; the execute step's map in `native.md`
   (*N3a*), with fresh `--brains-parts` shares. → message the orchestrator to read the map.
2. **Wait for CP1** (brains' bridge on main) → `git merge main` when told.
3. **N3b** leaves, each its own sub-switch, each equal against the LIVE GDScript, each priced at three sizes
   (`steer.drive`, `move.path`, `move.guard`, `t.poll`, `weapon.scan`).
4. **N3c** `Movement.drive` as one native call per tank (the mover rows, the synced fields).
5. **N3d** think's `situation`.
6. Stretch: `native_move` re-priced on the laptop (when the orchestrator releases it); the Android arm64 target.

### Decisions (reversible; one line each)

- **The record is filled from `Avoidance.refresh`** (mine; the one place that walks every hull once a tick) and its
  neighbour set IS Avoidance's (computed natively at load over N1's table): one definition of "neighbours".
- **Contacts from `match.intel` directly, sorted in the fill** — not through `AiTickCache.contact_prototypes`, whose
  memo a fill must not build at a different tick than the brains do (its live suppression/gun-ready reads would move).
- **`native_record` OFF by default**: nothing reads the record until N3b/N3c; ON only to price the marshalling.
- **`.uid` files written by hand** (Godot's base-34 form) for the two new scripts: the laptop is the orchestrator's
  tonight, so no local `make import`.

### Baseline

- `bfc00f53` builder0 `make remote T=check`: exited 0, **2295 passed, 0 failed**, 23 targets ALL JUDGED, thirteen unmoved, determinism `762a0576f944f5b7`.

### Questions for the lead

- None.

### Requests to other streams

- None yet.
