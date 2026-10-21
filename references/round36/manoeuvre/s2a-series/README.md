# S2a series (R36.27): h1bside + yieldgap ON v both OFF

- ON `lab/s2a-on` bf678480c (main e525f7311 + `H1B_SIDE_DEFAULT := true` + traffic `DEFAULT_OFF := []`), base `lab/s2a-base`
  = main e525f7311. Machine **builder2** (GCP e2-highcpu-32 Spot), native exec, J=6, one step at a time, 2026-10-21 00:57-06:35.
- Fights/wedge/jam: Locks, Terminus, Sumps x seeds 6540-6563 per arm (72 pairs). Hull-rest: seeds 6501-6532 x 4 factions x
  2 task sets, `--turn-states --element-trace=all` (128 pairs per task, 768 runs per arm).
- ON check: 23 passed, 2 FAILED (`test`: test_native_yield Sumps x2, `spot:back 0 >= 1`, 0 mismatches, ruled a test premise
  the switch moved, re-pinned by native `pair/native-yield-repin` 6a92e7a74; `sim-baseline`: expected with a switch flipped).
- Judge: `python3 tests/manoeuvre/s1_judge.py <dir> --bar s2a` -> `s2a_judge_bf678480c_v_e525f7311_builder2.txt`: **VERDICT PASS**.
- Caveat: the judge's "unstick fires" line reads 0 v 0 because main's WEDGE_TRACE row has no `unstick_fires` total (the S1 lab
  tree printed it). `fires_from_wedge_rows.txt` rebuilds the same guard from what main prints, paired by seed: unstick fires
  inside wedged episodes 28415 -> 27223 (-1192, 1.645se 1648), H1 escapes 2070 -> 2003 (-67, 166), asks 2033 -> 1930. Not up.
- Headlines: far loops 91 -> 35 (-56 > 38.6); stuck deaths 527 -> 497; kills/deaths/hit rate flat both teams; hull-rest
  left behind 77 -> 65 crews of 768 runs (wedged:idle 36 -> 34, wander 21 -> 10); faced_right never settled 19 -> 12.
