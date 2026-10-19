# M2 the k-turn arrival flicker: before/after REPORT on main (round 34, the orchestrator's ask after the merge)

M2 (`lab/m2-arriveleg` 0d0f22027, main 75a1d8c51) ships `ARRIVE_LEG_DEFAULT := true` with no judged series: a move_to's
arrival is not declared while a planned leg still drives (`Manoeuvre.leg_holds_arrival`, bounded 3 s). This folder is the
number behind it: `--nav-off=arriveleg` (base) v main (new), hull-rest, paired by seed, builder0, no bar (REPORT).

## Pass 1 (`judge_*.txt`, `hull_rest_counters.txt`, `flicker_spells.txt`, `face_pairs.txt`, `hull_rest_moving.txt`)
main c4aa9e2e0, all four factions, all six drawn tasks, seeds 60–71 (288 runs an arm), `M1_GD=1` (`--brains-off=native`),
`--turn-states`. **Every row identical, new v base** ((d), (e), settle, movers' kinds, the 380 short face spells), and
`arrivals_held` 0 in both arms: the hold never fired. Why: under `--brains-off=native` the planner seam's k-turn asks are
never answered inside their slice and every one is abandoned (`PLANNER_SEAM_REPORT` asks_by_kind kturn 3, driven 0 in
every run), so no crew is ever mid-leg at its radius. A measurement trap, now written on `M1_GDD` in mk/manoeuvre.mk.

## Pass 2 (`nd/`: `judge_new_drawn.txt`, `judge_new_clicked.txt`, `hull_rest_counters.txt`, `flicker_spells.txt`, `face_pairs.txt`)
stream b33b12fec (= main 165953b64 + M0's unshipped turn-in, which does not touch this path), gangs, drawn AND clicked, six
tasks, seeds 60–71 (72 runs an arm), `M1_GDD=1` (`--brains-off=native_drive`, planner's judge flags; the seam now drives:
kturn asks 478–745, driven 50–88 an arm). **The hold fired 3 times in 144 new-arm runs** (new_drawn 1: gangs
faced_attack_move-63; new_clicked 2: faced_attack_move-66, faced_right-63), one tick each; base 0. **Every other row is
identical new v base:** (d) movers 0–9 a task both arms, (e) never-settled 0–9 both, settle medians equal, planner's face
episodes paired BOTH 12 drawn / 28 clicked at equal distances (face_pairs (2c) ALL PASS), the short face spells 5 drawn /
25 clicked in both arms (those are `face from contact` at the quiet enemy, not arrival flickers). So on today's main
nothing else moved, and the arrival-mid-leg case is rare on this stage: three holds, each released the next tick.

## Pass 3 (`keep/`): planner's s69 stage exactly
Planner's diagnosis ran under P3's `--planner-face-keep=1` (the kept face search answers fast and starts the swing the
order then cancels); with today's keep 0 the mid-leg faces are the "neither served" kind. Gangs, CLICKED faced_attack_move,
seeds 66–71, keep 1, new v base: per seed the episodes and SERVED lists are identical (66: 4/1, 67: 5/0, 69: 12/1, the
rest none); seed 66 is where the hold fires (the seam's driven/aborted counts differ there, 4/6 v 2/4). The s69 shape
itself (five served faces, two closed by the order inside 46–216 ticks) is not on today's stage in either arm. `keep/`.

## Reading
Nothing else moved: every judged row, settle time, planner face episode and movers' kind is identical between main and
`--nav-off=arriveleg` over 288 + 144 + 12 paired runs. The hold itself fired three times in 144 gangs runs (and again on
seed 66 under keep 1), each for one tick, which is the whole measurable footprint of M2 on today's stage: the mid-leg
arrival is rare once the seam answers its asks, and planner's s69 flicker was a face-keep-1 (P3) shape that the ruler's
fresh stage no longer reproduces. The number for the orchestrator: 0 rows moved; 3 arrivals held; the flicker's own
signature 0 in both arms on seeds 66–71. The value of M2 is the correctness of the order (a move does not become a face
mid-leg); its size shows where k-turn legs are long (P5's stage), not here.
