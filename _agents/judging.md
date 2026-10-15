# Judging: how a bar is sized by its probe's noise (round 30, sizing)

> **Why this file exists.** builder0 is the bottleneck (loaded checks 53–60 min v 41 quiet; judged series queue for hours),
> and until round 30 every series was sized by feel (n = 18 a case, three seeds × six ticks) and every guard was a round
> number (+5 crews; ≤ +20 %). Rounds 27–29's judged lines, read against their own rows
> ([`references/round30/sizing/inventory.md`](streams/references/round30/sizing/inventory.md)), show **42 of 122 judged pass
> lines inside their probe's noise**: a treatment that changed nothing would have failed that guard (or passed that gain line)
> more than one time in twenty at the n used. M1's +5 guard was one of them; so was every "crews ≥ base − 2" line. With
> round 30's judged pairs in (*Round 30 re-render*, below) the count is **56 of 194 through round 30**: 14 of round 30's 72.
> This file is the method that replaces feel: **the probe's noise → the smallest n that decides the effect the bar names
> → lines set from the noise → pre-register → judge, stopping early when the series is decided.**
> Every number here is reproducible by a `tools/judge/` command on a file under `streams/references/`; generated blocks
> carry their marker and are rewritten by `python3 tools/judge/table.py`. Contract C30.3: a bar pre-registered after CP-N
> cites its row here (or says why it departs).

## The table (CP-N): one row per probe × metric

**How to read a row.** *sd a run* is the probe's noise: the sd of the per-run paired difference (arm − base on the same
seed and start tick), pooled over every judged pair of rounds 28–30 in which the treatment acted in at least a third of the
runs (a pair where the rule never fired is byte-identical and is an equality check, not a sample; the pairs are named in
`table.csv`'s `pairs` column). *base a run* is the base
arm's level per run, so an effect named in % becomes an effect per run. *icc* is the share of that noise sitting between
seeds: near 0, a new start tick buys as much as a new seed; above 0.3, add seeds first. *se at n today* is the se of the
statistic the line compares (the sum over the runs for a total, the bootstrap sd of the median difference for a median) at
the n the latest judged bar used (round 29's, or round 30's where that round re-ran the probe: Terminus 13 seeds, hull-rest
15 runs with the class): **this is the number a bar quotes**. *n that decides it* is the paired n at which the effect
the bar names is detected with 80 % power at a 5 % one-sided false-pass rate (`stats.n_paired`); *MDE at n today* is the
smallest effect n today detects at the same rates; *noise-sized guard* is base ± 1.645 se, the line a "not worse than
base" guard should sit at so that a do-nothing treatment fails it 5 % of the time. Box-minutes are both arms at the
brief's per-run costs (traffic 1.75 min, hull-rest 2.5, fights 3.5, Terminus 4, census 4; loaded builder0), an estimate.

<!-- judge:table:begin -->
| probe | metric | form | noise: sd a run | base a run | icc | n today | **se at n today** (quote this) | the bar's line | effect named (a run) | **n that decides it** (80 % / 5 %) | MDE at n today | noise-sized guard at n today | box-min today → needed |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| traffic-series terminus/head | xfast | total | 16.70 | 22.09 | 0.0413 | 18 | 70.8 | between-squad fast contacts down >= 25 % | 5.52 (25 %) | **57** | 9.78 (44 %) | base ± 116.5 | 63 → 200 |
| traffic-series terminus/head | fast | total | 27.85 | 42.24 | 0.0283 | 18 | 118.2 | fast friendly contacts down >= 25 % (round 28's line) | 10.56 (25 %) | **44** | 16.32 (39 %) | base ± 194.4 | 63 → 154 |
| traffic-series terminus/head | ownfast | total | 12.89 | 20.15 | 0.0491 | 18 | 54.7 | same-squad fast <= base x 1.2 + 10 | 4.03 (20 %) | **64** | 7.55 (37 %) | base ± 89.9 | 63 → 224 |
| traffic-series terminus/head | arrived | total | 0.975 | 9.59 | 0.124 | 18 | 4.14 | crews in >= base - 2 (over 18 runs) | 0.111 (1 %) | **477** | 0.572 (6 %) | base ± 6.81 | 63 → 1670 |
| traffic-series terminus/head | allin | median | 17.45 | 60.08 | 0.148 | 18 | 5.85 | all-in median <= base + 20 % | 12.02 (20 %) | **27** | 14.54 (24 %) | base ± 9.62 | 63 → 94.5 |
| traffic-series terminus/head | fstuck | total | 41.17 | 32.77 | 0.166 | 18 | 174.7 | friendly-stuck <= base x 1.2 + 10 | 6.55 (20 %) | **244** | 24.13 (74 %) | base ± 287.3 | 63 → 854 |
| traffic-series terminus/cross | xfast | total | 2.69 | 5.08 | 0.114 | 18 | 11.4 | between-squad fast contacts down >= 25 % | 1.27 (25 %) | **28** | 1.58 (31 %) | base ± 18.8 | 63 → 98 |
| traffic-series terminus/cross | fast | total | 6.33 | 13.18 | 0.0809 | 18 | 26.9 | fast friendly contacts down >= 25 % (round 28's line) | 3.30 (25 %) | **23** | 3.71 (28 %) | base ± 44.2 | 63 → 80.5 |
| traffic-series terminus/cross | ownfast | total | 6.23 | 8.10 | 0.0729 | 18 | 26.4 | same-squad fast <= base x 1.2 + 10 | 1.62 (20 %) | **92** | 3.65 (45 %) | base ± 43.5 | 63 → 322 |
| traffic-series terminus/cross | arrived | total | 0.586 | 9.78 | 0.0665 | 18 | 2.49 | crews in >= base - 2 (over 18 runs) | 0.111 (1 %) | **173** | 0.344 (4 %) | base ± 4.09 | 63 → 606 |
| traffic-series terminus/cross | allin | median | 24.97 | 42.91 | 0.0833 | 18 | 7.32 | all-in median <= base + 20 % | 8.58 (20 %) | **81** | 18.21 (42 %) | base ± 12.0 | 63 → 284 |
| traffic-series terminus/cross | fstuck | total | 8.98 | 6.74 | 0.188 | 18 | 38.1 | friendly-stuck <= base x 1.2 + 10 | 1.35 (20 %) | **275** | 5.26 (78 %) | base ± 62.7 | 63 → 962 |
| traffic-series terminus/cross | xclear (crossing clock, s) | mean | 4.44 | 13.91 | 0.408 | 18 | 1.05 | mean paired cross_clear_s <= 0.10 x base median + 1.645 se (T3b; the effect here is 10 % of the base MEAN) | 1.39 (10 %) | **63** | 2.60 (19 %) | base ± 1.72 | 63 → 220 |
| traffic-series yard_open/cross | xfast | total | 1.77 | 6.11 | 0.488 | 18 | 7.51 | between-squad fast contacts down >= 25 % | 1.53 (25 %) | **9** | 1.04 (17 %) | base ± 12.4 | 63 → 31.5 |
| traffic-series yard_open/cross | fast | total | 7.68 | 15.56 | 0.261 | 18 | 32.6 | fast friendly contacts down >= 25 % (round 28's line) | 3.89 (25 %) | **25** | 4.50 (29 %) | base ± 53.6 | 63 → 87.5 |
| traffic-series yard_open/cross | ownfast | total | 7.16 | 9.44 | 0.162 | 18 | 30.4 | same-squad fast <= base x 1.2 + 10 | 1.89 (20 %) | **89** | 4.20 (44 %) | base ± 50.0 | 63 → 312 |
| traffic-series yard_open/cross | arrived | total | 0.66 | 9.35 | 0.0726 | 18 | 2.8 | crews in >= base - 2 (over 18 runs) | 0.111 (1 %) | **219** | 0.387 (4 %) | base ± 4.61 | 63 → 766 |
| traffic-series yard_open/cross | allin | median | 25.40 | 81.19 | 0.0192 | 18 | 8.89 | all-in median <= base + 20 % | 16.24 (20 %) | **34** | 22.11 (27 %) | base ± 14.6 | 63 → 119 |
| traffic-series yard_open/cross | fstuck | total | 12.25 | 9.89 | 0.185 | 18 | 52.0 | friendly-stuck <= base x 1.2 + 10 | 1.98 (20 %) | **238** | 7.18 (73 %) | base ± 85.5 | 63 → 833 |
| traffic-series yard_open/cross | xclear (crossing clock, s) | mean | 0.92 | 8.39 | 0.00 | 18 | 0.217 | mean paired cross_clear_s <= 0.10 x base median + 1.645 se (T3b; the effect here is 10 % of the base MEAN) | 0.839 (10 %) | **8** | 0.539 (6 %) | base ± 0.357 | 63 → 28 |
| traffic-series yard_open/head | xfast | total | 0.692 | 3.11 | 0.004 | 18 | 2.94 | between-squad fast contacts down >= 25 % | 0.778 (25 %) | **8** | 0.406 (13 %) | base ± 4.83 | 63 → 28 |
| traffic-series yard_open/head | fast | total | 1.52 | 6.67 | 0.00 | 18 | 6.45 | fast friendly contacts down >= 25 % (round 28's line) | 1.67 (25 %) | **8** | 0.891 (13 %) | base ± 10.6 | 63 → 28 |
| traffic-series yard_open/head | ownfast | total | 1.57 | 3.56 | 0.0276 | 18 | 6.65 | same-squad fast <= base x 1.2 + 10 | 0.711 (20 %) | **31** | 0.918 (26 %) | base ± 10.9 | 63 → 108 |
| traffic-series yard_open/head | arrived | total | 0.283 | 9.94 | 0.1 | 18 | 1.2 | crews in >= base - 2 (over 18 runs) | 0.111 (1 %) | **41** | 0.166 (2 %) | base ± 1.97 | 63 → 144 |
| traffic-series yard_open/head | allin | median | 7.57 | 33.90 | 0.0356 | 18 | 2.82 | all-in median <= base + 20 % | 6.78 (20 %) | **20** | 7.02 (21 %) | base ± 4.65 | 63 → 70 |
| traffic-series yard_open/head | fstuck | total | 2.50 | 0.886 | 0.133 | 18 | 10.6 | friendly-stuck <= base x 1.2 + 10 | 0.177 (20 %) | **> 1000 (not affordable)** | 1.46 (165 %) | base ± 17.4 | 63 → 4305 |
| traffic-series crossings pooled | xfast | total | 2.28 | 5.60 | 0.00 | 36 | 13.7 | between-squad fast pooled over the two crossing cases down >= 25 % (T3, T3b) | 1.40 (25 %) | **17** | 0.945 (17 %) | base ± 22.5 | 126 → 59.5 |
| hull-rest probe (a task) | crews still moving at 75 s, wheeled turret | total | 1.63 | 1.76 | 0.00 | 15 | 6.3 | guard: <= base + 5 crews a task (M1); <= base + 2 se (M1b) | 0.185 (11 %) | **478** | 1.04 (59 %) | base ± 10.4 | 75 → 2390 |
| hull-rest probe (a task) | crews still moving at 75 s, all classes | total | 1.85 | 2.32 | 0.00 | 15 | 7.17 | guard: <= base + 5 crews a task, all classes (M1); <= base + 2 se (M1b) | 0.185 (8 %) | **619** | 1.19 (51 %) | base ± 11.8 | 75 → 3095 |
| hull-rest probe (a task) | hull error median, wheeled turret (310 crews) | median | – | – | – | 27 | – | clicked within +-5 deg of base; point tasks median <= 15 deg; per-class permutation p >= 0.05 (M1b) | – | see *Count lines* / A/A | – | – | – |
| hull-rest probe (a task) | share within 15 deg, wheeled turret | share | – | – | – | 27 | – | >= 70 % within 15 deg | – | owed (A/A column) | – | – | – |
| hull-rest probe (a task) | settle time (75 s window) | median | – | – | – | 27 | – | settle paired median <= +6 s | – | see *Count lines* / A/A | – | – | – |
| pinned probe (hull-rest seeds, 144 runs) | pinned crew-seconds | total | 36.77 | 19.09 | 0.00 | 144 | 441.2 | down by > 2 se (M4 b2, M4b b2); sized here for a -50 % effect | 9.55 (50 %) | **92** | 7.62 (40 %) | base ± 725.8 | 121 → 77.3 |
| pinned probe | pinned crews (count) | total | 0.88 | 0.465 | 0.00 | 144 | 10.6 | down (M4 b2); reported (M4b) | 0.233 (50 %) | **89** | 0.182 (39 %) | base ± 17.4 | 121 → 74.8 |
| manoeuvre-fights (180 s) | kills | total | 5.76 | 41.00 | 0.00 | 24 | 28.2 | guard: within 2 se (M4, M4b); sized for a 5 % loss | 2.05 (5 %) | **49** | 2.92 (7 %) | base ± 46.4 | 168 → 343 |
| manoeuvre-fights (180 s) | deaths | total | 5.87 | 41.35 | 0.00 | 24 | 28.8 | guard: within 2 se | 2.07 (5 %) | **50** | 2.98 (7 %) | base ± 47.3 | 168 → 350 |
| manoeuvre-fights (180 s) | hit rate | mean | 0.0749 | 0.714 | 0.00 | 24 | 0.0153 | guard: within 2 se; sized for -2 pts | 0.02 (3 %) | **87** | 0.038 (5 %) | base ± 0.0252 | 168 → 609 |
| manoeuvre-fights (180 s) | hits | total | 329.98 | 858.15 | 0.00 | 24 | 1616.5 | reported (outside 2 se at M4; within at M4b) | 42.91 (5 %) | **366** | 167.48 (20 %) | base ± 2659.0 | 168 → 2562 |
| Terminus census, rigs (a seed) | arrived (of 16) | total | 1.68 | 13.66 | 0.00 | 13 | 6.07 | arrivals >= base (M2, M4); not down beyond 1 se / 1.645 se (M4b, M1b, M2b, kturnarc); sized for -10 % | 1.37 (10 %) | **10** | 1.16 (8 %) | base ± 9.98 | 104 → 80 |
| Terminus census, rigs (a seed) | wall contact-ticks | total | 894.41 | 828.70 | 0.00 | 13 | 3224.9 | <= base + 10 % (M2); down (M4); <= base + 1.645 se (M4b run 2); reported (M1b, M2b, kturnarc) | 82.87 (10 %) | **721** | 616.81 (74 %) | base ± 5304.4 | 104 → 5768 |
| Terminus census, mixed (a seed) | arrived (of 24) | total | 1.04 | 22.44 | 0.00 | 13 | 3.75 | arrivals >= base; not down beyond 1 se / 1.645 se (round 30) | 2.24 (10 %) | **2** | 0.718 (3 %) | base ± 6.17 | 104 → 16 |
| Terminus census, mixed (a seed) | wall contact-ticks | total | 253.54 | 145.09 | 0.00 | 13 | 914.2 | <= base + 10 %; <= base + 1.645 se (M4b run 2) | 14.51 (10 %) | **> 1000 (not affordable)** | 174.85 (121 %) | base ± 1503.7 | 104 → 15104 |
| ApproachStage flank probe (a roster) | on side (median hit bearing <= 35 deg), runs | count-runs | – | – | – | 18 | – | >= 12/18 (threshold) or v clicked 0/18 (comparison) | – | see *Count lines* / A/A | – | – | – |
| ApproachStage flank probe (a roster) | alive (of 5) | mean | 2.33 | 1.50 | 0.00 | 18 | 0.55 | guard: alive >= clicked - 0.5 | 0.5 (33 %) | **135** | 1.37 (91 %) | base ± 0.904 | 54 → 405 |
| ApproachStage flank probe (a roster) | first shot s | mean | 1.14 | 7.58 | 0.0607 | 18 | 0.269 | first round <= clicked + 10 s (B2 battery) / + 30 s (B1) | 10.00 (132 %) | **2** | 0.668 (9 %) | base ± 0.442 | 54 → 6 |
| ApproachStage flank probe (a roster) | hit on side share | mean | 0.121 | 0.245 | 0.00 | 18 | 0.0285 | side/rear share >= clicked | 0.05 (20 %) | **37** | 0.0708 (29 %) | base ± 0.0468 | 54 → 111 |
| ApproachStage flank probe (a roster) | median hit bearing deg | mean | 28.32 | 77.10 | 0.134 | 18 | 6.67 | (the count line's underlying metric) | 20.00 (26 %) | **13** | 16.60 (22 %) | base ± 11.0 | 54 → 39 |
| contact census (showmatch, a seed) | enemy hull contacts under an ordered MOVE | total | 9.39 | 9.25 | 0.00 | 12 | 32.5 | down >= 50 % (B3) | 4.62 (50 %) | **26** | 6.74 (73 %) | base ± 53.5 | 96 → 208 |
| contact census (showmatch, a seed) | recon deaths | total | 1.88 | 5.00 | 0.00 | 12 | 6.52 | guard: not up (B3); sized for +20 % | 1.00 (20 %) | **22** | 1.35 (27 %) | base ± 10.7 | 96 → 176 |
| scout census (showmatch, a seed) | fixed-gun contacts | total | 11.64 | 7.75 | 0.00 | 12 | 40.3 | down (B3 shipped line: 93 -> 24) | 3.88 (50 %) | **56** | 8.35 (108 %) | base ± 66.3 | 96 → 448 |
| scout census (showmatch, a seed) | gang_scout gun on target, pts of fight time | mean | 9.12 | 6.02 | 0.00 | 13 | 2.53 | >= +5 pts outside 2 se (CP-S v1/v2, S1) | 5.00 (83 %) | **21** | 6.29 (105 %) | base ± 4.16 | 104 → 168 |
| scout census (showmatch, a seed) | kills | total | 2.68 | 1.42 | 0.00 | 12 | 9.28 | guard: kills not down beyond 2 se | 0.283 (20 %) | **553** | 1.92 (136 %) | base ± 15.3 | 96 → 4424 |
| traffic-census (3 arenas x seeds) | artillery shots | total | 34.05 | 24.89 | 0.00 | 9 | 102.2 | not down > 2 se (T1c); not down > 21.6 (T1c-b: FAILED on one run, 171 -> 26) | 4.98 (20 %) | **290** | 28.22 (113 %) | base ± 168.0 | 90 → 2900 |
| traffic-census (3 arenas x seeds) | fast friendly contacts | total | 6.84 | 58.50 | 0.00 | 9 | 20.5 | <= base x 1.1 + 5 (T1c); <= base + 27.1 (T1c-b) | 5.85 (10 %) | **9** | 5.67 (10 %) | base ± 33.7 | 90 → 90 |
| traffic-census (3 arenas x seeds) | friendly-stuck s | total | 32.25 | 44.15 | 0.00 | 9 | 96.7 | <= base x 1.2 + 10 (T1c); <= base + 1.645 se (T1c-b) | 8.83 (20 %) | **83** | 26.73 (61 %) | base ± 159.1 | 90 → 830 |
| traffic-census (3 arenas x seeds) | runs with a repack while firing | count-runs | – | – | – | 9 | – | arm 0/9 and Fisher p <= 0.05 v base (T1c-b: 0/9 v 4/9, p 0.041) | – | see *Count lines* / A/A | – | – | – |
| yard crossing cell (seeds x 6 ticks) | runs with every crew in | count-runs | – | – | – | 12 | – | last crew in every run; median <= off - 5 s (B5c, B5c-v4) | – | see *Count lines* / A/A | – | – | – |
| Sumps cell (seeds x 6 ticks, a run) | all-within-8 m s (never = 90 s) | median | 12.92 | 37.53 | 0.766 | 12 | 6.61 | median on <= off; no run > 5 s later (B5c, B5c-v4); sized for the 5 s the lines name | 5.00 (13 %) | **130** | 16.43 (44 %) | base ± 10.9 | 36 → 390 |
| Sumps cell (seeds x 6 ticks, a run) | guns on arc (share) | mean | – | – | – | 12 | – | guns_on_arc >= off - 0.05 (B5c, B5c-v4) | – | owed (A/A column) | – | – | – |
| arrive series (100 cells) | cells within 8 m | count-cells | – | – | – | 100 | – | >= control - 1; 100/100 v 89/100 (B5c), 99 v 91 (B5c-v4), 95 v 88 (B2 v5), 97 v 93 (B3) | – | see *Count lines* / A/A | – | – | – |
| arrive series (100 cells) | all-within-8 m s, cells complete in both arms | median | 14.95 | 29.57 | 0.00 | 91 | 1.03 | median no slower than +2 % (B5c-v4: 29.6 -> 24.5 s over 91 complete pairs) | 0.591 (2 %) | **> 1000 (not affordable)** | 2.56 (9 %) | base ± 1.69 | 218 → 4080 |
| bridge-pooled (18 cells) / his bridge 108 | cells passed | deterministic | – | – | – | 18 | – | 18/18; 108/108 | – | see *Count lines* / A/A | – | – | – |
<!-- judge:table:end -->

**What the table says, in four lines.**
1. **The −25 % lines on traffic's between-squad fast contacts are sized for a halving, not a quarter.** At n = 18 the
   MDE is ~44 % of base on Terminus head-on; a true −25 % passes the line about half the time. CP-T's −81 % was decided
   inside one seed (n ≈ 6); T3's crossings (−54 %) inside two. Either name the effect you can see (−50 %) or run n ≈ 45–65.
2. **Every "crews ≥ base − 2" line is inside the noise.** The paired sd of crews arrived is 0.6–1.0 a run where squads
   meet, so over 18 runs the sum's se is 2.5–4 crews: a rule that changes nothing fails "−2" one time in four on Terminus
   head-on. The noise-sized guard is base − 4 (crossings) to base − 7 (head-on), or, better, the share of crews in with
   its se. (Yard head-on, where the arms barely diverge, is the exception: sd 0.24, se 1.)
3. **The hull-rest guard +5 a task needs ~480 runs with the class; n = 15 (round 30's grid) reads +10 (wheeled turret) or
   +12 (all classes); at round 29's n = 27 it read +12 / +15.** The clicked pairs, an A/A, moved the same count by −12..+10
   (M1) and −3..+11 (M1b). Say "≤ base + 2 se" and quote the se (M1_CLASS prints it): M1b did, and passed on every task.
4. **Terminus wall contact-ticks cannot carry a ±10 % line at any affordable n** (rigs: sd ≈ 890 a run on a base of 830
   over five judged pairs; MDE at n = 13 is +74 %; round 29's one pair read sd 1100, MDE +127 % at n = 6). Arrivals can
   (rigs sd 1.7 of 16: MDE −8 % at 13 seeds, −10 % decided at 10; mixed sd 1.0 of 24). Judge pins with the pinned probe's
   crew-seconds (144 cheap runs, MDE −40 %), and report contact-ticks as a median per run or not at all; M4b run 1's
   +141 % (+3.1 se) is what a reported line can still say.

## Count lines: what k/n v j/n means, and when 17/18 is a pass

<!-- judge:counts:begin -->
**Two arms' run counts (Fisher exact, one-sided 5 %), the n a side at which the OBSERVED rates reach 80 % power:**

| observed (arm v control) | one-sided p at the n run | n a side that decides it |
|---|---|---|
| 18/18 v 0/18 (B1 r29 on side) | 0.0000 | 3 |
| 14/18 v 0/18 (B2 (a) r29) | 0.0000 | 6 |
| 10/18 v 0/18 (B1 (a) r28, failed its 12/18 threshold) | 0.0002 | 9 |
| 4/18 v 0/18 (B1 (c) r28) | 0.0519 | 29 |
| 12/12 v 5/12 (B5c yard, every crew in) | 0.0023 | 9 |
| 12/12 v 1/12 (B5c-v4 yard r30, every crew in) | 0.0000 | 5 |
| 9/18 v 0/18 (S3 / S4 contact runs (read as 0 v 9)) | 0.0005 | 10 |
| 0/9 v 4/9 (T1c-b r30 runs with a repack while firing (read as 0 v 4 of 9)) | 0.0412 | 12 |
| 21/24 v 14/24 (B2 v4 Sumps cell) | 0.0245 | 34 |
| 12/12 v 10/12 (a 12/12 v 10/12 cell) | 0.2391 | 39 |

**One arm against a threshold ("on side ≥ 12/18"): how often the line passes at a true rate p (binomial):**

| line | p = 0.5 | p = 0.6 | p = 0.67 | p = 0.8 | p = 0.9 |
|---|---|---|---|---|---|
| ≥ 12/18 | 0.12 | 0.37 | 0.62 | 0.95 | 1.00 |
| ≥ 16/18 | 0.00 | 0.01 | 0.03 | 0.27 | 0.73 |
| ≥ 9/18 | 0.59 | 0.87 | 0.96 | 1.00 | 1.00 |
| ≥ 8/12 | 0.19 | 0.44 | 0.64 | 0.93 | 1.00 |
| ≥ 24/36 | 0.03 | 0.26 | 0.59 | 0.98 | 1.00 |

A threshold at two thirds of 18 runs passes a true 50 % rule a quarter of the time and fails a true 80 % rule a tenth of the time: it separates 0.5 from 0.8, not 0.6 from 0.75. The comparison form (arm v clicked, Fisher) is what decided every flank line that passed; write the count line as the comparison plus the rate's exact 90 % interval, and keep the threshold only where a minimum rate is itself the product promise (then size it: 0.67 v 0.5 at 80 % power needs n ≈ 116).

**Paired cells (the arrive series, the bridge cells): a rule that never acts leaves every cell identical, so the discordant cells carry the whole test (McNemar exact):**

| discordant cells (for v against) | exact p | reading |
|---|---|---|
| 11 v 0 (B5c arrive 100/100 v 89/100) | 0.0010 | decided |
| 8 v 0 (B5c-v4 arrive 99 v 91 (r30)) | 0.0078 | decided |
| 8 v 1 (B2 v5 95 v 88) | 0.0391 | decided |
| 5 v 1 (B3 make-room 97 v 93) | 0.2188 | not decided: a coin |
| 7 v 4 (B2 v3 89 v 86) | 0.5488 | not decided: a coin |
| 4 v 2 (B2 v4 85 v 83) | 0.6875 | not decided: a coin |
| 2 v 1 (B3b bridge 108: 107 v control 106 (r30)) | 1.0000 | not decided: a coin |
| 0 v 1 (M4 bridge 17/18 v 18/18) | 1.0000 | not decided: a coin |
| 1 v 0 (one cell gained) | 1.0000 | not decided: a coin |

Cells needed for a one-way gain (the arm wins cells the base loses, never the reverse) at 80 % power: a 11 % gain needs 71 cells, 5 % needs 157, 2 % needs 394. A line "lost ≤ 1" is a direction check on the against-cells alone; "≥ control − 1" fails on one unlucky cell, which at 100 cells of an 11 % base failure rate is a coin (p = 1.0 for 0 v 1).
<!-- judge:counts:end -->

**17/18 v 18/18.** One failing cell among 18 named, deterministic cells is not a sample statistic (McNemar 0 v 1: p = 1):
it is a regression in a named cell, and the rule for it is lesson 302's, read the run's trace, then decide. The bridge
cells and the 108 are *every-cell* checks by design; this file does not size them.

## A/A: what the same arm does on another seed set

<!-- judge:aa:begin -->
**traffic-series, the same arm on different seed sets (and commits): the swing of a case total at n = 18.** A null's swing between seed sets is what a 'within 2 se' or '≥ base − 2' line must clear.

| case | metric | hold ON (4 seed sets) | swing | hold OFF (4 seed sets) | swing |
|---|---|---|---|---|---|
| terminus/head | fast | 379, 322, 341, 335 | ±8 % | 716, 881, 871, 872 | ±10 % |
| terminus/head | xfast | 91, 54, 71, 90 | ±24 % | 398, 475, 474, 493 | ±10 % |
| terminus/head | arrived | 177, 177, 171, 179 | ±2 % | 170, 176, 170, 173 | ±2 % |
| terminus/head | allin | 59.3, 54.7, 61.2, 59.8 | ±6 % | 64.3, 60.8, 56.9, 56.5 | ±7 % |
| terminus/head | fstuck | 319, 326, 393, 341 | ±11 % | 489, 664, 700, 629 | ±17 % |
| terminus/cross | fast | 236, 226, 294, 246 | ±14 % | 294, 236, 183, 246 | ±23 % |
| terminus/cross | xfast | 112, 92, 116, 76 | ±20 % | 116, 112, 82, 106 | ±16 % |
| terminus/cross | arrived | 173, 176, 176, 176 | ±1 % | 176, 173, 176, 177 | ±1 % |
| terminus/cross | allin | 45.9, 39.4, 45.8, 50.8 | ±12 % | 45.8, 45.9, 35.6, 50.2 | ±16 % |
| terminus/cross | fstuck | 204, 136, 157, 92.6 | ±38 % | 157, 204, 99.6, 184 | ±32 % |
| yard_open/cross | fast | 247, 294, 277, 240 | ±10 % | 277, 247, 309, 232 | ±14 % |
| yard_open/cross | xfast | 111, 114, 118, 100 | ±8 % | 118, 111, 108, 120 | ±5 % |
| yard_open/cross | arrived | 166, 171, 169, 168 | ±1 % | 169, 166, 165, 163 | ±2 % |
| yard_open/cross | allin | 77.2, 69.2, 75.6, 90.0 | ±13 % | 75.6, 77.2, 90.0, 89.1 | ±9 % |
| yard_open/cross | fstuck | 159, 116, 196, 173 | ±25 % | 196, 159, 228, 133 | ±26 % |
| yard_open/head | fast | 115, 132, 113, 108 | ±10 % | 113, 115, 122, 97 | ±11 % |
| yard_open/head | xfast | 55, 60, 60, 52 | ±7 % | 60, 55, 63, 53 | ±9 % |
| yard_open/head | arrived | 176, 180, 179, 178 | ±1 % | 179, 176, 179, 180 | ±1 % |
| yard_open/head | allin | 30.9, 34.1, 37.2, 33.7 | ±9 % | 37.2, 30.9, 39.4, 30.1 | ±14 % |
| yard_open/head | fstuck | 13.5, 18.4, 8.9, 13.5 | ±35 % | 8.9, 13.5, 6.1, 12.7 | ±36 % |

The hold-OFF sets span three rounds of other merges, so part of that swing is code, not seeds; the hold-ON sets are three commits over two days (the fourth, `cf124433`, is T3b's base at round 30's close). Read the swing as the A/A ceiling a bar's guard must sit above when it compares totals across seed sets; within one seed set, a case the rule never touches swings 0 (the sim is deterministic per flags).

**hull-rest probe, the clicked pair at `d7385da2` (M1 never acts on a clicked order, so new_clicked v base_clicked is an A/A at n = 48 runs a task, 27 with wheeled turrets):**

| task | crews still moving: clicked new − base | hull-error median, ALL | wheels/turret |
|---|---|---|---|
| faced_ambush | -3 | -1.5° | -6.2° |
| faced_attack_move | +4 | -5.8° | -8.3° |
| faced_move | +0 | -0.4° | +2.9° |
| faced_right | -6 | -0.2° | +0.6° |
| faced_screen | +5 | -0.4° | +6.3° |
| faced_support_by_fire | -16 | -1.5° | -17.8° |

**hull-rest probe, the clicked pair at `55622870` (M1b's face_slot anchor, the same A/A at n = 24 runs a task, 15 with wheeled turrets; 303 crews a task, 165 wheeled turret):**

| task | crews still moving: clicked new − base | hull-error median, ALL | wheels/turret |
|---|---|---|---|
| faced_ambush | -3 | +1.2° | +6.2° |
| faced_attack_move | +11 | +1.8° | +5.9° |
| faced_move | +5 | -0.9° | -5.6° |
| faced_right | -1 | +0.4° | -4.5° |
| faced_screen | -4 | +0.4° | +8.4° |
| faced_support_by_fire | +2 | -0.4° | +4.4° |

So a +5 guard on crews-still-moving and a ±5° line on clicked medians were both inside this probe's A/A at the n M1 used; M1b's clicked pair says the same at n = 15 (wheeled-turret medians −6.2..+8.4°, moving −3..+11 a task).

**yard crossing cells (B5c):** two near-identical rules (`053beffb` judged, `a8df3dc3` the narrow fix) on the same yard-23 cells moved last-crew-in by −3.6, +0.8, +3.5, +11.1, +17.8 s (t11, t8, t6, t1, t3) and Sumps 6 by −0.3 s: a cell's own swing is about ±9 s, so a 'median ≤ off − 5 s' line over 12 cells (se ≈ 3 s) is at the edge; the count line (every crew in, 12/12 v 5/12) is what decided B5c.
<!-- judge:aa:end -->

## The lines (S3): a variance-aware form for every kind of line this project writes

Every rule below has the same shape: **the line is written in units of the probe's own noise, the noise is read from the
judged pair's rows (never assumed), and the bar states what the line can and cannot see.** `k` is the multiple of the se
a guard sits at: **k = 1.645** is a 5 % one-sided false-fail rate on a treatment that changes nothing (the default);
k = 2 is 2.3 % (the "within 2 se" the project already writes). The se is always the PAIRED se over the (seed, tick)
grid, of the statistic the line compares. `tools/judge/size.py` prints every number in this section.

| form the bar writes | today's wording | the variance-aware form | what to quote beside the verdict |
|---|---|---|---|
| **guard** ("not worse than base by more than X") | `<= base + 5`, `<= +20 %`, `>= base − 2` | `<= base + k·se` with se the paired se of the SUM (totals) or of the mean; k stated. If the product names X ("+5 crews is what he would notice"), X must be a SHARE or a per-run amount, and n is sized so that MDE ≤ X: a fixed total gets harder to see as n grows (X/n a run). | se, k, and the MDE (= 2.49 se at 80 % power): the harm the guard can catch |
| **gain line** ("down ≥ X %") | `−25 %` as a point threshold | two conditions: the point ≥ X % **and** the drop − k·se > 0 (distinguishable from nothing). n from `n_paired(sd, X %·base)`; the bar says the power at X % and the false-pass at null (`size.py` prints both for the point form). | the drop, its se, n, and "a null passes this %" |
| **count of runs, two arms** ("k/n v j/n") | `on side 14/18 v 0/18` | Fisher exact, one-sided in the arm's direction, p ≤ 0.05 (the comparison is what decides; 18/18 v 0/18 is decided at n = 3 a side, 14/18 v 0/18 at 6, 12/12 v 5/12 at 9; 12/12 v 10/12 is a coin, p 0.24, needs 39) | both counts, the one-sided p |
| **count threshold, one arm** ("≥ K/n") | `≥ 12/18` | keep only where the minimum RATE is itself the product promise; then say which two true rates it separates (≥ 12/18 passes p = 0.5 twelve times in a hundred and p = 0.8 ninety-five: it separates 0.5 from 0.8, not 0.6 from 0.75). A missed threshold with a decided comparison (B1 r28: 10/18 v 0/18, p 0.0002) is a sizing miss, not a product miss. | the count, the binomial sd of the count (2.1 at 10/18) and the line's distance in sd |
| **paired cells** (arrive series, bridge cells) | `≥ control − 1`, `lost ≤ 1` | McNemar exact over the discordant cells (a rule that never acts leaves every cell identical, so only the discordants carry information): 11 v 0 p 0.001 decided; 5 v 1 p 0.22 a coin; 0 v 1 p 1.0. "lost ≤ 1" is a direction check on the against-cells and should say so. | b, c, p |
| **median line** ("median ≤ base + X %") | `all-in median <= +20 %` | `<= base + k·sd_boot` with sd_boot the bootstrap sd of the paired median difference (resample run PAIRS, `stats.bootstrap_median_diff`); report the 90 % interval; MDE = 2.49 sd_boot. On traffic's cases at n = 18 sd_boot is 5.8 s (Terminus head-on), 6–7 s (Terminus crossing), 10 s (yard crossing: the median sits near the 90 s cap), 2.3 s (yard head-on). | base and arm medians, the difference, sd_boot, the interval |
| **"within 2 se"** | `fast within 2 se` | define it: one-sided (a fall always passes), se = paired se of the sum (or sd_boot for a median) from the judged pair's own rows; where the rule never touches the case the pair is byte-identical and the line is an equality check (print "2 se 0.0: identical arms") | the se and whether the arms differed at all |
| **episode counts without rows** (creep episodes) | `−50 %` | Poisson sd √(a + b) is a FLOOR on the noise (episodes within a run are not independent): 125 → 75 against a −50 % line is 0.9 sd from the line. Keep per-run rows next time (ask the runner) so the paired form applies. | a, b, √(a+b), and that it is a floor |
| **deterministic cells** (bridge 18, his 108) | `18/18` | not a sample: a new failing cell is a regression in a named cell, lesson 302 (read the trace), never "17/18 is within noise" | the cell's name |
| **censored lines** | `settle median <= +6 s` with 17–25 of 27 runs at the 75 s window | measures nothing: both arms read 75.0. Widen the window, or judge the count of runs that never settle (a count line) | say it is censored |

**The partial-gain rule still comes first** (lesson 292): the forms above change how a line is READ, not when it is
written; every line, its k and its se source are pre-registered before numbers, and a bar written before CP-N may be
re-sized once, in writing, before its judged run (C30.3).

### Worked example 1: M1's 75 s guard (round 29, `d7385da2`, hull-rest probe, seeds 22–33)

`python3 tools/judge/size.py --class-table _agents/streams/references/round29/manoeuvre/m1_judged.txt --task faced_attack_move --guard 5`

The bar: crews still moving at 75 s, all classes, ≤ base + 5 on every task; attack-move read +8 and support by fire +8,
so M1 failed and was parked. The M1_CLASS lines carry the noise: on attack-move the four classes' paired se are 0.0,
2.8, 4.4 and 8.9, so the all-class se of the sum is √(2.8² + 4.4² + 8.9²) = **10.3**. A +5 line against a 10.3 se is
inside the noise: a treatment that changes nothing fails it **31 %** of the time (28 % on support by fire, se 8.8).
The variance-aware guard is ≤ base + 1.645 × 10.3 = **+17.0** (k = 2: +20.6); the observed +8 **passes**, as does
support by fire's +8 against +14.5. Wheeled turrets alone, the class M1 commands: +12 against 1.645 × 8.9 = 14.6,
passes. What a +5 guard would need: +5 over 27 runs is 0.185 a run against a per-run sd of 1.71, so n ≈ **530 runs with
the class** a task (today 27); the MDE at 27 runs is +22 crews a task (+24 % of the 90 moving in the base). The clicked
pair, where M1 never acts, moved the same count by −16..+5 a task (the A/A), which says the same thing.
**The verdict M1 would have had under this form:** the guard passes on all six tasks. Its other miss, "clicked medians
within ±5° of base", was also inside the A/A (wheeled-turret clicked medians moved −17.8..+6.3° between two arms that
differ only in divergence; 1 of 24 class rows has p < 0.05, which is the expected chance count), so M1's point tasks
would have shipped on the round-29 numbers. This is a retrospective reading of a pre-registered bar, so it does not
ship M1; it sizes M1b's bar: *guard: all-class moving-at-judge ≤ base + 2 se (M1_CLASS's se, ≈ +20 a task at n = 27),
wheeled-turret ≤ base + 2 se; clicked: the per-class permutation p ≥ 0.05 in ≥ 23 of 24 rows.*

### Worked example 2: T3's all-in line (round 29, `d9b3339c`, traffic-series, seeds 22–24)

`python3 tools/judge/size.py --base …/t3_judged_base_d9b3339c_seeds222324.jsonl --arm …/t3_judged_arm_d9b3339c_seeds222324.jsonl --case terminus/cross --metric allin --stat median --guard-share 0.2`

The bar: Terminus crossing all-in median ≤ base + 20 %; it read 39.4 → 48.3 s (+23 %) and failed. The paired bootstrap
sd of the median difference over the 18 run pairs is **6.0 s**, so the +20 % line (7.9 s) is inside the noise (a null
fails it 9 % of the time); the variance-aware guard is +1.645 × 6.0 = **+9.9 s**, and the observed +8.95 **passes** it,
with a 90 % interval on the difference of −2.4..+14.5 s (it includes 0: the slowdown is not distinguishable from nothing
at n = 18; MDE +14.9 s = +38 %). The yard crews line (171 → 167 against ≥ 169): paired sd 0.73 a run, se of the sum 3.1,
so "−2" is inside the noise (a null fails it 26 % of the time); the variance-aware guard is ≥ base − 5.1 and the −4
**passes**. The gain line held with room: between-squad fast pooled over the crossings 206 → 95, se 14.5, the drop minus
1.645 se is still −87 (not inside the noise; a −25 % effect at n = 36 is decided with 80 % power at n = 18).
**The verdict T3 would have had:** the two noise-fails flip to passes, but the third fail stands: the wedge at yard
s22/t6 (two crews never in where the base had none) is a named run, not a statistic, and its trace (the yielding squad
crawling at 0.4 for 30–45 s) is round 30's T3b design. T3 fails on the trace, which is the right reason.

### Worked example 3: B5c's yard count (round 29, `053beffb`, yard crossing seeds 23–24 × 6 ticks)

`python3 tools/judge/size.py --count 12/12 5/12`

The bar: last crew in on every run (12/12) against the off arm's "never in 7 of 12". As a comparison, 12/12 v 5/12 has
Fisher one-sided p **0.0023**: decided, and decided at **n = 9** a side (the observed rates reach 80 % power there), so
three cells of the twelve could have been spared. The median line beside it (on ≤ off − 5 s) is weaker than it looks:
the same yard cells re-run under the narrow fix moved by −3.6..+17.8 s, a cell swing of about ±9 s, so a 5 s margin on a
median of 12 (se ≈ 3 s) is at the edge; the count is the deciding line and the median the report. A 12/12 v 10/12 cell
(p 0.24) would not decide anything and would need 39 runs a side.

## Early stop (S4): deciding a paired series before the grid is run out

**The design** (`tools/judge/sequential.py`). A judged series is walked in the runner's own order (seed-major, start tick
minor: `mk/traffic.mk`'s loop), and after every run each pre-registered line is a Wald SPRT on the per-run paired
differences d_i = arm − base, with the probe's per-run sd taken from *The table* (pre-registered, not the series' own):

- a **gain line** ("down ≥ X %") tests H0 δ = 0 against H1 δ = −X %·base: PASS when the log-likelihood ratio reaches
  A = ln((1 − β)/α) = +2.77, FAIL when it falls to B = ln(β/(1 − α)) = −1.56 (α = 5 %: a null passes; β = 20 %: the named
  effect fails);
- a **guard** ("not worse by X") tests no-harm against harm = +X %·base (a fall for arrived-type metrics): FAIL at A,
  PASS at B (α = 5 %: a harmless change fails; β = 20 %: the named harm passes);
- a **rate line** (on side) is the Bernoulli SPRT of p₁ (the bar's rate) against p₀ (the control's, floored at 0.05);
- **truncation** at the grid's end decides by the fixed one-sided test at α (a gain passes only if the drop exceeds
  1.645 se; a guard fails only if the harm exceeds 1.645 se), never by the ratio's sign, which under a null is a coin;
- **no stop before one full seed** of ticks (`--min-runs 6`), so no verdict rests on one start tick;
- the **series** FAILS on the row the first line fails (no partial gain), PASSES on the row the last line passes; and a
  case whose arms are byte-identical AND whose rule counter (lesson 300: `tr_verdicts`, `tr_cross_verdicts`, passed as
  `--counter`) is 0 in every row of the first seed is **UNTOUCHED** and stops as PASS, an equality check (a guard there
  guards nothing).

**Its error rates, simulated on rounds 28–29's own rows** (`--simulate`: the null world sign-flips the centred paired
differences, so it has the probe's real noise shape and no effect; the effect world shifts that null by the named effect;
the observed world resamples the real differences). Per line, at n = 18, table sd:

| line (series) | a null passes / a harmless change fails | the named effect fails / the named harm passes | observed rows: decision, mean stop |
|---|---|---|---|
| Terminus head-on xfast gain −25 % (CP-T) | 6.1 % | 48 % (the series is too short for −25 %, as the table says; −81 % is what ran) | PASS 100 %, run 7.9 |
| Terminus head-on xfast gain (CP-T CPU) | 3.2 % | 48 % | PASS 100 %, run 7.2 |
| Terminus head-on arrived guard −5 % (CP-T) | 1.1 % | 27 % | PASS 100 %, run 11.4 |
| Terminus head-on all-in guard +20 % (CP-T) | 2.1 % | 8 % | PASS 96 %, run 9.6 |
| crossings pooled xfast gain −25 %, n = 36 (T3) | 4.3 % | 13 % | PASS 100 %, run 6.6 |
| Terminus crossing all-in guard +20 % (T3) | 3.5 % | 53 % | PASS 80 %, run 16.4 |
| yard crossing arrived guard −5 % (T3) | 10.1 % | 23 % | PASS 64 %, run 11.4 |
| Terminus head-on fast gain −25 % (T1 v3, r28) | 5.2 % | 45 % | PASS 100 %, run 10.7 |
| Terminus crossing fast gain −25 % (T1 v3) | 7.2 % | 43 % | PASS 1 %, run 11.3 |
| yard crossing fast gain −25 % (T1 v3) | 11.4 % | 32 % | PASS 88 %, run 11.7 |
| Terminus head-on fast gain −25 % (T1b, r28) | 10.1 % | 43 % | PASS 95 %, run 11.0 |
| Terminus head-on arrived / fstuck guards (T1b) | 14.9 % / 23 % | 38 % / 62 % | the wedged-run pair: its own sd is 1.5–1.9× the table's |
| B1 (a) on side, rate 0.67 v 0.05 | 0.3 % | 1.7 % | PASS 92 %, run 6.4 |
| M4 Terminus rigs arrived guard −10 %, n = 6 | 3.0 % | 50 % | FAIL 99 %, run 4.2 |

**Read:** the false-pass of a gain line sits at **3–11 %** (median 6 %) against the 5 % designed, and the false-fail of a
guard at 0–6 % except on T1b's pair, whose one wedged run put its real sd 1.5–1.9× above the table's and lifted the
guards' false-fail to 15–23 %: **the table's sd must be refreshed after every judged run** (`python3 tools/judge/table.py`
once the pair is under `references/`), and a stream prints the rows' own sd beside the table's (the script does). The
power column is the table's lesson again: at n = 18 a −25 % effect fails about half the time; the effects that shipped
(−81 %, −54 %) are decided inside 6–8 runs.

**What round 29 would have done with it** (the judged series whose rows are kept; runs per arm; every verdict the same):

| series | runs run | would have stopped at | why |
|---|---|---|---|
| CP-T Terminus head-on | 18 | 13 | xfast PASS at run 8; the arrived guard clears B at 10, all-in at 13 |
| CP-T CPU mirror | 18 | 12 | |
| CP-T Terminus crossing, yard crossing | 18 + 18 | 6 + 6 | UNTOUCHED (counter 0, identical arms) after one seed |
| CP-T yard head-on | 18 | 6 | the guards clear B inside the first seed |
| T3 crossings pooled xfast | 36 | 8 | the gain decided; the cases' guards below run on |
| T3 Terminus crossing, yard crossing, Terminus head-on | 18 × 3 | 18 × 3 | guards against +20 % / −5 % harms accrue evidence slowly; head-on's counter is 2, not 0 |
| T3 yard head-on | 18 | 6 | |
| M4 Terminus rigs / mixed | 6 + 6 | 4 + 6 | rigs' arrivals fail the guard at run 4 (all four lower) |
| **round 29 total** | **174** | **113 (−35 %)** | CP-T PASS, T3 FAIL (the wedge, a named run, still stands: lesson 302), M4 FAIL |
| round 28: T1 v3 (3 cases), T1b, B1 (a) and (c) | 54 + 18 + 36 | 35 + 6 + 31 | T1 v3's crossing fails at run 6 (fast UP); T1b fails at 6 (all-in guard); B1 (a) passes as a comparison |

At the brief's 1.75 box-minutes a traffic run, round 29's traffic series would have cost 125 fewer runs × 2 arms ≈
**3.6 box-hours** less, out of ~10; the biggest single saving is the untouched cases (one seed instead of three).

**What the runners should print** (a proposal to traffic / brains / manoeuvre through the orchestrator; the scripts are
theirs): after each row of `traffic-series` (and the census / Terminus / hull-rest loops), call
`python3 tools/judge/sequential.py --base <base.jsonl> --arm <arm so far.jsonl> --case <case> --lines <the bar's lines>
--counter <the rule's counter> --quiet | tail -1`, and print its `SERIES CONTINUE | PASS | FAIL at run k of n` beside the
row (`turns_verdict.py` / `hold_verdict.py` stay the final reading; this is the running one). The lines are the bar's,
written as `metric:gain:share`, `metric:guard:share` (or `abs=`), `metric:rate:p1:p0`, pre-registered with the bar.

**THE ONE RULE FOR WHEN A STREAM MAY STOP.** *A judged series may stop before its grid only on the row where
`sequential.py`, with the table's sd (not the rows' own) and the bar's pre-registered lines, prints `SERIES PASS` or
`SERIES FAIL` for every case the bar names; the stream records that row and the lines' ratios in the bar's block ("stopped
at run 13 of 18: xfast PASS llr 2.83 at run 8, …"). A `CONTINUE` on any line of any case means the series runs on. A
probe with no table row runs its full grid and owes its A/A pair first. The orchestrator's trace rules are untouched by a
stop: the worst run so far is still read before the median (302), and a wedge is a named run, not a line.*

## How to write a bar (S5): the method

1. **Name the probe and the metric, then read its noise from *The table*.** The row gives the per-run paired sd, the base
   level, icc, and the se at the usual n. No row → the probe owes an **A/A pair before its first bar**: two base runs of
   the grid (same arm, different seed sets; or the same seeds under a change that is not meant to act, like M1's clicked
   pair), read with `python3 tools/judge/aa.py A.jsonl B.jsonl`; the cost is in the table's A/A column (two base runs of a
   traffic case ≈ 63 box-min; of a yard cell ≈ 35; of a hull-rest task ≈ 4 h).
2. **Name the effect he would notice**, as a share of the base or a per-run amount, never a fixed total ("+5 crews over
   288" is 0.185 a run and needs 530 runs; "+10 % of crews moving" is a line). `python3 tools/judge/size.py --probe … --metric …
   --effect-share X` prints the n that decides it at 80 % / 5 % and the MDE at today's n. **If n_needed is beyond what the
   round can run, write the effect the n CAN see** (the MDE) into the bar, or change the line's form (a count, a comparison).
3. **Write every line in its variance-aware form** (*The lines*): guards as `base + k·se` with k and the se's source named;
   gain lines as the point AND "distinguishable from nothing"; counts as the comparison (Fisher) or McNemar; medians with the
   bootstrap sd; "within 2 se" with its se defined; and say which lines are equality checks (untouched cases), which are
   deterministic cells (bridge, the 108) and which are reports.
4. **Spend the runs where the noise is**: icc near 0 means a new start tick is as good as a new seed, so 6 ticks × seeds
   stays; icc above 0.3 (yard crossing xfast 0.54; arrivals on Terminus head-on 0.12–0.4) means add seeds before ticks.
5. **Pre-register** (C30.1, C30.3): the lines, their k and se source, the effect and its power, n and its grid, the partial
   rule, the last attempt, the rule's own counter (lesson 300) and the early-stop lines in `sequential.py`'s form, to the
   orchestrator before any number. Cite the table row, or say why the bar departs from it.
6. **Judge, stopping early only by the one rule** (*Early stop*): `sequential.py` with the table's sd prints SERIES PASS /
   FAIL for every case; record the stop row. Read the worst run's trace before the median (302) whatever the row.
7. **Report** the verdict with each line's observed value, its se, and the margin in se; a line inside its noise is said to
   be so (the inventory's column), and a gain decided inside one seed is said to be so.
8. **At the round's CLOSE, the orchestrator re-renders the table** once the judged pairs are under `references/round<N>/`:
   add the pair to `tools/judge/probes.py` (TRAFFIC_PAIRS or the probe's reader), run `python3 tools/judge/inventory.py` and
   `python3 tools/judge/table.py`, commit the doc and csv. The table's sd is the pre-registered noise for the NEXT round's
   bars, so a pair whose own sd exceeded the table's (T1b's wedged run: 1.5–1.9×) must be in before the next bar is sized.

**The two 11 % lines, and what α brings them under 5 %.** The gain lines whose simulated false-pass exceeded 10 % are
round 28's *yard crossing fast −25 %* (T1 v3; its pair's sd 9.5 a run against the table's 8.1) and *Terminus head-on fast
−25 %* (T1b; sd 37 against 28, the wedged run). At α = 2.5 % (A = +3.47) their null pass falls to 5.2 % and 6.6 %, and CP-T's
xfast from 6.1 % to 2.4 %; the price is n × 1.27 for the same power at the named effect (Terminus head-on xfast −25 %: 57
→ 72 runs; fast: 44 → 55; yard crossing fast: 25 → 32) and an early stop one or two rows later (CP-T's xfast at run 9
instead of 8, T1b's at 13 instead of 11). **Recommendation: keep α = 5 % and refresh the table (step 8) rather than pay
27 % on every series**; use α = 2.5 % only for a bar whose probe's last pair read above the table's sd.

### The cost side (stretch): round 29's judged series as run, against as sized

Runs per arm; "as sized" = the n the table or the early-stop rule gives for the effect each line named (or the effect that
ran, where that was decided sooner); the minutes are the brief's per-run costs on a loaded builder0 (traffic 1.75,
hull-rest 2.5, Terminus 4, fights 3.5, pinned 0.42, approach 1.5, cells 1.2–1.5), both arms, an estimate.

| series | runs as run | runs as sized | why |
|---|---|---|---|
| CP-T (traffic), 4 cases + CPU mirror | 90 | 43 | the −81 % decided at run 8; untouched cases one seed; the guards clear by 13 |
| T3 (traffic), 4 cases | 72 | 60 | the pooled gain decided at 8 of 36; guards against +20 % / −5 % run the grid |
| M1 hull-rest, 6 tasks × 48 | 288 | 288 | the +5 guard needs ~400 a task: not fewer runs, an honest line (+2 se) |
| M2 Terminus census, 12 | 12 | 12 | contact-ticks ±10 % not affordable at any n; arrivals −10 % would want 13 seeds |
| M4 Terminus 12 + pinned 144 + fights 24 + bridge 18 | 198 | 146 | pinned −50 % at 90 of 144; fights' 5 % kill guard 28 (24 run); rigs fail at run 4 of 6 |
| B1 + B2 ApproachStage, 3 rosters × 18 each | 108 | 36 | comparison lines decide at 3–6 a side; the alive guard as −2 se |
| B5c yard 12 + Sumps 12 + Terminus 3 + arrive 100 + bridge 18 | 145 | 113 | the yard count decides at 9; an 11 % arrive gain needs 71 cells |
| **round 29** | **913** | **698 (−24 %)** | ≈ **8 box-hours** of ~32 at the costs above; the traffic part alone −3.6 h |

The saving is modest because two of round 29's biggest series (M1's 576 runs, M4's fights) were not over-run but
UNDER-lined: their lines were inside the noise, and the fix there is the line, not the n. Where the n falls it falls hard:
a decided gain line stops in one or two seeds, an untouched case in one, a comparison count in three to six runs a side.

## Round 30 re-render (2026-10-14)

Step 8 of *How to write a bar*, done at round 30's CLOSE on main (laptop, pure python): `python3 tools/judge/table.py` and
`python3 tools/judge/inventory.py` re-wrote the three generated blocks above, `references/round30/sizing/table.csv` and
`inventory.{csv,md}`; `python3 -m unittest discover -s tools/judge -p "test_*.py"` 72 passed (was 64; the eight new ones are
known-answer tests on round 30's files). Every number below is reproduced from a file under `references/round30/`.

**Pairs added** (`tools/judge/probes.py`; a pair pools into a row only where the arms acted in ≥ a third of its runs):
- traffic-series **T3b** `cf124433` seeds 31–33 (`TRAFFIC_PAIRS`; base = no flag v `--traffic-on=turns`): pooled into the
  two crossing cases and yard head-on (the rule fired in 7 of 18 yard head-on runs); Terminus head-on untouched (2 of 18),
  not pooled. Its base rows are a fourth **hold-ON** A/A seed set. **New metric `xclear`** (the crossing clock
  `cross_clear_s`, never = run end, as `turns_verdict.py` reads it): two new rows, Terminus crossing sd 4.44 s a run
  (se 1.05 at n = 18) and yard crossing sd 0.92 (se 0.22); the judged run's own se, which the bar quoted. The row's effect
  column is 10 % of the base MEAN (13.9 / 8.4 s); the bar's line used the base MEDIAN (11.9 / 8.2 s), read by `inventory.py`.
- traffic-census **T1c-b** `16780030` seeds 7–9 (`CENSUS_PAIRS`, paired on arena + seed + roster, pooled with T1c); a new
  **friendly-stuck s** row (sd 32 a run) and an unsized count row for "runs with a repack while firing" (0/9 v 4/9 in the
  count block). The ApproachStage pair (seeds 13–15) is in the inventory (repacks 8 → 2 on the drawn rows) and the flank
  probe's A/A column (14 of 18 drawn rows byte-identical).
- Terminus census (`TERMINUS_PAIRS`, 13 seeds each): **M4b run 2** `77a1603f` 62–74 (mixed only: the rigs replicate their
  base run by construction, 0 of 13 differ), **M1b** `55622870` 36–48, **M2b** `1f1c9835` 49–61, **kturnarc** `e7a58262`
  75–87, pooled with round 29's M4; `rows.terminus_rows` reads both table formats. *n today* for the four Terminus rows is
  now **13** (was 6).
- hull-rest (`HULL_REST_TABLES`): **M1b**'s M1_CLASS lines (3 classes, wheeled turret n = 15) pooled with M1's; *n today*
  is now **15** runs with the class (was 27), round 30's grid. M1b's clicked pair is a second A/A table in the A/A block.
- fights and pinned (`GUARD_TABLES`): M4b run 2's printed FIGHT_GUARD / PINNED se pooled with M4's (`rows.guard_lines`).
- brains **B5c-v4** `19eca15a`: the gate-series rows (`rows.cell_pairs`) give a sized **Sumps cell** row (all-within-8 m,
  never = 90 s: median 37.5 → 24.5, paired sd 12.9 a run, bootstrap sd of the median difference 6.6 s at n = 12); the yard
  cell stays a count row (12/12 v 1/12 added to the count block; the off arm's last-crew-in is censored, never in 11 of 12);
  guns_on_arc is an equality check (0.941 = 0.941 run for run). The arrive series (`rows.arrive_pairs`) gives a sized
  median row over the 91 cells complete in both arms (29.6 → 24.5 s, se of the mean 1.6) and the 8 v 0 McNemar in the
  count block. **B3b** `4bc708d7`: his bridge 108 read by `bridge_verdict`'s rule (`rows.bridge_cells`): on 107/108 v
  control 106/108, 2 cells gained, 1 lost (McNemar p 1.0; the lost cell is a regression by name) in the count block.
- the inventory (`tools/judge/lines.py`): **86 round-30 lines** (72 judged, 14 reported) for T3b, T1c-b, M4b runs 1 and 2,
  M1b, M2b, kturnarc, B5c-v4, B3b, each noise read from the rows named above (new kinds `jsonl` with a filter, `terminus`,
  `guard_line`, `cells`, `arrive`, `bridge108`; a line may now be `x_share` of the base median plus `x_se` se, T3b's form).

**Rows whose sd a run moved by more than 20 %** (the T1b caveat: a pair whose own sd exceeded the table's is now in):

| row | sd before → after | why |
|---|---|---|
| traffic-census, artillery shots | 4.37 → 34.05 (**+679 %**) | T1c-b's one Parade run (171 → 26); its own pair sd 48. Row 82's 21.6 line was under-sized by ~7×, as the stream said; a bar on artillery now sees MDE +113 % at n = 9 (n = 290 for −20 %): change the line's form (per-battery rounds, or a median per run) before re-judging |
| traffic-census, fast friendly contacts | 5.50 → 6.84 (+24 %) | the second pair |
| manoeuvre-fights, kills / deaths / hit rate | 4.39 → 5.76 / 4.53 → 5.87 / 0.059 → 0.075 (+27..31 %) | M4b run 2's se 33.6 / 34.1 / 0.018 against M4's 21.5 / 22.2 / 0.012; the 5 % kill guard now needs n = 49 fights (was 28) |
| Terminus census, mixed arrived / wall contact-ticks | 1.47 → 1.04 (−29 %) / 754 → 254 (**−66 %**) | four more pairs at 13 seeds; M4's six seeds were the noisy end. Mixed arrivals now decide −10 % inside a handful of seeds; mixed contact-ticks still cannot carry ±10 % (MDE +121 %) |
| traffic-series yard head-on, fast / same-squad fast / arrived | 1.20 → 1.52 / 1.26 → 1.57 / 0.236 → 0.283 (+20..27 %) | T3b's rule touched the case a little (7 of 18 runs): a second pair where T3 alone had been pooled |

Everything else moved by less than 20 % (Terminus rigs arrived −13 %, rigs contact-ticks −19 %, hull-rest wheeled turret
+11 %: 1.46 → 1.63, the +5 guard's n 385 → 478; the traffic crossing cases ±5 %).

**Owed → sized.** No existing "owed" row became sized (the hull-rest share and settle rows, the flank probe's A/A, the scout
and contact censuses are as they were). Five new sized rows that had no row before: the two crossing clocks, census
friendly-stuck, the Sumps cell's all-within-8 m median, the arrive series' median. Still unsized by their nature: the yard
count (censored off arm), Sumps guns_on_arc (identical arms), the bridge cells (deterministic).

**The count: 56 of 194 judged pass lines of rounds 27–30 inside the noise** (rounds 27–29 unchanged at 42 of 122; round 30:
14 of 72). Round 30's fourteen: the four "not down beyond **1 se**" arrival lines (M4b run 1, M1b; a 1 se line is inside a
5 % noise by construction, a null fails it one time in six — M2b and kturnarc moved to 1.645 se and are outside); four T3b
guards whose table-sized x sat just under the judged pair's own 1.645 se (Terminus crossing crews 4.07 v 4.15; yard head-on
crews, fast, all-in); T1c-b's three (the "total = 0" count, fast friendly ≤ +27.1 v own se 23.9, and the artillery line
that FAILED inside a se of 144); two pure direction checks (x = 0: the ApproachStage repacks, the Sumps median) and the
arrive median's +2 % (0.59 s v se 1.0). 19 of round 30's verdicts cleared their line by less than 1.645 se (57 of 194
overall; `inventory.md` lists them).

**Not ingested, and why.** M4b run 1 (`m4b_run1_judged.txt`): its Terminus table carries squad totals and discordant seeds,
not per-seed arrivals, so its five lines are in the inventory with the printed se (3.72 / 3.49) and it is not pooled. B6's
sbf probe: not run this round (no rows). T4: tuning logs only (`t4_tuning/*.log.gz`), no judged pair. B5c-v4's Terminus
cells (n = 1 a seed) and yard last-crew median (censored): reported lines, no noise estimate. The M4b pair-check and seed-31
trace logs are traces, not rows. **Provenance note:** the seven manoeuvre tables under `references/round30/manoeuvre/` were
copied at the close from the `stream/manoeuvre` worktree (`godot-manoeuvre`), where the stream filed them; main had no
`manoeuvre/` folder before this re-render.

## Rows filed by hand in round 31 (folded into the table at the close's re-render)

| probe | metric | form | noise | base | n | the bar's line | filed |
|---|---|---|---|---|---|---|---|
| `test_tactics_pursuit` stage (`make pursuit-aa`, brains `3cb76e17`, game/ = main, builder0, default path; rows `streams/references/round31/brains/pursuit-aa-3cb76e17.{jsonl,txt}`) | pass verdict a cell (12 seeds × 8 / 18 m/s) | count | **a 0.25 m start nudge (a null change; the lab is deterministic a seed, so an exact A/A is an equality check) flips 3 of 12 verdicts at 8 m/s (seeds 3, 5, 9; seed 3 is the test's own), 0 of 12 at 18 m/s.** Reversal margin as written +69–70° every seed, nudged min −41°; closing margin ≥ +13.9 m both arms | rule OFF: as written 22/24 (8 m/s 12/12; 18 m/s 10/12, seeds 1 and 9 FAIL on main); nudged 19/24 | 48 runs | a per-seed line fails a null ~97 % of the time (1 − 0.75¹²). B5c-v5: count form ON ≥ OFF − 3 on the 24 cells (R31.3) | 2026-10-14 ~23:15 PDT, orchestrator, from brains' A/A |
