# Stream: native (the game stays fast at the cost cap; every ON rule has its C++ twin; rematches replay exactly)

> Read `_agents/orchestration.md` (the worker contract; lessons 339, 351, 353, 354), `_agents/judging.md`, `_agents/workstreams.md`
> **Round 48** (C48.1-C48.4) and **Round 47** (C47.1-C47.11; C47.6 is yours; R47.16, R47.18, R47.47), your last brief
> `streams/archive/round47/native.md` (FINAL REPORT and *Round 48's native list*). **You own:** as round 47 — `native/**`, `mk/native.mk`,
> `tools/scoreboard/**`, `references/scoreboard/**`, `tools/judge/**`, `tools/perf_judge.sh`, `tools/loaded.sh`, `tools/slot.sh`,
> `tools/remote.sh`, `tools/full_check_lock.sh`, `tools/copyback_verify.sh`, `tools/builder_checks.sh`, `tests/ai_scenarios/guard_line.gd`,
> `mk/play.mk`'s skirmish recipe, `mk/gcp.mk`, `_agents/judging.md`, `tests/replay_orders.gd`, `tools/recording_arrivals.py`,
> `tools/playtest_report*`, `tests/replay/**`, `game/match/match_recorder.gd`'s `rules()` table (additive); GRANT the C++ seams in
> `game/control/**`, `game/ai/tank_brain.gd`'s native call site, and the native call site of `ElementPlan.build` / `ElementSituation.build`,
> each GDScript body kept as the fallback. **Model:** Opus. **Machine:** builder3 (builder0 is DOWN). **Seeds:** 13505-13552; twins run
> on the owner's.

## The lead's direction

Memory: native code is C++ (core components in C++ long-term, even without a gain); the laptop is the test bed (UHD 620; perf cuts ship
as hardware presets). At the 1000-credit cost cap he gets ~10-12 fps as gangs on the laptop (round 47).

## Where things stand (main df9aacc1a GREEN builder3 3630/0)

- C++ ON: place, esit, matchups; doors and the sight class's eye mask; the replay stamp carries every round-47 rule (lesson 354).
- Replays of his matches part at ~11 s (cause 2: an unrecorded live input; his recordings will carry `inp` rows from now on).
- The yield-cycle (sliver) test PENDING (R47.47): same-process Jolt carry-over moves a lab by cm.
- The laptop ratio ~3.0x builder3 (measured round 47).

## Backlog (in order)

1. **N1 twins as bars arrive** (C47.6): manoeuvre's give-way fix (Bar B), engage's retreat (Bar E11), orders' follow station (Bar F if the
   native drive reads it). Output-identical first; each with its replay stamp entry. Answer within the hour a stream asks.
2. **N2 contact_prototypes' rebuild in C++** (~0.7 ms a frame on his laptop at the cost cap). Judged on the laptop preset, lock-held read.
3. **N3 the same-process physics carry-over:** Jolt state left by earlier matches in one process (`make native-repeat ... REPEAT_JITTER=on
   YIELD_CYCLE=on` is the tool); matters for rematches and netplay; unblocks R47.47 with manoeuvre's M6.
4. **N4 the laptop fog readers' unexplained ~2 ms** (`references/round47/native/fogread-laptop`).
5. **N5 R47.18 the army layout's bake timing** (ARMY_LAYOUT_UNCHECKED: standable queries before the navmesh).
6. **N6 replay cause 2** once one of his recordings carries `inp` rows (the orchestrator relays the file when he plays).
7. **Stretch:** a laptop-preset fps read at the cost cap, gangs v syndicate on Crossing, before / after N2-N4 (the number he'll feel).

## How to verify

`make remote T=check` for a hash you will NAME (read `>> remote: make check exited <N>` and `N passed, M failed`); `make quick-remote` to
iterate; VERIFY proofs in check for every twin; laptop reads lock-held only (`flock /tmp/tank-squad-laptop-godot.lock`), one at a time,
five sessions on a 7 GB laptop. Every number with commit, machine, workload, n.

## Don't touch

The GDScript bodies you twin (owners change them; you mirror), `arenas/**`, `game/camera/**`, `game/units/**`, `tests/baselines/**`
(the orchestrator adopts), `tools/spotter/**`.

## Waiting on the lead

Nothing at launch.

## Status

_(worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

**REPORT (2026-10-31 ~14:30 PDT) — N2 built, equal, held OFF (prices slower in-run); N3 found + fixed; N5 fixed on its own branch;
heldpost's C++ mirror drafted; O1 / E2 need no twin.**
**Branches:** stream/native = N2 (OFF) + N3 + the heldpost mirror (inert until manoeuvre's tree); **stream/native-n5** = cc3e962e9
(N5 + its stamp entry, alone: the orchestrator adopts its sim-baseline for one cause; worktree godot-native-n5 to be removed after
its merge). Hashes named below when their full checks are green.
**Plan (order, one-line reasons):** N1 answered as bars arrive (interrupts); N2 contact_prototypes in C++ (smallest foundation, a
pure table); N3 the rematch carry-over (a one-file probe first, so it no longer needs another test's history to reproduce); N4 the
laptop fog read (lock-held laptop time, one read at a time); N5 the layout's bake timing (moves every spawn: sim-baseline for the
orchestrator); N6 waits on his `inp` recording; stretch the laptop fps read at the cost cap last.
- **N2 contact_prototypes in C++ (4c037bebf, 771635051):** `native/src/contacts_native.cpp`, seam `NativeContacts`
  (`game/ai/native/native_contacts.gd`), the GDScript loop moved verbatim into `AiTickCache._contact_table` (the reference);
  `BrainSwitches.native_contacts` **OFF (priced slower in-run, below)**. EQUAL: test_native_contacts 402 tables / 1837 contacts (518 remembered, 405
  reloading, 571 suppressed; green champion, rust a6 so both variant branches run) 0 mismatches (builder3, 4c037bebf); his four
  round-46 replays under TANK_NATIVE_CONTACTS_VERIFY=1 (builder3, 771635051): Crossing 2000+, Locks 1500+, Sumps 2000+, Parade 2000+
  tables, 0 mismatches. check's native-verify-scenarios verifies contacts from now on.
- **N2 price:** in-run A/B (BRAINS_AB, 30-tick blocks, controller band cpu), cost cap = gangs v syndicate 3500 on Crossing seed 3, 150 s,
  builder3, f0900328a, n 4, hashes equal: native -1.9 / -1.8 / -1.6 / -0.7 % (i.e. the C++ arm read SLOWER). Direct per-call timing
  inside test_native_contacts (baed43f15 = keys as prebuilt Variants, builder3, 402 tables): GDScript 19.9 us a table, C++ 14.5 us
  (-27 %). Both tables a refresh = ~13 v ~10 us a tick builder3 (~3.5 us a tick saved; x3.0 laptop = ~10 us a tick, ~25 us a frame at
  2.5 ticks a frame): far below a frame read's noise. Round 47's "0.156 ms a tick" was the whole prologue bracket, not this table.
  Re-priced at 9149ff538 (Variant keys; load 37-50): -0.6 / +0.2 / -0.7 / -1.0 %; at d271488a7 with 45-tick blocks (alignment
  check): -3.3 / -1.2 / -1.2 %. 11 of 12 A/B blocks read the ON arm slower by 30-100 us a tick, more than the GDScript table's whole
  cost: UNEXPLAINED (not the call itself). **Decision: native_contacts stays OFF** (R47's rule: ON only if faster or neutral); the
  C++, its twin test and check's VERIFY stay live. Next: a laptop lock-held read before any flip; find what else the ON arm pays.
- **N3 the same-process carry-over: FOUND and FIXED (R48.5).** test_native_rematch (the CPU sliver lab, 300 ticks, three runs in
  one process, builder3 f0900328a): runs 2 and 3 equal each other and part from run 1 at tick 2 (0.32 m worst, Rust_Hunters_3). The
  root Viewport's World3D (physics space + navigation map) outlives a scene / a freed match. A fresh World3D before each run: all
  three identical tick for tick. `FreshWorld.apply` (game/ai/native/fresh_world.gd): a new World3D with the old one's environments,
  the old one HELD through the swap (dropped first, the engine frees it inside the setter and prints "Parameter scenario is null"
  per swap; the bare swap and an own_world_3d toggle both did). Called in Main._enter_tree (every REMATCH / ARMY / garage FIGHT) and
  per test file in tests/run_tests.gd. 9149ff538 builder3: 3 runs identical, 0 engine errors. `--fresh-world=off` = round 47's.
- **N5 (R47.18) the layout's bake timing: FIXED.** ArmyLayout.deploy calls NavigationServer3D.map_force_update when the map is
  not ready (the arena's region joins by a queued server command; a "has regions" guard left all 20 same-frame slots unchecked).
  test_native_layout_sync (9149ff538, builder3): an army laid in the bake's own frame and one laid 3 frames later stand on the same
  spots on Crossing, Locks, Sumps, 0 unchecked either way (before: 20 unchecked in the same frame). `--layout-sync=off`. No replay
  stamp entry: his replays teleport every crew to his recorded spawn (R47.18), and his interactive starts already laid checked
  (the sync had landed); it changes headless / same-frame starts only. The sim-baseline may move (headless matches laid
  unchecked before): the full check says; the orchestrator adopts.
- **N1:** orders' O1 (27cda7b28, follow station by heading of travel) needs NO twin: the follow goal is `Orders.goal_of` /
  `goal_position`, GDScript on every path (decide_native only proposes FOLLOW; no C++ reads a follow's slot). Its stamp entry
  `follow_travel` is in its commit (lesson 354). Manoeuvre's Bar B and engage's Bar E11: nothing filed yet.
