# Stream: perf (low-end hardware stays the target: the C++ follows every change, what pays is ported, the next step is priced)

> Read `_agents/orchestration.md` (the worker contract), `_agents/native.md` (everything: flags, hazards, the proof, what
> is ported, the seam rules, **N7: what a port must look like to pay**), `_agents/workstreams.md` *Round 26* (C26.2 is
> your first duty, C26.7 the laptop), round 25's native and pace reports (`streams/archive/round25/native.md`,
> `pace.md`, Status), and lessons 279–286. You own `native/**`, `game/ai/native/**`, `mk/native.mk`, `mk/pace.mk`,
> `brain_switches.gd` (others add one switch line), `cover_map.gd`, `combat_motion.gd`, `incoming_fire.gd`'s seam,
> `think_quiet.gd` and `tank_brain.gd`'s think-scheduling hunk, every `if BrainSwitches.native_*` seam on main, a NEW seam
> at the top of `TankBrain.act` and around `build_situation`'s non-core part, `tests/test_native*.gd`, `tests/native/**`,
> `tests/test_ai_think_lod.gd`, `tests/test_pace*.gd`, `tests/tactics/l1_speed_table.py`, `_agents/native.md`. Stretch
> only (P5): `game/theme/fx/render_levers.gd` and the effects it switches.

## The lead's direction (2026-10-10, before round 26's launch)

> *"so the game felt fine, but wouldn't we want to continue optimizing the framerate by migrating to C++ wherever
> possible? We're testing on a cheap laptop, but generally speaking we should target low performing hardware so that
> high end machines get really good gameplay"*

What he was told (`game_design.md` reading (9)): the clash at 20 a side felt fine to him, so no laptop-only cut is
forced; low-end hardware stays the target; the per-function migration has stopped paying (N7); every ported function
doubles the cost of a behaviour change; the step change would be the whole per-tick brain as ONE batched C++ pass, which
he decides once it is priced. Your job: keep what we have, take what pays, and price the step change honestly.

## Where things stand (VERIFY at main)

- ON in C++: drive (with `_avoid`, `_around_fire`, the k-turn leg), the route tail, situation's core, decide, the two
  TacticalQuery functions, dodge, avoid, cover, nav, `native_el`. OFF by price: `native_scan`, `native_matchups`,
  `native_move` (proof live), `native_record`. Weapon slices reverted (tag `n7-weapon-slices`).
- Laptop accounting at 20 a side (his preset, `379e0567` logs, native `59c3ecca`, n = 6): 37.8 ms wall per game tick vs
  34.4 needed for 0.97 — scripts 28.6, physics 0.6, outside the simulation 8.6. 0.881 of real time at 20 a side, 0.769
  at 25 (`--squad-cap=5`, lesson 285).
- N7's ranked list, after round 25's closing measurements: batched `t.poll` 0.1–0.3 ms (closed), `situation` past the
  core 0.5–0.9, `t.rate_progress` batched 0.4–0.7, `act` (whole, est.) 0.3–0.6, `feed.normalize` 0.2–0.3, the k-turn
  planner ≤ 0.1 (not built).
- Traffic and manoeuvre change mirrored functions this round (C26.2): their ports are yours.

## Backlog (in order)

**P0 — keep the C++ in step (C26.2), whenever asked; interrupts everything.** A diff from traffic (`_avoid`,
`Avoidance.solve`) or manoeuvre (`drive()`'s body, the k-turn leg's execution, the OFF geometry): port it on your branch,
equal answer by the live-function proof, name the commit to the orchestrator, who merges the pair back to back. For an
OFF port whose GDScript changes (`native_move`'s geometry): you may retire the port, seam and proof instead, if it will
never be switched on; say so in `native.md`.

**P1 — where the tick goes now (builder0 and laptop, his preset).** At current main, 20 and 25 a side (pinned, read
`ARMY_CAP_FIELDED`), the opening clash windowed (lesson 279): wall per game tick split into scripts by section (sub-laps),
native time, physics, and outside the simulation (render, UI, audio). This is P2's and P3's denominator; re-take it after
CP1 and CP3 (behaviour changes move it).

**P2 — the remaining batched ports that pay** (N7's rule: batched over the record, removes a crossing, or large per call).
In your own files and grants only: `act`'s prelude (seam at the top of `TankBrain.act`) and `build_situation`'s non-core
part; anything in `game/tactics/**` (`t.rate_progress`, `feed.normalize`) is brains' this round: a grant request through
the orchestrator with the seam and file list, not an edit. Size with throwaway sub-laps BEFORE building (lesson 286);
each port proven equal and priced on the laptop (ABBA, paired, n ≥ 6, C26.7); ON only outside 2 se.

**P3 — the whole-brain batched pass, priced for his decision.** A design in `native.md` (written before any number, lesson
278): which per-crew work moves into one C++ pass per tick over the record (think, act, the polls), what stays GDScript
(tactics/elements, the CPU commander), the record's shape, how a future behaviour change would land (both languages, or
the C++ as the ONLY implementation with GDScript retired for those functions — the trade spelled out: speed of AI
iteration vs frame time). A calibrated estimate: prototype the single hottest slice of it batched (throwaway branch),
measure it, scale the rest from it, and give ms per tick at 20 and 25 a side on the laptop, plus days of work and what
other streams would be frozen meanwhile. Write the decision for him in player terms ("the laptop could field 25 a side at
full speed / stays at 20; AI changes take ~N× longer for M weeks"), with one recommendation, in Status and to the
orchestrator.

**P4 — think-rate and quiet, re-checked** (pace's round-25 instruments): after CP1/CP3, confirm no traffic or manoeuvre
change made crews think at the engaged rate more often (the quiet census, `test_ai_think_lod.gd`).

**P5 — stretch: a lighter look he can switch on.** A render preset below the laptop's (fewer effects drawn: list them,
each priced on the laptop by removal, lesson "attribute a cost only by removing it"), default look unchanged on every
machine; his LOOK toggle reaches it; screenshots side by side, looked at. Does not change the army cap (C25.6) unless the
orchestrator rules it.

## How to verify

`make remote T=check`; `make native-proof`, the live-function proofs; `make native-tick-profile` on the laptop through the
orchestrator (C26.7); `ai-ab-match`/`ai-ab-play` for prices. Every number: commit, machine, workload, n, pinned cap.

## Don't touch

Traffic's and manoeuvre's GDScript (you port THEIR diffs, you don't author behaviour), `game/tactics/**` without a grant,
`game/control/**`, `game/theme/**` except the P5 grant.

## Waiting on the lead

P3's decision (after you price it).

## Status

_(the worker keeps this current; started 2026-10-10 23:11 PDT from `b57838ed`, on flightdeck = the laptop; heavy runs on
builder0. Laptop sessions only when the orchestrator grants one, C26.7.)_

### Plan (in order; reasons one line each)

1. **Baseline:** `make remote T=check` at `b57838ed` (builder0).
2. **P0 (C26.2)** whenever traffic or manoeuvre send a diff: interrupts everything below.
3. **P1, builder0 half first** (no laptop needed): `native-tp-headless` at 20 and 25 a side on the bar's arenas
   (foundry, parade) with every sub-lap, then the laptop half (`native-tick-profile`, arms `s20@20` / `s25@25`, his
   preset) when the orchestrator gives a slot. Re-taken after CP1 and CP3.
4. **P2 sizing before building** (lesson 286): throwaway sub-laps in `act`'s prelude and `build_situation`'s non-core
   part (s.squad, s.cover_spots, s.cover_fire, s.incoming; s.tactics is tactics': report only). Build only what the
   N7 test says can pay; price each on the laptop (ABBA, n >= 6).
5. **P3 design first** (in `native.md`, before any number, lesson 278), then the hottest slice prototyped batched on a
   throwaway branch, priced, scaled; the decision for him in player terms.
6. **P4** after CP1/CP3: the quiet census (`make pace-census`), `test_ai_think_lod.gd`.
7. **P5 stretch:** a lighter laptop look, each effect priced by removal.

### Baseline

- `b57838ed`: the orchestrator's launch check (builder0): `make check exited 0`, 2377 passed / 0 failed, ALL JUDGED,
  thirteen unmoved, determinism `762a0576f944f5b7`. Mine was cancelled on the orchestrator's word (builder0 load 15).

### P3 — the decision for him (written for the orchestrator to take to him; `native.md` *P3* has the design, the
### prototype and the arithmetic)

**In player terms:** today his laptop plays 20 a side at 0.88 of full speed in the opening clash (it felt fine).
Rewriting the whole vehicle brain as one C++ pass would, by our estimate, let the laptop play **25 a side at full speed
with room to spare** (and 20 a side with a third to spare). It costs **about five weeks** of one stream (4-7), during
which AI changes in the parts being rewritten either wait or are written twice; afterwards every AI change costs
**~1.5-2x** (written in both languages and proven equal) — or we make the C++ the only brain, and the browser version
keeps today's AI.

**Halfway point:** the "execute" half alone (driving, gunnery: the code that changes least) is ~2 weeks and gets 20 a
side to **just full speed** (~1.0), not 25.

**Recommendation (one):** do it in two stages, both proven equal (nothing he sees changes): **stage 1, the execute half,
next round** once this round's driving changes (traffic's convention, manoeuvre's reverse and three-point turn) have
landed, measured on his laptop; **stage 2, the think half, only if he wants bigger armies on the laptop** (it is the
part brains reshapes every round, so it is cheapest once his AI direction settles).

**The evidence and its limits:** the prototype (`local/perf-p3-proto` tip `b32c6a45`, never merged; builder0, n = 3;
equal answer 0/23 000) measured the C++ at 5 % of its GDScript for a tight loop and one shared gather at ~0.5 ms a
tick; the estimate assumes branchy brain code reaches 15 % (8-25 %) and the pushed state costs 1-2 gathers. Nothing
here is a laptop measurement: the laptop's split (P1, queued) re-bases it, and stage 1's own laptop price is the
check on the whole estimate before stage 2 is started.

### P0 (C26.2) log

- **traffic CP1b (`_avoid` → `Traffic.shape`)**, heads-up 2026-10-10 23:50 at traffic `5b881905`. Prepared as a callback
  (`c122bfc4`, inert until `traffic.gd` exists). **Sized** before any merge (orchestrator's rule; throwaway
  `local/perf-cp1b-size` `40029e1d` = perf + traffic 5b881905 + laps; builder0 light lane, load ~18, Sumps 25 a side +
  leaders, 8-20 s, seeds 92721 31337 5988): `Traffic.shape` 34.5-37.5 calls a tick, **2.79-2.86 ms a tick** (~80 us a
  call), `Traffic.refresh` **0.75 ms** (once a tick), the native->GDScript crossing ~0.5 ms on top (callback clocks
  off 3.1 + refresh 20 + shape 81 us a drive x 39 drives). **Ruled (orchestrator, 00:30):** HOLD the C++ port; traffic
  redesigns to <= 0.5 ms a tick on the GDScript path (ORCA's neighbour table, once per meeting pair, skip idle crews);
  perf ports the settled version when traffic names it, then prices whether the rest is worth C++. The harness was
  handed to traffic (same command, same laps).
- **manoeuvre M1 (CP2)**: `order = _manoeuvre(order)` at the top of drive()'s body; heads-up 00:25. To be called back
  at the top of drive_native's drive, sized the same way (a new per-drive crossing) when its hash arrives.

### Done (each with commit, machine, workload, n)

- **P1, builder0 half** (`b57838ed`, builder0 light lane UNDER LOAD ~16 from five streams' checks, so read SHARES, not
  ms; headless `native-tp-headless`, leaders on both sides, window 8-20 s, seeds 92721 31337 5988, n = 3 per cell;
  table `tests/native/p1_table.py`, evidence `references/round26/perf/p1-headless-b57838ed/table.txt`). Share of the
  tick's scripts, foundry / parade (the bar's arenas) at 25 a side, 20 a side alike within ~1 point:
  **controllers 74-75 %** = think 41-44 % (gate: t.poll 7, t.rate_progress 4, t.incoming 1.5; situation 15-16, of it
  the native core 6 and the non-core GDScript ~7.5 (s.tactics 2, s.squad 1.5, s.cover_spots 1.4, s.cover_fire 1.1-1.6,
  s.incoming 1); decide (native) 5; act 5-6, its prelude 1.5) + execute 29-30 % (move 12-14, of it the native drive
  10-11; weapon 12.5, of it scan 5 (mostly the engine's sight ray), aim 1.5, lanes 2) + wall_contact 1.2;
  **elements 15-16 %**; tank 5-6; match 3.5-4; engine-call laps (rays, nav) 2.7 %. The Sumps (water, pits) differs:
  elements 26 % (25) and 30 % (20), controllers 64 / 58 %. The laptop half (outside the sim, render) waits for the
  orchestrator's slot (C26.7, queued first).
