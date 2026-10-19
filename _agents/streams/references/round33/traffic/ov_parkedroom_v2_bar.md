parkedroom v2: the bar (filed before any number on its fights)

What changed from v1 (R33.12's two defects, read from the design reads on the OLD fights 700-723, builder2, ON, never
judged; references/round33/traffic/ov_parkedroom_v2_design.md):
- Gate: the room rule only for a crew AT a post = not under way AND still >= ROOM_STILL_S 2.0 s by Traffic's table clock
  (both drive paths refresh it). A crew paused for a moment between orders gets the ordinary give-way.
- Return: v1 left the way back to the brain. In fights only 359 of 1972 surviving room crews had the same order 30 s
  later, and of those only 65 % were inside the brain's own hold line (a hold ORDER returns only beyond max(3 m,
  settle + 1); an idle crew has a 30 m leash). v2 drives the crew back to the post itself once the asker is past, unless
  the brain has sent it somewhere new (a move_to more than 3 m from the post). A re-sent order (the CPU re-sends its
  orders; reset() drops the give-way) keeps the post owed, and the owed way back is checked on both drive paths
  (right_of_way, and Traffic.refresh for a holding crew the native drive runs). Dev reads on the old fights (never
  judged): L6 on unchanged orders 50 % → 58 % → 78 % (dev 5, 142 / 183), so the 90 % line below is a real risk.
Tree: stream/traffic-overnight 20b1cc113 (v2, DEFAULT_OFF; = main 2b40ce075-era + parkedroom); arm
--traffic-on=parkedroom, base none; native path; builder2,
both arms of every line on it. Every stage at --fixed-fps $(SIM_HZ). k = 1.645, se = paired se of the SUM, the pair's own
rows. FRESH fights: 724-771 x {terminus, locks, random} (n 144 paired, 180 s; only 700-723 have been read).

Pre-series gates: test_traffic_neck green (OFF never through in 40 s; ON through, scout back within 3 m 20 s later);
C31.1 the whole suite on the pair tree with parkedroom ON (pair/parkedroom-on-v2 5259fb463), green (builder2); one end-to-end fight episode
traced ON (traffic-far-one s403 crossing).
L1a (deciding) far loops behind a parked blocker on a HOLD post (far_table's "hold post" rows): arm <= 50 % of base.
L1b (deciding) all far loops behind a parked blocker: arm <= base + k*se (not up). Fire-post (T1c-b2) loops reported apart.
L2 (deciding) all far loops: arm <= base + k*se.
L3 (deciding) fights guard, the random arena's 48 fights: kills, deaths, hit rate each within base +/- k*se.
L4 (deciding) arrivals not down: traffic-series his four crossing cases (seeds 44-46 x six ticks, n 18 a case): crews in
   >= base - k*se per case.
L5 (deciding) T1c-b2 as shipped: traffic-census with the arm, runs with a repack while firing = 0.
L6 (deciding) the return: of the arm's room give-ways in L1's fights whose crew is alive 30 s after it began AND whose
   order did not change (goal moved <= 1 m, same verb): >= 90 % within 3 m of the post they left. REPORTED: the same over
   all alive crews; how many had a new order; and the line without crews giving way to someone else at the read. (A bar change from v1's L6, which counted crews the element had moved:
   in CPU fights most orders change within 30 s, and v2 lets a new order win by design.)
R (reported) room give-ways a fight, median and worst (v1: 42 / 111), and ways back begun.
Verdict: ships ON (a DEFAULT_OFF flip) only if L1a-L6 all pass; a fail is traced (the worst fight read first).

**Amended at filing (the orchestrator, workstreams.md on main):** L6 needs ≥ 50 unchanged-order room give-ways, or it
reads INCONCLUSIVE and cannot pass. The tree meets R33.32's main-only rule (main + movement.gd and traffic.gd only).

## Result (2026-10-18): FAIL on L3 and L6. v2 does not ship ON; it stays DEFAULT_OFF.

Tree `pair/parkedroom-on-v2n` `e7b202760` (game code = native's hand-back `5e5465af8` on `5259fb463`). builder2,
`native traffic-far-census`, fresh fights 724-771 x {terminus, locks, random}, n 144 paired, base
`--traffic-off=parkedroom`, --fixed-fps 30. Raw: `ov_parkedroom_v2n_series.txt`. Gates: C31.1 suite 2783 / 0
(sim-baseline moved on terminus, sumps, parade: the ON arm's own change); trace PASS (`ov_parkedroom_v2n_trace.md`).

| line | reading | verdict |
|---|---|---|
| L1a hold-post far loops | base 39, arm 1 (drop 38, se 14.5) | PASS |
| L1b parked far loops | 51 -> 39 | PASS |
| L2 all far loops | 83 -> 95, line 134 | PASS |
| L3 fights guard (random, n 48) | kills 1964 / 1957, deaths 1979 / 1971 within; hit rate 0.714 -> 0.731, paired se of the mean 0.0086 (out by 0.003) | FAIL |
| L4, L5 | not run (verdict already decided; builder2 went to item 4) | - |
| L6 the return | unchanged-order rooms alive at 30 s: 395, within 3 m of the post 248 (63 %; line 90 %) | FAIL |
| REPORTED fire-post far loops | 12 -> 37 (locks-727 10, locks-736 7, locks-753 6: branched fights; 19 of the 37 not engaged = item 4's idle-truck kind) | - |
| R | room give-ways a fight median 12, worst 68; ways back begun 1167; native ask_handed_back median 21, worst 162 a fight | - |

**Traced (the L6 misses, n 147).** The way back runs: 53 misses ended on their own room-back, and 89 of the 147 are
only 3-6 m off. But 99 of the 147 are inside the brain's own hold line around their ORDER GOAL. The post they left was
the spot they had been parked on, a median 3.1 m off the goal, and after the room the hold order took them to the goal
itself. Only 48 (12 % of 395) are off station by both readings (17 still owed the way back at the read, 31 not). So
most of L6's failure is the bar's choice of "the post it left" over "where its order holds it". That is a reading, NOT
a re-judge: as filed, L6 fails. **L3's hit rate is out on the GOOD side** (the arm hits more), and the line is
two-sided as filed.

**For a v3 (the orchestrator's call; none started):** return to the order's hold point when the crew has a hold order
(the brain's own home) rather than the parked spot, and an L6 that reads "inside its hold line" on new fresh fights. L3
one-sided (not worse) would need the bar amended before any number.

## Amendment R33.36 (the orchestrator, filed before any number): v3

**v3:** a crew on a HOLD order owes the way back to its hold point (the order's goal); any other crew to the spot it
left (`Movement._room_home`). Gate, way back, switch and native hand-back unchanged (the hand-back hands every AT-post
ask and executes every crew with a post owed, whatever that post is). Tree: a new pair, v3 + native's `5e5465af8`, with
its own C31.1 (builder2). FRESH fights 820-867 x {terminus, locks, random} (n 144 paired). Everything else as filed, except:
- **L6** = of the arm's room give-ways alive at 30 s with the order unchanged, >= 90 % are within 3 m of the post they
  left OR inside their hold line around the order goal (from_goal_m <= hold_line_m); needs >= 50 such rooms.
- **L3 one-sided (no worse):** hit rate arm >= base - k*se (higher is better). Kills and deaths are both teams' sums,
  so they have no good side: they stay within base +/- k*se (traffic's reading of "no worse", sent to the orchestrator
  with this amendment).

## v3 result (R33.36, 2026-10-18): FAIL on L3 and L6. v3 does not ship ON; parkedroom stays DEFAULT_OFF.

Pair `pair/parkedroom-on-v3` `6d0e00652` (v3 + the hold-point early end, on native's hand-back `5e5465af8` line).
builder2 from start to end, native, fresh fights 820-867 x {terminus, locks, random}, n 144 paired, base
`--traffic-off=parkedroom`. Gates: C31.1 2784 / 0 (sim-baseline moved on terminus, sumps, parade, docks: the ON arm);
pre-series trace PASS (`ov_parkedroom_v2n_trace.md` v3 section). Raw: `ov_parkedroom_v3_series.txt`.

| line | reading | verdict |
|---|---|---|
| L1a hold-post far loops | 59 -> 18 (drop 41, se 22.2) | PASS |
| L1b parked far loops | 224 -> 63 | PASS |
| L2 all far loops | 411 -> 201 (drop 210, se 97.6) | PASS |
| L3 fights guard (random, n 48) | hit rate 0.736 / 0.736 (one-sided: PASS); kills 2072 -> 1992 (drop 80, se 40.9), deaths 2090 -> 2008 (drop 82, se 40.8): outside base +/- k*se | FAIL |
| L4 crossing arrivals (seeds 44-46 x 6 ticks, n 18 a case) | 180/180, 180/180, 178/178, 180/180: identical | PASS |
| L5 traffic-census, the arm | repack while firing 0 of 9 | PASS |
| L6 (R33.36) the return | unchanged-order rooms alive at 30 s 448; at the post or inside the hold line 403 = 89.96 % (line 90 %) | FAIL |
| REPORTED | fire-post far loops 135 -> 45; room give-ways a fight median 14, worst 38; ways back begun 1314; native ask_handed_back median 29, worst 205 a fight | - |

**Traced.** L3: in the random arena kills fell in 29 of 48 fights, rose in 10. The worst fights are random-859 (54 -> 34),
random-835 (73 -> 54) and random-828 (26 -> 11). Shots are unchanged there (53833 -> 53492, -0.6 %) and the hit rate is
equal, so the same hits convert into fewer kills. On terminus and locks, kills are flat (-0.9 %, -0.1 %). Why is NOT
traced yet (next: random-859 with both arms, kills by hull and when). L6: 45 misses, all hold orders; 19 still owed
the way back at the read (the asker mostly still driving); 15 ended a way back 4-23 m off the goal; from the goal
4.2-23 m. One more crew home would have passed L6; no re-read is proposed.
