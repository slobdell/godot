# Bar B1 (round 44, manoeuvre): his War Rig backs out of the box first — FAILED as filed

Frozen tree stream/manoeuvre **9111520bf** (= main 0691e6aad + native's pair/native-backout-r3 30e37f336 + this stream; its check:
builder2, `make check exited 0`, 3446 / 0, perf NOT JUDGED there). Arms `base` v `bo` = `--traffic-on=backout`, native ON, the C++
drive in both arms. Seeds 11101-11148 as filed. Driver `~/overnight-manoeuvre/r44/bars_b1.sh` (+ `bars_b1_builder2.sh` for the two
builder2 legs, rerun verbatim after a cold-import hang and a Spot preemption; no rows had reached this side). Machines per leg in
`meta.txt`: his start builder2; the corpus builder0 light; group + workload builder2 light (the rerun); fights + G1 probe builder0 light.

| Line | Read | Verdict |
|---|---|---|
| D1 his start (Locks 56416, Green_Guns_2) | reverse t4 (base t44), past the box t93 (base t140); lines < 15 / < 110, base must not do both | PASS |
| D2 corpus, base-stuck poses (floor 8) | 21 poses; ON sooner in 15 = 71 % (line >= 80 %); median -1.73 s (line <= -1 s) | **FAIL** |
| D2 corpus, cost ceiling on the rest | 27 poses; worst +1.9 s (<= +3), median -0.57 s (<= +1) | PASS |
| Workload: yield+blocked / k-turn s per arena | crossing -3.3 / -1.3 se, locks -1.4 / +1.3 se, terminus -5.4 / -4.8 se (each <= +2 se) | PASS |
| Workload: seated by 15 s (>= -2 se), never-arrived, wedged s | -0.3 se; never-arrived -0.83 a run (se 0.18); wedged -2.58 s a run (se 1.01) | PASS |
| b1_judge: other crews' reversing ticks / seated (per arena) | -1.3/-1.4, -1.6/+0.0, -0.6/+2.2 se; nose-on crews clear 8 m -3.7 se | PASS |
| Group guards G5 / G6 / G7 (11125-11136) | identical arms (0 se) | PASS |
| G1 v9 corridor: ORDERS_PROBE_SQUAD rows byte-identical | 180 / 180 (36 runs x 5 squads); g1v8 lines identical, friend contacts 1659 = 1659 | PASS |
| Fights G1-G4 (11137-11142) | deaths in give-ways 54 -> 50, stuck deaths 151 -> 159, contacts +1 %, kill share moved 0.003 | PASS |
| Perf | the frozen tree's perf-judge NOT JUDGED on builder2 (not a judging machine); moot: the bar fails on D2 | — |

**Verdict: FAIL as filed (D2's 80 % share: 15 of 21). No re-file (C44.1); backout stays OFF.** The six base-stuck poses ON did not
clear sooner: pose 13 three times (crossing, alone, +55 deg, nose 0.0 m: `looks 0`, the look never fired, identical arms) and the
crossing crawl poses 10 / 6 three times (+1.7, +2.0, +5.3 s: the back-up then a second k-turn). Reads, not guards: the fights'
moving-stuck seconds +3.27 s a fight (1.1 se); on his start the 20 s arrival rows differ between arms, but on a live replay his later
clicks move the goals after the first seconds, so they are not comparable (the orders differ by t241).
