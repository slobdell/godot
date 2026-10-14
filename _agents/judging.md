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

_(written in S3; the rules per form, with M1's guard, T3's all-in line and B5c's yard count re-sized as worked examples)_

## Early stop (S4): deciding a paired series before the grid is run out

_(written in S4; the boundary, its simulated error rates on rounds 27–29's rows, and the one rule for when a stream may stop)_

## How to write a bar (S5)

_(written in S5)_
