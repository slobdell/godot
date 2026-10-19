T4 ghost ON, third try: the bar (filed before any number)

Tree: pair/ghost-on-r34 2b41d3a04 = main + ghost out of OPT_IN (ON by default) + traffic-t4-guard tooling; the OFF arm is the same tree
with --traffic-off=ghost. Native path where the stage has one. Machine: builder2 for every line, both arms of a line on
it. Every stage pinned at --fixed-fps $(SIM_HZ) (30). FRESH seeds throughout. k = 1.645, se = the pair's own paired se
of the sum.

G. The cohesion guard (brains' f8cf6476 shape: each arm a fresh body_probe.gd child, --fixed-fps 30, Locks, green side):
   seeds 7-18 (n 12), arms ghost OFF / ON x body OFF / ON (48 children).
   G1 (deciding) median body-ON alone_s: ghost ON <= ghost OFF + 3.0 s.
   G2 (deciding) seeds where ghost ON's body-ON alone_s exceeds ghost OFF's by > 3.0 s: at most 2 of 12. (Per-cell
      differences here are real, not noise: each child is deterministic. So the line counts losers rather than
      demanding none.)
   G3 (deciding) the Sirens choose the body route ghost ON in at least as many seeds as ghost OFF.
   G4 (deciding) the suite's own line, seed 1: ghost ON body-ON < 0.5 x body-OFF (test_tactics_body, run by the check).
R. Replay.
   r1 (deciding) a FRESH process replays exactly with the ghost ON: body_probe children, seeds 7-18, each seed run twice
      in two processes, the whole BODY_PROBE line identical (every field), plus rematch_probe's run-0 digest (every
      tank's position, real and estimated velocity at every tick) identical across two processes, seeds 7-18.
   r2 (REPORTED) a same-process rematch's branch rate (rematch_probe --arms=off,off --diff=on --diff-y=off), ghost ON v
      OFF, seeds 7-18, n 12 each: how many branched, and each branched seed's alone_s run 0 -> run 1.
7. C31.1: make check on the pair tree 2b41d3a04 green (builder2), before the series.
T. The Terminus re-judge: C33.7's lines unchanged, on FRESH seeds: drive 849-896 (n 48 a squad, mixed + rigs, paired,
   round 32's T4 reader). (1) deciding: mixed friend-stuck crew-s arm < base and (base - arm) - k*se > 0. (2) rigs stuck
   arm <= base + k*se. (3) pinned (mixed, rigs) arm <= base + k*se. (4) arrivals (mixed, rigs) arm >= base - k*se.
   (5) REPORTED: yard head-on settle and between-squad fast contacts, traffic-series seeds 44-46 x six ticks, n 18.
   (6) skirmish guard: showmatch fights random arena, FRESH seeds 924-947, n 24: kills, deaths, hit rate, far loops each
   within base +/- k*se.
Order: 7, then G and R (cheap), then T. A fail on G1-G4, r1, 7 or T(1) parks T4 with the reading; no partial rule.

**Amended at filing (the orchestrator, workstreams.md on main):** T(2), T(3), T(4) and T(6) are DECIDING guards too,
alongside G1–G4, r1, 7 and T(1). A ghost that cuts friend-stuck but costs arrivals or kills doesn't ship.

## Result: T4 PARKED on G2 (2026-10-18)

builder2, `make gcp-remote T="native traffic-t4-guard"` on pair/ghost-on-r34 `aacdfb4b6` (game code `2b41d3a04`), native
path, each arm a fresh body_probe child at --fixed-fps 30, seeds 7–18 (n 12). Raw: `ov_t4_guard.txt`.

- **G1 PASS:** median body-ON alone_s ghost OFF 14.0, ON 15.5 (line 17.0).
- **G2 FAIL (deciding):** 4 of 12 seeds have ghost ON > OFF + 3.0 s (s7 +6.5, s8 +4.0, s9 +3.5, s14 +4.0); line <= 2.
  The other side: s16 57.5 → 16.5 (−41.0), s18 −5.5. Median per-seed difference +0.75 s.
- **G3 PASS:** the Sirens choose body in 7 of 12 seeds in both arms.
- **r1 PASS:** a fresh process replays exactly ghost ON, 36 of 36 pairs identical (ghost OFF 36 of 36).
- **r2 REPORTED:** a same-process rematch's digest differs on 12 of 12 seeds in BOTH arms (sub-micron at least);
  alone_s moves on 4 of 12 ghost OFF and 5 of 12 ghost ON.
- **7 (C31.1) RED** before it (`ov_t4_line7.txt`): four native coverage floors starve ghost ON (R33.29: native makes
  its twin stages ghost-aware). **T not run** (it waited on 7, and G2 parks T4 anyway).

The reading: on Locks the ghost is a wash in the median, but it costs the body-route squads 3.5–6.5 s on a third of the
seeds, wins big on one (s16) and changes nothing on the rest. Per-seed differences are deterministic, so this is the
ghost's effect, not noise. A fourth try needs a ghost that doesn't slow the formed body on those seeds (trace s7, the
worst), or a bar that judges the cohesion stage on more than Locks.
