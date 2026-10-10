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

**N6 — the army cap follows the render preset (C25.6, added 2026-10-10 noon by the orchestrator; above everything but
N5c and the native_el check).** His pick: *"20 now, C++ continues"*. `Units.max_squads()` = 4 when
`RenderLevers.preset() == "laptop"`, else `MAX_SQUADS` (5, still the compile-time ceiling). It is read once at match
setup and applied to BOTH sides. Headless is desktop, so baselines don't move. The LOOK toggle counts from the next match;
in a network match the host's value is the match's; credits are unchanged. A saved 5-squad army keeps its first four
squads on the laptop and says so; the garage shows the cap the match will use. Granted: `game/units/units.gd`,
`army_catalog.gd`, `army_draft.gd`, `garage_opponent.gd`, `credits.gd`, `doctrine.gd`'s player cap,
`squad_consolidation.gd`'s `for_player` default (brains' file: one additive line, tell brains), and the tests that pin
5. Pass: a unit test per rule; `make skirmish` on the laptop fields 4 a side (log + a garage screenshot, looked at); the
laptop number at 20 a side re-taken through the real skirmish path (ask the orchestrator for the slot, C25.4).
**After N6:** the next C++ ports, ranked by Status' list. ElementPlan.build stays excluded (brains'); anything needing a
grant (tactics' polls) goes to the orchestrator first, with the file list and the seam.

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

### The report (read this first)

**Merge notes. GREEN, merge here: `40060c44`** (builder0, `make check exited 0`, 2374 passed, 0 failed, 23 targets ALL
JUDGED, sim-baseline/determinism passing; = N6 + the planning hint + main `6f24bd76` (brains F3'); log
`references/round25/native/native-check-40060c44.log`). Earlier: `3c9419c5` (builder0, 2338/0 ALL JUDGED: native_el ON as its
own commit `0988ed88`). Since then: **N6 (C25.6)** green at `94c26255` (builder0, `make check exited 0`, 2365 passed, 0
failed, ALL JUDGED), then mk help lines / docs (`379e0567`), the laptop evidence, and main `13de4dc6` merged
(`a2c85757`); the final check of the tip is named in the newest Done line once it is green.

**N6 changes game behaviour on the laptop preset only** (headless/desktop unchanged: the thirteen lines and
determinism are the proof): 4 squads / 20 a side for both sides, read once at skirmish setup; `--squad-cap=N` pins it
for measurements. Files (granted): units.gd, army.gd, army_catalog.gd, army_draft.gd, garage_opponent.gd,
garage_screen.gd (the cap note only), skirmish_mode.gd, squad_consolidation.gd (one line, brains acknowledged),
mk/fx.mk + mk/ai.mk (perf targets pin or say so), verification.md.

**Since 40060c44 (merged as main 840507d7):** main `8e42247e` merged (`4a03c482`); N7 sized and built in part, then
stopped on measurement (weapon slices proven equal but ~0: reverted, tag `n7-weapon-slices`; the k-turn planner sized
at <= 0.1 ms: not built); the lesson and the re-ranked list in `_agents/native.md` *N7*. The branch's code = main's
merge (no net code change since 40060c44 besides main's); the tip's check is named in Done when green.

**Done this round:** N5a, N5b (`native_el` **ON** on a fresh pre-registered n = 12), N5d (`native_scan` OFF), stretch
(b), the 20-a-side measurement (0.896, --size path; 0.881 through the real cap path), the remaining ports priced, N6.
**Waiting:** N5c (brains' "don't reverse into a squadmate" is OFF: no longer reproduces; F3' touched no ported function, only additive slot_ground helpers); the orchestrator's pick of the next port.  **Blocked:** stretch (a), no Android device.

**What to playtest:** on his laptop, `make garage` (a saved 5-squad army opens with its first four and a status-line
note) and `make skirmish` (4 squads a side). His LOOK toggle changes the cap from the next match.

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

- **native_el's proof after CP2** (main `13de4dc6` merged, `a2c85757`, builder0): element digest over crossing locks gorge
  pit sumps docks terminus_canal x 4 squads x 2 seeds x drills on/off, `native_el` on (default) = `--brains-off=native_el`:
  both `21db878fc7aebc9bd30bcbb445eded8a` (112 runs, 0 missing). `references/round25/native/el-proof-after-cp2/`.
- **N6 (C25.6) the army cap follows the render preset**: green `94c26255` (builder0, 2365/0 ALL JUDGED);
  `tests/test_native_army_cap.gd` 12 tests (each rule, the role mix within 1.5 vehicles of proportional for every faction
  x 4 seeds, --squad-cap). Laptop smokes (`379e0567`, `references/round25/native/n6-smokes-379e0567/`, screenshots
  looked at): the garage note and 4 x 5; garage FIGHT 20 v 17 (the CPU's credits) in 4 squads; faction skirmish 20 v 20.
  **Measured through the real path** (pre-registered, `379e0567`, flightdeck, bar, real v s25 ABBA n = 6, ARMY_CAP_FIELDED
  20 v 20 / 25 v 25 every run, nothing voided): game speed **0.881** v 0.769 (+0.111, se 0.013); scripts −18.4 %
  (se 1.23). `references/round25/perf/laptop/tp-bar-real20-379e0567/`.
- **20 a side MEASURED** (pre-registered, `48f2d843` = native_el ON + tooling, flightdeck, bar workload, seeds 92721
  31337 5988, s25 v s20 ABBA, n = 6 paired, nothing voided): game speed **0.896** v 0.792 at 25 (+0.105, se 0.015;
  foundry 0.883, parade 0.910); scripts 28.5 v 34.0 ms (−16.1 %, se 1.84). NOT 0.97. The clock averages 2.43 ticks a
  frame there, so the saturated model overstates (0.934): slow frames still hit the cap. Evidence
  `references/round25/perf/laptop/tp-bar-s20-48f2d843/`.
- **N5b `native_el` ON** (fresh pre-registered n = 12, `b1884509`, flightdeck, water workload, seeds 4242 777 13 2024 8191 60601,
  ABBA, no foreign Godot): tick −4.85 % (se 0.47), locks −5.11 (0.67), crossing −4.60 (0.69); speed 0.770 v 0.737; elements
  −2.16 ms (se 0.14); prio0 +0.008 (se 0.019); controllers per hull alive +1.21 % (se 0.76, not ruling). Switch flipped ON.
- **N5a tooling** (`c1633ed9`): `NATIVE_TP_WORKLOAD=water` (`NATIVE_TP_WATER_ARENAS=locks crossing`,
  `NATIVE_TP_WATER_WINDOW=12,24`); `tick_profile_paired.py` now prints elements and priority 0 (tank + match) paired in
  ms (the void rule), alive at the window's ends and a per-arena line; `tests/native/fight_onset.py` (first hit, first
  kill, hits per 2 s, alive, from recordings). Evidence `references/round25/native/water-onset-fccc520c/`: builder0
  windowed, one session alternating maps (load ~16, so shares only): **elements 22 % of the tick on the Locks v 15–18 %
  on foundry/parade (7.0 v 4.4 ms)**.

- **The laptop session** (07:21-08:10, granted by the orchestrator, `49e2bdcd` = main `fccc520c` + tooling; flightdeck,
  his preset, 25 a side, ABBA, n = 6 paired, a watcher logging foreign Godot processes; one bar pair voided for a
  brains process at 07:51:48 and re-run; `references/round25/perf/laptop/`, commit `2a895747`):
  - **N5a baseline, water** (locks + crossing, 12-24 s): shipped **game speed 0.763** (locks 0.80, crossing 0.72),
    tick scripts 38.2 ms; all native off 56.7 ms (+48.4 %, se 3.2), 0.537.
  - **N5b `native_el` on water: OFF by the letter**: tick −1.64 % (se 1.65); its segment, elements, −2.06 ms (se 0.33)
    of 8.75; controllers +1.20 ms (se 0.30) spread +4-5 % over every brain section, match, tank and engine rays
    (the windowed fights diverge: hulls alive differ by up to 2 a pair). builder0 headless ABBA, hashes equal on
    every pair (`references/round25/native/el-headless/`): elements' share 20 -> 16 % (Locks), 29 -> 22.5 % (Crossing).
    A pre-registered n = 12 follow-up (3 new seeds, pooled, same bar) proposed to the orchestrator.
  - **N5d `native_scan` in contact, bar: OFF**: −0.39 % (se 1.08); shipped 0.769, tick scripts 35.2 ms.
- **Stretch (b), the gap to 0.97** (`tests/native/tick_profile_budget.py`, `49e2bdcd`'s tree): saturated speed = 100/(R + 3S),
  model 0.768 v 0.769 measured. **Bar: 9.0 ms a tick short (25.6 % of the scripts), or 27 ms a frame from outside the
  sim alone (R 22.8); water: 9.5 ms (24.8 %)**. What equal-answer ports have left is ~2-3 ms a tick: porting alone
  does not reach 0.97 at 25 a side on his laptop. Sent to pace (their stretch-b request) with the full section split.
- **Rulings written** in `native.md` *Round 25: the two workloads* and the switches' comments (`8490e3ca`).

### What the remaining equal-answer ports buy (the orchestrator asked, 2026-10-10; an ESTIMATE, not a measurement)

Against the bar's gap of **9.0 ms a tick** (`49e2bdcd`, flightdeck, bar workload, shipped arm, n = 6: scripts 35.2 ms,
R 22.9 ms a frame, `references/round25/perf/laptop/tp-bar-49e2bdcd/`). Each section's ms is that arm's own windowed
split. **Calibration:** a port has removed 15-45 % of the section it replaces, not all of it (the seam keeps the
GDScript glue and the Dictionaries consumers read): `decide` ~1.5 ms (−4.3 %), the N4 group ~1.45 ms (−4.1 %),
`situation`'s core ~1 ms of 6.2, `scan` ~0.1 of 1.7 (its cost is the engine's sight ray). Below: 30 % of the section,
range 15-45 %. Days = port + proof + one laptop ruling.

| # | item | section now (ms a tick) | saves (ms a tick) | confidence | days | note |
|---|---|---|---|---|---|---|
| 1 | tactics' polls and progress (`t.poll` 2.72, `t.rate_progress` 1.37, `t.order_progress` 0.55) | 4.64 | **1.4** (0.7-2.1) | low | 4-5 | game/tactics is not native's: needs a grant, and C25.2 parity on files that change every round |
| 2 | `weapon` past scan (`lanes` 0.87, `aim` 0.72, the rest ~1.1) | 2.66 | **0.8** (0.4-1.2) | medium | 2-3 | |
| 3 | `act` (prelude, ENGAGE, combat_move, MOVE) | 2.48 | **0.75** (0.4-1.1) | low-medium | 3 | many callbacks into movement and tactics |
| 4 | `ElementPlan.build` (elements segment 5.6) | ≤ 1 | **0.75** (0.5-1) | medium | 2 | |
| 5 | `situation` past the core (`s.tactics` .80, `s.squad` .48, `s.cover_spots` .46, `s.incoming` .37, `s.cover_fire` .34) | 2.45 | **0.7** (0.35-1.1) | low | 3 | partly tactics' code: grant |
| 6 | turn on the proven-but-OFF ports as one pre-registered bundle (`native_scan` + `native_move` + `native_el`) | — | **0.5** (0-0.9) | medium | 0.5 | one laptop session, no new code |
| 7 | `feed.normalize` | 0.65 | 0.2 | medium | 1 | |
| 8 | the k-turn planner (a callback inside the native drive) | < 0.5 | 0.2 | medium | 1 | |
| | **all of it** | | **~5.3 (2.7-8)** | | **~17-19** | still short of 9.0 at the central estimate |

**Correction to the 2-3 ms pace quoted:** that figure counted only what native can port without a grant (items 3, 4,
6, 8). With grants into tactics and the rest of `situation` and `weapon`, the central estimate is ~5 ms, best case ~8:
**porting alone does not reach 0.97 at 25 a side on the laptop**, and it would take about three and a half weeks.
Items under ~0.7 ms (2 % of the tick) cannot pass the bar alone at n = 6 (se ~0.4 ms): they need bundling, pre-registered.

**20 a side, since MEASURED: 0.896, not 0.97 (Done, above).** The model this paragraph gave first: the controllers are per hull (contacts partly n²), so
scripts at 20 a side ≈ 0.75-0.8 × 35.2 = 26.5-28 ms, saving ~7-8.7 ms a tick: about the whole gap by itself, and with
item 6 (half a day) likely over it. One laptop session settles it: `make native-tick-profile NATIVE_TP_SIZE=20` (bar
workload, shipped arm, ~15 min). Native can run it whenever the laptop is free.

### N7 (granted 8e42247e; round 26's native-exec item started early): the weapon / act / k-turn bundle

Plan agreed with the orchestrator (2026-10-10 afternoon): build `native_weapon` (gunnery.gd's aim + lanes after the
scan: lead, Difficulty offset, cover, aim checks, Engagement.engage, the fire-lane hold), then `act` (tank_brain.gd),
then the k-turn planner (the native drive's `planned_reverse` callback, native-owned); each with its own equal-answer
proof against the LIVE GDScript (N2b pattern), each merged OFF on its own green; C25.2 holds. They are priced on the
laptop as ONE pre-registered bundle (one slot, told to the orchestrator first); if it misses the bar, it is reported
measured and nothing ships ON. The scan stays out (engine ray). Sizing: `references/round25/native/n7-weapon-split/`
(weapon's replaceable part ~1.4 ms of section headless; the k-turn planner 10-12 us a drive).
**State (2026-10-10 evening):** weapon slice 1 (`f5968c56`, the aim solution: 600 poses, 0 mismatches) and slice 2
(`148104c0`, Engagement.Lay.engage: 1200 poses, 0 mismatches) built, proven, OFF; native-proof with
`--brains-on=native_weapon` (+ leaders) on = off = ab = `b646df113768ddb8`. **Priced headless they save ~0**
(`ai-ab-match AB_SWITCH=native_weapon` x 3, builder0: controller band −0.4 / +0.4 / −0.2 %): a per-crew call with
10-16 arguments read off nodes costs what the GDScript did. The lanes slice is NOT built (the same shape). **Ruled (orchestrator): stopped; both slices reverted (`eafcfc10`, `cee722d8`), kept on the tag `n7-weapon-slices` (= `148104c0`) for a batched version.** The lesson and the re-ranked list: `_agents/native.md` *N7: what a port must look like to pay*. **Lesson:
only batched ports (one call over all crews, reading the native record) or removing the native drive's callbacks INTO
GDScript pay.** The k-turn planner sized (throwaway laps, `cc5f8da2`): ~0.13 ms a tick of GDScript, at most ~0.1 ms to win: not built; `act` only as a batched design, after
brains' F4 (tank_brain.gd's SUPPRESS arm + `_bounding_slot`, commit a438003f) is on main. The bundle's pre-registration (members,
config: laptop preset, `--squad-cap=5`, foundry + parade x 3 seeds, 8-20 s; pass: 2 % of tick scripts outside 2 se) is
committed here BEFORE any laptop run.

### Scope: a batched `t.poll` (the orchestrator asked, for round 26's plan; design + measurement only, no brains file edited)

**Measured** (builder0, headless `native-tp-headless`, Sumps 25 a side + leaders, 8-20 s, seeds 92721 31337 5988, n = 3;
`6bc6f52f` + throwaway laps on `local/native-laps-poll`, never merged; tick scripts 20.2 ms;
`references/round25/native/tpoll-scope/poll-split.txt`): `t.poll` **1.54 ms a tick** (47 calls: every crew every tick) =
element 0.63 (of it `ElementFeed.context` reads 0.43, 11.2 a tick) + order 0.50 (`OrderFeed.current` 0.28 + `key` 0.05,
11.5 reads a tick) + squad 0.23 (`game_match.squad_for`) + station 0.11 + home 0.03; `_due_to_think` 0.10. The rest,
~0.8 ms, is per-crew gate overhead (~17 us a crew a tick: the feed lookups, flags, the squad lookup).
**Why reads happen:** order: 2.2 a tick on the dirty flag (all 2.2 order changes a tick arrive this way), 9.3 on a
think tick with signals connected -- **those found a changed order 0 times**. Element: 1.8 on dirty, 9.4 on think --
and **1.7 element changes a tick were found ONLY by the think-tick read** (not signalled: the context changes without
`element_changed`, e.g. through the order verb or a slot); a crew sees those up to one think interval late. (For
brains: a fact, not a request.)

**The seam a batched C++ port would need:** tank_brain.gd `_think`'s prologue (lines ~566-603: home, `squad_for` +
`order_serial`, `_poll_order` 684-715, `_poll_element` 747-763, the station) replaced by one call over every crew,
fed by a per-crew record of: the order key (+ goal, verb, pace), the element feed key and context, the squad's serial,
the station. Those values are produced by GDScript objects (control's Orders, tactics' Elements/ElementFeed, Match's
squads), so the record would have to be PUSHED by them on every change -- or the batch crosses into them per crew,
which is the per-crew shape N7 measured at ~0. **C25.2 churn:** any change to Orders.current / goal_position /
pace_factor, OrderFeed.current / normalize / key, ElementFeed.context / normalize / changed, Element.feed_key,
Match.squad_for / order_serial, OrderFeed.station would need the C++ (and the push) changed with it: control's, brains'
and tactics' files, every round.
**Estimate, batched C++:** only the gate overhead can go (the reads stay GDScript): **0.1-0.3 ms headless (0.5-1.5 %)**,
for the largest churn surface of any port. **Not recommended.** The cheaper lever is GDScript, in brains' file: read the
order feed on the dirty flag only (the 9.3 think-tick re-reads found nothing): ~0.26 ms headless (~1.3 %), a
behaviour-neutral change IF the order signal is complete (pre-register: the thirteen lines and determinism unmoved);
the element reads cannot be dropped (they find real changes).

### Waiting on

- N5c: no diff sent yet by brains or pace.

### Blocked

- **Stretch (a) the Android device proof:** no device attached to the laptop (`adb devices` empty), no Android SDK
  or export templates installed. Needs his phone on USB with debugging on (a question below).

### Questions for the lead

- (Android, low priority) When convenient: plug an Android phone into the laptop with USB debugging enabled, so the
  native library can be proven on a real device (it already cross-compiles).

### Requests to other streams

- None.
