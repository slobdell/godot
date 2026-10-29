# Bar S v4 (round 45, manoeuvre M5): his first squad settles where he clicks — FAILED as filed

Frozen tree `wip/manoeuvre-b2-freeze` **0493977ed** (seat bound / seat order unchanged from main; check builder2 exited 0, 3448 / 0).
Arms `base` = `--shape-latch=off` v `s4` = `--shape-latch=off --seat-bound=on --seat-order=on`, native ON (the drive twinned; the rules
are planner-side GDScript), builder2 light, seeds 11401-11442 as filed (workstreams.md *Bars (round 45)*). Driver
`~/overnight-manoeuvre/r45/bars_s4.sh`; evidence `~/overnight-manoeuvre/r45/bars_s4/`; 0 SCRIPT ERROR.

| Line | Read | Verdict |
|---|---|---|
| D1 crews seated within the bound 15 s after their order (72 paired cells) | 219 -> 362 pooled; +1.99 a run, se 0.23, **+8.6 se** | PASS |
| D2 start-zone yield + blocked s (a guard here) | 1553 -> 1388; -2.3 s a run (-1.6 se) | PASS |
| Per arena yield+blocked s (<= +2 se) | crossing +1.9 se, locks +0.2, terminus -5.7 | PASS |
| Per arena k-turn s (<= +2 se) | crossing -3.2 se, locks -1.9, terminus -10.0 | PASS |
| Per arena wedged s (<= +2 se) | crossing -0.1 se, terminus -0.2 se, **Locks +6.44 s a run (se 1.48, +4.4 se)** | **FAIL** |
| Never-arrived pooled (<= +2 se) | 243 -> 198 (-0.63 a run); Locks alone +0.9 a run | PASS |
| Group guards G5 / G6 / G7 (11425-11436) | identical arms | PASS |
| G1 v9 corridor: ORDERS_PROBE_SQUAD rows byte-identical; g1v8 lines | 180 / 180; identical, friend contacts 1686 = 1686 | PASS |
| Fights G1-G3 (11437-11442) | deaths in give-ways 60 -> 53, stuck deaths 120 -> 150 (line +36.6), contacts -15 % | PASS |
| Fights G4 kill share within 0.03 | Green 0.634 -> 0.585, **worst move 0.049**; deaths 797 -> 800 | **FAIL** |
| Perf | NOT JUDGED on builder2; moot | — |

**Verdict: FAIL as filed on the Locks wedged guard and the fight guard G4; the seat bound stays OFF (R45.17).** Who carries Locks'
wedged (summed over 24 seeds by crew slot): slot 5 +88.5 s, slot 4 +54.2, slot 2 +23.7, slot 3 -12.0, slot 1 +0.1 — the squad's last two
crews converging on a bound the first three already fill (`judge-workload.txt`, the per-run rows). The S v5 candidate
(`--seat-last=open`, the open deep seat the rear-most crew's) cured Locks on dev seeds (wedged -0.5 s a run, D1 +7.7 se, never-arrived
13 -> 3) and cost Terminus (+8.0 s a run): round 46's starting table is in streams/manoeuvre.md Status.
