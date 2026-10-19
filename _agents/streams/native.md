# Stream: native (every pair; the judging table complete; planner's paths this round)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 35** (C35.1, C35.9),
> your round-34 brief `streams/archive/round34/native.md` and planner's `streams/archive/round34/planner.md` (both close-outs).
> **You own:** `native/**`, `mk/native.mk`, `exec_fields.h`, the twins, and this round planner's paths: `game/ai/planner/**`,
> `native/src/planner_*`, `tests/planner/**`, `tests/test_planner*.gd`, `mk/planner.mk`, `tools/judge/**`.
> **Model:** Opus. **Machine:** builder0 only (C35.1).

## The lead's direction

Nothing alone: native keeps every C++ change a twin of its GDScript, so the game stays fast on his laptop and the two paths agree.

## Where things stand

- **Shipped in round 34:** C34.7 the dropped-peer shell RPC, C34.8 (a) PIN_FPS everywhere + the moves list, N4 NativeExpect.absent,
  N5 the yield floors, N6 web-smoke with no desktop.
- **Unmerged on purpose:** the underfire mirrors (`badfdb978`, T6b parked), parkedroom v4m, the T4 ghost twins. The c339 stop
  hand-back rides the M0 merge (C35.3). `round34/native` carries inert underfire C++ (e1bd2453b, 979c3fa5b, 15b1523da): don't merge
  that branch as a whole; take commits.

## Backlog (in order)

1. **N1 Pairs, as they come:** orders' deploy step ON (D1, check whether any C++ reads the halt seats; likely none), manoeuvre's
   wedged-death rule (W1, the drive), traffic's T7 (rebuild the underfire mirror with the new gate), CP-F 5 if it reaches C++.
2. **N2 Planner's leftovers (C35.9):** delete FACE_KEEP_FAR (R34.5); the judging table's owed rows (round 31 brains, round 32, the
   round 31–34 inventory lines; `python3 tools/judge/inventory.py` and `table.py`); make every series tool drop random-seed twins
   (`tools/judge/seed_twins.py`).
3. **Stretch:** the watch item from R34.16 (one 9.1 m both-planned face) if a face_pairs series runs.

## How to verify

`make quick-remote`; `make native check` for a named hash, one at a time on builder0; tools tests on the laptop.

## Don't touch

Gameplay GDScript outside planner's paths, `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_

### Round 35 (started 2026-10-19 from main `a0ae0aafd`, which inherits c29a8c7b6's green check; main 0f4d528d7 merged in)

**Plan (in order):** N2 first (nothing had arrived for N1 at launch), with N1 pairs pre-empting as they come; then the stretch.
1. N2 (a) FACE_KEEP_FAR deleted. (b) seed twins dropped by the series tools. (c) The judging table's owed rows. Then one full check.
2. N1 pairs: orders' D1 (statement), manoeuvre's W1/W2 (the face settle: mirror when its bar passes), traffic's T7 (the
   underfire mirror rebuilt with its pass-lane gate), CP-F 5 if it reaches C++.
3. Stretch: R34.16's watch item when a face_pairs series runs.

**REPORT (2026-10-19, laptop tests; the full check is queued behind orders' check on builder0):**
- **N2 (a) done, `da93c3fea`:** FACE_KEEP_FAR deleted from `tests/planner/face_keep_table.py` (R34.5). face_pairs.py is the
  judged reading. The seam's `face_far` field stays, because kept_share.py reads it. Test: `test_face_keep_far_is_deleted`.
- **N2 (b) done, `8f29bff5a`:** `seed_twins.drop_twin_logs` / `filter_logs`. In a series folder of `<arena>-<seed>.log`,
  a `random-<seed>.log` is dropped when the map it was dealt has `<map>-<seed>.log` in the same folder. The dealt map
  comes from its own `*_CENSUS` line (Arena.active), else the R34.15 table. Both arms drop the same seeds, so paired
  readings keep their pairs. `tests/traffic/far_table.py` calls it: one import + one call, MERGE NOTE (traffic's file,
  covered by C35.9 per the orchestrator). `planner-pytest` now runs tools/judge's tests too, so they are in `make check`.
  On the laptop that is about 50 s, mostly test_table.
- **N2 (c) done, `339465130`:** the judging table's owed rows.
  - **Inventory:** `tools/judge/lines_r31_34.py`, 185 lines of rounds 31–34, 171 of them judged.
  - **Pairs pooled:** round 31/32's pairs in `probes.py`.
  - **Copied rows:** round 31's traffic rows from `round31/traffic` (PROVENANCE.md).
  - **Re-render:** judging.md *Round 35 re-render* has the details and the moved rows. The files are in
    `references/round35/native/sizing/`.
  - **Rounds 31–34:** 2 of 171 judged lines sit inside the noise, and 45 verdicts are within 1.645 se of their line.
  - **Tests:** tools/judge 83 OK and tests/planner 19 OK (laptop).
- **N1 D1 (orders' deploy step ON):** no native change. The step is ElementPlan only (GDScript on every path). The only C++
  it reaches is el_native's grounding, a pure function of map and point. exec_fields doesn't change. Told the orchestrator.

**Requests to other streams:** traffic, through the orchestrator (relayed after T7's series). Any series reader that pools
a folder containing random-arena fights calls `seed_twins.filter_logs(files)` first (far_ab, far_kills, jam_ab, jam_table).

**Merge notes:** `tests/traffic/far_table.py` (traffic's: one import + one call). `references/` gains round35/native/sizing
and `_agents/streams/references/round31/traffic/` (copies).

**Questions for the lead:** none. **Known issues:** none.
