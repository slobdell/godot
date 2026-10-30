# Bar S v6 (round 46, manoeuvre M2): his squad settles where he clicks — FAILED as filed (four lines)

Frozen tree **4e72c5470** (stream/manoeuvre: S v6 = 659c9ab9b's seat ranks by the shape's own lateral offsets, the deep seat and its
rear crew out of the ranks); its check builder3 `>> remote: make check exited 0`, 3474 passed / 0 failed, sim-baseline unmoved, perf NOT
JUDGED (builder3). Arms `base` = `--shape-latch=off` v `s6` = `--shape-latch=off --seat-bound=on --seat-order=on --seat-last=open`, native
ON (`native-fresh` first). Seeds as filed (streams/manoeuvre.md Status, recorded on main 6ae7775a6; no amendment). Driver `bars_s6.sh`,
builder3 light, 02:25-02:49 PDT 2026-10-30. 0 files with SCRIPT ERROR in any leg.

| Line | Read | Verdict |
|---|---|---|
| D1 crews seated within the bound by 15 s (72 paired, 12001-12024) | 249 -> 352; +1.43 a run, se 0.18 (+7.9 se) | PASS |
| Guard yield + blocked s per arena (<= +2 se) | crossing **+5.95 (+2.1 se)**; locks **+2.84 (+2.2 se)**; terminus -5.67 (-5.2 se) | **FAIL (crossing, locks)** |
| Guard k-turn s per arena (<= +2 se) | crossing **+2.48 (+2.6 se)**; locks -1.72 (-1.7 se); terminus -10.2 (-6.6 se) | **FAIL (crossing)** |
| Guard wedged s per arena (<= +2 se; S v4 / S v5's miss) | crossing -2.24 (-1.0 se); locks +2.58 (+1.8 se); terminus +0.35 (+0.2 se) | PASS |
| Guard never-arrived pooled | 194 -> 149 (-0.63 a run) | PASS |
| Group G5 / G6 / G7 (12025-12036, 48 paired) | identical arms | PASS |
| G1 v9 corridor (12025-12036) | ORDERS_PROBE_SQUAD rows 180 / 180 byte-identical; g1v8 lines identical both arms | PASS |
| Fights G1-G3 (12037-12042, 18 fights an arm) | give-way deaths 54 -> 45; stuck deaths 119 -> 125; contacts 470701 -> 455691 | PASS |
| Fights G4 kill share worst move (<= 0.03) | Green 0.529 -> 0.489: **0.040**; deaths 809 -> 826 (line +/- 40) | **FAIL** |

**Cause read (START_YIELD rows):** the squad no longer gives way to itself (same-squad rows crossing 80 -> 60, locks 52 -> 24); squads
give way to EACH OTHER more (Guns <-> Hunters crossing 46 -> 77, locks 35 -> 59): compact squads at their clicks sit in the next
squad's way out of the start. The fights' G4 is S v4's old miss again (0.049 then; S v5 0.029).
