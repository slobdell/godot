# Stream: combat (the rigs yaw through walls: the plant predicate, then the constraint back on; ORBIT reads hull length)

> Read `HANDOFF.md`, [orchestration.md](../orchestration.md) (*The worker contract*), [game_design.md](../game_design.md)
> (*Round 10 direction*), [workstreams.md](../workstreams.md) (*Round 10: the eight streams*, contracts **R5**, **R6**,
> checkpoints **CP3**, **CP4**; *What reads `hull_size`*), [balance.md](../balance.md), and your round-9 brief
> [archive/round9/combat.md](archive/round9/combat.md) — its "ROUND 10 STARTS HERE" list (the predicate, the ordering,
> diagonal spacing, the artillery scenario, gangs-vs-law, ORBIT) is the backlog below, in its order.
>
> **You own** `game/units/`, `game/combat/`, `game/match/`, `game/tank/` except `tank_motion.gd`,
> `tools/{match_series,matchup_matrix,combat_duel,matchup_search}.py`, `mk/match.mk`, `game/modes/match_runner_mode.gd`,
> `_agents/balance.md`. **Carve-outs this round (you review at merge):** arena holds `SLOT_X`, `SPAWN_ROWS`,
> `SPAWN_ROW_SPACING` in `match.gd`; feel holds `turret_mount` (R5: a new optional key per profile and the three-axis
> write in `Tank._apply_hull_size`) and the `hull_size`/`muzzle_height` VALUES of `tank` and `burner` (R6).

## The lead's direction (2026-09-20, evening; verbatim in game_design.md *Round 10 direction*)

> You alreayd mentioned that the truck rigs had yaw problems. Units are still driving into walls.

Round 8's words behind it: the semi "yawing in place" through scenery. The plant resolves a hull's position against
collision and not its rotation; the round-9 constraint (`Tank._fitting_forward`, `yaw_fit_enabled`) fixes 74 % of the
illegal yaw in a corridor (44.0° → 11.6°, footprint 12.1 → 6.1 m at the corrected two-arm table) and, on, freezes four
of five squads at spawn. It shipped OFF. **This round it comes back on or the reason it cannot is a mechanism, not a
correlation.**

## Where things stand

- **The refusal ranking killed the diagonal-spacing story** (your table, laptop, `DRIVE_TRACE` on the five off-slot
  crews of `test_five_squads_ordered_in_quick_succession`): `Green_Charlie_3` at 3.19 m across refused 1135
  CONTINUOUS ticks; `Green_Charlie_1` at 0.06 m refused 1260; `Green_Alpha_4` seated after 128 at a tight 0.26 m, and
  what sets it apart is that Alpha was ordered FIRST. The across gap predicts nothing; the counter never resets, so
  this is a freeze, not a stall. `Green_Echo_1` produced zero traced ticks (a gap in the data, not a row). Repro:
  `TUNE=match.yaw_fit=1 DRIVE_TRACE=<crew> make test FILTER=ai_player_orders`.
- **The tune plumbing is fixed** (`_ensure_env_tuning`, point-of-use readers, the two-arm load-order test at
  `d6daa3b3`: every knob's test asserts the PREDICATE moved, lesson 195). The world-only mask arm (`match.yaw_world`)
  measured a frozen hull (offered 30, applied 30, refused 30, swept 0.0°) and moved a corridor with no vehicles in
  it: two APIs, not one mask (lesson 201's shape). If the mask question is asked again it is `test_move` in both arms
  with only the collider set swapped, "the corridor must not move" as the arm proof.
- **The settle tick landed** (`Tank.place()`, one declared baseline move); `SPAWN_LIFT_M` 0.0; the disc sites behind
  `match.hull_disc` (disc default until the series); the suppression assertion; the engine-deck columns.
- **Two scenarios are yours:** `scenario_cp2::test_a_scout_works_onto_a_tanks_engine_deck` is red on main because the
  scout's ORBIT radius is tuned to a hull length that no longer exists (scale's arm: tank 8.62 → 3.60 m took deck hits
  0 → 22 of 43); `scenario_cp2::test_artillery_stays_dug_in_on_a_moving_target` was passing on a neighbour's leaked
  navigation state and fails in 0.6 s once drained (metrics' four-run table in
  [archive/round9/metrics.md](archive/round9/metrics.md)). The count baseline is `41,3,3,0`; the orchestrator
  re-records with your REASON.
- **nav is building a wall-contact instrument** (its item 1) and a Terminus drive test (its item 2). A hull ROTATING
  through a wall in that test is your row; a hull DRIVEN into one is nav's. Expect its log; ask for a getter if the
  plant does not expose its collision report and add it (yours).
- **feel writes into your files under two carve-outs** (R5 `turret_mount`, R6 the bus box). Review at merge for the
  mechanism (the write is three axes, default preserves today's pose; the box change is CP3 and moves the baseline).

## Backlog (in order)

1. **The predicate.** Why does `_fitting_forward` accept none of three candidate yaws (1.0/0.6/0.3 of the wanted
   step) for over a thousand consecutive ticks on a hull that is clear on every axis anyone measured? Instrument
   what each candidate's `_penetration` returns against WHICH collider, per tick, on `Charlie_3`, and on the seating
   `Alpha_4` for contrast. Hypotheses to rank before you look, with their signatures: (a) the "current" penetration
   is already non-zero against a squadmate and every candidate compares worse by a hair (dominance, your own
   correction); (b) `test_move` answers a boolean and two touching hulls saturate it; (c) the candidate transforms are
   built from a stale basis (the settle tick's `state_for`); (d) the yaw wanted is toward the goal but the refusal
   compares against the world layer where a kerb container sits. The answer is a mechanism with the tick it happens
   on. Constraint OFF throughout.
2. **The ordering.** five_squads with the squads ordered in the other four orders: does the seating squad follow the
   order or the geometry? One table.
3. **The fix the predicate implies**, as an arm with both claims measured on the same pair: the slots (five_squads, 0
   of 30 off) AND the corridor (44.0° → 11.6°, 12.1 → 6.1 m, the residual ≤ 1.8 m, giveups) AND nav's wedged rig
   (offered/applied/refused, never a freeze). Diagonal-derived spacing is a CANDIDATE with the table beside it (squad
   is deriving the pitch from the turning envelope this round and arena the spawn grid: after both land, re-run
   five_squads with the constraint on before concluding anything about the predicate). **CP4:** the constraint's
   default flips ON only when all three pass on one build; it moves the baseline; merged alone.
4. **ORBIT radius reads hull length.** The scout's orbit against a target reads `hull_size[2]` (or the box's reach
   along the bearing via `hull_reach_along`), the engine-deck scenario goes green on the resized tank, the REASON is
   written for the count re-record.
5. **The artillery scenario, honestly.** Reproduce with the drain; why does the artillery leave its dug-in position
   on a moving target once the map is clean? Fix the behaviour or re-specify with the reason.
6. **The gangs-vs-law series with `match.hull_disc` as the arm** (stretch; the lead's convergence call deferred it):
   feel's matrix as the before (pit 20 %, yard 50 %), per cell, never pooled, the null pre-registered as evidence
   AGAINST the disc being the cause; the box becomes default only on a result no worse on every cell.
7. **Stretch:** `Units.stat()`'s `has()` guard (C1); A2's verdict once metrics' cusp split is read; the duel's
   hide/peek regression named.

## How to verify

- `make check` green (`make remote T=check`); `make ai-scenarios` with the count beside the hash;
  `make test FILTER=ai_player_orders`, `FILTER=tank_yaw_fit`, `FILTER=nav_face_recovery` (nav's, run it: the wedged
  rig is your falsifier too).
- `make skirmish ARENA=terminus` with War Rigs: do they turn at a corner without the trailer passing through the
  block? Frames at his pose.
- Every number: commit, machine, sample size, the arm proven applied; every baseline move pre-registered with one
  cause and merged alone.

## Don't touch

`game/ai/**`, `game/tank/tank_motion.gd` (nav's: send the log and a failing test), `game/tactics/**` (squad's),
`arenas/`, `game/arena/` and the three spawn constants (arena's), `game/theme/**`, the `turret_mount` values and the
`tank`/`burner` boxes (feel's this round; review, do not set).

## Waiting on the lead

Nothing blocks. Balance is deferred by him; the series (item 6) reports, it does not tune.

## Research addendum (brief 2, 2026-09-20 evening; rows B2, B3, B9 in `research_catalog.md` *Round 10 addendum*)

**The freeze has a candidate mechanism, and it reorders item 1.** The reply names the sequence: formed-up hulls settle
INSIDE each other's collision margins (a non-zero penetration baseline), every candidate yaw compares worse against
the SQUADMATE contact, both hulls refuse, and the deepest contact masks the wall term. Your ranking measured LATERAL
gaps only; nose-to-tail contact was never measured, which is consistent with a 3.19 m-across crew refusing as long as
a 0.06 m one. So item 1's instrument is: per candidate per tick, the identity and depth of the deepest contact
collider, on the refusing crews AND the seating one. Confirmed if the refusers' deepest contact is a squadmate and
Alpha_4's is not. Then the fix family, in this order: (i) a capsule-string / multi-circle hull for the yaw test (its
distance field is monotone in yaw: no OBB discontinuity, no masking); (ii) a turning-envelope reservation before a
rotation, yield by priority (unit id) if denied; (iii) elongated wheeled hulls do not rotate in place at all (yaw
coupled to forward speed), which is what the creep already tries to be. CP4's three bars are unchanged and gain a
fourth: zero runs of more than 3 consecutive refused ticks anywhere in five_squads.

**The series gains two arms (B9):** physical collider (rescaled vs legacy mesh) × AI perception (disc vs box): arm B
(true mesh, box) decides whether perception caused 9/20 → 0/20; arm C (legacy mesh, scaled disc) whether perception
alone suffices. Per cell, never pooled. The aspect-exposure formula (broadside 4.2× head-on for the rig) is the other
candidate: a hull that cannot keep its nose on the threat; `hull_reach_along` already computes the chord.

**Stretch (B3):** the trailer as a second HINGED collider placed analytically from feel's hitch kinematics (no joint
solver; RK2 on the articulation angle; a jackknife lock in reverse), so a shell through a fold misses. Moves the
baseline once; not before the lead asks.

## Research addendum 2 (brief 3, 2026-09-20 late; rows C2, C6, C7, C8)

**The series' design changes (C6).** The one `match.hull_disc` knob flips three sites at once and can only say
"the disc" or "not the disc". Intervene on ONE site at a time with the disc kept in the others: the friendly-fire
line-of-fire site (`match.gd:1383`), the incoming-projectile site (`match.gd:1450`), squad's `incoming_fire.gd:101`
(squad's file; ask for the knob), and the aim point. Then Shapley effects over the subsets if the sites interact.
**Run every arm on the SAME seed list** (common random numbers) and report discordant pairs (McNemar), never pooled
rates: ~32 paired seeds per cell detect a 25-point shift, ~64 size a component; stop a dominated arm early with a
sequential test. Ten unpaired matches per cell (round 9's design) is retired.

**Counterfactual forking (C7) is the instrument that avoids the butterfly:** replay a seed to a checkpoint every
~5 s, fork under each configuration for 1 tick (which predicate flipped: friendly-fire blocked, threat, mode) and for
5 s (net damage from the identical state). Our determinism makes it a match-runner flag (`--fork-at=T` plus a tune).
The pre-registered arm the reply proposes: rescaled bodies, disc kept for spacing, box for line-of-fire AND threat;
its prediction is that this recovers most of the lost win rate. Record the prediction, then run it.

**Two traps to check before believing any cell (C8):** (a) the aim point: after the rescale (and R5's turret mount),
does every weapon aim at the target's hull centre at height, or at its origin? A test. (b) hard thresholds in the
selectors near the disc radius flip modes on a 1 % change; list them beside A2's verdict.

**"Who yields" for the yaw reservation (C2):** the deterministic key nav adopts (emergency brake, clearance slack,
stopping distance, distance to goal, unit id) is the tie-break for B2's turning-envelope reservation too; do not
invent a second one.

## Status

_(the worker keeps this current)_
