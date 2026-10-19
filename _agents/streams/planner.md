# Stream: planner (a rematch without restarting plays out the same; the judging table re-rendered; P3 v3 after the flicker)

> Read `_agents/orchestration.md` (the worker contract, and *Close the round* step 5b, the judging table), `_agents/judging.md`,
> `_agents/workstreams.md` **Round 34** (C34.6, C34.8 (b); R33.19, R33.26, R33.28 in *Round 33*), `_agents/roadmap.md`
> *Round 34 candidates* (the rematch entry), traffic's `streams/references/round33/traffic/ov_replay.md`, and your round-33
> brief `streams/archive/round33/planner.md` (*Round 33 close-out*).
> **You own:** `game/ai/planner/**`, `native/src/planner_*.{h,cpp}` (native reviews every C++ commit), `tests/planner/**`,
> `tests/test_planner*.gd`, `mk/planner.mk`, `references/round34/planner/**`. **Granted (round 34):** read all of
> `game/match/**`. For C34.6, once the diagnosis is written and agreed: a reset hook (or a fresh physics space per match) in
> `game/match/match.gd`, plus a new `tests/test_rematch*.gd`. `tools/judge/**` for C34.8 (b). **Model:** Opus.

## The lead's direction

His standing aims: relay-only network play, and replays. Both need a match to replay exactly. Today a rematch inside one
running game does not (`ov_replay.md`). What he will notice: nothing yet. A rematch that plays the same is the floor
under replays and the network. His round-31 planner direction stands (a long truck turns in a few deliberate legs).

## Where things stand (main at the round-34 docs commit)

- **Round 33 shipped from planner:** R33.3 (a cut-off planned turn could freeze the hull out of unstick), and P3 (the face
  keep: a vehicle told to face behind turns round in about 10 s instead of 15). CP-Q stays parked.
- **The rematch (UNOWNED until now; traffic's evidence):** body stage on Locks, 3 matches in one process, seeds 1–6, laptop
  GDScript, `--fixed-fps 60`. A rematch branched on 2 of 6 seeds with the ghost OFF (s3 39.0 → 37.0, s5 56.5 → 19.5). It enters
  at TICK 1 as hull height (y 0.000871 v 0.00087). A fresh World3D or clearing every GDScript static doesn't change it; a
  fresh process replays exactly.
- **P3 v3 withdrawn** until the k-turn arrival flicker is fixed (manoeuvre and brains, C34.4 (2)): most of its tail is the
  flicker. Your s69 diagnosis is their starting point, so answer their questions.
- **The judging table was not re-rendered at round 33's close.** Round 33's judged pairs (your P1 A/A rows, the P3 pinned
  pairs, CP-F, C33.9, parkedroom, the battery, the scout) need to go into `tools/judge/probes.py`.

## Backlog (in order)

1. **P1 The rematch diagnosis (C34.6 (1)).** Reproduce on current main (headless, `--fixed-fps`, one process, two matches,
   same seed), at the smallest stage that branches. Bisect what carries over: Godot's PhysicsServer3D state (body RIDs,
   broadphase pairs, contact caches, sleeping, solver warm starts), engine singletons, node order, RNG. Write it up with the
   test that shows it. Send the orchestrator the diagnosis and a proposed fix before any game code.
2. **P2 The fix and its test (C34.6 (2)–(3)).** Two matches in one process give identical sim hashes, in a test that fails
   without the fix. Full check; sim-baseline should not move.
3. **P3 The judging table (C34.8 (b)).** Add round 33's judged pairs to `tools/judge/probes.py`, then
   `python3 tools/judge/inventory.py` and `table.py`. Commit `_agents/judging.md` and the csv under
   `references/round34/planner/sizing/`. Fold in manoeuvre's new-ruler A/A rows when they come.
4. **P4 Tools:** one run identity across the series tools; a ruling request on retiring FACE_KEEP_FAR (send it to the
   orchestrator with the evidence).
5. **P5 P3 v3, the face keep cap,** only after the flicker fix merges. Fresh bar, pinned, paired by face.

## How to verify

`make quick-remote`; `make native check` for named hashes. `make sim-baseline` (must not move). Your planner series
targets. Long remote runs under `systemd-run --user`. Every number: commit, machine, workload, n.

## Don't touch

Gameplay in `game/match/**` beyond the agreed hook; traffic's, manoeuvre's and brains' paths; `native/**` outside
`planner_*`; `tests/baselines/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
