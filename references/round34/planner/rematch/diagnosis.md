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
