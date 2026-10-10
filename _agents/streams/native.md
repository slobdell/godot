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

_(the worker keeps this current)_
