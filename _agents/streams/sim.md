# Stream: sim (the same windowed fight twice: find the Sumps fork at ticks 601–630, fix it, and make it unable to return)

> Read `_agents/orchestration.md` (the worker contract), `_agents/streams/archive/round16/sim.md` (*Repeatability: the
> same skirmish seed was a different fight* — your predecessor's whole investigation and the witness it built),
> `_agents/determinism.md`, `_agents/workstreams.md` *Round 17*. You own `game/match/**`, `game/tank/**`,
> `game/combat/**`, `game/units/**`, `game/modes/**`, `tests/combat/**`, `tests/scale/**`, `tests/test_match*.gd`,
> `tests/test_combat*.gd`, `mk/match.mk`, `mk/scale.mk`, `project.godot [physics]`, `_agents/determinism.md`. **Reading is
> unrestricted; the fix lands where the defect is** — if that is a path nobody owns this round (`game/theme/**` outside
> containers and audio, `game/camera/**`, `game/ui/**`, `game/control/**`), you make the minimal fix yourself and list it
> in merge notes; if it is another stream's path (`game/ai/**`, `game/tactics/**` brains; `game/arena/**` yard;
> `game/theme/audio/**`, `game/audio/**` guns), you send the finding to the orchestrator with the witness.

## The lead's direction

No words of his on this item; he put it in round 17 on 2026-10-03 (*"I want all 5"*) from the orchestrator's list. Why
it matters to him: **every before/after he is shown from a windowed run assumes the two runs are one fight**, and so
do recordings, replays and the lockstep the vision needs for ranked play (`vision.md`, `determinism.md` D1–D4). Round
16's perf record had to avoid windowed Sumps A/Bs because of this.

## Where things stand (round 16, sim's Status; every claim there has its run)

- **Mechanism 1, fixed `0010bcb4`**: the skirmish's fire RNG was unseeded (only the match runner called
  `seed_spawns()`). Now seeded from the launch `--seed`; three headless runs identical to tick 900;
  `test_match_fire_rng_seeded.gd`.
- **Mechanism 2, OPEN**: on builder0, windowed `--scripted` skirmish pairs (`make windowed-repeat`, `mk/match.mk`): the
  Terminus identical to tick 870; **the Sumps forked in ticks 601–630 in 2 of 3 pairs**; the pair that did not fork was
  the one hashing AND dumping every unit every tick from 560 (`REPEAT_EVERY=1 REPEAT_FLAGS=--hash-detail-from=560`,
  3 872 / 3 872 lines identical) — the printing changes frame pacing, which points at **a timing-dependent input on
  the windowed path**, not an RNG. Headless Sumps: three runs identical to 900. builder0's vsync'd frames crawl at about
  a tenth of real time.
- **Ruled out, with how**: nothing in `game/ai`, `tactics`, `control`, `match`, `tank`, `combat`, `units`, `arena` reads
  frame time, frame count or the wall clock for a decision (grep: every `Time.get_ticks_*` is profiling); `--scripted`'s
  orders are `create_timer`s in idle frames, deterministic under `--fixed-fps`; **the bridges/water suspect is killed**
  (the Sumps' bridges are static decks built once by `ArenaTerrain`; the physics census finds only `StaticBody3D` boxes
  on every map; the theme side creates no collider and no nav region, and its only `_process` is the light show).
- **Not ruled out — hypotheses, not facts; rank them by what the evidence allows before testing any:** (a) **the
  fog-of-war field's worker thread** (`game/match/visibility_field.gd` `threaded`: a look's cell marks run on a
  `WorkerThreadPool` thread, native and multi-core only, and the field runs only in a skirmish) — does any result land
  on a tick that depends on when the thread finished, and does anything the simulation DECIDES on read the field
  (intel, a brain's contacts) rather than only the HUD? The switch exists: `--sim-off=visfield_thread`; (b) navigation
  map synchronisation relative to the frame (the brains' profile notes `nav.is_ready` "gives the same answer between two
  nav syncs" — when is a sync, on the windowed path?); (c) a `_process`-driven node whose transform the simulation
  reads (the airship, the cutaway, a camera-relative effect) or a physics body moved outside `_physics_process`; (d)
  more than one physics tick per rendered frame taking a different path than one (catch-up ticks under the crawl) —
  anything that runs once per FRAME but feeds per-TICK state; (e) the human side of a skirmish: selection, the
  controls' idle-frame work, auto-behaviours of the player's units keyed to input events.
- **The witness**: `--hash-every=N --hash-until=T` prints `SIM_HASH tick=<t> <hash>` in any mode and quits at T;
  `--hash-detail-from=T0` adds every unit's hashed fields, velocity, command and intent and every shell at full bits;
  `make windowed-repeat ARENA=sumps REPEAT_EVERY=5 REPEAT_UNTIL=640 REPEAT_FLAGS=--hash-detail-from=600`.

## Backlog (in order)

- **F1. A rate, before a cause.** On the launch tree (do NOT merge `main` until F3 is done or the orchestrator says:
  yard's CP1 turns the Sumps' containers and that is a different fight — C17.2): N windowed Sumps pairs with the least
  perturbing witness (hash every 5 from 600), the fork rate as k of N with N ≥ 10, and the same for the Terminus and
  one more map as controls. Is it always ticks 601–630? Always the same first unit and field? What happens in the
  fight at tick ~600 (read the recording: first contact? a bridge crossing? a unit entering water? the first kill? a
  smoke? an element re-plan?). The event at the fork tick is the best lead there is.
- **F2. Name the unit and the field.** From a forked pair: the first `SIM_HASH_DETAIL` line that differs — command
  versus position versus a shell versus an intent — and walk back from that field to its inputs. If dumping kills the
  fork, dump to memory and write at the end, or dump only the suspect fields.
- **F3. Bisect by removal, one layer at a time** (`--sim-off=visfield_thread` first — it is free and already built;
  then the airship, the cutaway, the controls, the HUD, the recorder; uncapped versus vsync; one core versus many):
  the rate with the layer off against F1's rate, N stated. **Attribute by removal within the same setup, never by a
  ratio** (lesson, and the round-9 rule: an arm assertion reads the state the code CONSULTS — prove the layer was
  actually off). A null on N pairs is only as strong as F1's rate allows: say the probability of seeing zero forks by
  chance.
- **F4. Fix it at the cause, and prove it.** The fix makes the input deterministic (a thread's result consumed on a
  fixed tick, a frame-driven write moved to the tick, a read replaced by simulation state), never a workaround that
  hides the hash. Proof: ≥ 10 windowed Sumps pairs identical to tick 900 on the fixed tree, where F1's rate says ≥ 3
  would have forked; a regression test that fails without the fix (mutation-checked). **The headless baseline is
  UNMOVED by the fix — pre-register that with the path**; if it moves, the defect also lived in the headless path and
  that is a finding for the orchestrator before anything merges (C17.1: yard is the round's one planned mover; an
  unplanned move is merged alone, declared and attributed).
- **F5. It cannot come back unseen.** A `windowed-repeat` pair on the map that forked, short, in `check-all` (it needs
  builder0's display; ship owns `mk/core.mk` — request the one-line addition through the orchestrator with its
  minutes), and a guard for the class if one exists (for example a debug assertion that no per-frame callback writes
  simulation state). `determinism.md` gets the witness paragraph (your predecessor wrote it, in its Status), the
  mechanism, and "determinism is per mode": which modes are covered by which target.
- **F6. Is the field's thread worth its risk on his laptop?** `make perf-play`'s `--sim-off=visfield_thread` arm on his
  four cores is the orchestrator's quiet-window run — ask for it with the exact command; if the thread buys nothing
  there or contends, flip `VisibilityField.threaded` off (and say what F3 found about it either way).
- **Stretch.** The field's remaining main-thread rays (0.32 ms a tick, builder0): an exact skip needs an occupancy
  structure — measure first, equality only. Cross-mode coverage: the garage's match and the network host path under
  the same witness (two runs, same seed, first divergence), reported as a table of mode × covered-by.

## How to verify

`make remote T=check` green on every commit you report (the wrapper's `>> remote: make check exited <N>` line and
`N passed, M failed`; never a pipe); `make determinism`; the sim baseline UNMOVED; `make remote T=windowed-repeat …`
for every pair (builder0's display; one remote run per worktree at a time; chain pairs in one detached script and poll
its done-file — `remote_builds.md` *Long remote runs*). Every rate is k of N with the commit, the machine, the map and
the flags.

## Don't touch

`game/ai/**`, `game/tactics/**` (brains) · `game/arena/**`, `arenas/**`, `tests/arena/**` (yard) · `game/theme/audio/**`,
`game/audio/**`, `assets/audio/**` (guns) · `mk/core.mk`, `mk/web.mk`, `export_presets.cfg` (ship) · `game/units/units.gd`
balance values (C12.6). Outside your paths: the minimal fix for F4 only, listed.

## Waiting on the lead

- Nothing. (Carried from round 16, his to feel in a Law army: the Retired APC's pivot at 95°/s —
  `units.gd` `law_ifv.hull_turn_rate_deg` — if it spins too eagerly.)

## Status

_Last updated 2026-10-03 16:55 PDT (sim worker)._

### Summary
**The Sumps windowed "fork" is the kill-cam, and it happens after the match is decided.** At tick 625 the last Green
unit dies (`elimination`), the kill-cam sets `Engine.time_scale = 0.2`, Godot hands every `_physics_process`
`physics_step × time_scale`, the simulation runs on after `finished`, and the kill-cam gave time back on a
**wall-clock** schedule: on builder0's ~1 s windowed frames ~3 ticks ran slowed, a frame-timing-dependent number. Fixed
at the cause (`eab2e906`): the kill-cam's schedule counts simulation ticks. Guard: `Match` warns once when a live tick
runs at `time_scale ≠ 1`. Regression: `make windowed-elimination-pair` (F5).

### Done, with measurements (every number: builder0 unless said; windowed = `--fixed-fps 30`, 1280×720, `--scripted`
skirmish, budget 6500)
- **F1 rate (old code, launch tree 3713fdaa + witness-only commits):** sumps seed 3, hash every 5 to 660, buffered —
  **1 of 3 pairs forked** (runs 1–6); trajectory classes **{1} {2,3,4,5,6}**, and the F2 pair (every tick, `15bc52f1`
  witness) both in the majority class: **A 1 of 8 runs, B 7 of 8**. Always at tick 630 (first difference between 625
  and 630). Frames and ticks locked 1:1 in every run (identical frame columns). Per-run wall 11 min, load 1.5–21.7
  (`meta.txt`). Terminus/sumps_dry controls were not run on the old code: the mechanism explains them (the Terminus
  never ended in a fresh elimination before 870).
- **The event:** Green_Alpha_3, Green's last unit, dies in ticks 621–625; the match ends by elimination; at 630 the
  Rust army switches to CONTEST.
- **F2 (the unit and the field):** at 630 ALL 34 Rust units differ in the last bits (turret yaw ~2e-6 rad, hull yaw,
  position, velocity); parked units with an identical command (aim point at full bits) differ in turret yaw only; all
  5 Green exact. **Headless takes a third branch C** at the same tick with the same signature (builder0, 2 runs
  identical). Per-tick witness, windowed B vs headless C: the first difference is the **clock line — `time_scale=0.2`
  on ticks 625–627 and `delta = 0.2/30` on 626–627**, then all 34 Rust units at 627.
- **F3 by removal / perturbation:** `--perturb-ids=3/1000` and `--perturb-heap=64` (headless, builder0: 4 runs) and the
  same on the laptop (4 runs) moved nothing — not object identity or heap order; the fog thread writes only its own
  image (and its arm assertion exists: the clock line's `visfield=enabled:…,threaded:…`). The removal that matters is
  the kill-cam's wall clock, proven by the fix.
- **Godot scales the step, not the tick rate (measured):** laptop, headless real time, foundry, 400 ticks: 25.2 s at
  time_scale 1.0, 21.3 s at `--slow-motion=0.2` (arm asserted from the clock line). So the tick-counted kill-cam still
  lasts ~2 s in real play when ticks keep up.
- **F4 fix `eab2e906`** (+ `16a02e14`): `KillCam` HOLD_TICKS 42 / RAMP_TICKS 18 (= its seconds at 30 Hz, a test keeps
  them in step), advanced in `_physics_process`. Tests: `test_fx_kill_cam` (the schedule is exact in ticks under uneven
  wall time — **fails on a wall-clock mutant**, mutation-checked), `test_match_time_scale_guard` (3 cases).
- **Pre-registered UNMOVED, re-read after the fix:** sim-baseline `05df1d55ba49cde1` (check), headless Sumps
  `441426e6489ed9eb` at tick 900 (seed 3, the witness every 30; before/after files byte-identical), determinism
  `762a0576f944f5b7`.
- **Check `16a02e14`: builder0 `make check exited 0`, 1920 passed, 0 failed** (1 NOT JUDGED in ai-scenarios-check, the
  standing refusal class). The guard fired only on its own test's expected warning.
- **F5:** `make windowed-elimination-pair` (sumps seed 1, Green gone by tick 450; two windowed runs to 530, every tick
  witnessed): fails unless the slow motion is exactly 60 ticks in both runs and the runs hash identically; on the old
  code's builder0 data it fails (3 slowed ticks). `determinism.md` has the witness, both mechanisms, the rule and the
  mode × coverage table.
- **F6: keep the thread.** Round 16's quiet-window record on his laptop (`301bac8b`, `perf-play` layer
  `no_visfield_thread`, 2 seeds × 2 presets × capped/uncapped = 8 arms): the thread saves 0.25–2.03 ms a tick in every
  arm; GPU ±0.21 ms, UI −0.76…+0.11: no contention on his 4 cores. No new run needed; `VisibilityField.threaded` stays on.

### Proof (fixed tree `16a02e14`; the orchestrator cut the 14-pair series to this, the cause being asserted directly)
- `make windowed-elimination-pair` **ok**: slowed `[(446, 60)]/[(446, 60)]`, 530/530 lines, no divergence; 18 min.
- Pair table (builder0, windowed, buffered witness every 5 to tick 900, detail from 600):

  | Map, seed | Match ends | Post-end ticks compared | Result | Load at start |
  |---|---|---|---|---|
  | sumps 1 | elimination by ~446 | ~454 | identical, 180/180 lines, one class | 16.8 / 16.8 |
  | terminus 3 | no elimination by 900 | — (control) | identical, 180/180 | 5.3 / 5.7 |
  | sumps 1 (`windowed-elimination-pair`, every tick to 530) | 446 | 84 | identical 530/530, slowed exactly 60 ticks in both | — |

  The seed-3 sumps series was stopped before its first fixed-tree pair at the orchestrator's word (the F5 target
  asserts the mechanism, which a pair rate only infers); unfixed, two runs agreed with p ≈ 0.72 (B 7 of 8 runs), so a
  pair-only proof would have needed ~14 identical pairs for p ≈ 1 %. The 14-pair soak can run in ship's LIGHT lane as
  confirmation once that is on main.
- **Merged to main** by the orchestrator at `16a02e14` (merge `d7860e7f`, 15:30 PDT).

### The kill-cam as he will see it (the orchestrator's point 2; laptop, his window 1854×1011, desktop preset, real
time, sumps seed 1 `--scripted`, a SceneTree probe logging every `time_scale` change; laptop LOADED, load 5.5–16.8)
- Old (wall clock): 5.19 / 6.15 s real, but the 2 s schedule fell inside TWO rendered frames (1.7 s and 3.4 s) and
  covered 6 ticks — two stills, not slow motion. Fixed (ticks): 5.08 / 5.36 s real, exactly 60 ticks over ~33 frames.
  On a machine that keeps up, 2 s either way; on a saturated one the tick version lasts as long as 60 ticks take.
- Frames looked at (start / hold / ramp / 1 s after, both arms): the last kill, DEFEAT, the burst, the end; results
  flow unchanged. **Finding for render/FX:** a multi-second frame stall at the final kill in both arms (first-use
  FX/shader?). If the post-kill slow motion feels long on his laptop, the knob is `KillCam.HOLD_TICKS` (42).

### Cross-mode coverage (stretch; laptop, headless, same seed twice, witness every 30)
| Mode | Result |
|---|---|
| Match runner | `make determinism` (in check) |
| Skirmish headless | identical (builder0: 2+2 runs to 900; laptop 4 runs to 660) |
| Skirmish windowed `--fixed-fps` | one fight until a decided elimination on the old code; with the fix one fight past it (`windowed-elimination-pair`) |
| Host (`--host --seed=3`) | 2 runs identical to tick 600 |
| Garage fight (`--garage --garage-autofight`) | not coverable unattended: the fight opens in the planning pause and never ticks without input |

### Stretch declined, with the measurement: the field's rays
builder0 (load 11–14, 20 000 rays vs 50 static boxes, 2 runs): a native `intersect_ray` costs 2.0–2.5 µs; one native
`AABB.intersects_segment` called from GDScript 0.15 µs of which 0.12 is loop overhead. A per-ray exact prefilter over
50 boxes costs ~7 µs, three times the ray it would skip; only a per-look angular structure could win, and its ceiling is
the skipped share of 0.32 ms a tick, with a float-conservative equality proof to carry. Not worth its risk.

### Decisions
- Fixed the kill-cam's clock rather than freezing the simulation at `finished` or hiding slow motion from it: the
  first changes what he sees after every match, the second needs every sim delta rewritten across owned and unowned
  paths. Ticks make the existing look deterministic.
- F5 asserts the cause (the slow-motion length in ticks), not only "a pair agrees": an unfixed pair agrees ~72 % of
  the time, the assertion fails every time on builder0.

### Questions for the lead (design notes; his)
- During ANY slow motion the tick-counted rules (reloads, brain think cadence, intel every N ticks) run at full rate
  while motion and `sim_seconds` run at the scaled rate: the post-match slow-motion sim is internally inconsistent;
  tactics' `--slow-motion=` does the same to a live match.
- Windowed and headless are the same fight until a decided elimination, and differ after it by design (headless has no
  kill-cam).

### Requests to other streams
- ship: add `windowed-elimination-pair` to `check-all` (needs the display; minutes to follow from the green run) — sent
  through the orchestrator.

### Known issues
- A windowed run on the laptop opened on his desktop four times on 2026-10-03 ~15:36–15:50 PDT (the kill-cam probe,
  ~1 min each).
- The frame stall at the final kill (above): render/FX's.

### Merge notes
- **`game/theme/fx/kill_cam.gd` — an unowned path, the brief's minimal-fix carve-out** (F4).
- `game/match/match.gd`: the witness (`--hash-buffer`, detail: intel/clock/census), `--perturb-ids/--perturb-heap`
  diagnostics, the time-scale guard. `mk/match.mk`: `windowed-series`, `windowed-elimination-pair`.
- New tests: `tests/test_match_time_scale_guard.gd`; `tests/test_fx_kill_cam.gd` gained two.

### What to playtest (the lead)
- `make skirmish`, play to an elimination: the slow-motion kill-cam should look exactly as before (~1.4 s held, ~0.6 s
  easing back, then the results).

**Merged**: `16a02e14` (green: check above) is on main (`d7860e7f`). Since then the branch adds only docs (`_agents/`), checked at the tip below.
