# Stream: native (water in the laptop's price; the C++ kept in step with this round's behaviour changes)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (everything: the flags, the hazards, the
> proof, what is ported, the seam rules), `_agents/workstreams.md` *Round 25* (C25.2 is your main contract this round,
> C25.4 the laptop), round 24's native report (`streams/archive/round24/native.md` Status), and lessons 279–282. You own
> `native/**`, `game/ai/native/**`, `mk/native.mk`, `avoidance.gd`, `steering.gd`, `cover_map.gd`, `combat_motion.gd`,
> `brain_switches.gd` (others may add one switch line), `incoming_fire.gd`'s seam, every native seam already on main
> (the `if BrainSwitches.native_*` lines in `movement.gd`, `tank_brain.gd`, `pathing.gd`, `tactical_query.gd`,
> `slot_ground.gd`, `gunnery.gd`), `tests/test_native*.gd`, `tests/native/**`, `_agents/native.md`.

## The lead's direction

- His first words after round 24: *"The game is definitely way smoother."* That was your C++.
- The bar (C24.7): 25 a side, no slow motion in the opening clash on his laptop, game speed ≥ 0.97 (shipped ≈ 0.82–0.83).
  Pace owns the think-rate lever this round; you own the price of water and the ports.
- His last two playtests were on maps with water (the Locks, the Crossing). The pricing workload has none.

## Where things stand (round 24's close; VERIFY)

- ON in C++: drive, the route tail, `_around_fire`, situation, decide, the two TacticalQuery functions, dodge, avoid,
  cover, nav. OFF by price: `native_scan` (+1.1 % at 50 v 50 headless), `native_matchups`, `native_move`, `native_record`,
  `native_el` (laptop windowed `4ba8fd0b` −0.37 %, se 0.67, on foundry/parade, which have no water; headless Sumps
  elements 4.21 → 3.27 ms).
- `ElementPlan.build` (~1 ms a tick) is NOT ported this round: brains is likely to change it (C25.2).
- Brains (seats, the crossing, the give-way) and pace (the think rate) will change behaviour this round. Every change
  to a ported function breaks its live-function proof until the C++ follows (C25.2): that port is your first priority
  the moment it is asked for.

## Backlog (in order)

**N5a — a water map in the laptop workload.** Add `locks` (and `crossing`, his last map) to `make native-tick-profile`'s
arenas as a second workload (keep foundry + parade as the bar's workload; C24.7's definition does not move without
him). Re-take the shipped baseline on it (laptop, C25.4: ask the orchestrator first), n = 6 paired, and file it under
`streams/references/round25/perf/laptop/`.

**N5b — `native_el` re-priced on water.** ABBA, paired, on N5a's water workload, by the in-contact rule; rule ON or OFF
and write it in `native.md` and the switch's comment. If ON: the proof against the live functions on every map with
water must hold after brains' F2 (re-run it after CP2).

**N5c — keep the C++ in step (C25.2), whenever asked.** Brains or pace sends a GDScript diff to a ported function: port
it on your branch, equal answer by the live-function proof, name the commit to the orchestrator, who merges the pair.
This interrupts N5a/N5b/N5d.

**N5d — the weapon scan in contact.** `native_scan` was priced headless at 50 v 50; re-price it in contact on the
laptop's bar workload (lesson 279). Rule it.

**Stretch:** (a) the Android device proof (round 24 stretch b: the cross-compile works); (b) with pace, a breakdown of
what is left between the shipped speed and 0.97 by component, on both workloads.

## How to verify

`make native && make remote T=check` (the TRAP in `native.md`: plain `make test` does not rebuild the library; on
builder0's main lane run `make remote T=native` after a merge). The proofs (`tests/test_native*.gd`), `native-proof`,
`ai-parity`, `element-digest` unchanged for every equal-answer port. Laptop prices through `make native-tick-profile`
under C25.4. Every number with commit, machine, workload, n and se.

## Don't touch

Behaviour in `movement.gd`, `tank_brain.gd`, `game/tactics/**` (a port follows the GDScript; it never leads it), pace's
files, and the *Nobody this round* list in `workstreams.md` *Round 25*.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current; started 2026-10-10 ~06:00 PDT from `fccc520c`, on flightdeck = the laptop)_

### Plan (in order)

1. **N5a** the water workload in `make native-tick-profile` (`NATIVE_TP_WORKLOAD=water`: locks + crossing), its window
   set from where the fight starts on those maps; the laptop baseline (shipped `on` v all-native `off`) n = 6 paired.
2. **N5b** `native_el` priced in the same laptop session as a third arm (`el` = `--brains-on=native_el`), ABBA; rule by
   the in-contact rule (≥ 2 % of the tick's scripts outside 2 se); headless builder0 Locks as the second reading.
3. **N5d** `native_scan` on the bar's workload (foundry + parade), arms `on` / `scan`, same session if the orchestrator
   gives one window, otherwise the next.
4. **N5c** whenever brains/pace send a diff to a ported function (interrupts everything).
5. Stretch: (b) the breakdown to 0.97 by component on both workloads (from the session's logs); (a) Android.

### Decisions (reversible; one line each)

- **Water window 12–24 s, not 8–20:** on the Crossing the first hit lands at 12–14 s (builder0, 3 seeds), on the Locks
  at 8–10 s; 12–24 holds both maps' opening clash and keeps the bar's 12 s length. The bar's workload is unchanged.
- **One session = one workload's table:** `native-tick-profile` moves the previous `build/tp-*.log` to `build/tp-prev/`
  first, so two workloads are never pooled by accident.
- **`el` as a third arm of the baseline session, not its own session:** the arms are alternated ABBA anyway, and it
  halves the laptop time C25.4 serializes.

### Baseline

- `fccc520c` builder0 `make remote T=check`: exited 0, **2338 passed, 0 failed**, 23 targets ALL JUDGED (log
  `build/native-check-fccc520c.log`).

### Done (each with commit, machine, workload, n)

- **N5a tooling** (`c1633ed9`): `NATIVE_TP_WORKLOAD=water` (`NATIVE_TP_WATER_ARENAS=locks crossing`,
  `NATIVE_TP_WATER_WINDOW=12,24`); `tick_profile_paired.py` now prints elements and priority 0 (tank + match) paired in
  ms (the void rule), alive at the window's ends and a per-arena line; `tests/native/fight_onset.py` (first hit, first
  kill, hits per 2 s, alive, from recordings). Evidence `references/round25/native/water-onset-fccc520c/`: builder0
  windowed, one session alternating maps (load ~16, so shares only): **elements 22 % of the tick on the Locks v 15–18 %
  on foundry/parade (7.0 v 4.4 ms)**.

### Waiting on

- The laptop (C25.4): asked the orchestrator 2026-10-10 ~06:30 for one ~45 min session (water: on/el/off; bar:
  on/scan).

### Questions for the lead

- None.

### Requests to other streams

- None yet.
