# CP-F attempt 4 (Bar M3): JUDGED — PARKS on (d), (e), (g)

Series on `lab/cpf4` e76f6dab6 (lab/m1-ruler's tree + `TURN_HULL_DEFAULT := true`), builder2 start to end, 14 steps all
`exited 0` (`series-summary.txt`; steps 2–14 under systemd-run). Gate: e76f6dab6 `make native check` builder2 2815/0,
net-smoke and remote-guard-test green re-run alone; native's statement: no C++ change, twins 14/0. Fresh seeds: hull-rest
601–616 (384 runs an arm, drawn and clicked; the native drawn pair in `hull-rest-native`), Terminus 620–632, fights
640–663, SBF 670–675, bridge-pooled's 18. Base = the same tree with `--nav-off=turnhull` (native base arm: lab/m1-ruler
6c54f4e66, default false). Raw runs: `~/overnight-manoeuvre/r34_cpf4_series_e76f6dab6/` (outside the repo).

Readers here: `judge_*.txt` (cpf_judge --wedged, distinct and all pairs; the base arm's (a) lines; the native pair),
`hull_rest_ab.txt` (every class, permutation p), `hull_rest_moving.txt` (what the movers were doing), `hull_rest_counters*.txt`,
`line_c_clicked.txt`, `line_f_arrived.txt`, `terminus_ab.txt`, `fight_table.txt`, `face_pairs.txt` (planner's reader),
`sbf_*.txt`, `bridge.txt`, and the trace `trace_d_*.txt`.

| line | reads (distinct pairs; new v base) | verdict |
|---|---|---|
| (a) drawn point tasks, wheels/turret | move 3.0° / 92.3 % within 15°, right 3.2° / 93.5 %, attack-move 4.0° / 82.2 % (base 49.3° / 24 %, 47.5° / 22 %, 57.1° / 14 %) | PASS |
| (b) drawn line tasks, every class | ambush 3.7° v 80.4°, screen 26.0° v 53.7°, SBF 3.7° v 77.5°; no class median worse at p < 0.05 (hover and tracks identical between arms; wheels/fixed 3.1–4.2° v 3.1–4.1°, p 0.43–1.0) | PASS |
| (c) clicked, wheels/turret | paired median +0.0° on all six tasks, se 0: the clicked arms are the same runs (`hull_turns` 0 in new_clicked; a clicked face never reaches the hull turn) | PASS (vacuous) |
| (d) movers by `real_mps`, all classes | ambush 8 v 1 (+7, guard +3.2) **FAIL**; attack-move 19 v 4 (+15, guard +15.4) pass; move 14 v 5 (+9, guard +6.7) **FAIL**; right 13 v 10 (+3, +8.4) pass; screen 23 v 10 (+13, +5.4) **FAIL**; SBF 7 v 5 (+2, +3.0) pass; wheels/turret alone the same three miss; clicked all pass | **FAIL** |
| (e) never settled in 75 s | ambush 13 v 9 (+4, lim +4.9) pass; attack-move 20 v 14 (+6) **FAIL**; move 13 v 13; right 11 v 18; screen 20 v 20; SBF 12 v 8 (+4) pass; settle paired medians +2.8 / +2.0 / +1.5 / 0 / 0 / +9.0 s | **FAIL** |
| (f) squads arrived | drawn 846 v 842 over 382 pairs (+4, se 5.2); clicked 830 v 830; re-seats not measured (no re-seat count in the rows, as attempt 3) | PASS |
| (g) Terminus arrivals | mixed 285 v 290 of 312 (−5, 1.645 se 4.6; without each arm's two worst runs −3, se 1.5) **FAIL**; rigs 184 v 175 (+9, 1.645 se 15.2) pass; contact-ticks mixed −315, rigs −1075, both pass | **FAIL** (mixed) |
| (h) bridge-pooled | 18 of 18 both arms | PASS |
| (i) fights (23 pairs) | kills −12 (se 27.8), deaths −17 (25.2), shots −799 (1309), hits −312 (808), hit rate +0.011 (0.011), on touching targets +0.031 (0.034) | PASS |
| (j) counters, new_drawn | `hull_turns` 261 434, `hull_holds` 22 150 (reported), `off_seat_declines` 32 402, `face_keep_refused` 30 768; base all 0 | PASS |
| (k) s66 Green_Guns_5 | seed 66 is not in the fresh set; not run | REPORTED |
| (l) SBF gang_ifv drawn | in 24/24 both; median in 18.2 s v 15.2 s; hull error at in: median 2.3° v 31.9°, ≥ 45°: 0 v 7 | REPORTED |
| (m) the native path | twins 14/0; the native drawn pair agrees in sign: (a) 3.7 / 4.2 / 3.0 / 3.2 / 26.0 / 3.7° v 82.4 / 56.3 / 56.3 / 54.8 / 56.2 / 85.0°; (d) screen +18 (lim +10.9) fails there too, the other tasks pass | PASS (sign) |
| FACE_KEEP_FAR | drawn BOTH 9 faces INCONCLUSIVE, CAND_ONLY 33 faces median 5.4 v 3.6 m (se 0.54) over; clicked BOTH 25 faces 1.7 v 1.9 m ok | REPORTED |

**Verdict: PARKS** — (a)–(c), (f), (h)–(j) pass; (d) misses on three drawn tasks, (e) on attack-move, (g) on Terminus mixed.
R33.34's last-attempt clause: a fifth needs a new design, not a re-run.

## The trace of (d)/(e): two mechanisms, both named in `trace_d_*.txt`

1. **Faces that never finish (the creep).** `hull_rest_moving.txt`: wheels/turret crews in `face_creep` at the judge, new v
   base: screen 8 v 0, attack-move 4 v 0, SBF 2 v 0, ambush 1 v 0. A drawn face no plan fits is retried every second
   (`retry` 17–27) while the hull creeps at the 0.35 lock: law/faced_ambush-612 Green_Guns_1 from t 72 to the judge at 81,
   gangs/faced_screen-603 Green_Guns_2 retry 22 at 1.9 m/s. The ruler now counts those as movers (by `real_mps`); the old
   ruler counted them too but half of its movers were wedged hulls that hid them.
2. **Attack-move elements step later.** A crew that reaches an attack-move leg gets a `face from sector` (the brain's
   sector watch, tank_brain.gd ~2960) and the hull turns (law/faced_attack_move-614 Green_Guns_8: 4 s, then at rest 35 s);
   in the base arm the same crew gets a `stop`. The element's next leg then came at t 60 instead of t 32 (both arms had the
   same laggard, Green_Guns_6, 25 m short of its seat for 40 s; the base stepped at 32 regardless), so legs 2–3 ran past
   the 75 s judge: 7 of 26 attack-move pairs step ≥ 10 s later (`trace_d_secondleg.txt`: gangs 604/605/607/611/616, law
   612/614), which is attack-move's `driving` 14 v 10 and never-settled 20 v 14. Which rule in the element task holds the
   step while its crews sit on a `face` instead of a `stop` is brains' path; not traced further.

(g) mixed: the per-seed line (`terminus_ab.txt`) reads 620 22>21, 625 23>22, 627 23>22, 629 23>22, 630 22>20, 632 18>19:
one arrival a seed, five seeds of thirteen; no trace cut (parks on (d)/(e) already).
