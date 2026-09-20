# T1 / CP3: `make check` runs its targets concurrently and splits the test suite

**Status: the before is measured, the mechanism is built and verified, the three-run table is waiting on
builder0** (off the network from ~02:45 on 2026-09-20; the series will be restarted whole rather than salvaged).

## The finding that shaped the work

Round 8's plan for T1 was *"the targets in `check` are largely independent, run them concurrently"*. Measured
first, as the brief required — and the plan was aimed at the wrong thing.

**`test` is 2388 s of a 2584 s check: 92% of it.** Running all twelve other targets perfectly in parallel saves
under three minutes out of forty-three, which cannot reach T1's own ≥ 50% bar. **The suite is the check.**

Underneath that: the work is **latency-bound, not compute-bound**. `make test` passes no `--fixed-fps`, so the
engine advances physics at wall-clock 30 Hz and the suite spends most of its time *waiting*. Sampled from builder0
while **three whole checks ran**: load 0.33–0.47 on 12 cores, **90–99% idle**
(`t1-builder0-idle.txt`). That is why raising the slot count never helped — more slots shortens the QUEUE; only
inner parallelism shortens the RUN.

## The before (a)

builder0, commit `2fd84d69`, 12 cores, 12.4 GB available, load 1.15, 5 other Godot processes. Targets one at a
time, **working lint, unsharded test**:

| target | s | | target | s | | target | s |
|---|---|---|---|---|---|---|---|
| **test** | **2387** | | army-loop-smoke | 24 | | net-smoke | 4 |
| lint | 94 | | combat-smoke | 18 | | sim-baseline | 4 |
| announcer-check | 89 | | determinism | 11 | | broker-test / match-smoke | 3 |
| audio-check | 36 | | relay-smoke | 10 | | lobby-smoke | 2 |
| | | | garage-smoke | 8 | | the pytest suites | 0 |
| | | | | | | **TOTAL** | **2693** |

`test` reproduced to **within one second** across two independent runs (2388 s and 2387 s) — a better-behaved
baseline than a wall-clock falsifier usually gets. An earlier profile of the same 16 targets with the (then
broken) lint totalled **2584 s**; the ≥ 50% bar is read against that, the *most favourable* figure the serial
check ever produced.

## The mechanism

- **`check` hands its list to one sub-make** with `-j$(CHECK_JOBS) -Otarget`. One invocation, so `import` — the
  only `.godot` writer among these targets — is built exactly once before anything else starts.
- **Three exclusion groups**, as order-only prerequisites between `_cp-*` wrappers so the chains never leak onto
  the real targets: `SMOKE_NET_PORT` {net-smoke, combat-smoke}, `SMOKE_BROKER_PORT` {relay-smoke, lobby-smoke},
  `user://garage_scratch/my_army.json` {garage-smoke, army-loop-smoke}.
- **The suite shards.** `tests/run_tests.gd --shard=I/N`, round-robin over the sorted discovery order so no shard
  inherits the expensive tail (the `test_tactics_*` scenario files sort last and dominate the run). Unsharded
  behaviour is byte-identical, including its final line.
- **`lint` fans out.** 531 files × 1.82 s of Godot start-up was the second-largest cost; 94 s fanned out.
- **Every budget is derived** (`tools/slot.sh --jobs`), from measured peak RSS, with the memory share divided by
  the live slot count — never hard-coded (lesson 148).

## What was verified without builder0

| claim | how |
|---|---|
| the shard partition is exact | shard file counts sum to **187** at N = 2, 3, 5, 6 — the exact discovery count. Nothing dropped, nothing run twice |
| a silent shard cannot vanish from the total | the recipe refuses when fewer than N shards report a summary line; tested with a stubbed shard that exits mute |
| the shard totals sum correctly | stubbed shards: 3 × 40 passed → one bare `120 passed, 0 failed` |
| exactly one `N passed, M failed` in a sharded run | shards print `SHARD i/n: …` and never the bare line |
| the serial fallbacks still work | `TEST_SHARDS=1` and any `FILTER` take the one-process path |
| no `user://` shard race | 17 references across 10 test files; **no path is touched by more than one file**, and shards take whole files |
| no port shard race | no test under `tests/` binds one; the smokes that do are separate targets, already in the exclusion groups |
| `--check-only` never writes `.godot` | all 911 cache files snapshotted, five passes, zero change |
| serial and parallel lint agree | 24 files, 35 s → 11 s, byte-identical findings — then repeated with a deliberately broken file, because an empty comparison proves nothing (lesson 147) |
| the order-only chains are registered | read back out of `make --print-data-base` |

## The falsifier, pre-registered (workstreams.md T1)

1. full-`check` wall-clock on builder0 drops **≥ 50%** against (a);
2. **zero new flakes over three consecutive runs** on the same commit;
3. `sim-baseline` and `determinism` hashes **bit-identical** to the serial run's.

**The references those three runs must match** (serial, builder0, pre-outage):

    sim-baseline   04414f5d6a6dfa7c  (glibc-2.43; also main's recorded baseline)
    determinism    state_hash 133fd18a5285d64c, Green 8 / Rust 6
    test           1261 passed, 0 failed  (UNSHARDED -- the sharding control)

## Results

_(the three-run table goes here: run, commit, machine, wall-clock, load, 1261, both hashes, flakes)_
