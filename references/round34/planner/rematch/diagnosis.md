# C34.6 (1): why a same-process rematch doesn't replay (planner, round 34)

**Answer: Traffic's solve stagger reads the ENGINE's physics frame counter, not anything that belongs to the match.**
`game/ai/traffic.gd` `hold_of()` (l. 282) and `shape()` (l. 415) re-solve a crew's hold look and crossing cap when
`(Engine.get_physics_frames() + (name.hash() & 0xffff)) % SOLVE_TICKS == 0`, with `SOLVE_TICKS = 6`. A process's frame
counter never resets, so a rematch starts at another frame phase mod 6, each crew re-solves on different ticks, and one
crew's throttle differs with every input to the sim identical (tick 250 of the sim-baseline match: Green_Line_2's
throttle 0.434 v 0.283, pose, velocities and every other command bit-identical). It is trip-up 28 ("decisions think on
`Match.tick`") broken by a stagger. The physics server, the resource cache and GDScript statics carry nothing.

## Evidence (commit 918ede503 = main at the round-34 docs commit; `make planner-rematch`, tests/planner/rematch_probe.gd)

The probe is the real game's rematch path: `Main.next_flags` + a scene change to `main.tscn` (what
`ArmyLoop.restart`'s `reload_current_scene` does), the sim-baseline match (seed 3, foundry, `--fixed-fps 30`), runs
compared per tick on `state_hash()` and, with `--rematch-detail=on`, every tank's pose, rotation, velocity,
real_velocity, estimated_velocity and command.

**1. A rematch branches (laptop flightdeck, GDScript path, n 3 runs, each process repeated: identical).**
Run 0 `ee6ba8aac7a442d7` at tick 600; run 1 first differs at tick 250 (a command; the hash at 446); run 2 at 251.

**2. Nothing the obvious suspects carry changes a single bit (laptop, GDScript, the same three hashes every time):**

| intervention before each rematch | run 1 / run 2 hash at tick 600 |
|---|---|
| none | c345b9ad195991ce / 7471a2662e3a6011 |
| every GDScript static of every global class restored to its value before run 0 (798 vars, 153 had changed) | same |
| a new `World3D` on the root viewport (fresh physics space + navigation map) | same |
| main.tscn and every sub-resource reloaded (`CACHE_MODE_IGNORE_DEEP`) | same |
| `--perturb-ids=1000` / `--perturb-heap=64` (instance ids, heap layout) | same |

**3. The FIRST match of a fresh process changes with the frames idled before it, period 6 (laptop, GDScript,
one run per process, hash at tick 600):** idle 0 `ee6ba8aa`, 1 `c345b9ad`, 2 `7471a266`, 3 `95ce49ac`, 4 `2c853e22`,
5 `d94267ca`, 6 `ee6ba8aa`, 7 `c345b9ad`, ... 12 `ee6ba8aa`. The rematch's run 1 / run 2 are exactly idle 1 / idle 2:
the rematch is a first match at another phase. Nothing game-side runs during the idle frames (no scene is loaded), so
the only thing they change is the engine's frame counter. `SOLVE_TICKS = 6` is the only period-6 frame-modulo in the
sim (grep `% ` over game/ai, game/tactics, game/tank, game/match: every other stagger uses `Match.tick` or a
frame DIFFERENCE).

**4. The scratch patch proves it is the only carrier** (`traffic_origin.diff`, NOT committed: the phase counts from
the frame Traffic's table first saw this match's tanks root, three lines):

| builder0, native ON, 918ede503, 1150 ticks, 3 runs a process at idle phases 0-5 | distinct outcomes (hash at 1150) | rematches that branched |
|---|---|---|
| base (`builder0_base.txt`) | 6 (one per phase) | 12 of 12 (first diff tick 250-434) |
| origin patch (`builder0_origin_patch.txt`) | 1 (`09152e34b99dedc3`) | 0 of 12, full detail (pose, velocities, command) identical every tick |

Laptop GDScript with the patch: identical at idles 0, 1, 4 over 3 runs (n 9).

**5. Traffic's body-stage case (ov_replay.md) is the same carrier.** tests/planner/rematch_body_probe.gd, body OFF,
3 runs a process, compared from tick 3 (after the stage snaps its hulls). builder0 native, base: seed 3 branched
(16.0 → 16.5 alone_s); seeds 1, 5 replayed. Patched: all three replay. The hull HEIGHT difference ov_replay saw at
tick 1 is the lab's pre-start frames in a process's first arena (the hulls are separated by the physics before the
stage snaps them back): the snap erases it, so it never reached the result. Its A, B, A pattern at `--fixed-fps 60`
is the same mod-6 phase stepping 2 frames a tick. R33.14's "what a match leaves behind (the physics server's bodies)"
in test_tactics_body is this too: a shard's earlier tests move the frame phase.

## Proposed fix (for the orchestrator to agree; no game code written)

**(A) Recommended: Traffic's stagger counts from the match, not the process.** The patch above, or the same thing
keyed on `Match.tick` (Traffic sees the tanks root, whose parent is the Match). Three lines in `game/ai/traffic.gd`
(traffic's file: either traffic makes it, or the orchestrator grants planner these lines). No reset hook in
`match.gd` is needed: there is nothing in the physics server to reset.
- **sim-baseline MOVES, and why:** a fresh match-runner process's first refresh is on a frame ≡ 2 mod 6, so the
  origin shifts every crew's phase by 4 (patched run 0 = base idle 4: `09152e34` on builder0 native, `2c853e22` laptop
  GDScript). Every dealt map's line moves once, cause: "Traffic's solve stagger is match-relative (C34.6)". Nothing
  changes in kind; a crew re-solves every 6 ticks as before, on other ticks.
- Judged rulers: any judged stage moves the same way once (a phase shift, like a reseed). Tests run in shards, so
  their phase was already arbitrary per shard order; the fix makes them order-independent instead.

**(B) Not recommended: keep the baseline by aligning the match start** (Match waits until the engine frame is the
fresh process's residue mod 6). It couples Match to a Traffic constant, and the next frame-keyed stagger breaks it.

**The test (C34.6 (3)), `tests/test_rematch.gd`:** a child process runs the probe with 2 runs and
`--rematch-phase=1` (the rematch starts 1 frame past a multiple of 60 after run 0: every period dividing 60 sees another
phase), and asserts identical per-tick detail through tick 450. It fails today at tick ~250 and passes with (A).
A guard for the future: any new decision keyed to the engine frame counter fails it.

**Checked and left:** `game/ai/brains_ab.gd:155` alternates a perf A/B's arms on `Engine.get_physics_frames() / _block`
(a CPU-cost tool that flips switches within one run, never play or a judged behaviour series). Brains' file; noted only.

## The fix (C34.6 (2), the orchestrator's ruling: (A), with the audit first)

`game/ai/traffic.gd`: `_phase(frame)` returns the Match's tick (the tanks root's parent, found when the table meets a new
root; `frame` for a table with no Match, as `load_rows` tests use); `hold_of` and `shape` stagger on `_phase(frame)`.
The Match's tick was chosen over the first-seen frame (the orchestrator's preference, and a better clock): the frame
counter still runs while the tree is paused (the skirmish's planning pause), so a frame origin would make the phase
depend on how long a player paused, which a replay doesn't reproduce. Every other read of `frame` in traffic.gd is a
difference (LIVE_TICKS, SOLVE_TICKS age, the cap, TABLE_TICKS), unchanged. No C++ mirror: the native drive calls
`Traffic.hold_of` / `Traffic.shape` (native_traffic.gd), and native/src has no SOLVE_TICKS.

### The audit: every engine frame-counter read on a sim path (grep get_physics_frames / get_process_frames, game/ and native/src)

| site | how the value is used | class |
|---|---|---|
| traffic.gd hold_of 282, shape 415 (the `%` term) | `(frame + hash) % SOLVE_TICKS` | **absolute phase: FIXED** |
| traffic.gd 245/276/412/893 (all other uses) | `frame - seen`, `frame - last >= SOLVE_TICKS`, table age; `_forget()` on a new root | difference |
| drive_native.cpp 342 | C++ twin of `Traffic.holding`: `frame - at <= LIVE_TICKS` | difference |
| drive_native.cpp 2286/2294 (`_manoeuvre`'s `tick`) = movement.gd 1148 | `tick - _behind_tick > BEHIND_GAP_TICKS`, `tick - _behind_since`; per-mover members (fresh each match) | difference |
| movement.gd 1278 (`_face_tick`) | `tick - _face_tick` | difference |
| execute_native.cpp 269 | `swept_frame != frame`: sweep freed movers once a frame | per-frame memo (equality to now) |
| gun_native.cpp 533 | `wander_frame != now`: difficulty read once a frame | per-frame memo |
| pathing.gd 120, perception.gd 37, avoidance.gd 114, movement.gd 3256 (`_chord`), native_route.gd 22, native_scan.gd 30, native_record.gd 53, element.gd 815 (feed key) | `frame != _memo_frame` (+ map / root / match id) | per-frame memo |
| element.gd 315/1195/1201 (`task_frame`) | squads tasked on the SAME frame weigh the body together: equality between elements of one match | equality within a frame |
| ai_tick_cache.gd 312/323 (`_fired`) | `now - fired`, keyed by the hull's instance id (never reused across matches) | difference |
| planner_seam.gd 477/527 (`tick_seen`, `_retry_until`, `_watch_faces`) | `tick - tick_seen > STALE_TICKS`, `held > tick` with the hull's instance id checked | difference |
| planner_seam `_last_refusal` → manoeuvre_census.gd `refusal_recent` (movement.gd 3521) | `now - last <= window`, keyed by NAME across matches | difference; read only by a measurement counter (`esc_after_refusal`), not a decision |
| manoeuvre_census.gd 260/407 | `tick % STATE_EVERY`, `tick % TRACE_EVERY`: which ticks a trace prints | absolute phase, **measurement output only** (no decision reads it) |
| brains_ab.gd 155 | perf A/B alternates arms on `frame / _block` | absolute phase, CPU-cost tool only |
| element.gd 1563-1573/1836/1846, tank.gd 971, wall_contact.gd, movement.gd logs, tick_profile.gd, match.gd 459 | printed or logged | output only |

A name-keyed carry can still depend on the GAP between two matches (a difference against a frame from the last
match): the only such read is `_last_refusal`, measurement only. The test's rematch starts within ~1 frame of the
first match's end, the worst case for such a carry, and replays.

### Measured (the fix = this commit's game/ai/traffic.gd)

- `tests/test_rematch.gd` (builder0 light lane, native ON): **passes with the fix** (run 0 and the rematch both
  `1102d7243f9f6fc4` at tick 600, full per-tick detail identical); **fails on 06b5be57c's traffic.gd** (rematch parts
  at tick 250, Green_Line_2's throttle: the diagnosed fork).
- **Full check, 09a98132c (= b7184e87d's game code + P3/P4 tools and docs), builder2, `make check exited 2`, 2797 passed
  / 1 failed, 23 of 26 targets passed.** (a) sim-baseline MOVED on every dealt map: the planned move. The fixed tree reads
  identical twice, 13 maps (`sim-baseline-twice-builder2.txt`). (b) native-verify-scenarios: scenario_perf over budget on
  a loaded box (perf_reference 1.49×). Alone: 53 passed / 0 failed / 0 mismatches. (c)
  `test_native_yield::test_the_give_way_on_the_owned_state`: yard_open owned, spot:spot 10 against a floor of 11, 0 twin
  mismatches. It's a coverage floor moved by the phase shift (base live 24 / owned 22 → fixed live 21 / owned 10,
  `native-yield-{base,fix}-builder2.txt`). Ruling asked of the orchestrator. (builder0's run of b7184e87d died with the
  machine at ~22:55, exit 255: no reading.)
