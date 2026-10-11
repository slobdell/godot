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

Nothing: P3 decided 2026-10-11 (stage 1 next round).

## Status

_(the worker keeps this current; started 2026-10-10 23:11 PDT from `b57838ed`, on flightdeck = the laptop; heavy runs on
builder0. Laptop sessions only when the orchestrator grants one, C26.7.)_

### The report (read this first; kept current)

**State (2026-10-11 02:40):** P1 (both halves), P2, P3 (decided by the lead), P5 (measured, not shipped) are done; P0
and P4 wait on other streams (traffic's settled CP1b, manoeuvre's M1 hash; CP1a/CP1/CP3 on main). The branch's CODE
equals main `b57838ed` plus two measurement scripts (`tests/native/p1_table.py`, `tests/native/r_paired.py`); every
other commit is docs and references. Merge point: the newest *Green commits* line.

**Done, with numbers:** P1 builder0 shares and the laptop split (20 a side 0.918, 25 a side 0.803; a game tick at 20
= scripts 27.8 + physics 0.6 + outside the sim 8.0 ms, 2.0 short of 0.97); P2 (no port in my grant pays; one free
GDScript reorder in brains' `_cover_spots`, relayed); P3 (the whole-brain pass priced: 46 % of the tick's scripts,
36-52; stage 1 re-priced in its own per-crew shape: 11-15 %, laptop 20 a side 0.96-1.03; the lead chose stage 1 for the
next round; launch design in `native.md` *Stage 1*); P5 (LIGHTER +0.013, no lever passes: not shipped; the laptop is
CPU-bound by the simulation); P4's baseline census (engaged share 12.5 / 37.8 / 31.6 % on crossing / foundry / parade).

**Decisions (one line each):** CP1b's port held for traffic's redesign (orchestrator, 3.6 ms measured); the callback
prep reverted (C26.10); stage 1 stays per crew, equal answer (a declared batched execute buys +0.005); P5 not shipped
by the keep rule written before its run.

**What to playtest:** nothing new from perf this round (no behaviour or look ships).

**Next steps:** P0 when traffic names its settled CP1b (port `Traffic.shape`/refresh into C++ reading the record, live-
function proof, price) and when manoeuvre sends M1's hash (size the `_manoeuvre` callback; port its gate if > 0.1 ms);
P4 re-run `make pace-census` after CP1 and CP3 against the baseline; P1 re-taken after CP1 and CP3 (laptop, a slot).

**Merge notes:** none (no shared file changed in the final code).

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

### Green commits

- **`d397a39e`** (P5 levers + test, the inert CP1b prep `c122bfc4`): builder0 `make check exited 0`, **2382 passed, 0
  failed**, 23 targets ALL JUDGED, thirteen unmoved, determinism `762a0576f944f5b7`
  (`references/round26/perf/checks/perf-check-d397a39e.txt`). Everything after it is docs and references.

### Baseline

- `b57838ed`: the orchestrator's launch check (builder0): `make check exited 0`, 2377 passed / 0 failed, ALL JUDGED,
  thirteen unmoved, determinism `762a0576f944f5b7`. Mine was cancelled on the orchestrator's word (builder0 load 15).

### P3 — DECIDED 2026-10-11 by the lead: "Driving+shooting half (Recommended)" — stage 1 next round, after CP1-CP3,
### priced on his laptop; launch design in `native.md` *Stage 1* (`7186872e`). What he was shown (written for the orchestrator to take to him; `native.md` *P3* has the design, the
### prototype and the arithmetic)

**In player terms:** today his laptop plays 20 a side at 0.88 of full speed in the opening clash (it felt fine).
Rewriting the whole vehicle brain as one C++ pass would, by our estimate, let the laptop play **25 a side at full speed**
(1.09-1.23 uncapped) and 20 a side with a fifth to a third to spare. (Corrected 01:10: already-native time counted at its
marshalling only, r up to 0.3: the saving is 46 % of the tick's scripts, 36-52 %.) It costs **about five weeks** of one stream (4-7), during
which AI changes in the parts being rewritten either wait or are written twice; afterwards every AI change costs
**~1.5-2x** (written in both languages and proven equal) — or we make the C++ the only brain, and the browser version
keeps today's AI.

**Halfway point:** the "execute" half alone (driving, gunnery: the code that changes least) is ~2 weeks and gets 20 a
side to **just full speed** (0.975-1.0), not 25 (0.86-0.88).

**Recommendation (one):** do it in two stages, both proven equal (nothing he sees changes): **stage 1, the execute half,
next round** once this round's driving changes (traffic's convention, manoeuvre's reverse and three-point turn) have
landed, measured on his laptop; **stage 2, the think half, only if he wants bigger armies on the laptop** (it is the
part brains reshapes every round, so it is cheapest once his AI direction settles).

**The evidence and its limits:** the prototype (`local/perf-p3-proto` tip `b32c6a45`, never merged; builder0, n = 3;
equal answer 0/23 000) measured the C++ at 5 % of its GDScript for a tight loop and one shared gather at ~0.5 ms a
tick; the estimate assumes branchy brain code reaches 15 % (8-30 %), already-native sections save 30-50 % (their marshalling) and the pushed state costs 1-2 gathers. Nothing
here is a laptop measurement: the laptop's split (P1, queued) re-bases it, and stage 1's own laptop price is the
check on the whole estimate before stage 2 is started.

### P5 (stretch) — the lighter look: MEASURED, NOT SHIPPED (the pre-registered keep rule; ruled by the orchestrator 02:40)

**Finding: at 20 a side his laptop is held back by the simulation's CPU, not by drawing; drawing cuts below LOOK LIGHT
buy at most ~0.013 of game speed.** P5-2 (`354052f5`, flightdeck, 20 a side pinned, ABBA n = 6, valid; R paired by
`tests/native/r_paired.py`, `references/round26/perf/laptop/tp-p52-354052f5/`), each lever removed from LIGHTER: R
(outside the sim, ms a frame) +1.02 (se 0.58) without `scale_065`, +0.68 (se 0.95) without `no_glow`, +0.21 (se 0.73)
without `fx_lean`, -0.36 (se 0.81) without `crowd_low`; game speed moves <= 0.008 each. None removes >= 2 % of R outside
2 se, so by the rule written before the run none stays, and LIGHTER does not ship (a look that makes the game uglier
for no measured speed). The code is reverted on the branch (`6f5f9b9f`, `36ec01ff`; the build commits `d397a39e`,
`e2f20843` kept for the record; the Units grant unused). It backs stage 1 as the next step. What was built:

Built (`d397a39e`, check running): four levers in `render_levers.gd` and `crowd_system.gd` (the grant), all through the
existing quality path: `scale_065` (65 % of the lines), `no_glow`, `fx_lean` (effects 96, scorch marks 8, sprays 3,
overdraw 2000 m2, no ground splats), `crowd_low` (the low tier's crowd). Preset **`lighter`** = laptop's five + those
four; OPT-IN only (`--render-preset=lighter` or the LOOK toggle, which now cycles FULL -> LIGHT -> LIGHTER); the adapter
never picks it, so no machine's default look moves; the stands stay lit (his round-16 tap). `test_pace_lighter_look.gd`.
**Pre-registered laptop sessions (written 2026-10-11 01:55, before any P5 run; C26.7, when the orchestrator grants):**
- **P5-1 (~20 min):** `make native-tick-profile BUILD_DIR=.laptop-tp NATIVE_TP_ARMS="light@20=--render-levers=scale_075,lights_2,no_env_fog,no_haze,crowd_medium lighter@20=--render-levers=scale_075,lights_2,no_env_fog,no_haze,crowd_medium,scale_065,no_glow,fx_lean,crowd_low"`
  (bar workload, 20 a side pinned, ABBA, n = 6). Read: game speed, R (outside the sim, per frame), the tick's scripts
  (must NOT move: a look cannot change the sim; a moving prio0 voids the session). Reported as measured; no ON/OFF
  ruling (an opt-in preset changes no default).
- **P5-2 (~40 min), each lever priced by REMOVAL from lighter:** arms `lighter` and `lighter` minus each of `scale_065`,
  `no_glow`, `fx_lean`, `crowd_low` (five arms, ABBA order cycled, n = 6). A lever stays in `lighter` only if removing
  it costs >= 2 % of R outside 2 se; otherwise it comes out (it changes his picture for nothing).
Next: side-by-side frames on builder0 (`look-parity-shots`, sumps, his window and the phone: full / light / lighter),
looked at; then each lever priced by REMOVAL on his laptop (C26.7, when slots allow); the army cap needs the Units
request before it ships (Requests).

**P5-1** (slot granted 01:48; `354052f5` = code e2f20843, flightdeck, laptop-built library, his window, bar
workload 8-20 s, 20 a side pinned, ARMY_CAP_FIELDED 20 v 20 x12, ABBA n = 6, load <= 3, prio0 unmoved -0.05 ms (se 0.06):
valid; `references/round26/perf/laptop/tp-p51-354052f5/`): LIGHTER v LIGHT game speed **+0.013 (se 0.010): not
outside 2 se**; 0.917 v 0.904. Outside the sim R ~17.8 v ~18.9 ms a frame (-1.1); frames 76.6 v 87.9 ms. The tick's
scripts read -3.5 % (se 1.9) and the controllers -4.2 % (se 1.8): a look cannot change the sim, so that is the windowed
fights diverging (lesson: hulls alive differ per pair), not the levers. **Reading:** at 20 a side his laptop is held
back by the CPU's simulation, not by drawing; a lighter look buys about a hundredth of game speed.

### P4 — the quiet census, baseline before CP1/CP3

`354052f5` (code = b57838ed's behaviour), builder0 light lane (display :0, Iris Xe), `make pace-census` (perf-fight 25 a
side, crossing / foundry / parade x 92721 31337 5988, census window 8-20 s; `references/round26/perf/p4-census-354052f5/`):
crew-ticks at the ENGAGED fight rate: **crossing 12.5 %, foundry 37.8 %, parade 31.6 %**; the round-24 quiet (in reach,
not in the shooting) 57.2 / 59.6 / 62.5 %; smart-quiet share of that 16.8 / 10.9 / 16.1 %. After CP1 and CP3 the same
command is re-run; a change is a finding if the engaged share rises by more than the seed spread (to be read from the
three seeds per arena).

### P2 — sized before building (lesson 286); verdict: no C++ port in my grant pays

Throwaway laps (`local/perf-p2-size`, patch `references/round26/perf/p2-sizing/p2-laps.patch`; builder0 light lane,
load high so ratios; `b57838ed` + laps, foundry 25 a side + leaders, 8-20 s, seeds 92721 31337 5988, n = 3; tick
scripts 53.3 ms; 12.4 thinks a tick; `references/round26/perf/p2-sizing/parts.txt`), ms a tick:

| part of build_situation's non-core | ms | of it | shape (N7) |
|---|---|---|---|
| s.squad 1.08 | | `_order_context` 0.67, objective/centre 0.14, squad_context 0.09, overwatch 0.09 | per crew, reads OrderFeed/ElementFeed/SlotGround objects: ~0 as C++ |
| s.cover_spots 0.83 | | **`threat_list` 0.51 computed BEFORE the "am I worn?" early-out**, find_cover (native) 0.05 | a GDScript reorder, not a port |
| s.cover_fire 0.92 | | target loop 0.28, find_cover_fire (native) 0.29, request 0.09 | per crew; the query is native already |
| s.incoming 0.63 | | `Match.incoming_projectiles` 0.37 (match's), the filter 0.25 | per crew, ~0 |
| s.tactics 1.23 | | SquadTactics (tactics': not mine) | -- |
| act.prelude 0.82 | | (round 25: 35 us a call, not batchable) | ~0 |

By N7's test none of these is batched over the record, removes a crossing, or is large per call next to what it
marshals, so **nothing is ported**: they belong to the whole-brain pass (P3), where they read the shared record. **The one
free saving is GDScript, in brains' file:** `_cover_spots` builds `threat_list` (a sort of every visible contact) for
every thinking crew and only then returns `[]` for a crew that is not worn; testing toughness first gives the same
answer and saves ~0.4-0.5 ms a tick (~1 % of the loaded tick). Sent to brains through the orchestrator (Requests).

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
- **c122bfc4 (the callback prep) REVERTED** (`878af895`, the orchestrator's C26.10: traffic settles its rule first,
  then a C++ port, never a callback). Traffic's v2 (`b1e4f15a`: a flat per-team table rebuilt every 3 ticks, a per-crew
  answer cached and re-solved every 6 ticks, a crossing verdict latched per pair -- state, not pure functions) is
  being measured by traffic on the GDScript path; perf ports the settled version when traffic names it.
- **manoeuvre M1 (CP2)**: `order = _manoeuvre(order)` at the top of drive()'s body; heads-up 00:25. To be called back
  at the top of drive_native's drive, sized the same way (a new per-drive crossing) when its hash arrives.

### Done (each with commit, machine, workload, n)

- **P1, laptop half** (slot granted 01:10, ran 01:14-01:29; `d84f7503` = b57838ed game code + inert prep; flightdeck,
  his preset, laptop-built library; bar workload foundry + parade 8-20 s, seeds 92721 31337 5988; arms s20@20 / s25@25
  ABBA n = 6 paired; ARMY_CAP_FIELDED 20 v 20 x6 and 25 v 25 x6; load <= 2.7, one Godot; evidence
  `references/round26/perf/laptop/tp-bar-s20s25-d84f7503/`): **game speed 0.918 at 20 a side (sd 0.015), 0.803 at 25**
  (+0.115, se 0.011); tick scripts 27.8 v 33.5 ms (-16.9 %, se 1.7). **Where a game tick goes at 20 a side:** wall 36.4
  ms = scripts 27.8 (controllers 19.9 = think 11.8 + execute 7.3 + wall contact 0.3; elements 4.5; tank 1.5, match 0.9,
  visfield 0.4) + the engine's physics step 0.6 + outside the simulation 8.0 (R 17.2 ms a frame over 2.15 ticks); 0.97
  needs 34.4: **2.0 ms a game tick short**. At 25: wall 41.5 ms a game tick (frame 120.8 over 2.91 ticks, at the
  3-tick cap) = scripts 33.5 + physics 0.6 + outside 7.4. The laptop's shares match builder0's (controllers 72 %, think 42.5, execute 26.3, elements 16). Session to
  session the base drifts (round 25: 0.881-0.896 at 20, 0.769-0.792 at 25), so compare arms only within a session.

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

### Requests to other streams

- **brains (through the orchestrator), 2026-10-11:** in `TankBrain._cover_spots`, test the toughness/shield early-out
  BEFORE `TankBrain.threat_list` (keep `threats.is_empty()` as the second test). Same answer for every crew; ~0.4-0.5 ms
  a tick at 25 a side (builder0 headless, P2's table). Pre-register the thirteen lines and determinism unmoved.
- ~~orchestrator: `Units.squads_for_preset` caps "lighter" too~~ GRANTED and done (`e2f20843`, with its test).
- **orders (game/ui, minor, for when P5 merges):** the LOOK button's tooltip (`hud_skin.gd` line ~78) describes two
  looks; a third (LOOK LIGHTER: 65 % resolution, no glow, fewer effects, the smallest crowd) should be added.

### Questions for the lead

- None open (P3 decided 2026-10-11).
