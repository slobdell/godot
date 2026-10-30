# Bar B3 (round 45, manoeuvre): his War Rig backs out of the box first, on every pose — read on 11701-11748

Frozen tree **26b1425e7** = `pair/native-backout-b3` (stream/manoeuvre's backout v2 with the 11187 fallback and the room-behind gate +
native's twins `pair/native-backout-b2v2` 04ce3abe9 and `pair/native-backout-skip` 5ed7788ef, main 9203851ec); its check: builder2,
`>> remote: make check exited 0`, 25 passed, 3 NOT JUDGED (perf lines: builder2 is not a judging machine), sim-baseline unmoved
(`check-26b1425e7-summary.txt`). Arms `base` v `bo` = `--traffic-on=backout`, native ON, the C++ drive in both arms: native-proof
EQUAL 4a04ea921011cd9a, twin tests 34 / 0, the default orders probe 60 / 60 on 26b1425e7 (builder2). Seeds 11701-11748 as filed
(workstreams.md *Bars (round 45)*, FILED before any number; no amendment). Drivers `~/overnight-manoeuvre/r45/bars_b3_a.sh` (builder0
light, from `../godot-manoeuvre-b3x`: corpus, guard poses, named pose, fights, G1 probe) and `bars_b3_b.sh` (builder2, from
`../godot-manoeuvre-b3`: his start, his Gorge replay, workload, group guards); `meta.txt` has each leg's clock (launched 18:51 PDT
2026-10-29). Evidence `~/overnight-manoeuvre/r45/bars_b3/`.

| Line | Read | Verdict |
|---|---|---|
| D1 his start (Locks 56416, Green_Guns_2; builder2) | reversing t4 (base t44), past the box t97 (base t140); lines < 15 / < 110, base must not do both (`d1-his-start.txt`) | PASS |
| D2 corpus, base-stuck poses (floor 8; builder0 light, 98 rows) | 12 poses; ON sooner in **9 / 12 = 75 %** (line >= 80 %); the 3 not won are exact ties on pose 10 (11711 t360 = t360, 11725 t360 = t360, 11739 t187 = t187) | **FAIL** |
| D2 corpus, median gain on the base-stuck poses | -2.78 s (line <= -1 s) | PASS |
| D2 corpus, cost ceiling on the rest | 36 poses; worst +1.3 s (<= +3), median -0.52 s (<= +1) | PASS |
| D2 named cell: pose 10 at B2's 11187 jitter | clear t211 -> t236 (+0.8 s, line <= +3 s); wall ticks 126 -> 19 | PASS |
| D3 guard poses (the six round-44 stagings, 24 jittered) | 0 of 24 worse: the five no-room stagings within +1.0 s and +15 wall ticks; pose 2 within the +3 s ceiling (`judge-guard.txt`) | PASS |
| Workload: yield+blocked s per arena (72 paired cells) | crossing -0.0 se, locks +1.7 se, terminus -2.8 se (each <= +2 se) | PASS |
| Workload: wedged s per arena | crossing +1.1 se, locks -0.2 se, terminus -1.3 se | PASS |
| Workload: the squad's time to clear its start per arena (replaces k-turn s) | crossing +0.7 se (+21 ticks), locks +1.1 se (+3 ticks), terminus -1.5 se (-47 ticks) | PASS |
| Workload: never-arrived (pooled), D1-seated-by-15 s | -0.375 a run (-3.3 se, better); +0.24 a run (+1.3 se, line >= -2 se) | PASS |
| b1_judge: other crews' reversing ticks / seated (per arena) | -4.7/+2.0, +1.8/+1.0, -3.2/+1.3 se; nose-on crews clear 8 m 260 -> 280 ticks (+1.3 se, reported) | PASS |
| REPORTED (not a line): k-turn s per arena | crossing -0.1 se, locks +1.5 se, **terminus +3.7 se (+3.3 s a run)**: the rule's own back-ups, the same shape B2 read at +2.6 se | — |
| Engage's line: his Gorge replay 107 s base v bo | per-crew divergence tables identical (both arms read the same FAIL v his recording: main's E2 moved the replay, engage's) | PASS |
| Group guards G5 / G6 / G7 (11725-11736; builder2 light, 48 paired) | identical arms: every-squad-in 73.2 = 73.2 s, never-in 1.00 = 1.00, friendly contact ticks 663820 = 663820 (0 se) | PASS |
| G1 v9 corridor: ORDERS_PROBE_SQUAD rows byte-identical, g1v8 lines | PENDING (builder0 light) | — |
| Fights G1-G4 (11737-11742; builder0 light, 18 fights an arm) | deaths in give-ways 49 -> 47 (line +7.1), stuck deaths 120 -> 116 (line +6.2), friendly contact ticks -2.0 % (line +10 %), kill share worst move 0.004 (line 0.03); moving-stuck -0.54 s a fight (follow's deciding line, reported) | PASS |
| Perf | NOT JUDGED on builder2; a quiet builder0 perf read of the merge is owed before ON (R45.23) | — |
