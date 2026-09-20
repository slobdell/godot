# T1 follow-up, measured but deliberately NOT shipped in CP3: `make test` runs at REAL TIME

**`mk/core.mk`'s `test` target passes no `--fixed-fps`, so the engine advances physics at wall-clock 30 Hz and
the suite spends most of its 2388 s WAITING.** Every match target does pass it — `mk/match.mk`'s own comment says
why: *"`--fixed-fps $(SIM_HZ)` makes every frame advance exactly 1/60 s of game time without waiting for the wall
clock, so matches run as fast as the CPU allows."* The test target never got the same treatment.

**Measured** (laptop, commit `2fd84d69`, 2026-09-20, `tests/nav/fight_probe.gd --time-limit=10`, i.e. ten seconds
of SIMULATED time, same seed and arena in both arms):

| arm | wall clock |
|---|---|
| as `make test` runs today (no `--fixed-fps`) | **15.4 s** |
| `--fixed-fps 30` | **6.9 s** |

Both include ~5 s of engine start-up, so the simulated portion went from ~10 s to ~2 s: **about 5×**, and it is
the same 5× that makes builder0 sit 90–99% idle during a check.

## Why it is not in CP3

1. **It is a change to what 1,261 tests mean, not to how they are scheduled.** A test that measures elapsed real
   time, or that relies on real-time pacing, behaves differently under a fixed tick. Sharding cannot change a
   test's result; this can.
2. **It would confound CP3's falsifier.** CP3 is a before/after wall-clock comparison of one change. Landing two
   independent speed-ups in the same commit means a regression in either is invisible in the number.
3. Sharding alone clears the ≥ 50% bar with room, so nothing is being sacrificed by sequencing them.

## How to land it, as its own small checkpoint

- `TEST_FIXED_FPS ?= 1` on the `test` recipe, adding `--fixed-fps $(SIM_HZ)` — one variable, trivially reversible.
- **The control is the one already in hand:** `1261 passed, 0 failed` on builder0, unsharded, at `c21d0256`. The
  fixed-tick arm must produce the same 1261 and the same zero.
- Run it **three times**, because a test that depends on real-time pacing may fail intermittently rather than
  always, and an intermittent failure introduced here would be blamed on sharding for weeks.
- Any test that changes result under a fixed tick is a **test bug to report**, not a reason to abandon the change:
  a unit test whose outcome depends on how fast the machine was is already unreliable.

Expected prize: if the suite's waiting dominates the way the probe's does, `test` goes from 2388 s to roughly
500 s **before** sharding — and sharded on top of that, the whole check lands near two minutes.
