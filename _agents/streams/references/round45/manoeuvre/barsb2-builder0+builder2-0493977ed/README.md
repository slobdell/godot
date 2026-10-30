# Bar B2 (round 45, manoeuvre): his War Rig backs out of the box first, on every pose — FAILED as filed

Frozen tree `wip/manoeuvre-b2-freeze` **0493977ed** (= stream/manoeuvre ce52cba1c (code dab58b334) + native's twin `pair/native-backout-b2v2`
04ce3abe9); its check: builder2, `>> remote: make check exited 0`, 3448 / 0, 24 targets passed, 4 NOT JUDGED (perf lines: not a judging
machine / loaded) — `check-0493977ed.log`. Arms `base` v `bo` = `--traffic-on=backout`, native ON, the C++ drive in both arms (proven
EQUAL to the GDScript on this block: 96 / 96 rows, builder2, `~/overnight-manoeuvre/r45/b2_equal/`). Seeds 11149-11196 as filed
(workstreams.md *Bars (round 45)*, R45.4 / R45.8 amendments before any number). Drivers `~/overnight-manoeuvre/r45/bars_b2_a.sh`
(builder0 light, from `../godot-manoeuvre-b2x`: corpus, guard poses, fights, G1 probe) and `bars_b2_b.sh` (builder2: his start, his
Gorge replay, workload, group guards); `meta.txt` has each leg's clock. Evidence `~/overnight-manoeuvre/r45/bars_b2/`.

| Line | Read | Verdict |
|---|---|---|
| D1 his start (Locks 56416, Green_Guns_2; builder2) | reversing t4 (base t44), past the box t97 (base t140); lines < 15 / < 110, base must not do both | PASS |
| D2 corpus, base-stuck poses (floor 8; builder0 light) | 11 poses; ON sooner in 11 / 11 (line 80 %); median -3.03 s (line <= -1 s) | PASS |
| D2 corpus, cost ceiling on the rest | 37 poses; median -0.13 s (<= +1) PASS; worst **+6.3 s** (<= +3): seed 11187, pose 10 crossing crawl +50 | **FAIL** |
| D3 guard poses (the six round-44 stagings, 24 jittered) | 4 of 24 worse: 11155 wall ticks 14 -> 102 (clear -1.7 s), 11163 +0.3 s / +19 ticks, 11168 **+3.5 s**, 11171 +32 ticks | **FAIL** |
| Workload: yield+blocked s per arena | crossing -0.9 se, locks -0.1 se, terminus -3.4 se (each <= +2 se) | PASS |
| Workload: k-turn s per arena | crossing -0.5 se, locks +1.8 se, **terminus +2.6 se (+1.79 s a run)** | **FAIL** |
| Workload: wedged s, seated by 15 s, never-arrived | -0.35 s a run; -0.6 se (>= -2); -0.50 a run (better) | PASS |
| b1_judge: other crews' reversing ticks / seated (per arena) | -4.0/+0.2, +0.5/-1.4, -3.3/+1.9 se; nose-on crews clear 8 m 248 -> 264 ticks (+1.0 se, reported) | PASS |
| Group guards G5 / G6 / G7 (11173-11184) | identical arms (0 se) | PASS |
| G1 v9 corridor: ORDERS_PROBE_SQUAD rows byte-identical | 180 / 180; g1v8 lines identical, friend contacts 1982 = 1982 | PASS |
| Engage's line: his Gorge replay 107 s base v bo | per-crew divergence tables identical (20 / 20 within 3 m both) | PASS |
| Fights G1-G4 (11185-11190) | deaths in give-ways 41 -> 38, stuck deaths 143 -> 146, contacts -1.6 %, kill share moved 0.002 | PASS |
| Perf | NOT JUDGED on builder2 (not a judging machine); moot | — |

**Verdict: FAIL as filed on three lines (R45.11 / R45.14): backout stays OFF.** The 11187 ceiling miss is a departure look that planned
nothing where today's planner had a plan (fixed on stream/manoeuvre 0a80c3685, OFF code: the look falls back to today's planner and
keeps today's cadence). The Terminus k-turn excess is the rule's own back-ups (+2 s a War Rig) and the Resupply Tanker behind them
turning to make way (+8 s on 7 of 24 seeds) — the fallback does not change it (`terminus-removal-*.txt`: dev 7001-7012, three arms,
+4.45 s a run in both bo arms); the same cells read yield+blocked -4.9 s a run and never-arrived -0.75 a run. The guard poses: on
stagings where no back-up is possible, ON pressed harder into the wall on 3 of 24 and was 3.5 s later on one. Round 46: judge the
squad's time to clear its start rather than k-turn seconds (a back-up IS a k-turn); the rear crew's reaction to a rig backing toward it.
