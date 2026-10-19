# Stream: traffic (a crew stuck behind a parked crew of another squad gets by, and the parked crew goes home: parkedroom v4; then T4's circling hull)

> Read `_agents/orchestration.md` (the worker contract), `_agents/judging.md`, `_agents/workstreams.md` **Round 34**
> (C34.1–C34.3; C31.1–C31.3, R31.1–R31.10, R32.1–R32.7, R33.20, R33.32 stand), its *Round 33* rulings R33.12, R33.36,
> R33.37 and R33.29–R33.30, `_agents/roadmap.md` *Round 34 candidates*, and your round-33 brief
> `streams/archive/round33/traffic.md` (**ROUND 34: OPEN ITEMS** at the top of its Status, the v2/v3 results, T4's G2).
> Evidence: `streams/references/round33/traffic/` (ov_parkedroom_v2_bar.md "v3 result", ov_parkedroom_v3_l3_trace.md,
> ov_t4_bar.md, ov_replay.md; `r33_traffic_overnight_runs.tar.gz` holds the raw per-fight logs).
> **You own:** round 33's traffic paths (`game/ai/avoidance.gd`, `steering.gd`, `traffic*.gd`; in `movement.gd` the
> give-way block `right_of_way` through `_blocker` including `_negotiate`, ask, `_begin_yield`, plus `_avoid`,
> `_around_friends`, `_ask_behind`, `_hull_within`, and v3's `_room_home` / `_room_home_inside`; `tests/test_traffic*.gd`,
> `tests/traffic/**`, `tests/ai_scenarios/scenario_traffic*.gd`, `tests/test_avoidance.gd`, `mk/traffic.mk`,
> `tools/series_cache.sh`, `tools/quick_tests.sh`, `mk/infra.mk`, `tests/run_tests.gd`'s shard plan).
> **The C++ (C31.2):** the drive's ask and the execute path have native twins. parkedroom's hand-back is native's,
> rebased onto your pair. **Model: FABLE** (this problem has parked three times).

## The lead's direction

Round 28: **TAKE TURNS**: "fewer bumps; both squads arrive a little later." His standing rule: smart AI on both sides,
and symmetric AI improvements ship without asking him. He was told at round 32's close, as a known issue: **a crew stuck
behind a parked crew of ANOTHER squad nudges back and forth instead of getting by.** What he will notice when this ships:
that crew gets by, because the parked crew makes room and then goes back to its post. Fewer crews die stuck in a jam, on
both sides.

## Where things stand (main at the round-34 docs commit)

- **Shipped in round 33:** item 4, the fire mission (a set-up mortar truck counts as firing only with a target: idle
  fire-post loops 20 → 0, main `8684a97bb`), plus islands and the far census tools.
- **parkedroom v1, v2, v3 all PARKED (R33.12, R33.36, R33.37).** v3 (a hold-order crew returns to its hold point after
  making room) is on `round33/traffic-overnight`, DEFAULT_OFF. On fresh 820–867 × 3 (builder2, n 144) it PASSED
  L1a hold-post loops 59 → 18, L1b parked loops 224 → 63, L2 far loops 411 → 201, L4 and L5. It FAILED L3, kills
  2072 → 1992 (se 40.9) with the hit rate equal, and L6, 89.96 % home (line 90 %).
- **Your random-859 trace** (`9e3474e61`, builder0, n 1): give-ways from 13 s branch the fight, and the base's rout of
  Rust's artillery park (14 lost, caught driving or stuck) never happens with the fix. **The orchestrator's ruling (C34.2):
  fewer crews dying stuck is the fix working.** L3 is re-shaped, not dropped.
- **Native's hand-back for v3** sits on `pair/native-parkedroom` `5e5465af8` (`ae8d6e858`, `f16f49867`, `a7999c5c4`,
  `bcb0af2ba`, `6596e871c`) on an OLDER main. Native rebases it onto your v4 pair.
- **T4 PARKED on G2 (R33.30):** `pair/ghost-on-r34` `aacdfb4b6`; alone_s rises > 3 s on seeds 7, 8, 9, 14. Native's
  ghost-aware twins `pair/native-ghost-on` `b2b97188d` are unmerged.

## Backlog (in order)

1. **X1 The stuck-death census (REPORTED, dev fights only).** v3 ON v OFF on dev random fights (not 820–867, not any seed
   you will judge on), both arms, native, `far_census --far-kills=on`. Report deaths by cause: caught stuck or jammed, v in
   the open (define both in code before the run), kills by side, routs (a side losing ≥ N in a window). Does random-859
   generalise? Commit the table; send the orchestrator the hash and a three-line reading.
2. **X2 v4's design and bar, filed before any v4 number (C34.2).** v4 = v3 plus whatever the census and L6's 19 owed
   returns call for (L6's read time, or a way back that doesn't wait behind a still-driving asker). The bar: L1a/L1b/L2/L4/L5
   as v3's; **L3** = deaths in the open two-sided, stuck/jammed deaths ON ≤ base (one-sided), hit rate one-sided; **L6** read
   at a time named in the bar with its reason. FRESH fights from 868 up, × 3, native, ONE machine.
3. **X3 The v4 pair (C31.1, R33.32):** current main + v4 ON + native's rebased hand-back, nothing else. The full `make
   native check` goes green first, then the series, then the hand-over hash.
4. **X4 T4's trace (C34.3):** per-seed traces of 7, 8, 9 and 14 (ghost ON v OFF): which body route the Sirens' crews take
   and why the ghost changes it. Write it up. A fourth try is filed only if the traces name a fix; ask brains for an
   order-free body stage if the trace needs one.
5. **Stretch:** the engaged fire-post loops (a firing battery holds against its own column) are his T1c-b2 yes. Report the
   count on X1's fights; don't change it.

## How to verify

`make quick-remote` to iterate; `make native check` on the pair tree (switch ON) before any series, only for hashes you
name. `make traffic-far-census`, `far_ab.py --v3` (extend for v4), `traffic-series`, `traffic-census`,
`make traffic-t4-guard` / `traffic-t4-drive`. Long remote runs under `systemd-run --user`, launched FROM the pair's
worktree (round 33's slip: a script ran the stream worktree). Every number: commit, machine, workload, n.

## Don't touch

Manoeuvre's drive body, `_nose_stop`, `unstick`, the executor; brains' elements, `game/tactics/**`, `tank_brain.gd`;
planner's `game/ai/planner/**`; native's `native/**`; `game/match/**`; `tests/baselines/**`; `tools/judge/**`. Don't push.

## Waiting on the lead

Nothing.

## Status

_(the worker keeps this current: report at the top, every number with commit, machine, workload, n; green hashes named)_
