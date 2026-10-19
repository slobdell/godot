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

**Report (2026-10-18, late):**
- **P1 done (06b5be57c): the rematch diagnosis.** Traffic's solve stagger (`traffic.gd` hold_of/shape) read
  `Engine.get_physics_frames() % 6`, and the process's frame counter never resets, so a rematch started at another phase
  and branched. Nothing else carries a match: GDScript statics (all 798 restored), a new World3D, the resource cache,
  ids and heap all change no bit. Evidence (918ede503, builder0 native, sim-baseline match through main.tscn, 3 runs a
  process × idle phases 0–5, 1150 ticks): base gives 6 outcomes and 12 of 12 rematches branched; a scratch patch gives
  1 outcome and 0 of 12. `references/round34/planner/rematch/diagnosis.md`. Ruled (A) by the orchestrator.
- **P2 MERGED: main `89e775f87` = `39f0d7e81`** (the orchestrator, 2026-10-19; baseline adoption on builder0 follows).
  **Green hash was `39f0d7e81`** (stream/planner + native's `ae2f03c59`: N5's Sumps stage move
  and test_native_yield's floors, now set as paths reached, after the phase shift). builder0 `make check exited 2`:
  test 2798 / 0, perf-judge JUDGED PASS, 25 of 27 targets passed. The two reds are the planned sim-baseline move (all
  13 maps; identical to builder2's two agreeing reads; foundry `2e54d6f5c9fc22ac`) and web-smoke (builder0's Chrome lost
  WebGL2: environmental, per the orchestrator). `Traffic._phase` = the Match's tick (a frame origin would still drift
  through the planning pause). The audit of every frame-counter read is in the diagnosis. `tests/test_rematch.gd` passes
  with the fix and fails without it (tick 250). The orchestrator merges it alone and adopts the baseline on builder0.
- **P3 done (697029f4a):** judging table re-rendered with round 33's pairs (hull-rest, fights, Terminus printed se, plus
  three new probes: hull-rest gangs A/A, orbit cells, far census). No row's sd moved more than 20 %. Far-census kills:
  sd 5.96 a fight, MDE 5 % at 48 fights. `_agents/judging.md` *Round 34 re-render*; csv under
  `references/round34/planner/sizing/`. Owed: rounds 31–32's pairs and the round-31–33 inventory lines.
- **P4 done:** (a) d3203aeb3, one run identity (screen.json + seam report) for hull_aa / face_keep_table / face_pairs /
  kept_share; they used to read 48 / 32 / 36 distinct pairs on one series. (b) R34.5 (orchestrator): FACE_KEEP_FAR is
  REPORTED only (09a98132c) and gets deleted in round 35.
- **P5 waiting:** P3 v3 starts only after the k-turn arrival flicker fix merges (manoeuvre's M2, C34.4 (2); its check
  was running at the C34.6 merge). Next step then: merge main at the orchestrator's checkpoint, re-measure the face-keep
  tail on the flicker-fixed tree, and file v3 only if a tail remains on faces really asked (fresh bar, pinned, paired by
  face via face_pairs).

**Plan:** P1 → P2 (merge alone, then the baseline adoption on main) → P3 → P4 → P5 after the flicker.

**Merge notes (shared files):** `game/ai/traffic.gd` (traffic's; three changes, granted for C34.6: `_match_id`, `_phase`,
and the two stagger lines). `tools/judge/**` (granted for C34.8). Main moved (docks adopted, 71bd4e466) after this
branch's base.

**Known issues:** none open. (Native explained the owned ≠ live counts: yard_open's two stages differ by design, and
their floors are now set as paths reached.)

**Questions for the lead:** none. **Requests to other streams:** none.

**What to playtest:** nothing new to see. A rematch from the results screen should now play out the same as the first
fight given the same orders (the floor under replays and the network).
