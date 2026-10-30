# Bar A6 v4 (round 45, manoeuvre M6): the street hold decided on the side stage's jam, one-sided head-on guard — FAILED as filed

Frozen tree `wip/manoeuvre-b2-freeze` **0493977ed** (holdway unchanged from main; check builder2 exited 0, 3448 / 0). ARM-W =
`--traffic-on=holdway` v BASE, native ON, builder0 light (`~/overnight-manoeuvre/r45/bars_a6v4/`), seeds 11449-11472 (hold probe, odd side /
even head-on, 75 s) and 11473-11496 (Bar E1's attack-shot probe). 0 files with SCRIPT ERROR. Filed in workstreams.md *Bars (round 45)*.

| Line | Read (paired mean a run, se, z) | Verdict |
|---|---|---|
| Deciding: side jam_s (12 side seeds; exercised 12 / 12, floor 8) | 397 -> 48 pooled; -29.1 s a run, se 5.2, **z -5.6**; pooled ARM < BASE | PASS |
| 1 off_arrive_s (side) <= BASE + 2 se | 752 -> 580; -14.3 s a run, z -5.0 | PASS |
| 2a verdicts (head-on) within +/- 2 se | 11 -> 13; +0.17, se 0.17, z 1.0 | PASS |
| 2b held_on_s (head-on) <= BASE + 2 se (one-sided) | 719 -> 357; -30.2 s a run, z -1.8 | PASS |
| 3 contacts_mouth (24) <= BASE + 1.645 se | 758 -> 1098; +14.2 a run, se 9.3, z 1.52 | PASS |
| 4 contacts_far (24) <= BASE + max(1.645 se, 2) | 9 -> 70; **+2.54 a run, se 1.41 (z 1.81); line +2.32** | **FAIL** |
| 5 last_a_s (24) <= BASE + 1.645 se | 1686 -> 1630; -2.3 s a run, z -1.0 | PASS |
| 6 Bar E1's lines (11473-11496, attack-shot ON both arms) | stuck 131.4 = 131.4, first hit 6.92 = 6.92, deaths 36 = 36: identical | PASS |
| 7 perf (the frozen tree's check) | NOT JUDGED on builder2; moot | — |
| 8 SCRIPT ERROR | none | PASS |

**Verdict: FAIL as filed on guard 4 by 0.22 contacts a run** (the released far crews meet the passer at the mouth on the head-on stages:
0 -> 0 on the side seeds, 9 -> 70 on the head-on ones, five seeds carry it: 11450 0 -> 9, 11458 3 -> 9, 11460 6 -> 15, 11464 0 -> 5,
11466 0 -> 32). Everything the bar is for passes by a wide margin (the side-street jam -29 s a run, the far crew arriving 14 s sooner).
holdway stays OFF; round 46: the head-on release's contacts at the mouth (A6 v3 read the same line at +1.0 se, now +1.8).
