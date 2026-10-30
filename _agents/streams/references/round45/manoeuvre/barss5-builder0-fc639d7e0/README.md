# Bar S v5 (round 45, manoeuvre M5): his first squad settles where he clicks, the last crew parks behind it — FAILED as filed

Frozen tree **fc639d7e0** (= stream/manoeuvre's code tip: S v4's bound + order, the open last seat with its two fixes 0a0b822ae /
ca8e71aba, holdway's verdict fix); its check: builder2, `>> remote: make check exited 0`, 27 targets, 26 passed, 2 NOT JUDGED (perf
lines: not a judging machine), sim-baseline unmoved (`check-fc639d7e0-summary.txt`). Arms `base` = `--shape-latch=off` v `s5` =
`--shape-latch=off --seat-bound=on --seat-order=on --seat-last=open`, native ON (planner-side GDScript rules; the drive twinned and
unchanged). Seeds 11751-11798 as filed (workstreams.md *Bars (round 45)*, FILED before any number; no amendment). Driver
`~/overnight-manoeuvre/r45/bars_s5.sh` from `../godot-manoeuvre-s5`, every leg builder0 light at J=4 (launched 21:05 PDT 2026-10-29 by
`after_check_s5.sh` on the check's green line); `meta.txt` has each leg's clock. Evidence `~/overnight-manoeuvre/r45/bars_s5/`.

| Line | Read | Verdict |
|---|---|---|
| D1 crews seated within the bound by 15 s (72 paired cells) | 220 -> 329; +1.51 a run, se 0.18 (**+8.4 se**); line >= +2 se and pooled ARM > BASE | PASS |
| D2 guard: start-zone yield + blocked s per arena (<= +2 se) | crossing **+9.85 s a run (+4.1 se)**; locks +1.80 (+2.0 se); terminus -2.14 (-1.0 se) | **FAIL (crossing)** |
| Guard: k-turn s per arena (<= +2 se) | crossing **+2.42 (+2.1 se)**; locks -0.47 (-0.5 se); terminus -10.9 (-9.2 se) | **FAIL (crossing)** |
| Guard: wedged s per arena (<= +2 se; S v4's miss) | crossing -8.44 (-5.9 se); **locks +3.37 (+3.2 se)**; terminus +3.40 (+1.2 se) | **FAIL (locks)** |
| Guard: never-arrived pooled (<= +2 se) | 225 -> 201; -0.33 a run (se 0.20, better) | PASS |
| Reported | seat moves 3238 -> 1784 (-20 a run); mean arrival -0.42 s a run; k-turn s pooled -3.0 s a run | — |
| Group guards G5 / G6 / G7 (11775-11786; 48 paired, for the record) | identical arms: every-squad-in 73.5 = 73.5 s, never-in 1.00 = 1.00, friendly contact ticks 657438 = 657438 (0 se) | PASS |
| G1 v9 corridor: ORDERS_PROBE_SQUAD byte-identical, g1v8 lines (11775-11786) | run for the record (`judge-g1v9.txt`) | — |
| Fights G1-G4 (11787-11792) | run for the record (`judge-fights.txt`) | — |
| No SCRIPT ERROR | 0 files in the workload | PASS |

**Verdict: FAIL as filed on three guards; the seat rules stay OFF.** The deciding line is wide (+8.4 se: his squad settles where he
clicks) and Locks' wedged miss halved from S v4 (+6.4 -> +3.4 s a run) but did not clear; Crossing's yield + blocked is the filing's
named risk come true, at +4.1 se where the dev read had +1.7 se. **Read on Crossing 11751 (the Battery layout; `judge-workload.txt`
cells):** base has NO yielding in the squad; under s5 the Battery yields to ITSELF in its start zone (Battery_3 <-> Battery_1 51 / 41
crew-ticks of mutual yield, Battery_4 <-> Battery_5 45 / 36): the open last seat and the rear-crew term deal the two-row layout seats
whose paths cross, so pairs of squadmates give way to each other where the bound alone (S v4) crossed nothing. The same shape on the Guns
+ Hunters layout (+10 s a run on 7 of 24 seeds). Round 46: the rear-crew term must respect the lateral order of the rest of the squad
(the deep seat's side decides which rear crew; the others keep S v4's order), or the open seat is laid on the squad's own line of
advance rather than the shape's deepest slot.
