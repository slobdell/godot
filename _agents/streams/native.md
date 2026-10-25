# Stream: native (the measuring tools under round 40: per-unit counts, same sim on every machine, fast)

> Read `_agents/orchestration.md` (the worker contract), `_agents/remote_builds.md`, `_agents/judging.md`, `_agents/workstreams.md`
> **Round 40** (C40.1, CP40.0). Your round-39 brief: `streams/archive/round39/native.md` (Status: the trig A/B, the copy-back fix, the
> full-check lock). **You own:** `native/**`, `mk/native.mk`, `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`,
> `tools/perf_judge.sh`, `tools/loaded.sh`, `tools/slot.sh`, `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`,
> `tests/ai_scenarios/guard_line.gd`, `mk/play.mk`'s skirmish recipe. Scratch trees `../godot-native-score` and `../godot-native-guard`
> are yours (their builder2 copies were cleared at launch; remote.sh re-syncs them). **Model:** Opus. **Machines:** builder2 for rows,
> builder0 only in a quiet window for perf.

## The lead's direction

Native code is C++ for core components (his call). He may buy a 16-core Ryzen tower (2026-10-24; memory *builder0 throughput*).

## Where things stand (main at launch: see HANDOFF)

N4 (CORE-MATH trig) ships: the laptop simulates the builders' fights. The trig A/B (main 6a1c77752, builder0 quiet, n 3 an arm): CORE-MATH
+169 us/tick (+2.2 %) v glibc 2.43's libm, 3/3 rounds. Full-check lock and copy-back fix merged. Main's perf: 7,691 us/tick (68d0410d3,
builder0).

## Backlog (in order)

1. **N1 per-unit counts in GUARD_RESULT (CP40.0, FIRST; balance waits on it).** For each side: per unit (id, type, faction, cost) kills,
   death (and the tick), damage dealt and taken. Additive fields; `guard.py` still reads old rows. Test: a fixture fight's tally sums to
   the row's kills. Name the green hash to the orchestrator the minute it's green; it merges alone.
2. **N2 a per-unit summary in `guard.py`** (`--by-unit`): per faction and unit type, kills/losses/damage per credit, paired arms.
3. **N3 the balance search's runner (for balance's B4):** run a candidate's stat overrides (a `--unit-overrides=<json>` flag read at army
   load, OFF by default; GRANT: the one read in `game/units/army.gd`, additive) across N seeds on builder2. Agree the json shape with
   balance via the orchestrator.
4. **N4 the trig's ~2 % (low priority):** a 5-round rerun of the A/B first; only if the sign holds at 5/5, try the FMA target clone or
   resolving to libm on glibc >= 2.41, with the twin and known-answer tests again.
5. **N5 (only if he buys the Ryzen):** measure it against builder2 on one full check and one guard chunk, add it to `remote.sh`.

## How to verify

Pure tests and twins; `make quick-remote`; a full check per named hash; perf only via `make remote-quiet T=perf-judge` on builder0.

## Don't touch

Brains (balance's), deploy (settle's), movement/traffic (manoeuvre's), `game/control/**` (orders'), `game/units/**` beyond N3's one read,
`tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing (N5 waits on his purchase).

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Report (round 40 worker, 2026-10-24 evening): in progress

**Plan (in order):** N1 -> N2 -> N3 (the orchestrator: N3 is on balance's critical path, R40.1/R40.2; N4/N5 never ahead of it)
-> N4 (low) -> N5 (waits on his Ryzen).

- **N1 (CP40.0) DONE at 8b069ae2a** (full check pending; the hash to merge is named below when green). GUARD_RESULT gains
  `units` {"green": [...], "rust": [...]}: per unit {id, type, faction, cost, kills, death (tick, -1 alive), killer, dealt,
  taken}. Damage = shield + hull points between ENEMIES (friendly fire and hazards not counted), as projectile_impact counts
  it. Shells, beams, arc bursts (their victims) from weapon_fired + projectile_impact; a cone has no event, so the probe
  snapshots the enemies' shield + health before and after the match's own `sprayed` handler (it reorders the connections:
  read-only, the sim unchanged). Cost = `Units.stat(type, "cost")` (a tuned cost shows). Additive; guard.py reads old rows.
  Tests: `tests/test_guard_units.gd` (a fixture fight: kills sum to the side's enemy kills; dealt = the other side's taken).
  Live (laptop, 8b069ae2a's tree, locks 9001 blob green, syndicate v law, n 1): unit kills 24 = row 24 and 9 = 9; deaths
  9 / 24 = losses; dealt 9074.23 v taken 9074.24, 6293.78 v 6293.77 (rounding to 0.01 a row).
- **N2 DONE at 7cca8df93:** `guard.py --by-unit RAW...` (per faction and unit type, "*" the whole army: fielded, credits,
  kills a 1000 credits, credits killed / lost a credit, dealt / taken a credit, share lived) and `--by-unit --pair BASE ARM`
  (each rate base -> arm, se from the per-seed differences). Known answers in `test_guard.py`.
  Cone path proven live (laptop, gorge 9005 blob, syndicate v condemned, n 1): 12 burners (flamethrower only) dealt 0.55 a
  credit (~1,450 points). A/B v the round-39 probe (laptop, sumps 9002 turtle rust, gangs v condemned, n 1): the identical
  fight (Rust on control 196.6 s, kills 24/27, shots 300/107, hits 218/92), so the tally changes nothing. (Seeds 9001-9005
  are laptop smoke only, not the registry.)
- **N3 DONE at 31b5ae24a** (+ main merged f7fd739d9; check pending). R40.2's shape, ABSOLUTE values:
  `{"units": {"gang_tank": {"max_health": 483, "cost": 160, "armor": {"front": 8.05}}}, "weapons": {"scrap_cannon": {"damage": 299}}}`.
  `Units.apply_overrides` validates the whole document (every unit / weapon / stat must exist and be a number; armor one level
  down) and writes into `Units.tuning` / `Weapons.tuning`, the same dictionaries `--tune` fills (all or nothing). GRANT used:
  `Units.cost_of` and `roster_average_cost` read `Units.stat(id, "cost")`, so a tuned cost prices army_cost and the CPU deal
  (army.gd's cpu_army goes through cost_of); untuned they read the catalog as before. `Army.ensure_overrides()` (top of
  `load_army`) reads `--unit-overrides=<path>` ONCE; no flag = nothing read. GUARD_RESULT: `overrides_sha` (the file's sha256,
  "" without) and the flag in `args`. Tests: `tests/test_unit_overrides.gd` (writes, tuned cost prices the army, half price buys
  a bigger CPU army inside the budget, bad documents write nothing). Live (laptop, f7fd739d9's tree, gorge 9003, gangs v law, 30 s):
  `UNIT_OVERRIDES applied`, gang_tank's row cost 160 (catalog 175), overrides_sha = `sha256sum` of the file.
  **The runner (for balance's B4):**
  `GUARD_OVERRIDES=cand.json GUARD_SEEDS="..." tools/scoreboard/guard.sh <commit with N3> slobdell@builder2` lays the file into
  the scratch tree as `overrides/<sha12>.json`, passes `--unit-overrides=res://overrides/<sha12>.json` to every fight, and files
  the logs under `../godot-native-guard-raw/<commit>-ov-<sha12>/` (GUARD_TAG overrides the name); it refuses a commit without
  N3. Read: `guard.py --by-unit <dir>` and `guard.py --by-unit --pair <base dir> <arm dir>`.
  `GUARD_SIDES=green` (balance's ask, dec9725f5): one guard side only (the none line's two sides are the same fight).
- **Inserted by the orchestrator: M1 v2's chainrelease twin, `pair/native-chainrelease` 18e5dbca8** (on manoeuvre's 4406e1f52;
  worktree `../godot-native-chain`; QUICK-GREEN builder0 114/0, needs a full check before merge). drive_native.cpp: `chain_in_play(seat, reach, asker)` lifts the reach
  when chainrelease is on and the asker's Movement (Movement.of via the script) has stalled_ticks >= CHAIN_RELEASE_TICKS
  (configured from Movement.chain_release_ticks(), so `--chain-release-s` reaches it; -1 on a tree without it = off), counting
  chain_releases; the hold branch refuses (chain_holds_refused, chain_refusals) when the chain is in play and its search skipped
  a spot. chainside NOT twinned: Traffic._chain_native now bypasses native_yield only for chainside (manoeuvre's grant), and
  test_traffic_chain's switch test flipped. Twins (laptop, n 1 run each): the chain stages with the release on, wedged
  (stalled 100000) and still (50) askers, 210 drives a mode, 0 mismatches, chain_releases 69; a new Sumps stage of 6 poses
  that reach the refused hold (swept: 66 of 792 poses, all 0 mismatches), 6 refused, 0 mismatches; the ON and OFF arms as
  before; test_traffic_chain's v2 stages pass through the C++ (16/0). Mutation: the C++ refusal dropped -> the hold stage
  6/6 mismatches.
