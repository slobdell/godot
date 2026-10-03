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

_(the worker keeps this current: plan, done with measurements, decisions, questions for the lead, requests to other
streams, known issues, what to playtest, next steps, merge notes — and `this commit is green, merge here: <sha>`)_
