# G1 v5 lab: crossing 3 click s4710 (R38.51's failing guard cell)

- Machine: builder0 light lane, J3. Tree: ef68308d1 (G1 v5 committed) + G2 v2 work in progress (`--group-route-corner`, OFF, not in these arms).
- Workload: `make native orders-probe`, crossing, 3 squads, click, seed 4710, n 1 (a lab, not judged).
- Arms: `main:`; `v4:--group-lay=column,--group-rank-shift=half,--group-whole=click,--group-clear=reached`; `v5:` v4 + `--group-lead=drive`.

| arm | squad 1 (Alpha, leads) | squad 2 (Bravo) | squad 3 | all-in | contacts |
|---|---|---|---|---|---|
| main | (-98.6, 62.1) in 9.2 s | (-79.7, 30.5) in 15.1 s | (-76.8, 31.3) in 17.3 s | 17.3 s | 875 |
| v4 | (-43.1, 86.2) in 3.3 s, twitch 32 m | (-75.4, 45.4) **never in** | (11.4, 97.5) in 2.2 s | never | 3,756 |
| v5 | (-75.4, 45.4) head, in 9.7 s, twitch 0 | (-43.1, 86.2) in 6.5 s, twitch 0 | (11.4, 97.5) in 2.2 s | 9.7 s | 71 |

v5 gives the column's head to Alpha, whose crews lead by ground; untangle swaps 0 (v4: 2).
