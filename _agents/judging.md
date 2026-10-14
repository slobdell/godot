# Judging: how a bar is sized by its probe's noise (round 30, sizing)

> **Why this file exists.** builder0 is the bottleneck (loaded checks 53–60 min v 41 quiet; judged series queue for hours),
> and until round 30 every series was sized by feel (n = 18 a case, three seeds × six ticks) and every guard was a round
> number (+5 crews; ≤ +20 %). Rounds 27–29's judged lines, read against their own rows
> ([`references/round30/sizing/inventory.md`](streams/references/round30/sizing/inventory.md)), show **42 of 122 judged pass
> lines inside their probe's noise**: a treatment that changed nothing would have failed that guard (or passed that gain line)
> more than one time in twenty at the n used. M1's +5 guard was one of them; so was every "crews ≥ base − 2" line.
> This file is the method that replaces feel: **the probe's noise → the smallest n that decides the effect the bar names
> → lines set from the noise → pre-register → judge, stopping early when the series is decided.**
> Every number here is reproducible by a `tools/judge/` command on a file under `streams/references/`; generated blocks
> carry their marker and are rewritten by `python3 tools/judge/table.py`. Contract C30.3: a bar pre-registered after CP-N
> cites its row here (or says why it departs).

## The table (CP-N): one row per probe × metric

**How to read a row.** *sd a run* is the probe's noise: the sd of the per-run paired difference (arm − base on the same
seed and start tick), pooled over every judged pair of rounds 28–29 in which the treatment acted in at least half the runs
(a pair where the rule never fired is byte-identical and is an equality check, not a sample). *base a run* is the base
arm's level per run, so an effect named in % becomes an effect per run. *icc* is the share of that noise sitting between
seeds: near 0, a new start tick buys as much as a new seed; above 0.3, add seeds first. *se at n today* is the se of the
statistic the line compares (the sum over the runs for a total, the bootstrap sd of the median difference for a median) at
the n the round-29 bar used: **this is the number a bar quotes**. *n that decides it* is the paired n at which the effect
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
| traffic-series terminus/cross | xfast | total | 2.74 | 5.37 | 0.101 | 18 | 11.6 | between-squad fast contacts down >= 25 % | 1.34 (25 %) | **26** | 1.61 (30 %) | base ± 19.1 | 63 → 91 |
| traffic-series terminus/cross | fast | total | 6.12 | 13.02 | 0.0722 | 18 | 26.0 | fast friendly contacts down >= 25 % (round 28's line) | 3.25 (25 %) | **22** | 3.59 (28 %) | base ± 42.7 | 63 → 77 |
| traffic-series terminus/cross | ownfast | total | 6.27 | 7.65 | 0.0773 | 18 | 26.6 | same-squad fast <= base x 1.2 + 10 | 1.53 (20 %) | **104** | 3.67 (48 %) | base ± 43.7 | 63 → 364 |
| traffic-series terminus/cross | arrived | total | 0.584 | 9.78 | 0.0886 | 18 | 2.48 | crews in >= base - 2 (over 18 runs) | 0.111 (1 %) | **171** | 0.342 (3 %) | base ± 4.07 | 63 → 598 |
| traffic-series terminus/cross | allin | median | 25.39 | 40.30 | 0.00677 | 18 | 7.01 | all-in median <= base + 20 % | 8.06 (20 %) | **85** | 17.43 (43 %) | base ± 11.5 | 63 → 298 |
| traffic-series terminus/cross | fstuck | total | 9.00 | 7.27 | 0.0793 | 18 | 38.2 | friendly-stuck <= base x 1.2 + 10 | 1.45 (20 %) | **238** | 5.28 (73 %) | base ± 62.8 | 63 → 833 |
| traffic-series yard_open/cross | xfast | total | 1.81 | 6.30 | 0.537 | 18 | 7.68 | between-squad fast contacts down >= 25 % | 1.57 (25 %) | **9** | 1.06 (17 %) | base ± 12.6 | 63 → 31.5 |
| traffic-series yard_open/cross | fast | total | 8.09 | 16.30 | 0.331 | 18 | 34.3 | fast friendly contacts down >= 25 % (round 28's line) | 4.07 (25 %) | **25** | 4.74 (29 %) | base ± 56.5 | 63 → 87.5 |
| traffic-series yard_open/cross | ownfast | total | 7.54 | 10.00 | 0.216 | 18 | 32.0 | same-squad fast <= base x 1.2 + 10 | 2.00 (20 %) | **88** | 4.42 (44 %) | base ± 52.6 | 63 → 308 |
| traffic-series yard_open/cross | arrived | total | 0.684 | 9.35 | 0.0968 | 18 | 2.9 | crews in >= base - 2 (over 18 runs) | 0.111 (1 %) | **235** | 0.401 (4 %) | base ± 4.77 | 63 → 822 |
| traffic-series yard_open/cross | allin | median | 25.12 | 78.25 | 0.0255 | 18 | 10.2 | all-in median <= base + 20 % | 15.65 (20 %) | **48** | 25.35 (32 %) | base ± 16.8 | 63 → 168 |
| traffic-series yard_open/cross | fstuck | total | 11.63 | 9.99 | 0.226 | 18 | 49.3 | friendly-stuck <= base x 1.2 + 10 | 2.00 (20 %) | **210** | 6.81 (68 %) | base ± 81.1 | 63 → 735 |
| traffic-series yard_open/head | xfast | total | 0.832 | 3.33 | 0.008 | 18 | 3.53 | between-squad fast contacts down >= 25 % | 0.833 (25 %) | **8** | 0.488 (15 %) | base ± 5.81 | 63 → 28 |
| traffic-series yard_open/head | fast | total | 1.20 | 7.33 | 0.00 | 18 | 5.09 | fast friendly contacts down >= 25 % (round 28's line) | 1.83 (25 %) | **8** | 0.704 (10 %) | base ± 8.38 | 63 → 28 |
| traffic-series yard_open/head | ownfast | total | 1.26 | 4.00 | 0.0552 | 18 | 5.34 | same-squad fast <= base x 1.2 + 10 | 0.8 (20 %) | **16** | 0.738 (18 %) | base ± 8.79 | 63 → 56 |
| traffic-series yard_open/head | arrived | total | 0.236 | 10.00 | 0.00 | 18 | 1 | crews in >= base - 2 (over 18 runs) | 0.111 (1 %) | **28** | 0.138 (1 %) | base ± 1.64 | 63 → 98 |
| traffic-series yard_open/head | allin | median | 7.04 | 34.10 | 0.0658 | 18 | 2.32 | all-in median <= base + 20 % | 6.82 (20 %) | **13** | 5.77 (17 %) | base ± 3.82 | 63 → 45.5 |
| traffic-series yard_open/head | fstuck | total | 2.90 | 1.02 | 0.149 | 18 | 12.3 | friendly-stuck <= base x 1.2 + 10 | 0.204 (20 %) | **> 1000 (not affordable)** | 1.70 (166 %) | base ± 20.3 | 63 → 4364 |
| traffic-series crossings pooled | xfast | total | 2.29 | 5.83 | 0.00 | 36 | 13.8 | between-squad fast pooled over the two crossing cases down >= 25 % (T3) | 1.46 (25 %) | **16** | 0.95 (16 %) | base ± 22.6 | 126 → 56 |
| hull-rest probe (a task) | crews still moving at 75 s, wheeled turret | total | 1.46 | 1.75 | 0.00 | 27 | 7.59 | guard: <= base + 5 crews a task (M1) | 0.185 (11 %) | **385** | 0.699 (40 %) | base ± 12.5 | 135 → 1925 |
| hull-rest probe (a task) | crews still moving at 75 s, all classes | total | 1.74 | 2.38 | 0.00 | 27 | 9.03 | guard: <= base + 5 crews a task, all classes (M1) | 0.185 (8 %) | **545** | 0.831 (35 %) | base ± 14.9 | 135 → 2725 |
| hull-rest probe (a task) | hull error median, wheeled turret (310 crews) | median | – | – | – | 27 | – | clicked within +-5 deg of base; point tasks median <= 15 deg | – | see *Count lines* / A/A | – | – | – |
| hull-rest probe (a task) | share within 15 deg, wheeled turret | share | – | – | – | 27 | – | >= 70 % within 15 deg | – | owed (A/A column) | – | – | – |
| hull-rest probe (a task) | settle time (75 s window) | median | – | – | – | 27 | – | settle paired median <= +6 s | – | see *Count lines* / A/A | – | – | – |
| pinned probe (hull-rest seeds, 144 runs) | pinned crew-seconds | total | 38.30 | 20.15 | 0.00 | 144 | 459.6 | down by > 2 se (M4 b2); sized here for a -50 % effect | 10.08 (50 %) | **90** | 7.94 (39 %) | base ± 756.0 | 121 → 75.6 |
| pinned probe | pinned crews (count) | total | 0.908 | 0.479 | 0.00 | 144 | 10.9 | down (M4 b2) | 0.24 (50 %) | **89** | 0.188 (39 %) | base ± 17.9 | 121 → 74.8 |
| manoeuvre-fights (180 s) | kills | total | 4.39 | 41.71 | 0.00 | 24 | 21.5 | guard: within 2 se (M4); sized for a 5 % loss | 2.09 (5 %) | **28** | 2.23 (5 %) | base ± 35.4 | 168 → 196 |
| manoeuvre-fights (180 s) | deaths | total | 4.53 | 42.08 | 0.00 | 24 | 22.2 | guard: within 2 se | 2.10 (5 %) | **29** | 2.30 (5 %) | base ± 36.5 | 168 → 203 |
| manoeuvre-fights (180 s) | hit rate | mean | 0.0588 | 0.717 | 0.00 | 24 | 0.012 | guard: within 2 se; sized for -2 pts | 0.02 (3 %) | **54** | 0.0298 (4 %) | base ± 0.0197 | 168 → 378 |
| manoeuvre-fights (180 s) | hits | total | 362.03 | 822.88 | 0.00 | 24 | 1773.6 | reported (outside 2 se at M4) | 41.14 (5 %) | **479** | 183.75 (22 %) | base ± 2917.3 | 168 → 3353 |
| Terminus census, rigs (a seed) | arrived (of 16) | total | 1.94 | 13.50 | 0.00 | 6 | 4.75 | arrivals >= base (M2, M4); sized for -10 % | 1.35 (10 %) | **13** | 1.97 (15 %) | base ± 7.82 | 48 → 104 |
| Terminus census, rigs (a seed) | wall contact-ticks | total | 1110.61 | 889.50 | 0.00 | 6 | 2720.4 | <= base + 10 % (M2); down (M4) | 88.95 (10 %) | **964** | 1127.38 (127 %) | base ± 4474.7 | 48 → 7712 |
| Terminus census, mixed (a seed) | arrived (of 24) | total | 1.47 | 22.83 | 0.00 | 6 | 3.61 | arrivals >= base | 2.28 (10 %) | **8** | 1.49 (7 %) | base ± 5.93 | 48 → 64 |
| Terminus census, mixed (a seed) | wall contact-ticks | total | 753.75 | 120.00 | 0.00 | 6 | 1846.3 | <= base + 10 % | 12.00 (10 %) | **> 1000 (not affordable)** | 765.13 (638 %) | base ± 3036.9 | 48 → 195144 |
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
| traffic-census (3 arenas x seeds) | artillery shots | total | 4.37 | 14.44 | 0.00 | 9 | 13.1 | not down > 2 se (T1c) | 2.89 (20 %) | **15** | 3.62 (25 %) | base ± 21.6 | 90 → 150 |
| traffic-census (3 arenas x seeds) | fast friendly contacts | total | 5.49 | 51.56 | 0.00 | 9 | 16.5 | <= base x 1.1 + 5 (T1c) | 5.16 (10 %) | **8** | 4.55 (9 %) | base ± 27.1 | 90 → 80 |
| yard / Sumps / Terminus cells (a cell) | runs with every crew in | count-runs | – | – | – | 12 | – | last crew in every run; median <= off - 5 s (B5c) | – | see *Count lines* / A/A | – | – | – |
| arrive series (100 cells) | cells within 8 m | count-cells | – | – | – | 100 | – | >= control - 1; 100/100 v 89/100 (B5c), 95 v 88 (B2 v5), 97 v 93 (B3) | – | see *Count lines* / A/A | – | – | – |
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
3. **The hull-rest guard +5 a task needs ~400 runs with the class; n = 27 reads +12 (wheeled turret) or +15 (all classes).**
   The clicked pair, an A/A, moved the same count by −12..+10. Say "≤ base + 2 se" and quote the se (M1_CLASS prints it).
4. **Terminus wall contact-ticks cannot carry a ±10 % line at any affordable n** (sd ≈ 1100 a run on a base of 890; MDE at
   n = 6 is +127 %). Arrivals can (sd 1.9 of 16: MDE −15 % at n = 6; −10 % needs 13 seeds). Judge pins with the pinned
   probe's crew-seconds (144 cheap runs, MDE −39 %), and report contact-ticks as a median per run or not at all.

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
| 9/18 v 0/18 (S3 / S4 contact runs (read as 0 v 9)) | 0.0005 | 10 |
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
| 8 v 1 (B2 v5 95 v 88) | 0.0391 | decided |
| 5 v 1 (B3 make-room 97 v 93) | 0.2188 | not decided: a coin |
| 7 v 4 (B2 v3 89 v 86) | 0.5488 | not decided: a coin |
| 4 v 2 (B2 v4 85 v 83) | 0.6875 | not decided: a coin |
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

| case | metric | hold ON (3 seed sets) | swing | hold OFF (4 seed sets) | swing |
|---|---|---|---|---|---|
| terminus/head | fast | 379, 322, 341 | ±8 % | 716, 881, 871, 872 | ±10 % |
| terminus/head | xfast | 91, 54, 71 | ±26 % | 398, 475, 474, 493 | ±10 % |
| terminus/head | arrived | 177, 177, 171 | ±2 % | 170, 176, 170, 173 | ±2 % |
| terminus/head | allin | 59.3, 54.7, 61.2 | ±6 % | 64.3, 60.8, 56.9, 56.5 | ±7 % |
| terminus/head | fstuck | 319, 326, 393 | ±11 % | 489, 664, 700, 629 | ±17 % |
| terminus/cross | fast | 236, 226, 294 | ±13 % | 294, 236, 183, 246 | ±23 % |
| terminus/cross | xfast | 112, 92, 116 | ±11 % | 116, 112, 82, 106 | ±16 % |
| terminus/cross | arrived | 173, 176, 176 | ±1 % | 176, 173, 176, 177 | ±1 % |
| terminus/cross | allin | 45.9, 39.4, 45.8 | ±7 % | 45.8, 45.9, 35.6, 50.2 | ±16 % |
| terminus/cross | fstuck | 204, 136, 157 | ±20 % | 157, 204, 99.6, 184 | ±32 % |
| yard_open/cross | fast | 247, 294, 277 | ±9 % | 277, 247, 309, 232 | ±14 % |
| yard_open/cross | xfast | 111, 114, 118 | ±3 % | 118, 111, 108, 120 | ±5 % |
| yard_open/cross | arrived | 166, 171, 169 | ±1 % | 169, 166, 165, 163 | ±2 % |
| yard_open/cross | allin | 77.2, 69.2, 75.6 | ±5 % | 75.6, 77.2, 90.0, 89.1 | ±9 % |
| yard_open/cross | fstuck | 159, 116, 196 | ±26 % | 196, 159, 228, 133 | ±26 % |
| yard_open/head | fast | 115, 132, 113 | ±8 % | 113, 115, 122, 97 | ±11 % |
| yard_open/head | xfast | 55, 60, 60 | ±4 % | 60, 55, 63, 53 | ±9 % |
| yard_open/head | arrived | 176, 180, 179 | ±1 % | 179, 176, 179, 180 | ±1 % |
| yard_open/head | allin | 30.9, 34.1, 37.2 | ±9 % | 37.2, 30.9, 39.4, 30.1 | ±14 % |
| yard_open/head | fstuck | 13.5, 18.4, 8.9 | ±35 % | 8.9, 13.5, 6.1, 12.7 | ±36 % |

The hold-OFF sets span three rounds of other merges, so part of that swing is code, not seeds; the hold-ON sets are two commits a day apart. Read the swing as the A/A ceiling a bar's guard must sit above when it compares totals across seed sets; within one seed set, a case the rule never touches swings 0 (the sim is deterministic per flags).

**hull-rest probe, the clicked pair at `d7385da2` (M1 never acts on a clicked order, so new_clicked v base_clicked is an A/A at n = 48 runs a task, 27 with wheeled turrets):**

| task | crews still moving: clicked new − base | hull-error median, ALL (651 crews) | wheels/turret (310 crews) |
|---|---|---|---|
| faced_ambush | -3 | -1.5° | -6.2° |
| faced_attack_move | +4 | -5.8° | -8.3° |
| faced_move | +0 | -0.4° | +2.9° |
| faced_right | -6 | -0.2° | +0.6° |
| faced_screen | +5 | -0.4° | +6.3° |
| faced_support_by_fire | -16 | -1.5° | -17.8° |

So a +5 guard on crews-still-moving and a ±5° line on clicked medians were both inside this probe's A/A at the n M1 used.

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
