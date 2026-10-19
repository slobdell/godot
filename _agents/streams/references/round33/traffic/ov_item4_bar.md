# Item 4: T1c-b2 narrowed to a battery with a fire mission (bar FILED before any number)

From the random-705 diagnosis (`ov_firepost_r705.md`; brains agrees, the orchestrator assigned it as overnight item 4).

**The change (traffic's, movement.gd; native mirrors it):** `Movement.on_fire_post()` reads true only when the hull is
set up (deploy_ratio > 0), has a fire order that isn't hold_fire, has no move of its own under way, AND has a fire
mission: its weapon order is `target` or `suppress` (the player's or the brain's fire order at someone), or it has an
engaged target. A truck dug in on `fire_at_will` with nothing to shoot is asked like any parked crew. The lead's T1c-b2 yes
stands: a truck ORDERED to fire stays set up for a passer. Switch: `--traffic-off=firemission` restores today's reading.
**Native:** `Drive::on_fire_post()` (drive_native.cpp:2448) mirrors the GDScript today and must read the same fire mission;
that is native's C++ (a pair, as C26.2's gate pairs were). test_traffic_setup gains the idle-truck case.

**Bar (filed before any number):** tree = a pair: main with brains' battery item ON (so the askers' stall dig-in is
gone; whichever of its switches ship) + the narrowing + native's on_fire_post mirror; arm = default, base
`--traffic-off=firemission`; native path, every run `native <target>`; builder2, both arms; --fixed-fps 30; k = 1.645, se =
paired se of the sum; FRESH fights.
1. (deciding) random-705 on the pair tree, both arms: fire-post far loops arm 0. If the case no longer arises on that
   tree (base 0 too), the traced reason is reported and line 2 decides alone.
2. (deciding) fire-post far loops, traffic-far-census FRESH fights 772–795 × {terminus, locks, random} (n 72 paired):
   arm ≤ base AND (base − arm) − k·se > 0 if base has ≥ 10 such loops, else arm ≤ base.
3. (deciding) T1c-b2 as shipped: traffic-census with the arm, a repack while firing = 0.
4. (deciding) brains' battery census (Sumps/Parade/Foundry × FRESH seeds 59–64, n 18) both arms: artillery shots arm ≥
   base − 5 %; median first shot after a fire order arm ≤ base + 5 s.
5. (deciding) line 2's fights: all far loops arm ≤ base + k·se; the random arena's 24: kills, deaths, hit rate within
   base ± k·se.
6. (deciding) C31.1: the whole suite on the pair tree, green.
Ships ON only if 1–6 pass; a fail is traced (the worst fight first).

## Result (2026-10-18): FAIL on line 2. Item 4 does not ship ON; firemission stays DEFAULT_OFF.

Tree `pair/firemission-on-n` `23251f069` (= native's mirror `5b6aa0fd2` on main-based `0d3f45b25`, plus test fix
`328778c94`). builder2, native, base `--traffic-off=firemission`, --fixed-fps 30. Raw: `ov_item4_series.txt`.

| line | reading | verdict |
|---|---|---|
| 1 random-705 | fire-post far loops base 0, arm 0: the case no longer arises on this tree (battery (a) merged, `32e740843`; not traced further), so line 2 decides alone | NOT ARISEN |
| 2 fire-post far loops (fresh 772-795 x 3, n 72) | base 34, arm 29, drop 5, se 14.4 (base >= 10: drop - k*se > 0 needed) | FAIL |
| 3 traffic-census, the arm | runs with a repack while firing 0 of 9 | PASS |
| 4 battery census (Sumps / Parade / Foundry x 59-64, n 18) | art shots 594 v 595 (line >= 565); first shot median 2.8 v 2.8 s | PASS |
| 5 guards | all far loops 101 -> 86 (line 135); random n 24: kills 992 / 989, deaths 1001 / 998, hit rate 0.715 / 0.713 within | PASS |
| 6 C31.1 | `make native check` exited 0, 2782 / 0, sim-baseline unmoved, perf 1.15x | PASS |

**Traced (line 2).** All 29 of the arm's fire-post loops have an ENGAGED blocker: a battery with a real fire mission,
which is the lead's T1c-b2 yes, kept by design. The base's 34 = 24 engaged + 10 idle (not engaged). The arm's idle
fire-post loops are 0. So the change did what it narrows (idle 10 -> 0); line 2 counts both kinds, and on this tree the
engaged kind dominates (terminus-775 alone has 12 in the arm, 1 in the base: a branched fight). As filed, it fails.
**For a re-judge (the orchestrator's call):** a line on IDLE (not engaged) fire-post loops, on new fresh fights.

## Amendment R33.36 (the orchestrator, filed before any number on its fights)

Re-judge on the same pair (`pair/firemission-on-n` `23251f069`), builder2, native, FRESH fights 796-819 x {terminus,
locks, random} (n 72 paired). **Line 2 becomes:** IDLE fire-post far loops (blocker on its fire post with NO fire
mission: not engaged) arm = 0 AND arm <= base. Engaged fire-post loops REPORTED (the lead's T1c-b2 keeps those). Line 5
is read on these fights. Lines 3, 4, 6 are unchanged and stand from the first run on this same pair (same tree, same
seeds as filed).
